-- 020_sessions_started_at_index.sql
-- Index DESC pada `sessions.started_at` untuk akselerasi filter rentang
-- waktu (mis. `started_at >= NOW() - INTERVAL '7 days'`).
--
-- Konsumen utama: endpoint baru `GET /api/mobile/sessions/eligible-for-leave`
-- yang dipakai wizard "Ajukan Izin" mobile (Phase 5 Mobile UI Rebuild,
-- step 1 → group "Sedang berlangsung" + "Belum sempat hadir" max 7 hari).
-- Tanpa index ini, query partition aktif/recent jatuh ke Seq Scan di tabel
-- `sessions` yang akan tumbuh seiring semester berjalan.
--
-- Spec referensi: `.kiro/specs/phase-5-mobile-ui-rebuild/`
-- Requirement     : 30.1 (index untuk filter started_at), 30.2 (idempotent
--                   migration via `IF NOT EXISTS`)
-- Rule referensi : `14-web-supabase-patterns.md` Section A (Index Discipline)
--                  & Section G (Migration Idempotency)
--
-- Idempotent: aman dijalankan ulang via `mcp0_apply_migration` — `IF NOT EXISTS`
-- mencegah error "relation already exists". Order DESC dipilih karena query
-- selalu ambil sesi terbaru lebih dulu (`ORDER BY started_at DESC`).
--
-- TIDAK ada perubahan RLS / policy — index murni struktur fisik, tidak
-- mempengaruhi data exposure. Tidak perlu advisor security re-run untuk
-- file ini saja, tapi advisor performance harus tetap dicek (task 0.3)
-- untuk pastikan tidak ada "unused index" warning baru.

CREATE INDEX IF NOT EXISTS idx_sessions_started_at
  ON sessions (started_at DESC);
