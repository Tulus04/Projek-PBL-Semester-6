-- ============================================================
-- verify-attendance.sql — Smoke test queries untuk attendance flow
-- ============================================================
-- Tujuan : Verifikasi end-to-end submit presensi mahasiswa via mobile,
--          termasuk path mock-GPS rejection (anti-fraud) dan path 5-layer
--          validasi sukses (sesi aktif + kode + enrolled + belum submit + GPS).
--
-- Pakai  : Supabase Studio → SQL Editor (login admin), atau psql.
-- Substitusi parameter di bawah sesuai konteks test:
--   <STUDENT_ID>   = profiles.id mahasiswa demo (dari .dev-accounts.md)
--   <SESSION_ID>   = sessions.id sesi yang baru di-mulai dosen
--   <COURSE_ID>    = courses.id MK-nya
-- ============================================================

-- ============================================================
-- Section 1: Pre-test baseline (catat angka SEBELUM mahasiswa submit)
-- ============================================================
-- Catatan: jalankan section ini sebelum mahasiswa scan QR. Catat hasilnya
-- supaya bisa bandingkan delta-nya di section 2.

-- 1.1 Sesi aktif & kode masih hidup
SELECT
  s.id              AS session_id,
  s.session_number,
  s.is_active,
  s.session_code,                   -- 6 digit (Tier 1 — jangan share screenshot publik)
  s.session_code_expires_at,
  (s.session_code_expires_at > now()) AS code_still_valid,
  s.mode,                           -- offline | online
  s.location_lat, s.location_lng,
  s.radius_meters,
  c.code AS course_code,
  c.name AS course_name
FROM sessions s
JOIN courses c ON c.id = s.course_id
WHERE s.id = '<SESSION_ID>';

-- 1.2 Mahasiswa enrolled di MK ini? (kalau 0 row → submit akan ditolak 403)
SELECT
  e.id, e.course_id, e.student_id, e.academic_year,
  p.full_name, p.nim_nip
FROM enrollments e
JOIN profiles p ON p.id = e.student_id
WHERE e.course_id = '<COURSE_ID>'
  AND e.student_id = '<STUDENT_ID>';

-- 1.3 Baseline jumlah attendance untuk sesi ini (harus 0 untuk mahasiswa target)
SELECT count(*) AS existing_count
FROM attendances
WHERE session_id = '<SESSION_ID>'
  AND student_id = '<STUDENT_ID>';

-- 1.4 Baseline audit_logs untuk mahasiswa target (untuk diff di section 3)
SELECT count(*) AS audit_baseline
FROM audit_logs
WHERE user_id = '<STUDENT_ID>'
  AND created_at > now() - interval '10 minutes';


-- ============================================================
-- Section 2: Verify submit success — happy path (GPS valid, no mock)
-- ============================================================
-- Jalankan setelah mahasiswa tap "Scan QR" di mobile + sukses.
-- Harus muncul tepat 1 row baru.

-- 2.1 Row attendance baru
SELECT
  a.id, a.session_id, a.student_id,
  a.status,                         -- 'hadir' (atau 'terlambat' kalau migration 013 aktif)
  a.scanned_at,
  a.student_lat, a.student_lng,
  a.distance_meters,                -- Haversine hasil server (bukan trust client)
  a.is_location_valid,              -- true kalau distance <= radius
  a.is_mock_location,               -- HARUS false untuk row hadir valid
  a.face_confidence,                -- null kalau face_verification_mode=optional
  a.is_face_matched,
  a.is_liveness_passed,
  a.device_model, a.device_os,
  a.ip_address,
  a.session_mode
FROM attendances a
WHERE a.session_id = '<SESSION_ID>'
  AND a.student_id = '<STUDENT_ID>'
ORDER BY a.scanned_at DESC
LIMIT 1;

-- 2.2 Sanity check: distance_meters dihitung server, bukan dari client
-- distance_meters > radius_meters tapi is_location_valid=true → BUG.
SELECT
  a.distance_meters,
  s.radius_meters,
  a.is_location_valid,
  CASE
    WHEN a.distance_meters <= s.radius_meters AND a.is_location_valid = true THEN 'OK'
    WHEN a.distance_meters > s.radius_meters AND a.is_location_valid = false THEN 'OK (di luar radius, ditolak)'
    ELSE 'INCONSISTENT — investigate Haversine logic'
  END AS sanity
