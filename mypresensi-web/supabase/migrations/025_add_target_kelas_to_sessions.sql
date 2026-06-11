-- Migration: Add target_kelas to sessions

ALTER TABLE sessions
ADD COLUMN target_kelas VARCHAR(50) NULL;

-- Index for performance when filtering sessions by target_kelas
CREATE INDEX IF NOT EXISTS idx_sessions_target_kelas ON sessions(target_kelas);
