-- ============================================================
-- MyPresensi — Database Migration v1
-- Prodi TRPL, Politeknik Pertanian Negeri Samarinda
-- Jalankan di: Supabase Dashboard → SQL Editor
-- ============================================================

-- ===========================
-- PROFILES (semua user)
-- ===========================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT NOT NULL,
  nim_nip TEXT UNIQUE NOT NULL,
  role TEXT CHECK (role IN ('admin', 'dosen', 'mahasiswa')) NOT NULL,
  semester INTEGER,
  kelas TEXT,
  phone TEXT,
  avatar_url TEXT,
  is_face_registered BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  must_change_password BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- FACE EMBEDDINGS
-- ===========================
CREATE TABLE IF NOT EXISTS face_embeddings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  embedding BYTEA NOT NULL,
  embedding_hash TEXT NOT NULL,
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- COURSES (mata kuliah)
-- ===========================
CREATE TABLE IF NOT EXISTS courses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  sks INTEGER DEFAULT 3,
  semester INTEGER NOT NULL,
  dosen_id UUID REFERENCES profiles(id),
  academic_year TEXT DEFAULT '2025/2026',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- ENROLLMENTS (relasi mahasiswa - mata kuliah)
-- ===========================
CREATE TABLE IF NOT EXISTS enrollments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  academic_year TEXT NOT NULL,
  UNIQUE(course_id, student_id, academic_year)
);

-- ===========================
-- SESSIONS (sesi perkuliahan)
-- ===========================
CREATE TABLE IF NOT EXISTS sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
  dosen_id UUID REFERENCES profiles(id),
  session_number INTEGER NOT NULL,
  topic TEXT,
  mode TEXT CHECK (mode IN ('offline', 'online')) DEFAULT 'offline',
  session_code TEXT,
  session_code_expires_at TIMESTAMPTZ,
  location_lat DOUBLE PRECISION DEFAULT -0.5378,
  location_lng DOUBLE PRECISION DEFAULT 117.1242,
  radius_meters INTEGER DEFAULT 150,
  is_active BOOLEAN DEFAULT TRUE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- ATTENDANCES
-- ===========================
CREATE TABLE IF NOT EXISTS attendances (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('hadir', 'izin', 'sakit', 'alpa')) DEFAULT 'hadir',
  scanned_at TIMESTAMPTZ DEFAULT NOW(),
  student_lat DOUBLE PRECISION,
  student_lng DOUBLE PRECISION,
  distance_meters DOUBLE PRECISION,
  is_location_valid BOOLEAN,
  is_mock_location BOOLEAN DEFAULT FALSE,
  wifi_ssid TEXT,
  face_confidence DOUBLE PRECISION,
  is_face_matched BOOLEAN,
  is_liveness_passed BOOLEAN,
  device_model TEXT,
  device_os TEXT,
  ip_address TEXT,
  session_mode TEXT,
  UNIQUE(session_id, student_id)
);

-- ===========================
-- LEAVE REQUESTS (izin/sakit)
-- ===========================
CREATE TABLE IF NOT EXISTS leave_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  type TEXT CHECK (type IN ('izin', 'sakit')) NOT NULL,
  reason TEXT NOT NULL,
  evidence_url TEXT,
  status TEXT CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
  reviewed_by UUID REFERENCES profiles(id),
  review_note TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- SETTINGS (konfigurasi sistem)
-- ===========================
CREATE TABLE IF NOT EXISTS settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed data default settings
INSERT INTO settings (key, value, description) VALUES
  ('geofence_radius_meters', '150', 'Radius default geofencing kampus dalam meter'),
  ('face_confidence_threshold', '0.75', 'Batas minimum confidence face recognition (0-1)'),
  ('session_code_expiry_minutes', '3', 'Durasi kode sesi online dalam menit'),
  ('max_login_attempts', '5', 'Maksimum percobaan login sebelum lockout'),
  ('lockout_minutes', '30', 'Durasi lockout setelah gagal login')
ON CONFLICT (key) DO NOTHING;

