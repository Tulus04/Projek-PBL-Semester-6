-- mypresensi-web/supabase/migrations/006_security_hardening.sql
-- Security hardening berdasarkan Supabase Database Advisor (mcp_get_advisors).
--
-- Fixes:
-- 1. function_search_path_mutable — set search_path eksplisit di SECURITY DEFINER
--    & trigger functions untuk mencegah SQL injection via search_path manipulation.
-- 2. rls_policy_always_true — drop policy "always true" yang membolehkan anon
--    role flood/spam INSERT ke audit_logs & notifications.
-- 3. anon_security_definer_function_executable — revoke EXECUTE dari `anon` &
--    `authenticated` untuk handle_new_user (dipanggil hanya oleh trigger
--    auth.users INSERT, bukan via REST RPC).
-- 4. pg_graphql_anon_table_exposed — revoke SELECT dari `anon` untuk tabel
--    privat. Web app tidak fetch via anon (semua via authenticated session
--    atau service_role server-side). Mobile pakai service_role server-side.
--
-- Yang TIDAK di-touch:
-- - rls_auto_enable: sudah aman (search_path=pg_catalog set).
-- - campus_locations: SELECT FOR authenticated WITH CHECK true intentional.
-- - rate_limit_log: rls_enabled_no_policy OK karena hanya service_role akses.

-- ============================================================
-- 1. Fix function_search_path_mutable
-- ============================================================

-- handle_new_user: trigger SECURITY DEFINER yang auto-create row di public.profiles
-- saat user baru di auth.users. Tanpa search_path eksplisit, attacker bisa create
-- function dengan nama sama di schema lain & hijack execution.
ALTER FUNCTION public.handle_new_user() SET search_path = public, pg_temp;

-- update_updated_at_column: trigger biasa untuk update kolom updated_at otomatis.
ALTER FUNCTION public.update_updated_at_column() SET search_path = public, pg_temp;

-- ============================================================
-- 2. Hapus RLS policy yang permissive
-- ============================================================

-- audit_logs: policy "System can insert audit logs" pakai role `public`
-- (artinya anon + authenticated + service_role) WITH CHECK (true).
-- Berbahaya: anon (browser tanpa login) bisa flood audit_logs.
-- Solusi: drop policy. service_role tetap bisa INSERT karena bypass RLS by default.
-- Server-side audit logging (auditLog() di lib/audit.ts) pakai createAdminClient
-- → service_role → tetap berfungsi.
DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_logs;

-- notifications: sama persis pattern-nya.
-- Server-side notification insertion (di server actions) pakai service_role.
DROP POLICY IF EXISTS "Service role can insert notifications" ON public.notifications;

-- ============================================================
-- 3. Revoke EXECUTE dari security definer functions
-- ============================================================

-- handle_new_user dipanggil oleh trigger AFTER INSERT ON auth.users — tidak pernah
-- via REST/RPC. Revoke EXECUTE dari anon & authenticated mencegah eksekusi
-- via /rest/v1/rpc/handle_new_user.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;

-- rls_auto_enable adalah event_trigger (DDL), tidak callable via REST,
-- tapi advisor tetap warn. Defense in depth.
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM anon;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC;

-- ============================================================
-- 4. Revoke SELECT dari anon untuk tabel privat
-- ============================================================
-- MyPresensi tidak pakai supabase-js di client browser untuk SELECT data tabel.
-- - Web (Next.js): SSR via createServerClient (cookie auth → role authenticated)
--   atau createAdminClient server-side (role service_role).
-- - Mobile: API endpoint /api/mobile/* dengan service_role.
-- - Public pages (login, forgot-password): hanya call auth.signInWithPassword
--   yang TIDAK butuh SELECT row tabel.
--
-- Jadi anon SELECT bisa di-revoke tanpa breaking apapun.
-- Tabel campus_locations & courses TETAP punya SELECT dari authenticated
-- (untuk dropdown pilih kampus/MK), jadi tetap berfungsi.

REVOKE SELECT ON public.attendances FROM anon;
REVOKE SELECT ON public.audit_logs FROM anon;
REVOKE SELECT ON public.campus_locations FROM anon;
REVOKE SELECT ON public.courses FROM anon;
REVOKE SELECT ON public.enrollments FROM anon;
REVOKE SELECT ON public.face_embeddings FROM anon;
REVOKE SELECT ON public.leave_requests FROM anon;
REVOKE SELECT ON public.notifications FROM anon;
REVOKE SELECT ON public.profiles FROM anon;
REVOKE SELECT ON public.rate_limit_log FROM anon;
REVOKE SELECT ON public.sessions FROM anon;
REVOKE SELECT ON public.settings FROM anon;

-- Catatan: ini tidak mempengaruhi role `authenticated` & `service_role`.
-- RLS policies untuk authenticated tetap aktif & gating per-row.

-- ============================================================
-- Verifikasi (opsional — uncomment untuk debug)
-- ============================================================
-- SELECT proname, proconfig FROM pg_proc
-- WHERE proname IN ('handle_new_user','update_updated_at_column','rls_auto_enable');
--
-- SELECT * FROM pg_policies WHERE schemaname='public' AND with_check='true';
--
-- SELECT grantee, privilege_type, table_name FROM information_schema.role_table_grants
-- WHERE table_schema='public' AND grantee='anon';
