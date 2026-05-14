-- Migration 011: RLS Auth Initialization Plan Optimization
-- Ganti `auth.uid()` direct → `(SELECT auth.uid())` di semua RLS policy.
-- Postgres akan evaluate (SELECT ...) sekali per query, bukan per row.
-- Berdasarkan Supabase advisor `auth_rls_initplan` (WARN, performance).
--
-- Behavior IDENTIK, hanya optimisasi query plan untuk skala besar.
-- Reference: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

-- ========== attendances ==========
DROP POLICY IF EXISTS "Students can view own attendance" ON public.attendances;
CREATE POLICY "Students can view own attendance" ON public.attendances
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = student_id);

DROP POLICY IF EXISTS "Students can insert own attendance" ON public.attendances;
CREATE POLICY "Students can insert own attendance" ON public.attendances
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = student_id);

DROP POLICY IF EXISTS "Dosen and admin can view all attendances" ON public.attendances;
CREATE POLICY "Dosen and admin can view all attendances" ON public.attendances
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

-- ========== audit_logs ==========
DROP POLICY IF EXISTS "Admin can view audit logs" ON public.audit_logs;
CREATE POLICY "Admin can view audit logs" ON public.audit_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = 'admin'::text
    )
  );

-- ========== campus_locations ==========
DROP POLICY IF EXISTS "Admin can manage campus locations" ON public.campus_locations;
CREATE POLICY "Admin can manage campus locations" ON public.campus_locations
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = 'admin'::text
    )
  );

-- ========== courses ==========
DROP POLICY IF EXISTS "All users can view courses" ON public.courses;
CREATE POLICY "All users can view courses" ON public.courses
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Admin can manage courses" ON public.courses;
CREATE POLICY "Admin can manage courses" ON public.courses
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

-- ========== enrollments ==========
DROP POLICY IF EXISTS "Students can view own enrollments" ON public.enrollments;
CREATE POLICY "Students can view own enrollments" ON public.enrollments
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = student_id);

DROP POLICY IF EXISTS "Admin and dosen can manage enrollments" ON public.enrollments;
CREATE POLICY "Admin and dosen can manage enrollments" ON public.enrollments
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

-- ========== face_embeddings ==========
DROP POLICY IF EXISTS "Users can manage own face embedding" ON public.face_embeddings;
CREATE POLICY "Users can manage own face embedding" ON public.face_embeddings
  FOR ALL TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ========== leave_requests ==========
DROP POLICY IF EXISTS "Students can manage own leave requests" ON public.leave_requests;
CREATE POLICY "Students can manage own leave requests" ON public.leave_requests
  FOR ALL TO authenticated
  USING ((SELECT auth.uid()) = student_id);

DROP POLICY IF EXISTS "Dosen and admin can view and update leave requests" ON public.leave_requests;
CREATE POLICY "Dosen and admin can view and update leave requests" ON public.leave_requests
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = ANY (ARRAY['admin'::text, 'dosen'::text])
    )
  );

-- ========== notifications ==========
-- DROP policy redundant: service_role bypass RLS otomatis, tidak perlu policy explicit.
DROP POLICY IF EXISTS "Service role can manage all notifications" ON public.notifications;

DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Users can read own notifications" ON public.notifications
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ========== profiles ==========
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admin can view all profiles" ON public.profiles;
-- Merge ke 1 policy SELECT untuk hilangkan multiple_permissive_policies warning
CREATE POLICY "View own or all if admin" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    (SELECT auth.uid()) = id
    OR EXISTS (
      SELECT 1 FROM public.profiles p2
      WHERE p2.id = (SELECT auth.uid())
        AND p2.role = 'admin'::text
    )
  );

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id);

-- ========== sessions ==========
DROP POLICY IF EXISTS "Authenticated users can view sessions" ON public.sessions;
DROP POLICY IF EXISTS "Dosen can manage own sessions" ON public.sessions;
-- Re-create dengan command-spesifik untuk hilangkan multiple permissive
CREATE POLICY "Authenticated users can view sessions" ON public.sessions
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE POLICY "Dosen can insert own sessions" ON public.sessions
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = dosen_id);

CREATE POLICY "Dosen can update own sessions" ON public.sessions
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = dosen_id);

CREATE POLICY "Dosen can delete own sessions" ON public.sessions
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = dosen_id);

-- ========== settings ==========
DROP POLICY IF EXISTS "Admin can manage settings" ON public.settings;
CREATE POLICY "Admin can manage settings" ON public.settings
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
        AND profiles.role = 'admin'::text
    )
  );

-- Audit
DO $$
BEGIN
  RAISE NOTICE 'Migration 011 applied: RLS auth.uid() refactored to (SELECT auth.uid()) + profiles SELECT merged + sessions cmd-split.';
END
$$;
