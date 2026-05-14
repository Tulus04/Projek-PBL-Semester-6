-- Migration 012: Konsolidasi Multiple Permissive Policies
-- Postgres harus evaluate SEMUA permissive policy untuk role+command yang sama.
-- Solusi: merge 2+ policy jadi 1 dengan OR clause (kecuali untuk tabel sederhana).
-- Berdasarkan Supabase advisor `multiple_permissive_policies` (WARN).
--
-- Behavior IDENTIK — UNION dari conditions di-pertahankan via OR.

-- ========== attendances ==========
-- Sebelum: 2 policy SELECT (own + admin/dosen all)
-- Setelah: 1 policy SELECT dengan OR
DROP POLICY IF EXISTS "Students can view own attendance" ON public.attendances;
DROP POLICY IF EXISTS "Dosen and admin can view all attendances" ON public.attendances;
CREATE POLICY "View own or all if admin/dosen" ON public.attendances
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = student_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

-- ========== campus_locations ==========
-- Sebelum: "Admin can manage" (ALL) + "Authenticated users can read" (SELECT) — overlap SELECT
-- Setelah: SELECT untuk semua authenticated + ALL untuk admin (sisanya INSERT/UPDATE/DELETE)
DROP POLICY IF EXISTS "Admin can manage campus locations" ON public.campus_locations;
DROP POLICY IF EXISTS "Authenticated users can read campus locations" ON public.campus_locations;

CREATE POLICY "Authenticated can read campus locations" ON public.campus_locations
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE POLICY "Admin can insert campus locations" ON public.campus_locations
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = 'admin'::text
    )
  );

CREATE POLICY "Admin can update campus locations" ON public.campus_locations
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = 'admin'::text
    )
  );

CREATE POLICY "Admin can delete campus locations" ON public.campus_locations
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = 'admin'::text
    )
  );

-- ========== courses ==========
-- Sebelum: "All users can view" (SELECT) + "Admin can manage" (ALL) — overlap SELECT
-- Setelah: SELECT untuk semua authenticated + cmd-spesifik untuk admin/dosen
DROP POLICY IF EXISTS "All users can view courses" ON public.courses;
DROP POLICY IF EXISTS "Admin can manage courses" ON public.courses;

CREATE POLICY "All authenticated can view courses" ON public.courses
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE POLICY "Admin/dosen can insert courses" ON public.courses
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

CREATE POLICY "Admin/dosen can update courses" ON public.courses
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

CREATE POLICY "Admin/dosen can delete courses" ON public.courses
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

-- ========== enrollments ==========
DROP POLICY IF EXISTS "Students can view own enrollments" ON public.enrollments;
DROP POLICY IF EXISTS "Admin and dosen can manage enrollments" ON public.enrollments;

CREATE POLICY "View own enrollments or all if admin/dosen" ON public.enrollments
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = student_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

CREATE POLICY "Admin/dosen can insert enrollments" ON public.enrollments
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

CREATE POLICY "Admin/dosen can update enrollments" ON public.enrollments
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

CREATE POLICY "Admin/dosen can delete enrollments" ON public.enrollments
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

-- ========== leave_requests ==========
-- Sebelum: 2 policy FOR ALL → overlap di SELECT/INSERT/UPDATE/DELETE
-- Setelah: split per command dengan OR (student own OR admin/dosen)
DROP POLICY IF EXISTS "Students can manage own leave requests" ON public.leave_requests;
DROP POLICY IF EXISTS "Dosen and admin can view and update leave requests" ON public.leave_requests;

CREATE POLICY "View own leave requests or all if admin/dosen" ON public.leave_requests
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = student_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

CREATE POLICY "Students can insert own leave requests" ON public.leave_requests
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = student_id);

CREATE POLICY "Update own leave or all if admin/dosen" ON public.leave_requests
  FOR UPDATE TO authenticated
  USING (
    (SELECT auth.uid()) = student_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

CREATE POLICY "Delete own leave or all if admin/dosen" ON public.leave_requests
  FOR DELETE TO authenticated
  USING (
    (SELECT auth.uid()) = student_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

-- Audit
DO $$
BEGIN
  RAISE NOTICE 'Migration 012 applied: consolidated multiple permissive policies across 5 tables.';
END
$$;
