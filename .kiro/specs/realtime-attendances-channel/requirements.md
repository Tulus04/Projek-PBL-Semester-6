# Requirements Document

## Introduction

Spec ini menambahkan **Supabase Realtime channel** untuk tabel `attendances` agar dashboard web (dosen/admin) bisa subscribe perubahan kehadiran tanpa polling. Saat ini fitur seperti QR Display Fullscreen (Phase B1) pakai polling 5 detik — efektif tapi bukan true real-time. Untuk fitur showcase **Live Monitor** (Phase B2) yang akan menampilkan dot mahasiswa bergerak masuk satu per satu di geofence ring, polling = tech debt.

Solusi: Setup migration enable publication `supabase_realtime` untuk tabel `attendances`, plus React hook reusable `useRealtimeAttendances(sessionId, callback)` yang encapsulasi subscribe + cleanup + status surfaced. Hook reusable di Live Monitor + future upgrade QR Display dari polling.

Ini Phase **C1** dari roadmap TODO.md (Prioritas 3 nomor 2: "Supabase Realtime untuk live dashboard dosen"). Mockup referensi tidak ada (infrastructure work). Effort estimasi: **4-6 jam**.

## Glossary

- **Web_App**: Aplikasi Next.js `mypresensi-web/` di laptop dosen/admin.
- **Realtime_Channel**: Supabase Realtime channel — WebSocket subscription dengan filter Postgres Changes.
- **Realtime_Publication**: Postgres publication `supabase_realtime` yang track tabel mana yang stream perubahan ke Realtime gateway.
- **CDC**: Change Data Capture — Postgres WAL streaming via logical replication ke Realtime gateway.
- **Attendances_Channel**: Channel name pattern `attendances:session=${sessionId}` — 1 channel per session yang di-pantau.
- **Postgres_Changes_Filter**: Supabase Realtime filter `session_id=eq.${sessionId}` yang server-side filter event sebelum delivery.
- **REPLICA_IDENTITY_FULL**: Postgres setting yang membuat WAL include full row pada UPDATE/DELETE (default DEFAULT cuma include PK).
- **Use_Realtime_Attendances**: Custom React hook `useRealtimeAttendances(opts)` di `app/lib/realtime/use-realtime-attendances.ts` baru.
- **Realtime_Attendance_Row**: Type interface untuk payload row di `app/types/realtime.ts` baru.
- **Realtime_Channel_Status**: Type union `'SUBSCRIBED' | 'CHANNEL_ERROR' | 'TIMED_OUT' | 'CLOSED' | 'CONNECTING'`.
- **createClient**: Helper `app/lib/supabase/client.ts` (existing) — `createBrowserClient` dari `@supabase/ssr` untuk browser context.
- **Stale_Closure**: React anti-pattern dimana callback inside useEffect closure-nya pegang state lama. Mitigasi: useRef untuk callback.
- **MCP_Apply_Migration**: Supabase MCP tool `apply_migration` yang track migration di history Supabase (bukan manual SQL editor).
- **Free_Tier_Limit**: Supabase Free tier max 200 concurrent Realtime connections per project.

## Requirements

### Requirement 1: Migration Enable Realtime Publication

**User Story:** Sebagai pengembang, saya ingin tabel `attendances` masuk ke publication `supabase_realtime` agar Postgres CDC stream perubahannya ke Realtime gateway.

#### Acceptance Criteria

1. THE Web_App backend SHALL memiliki migration baru `021_enable_realtime_attendances.sql` di `mypresensi-web/supabase/migrations/`.
2. THE migration SHALL menambahkan tabel `public.attendances` ke publication `supabase_realtime` via `ALTER PUBLICATION supabase_realtime ADD TABLE public.attendances`.
3. THE migration SHALL idempotent — pakai DO block dengan check `pg_publication_tables` untuk hindari error "table already in publication" saat re-run.
4. THE migration SHALL set `REPLICA IDENTITY FULL` eksplisit pada tabel attendances untuk memastikan payload event include full row.
5. THE migration SHALL diapply via `mcp0_apply_migration` (BUKAN manual via SQL Editor) agar tracked di Supabase migration history.
6. WHEN migration diapply, THE pengembang SHALL menjalankan `mcp0_get_advisors({ type: 'security' })` dan memastikan 0 issue baru.