FROM attendances a
JOIN sessions s ON s.id = a.session_id
WHERE a.session_id = '<SESSION_ID>'
  AND a.student_id = '<STUDENT_ID>';

-- 2.3 UNIQUE constraint enforcement: submit ke-2 dari mahasiswa yang sama
-- harus rejected di endpoint (409 / "sudah pernah submit").
-- Query ini hanya monitor — kalau muncul > 1 row, ada bug serius.
SELECT count(*) AS attendance_rows
FROM attendances
WHERE session_id = '<SESSION_ID>'
  AND student_id = '<STUDENT_ID>';
-- Expected: tepat 1


-- ============================================================
-- Section 3: Audit-check — mobile_attendance_submit
-- ============================================================
-- Setiap submit sukses WAJIB punya 1 row di audit_logs (rule
-- 02-quality-debugging A.1 + 14-supabase-patterns).

-- 3.1 Audit row submit sukses
SELECT
  al.id,
  al.action,                        -- 'mobile_attendance_submit'
  al.user_id,                       -- HARUS = <STUDENT_ID> (BUG-011 sudah fix)
  al.ip_address,                    -- HARUS non-null untuk endpoint mobile
  al.details,                       -- JSON: session_id, course_id, distance, device_id, ...
  al.created_at
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action = 'mobile_attendance_submit'
  AND al.created_at > now() - interval '10 minutes'
ORDER BY al.created_at DESC
LIMIT 1;

-- 3.2 Validasi shape details (harus include session_id + device_id + user_agent)
SELECT
  al.action,
  al.details ? 'session_id'   AS has_session_id,
  al.details ? 'device_id'    AS has_device_id,
  al.details ? 'user_agent'   AS has_user_agent,
  al.details->>'session_id'   AS session_id_in_details
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action = 'mobile_attendance_submit'
ORDER BY al.created_at DESC
LIMIT 1;


-- ============================================================
-- Section 4: Mock GPS rejection (P0 anti-fraud — release build)
-- ============================================================
-- Jalankan setelah test pakai Fake GPS app (release build APK).
-- Server harus REJECT 403 + insert audit row 'mock_location_detected'.
-- TIDAK ADA row di tabel attendances untuk submit ini.

-- 4.1 Pastikan TIDAK ada row attendance baru dari attempt mock
-- (server reject sebelum insert)
SELECT count(*) AS attendance_rows_after_mock
FROM attendances
WHERE session_id = '<SESSION_ID>'
  AND student_id = '<STUDENT_ID>'
  AND created_at > now() - interval '5 minutes';
-- Expected: 0 (atau count yang sama dengan baseline 1.3)

-- 4.2 Audit row mock_location_detected harus muncul
SELECT
  al.id, al.action, al.user_id, al.ip_address,
  al.details->>'session_id'  AS session_id,
  al.details->>'device_id'   AS device_id,
  al.details->>'student_lat' AS student_lat,
  al.details->>'student_lng' AS student_lng,
  al.created_at
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action = 'mock_location_detected'
  AND al.created_at > now() - interval '10 minutes'
ORDER BY al.created_at DESC
LIMIT 5;
-- Expected: minimal 1 row dengan ip_address non-null


-- ============================================================
-- Section 5: Face-related rejection paths (P0 face server-side)
-- ============================================================
-- Untuk session dengan face_verification_mode=required:
--   - mahasiswa belum register wajah  → audit 'face_not_registered_attempt'
--   - mahasiswa register tapi gagal match → audit 'face_mismatch_attempt'
-- Tidak ada row di attendances untuk attempt ini (server reject pre-insert).

SELECT
  al.action,
  al.user_id,
  al.details->>'session_id' AS session_id,
  al.details->>'similarity' AS similarity_score,
  al.details->>'threshold'  AS threshold_used,
  al.created_at
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action IN (
    'face_not_registered_attempt',
    'face_mismatch_attempt'
  )
  AND al.created_at > now() - interval '10 minutes'
ORDER BY al.created_at DESC;


-- ============================================================
-- Section 6: Cleanup helpers (DESTRUCTIVE — pakai hati-hati)
-- ============================================================
-- Untuk re-test happy path tanpa harus bikin sesi baru, hapus row attendance
-- mahasiswa target. JANGAN run di production. Comment out by default.
--
-- DELETE FROM attendances
-- WHERE session_id = '<SESSION_ID>'
--   AND student_id = '<STUDENT_ID>';
