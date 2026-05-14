-- 017_seed_demo_data.sql
-- Seed data demo untuk presentasi PBL — sintetis, mudah di-purge.
-- Pattern: semua sesi yg di-seed punya marker '[DEMO]' di kolom topic.
--
-- Distribusi sengaja:
--   Ahmad (mhs 1) — sehat ~86%       (6/7 sesi hadir/terlambat)
--   Siti  (mhs 2) — KRITIS ~29%      (2/7 sesi hadir, banyak alpa)
--   Dewi  (mhs 3) — Perhatian ~57%   (4/7 sesi hadir/terlambat)
--   Budi  (mhs 4) — Perhatian ~67%   (2/3 sesi hadir di MK002)
-- Output expected at /at-risk: 3 mhs (1 kritis + 2 perhatian)
--
-- Untuk purge nanti:
--   DELETE FROM attendances WHERE session_id IN (SELECT id FROM sessions WHERE topic LIKE '[DEMO]%');
--   DELETE FROM leave_requests WHERE reason LIKE '[DEMO]%';
--   DELETE FROM sessions WHERE topic LIKE '[DEMO]%';
--   DELETE FROM enrollments WHERE academic_year = '2025/2026';

DO $$
DECLARE
  -- Mahasiswa
  ahmad_id  uuid := '9719313b-9f4d-498a-a53f-dbfaa8baf202';
  siti_id   uuid := 'ed18b27b-6b07-4a5e-a8c3-9cdd0eb1b786';
  budi_id   uuid := '8c768d0f-51c2-4c10-b55c-f41d4dadf927';
  dewi_id   uuid := '21592124-375b-4398-97ba-e6319dedd2dd';
  -- Dosen
  bahlil_id  uuid := '673c71ad-133c-4d4b-b3b6-fb8445b755f1';
  ahmad_d_id uuid := '9ac5a41a-7588-4a24-a592-8cdc87258c6e';
  -- Courses
  mk001_id uuid := '5613064d-74cb-45bc-8901-cd8a8972f41f'; -- Pemrograman Web Lanjut, sm6, dosen bahlil
  mk002_id uuid := '3868b800-4341-404d-956e-9a29b7169a8b'; -- Basis Data Lanjut, sm4, dosen bahlil
  mk005_id uuid := 'acef89df-7417-4dac-8855-fcac01d8fc14'; -- Kecerdasan Buatan, sm6, dosen Ahmad Fauzi
  -- Sessions UUID storage (pakai gen_random_uuid pre-allocate biar bisa reference saat insert attendances)
  s_mk001_1 uuid := gen_random_uuid();
  s_mk001_2 uuid := gen_random_uuid();
  s_mk001_3 uuid := gen_random_uuid();
  s_mk001_4 uuid := gen_random_uuid();
  s_mk005_1 uuid := gen_random_uuid();
  s_mk005_2 uuid := gen_random_uuid();
  s_mk005_3 uuid := gen_random_uuid();
  s_mk002_1 uuid := gen_random_uuid();
  s_mk002_2 uuid := gen_random_uuid();
  s_mk002_3 uuid := gen_random_uuid();
BEGIN

-- ============================
-- 1. ENROLLMENTS (7 row)
-- ============================
INSERT INTO enrollments (course_id, student_id, academic_year) VALUES
  (mk001_id, ahmad_id, '2025/2026'),
  (mk001_id, siti_id,  '2025/2026'),
  (mk001_id, dewi_id,  '2025/2026'),
  (mk005_id, ahmad_id, '2025/2026'),
  (mk005_id, siti_id,  '2025/2026'),
  (mk005_id, dewi_id,  '2025/2026'),
  (mk002_id, budi_id,  '2025/2026')
ON CONFLICT DO NOTHING;

