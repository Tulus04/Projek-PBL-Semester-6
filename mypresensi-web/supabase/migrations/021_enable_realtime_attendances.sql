-- 021_enable_realtime_attendances.sql
-- Enable Supabase Realtime CDC streaming untuk tabel `attendances`.
-- Konsumen utama: hook `useRealtimeAttendances` di web dashboard
-- (Live Monitor Phase B2 + upgrade QR Display Fullscreen Phase B1).
--
-- Perubahan:
--   1. ADD `public.attendances` ke publication `supabase_realtime`
--      → Postgres WAL akan stream INSERT/UPDATE/DELETE event tabel ini
--        ke Realtime gateway untuk subscriber.
--   2. SET `REPLICA IDENTITY FULL` eksplisit
--      → payload event INCLUDE seluruh kolom row, bukan hanya PK.
--        Default pada PG sudah FULL untuk tabel dengan PK, tapi kita
--        eksplisit untuk safety + dokumentasi.
--
-- Spec referensi: `.kiro/specs/realtime-attendances-channel/`
-- Requirement     : 1.1, 1.2, 1.3, 1.4
-- Rule referensi : `14-web-supabase-patterns.md` Section G (Migration Idempotency)
--
-- Catatan keamanan: RLS policy "View own or all if admin/dosen" (existing
-- migration 012) sudah filter event delivery per-user. Realtime patuh RLS
-- — mahasiswa lain tidak akan terima event dari attendance bukan miliknya.
--
-- Idempotent: aman dijalankan ulang via `mcp0_apply_migration` — DO block
-- check `pg_publication_tables` mencegah error "table already in publication".

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'attendances'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.attendances;
  END IF;
END $$;

-- REPLICA IDENTITY FULL — payload event include seluruh kolom row.
-- Default sudah FULL untuk tabel dengan PK, tapi kita eksplisit.
ALTER TABLE public.attendances REPLICA IDENTITY FULL;