### Requirement 2: Type Definitions Realtime

**User Story:** Sebagai pengembang TypeScript strict, saya ingin payload Realtime ter-type dengan benar agar consumer hook tidak `any`.

#### Acceptance Criteria

1. THE Web_App SHALL memiliki file baru `app/types/realtime.ts` yang export interface `RealtimeAttendanceRow`, type `RealtimeAttendancePayload`, type `RealtimeChannelStatus`, dan interface `UseRealtimeAttendancesOptions`.
2. THE `RealtimeAttendanceRow` SHALL match schema tabel attendances current (id, session_id, student_id, status, scanned_at, student_lat, student_lng, distance_meters, is_location_valid, is_mock_location, face_confidence, is_face_matched, device_model, device_os, ip_address, created_at).
3. THE `RealtimeAttendancePayload` SHALL = `RealtimePostgresChangesPayload<RealtimeAttendanceRow>` (re-export dari `@supabase/supabase-js`).
4. THE `UseRealtimeAttendancesOptions` SHALL include: `sessionId: string`, `onInsert: (row) => void`, `onStatusChange?: (status) => void`, `enabled?: boolean` (default true).

### Requirement 3: Hook `useRealtimeAttendances`

**User Story:** Sebagai pengembang yang akan mendapat fitur Live Monitor, saya ingin hook reusable yang encapsulasi subscribe + cleanup channel attendances filtered by session.

#### Acceptance Criteria

1. THE Web_App SHALL memiliki file baru `app/lib/realtime/use-realtime-attendances.ts` yang export function `useRealtimeAttendances(opts: UseRealtimeAttendancesOptions): void`.
2. THE file SHALL diawali dengan directive `'use client'` di baris pertama (after komentar header).
3. THE hook SHALL menggunakan `createClient()` dari `@/lib/supabase/client` untuk browser Supabase client.
4. THE hook SHALL membuka channel dengan name `attendances:session=${sessionId}` ketika `enabled=true && sessionId` non-empty.
5. THE hook SHALL listen event `INSERT` saja (tidak UPDATE/DELETE) pada schema `public` table `attendances` dengan filter `session_id=eq.${sessionId}`.
6. WHEN INSERT event diterima, THE hook SHALL panggil `opts.onInsert(payload.new as RealtimeAttendanceRow)`.
7. WHEN status channel berubah, THE hook SHALL panggil `opts.onStatusChange?.(status)` jika provided.
8. WHEN component unmount, THE hook SHALL panggil `channel.unsubscribe()` AND `client.removeChannel(channel)` untuk cleanup.
9. WHEN `enabled=false` atau `sessionId` empty, THE hook SHALL TIDAK membuka channel (no-op).

### Requirement 4: Channel Filtering & Scope

**User Story:** Sebagai dosen yang lagi pantau sesi spesifik, saya ingin terima event hanya untuk attendance di sesi itu — bukan dari sesi MK lain saya juga.

#### Acceptance Criteria

1. THE hook SHALL set Postgres Changes filter `session_id=eq.${sessionId}` agar Supabase Realtime gateway tidak deliver event dari session lain.
2. WHEN dosen subscribe channel session A, THE channel SHALL TIDAK menerima event dari INSERT attendances di session B.
3. THE filter SHALL handled server-side oleh Supabase Realtime parser — TIDAK boleh client-side filter as defense.

### Requirement 5: Cleanup & Lifecycle

**User Story:** Sebagai pengembang yang menjaga memory hygiene, saya ingin pastikan channel selalu unsubscribe + removeChannel saat unmount agar tidak ada ghost connection.

#### Acceptance Criteria

1. WHEN React component yang pakai hook unmount, THE hook SHALL clear channel dalam useEffect cleanup function.
2. THE cleanup SHALL panggil `channel.unsubscribe()` (close subscription) AND `client.removeChannel(channel)` (release client memory).
3. WHEN dependencies (`sessionId` atau `enabled`) berubah, THE hook SHALL cleanup channel lama dan create channel baru.
4. AFTER cleanup, THE hook SHALL TIDAK lagi panggil `onInsert` atau `onStatusChange`.
5. WHEN sessionId berubah dari valid ke null/empty, THE hook SHALL cleanup tanpa create channel baru.

### Requirement 6: RLS Compliance