-- ============================
-- 2. SESSIONS (10 row, semua sudah selesai = ended_at NOT NULL)
-- ============================
INSERT INTO sessions (id, course_id, dosen_id, session_number, topic, mode, started_at, ended_at, location_lat, location_lng, radius_meters, is_active) VALUES
  -- MK001 Pemrograman Web Lanjut (4 sesi, dosen bahlil)
  (s_mk001_1, mk001_id, bahlil_id, 1, '[DEMO] Pengenalan Next.js & React',     'offline', NOW() - INTERVAL '28 days' + INTERVAL '8 hours',  NOW() - INTERVAL '28 days' + INTERVAL '9 hours 30 minutes',  -0.5378, 117.1242, 150, false),
  (s_mk001_2, mk001_id, bahlil_id, 2, '[DEMO] Server Components & RSC',         'offline', NOW() - INTERVAL '21 days' + INTERVAL '8 hours',  NOW() - INTERVAL '21 days' + INTERVAL '9 hours 30 minutes',  -0.5378, 117.1242, 150, false),
  (s_mk001_3, mk001_id, bahlil_id, 3, '[DEMO] Routing & Middleware',            'offline', NOW() - INTERVAL '14 days' + INTERVAL '8 hours',  NOW() - INTERVAL '14 days' + INTERVAL '9 hours 30 minutes',  -0.5378, 117.1242, 150, false),
  (s_mk001_4, mk001_id, bahlil_id, 4, '[DEMO] Authentication dengan Supabase',  'offline', NOW() - INTERVAL '7 days'  + INTERVAL '8 hours',  NOW() - INTERVAL '7 days'  + INTERVAL '9 hours 30 minutes',  -0.5378, 117.1242, 150, false),
  -- MK005 Kecerdasan Buatan (3 sesi, dosen Ahmad Fauzi)
  (s_mk005_1, mk005_id, ahmad_d_id, 1, '[DEMO] Pengenalan AI & Machine Learning', 'offline', NOW() - INTERVAL '25 days' + INTERVAL '13 hours', NOW() - INTERVAL '25 days' + INTERVAL '14 hours 30 minutes', -0.5378, 117.1242, 150, false),
  (s_mk005_2, mk005_id, ahmad_d_id, 2, '[DEMO] Neural Networks Dasar',             'offline', NOW() - INTERVAL '18 days' + INTERVAL '13 hours', NOW() - INTERVAL '18 days' + INTERVAL '14 hours 30 minutes', -0.5378, 117.1242, 150, false),
  (s_mk005_3, mk005_id, ahmad_d_id, 3, '[DEMO] Computer Vision & Deep Learning',  'offline', NOW() - INTERVAL '11 days' + INTERVAL '13 hours', NOW() - INTERVAL '11 days' + INTERVAL '14 hours 30 minutes', -0.5378, 117.1242, 150, false),
  -- MK002 Basis Data Lanjut (3 sesi, dosen bahlil)
  (s_mk002_1, mk002_id, bahlil_id,  1, '[DEMO] Normalisasi Database',           'offline', NOW() - INTERVAL '24 days' + INTERVAL '10 hours', NOW() - INTERVAL '24 days' + INTERVAL '11 hours 30 minutes', -0.5378, 117.1242, 150, false),
  (s_mk002_2, mk002_id, bahlil_id,  2, '[DEMO] Indexing & Query Optimization',  'offline', NOW() - INTERVAL '17 days' + INTERVAL '10 hours', NOW() - INTERVAL '17 days' + INTERVAL '11 hours 30 minutes', -0.5378, 117.1242, 150, false),
  (s_mk002_3, mk002_id, bahlil_id,  3, '[DEMO] Transaction & Concurrency',      'offline', NOW() - INTERVAL '10 days' + INTERVAL '10 hours', NOW() - INTERVAL '10 days' + INTERVAL '11 hours 30 minutes', -0.5378, 117.1242, 150, false);

