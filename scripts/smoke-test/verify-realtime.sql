-- ============================================================
-- verify-realtime.sql — Smoke test queries untuk Supabase Realtime channel
-- ============================================================
-- Tujuan : Verifikasi Phase C1 (realtime-attendances-channel) + showcase
--          Phase B2 (Live Monitor dosen) yang konsumsi hook
--          useRealtimeAttendances.
--
-- Coverage:
--   (1) Tabel attendances ter-publish ke supabase_realtime
--   (2) REPLICA IDENTITY FULL → payload event include semua kolom
--   (3) RLS policy attendances konsisten (dosen MK lihat semua, mahasiswa hanya own)
--   (4) FK index untuk performa Live Monitor query
--   (5) QR Display Phase B1 — endpoint /live-stats (sanity)
--
-- Pakai  : Supabase Studio → SQL Editor (login admin), atau psql.
-- Substitusi:
--   <SESSION_ID> = sessions.id sesi aktif yang lagi dipantau
--   <COURSE_ID>  = courses.id MK-nya
-- ============================================================

-- ============================================================
-- Section 1: Realtime publication aktif untuk attendances
-- ============================================================

-- 1.1 Tabel attendances HARUS terdaftar di publication supabase_realtime
SELECT
  pubname,
  schemaname,
  tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public'
  AND tablename = 'attendances';
-- Expected: 1 row. Kalau kosong → migration 021 belum apply.

-- 1.2 Semua tabel di publication (untuk audit scope)
SELECT pubname, schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY schemaname, tablename;
-- Expected: minimal include 'attendances'. Kalau ada tabel sensitif lain
-- (face_embeddings, audit_logs) → STOP, investigate (jangan publish Tier 1).

-- 1.3 REPLICA IDENTITY = FULL (payload event include semua kolom row)
SELECT
  c.relname AS table_name,
  CASE c.relreplident
    WHEN 'd' THEN 'DEFAULT (PK only)'
    WHEN 'n' THEN 'NOTHING'
    WHEN 'f' THEN 'FULL'
    WHEN 'i' THEN 'INDEX'
  END AS replica_identity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'attendances';
-- Expected: FULL


-- ============================================================
-- Section 2: RLS policy attendances — Realtime patuh RLS
-- ============================================================
-- Realtime evaluasi RLS per-event delivery. Mahasiswa A subscribe channel
-- tidak akan dapat INSERT row mahasiswa B (kecuali dia admin/dosen).

-- 2.1 List policies
SELECT
  policyname, cmd, permissive, roles, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'attendances'
ORDER BY policyname;

-- 2.2 RLS aktif?
SELECT relname, relrowsecurity AS rls_enabled
FROM pg_class
WHERE relname = 'attendances'
  AND relnamespace = 'public'::regnamespace;
-- Expected: rls_enabled = true


-- ============================================================
-- Section 3: FK index untuk performa Live Monitor query
-- ============================================================
-- Endpoint /live-state JOIN enrollments + attendances + profiles.
-- Tanpa index FK → seq scan, lambat di scale.

SELECT
  i.tablename, i.indexname, i.indexdef
FROM pg_indexes i
WHERE i.schemaname = 'public'
  AND i.tablename IN ('attendances', 'enrollments', 'sessions')
ORDER BY i.tablename, i.indexname;
-- Expected (sesuai migration 010 + 020):
--   attendances: idx_attendances_session, idx_attendances_student, idx_attendances_status
--   enrollments: idx_enrollments_student, idx_enrollments_course
--   sessions   : idx_sessions_course, idx_sessions_active, idx_sessions_started_at


-- ============================================================
-- Section 4: Live state snapshot untuk session aktif (Phase B2)
-- ============================================================
-- Manual reproduce query yang dipakai endpoint /api/admin/sessions/[id]/live-state.

-- 4.1 Daftar mahasiswa enrolled + status presensi mereka di sesi
SELECT
  p.id          AS student_id,
  p.full_name,
  p.nim_nip,
  COALESCE(a.status, 'belum')      AS status,
  a.scanned_at,
  a.distance_meters,
  a.is_mock_location,
  a.face_confidence
FROM enrollments e
JOIN profiles p ON p.id = e.student_id
LEFT JOIN attendances a
  ON a.session_id = '<SESSION_ID>'
 AND a.student_id = e.student_id
WHERE e.course_id = '<COURSE_ID>'
ORDER BY p.full_name;

-- 4.2 KPI bar live monitor
SELECT
  count(*) FILTER (WHERE a.status = 'hadir')                      AS hadir,
  count(*) FILTER (WHERE a.status = 'terlambat')                  AS terlambat,
  count(*) FILTER (WHERE a.is_mock_location = true)               AS ditolak_mock,
  count(*) FILTER (WHERE a.id IS NULL)                            AS belum,
  count(*)                                                        AS total
FROM enrollments e
LEFT JOIN attendances a
  ON a.session_id = '<SESSION_ID>'
 AND a.student_id = e.student_id
WHERE e.course_id = '<COURSE_ID>';


-- ============================================================
-- Section 5: QR Display Phase B1 — sanity /live-stats
-- ============================================================
-- Endpoint /api/admin/sessions/[id]/live-stats return { hadir, total }
-- (polling 5 detik, fallback path saat Realtime CHANNEL_ERROR).

SELECT
  -- hadir + terlambat = "sudah hadir di kelas" (rule 04-security E + 13-late-status migration)
  (
    SELECT count(*) FROM attendances
    WHERE session_id = '<SESSION_ID>'
      AND status IN ('hadir', 'terlambat')
  ) AS hadir,
  (
    SELECT count(*) FROM enrollments
    WHERE course_id = '<COURSE_ID>'
  ) AS total;


-- ============================================================
-- Section 6: Realtime debug — recent INSERT events di window terakhir
-- ============================================================
-- Untuk verifikasi mata-vs-mata: setelah mahasiswa scan QR, query ini muncul
-- row baru. Window A (browser dosen) HARUS lihat dot baru muncul <2 detik
-- setelah row ini ada.

SELECT
  a.id, a.session_id, a.student_id,
  a.status, a.scanned_at,
  a.is_mock_location,
  a.distance_meters,
  p.full_name
FROM attendances a
JOIN profiles p ON p.id = a.student_id
WHERE a.session_id = '<SESSION_ID>'
  AND a.scanned_at > now() - interval '2 minutes'
ORDER BY a.scanned_at DESC;


-- ============================================================
-- Section 7: Free tier connection check (informational)
-- ============================================================
-- Free tier limit: 200 concurrent Realtime connections per project.
-- Setiap browser tab dosen yang buka Live Monitor / QR Display = 1 connection.

-- Tidak ada query langsung ke pg_stat untuk ini (Realtime jalan di service
-- terpisah Phoenix). Cek via Supabase Dashboard → Reports → Realtime usage.
-- Catatan smoke test: untuk PBL skala (5-10 dosen + 50 mahasiswa) jauh di
-- bawah limit.