**User Story:** Sebagai admin sistem, saya ingin pastikan Realtime tidak bypass RLS — mahasiswa lain tidak boleh terima event attendance bukan miliknya.

#### Acceptance Criteria

1. THE Realtime SHALL evaluate RLS policy "View own or all if admin/dosen" (existing migration 012) per event delivery.
2. WHEN mahasiswa A subscribe channel session yang bukan MK-nya, THE Realtime SHALL TIDAK deliver event dari INSERT attendance di session itu (RLS reject di server).
3. WHEN dosen B subscribe channel session di MK Dosen A, THE Realtime SHALL TIDAK deliver event (RLS reject — dosen B bukan owner).
4. THE auth context SHALL otomatis attach ke channel dari cookie session aktif di browser via `createBrowserClient()` dari `@supabase/ssr`.
5. WHEN user belum login (cookie tidak set atau expired), THE channel SHALL fail subscribe dengan status `CHANNEL_ERROR`.

### Requirement 7: Status Surface to Caller

**User Story:** Sebagai consumer hook (UI), saya ingin tahu status channel realtime agar bisa show indikator "Sync aktif" / "Reconnecting" / "Offline".

#### Acceptance Criteria

1. THE hook SHALL expose status channel via `opts.onStatusChange?(status: RealtimeChannelStatus)` callback yang dipanggil setiap status berubah.
2. THE possible status values SHALL include: `'SUBSCRIBED'`, `'CHANNEL_ERROR'`, `'TIMED_OUT'`, `'CLOSED'`, `'CONNECTING'`.
3. WHEN initial mount, THE hook SHALL trigger `onStatusChange('CONNECTING')` (atau status yang pertama Supabase report) — caller bisa show loading indicator.
4. WHEN subscribe sukses, THE hook SHALL trigger `onStatusChange('SUBSCRIBED')` — caller bisa show badge "Sync aktif".
5. WHEN network drop, THE hook SHALL eventually trigger `onStatusChange('CHANNEL_ERROR')` lalu `onStatusChange('CONNECTING')` saat auto-retry.

### Requirement 8: Stale Closure Resistance

**User Story:** Sebagai pengembang yang pakai hook di komponen yang sering re-render, saya ingin callback `onInsert` selalu invoke versi terbaru — tanpa harus subscribe ulang setiap re-render.

#### Acceptance Criteria

1. THE hook SHALL gunakan `useRef` untuk menyimpan `onInsert` dan `onStatusChange` callback agar event handler menggunakan callback terbaru tanpa dependency di useEffect.
2. WHEN parent re-render dengan `onInsert` callback yang berbeda identitas tapi `sessionId` sama, THE hook SHALL TIDAK re-subscribe channel (tetap pakai channel lama, callback ref di-update).
3. THE useEffect dependencies SHALL HANYA mencakup `sessionId` dan `enabled` (BUKAN callback identity).

### Requirement 9: No Sensitive Field Exposure di Log

**User Story:** Sebagai admin sistem, saya ingin hook TIDAK secara default `console.log` payload Realtime karena mengandung field sensitif (`device_os`, `ip_address`).

#### Acceptance Criteria

1. THE hook implementation SHALL TIDAK menggunakan `console.log(payload)` atau `console.log(row)` di production code path.
2. WHERE debug log diperlukan, THE pengembang SHALL pakai `if (process.env.NODE_ENV === 'development')` guard atau dedicated logger yang gampang strip di production.
3. THE callback consumer SHALL bertanggung jawab tidak `console.log(row)` sembarangan — best practice didokumentasikan di JSDoc hook.

### Requirement 10: Backward Compat dengan Polling Endpoint

**User Story:** Sebagai pengembang yang menjaga reliability, saya ingin polling endpoint `/api/admin/sessions/[id]/live-stats` (dari Phase B1) TETAP berfungsi sebagai fallback kalau Realtime fail.

#### Acceptance Criteria

1. THE existing endpoint `/api/admin/sessions/[id]/live-stats` SHALL TIDAK dihapus atau di-deprecate dalam scope spec ini.
2. THE existing QR Display Fullscreen `qr-display-client.tsx` (Phase B1) SHALL TETAP pakai polling — TIDAK di-migrate ke Realtime di scope spec ini (separate spec future).
3. THE Live Monitor (Phase B2 future) AKAN pakai Realtime sebagai primary data source. Fallback ke polling kalau status `CHANNEL_ERROR` persistent — tapi itu di-handle di Live Monitor spec, bukan di sini.

