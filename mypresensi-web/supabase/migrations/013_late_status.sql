-- mypresensi-web/supabase/migrations/013_late_status.sql
-- Tambah status 'terlambat' ke enum CHECK constraint attendances.status
-- + tambah setting late_threshold_minutes (default 15 menit).
--
-- Auto-classify oleh /api/mobile/attendance/submit:
-- jika selisih (NOW() - sessions.started_at) > late_threshold_minutes
-- dan presensi valid (in-radius, GPS asli) → status='terlambat' bukan 'hadir'.
--
-- Treatment di UI:
-- - Dashboard summary: 'terlambat' DIHITUNG sebagai sub-bagian "Hadir" (tetap hadir, hanya telat)
-- - Rekap detail per mahasiswa: tampilkan kolom terpisah "Terlambat"
-- - Badge: warning tone (kuning) dengan label "Terlambat" + icon Clock
-- - Distinction dari izin/sakit (juga warning): label & icon yang berbeda
--
-- Idempotent: aman dijalankan ulang.

-- 1. Drop CHECK constraint lama, tambah baru dengan 'terlambat'
ALTER TABLE attendances
DROP CONSTRAINT IF EXISTS attendances_status_check;

ALTER TABLE attendances
ADD CONSTRAINT attendances_status_check
CHECK (status IN ('hadir', 'terlambat', 'izin', 'sakit', 'alpa'));

-- 2. Tambah setting late_threshold_minutes (idempotent)
INSERT INTO settings (key, value, description) VALUES
  ('late_threshold_minutes', '15', 'Batas keterlambatan dalam menit. Submit > nilai ini → status=terlambat')
ON CONFLICT (key) DO NOTHING;

-- 3. (Opsional) Index parsial untuk query "siapa yang sering terlambat"
-- Hanya buat kalau belum ada.
CREATE INDEX IF NOT EXISTS idx_attendances_terlambat
  ON attendances(student_id, scanned_at)
  WHERE status = 'terlambat';
