-- 015_at_risk_function.sql
-- Fitur At-Risk Students Widget — deteksi mahasiswa dengan kehadiran rendah.
-- Definisi: persentase = (count attendances WHERE status IN hadir/terlambat) / (count distinct sessions sudah selesai dari MK enrolled) × 100.
-- Default threshold: <70% dalam 30 hari terakhir, minimum 3 sesi expected (avoid noise mhs baru).
-- Catatan keamanan: SECURITY DEFINER + SET search_path eksplisit (ikuti pola handle_new_user). Server action WAJIB auth-guard requireRole.

BEGIN;

-- 1. Setting baru di tabel settings (4 row)
INSERT INTO public.settings (key, value, description) VALUES
  ('at_risk_threshold_pct', '70', 'Threshold persen kehadiran untuk dianggap at-risk (default 70). Mahasiswa dengan persentase kehadiran di bawah angka ini akan ditandai.'),
  ('at_risk_critical_pct', '50', 'Threshold persen kehadiran untuk tier kritis (default 50). Mahasiswa di bawah angka ini ditandai dengan badge merah.'),
  ('at_risk_window_days', '30', 'Window hari untuk hitung kehadiran at-risk (default 30 hari terakhir).'),
  ('at_risk_min_sessions', '3', 'Jumlah minimum sesi expected untuk hitungan at-risk valid (default 3). Avoid noise dari mahasiswa baru daftar.')
ON CONFLICT (key) DO NOTHING;

-- 2. Function get_at_risk_students()
-- Parameter:
--   p_threshold_pct  - threshold % kehadiran (default 70)
--   p_window_days    - window hari (default 30)
--   p_min_sessions   - minimum sesi expected (default 3)
--   p_dosen_id       - jika diisi, hanya hitung mhs di MK yang dosen tersebut ajar (default NULL = semua MK)
-- Return: list mhs at-risk, sorted by attendance_pct asc.
CREATE OR REPLACE FUNCTION public.get_at_risk_students(
  p_threshold_pct numeric DEFAULT 70,
  p_window_days int DEFAULT 30,
  p_min_sessions int DEFAULT 3,
  p_dosen_id uuid DEFAULT NULL
)
RETURNS TABLE (
  student_id uuid,
  full_name text,
  nim_nip text,
  kelas text,
  semester int,
  avatar_url text,
  expected_sessions bigint,
  attended_sessions bigint,
  attendance_pct numeric,
  last_attended_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH date_window AS (
    SELECT NOW() - (p_window_days || ' days')::interval AS start_date
  ),
  -- Per mhs: total sesi yang seharusnya diikuti (sudah selesai dalam window).
  -- Filter dosen_id jika diberikan: hanya MK yang dosen tsb ajar.
  expected_sess AS (
    SELECT 
      e.student_id,
      COUNT(DISTINCT s.id) AS total_expected
    FROM enrollments e
    JOIN courses c ON c.id = e.course_id
    JOIN sessions s ON s.course_id = e.course_id
    CROSS JOIN date_window dw
    WHERE s.started_at >= dw.start_date
      AND s.ended_at IS NOT NULL
      AND (p_dosen_id IS NULL OR c.dosen_id = p_dosen_id)
    GROUP BY e.student_id
  ),
  -- Per mhs: total kali hadir/terlambat (terlambat tetap dianggap "datang" untuk persentase).
  actual_att AS (
    SELECT 
      a.student_id,
      COUNT(*) AS total_attended,
      MAX(a.scanned_at) AS last_scanned
    FROM attendances a
    JOIN sessions s ON s.id = a.session_id
    JOIN courses c ON c.id = s.course_id
    CROSS JOIN date_window dw
    WHERE s.started_at >= dw.start_date
      AND a.status IN ('hadir', 'terlambat')
      AND (p_dosen_id IS NULL OR c.dosen_id = p_dosen_id)
    GROUP BY a.student_id
  )
  SELECT 
    p.id AS student_id,
    p.full_name,
    p.nim_nip,
    p.kelas,
    p.semester,
    p.avatar_url,
    COALESCE(es.total_expected, 0) AS expected_sessions,
    COALESCE(aa.total_attended, 0) AS attended_sessions,
    CASE 
      WHEN COALESCE(es.total_expected, 0) > 0 
      THEN ROUND((COALESCE(aa.total_attended, 0)::numeric / es.total_expected::numeric) * 100, 1)
      ELSE 100::numeric
    END AS attendance_pct,
    aa.last_scanned AS last_attended_at
  FROM profiles p
  LEFT JOIN expected_sess es ON es.student_id = p.id
  LEFT JOIN actual_att aa ON aa.student_id = p.id
  WHERE p.role = 'mahasiswa'
    AND p.is_active = true
    AND COALESCE(es.total_expected, 0) >= p_min_sessions
    AND CASE 
      WHEN COALESCE(es.total_expected, 0) > 0 
      THEN (COALESCE(aa.total_attended, 0)::numeric / es.total_expected::numeric) * 100
      ELSE 100::numeric
    END < p_threshold_pct
  ORDER BY attendance_pct ASC, expected_sessions DESC;
$$;

-- 3. Permission: revoke dari public, grant ke authenticated + service_role.
-- Server Action WAJIB requireRole('admin') atau ('dosen') dengan p_dosen_id sebelum call.
REVOKE ALL ON FUNCTION public.get_at_risk_students(numeric, int, int, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_at_risk_students(numeric, int, int, uuid) TO authenticated, service_role;

COMMIT;
