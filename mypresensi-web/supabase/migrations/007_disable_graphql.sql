-- Migration 007: Disable pg_graphql extension
-- MyPresensi tidak pakai GraphQL (semua via Supabase REST/PostgREST + Server Action).
-- Drop extension untuk eliminasi 12 security advisor warning terkait `graphql_public` schema.
-- Reversible: bisa re-enable via Dashboard > Database > Extensions kalau suatu saat butuh.

-- Drop extension dengan CASCADE untuk hilangkan schema `graphql` & `graphql_public`
DROP EXTENSION IF EXISTS pg_graphql CASCADE;

-- Audit log
DO $$
BEGIN
  RAISE NOTICE 'Migration 007 applied: pg_graphql extension disabled.';
END
$$;
