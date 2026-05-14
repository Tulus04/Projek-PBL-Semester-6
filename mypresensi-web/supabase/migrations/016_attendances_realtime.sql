-- 016_attendances_realtime.sql
-- Fitur Live Session Monitor — enable Supabase Realtime untuk tabel attendances.
-- Dosen subscribe ke channel `attendances:session_id=eq.<id>` untuk menerima INSERT
-- saat mahasiswa submit presensi → update progress bar + list peserta secara realtime.
-- Catatan keamanan: RLS pada attendances tetap apply ke realtime broadcast.
-- Policy "View own or all if admin/dosen" sudah memungkinkan dosen lihat row attendances.

-- Add tabel attendances ke publication supabase_realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.attendances;
