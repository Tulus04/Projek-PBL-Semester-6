# Implementation Plan: Supabase Realtime — Attendances Channel

## Overview

Convert design + requirements menjadi serangkaian task implementasi terurut. Implementation order:

1. **Migration** — enable publication `supabase_realtime` untuk attendances + REPLICA IDENTITY FULL.
2. **Verifikasi advisor** — security 0 issue baru.
3. **Type definitions** — `app/types/realtime.ts`.
4. **Hook** — `app/lib/realtime/use-realtime-attendances.ts`.
5. **Verification** — type-check + lint.
6. **(Optional) Test page** — minimal page untuk smoke test sebelum Live Monitor (Phase B2) dibuat.
7. **Manual smoke test** — 2 browser windows interaction.

Bahasa: SQL (migration) + TypeScript / TSX (Next.js 14). Setiap task WAJIB lulus verifikasi sebelum ditandai selesai (Requirement 12).

## Tasks

- [x] 0. Migration — Enable Realtime Publication

  - [x] 0.1 Create migration `021_enable_realtime_attendances.sql`
    - File path: `mypresensi-web/supabase/migrations/021_enable_realtime_attendances.sql`
    - Header komentar Bahasa Indonesia: tujuan + spec reference
    - SQL: idempotent ADD TABLE ke publication `supabase_realtime`
    - SQL: explicit `ALTER TABLE public.attendances REPLICA IDENTITY FULL`
    - Pattern idempotent: DO block dengan check `pg_publication_tables`
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [x] 0.2 Apply migration via MCP `mcp0_apply_migration`
    - Migration name (timestamp): `<YYYYMMDDhhmmss>_enable_realtime_attendances`
    - Verify tracked via `mcp0_list_migrations`
    - Verify publication membership via `execute_sql` `SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'attendances'`
    - _Requirements: 1.5_

  - [x] 0.3 Verify advisor security after migration
    - Run `mcp0_get_advisors({ type: 'security' })` → 0 issue baru
    - Run `mcp0_get_advisors({ type: 'performance' })` → no new warning terkait migration ini
    - _Requirements: 1.6, 12.1_

- [x] 1. Type Definitions

  - [x] 1.1 Create `app/types/realtime.ts`
    - File path: `mypresensi-web/app/types/realtime.ts`
    - Header komentar Bahasa Indonesia
    - Export `RealtimeAttendanceRow` interface (16 field match schema attendances)
    - Re-export `RealtimeAttendancePayload = RealtimePostgresChangesPayload<RealtimeAttendanceRow>` dari `@supabase/supabase-js`
    - Export `RealtimeChannelStatus` union type
    - Export `UseRealtimeAttendancesOptions` interface
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 2. Hook `useRealtimeAttendances`

  - [x] 2.1 Create `app/lib/realtime/use-realtime-attendances.ts`
    - File path: `mypresensi-web/app/lib/realtime/use-realtime-attendances.ts`
    - Header komentar Bahasa Indonesia + JSDoc
    - Directive `'use client'` di baris pertama (setelah komentar)
    - Import: `useEffect`, `useRef` dari react; `createClient` dari `@/lib/supabase/client`; types dari `@/types/realtime`
    - Implement per design.md §Components and Interfaces - Component 3 + Algorithm 1:
      - Refs untuk callback (avoid stale closure — Req 8)
      - useEffect dengan dependencies `[sessionId, enabled]` (BUKAN callback identity — Req 8.3)
      - Return early kalau `!enabled || !sessionId`
      - Channel name: `attendances:session=${sessionId}` (Req 3.4)
      - `.on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'attendances', filter: \`session_id=eq.\${sessionId}\` }, ...)` (Req 3.5, 4.1)
      - `.subscribe((status) => onStatusChangeRef.current?.(status))` (Req 7.1, 7.5)
      - Cleanup: `channel.unsubscribe(); supabase.removeChannel(channel)` (Req 5.1, 5.2)
    - JSDoc warning: jangan `console.log(payload)` di consumer (Req 9.3)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 4.1, 4.2, 4.3, 5.1, 5.2, 5.3, 5.4, 5.5, 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.2, 8.3, 9.1, 9.2, 9.3_

