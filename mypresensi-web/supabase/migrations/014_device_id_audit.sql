-- Migration 014: Device ID untuk Rate Limit & Audit Forensic
--
-- Konteks: Sejak T2-#5 (rate limit per-device), mobile app inject header
-- `X-Device-Id` ke setiap request via Dio interceptor. Backend membaca
-- header ini di endpoint `/api/mobile/*` untuk:
--   1. Composite key rate limit `userId:deviceId` (in-memory) → 1 device
--      bermasalah tidak block device lain dari user yang sama.
--   2. Audit forensic — track device asal request via `audit_logs.details->>'device_id'`.
--
-- Migration ini:
--   - Tambah kolom `device_id` di `rate_limit_log` untuk future use (kalau migrasi
--     dari in-memory ke DB-backed window query). Saat ini in-memory cukup.
--   - Tambah BTREE expression index pada `audit_logs((details->>'device_id'))` untuk
--     query forensic cepat: "tampilkan semua request dari device X".
--
-- Idempotent: pakai IF NOT EXISTS, aman dijalankan ulang.

-- ============================================================
-- 1. rate_limit_log.device_id (future-proof; saat ini in-memory)
-- ============================================================
ALTER TABLE public.rate_limit_log
  ADD COLUMN IF NOT EXISTS device_id TEXT;

COMMENT ON COLUMN public.rate_limit_log.device_id IS
  'Device ID dari header X-Device-Id (mobile). Future-proof untuk DB-backed rate limiting; saat ini rate limit pakai in-memory map di Next.js Route Handler.';

-- Index opsional untuk query gabungan (user_id, device_id, requested_at)
-- Skip dulu untuk hemat storage; tambah saat migrasi DB-backed.

-- ============================================================
-- 2. Forensic index untuk query audit_logs by device_id
-- ============================================================
-- Query target: `SELECT * FROM audit_logs WHERE details->>'device_id' = '...'`
-- Tanpa index, full scan. Dengan BTREE expression, log-N lookup.
-- Filter WHERE device_id IS NOT NULL untuk hemat ukuran (banyak entry tidak punya device_id).
CREATE INDEX IF NOT EXISTS idx_audit_logs_device_id
  ON public.audit_logs ((details->>'device_id'))
  WHERE details->>'device_id' IS NOT NULL;

COMMENT ON INDEX public.idx_audit_logs_device_id IS
  'Partial expression index untuk query forensic by device_id di JSONB details. Dipakai admin saat investigasi insiden (e.g. "audit semua request dari device curian").';

-- ============================================================
-- 3. Audit notice
-- ============================================================
DO $$
BEGIN
  RAISE NOTICE 'Migration 014 applied: device_id column on rate_limit_log + forensic index on audit_logs.';
END
$$;
