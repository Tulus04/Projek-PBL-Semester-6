-- ============================================
-- Migration: 002_notifications
-- Tabel notifikasi in-app untuk MyPresensi.
-- Setiap user memiliki daftar notifikasi sendiri.
-- ============================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info',          -- 'info' | 'success' | 'warning' | 'danger'
  href TEXT,                                   -- Link navigasi saat diklik (opsional)
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index untuk query efisien per user
CREATE INDEX idx_notifications_user_id ON notifications(user_id);

-- Partial index: hanya unread, untuk badge counter
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

-- RLS: user hanya bisa akses notifikasi miliknya sendiri
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Service role (server actions) bisa insert notifikasi untuk siapapun
CREATE POLICY "Service role can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Service role can manage all notifications"
  ON notifications FOR ALL
  USING (auth.role() = 'service_role');
