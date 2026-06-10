-- 024_qr_gating_tokens.sql
-- Create table to store short-lived tokens for QR gating mechanism

CREATE TABLE public.attendance_qr_tokens (
    token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '1 minute'),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.attendance_qr_tokens ENABLE ROW LEVEL SECURITY;

-- Student can only read/insert their own tokens
CREATE POLICY "Students can manage their own QR tokens" ON public.attendance_qr_tokens
    FOR ALL
    TO authenticated
    USING ((SELECT auth.uid()) = student_id)
    WITH CHECK ((SELECT auth.uid()) = student_id);

-- Create index for quick lookup and pruning
CREATE INDEX idx_attendance_qr_tokens_session_student ON public.attendance_qr_tokens(session_id, student_id);
CREATE INDEX idx_attendance_qr_tokens_expires_at ON public.attendance_qr_tokens(expires_at);