### Requirement 11: Connection Limit Awareness

**User Story:** Sebagai admin sistem yang aware Free tier limit, saya ingin pastikan hook tidak menyebabkan connection leak yang bisa hit limit 200 concurrent.

#### Acceptance Criteria

1. THE hook SHALL pasti unsubscribe + removeChannel saat unmount (Req 5) untuk free up slot.
2. WHEN `enabled=false`, THE hook SHALL TIDAK open channel (no slot consumed).
3. THE design.md SHALL document Free tier limit + recommendation upgrade ke Pro plan untuk production scale-out (>200 dosen aktif simultan).

### Requirement 12: Verification Gate

**User Story:** Sebagai engineer yang menjaga kualitas, saya ingin setiap task diverifikasi secara teknis sebelum ditandai selesai.

#### Acceptance Criteria

1. WHEN engineer menyelesaikan migration, THE engineer SHALL verifikasi via `mcp0_list_migrations` bahwa migration baru tracked + `mcp0_get_advisors security` 0 issue baru.
2. WHEN engineer menyelesaikan type definitions + hook, THE engineer SHALL menjalankan `npm run type-check` di `mypresensi-web/` dan memastikan exit 0.
3. WHEN engineer menyelesaikan, THE engineer SHALL menjalankan `npm run lint` di `mypresensi-web/` dan memastikan 0 errors 0 warnings baru.
4. WHEN type-check atau lint atau advisor fail, THE task SHALL TIDAK dianggap selesai hingga issue diperbaiki.

### Requirement 13: Manual Smoke Test

**User Story:** Sebagai pemilik produk, saya ingin verifikasi end-to-end Realtime flow dengan 2 browser windows interaction sebelum spec dianggap selesai.

#### Acceptance Criteria

1. WHEN keseluruhan implementasi selesai dan verification gate lulus, THE pemilik produk SHALL melakukan smoke test:
   - (a) Buat test page minimal `app/(dashboard)/realtime-test/page.tsx` ATAU pakai page Live Monitor saat sudah ada (Phase B2). Test page menampilkan list event INSERT yang diterima dengan timestamp + student_id + status.
   - (b) Login dosen di Window A → buka test page dengan parameter sessionId active session
   - (c) Verify status badge `SUBSCRIBED`
   - (d) Login mahasiswa di Window B (atau mobile emulator) → scan QR sesi tsb
   - (e) Verify Window A receive event dalam <2 detik tanpa refresh
   - (f) Verify list event di Window A bertambah row dengan student_id, status='hadir'/'terlambat', scanned_at terbaru
   - (g) Tutup Window A → verify console tidak ada warning memory leak; buka Network tab WebSocket → verify connection closed
   - (h) Login dosen LAIN di Window C dengan sessionId session yang BUKAN MK-nya → verify subscribe tapi tidak terima event (RLS gate)
2. THE manual smoke test SHALL menggunakan akun dari `mypresensi-web/.dev-accounts.md`.
3. THE manual smoke test result SHALL didokumentasikan di `dev-log.md` atau `CHANGELOG.md`.

### Requirement 14: Out of Scope (Explicit Non-Goals)

**User Story:** Sebagai pemilik produk, saya ingin pastikan scope spec ini tidak overlap dengan spec lain.

#### Acceptance Criteria

1. THE spec ini SHALL TIDAK membuat UI Live Monitor — itu Phase B2 separate spec.
2. THE spec ini SHALL TIDAK migrate QR Display Fullscreen dari polling ke Realtime — itu future spec terpisah (atau sub-task Phase B2 sekaligus).
3. THE spec ini SHALL TIDAK enable Realtime untuk tabel selain `attendances` (e.g. `sessions`, `leave_requests`, `notifications`) — itu separate spec kalau dibutuhkan.
4. THE spec ini SHALL TIDAK menggunakan Supabase Realtime Presence atau Broadcast — hanya Postgres Changes (CDC).
5. THE spec ini SHALL TIDAK menambah throttling di hook — INSERT-only, frequency rendah, tidak butuh.
6. THE spec ini SHALL TIDAK upgrade Supabase plan — tetap di Free tier untuk PBL.
