-- Migration 008: Avatar Bucket Listing Hardening
-- Bucket `avatars` adalah PUBLIC bucket — akses URL langsung tidak perlu SELECT policy.
-- Policy `Avatar public read` (broad SELECT) memungkinkan client melakukan LIST operation
-- yang dapat mengekspos daftar semua file di bucket.
-- 
-- Solusi: drop policy SELECT. Akses avatar via getPublicUrl() / direct URL TETAP JALAN
-- karena bucket flag public=true bypass RLS untuk URL access.
-- 
-- Verified safe: kode MyPresensi (`mypresensi-web/app/lib/actions/`) tidak pakai
-- `storage.from('avatars').list()` di mana pun.

DROP POLICY IF EXISTS "Avatar public read" ON storage.objects;

-- Audit
DO $$
BEGIN
  RAISE NOTICE 'Migration 008 applied: removed broad SELECT policy on storage.objects for avatars bucket.';
END
$$;
