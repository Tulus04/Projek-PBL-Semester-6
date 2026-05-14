-- Migration 009: Rate Limit Log Explicit Deny Policy
-- Table `public.rate_limit_log` dipakai oleh middleware via service_role untuk track
-- rate limiting (login attempts, dll). Service_role bypass RLS, jadi kerja normal.
-- 
-- Sebelumnya: RLS enabled tapi 0 policy. Default = deny untuk authenticated/anon.
-- Behavior tetap aman, TAPI Supabase advisor flag sebagai INFO (potensial dev forget).
-- 
-- Solusi: tambah explicit deny policy sebagai dokumentasi intent (no-op behavior wise).

CREATE POLICY "Deny all client access (service_role only)"
ON public.rate_limit_log
FOR ALL
TO authenticated, anon
USING (false)
WITH CHECK (false);

-- Audit
DO $$
BEGIN
  RAISE NOTICE 'Migration 009 applied: explicit deny policy on rate_limit_log for client roles.';
END
$$;
