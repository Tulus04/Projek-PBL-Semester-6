-- supabase/migrations/023_profiles_fcm_token.sql
-- Tambah kolom FCM token ke profiles untuk push notification (FCM).
-- Catatan keamanan: fcm_token = data per-device, hanya di-update via service_role
-- (endpoint mobile setelah auth). TIDAK pernah di-return ke endpoint mobile lain.
-- Idempotent: aman dijalankan ulang.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS fcm_token TEXT NULL,
  ADD COLUMN IF NOT EXISTS fcm_token_updated_at TIMESTAMPTZ NULL;

-- Partial index: hanya baris yang punya token (untuk query batch push cepat).
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token
  ON public.profiles (id)
  WHERE fcm_token IS NOT NULL;

COMMENT ON COLUMN public.profiles.fcm_token IS
  'FCM device token untuk push notification. Null kalau permission ditolak atau belum login. Hanya di-update via service_role.';
COMMENT ON COLUMN public.profiles.fcm_token_updated_at IS
  'Timestamp terakhir fcm_token di-update (saat login/refresh token).';
