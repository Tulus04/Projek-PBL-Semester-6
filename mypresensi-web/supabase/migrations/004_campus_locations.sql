-- supabase/migrations/004_campus_locations.sql
-- Tabel preset lokasi kampus untuk konfigurasi geofencing sesi absensi.
-- Dosen memilih lokasi dari daftar preset saat membuat sesi (mode offline).
-- Admin mengelola CRUD lokasi kampus via halaman Settings.

-- ===========================
-- CAMPUS LOCATIONS (preset lokasi kampus)
-- ===========================
CREATE TABLE IF NOT EXISTS campus_locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  radius_meters INTEGER DEFAULT 150,
  is_default BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed lokasi default (Politeknik Pertanian Negeri Samarinda)
INSERT INTO campus_locations (name, latitude, longitude, radius_meters, is_default) VALUES
  ('Kampus Utama', -0.5378, 117.1242, 150, true)
ON CONFLICT DO NOTHING;

-- ===========================
-- ROW LEVEL SECURITY
-- ===========================
ALTER TABLE campus_locations ENABLE ROW LEVEL SECURITY;

-- Semua authenticated user bisa baca (dosen perlu lihat daftar lokasi saat buat sesi)
CREATE POLICY "Authenticated users can read campus locations"
  ON campus_locations FOR SELECT
  TO authenticated
  USING (true);

-- Hanya admin yang bisa create/update/delete lokasi
CREATE POLICY "Admin can manage campus locations"
  ON campus_locations FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