-- ===========================
-- AUDIT LOGS
-- ===========================
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  action TEXT NOT NULL,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- RATE LIMIT LOG
-- ===========================
CREATE TABLE IF NOT EXISTS rate_limit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  endpoint TEXT NOT NULL,
  requested_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- INDEXES (performa query)
-- ===========================
CREATE INDEX IF NOT EXISTS idx_attendances_session ON attendances(session_id);
CREATE INDEX IF NOT EXISTS idx_attendances_student ON attendances(student_id);
CREATE INDEX IF NOT EXISTS idx_attendances_status ON attendances(status);
CREATE INDEX IF NOT EXISTS idx_leave_requests_student ON leave_requests(student_id);
CREATE INDEX IF NOT EXISTS idx_leave_requests_status ON leave_requests(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_sessions_course ON sessions(course_id);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON sessions(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_enrollments_student ON enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_nim ON profiles(nim_nip);

-- ===========================
-- ROW LEVEL SECURITY (RLS)
-- ===========================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE face_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendances ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- ===========================
-- RLS POLICIES
-- ===========================

-- PROFILES: user bisa lihat & update profilnya sendiri
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Admin bisa lihat semua profile
CREATE POLICY "Admin can view all profiles"
  ON profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- FACE EMBEDDINGS: hanya pemilik
CREATE POLICY "Users can manage own face embedding"
  ON face_embeddings FOR ALL
  USING (auth.uid() = user_id);

-- COURSES: semua user bisa lihat, dosen/admin bisa manage
CREATE POLICY "All users can view courses"
  ON courses FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admin can manage courses"
  ON courses FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dosen')
    )
  );

-- ENROLLMENTS: mahasiswa lihat enrollment sendiri
CREATE POLICY "Students can view own enrollments"
  ON enrollments FOR SELECT
  USING (auth.uid() = student_id);

CREATE POLICY "Admin and dosen can manage enrollments"
  ON enrollments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dosen')
    )
  );

-- SESSIONS: semua user login bisa lihat
CREATE POLICY "Authenticated users can view sessions"
  ON sessions FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Dosen can manage own sessions"
  ON sessions FOR ALL
  USING (auth.uid() = dosen_id);

-- ATTENDANCES: mahasiswa hanya lihat milik sendiri
CREATE POLICY "Students can view own attendance"
  ON attendances FOR SELECT
  USING (auth.uid() = student_id);

CREATE POLICY "Students can insert own attendance"
  ON attendances FOR INSERT
  WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Dosen and admin can view all attendances"
  ON attendances FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dosen')
    )
  );

-- LEAVE REQUESTS: mahasiswa manage request sendiri
CREATE POLICY "Students can manage own leave requests"
  ON leave_requests FOR ALL
  USING (auth.uid() = student_id);

CREATE POLICY "Dosen and admin can view and update leave requests"
  ON leave_requests FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dosen')
    )
  );

-- SETTINGS: hanya admin yang bisa lihat & ubah
CREATE POLICY "Admin can manage settings"
  ON settings FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- AUDIT LOGS: hanya admin
CREATE POLICY "Admin can view audit logs"
  ON audit_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- System dapat insert audit log
CREATE POLICY "System can insert audit logs"
  ON audit_logs FOR INSERT
  WITH CHECK (TRUE);

-- ===========================
-- FUNCTION: Auto-update updated_at
-- ===========================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger untuk profiles
CREATE OR REPLACE TRIGGER trigger_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger untuk face_embeddings
CREATE OR REPLACE TRIGGER trigger_face_embeddings_updated_at
  BEFORE UPDATE ON face_embeddings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===========================
-- FUNCTION: Auto-create profile saat user baru daftar
-- ===========================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, nim_nip, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Pengguna Baru'),
    COALESCE(NEW.raw_user_meta_data->>'nim_nip', NEW.id::TEXT),
    COALESCE(NEW.raw_user_meta_data->>'role', 'mahasiswa')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger untuk auth.users
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
