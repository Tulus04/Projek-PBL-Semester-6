-- 018_revoke_at_risk_function_public.sql
-- Cabut akses function get_at_risk_students dari role anon + authenticated.
-- Function ini SECURITY DEFINER dengan akses lintas tabel sensitif (profiles, attendances)
-- — hanya boleh dipanggil dari service_role setelah requireRole admin/dosen di Server Action.
--
-- Background: Migration 015 sebelumnya GRANT EXECUTE ke authenticated, tapi caller di kode
-- (app/lib/actions/at-risk.ts + app/lib/ai/tools.ts) semuanya pakai createAdminClient()
-- (service_role). Grant ke authenticated tidak pernah dipakai dan justru memperluas attack
-- surface — anon/authenticated bisa hit /rest/v1/rpc/get_at_risk_students dan dapat data
-- mahasiswa Tier 2 PII (full_name, NIM, persentase kehadiran).
--
-- Supabase advisor flag yang ditutup migration ini:
--   anon_security_definer_function_executable (WARN)
--   authenticated_security_definer_function_executable (WARN)
--
-- Sesuai rule:
--   .kiro/steering/04-security-and-privacy.md Section A (Tier 2 PII RLS strict per-row)
--   .kiro/steering/14-web-supabase-patterns.md Section B (RLS pakai auth.uid, function SD
--     dengan search_path explicit, defense-in-depth 3 layer)
--
-- Applied via MCP apply_migration sebagai version 20260516170810_revoke_at_risk_function_public.
-- File lokal pakai sequential 018 untuk readability di repo.

BEGIN;

-- 1. Revoke total dari anon + authenticated + PUBLIC (idempotent)
REVOKE ALL ON FUNCTION public.get_at_risk_students(numeric, int, int, uuid)
  FROM PUBLIC, anon, authenticated;

-- 2. Re-affirm service_role akses (caller via createAdminClient).
--    postgres tetap punya akses default sebagai owner.
GRANT EXECUTE ON FUNCTION public.get_at_risk_students(numeric, int, int, uuid)
  TO service_role;

COMMIT;
