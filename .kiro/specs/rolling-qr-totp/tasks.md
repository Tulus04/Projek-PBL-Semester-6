# Implementation Plan: Rolling QR TOTP-like (Phase 3 v7)

## Overview

DAG implementation order untuk Phase 3 — ganti static QR 3-menit dengan TOTP-like rolling QR. Backward-compat additive — sessions lama dengan `session_code_seed = NULL` tetap pakai static check, sessions baru (post-deploy) auto-rolling.

**Effort**: 4-6 jam realistis (pessimistic).

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "name": "Foundation (parallel)",
      "tasks": ["1.1", "2.1"],
      "depends_on": []
    },
    {
      "wave": 2,
      "name": "Apply migration + property test",
      "tasks": ["1.2", "2.2"],
      "depends_on": ["1.1", "2.1"]
    },
    {
      "wave": 3,
      "name": "Security advisor verification",
      "tasks": ["1.3"],
      "depends_on": ["1.2"]
    },
    {
      "wave": 4,
      "name": "Backend code (parallel) — needs migration + utility",
      "tasks": ["3.1", "4.1", "5.1", "5.2"],
      "depends_on": ["1.2", "2.1"]
    },
    {
      "wave": 5,
      "name": "Web client polling — needs admin endpoint",
      "tasks": ["6.1", "7.1"],
      "depends_on": ["4.1"]
    },
    {
      "wave": 6,
      "name": "Verify backend + utility tests",
      "tasks": ["8.1", "8.2"],
      "depends_on": ["3.1", "4.1", "5.1", "5.2", "2.2"]
    },
    {
      "wave": 7,
      "name": "Verify web + production build",
      "tasks": ["9.1", "9.2"],
      "depends_on": ["6.1", "7.1", "8.1"]
    },
    {
      "wave": 8,
      "name": "Manual smoke test (USER-ACTION)",
      "tasks": ["10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7"],
      "depends_on": ["9.2"]
    },
    {
      "wave": 9,
      "name": "Document smoke result",
      "tasks": ["10.8"],
      "depends_on": ["10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7"]
    },
    {
      "wave": 10,
      "name": "Documentation update",
      "tasks": ["11.1", "11.2"],
      "depends_on": ["10.8"]
    }
  ]
}
```

| ID | Task | Depends on |
|----|------|------------|
| 1.1 | Create migration file 022 | – |
| 1.2 | Apply migration via MCP | 1.1 |
| 1.3 | Run security advisor | 1.2 |
| 2.1 | Create totp.ts utility | – |
| 2.2 | Property test totp.test.ts | 2.1 |
| 3.1 | Refactor submit Layer 2 | 1.2, 2.1 |
| 4.1 | Create admin current-code endpoint | 1.2, 2.1 |
| 5.1 | Update toggleSessionAction | 1.2, 2.1 |
| 5.2 | Update refreshSessionCode | 1.2, 2.1 |
| 6.1 | Refactor qr-display-client polling | 4.1 |
| 7.1 | Refactor session-list modal polling | 4.1 |
| 8.1 | Verify backend type-check + lint | 3.1, 4.1, 5.1, 5.2 |
| 8.2 | Run TOTP property test | 2.2 |
| 9.1 | Verify web type-check + lint | 6.1, 7.1 |
| 9.2 | Build production | 8.1, 9.1 |
| 10.1-10.7 | Manual smoke test (USER) | 9.2 |
| 10.8 | Document smoke result | 10.1-10.7 |
| 11.1 | Update CHANGELOG | 10.8 |
| 11.2 | Update implementation_plan status | 10.8 |

**Files baru** (3):
1. `mypresensi-web/supabase/migrations/022_rolling_qr_seed.sql`
2. `mypresensi-web/app/lib/utils/totp.ts`
3. `mypresensi-web/app/lib/utils/totp.test.ts`
4. `mypresensi-web/app/api/admin/sessions/[id]/current-code/route.ts`

**Files modified** (3):
1. `mypresensi-web/app/api/mobile/attendance/submit/route.ts`
2. `mypresensi-web/app/lib/actions/sessions.ts`
3. `mypresensi-web/app/(qr-projector)/sesi/[id]/qr/qr-display-client.tsx`
4. `mypresensi-web/app/(dashboard)/sesi/session-list.tsx`

**Files NOT modified**:
- `mypresensi-mobile/**` — no change, backward compat di server saja.

## Tasks

- [x] 1. Database Migration

  - [x] 1.1 Create migration file `022_rolling_qr_seed.sql`
    - **id**: `1.1`
    - **text**: Tulis SQL migration tambah kolom `sessions.session_code_seed TEXT NULL` + partial index + COMMENT Bahasa Indonesia. Idempotent guard. File lokal pakai `022_` karena 020/021 sudah dipakai migration lain.
    - **requirements**: 1.1, 1.2, 1.3, 1.4, 1.5, 1.8
    - **dependencies**: -
    - File path: `mypresensi-web/supabase/migrations/022_rolling_qr_seed.sql`

  - [x] 1.2 Apply migration via Supabase MCP
    - **id**: `1.2`
    - **text**: Jalankan `mcp0_apply_migration` dengan SQL dari file migration untuk track di Supabase history. Verifikasi via `mcp0_list_migrations` dan `mcp0_execute_sql` cek `information_schema.columns` ada `session_code_seed`.
    - **requirements**: 1.6
    - **dependencies**: 1.1

  - [x] 1.3 Run security advisor check
    - **id**: `1.3`
    - **text**: `mcp0_get_advisors({ project_id, type: 'security' })` — pastikan 0 issue baru terkait kolom seed atau RLS policy session.
    - **requirements**: 1.7, 18.1
    - **dependencies**: 1.2

- [x] 2. TOTP Utility

  - [x] 2.1 Create `app/lib/utils/totp.ts`
    - **id**: `2.1`
    - **text**: Implement `generateCode(seedHex, window)`, `getCurrentWindow(nowMs?)`, `verifyWithTolerance(seedHex, inputCode, currentWindow, tolerance=1)`, `msUntilNextWindow(nowMs?)`. Pakai Node.js `crypto.createHmac` dan `crypto.timingSafeEqual`. Konstanta module-level `WINDOW_SIZE_MS=30_000`, `DIGIT_COUNT=6`, `TOLERANCE_DEFAULT=1`. Header file Bahasa Indonesia.
    - **requirements**: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 16.5
    - **dependencies**: -
    - File path: `mypresensi-web/app/lib/utils/totp.ts`

  - [ ]* 2.2 Property test TOTP utility
    - **id**: `2.2`
    - **text**: Tulis test suite `totp.test.ts` cover determinisme, round-trip, tolerance accept (offset -1, 0, +1), tolerance reject (offset > tolerance), input malformed (length salah, non-digit), seed-isolation. Run `npm test -- totp` exit 0.
    - **requirements**: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8
    - **dependencies**: 2.1
    - File path: `mypresensi-web/app/lib/utils/totp.test.ts`

- [x] 3. Backend Submit Refactor

  - [x] 3.1 Refactor Layer 2 verifikasi di `submit/route.ts`
    - **id**: `3.1`
    - **text**: Branch by `session.session_code_seed`. Kalau non-null → `verifyWithTolerance` + audit `qr_code_invalid_attempt` saat reject + capture `qr_window_offset`. Kalau null → static equality + expiry check existing. Tambah `qr_verify_method` + `qr_window_offset` ke audit details `mobile_attendance_submit`. JANGAN sentuh Layer 3-6 (enrollment, duplicate, GPS, face). Pesan error Bahasa Indonesia ramah ("Kode QR sudah lewat, mohon scan ulang.").
    - **requirements**: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11, 11.1, 11.2, 12.1, 13.1, 13.2, 13.3, 14.1, 15.1, 15.2, 15.3, 15.6, 17.1, 17.2, 17.3
    - **dependencies**: 1.2, 2.1
    - File path: `mypresensi-web/app/api/mobile/attendance/submit/route.ts`

- [x] 4. Backend Admin Endpoint

  - [x] 4.1 Create `GET /api/admin/sessions/[id]/current-code/route.ts`
    - **id**: `4.1`
    - **text**: Cookie auth via `requireRole(['admin','dosen'])` + `canAccessCourse` ownership check. Branch rolling vs legacy. Return body `{current_code, window, ttl_ms_until_next, is_rolling, is_active, expires_at}`. Set `Cache-Control: no-store`. Update `sessions.session_code` cache. JANGAN expose seed. Handle 401/403/404/410. Header file Bahasa Indonesia.
    - **requirements**: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10, 5.11, 5.12, 5.13, 14.2, 16.1, 16.3, 17.4
    - **dependencies**: 1.2, 2.1
    - File path: `mypresensi-web/app/api/admin/sessions/[id]/current-code/route.ts`

- [x] 5. Backend Server Actions

  - [x] 5.1 Update `toggleSessionAction` — generate seed + initial code
    - **id**: `5.1`
    - **text**: Saat `isActive=true`, generate seed via `crypto.randomBytes(32).toString('hex')`, compute initial code, UPDATE `session_code_seed` + `session_code` + `session_code_expires_at = NOW() + 24h` + `started_at` + `is_active`. Audit log `start_session` dengan `has_seed: true`, `qr_mode: 'rolling'`, `code_length: 6` (TIDAK boleh log seed/code mentah). Return value tetap `{ error, sessionCode, expiresAt }` kompatibel UI.
    - **requirements**: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 16.2
    - **dependencies**: 1.2, 2.1
    - File path: `mypresensi-web/app/lib/actions/sessions.ts`

  - [x] 5.2 Update `refreshSessionCode` — rotate seed
    - **id**: `5.2`
    - **text**: Generate seed BARU (rotate, bukan reuse), compute new code, UPDATE seed + code + `expires_at = NOW() + 24h`. Validate `is_active = true` + ownership. Audit log `refresh_session_code` dengan `has_seed: true`, `rotated: true`. Return tetap kompatibel.
    - **requirements**: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 16.2
    - **dependencies**: 1.2, 2.1
    - File path: `mypresensi-web/app/lib/actions/sessions.ts`

- [x] 6. Web QR Projector Refactor

  - [x] 6.1 Add polling `current-code` di `qr-display-client.tsx`
    - **id**: `6.1`
    - **text**: Tambah state `currentCode: string | null` + `windowTtlMs: number` initialized dari prop. Tambah polling loop kedua (paralel dengan `live-stats` polling) ke `/api/admin/sessions/:id/current-code` interval 5000ms. AbortController cleanup saat unmount. Update state saat response 200 (rolling vs legacy fallback). Handle 410 → banner + auto-close. Backoff 30s setelah 3x error consecutive. QR `value` derive dari `currentCode` state. OtpBlock countdown derive dari `windowTtlMs`. ExpiredOverlay HANYA untuk legacy session expired — JANGAN tampil untuk rolling.
    - **requirements**: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 8.10, 8.11, 8.12
    - **dependencies**: 4.1
    - File path: `mypresensi-web/app/(qr-projector)/sesi/[id]/qr/qr-display-client.tsx`

- [x] 7. Web Session-list Modal Refactor

  - [x] 7.1 Add polling `current-code` di session-list modal QR
    - **id**: `7.1`
    - **text**: Tambah state `modalCurrentCodes: Record<sessionId, {code, ttl}>`. Polling per active session yang punya `session_code_seed != null` interval 5000ms ke `/api/admin/sessions/:id/current-code`. AbortController cleanup saat modal close / session switch. QR + OTP digit display + countdown derive dari state. Fallback ke `session.session_code` prop kalau polling belum sukses pertama kali. Polling SKIP untuk legacy session (seed null) — tetap pakai static value.
    - **requirements**: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 14.3
    - **dependencies**: 4.1
    - File path: `mypresensi-web/app/(dashboard)/sesi/session-list.tsx`

- [ ] 8. Verify Backend

  - [x] 8.1 Type-check + lint backend
    - **id**: `8.1`
    - **text**: `cd mypresensi-web && npm run type-check && npm run lint`. Expected exit 0 + 0 error.
    - **requirements**: 18.2, 18.3
    - **dependencies**: 3.1, 4.1, 5.1, 5.2

  - [~] 8.2 Run TOTP property test
    - **id**: `8.2`
    - **text**: `cd mypresensi-web && npm test -- totp`. Expected exit 0 — semua property test pass.
    - **requirements**: 18.4
    - **dependencies**: 2.2

- [x] 9. Verify Web

  - [x] 9.1 Type-check + lint web
    - **id**: `9.1`
    - **text**: `cd mypresensi-web && npm run type-check && npm run lint` (sudah include web changes). Expected exit 0 + 0 error.
    - **requirements**: 18.2, 18.3
    - **dependencies**: 6.1, 7.1

  - [x] 9.2 Build production
    - **id**: `9.2`
    - **text**: `cd mypresensi-web && npm run build`. Expected exit 0 — bukti runtime safety pre-merge.
    - **requirements**: 18.5
    - **dependencies**: 9.1, 8.1

- [ ] 10. Smoke Test (USER-ACTION manual)

  - [~] 10.1 Test happy-path start session rolling
    - **id**: `10.1`
    - **text**: User login dosen → buat sesi baru → klik "Mulai Sesi". Verifikasi DB via SQL: `SELECT session_code, session_code_seed, session_code_expires_at, is_active FROM sessions WHERE id=...` — seed non-null 64-char hex, code 6-digit, expires_at ~24h ahead, is_active true.
    - **requirements**: 6.1-6.7
    - **dependencies**: 9.2

  - [~] 10.2 Test web display polling
    - **id**: `10.2`
    - **text**: User buka `/sesi/[id]/qr` (fullscreen projector) atau modal QR di `/sesi`. Buka DevTools Network → confirm polling GET `/api/admin/sessions/:id/current-code` setiap 5s. QR + OTP digit update otomatis tiap ~30 detik (window roll). Countdown bar OtpBlock turun 30→0→reset.
    - **requirements**: 8.1-8.12, 9.1-9.9
    - **dependencies**: 9.2

  - [~] 10.3 Test submit happy path
    - **id**: `10.3`
    - **text**: HP mahasiswa scan QR aktif → submit presensi. Server return 201. Cek `audit_logs` — entry `mobile_attendance_submit` dengan `details.qr_verify_method = 'totp'` dan `qr_window_offset = 0`.
    - **requirements**: 4.2, 4.3, 4.9, 15.1
    - **dependencies**: 9.2

  - [~] 10.4 Test screenshot expire (THREAT — PRIMARY)
    - **id**: `10.4`
    - **text**: User screenshot QR layar. Tunggu 90+ detik tanpa refresh. Tampilkan screenshot di layar lain. HP scan dari screenshot → submit. Expected: HTTP 400 dengan message "Kode QR sudah lewat, mohon scan ulang." Cek `audit_logs` — entry `qr_code_invalid_attempt`.
    - **requirements**: 11.1, 11.2, 17.1
    - **dependencies**: 9.2

  - [~] 10.5 Test backward compat legacy session
    - **id**: `10.5`
    - **text**: User SQL update manual `UPDATE sessions SET session_code_seed = NULL WHERE id = '<active_session>'`. HP submit dengan code current static — should still success (legacy fallback). Cek audit log entry `qr_verify_method = 'static_legacy'`.
    - **requirements**: 4.6, 4.7, 4.8, 14.1, 14.2, 14.3, 14.4, 15.2
    - **dependencies**: 9.2

  - [~] 10.6 Test refresh code rotation
    - **id**: `10.6`
    - **text**: User klik "Refresh Kode" di session-list. Sebelum click: catat current `session_code_seed` via SQL. Setelah click: re-query — seed berubah. Polling next tick di display: code di QR + OTP berubah. Audit log entry `refresh_session_code` dengan `rotated: true`.
    - **requirements**: 7.1, 7.2, 7.3, 7.6, 15.5
    - **dependencies**: 9.2

  - [~] 10.7 Test auth gate negative — mahasiswa role
    - **id**: `10.7`
    - **text**: HP mahasiswa (Bearer JWT mahasiswa) coba GET `/api/admin/sessions/:id/current-code` via curl/Postman. Expected: 401 atau 403. Pastikan tidak return body apapun yang expose seed.
    - **requirements**: 5.5, 16.1, 16.3
    - **dependencies**: 9.2

  - [~] 10.8 Document smoke result di dev-log.md
    - **id**: `10.8`
    - **text**: User append entry tanggal + result 7 sub-test (10.1 sd 10.7) ke `dev-log.md`. Format sesuai pattern existing.
    - **requirements**: 18.6
    - **dependencies**: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7

- [x] 11. Documentation & CHANGELOG

  - [x] 11.1 Update CHANGELOG.md
    - **id**: `11.1`
    - **text**: Append entry `[ADD]` untuk migration 022, `[ADD]` untuk totp.ts utility, `[ADD]` untuk admin endpoint, `[MOD]` untuk submit refactor + sessions.ts, `[MOD]` untuk web display + session-list. Bahasa Indonesia singkat.
    - **requirements**: -
    - **dependencies**: 10.8

  - [x] 11.2 Update implementation_plan.md status Phase 3
    - **id**: `11.2`
    - **text**: Mark Phase 3 sebagai ✅ Selesai di tabel timeline implementation_plan.md. Update tabel migration list 022 dari "pending" ke "applied".
    - **requirements**: -
    - **dependencies**: 10.8

## Notes

### Optional Tasks (`*` postfix)
- Task `2.2` (property test TOTP) — high-value tapi optional kalau time-constrained. Recommended jangan skip karena algoritma critical security.

### Mandatory Tasks
- Tasks 1.x (DB), 2.1 (utility), 3.1 (submit), 4.1 (endpoint), 5.x (actions), 6.1 + 7.1 (web), 8.x + 9.x (verify), 10.x (smoke), 11.x (docs) WAJIB.

### Manual User Action Tasks
- Tasks 10.x adalah manual smoke test runtime — coding agent tidak bisa eksekusi. User harus jalankan di HP fisik + browser.

### Rollback Strategy
Per file via git revert. DB column drop hanya kalau benar-benar full rollback:
```sql
ALTER TABLE sessions DROP COLUMN IF EXISTS session_code_seed;
DROP INDEX IF EXISTS idx_sessions_active_with_seed;
```

### Critical Constraints
- **MOBILE NO CHANGE** — folder `mypresensi-mobile/` tidak boleh tersentuh.
- **Seed NEVER expose ke client** — verifikasi di task 3.1, 4.1, 5.1, 5.2 wajib.
- **Pesan error Bahasa Indonesia ramah** — task 3.1 wajib pakai exact copy "Kode QR sudah lewat, mohon scan ulang."
- **RLS pattern existing tidak diubah** — sessions table policy migration 011/012 sudah cover.
- **Migration via MCP wajib** — task 1.2 pakai `mcp0_apply_migration`, BUKAN manual SQL Editor.

## Files Summary

| Path | Action | Tasks |
|------|--------|-------|
| `mypresensi-web/supabase/migrations/022_rolling_qr_seed.sql` | NEW | 1.1, 1.2 |
| `mypresensi-web/app/lib/utils/totp.ts` | NEW | 2.1 |
| `mypresensi-web/app/lib/utils/totp.test.ts` | NEW (optional) | 2.2 |
| `mypresensi-web/app/api/admin/sessions/[id]/current-code/route.ts` | NEW | 4.1 |
| `mypresensi-web/app/api/mobile/attendance/submit/route.ts` | MOD | 3.1 |
| `mypresensi-web/app/lib/actions/sessions.ts` | MOD | 5.1, 5.2 |
| `mypresensi-web/app/(qr-projector)/sesi/[id]/qr/qr-display-client.tsx` | MOD | 6.1 |
| `mypresensi-web/app/(dashboard)/sesi/session-list.tsx` | MOD | 7.1 |
| `CHANGELOG.md` | MOD | 11.1 |
| `docs/plans/implementation_plan.md` | MOD | 11.2 |
| `dev-log.md` | MOD | 10.8 |
| `mypresensi-mobile/**` | **NO CHANGE** | – |
