-- 022_rolling_qr_seed.sql
-- Phase 3 v7: Rolling QR TOTP-like — tambah kolom seed per-session.
--
-- Konteks: Layer 1 dari 3-layer security MyPresensi (QR · GPS · Face).
-- Ganti static QR 3-menit dengan TOTP-like (HMAC-SHA1 + window 30s + tolerance ±1)
-- untuk anti-share screenshot via WhatsApp ke teman di kos.
--
-- Perubahan: PURELY ADDITIVE.
--   1. ADD COLUMN `sessions.session_code_seed TEXT NULL`
--      → Hex 32-byte (64 char) random secret per-session. Server-side only.
--      → NULL untuk row existing pre-migration (legacy session) — submit endpoint
--        akan fallback ke static equality check (kompatibilitas penuh).
--      → Non-null setelah `toggleSessionAction` / `refreshSessionCode` di Phase 3.
--   2. CREATE INDEX partial `idx_sessions_active_with_seed`
--      → Akselerasi query "active rolling sessions" oleh admin endpoint polling
--        `GET /api/admin/sessions/:id/current-code` (interval 5 detik dari web display).
--
-- TIDAK mengubah kolom existing `session_code` atau `session_code_expires_at` —
-- keduanya tetap dipakai (cache code current + placeholder TTL 24 jam saat rolling).
--
-- Spec referensi: `.kiro/specs/rolling-qr-totp/`
-- Requirement     : 1.1, 1.2, 1.3, 1.4, 1.5, 1.8, 14.1, 14.4
-- Design ref      : Component 1 (Migration `020_rolling_qr_seed.sql`) — file lokal
--                   pakai nomor 022 karena 020 dan 021 sudah dipakai migration lain.
-- Rule referensi  : `14-web-supabase-patterns.md` Section A (Index Discipline) +
--                   Section G (Migration Idempotency)
--
-- Sensitivity: `session_code_seed` = Tier 1 secret (per data classification rule 04).
--   - JANGAN expose di response endpoint mana pun (`/api/mobile/*`, `/api/admin/*`).
--   - JANGAN log via console.log / debugPrint / logAudit.
--   - RLS sessions table policy existing (migration 011 + 012) sudah deny role
--     `anon` dan `authenticated` cookie — kolom baru otomatis ikut policy itu,
--     tidak perlu policy tambahan.
--
-- Idempotent: aman dijalankan ulang via `mcp0_apply_migration` — `IF NOT EXISTS`
-- mencegah error "column already exists" / "relation already exists".
--
-- Rollback (kalau full revert dibutuhkan):
--   ALTER TABLE public.sessions DROP COLUMN IF EXISTS session_code_seed;
--   DROP INDEX IF EXISTS public.idx_sessions_active_with_seed;

ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS session_code_seed TEXT NULL;

COMMENT ON COLUMN public.sessions.session_code_seed IS
  'Hex 32-byte (64 char) secret seed untuk TOTP-like rolling QR (Phase 3 v7). '
  'Server-side only — JANGAN expose ke client (mobile, web display, audit log details). '
  'NULL = legacy session (static code fallback). Non-null = rolling mode aktif.';

-- Partial index untuk query "active rolling sessions".
-- Konsumen utama: admin endpoint polling current-code dan future audit/forensic query
-- yang scan rolling sessions aktif. Filter (seed IS NOT NULL AND is_active = true)
-- memastikan index kecil — hanya cover sesi yang sedang ber-roll.
CREATE INDEX IF NOT EXISTS idx_sessions_active_with_seed
  ON public.sessions (id)
  WHERE session_code_seed IS NOT NULL AND is_active = true;