- [x] 3. Verification

  - [x] 3.1 Verify type-check + lint
    - cwd: `mypresensi-web/`
    - `npm run type-check` → exit 0
    - `npm run lint` → 0 errors 0 warnings baru
    - Fix issue sebelum mark task complete
    - _Requirements: 12.2, 12.3, 12.4_

  - [x] 3.2 (Optional) Verify build success
    - cwd: `mypresensi-web/`
    - `npm run build` → exit 0
    - Verify hook tidak break build SSR (Server Component) — hook is client-only via `'use client'` directive
    - _Requirements: 12.4_

- [ ] 4. (Optional) Test Page Minimal

  - [ ]* 4.1 Create `app/(dashboard)/realtime-test/page.tsx` for smoke test
    - File path: `mypresensi-web/app/(dashboard)/realtime-test/page.tsx`
    - Server Component dengan `requireRole(['admin', 'dosen'])`
    - Client Component child `<RealtimeTestClient />` yang panggil `useRealtimeAttendances` dengan sessionId dari URL query param `?session=<id>`
    - Render: input field untuk paste sessionId + button "Subscribe" + list events received (timestamp + student_id + status) + status badge channel
    - Optional task — skip kalau Live Monitor (Phase B2) langsung dikerjakan setelahnya. Live Monitor sendiri sudah berfungsi sebagai integration test untuk hook ini.
    - _Requirements: 13.1_

- [ ] 5. Manual Smoke Test

  - [~] 5.1 Smoke test 2-window interaction (user-action)
    - **NOTE**: Task ini dilakukan oleh user manual, BUKAN coding agent.
    - Prerequisite: dev server `npm run dev` running di `mypresensi-web/`. Minimal 1 sesi aktif di salah satu MK.
    - Per Requirement 13.1 acceptance criteria:
      - (a) Buka test page (jika dibuat di task 4.1) atau pakai console browser direct di /sesi: `useRealtimeAttendances` hook bisa di-test pakai snippet manual atau dengan Live Monitor masa depan
      - (b) Login dosen di Window A → ke test page dengan sessionId
      - (c) Verify status badge `SUBSCRIBED` muncul
      - (d) Login mahasiswa di Window B atau mobile emulator → scan QR sesi tsb
      - (e) Verify Window A receive event dalam <2 detik tanpa refresh — list bertambah row dengan student_id + status + scanned_at
      - (f) Tutup Window A → DevTools Network tab WebSocket → verify connection closed
      - (g) Login dosen LAIN di Window C dengan sessionId yang BUKAN MK-nya → verify subscribe tapi tidak terima event (RLS gate kerja)
    - User SHALL document hasil di `dev-log.md` atau `CHANGELOG.md`
    - _Requirements: 13.1, 13.2, 13.3_

## Notes

- Tasks dengan `*` adalah opsional (Test page 4.1 — skip kalau Live Monitor langsung dikerjakan).
- Setiap task reference spesifik `_Requirements: X.Y_` untuk traceability.
- Smoke test (5.1) eksplisit user-action karena Realtime butuh 2 browser windows + mobile emulator interaction yang tidak feasible automated tanpa Playwright/Cypress (out of scope spec ini).
- All implementation MUST follow rules:
  - `02-quality-debugging-verification.md` (verify before claim)
  - `13-web-nextjs-patterns.md` (Server vs Client Component, `'use client'` directive)
  - `14-web-supabase-patterns.md` (RLS, migration via MCP, advisor checks)
  - `04-security-and-privacy.md` (no Tier 1 leak ke log)
  - `03-design-and-libraries.md` (no new deps, reuse @supabase/ssr)
- File yang akan dibuat (3 file baru, 1 optional):
  1. `mypresensi-web/supabase/migrations/021_enable_realtime_attendances.sql`
  2. `mypresensi-web/app/types/realtime.ts`
  3. `mypresensi-web/app/lib/realtime/use-realtime-attendances.ts`
  4. (Optional) `mypresensi-web/app/(dashboard)/realtime-test/page.tsx` + client component
- Tidak ada file existing yang dimodifikasi.
- Tidak ada perubahan API mobile.
- Backward compatible — polling endpoint dari Phase B1 tetap berfungsi (Req 10).
