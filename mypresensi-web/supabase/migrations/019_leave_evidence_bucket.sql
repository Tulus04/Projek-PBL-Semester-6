-- 019_leave_evidence_bucket.sql
-- Bucket private untuk simpan bukti izin/sakit (foto KTM, surat dokter, dll).
-- Akses lewat signed URL on-demand (TTL 5 menit) bukan public URL.
--
-- Path convention: '<student_id>/<random>.<ext>' — path prefix mahasiswa
-- jadi authorization boundary lewat RLS.
--
-- Tier sensitivity: surat dokter = data kesehatan personal (UU PDP Pasal 4 'data spesifik').
-- Akses minimum: owner mahasiswa, dosen MK terkait, admin. Anon/authenticated lain DENIED.
--
-- Applied via MCP apply_migration sebagai version 20260516xxxxxx_leave_evidence_bucket.
-- File lokal pakai sequential 019 untuk readability di repo.

BEGIN;

-- 1. Create bucket private
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'leave-evidence',
  'leave-evidence',
  false,
  5242880,  -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Storage policies

-- 2a. INSERT — mahasiswa upload ke folder dengan prefix UUID-nya sendiri.
-- Path format: '<auth.uid()>/<filename>' — (storage.foldername(name))[1] = path part pertama.
DROP POLICY IF EXISTS "Leave evidence upload by owner" ON storage.objects;
CREATE POLICY "Leave evidence upload by owner"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'leave-evidence'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

-- 2b. SELECT — 3 path:
--   (a) Owner mahasiswa lihat punya sendiri
--   (b) Dosen MK terkait lihat evidence student di MK-nya (via leave_requests → sessions → courses)
--   (c) Admin lihat semua
DROP POLICY IF EXISTS "Leave evidence read by authorized" ON storage.objects;
CREATE POLICY "Leave evidence read by authorized"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'leave-evidence'
    AND (
      -- (a) Owner
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
      -- (b) Admin
      OR EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = (SELECT auth.uid()) AND role = 'admin'
      )
      -- (c) Dosen MK terkait
      OR EXISTS (
        SELECT 1
        FROM public.leave_requests lr
        JOIN public.sessions s ON s.id = lr.session_id
        JOIN public.courses c ON c.id = s.course_id
        WHERE lr.evidence_url = storage.objects.name
          AND c.dosen_id = (SELECT auth.uid())
      )
    )
  );

-- 2c. UPDATE & DELETE — deny semua (immutable evidence). Service_role tetap bisa via bypass RLS.
-- Tidak buat policy → default DENY untuk authenticated.
-- Sengaja TIDAK CREATE POLICY agar tidak ada path untuk authenticated modify.

COMMIT;
