-- Migration 010: Foreign Key Indexes
-- Tambah covering index untuk FK yang belum punya — improve query JOIN performance.
-- Berdasarkan Supabase performance advisor `unindexed_foreign_keys` (INFO).

-- audit_logs.user_id
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs (user_id);

-- courses.dosen_id
CREATE INDEX IF NOT EXISTS idx_courses_dosen_id ON public.courses (dosen_id);

-- leave_requests.reviewed_by
CREATE INDEX IF NOT EXISTS idx_leave_requests_reviewed_by ON public.leave_requests (reviewed_by);

-- leave_requests.session_id
CREATE INDEX IF NOT EXISTS idx_leave_requests_session_id ON public.leave_requests (session_id);

-- rate_limit_log.user_id
CREATE INDEX IF NOT EXISTS idx_rate_limit_log_user_id ON public.rate_limit_log (user_id);

-- sessions.dosen_id
CREATE INDEX IF NOT EXISTS idx_sessions_dosen_id ON public.sessions (dosen_id);

-- Audit
DO $$
BEGIN
  RAISE NOTICE 'Migration 010 applied: 6 FK indexes added.';
END
$$;
