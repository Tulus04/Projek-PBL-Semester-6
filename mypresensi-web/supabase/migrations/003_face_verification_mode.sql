-- supabase/migrations/003_face_verification_mode.sql
-- Menambahkan setting face_verification_mode ke tabel settings.
-- Mode: 'optional' (default) atau 'required'.

INSERT INTO settings (key, value, description) VALUES
  ('face_verification_mode', 'optional', 'Mode verifikasi wajah saat presensi: optional atau required')
ON CONFLICT (key) DO NOTHING;