-- ============================
-- 3. ATTENDANCES (24 row, distribusi sengaja agar memicu at-risk widget)
-- ============================
INSERT INTO attendances (session_id, student_id, status, scanned_at, student_lat, student_lng, distance_meters, is_location_valid, is_mock_location, session_mode) VALUES
  -- AHMAD — sehat ~86% (6 hadir/terlambat dari 7 sesi expected di MK001+MK005)
  (s_mk001_1, ahmad_id, 'hadir',     NOW() - INTERVAL '28 days' + INTERVAL '8 hours 5 minutes',  -0.5378, 117.1242, 12, true,  false, 'offline'),
  (s_mk001_2, ahmad_id, 'hadir',     NOW() - INTERVAL '21 days' + INTERVAL '8 hours 3 minutes',  -0.5378, 117.1242,  8, true,  false, 'offline'),
  (s_mk001_3, ahmad_id, 'terlambat', NOW() - INTERVAL '14 days' + INTERVAL '8 hours 30 minutes', -0.5378, 117.1242, 15, true,  false, 'offline'),
  (s_mk001_4, ahmad_id, 'hadir',     NOW() - INTERVAL '7 days'  + INTERVAL '8 hours 7 minutes',  -0.5378, 117.1242, 10, true,  false, 'offline'),
  (s_mk005_1, ahmad_id, 'hadir',     NOW() - INTERVAL '25 days' + INTERVAL '13 hours 5 minutes', -0.5378, 117.1242,  7, true,  false, 'offline'),
  (s_mk005_2, ahmad_id, 'hadir',     NOW() - INTERVAL '18 days' + INTERVAL '13 hours 8 minutes', -0.5378, 117.1242,  9, true,  false, 'offline'),
  (s_mk005_3, ahmad_id, 'alpa',      NOW() - INTERVAL '11 days' + INTERVAL '15 hours',           NULL,    NULL,     NULL, false, false, 'offline'),

  -- SITI — KRITIS ~29% (2 hadir dari 7, banyak alpa)
  (s_mk001_1, siti_id, 'hadir', NOW() - INTERVAL '28 days' + INTERVAL '8 hours 5 minutes',  -0.5378, 117.1242, 14, true,  false, 'offline'),
  (s_mk001_2, siti_id, 'alpa',  NOW() - INTERVAL '21 days' + INTERVAL '10 hours',           NULL,    NULL,     NULL, false, false, 'offline'),
  (s_mk001_3, siti_id, 'alpa',  NOW() - INTERVAL '14 days' + INTERVAL '10 hours',           NULL,    NULL,     NULL, false, false, 'offline'),
  (s_mk001_4, siti_id, 'sakit', NOW() - INTERVAL '7 days'  + INTERVAL '8 hours',            NULL,    NULL,     NULL, false, false, 'offline'),
  (s_mk005_1, siti_id, 'alpa',  NOW() - INTERVAL '25 days' + INTERVAL '15 hours',           NULL,    NULL,     NULL, false, false, 'offline'),
  (s_mk005_2, siti_id, 'hadir', NOW() - INTERVAL '18 days' + INTERVAL '13 hours 5 minutes', -0.5378, 117.1242, 11, true,  false, 'offline'),
  (s_mk005_3, siti_id, 'alpa',  NOW() - INTERVAL '11 days' + INTERVAL '15 hours',           NULL,    NULL,     NULL, false, false, 'offline'),

  -- DEWI — PERHATIAN ~57% (4 hadir/terlambat dari 7)
  (s_mk001_1, dewi_id, 'hadir',     NOW() - INTERVAL '28 days' + INTERVAL '8 hours 5 minutes',   -0.5378, 117.1242, 13, true,  false, 'offline'),
  (s_mk001_2, dewi_id, 'hadir',     NOW() - INTERVAL '21 days' + INTERVAL '8 hours 3 minutes',   -0.5378, 117.1242,  9, true,  false, 'offline'),
  (s_mk001_3, dewi_id, 'alpa',      NOW() - INTERVAL '14 days' + INTERVAL '10 hours',            NULL,    NULL,     NULL, false, false, 'offline'),
  (s_mk001_4, dewi_id, 'izin',      NOW() - INTERVAL '7 days'  + INTERVAL '8 hours',             NULL,    NULL,     NULL, false, false, 'offline'),
  (s_mk005_1, dewi_id, 'terlambat', NOW() - INTERVAL '25 days' + INTERVAL '13 hours 35 minutes', -0.5378, 117.1242, 16, true,  false, 'offline'),
  (s_mk005_2, dewi_id, 'alpa',      NOW() - INTERVAL '18 days' + INTERVAL '15 hours',            NULL,    NULL,     NULL, false, false, 'offline'),
  (s_mk005_3, dewi_id, 'hadir',     NOW() - INTERVAL '11 days' + INTERVAL '13 hours 7 minutes',  -0.5378, 117.1242,  8, true,  false, 'offline'),

  -- BUDI — PERHATIAN ~67% (2 hadir dari 3 di MK002)
  (s_mk002_1, budi_id, 'hadir', NOW() - INTERVAL '24 days' + INTERVAL '10 hours 6 minutes',  -0.5378, 117.1242, 11, true,  false, 'offline'),
  (s_mk002_2, budi_id, 'alpa',  NOW() - INTERVAL '17 days' + INTERVAL '11 hours 30 minutes', NULL,    NULL,     NULL, false, false, 'offline'),
  (s_mk002_3, budi_id, 'hadir', NOW() - INTERVAL '10 days' + INTERVAL '10 hours 3 minutes',  -0.5378, 117.1242,  9, true,  false, 'offline');

-- ============================
-- 4. LEAVE REQUESTS — 3 pending untuk demo Quick Action badge counter
-- ============================
INSERT INTO leave_requests (student_id, session_id, type, reason, status) VALUES
  (siti_id, s_mk001_3, 'sakit', '[DEMO] Demam tinggi 38.5C, tidak bisa hadir kuliah pagi.',          'pending'),
  (dewi_id, s_mk005_2, 'izin',  '[DEMO] Mengikuti kompetisi UI/UX di kampus.',                       'pending'),
  (budi_id, s_mk002_2, 'sakit', '[DEMO] Sakit kepala migrain, sudah ke poliklinik kampus.',          'pending');

END $$;
