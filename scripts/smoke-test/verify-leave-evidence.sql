-- ============================================================
-- verify-leave-evidence.sql — Smoke test queries untuk leave + evidence upload
-- ============================================================
-- Tujuan : Verifikasi P3-#1 (leave evidence upload) end-to-end:
--          (a) Bucket private + storage policies aktif (migration 019)
--          (b) Mobile upload bukti (multipart) → file di storage.objects
--          (c) Submit izin pakai evidence_path → row leave_requests
--          (d) Web admin/dosen klik "Lihat Bukti" → signed URL 5 menit
--          (e) Avatar upload mobile (P3-#3) — bonus reuse pattern
--
-- Pakai  : Supabase Studio → SQL Editor (login admin), atau psql.
-- Substitusi:
--   <STUDENT_ID>    = profiles.id mahasiswa demo
--   <REQUEST_ID>    = leave_requests.id (setelah submit)
--   <EVIDENCE_PATH> = '<student_id>/<32hex>.jpg' yang di-return upload endpoint
-- ============================================================

-- ============================================================
-- Section 1: Bucket + storage policies (migration 019)
-- ============================================================

-- 1.1 Bucket leave-evidence ada, private, limit + mime sesuai spec
SELECT
  id, name, public,
  file_size_limit,                  -- 5242880 (5 MB)
  allowed_mime_types                -- {image/jpeg, image/png, image/webp}
FROM storage.buckets
WHERE id = 'leave-evidence';
-- Expected: public=false, limit=5242880, 3 mime types

-- 1.2 Storage policies untuk bucket ini
SELECT policyname, cmd, roles, permissive
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname ILIKE '%Leave evidence%';
-- Expected: 2 policy
--   "Leave evidence upload by owner"  | INSERT | {authenticated}
--   "Leave evidence read by authorized" | SELECT | {authenticated}
-- (UPDATE / DELETE intentionally TIDAK ADA → immutable)

-- 1.3 Bucket avatars (reuse untuk avatar upload P3-#3) tetap aktif
SELECT id, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'avatars';


-- ============================================================
-- Section 2: Verify upload evidence (POST /api/mobile/leave-requests/upload-evidence)
-- ============================================================
-- Setelah mahasiswa pick foto + submit:
--   - Server return { path: '<user_id>/<random>.jpg' }
--   - File ada di storage.objects bucket=leave-evidence
--   - Audit row 'mobile_leave_evidence_upload'

-- 2.1 File di storage.objects (path prefix HARUS = student_id)
SELECT
  o.bucket_id,
  o.name,                            -- '<STUDENT_ID>/<32hex>.<ext>'
  o.owner,
  o.metadata->>'size'      AS size_bytes,
  o.metadata->>'mimetype'  AS mime,
  o.created_at
FROM storage.objects o
WHERE o.bucket_id = 'leave-evidence'
  AND (storage.foldername(o.name))[1] = '<STUDENT_ID>'
ORDER BY o.created_at DESC
LIMIT 5;

-- 2.2 Audit row upload
SELECT
  al.action, al.user_id, al.ip_address,
  al.details->>'path' AS evidence_path,
  al.details->>'size' AS size_bytes,
  al.details->>'mime' AS mime_type,
  al.created_at
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action = 'mobile_leave_evidence_upload'
  AND al.created_at > now() - interval '10 minutes'
ORDER BY al.created_at DESC
LIMIT 5;


-- ============================================================
-- Section 3: Verify submit leave_requests (POST /api/mobile/leave-requests/submit)
-- ============================================================
-- Body Zod sekarang accept evidence_path (BUKAN evidence_url).
-- Server validate prefix === user.id (defense-in-depth) sebelum simpan.
-- Kolom DB legacy tetap nama 'evidence_url' tapi isi sekarang PATH.

-- 3.1 Row leave_requests baru
SELECT
  lr.id,
  lr.student_id,
  lr.session_id,
  lr.type,                          -- 'izin' | 'sakit'
  lr.reason,
  lr.evidence_url,                  -- isi PATH (defacto), bukan full URL
  lr.status,                        -- default 'pending'
  lr.created_at
FROM leave_requests lr
WHERE lr.student_id = '<STUDENT_ID>'
  AND lr.created_at > now() - interval '10 minutes'
ORDER BY lr.created_at DESC
LIMIT 1;

-- 3.2 Validasi format evidence_url cocok regex EVIDENCE_PATH_REGEX server
-- ('<uuid>/<32hex>.<jpg|jpeg|png|webp>')
SELECT
  id,
  evidence_url,
  evidence_url ~ '^[0-9a-f-]{36}/[0-9a-f]+\.(jpe?g|png|webp)$' AS path_format_ok,
  split_part(evidence_url, '/', 1) AS path_owner_uuid,
  split_part(evidence_url, '/', 1) = '<STUDENT_ID>' AS prefix_match_owner
FROM leave_requests
WHERE id = '<REQUEST_ID>';
-- Expected: path_format_ok=true, prefix_match_owner=true

-- 3.3 Audit row submit
SELECT
  al.action,                        -- 'mobile_leave_request_submit'
  al.user_id, al.ip_address,
  al.details->>'session_id'    AS session_id,
  al.details->>'type'          AS leave_type,
  al.details->>'has_evidence'  AS has_evidence_flag,
  al.created_at
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action = 'mobile_leave_request_submit'
  AND al.created_at > now() - interval '10 minutes'
ORDER BY al.created_at DESC
LIMIT 1;


-- ============================================================
-- Section 4: Web admin/dosen baca bukti via signed URL
-- ============================================================
-- Server Action getLeaveEvidenceSignedUrl(requestId) → signed URL TTL 5 menit.
-- Tidak ada DB row baru — verify via response API + storage log.

-- 4.1 Confirm path masih ada (file tidak terhapus)
SELECT
  o.name, o.bucket_id, o.created_at
FROM storage.objects o
WHERE o.bucket_id = 'leave-evidence'
  AND o.name = '<EVIDENCE_PATH>';
-- Expected: 1 row (file tetap ada — immutable, tidak ada policy DELETE untuk authenticated)

-- 4.2 Approve / reject akan log audit (review_at + status)
SELECT
  lr.id, lr.status, lr.reviewed_by, lr.reviewed_at, lr.review_note,
  reviewer.full_name AS reviewer_name,
  reviewer.role      AS reviewer_role
FROM leave_requests lr
LEFT JOIN profiles reviewer ON reviewer.id = lr.reviewed_by
WHERE lr.id = '<REQUEST_ID>';

-- 4.3 Audit approve_leave / reject_leave (server action dosen/admin)
SELECT
  al.action, al.user_id,
  al.details->>'request_id' AS request_id,
  al.details->>'type'       AS leave_type,
  al.created_at
FROM audit_logs al
WHERE al.action IN ('approve_leave', 'reject_leave')
  AND al.details->>'request_id' = '<REQUEST_ID>'
ORDER BY al.created_at DESC
LIMIT 5;


-- ============================================================
-- Section 5: Avatar upload mobile (P3-#3 — bonus, reuse infra)
-- ============================================================
-- Path convention: '<user.id>.jpg' di bucket avatars (public).

-- 5.1 File avatar tersimpan
SELECT
  o.bucket_id, o.name, o.owner,
  o.metadata->>'size'     AS size_bytes,
  o.metadata->>'mimetype' AS mime,
  o.updated_at
FROM storage.objects o
WHERE o.bucket_id = 'avatars'
  AND o.name LIKE '<STUDENT_ID>%'
ORDER BY o.updated_at DESC
LIMIT 5;

-- 5.2 profiles.avatar_url updated dengan cache buster ?t=<ts>
SELECT id, full_name, avatar_url, updated_at
FROM profiles
WHERE id = '<STUDENT_ID>';

-- 5.3 Audit row avatar upload
SELECT
  al.action,                        -- 'mobile_avatar_upload'
  al.user_id, al.ip_address,
  al.details->>'path' AS path,
  al.details->>'size' AS size_bytes,
  al.created_at
FROM audit_logs al
WHERE al.user_id = '<STUDENT_ID>'
  AND al.action = 'mobile_avatar_upload'
  AND al.created_at > now() - interval '15 minutes'
ORDER BY al.created_at DESC
LIMIT 1;


-- ============================================================
-- Section 6: Cross-tenant isolation check (P0 — RLS hardness)
-- ============================================================
-- Mahasiswa B coba upload ke prefix mahasiswa A → INSERT policy reject.
-- Test ini paling baik dilakukan di mobile (real Bearer JWT) — query di sini
-- hanya untuk audit forensic kalau ada violation log.

-- Cari upload yang folder prefix-nya BUKAN milik si uploader (anomaly)
SELECT
  o.name,
  (storage.foldername(o.name))[1] AS path_prefix,
  o.owner                          AS uploader_user,
  o.created_at
FROM storage.objects o
WHERE o.bucket_id = 'leave-evidence'
  AND o.owner IS NOT NULL
  AND (storage.foldername(o.name))[1] <> o.owner::text
LIMIT 10;
-- Expected: 0 row (RLS sudah enforce prefix === auth.uid())
