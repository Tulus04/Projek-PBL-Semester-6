# Implementation Plan: QR Display Fullscreen Web

## Overview

Convert design + requirements menjadi serangkaian task implementasi terurut. Implementation order:

1. **Backend endpoint** `/api/admin/sessions/[id]/live-stats` — prerequisite untuk frontend polling.
2. **Frontend layout & page** — route group `(qr-projector)` + Server Component page.
3. **Frontend client** — interactive UI (countdown, polling, expired overlay).
4. **Frontend wiring** — tombol "Tampilkan Fullscreen" di session-list dan sessions-modal.
5. **Verification** — type-check + lint.
6. **Manual smoke test** — user-action.

Bahasa: TypeScript / TSX (Next.js 14 App Router). Setiap task WAJIB lulus `npm run type-check` exit 0 dan `npm run lint` clean sebelum task ditandai selesai (Requirement 17).

## Tasks

- [x] 0. Backend Endpoint — Live Stats

  - [x] 0.1 Implement endpoint `GET /api/admin/sessions/[id]/live-stats/route.ts`
    - File path: `mypresensi-web/app/api/admin/sessions/[id]/live-stats/route.ts`
    - Komentar header Bahasa Indonesia: tujuan + catatan keamanan
    - Implement per design.md §Components and Interfaces - Component 4 + §Algorithmic Pseudocode Algorithm 3
    - Auth: `requireRole(['admin', 'dosen'])` di awal handler
    - Rate limit: 60 req per 60 detik per `(user.id + sessionId)` — pakai pola sliding window in-memory (lihat `app/api/mobile/_lib/rate-limit.ts` jika ada, atau implementasikan inline mirip `attendance/submit/route.ts`)
    - Fetch session.course_id (single field) untuk ownership check
    - `canAccessCourse(user.id, user.role, session.course_id)` — 403 if not owner (admin pass-through)
    - `Promise.all` dua count: attendances `status IN ('hadir','terlambat')` + enrollments `course_id`
    - Return `{ hadir: number, total: number }` via NextResponse JSON
    - Error response: 401 / 403 / 404 / 429 / 500 dengan pesan Bahasa Indonesia
    - TIDAK panggil `logAudit` (read-only endpoint)
    - TIDAK return `session_code` atau field sensitif lain
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 7.10, 7.11, 7.12, 8.1, 8.2, 8.3, 8.4, 8.5, 14.3, 14.4, 14.5, 15.2_

  - [x] 0.2 Verify backend — `npm run type-check` + `npm run lint`
    - cwd: `mypresensi-web/`
    - Expected: type-check exit 0, lint 0 errors 0 warnings baru
    - Fix issue sebelum mark task complete
    - _Requirements: 17.1, 17.2, 17.4_

- [ ] 1. Frontend Layout — Route Group `(qr-projector)`

  - [x] 1.1 Create `app/(qr-projector)/layout.tsx`
    - File path: `mypresensi-web/app/(qr-projector)/layout.tsx`
    - Server Component (default, tidak `'use client'`)
    - Komentar header Bahasa Indonesia
    - Export `metadata: Metadata` dengan `robots: 'noindex, nofollow'`
    - Render `<div>` root dengan dark theme base styling (Tailwind + inline gradient kalau perlu)
    - TIDAK render sidebar atau topbar
    - TIDAK panggil auth guard di layout (page.tsx yang handle, agar layout reusable kalau ke depan ada route lain di group ini)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 16.1_

  - [ ] 1.2 Create `app/(qr-projector)/sesi/[id]/qr/page.tsx`
    - File path: `mypresensi-web/app/(qr-projector)/sesi/[id]/qr/page.tsx`
    - Server Component (default, tidak `'use client'`)
    - Komentar header Bahasa Indonesia
    - Implement per design.md §Components and Interfaces - Component 2
    - Auth: `requireRole(['admin', 'dosen'])` (throws → handled by Next.js middleware/error)
    - Fetch session via single JOIN query (`courses + dosen profiles`)
    - WHEN session null/error: `notFound()`
    - WHEN dosen + bukan owner: `redirect('/sesi?error=no-access')`
    - Initial stats fetch via helper `fetchInitialStats(supabase, sessionId, courseId)` — boleh buat helper inline atau extract ke utility
    - `generateMetadata` async: title `${courseName} · Pertemuan ${N} — QR Presensi`
    - Render `<QrDisplayClient {...props} />` dengan props lengkap
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 1.3 Verify layout + page — `npm run type-check`
    - cwd: `mypresensi-web/`
    - Expected: exit 0
    - _Requirements: 17.1_

- [x] 2. Frontend Client — Interactive UI

  - [x] 2.1 Create `qr-display-client.tsx`
    - File path: `mypresensi-web/app/(qr-projector)/sesi/[id]/qr/qr-display-client.tsx`
    - Client Component (`'use client'` baris pertama)
    - Komentar header Bahasa Indonesia
    - Implement per design.md §Components and Interfaces - Component 3
    - Top-level component `QrDisplayClient(props: QrDisplayClientProps)`
    - State: countdown seconds, stats, pollState, errorCount
    - `useEffect`:
      - Countdown setInterval 1000ms (Algorithm 1) → cleanup di unmount
      - Polling setInterval 5000ms (Algorithm 2) → AbortController per fetch → cleanup unmount
    - Sub-components private:
      - `<PresTopbar courseName courseCode>` — brand + status pill SESI AKTIF + tombol "Tutup"
      - `<MkHeader courseName courseCode dosenName sessionNumber />`
      - `<QrCard qrPayload size={360} />` — wrap `QRCodeSVG`, gold glow shadow + dashed bottom row info
      - `<OtpBlock code countdownSec totalSec />` — 88pt mono with gold separator, countdown bar
      - `<InstructionList />` — 1-2-3 numbered steps cara scan (Bahasa Indonesia)
      - `<PresProgress stats={ hadir, total } pollState />` — bottom strip stats + progress bar
      - `<ExpiredOverlay onRefresh />` — overlay penuh saat expired
    - Tombol "Tutup" panggil `window.close()` (window terpisah, aman untuk close programmatic)
    - Tombol "Refresh Kode" call `refreshSessionCode` server action → `router.refresh()` on success → toast.fire on error
    - WHEN polling 401 → `window.location.href = '/login'`
    - WHEN polling 403 → tampilkan banner "Tidak ada akses" + setTimeout 3000ms → `window.close()`
    - WHEN polling 404 → tampilkan banner "Sesi sudah dihapus" + setTimeout 3000ms → `window.close()`
    - WHEN polling backoff → tampilkan badge "Sync terganggu" di stats area, angka cached tetap visible
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 11.1, 11.2, 11.3, 11.4, 11.5, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 15.1, 15.3, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_

  - [ ]* 2.2 Write property test for `computeCountdown` helper
    - **Property 1: Countdown Monotonicity**
    - **Validates: Requirements 6.1, 6.5**
    - Optional task. Pure function, deterministic terhadap input ISO + clock — kandidat PBT yang ringan
    - Skip kalau time tight; verifikasi static + manual smoke test cukup

  - [x] 2.3 Verify client component — `npm run type-check` + `npm run lint`
    - cwd: `mypresensi-web/`
    - Expected: type-check exit 0, lint 0 baru
    - _Requirements: 17.1, 17.2_

- [ ] 3. Frontend Wiring — Tombol Tampilkan Fullscreen

  - [ ] 3.1 Modify `session-list.tsx` — tambah tombol di active session card
    - File path: `mypresensi-web/app/(dashboard)/sesi/session-list.tsx`
    - Cari section active session card (around line 380-500, kondisi `session.is_active && session.session_code`)
    - Tambah tombol `<a>` dengan:
      - `href={\`/sesi/${activeSession.id}/qr\`}`
      - `target="_blank"`
      - `rel="noopener noreferrer"`
      - Icon Lucide `Maximize2` atau `ExternalLink`
      - Label "Tampilkan Fullscreen"
      - Style secondary outline (cn dengan border-border + bg-white + hover)
      - Tempatkan di row tombol existing (Refresh + Copy + ...) dengan flex gap
    - JANGAN ubah business logic existing (countdown, refresh, copy semua tetap jalan)
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.6, 14.6_

  - [x] 3.2 Modify `sessions-modal.tsx` — tambah tombol di active session card
    - File path: `mypresensi-web/app/(dashboard)/matakuliah/sessions-modal.tsx`
    - Cari section active session card (around line 218-310)
    - Tambah tombol identical dengan task 3.1
    - JANGAN ubah business logic existing
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 14.6_

  - [x] 3.3 Verify wiring — `npm run type-check` + `npm run lint`
    - cwd: `mypresensi-web/`
    - Expected: type-check exit 0, lint 0 errors 0 warnings baru
    - _Requirements: 17.1, 17.2_

- [ ] 4. Final Checkpoint

  - [x] 4.1 Run full project verification
    - cwd: `mypresensi-web/`
    - `npm run type-check` → exit 0
    - `npm run lint` → 0 errors 0 warnings baru
    - (opsional, untuk pre-merge) `npm run build` → exit 0
    - _Requirements: 17.3_

  - [~] 4.2 Manual smoke test (user-action)
    - **NOTE**: Task ini dilakukan oleh user manual, BUKAN coding agent. Mark complete adalah tanggung jawab user setelah verifikasi visual + integrasi per Requirement 18.
    - User SHALL melakukan smoke test menggunakan akun dari `mypresensi-web/.dev-accounts.md` / `credentials-MUSTREAD.txt`:
      - (a) Login dosen demo → buka /sesi → klik tombol "Tampilkan Fullscreen"
      - (b) Verify window baru terbuka dengan URL `/sesi/[id]/qr`
      - (c) Verify visual: QR 360px, OTP 88pt mono dengan separator gold, countdown bar gold, stats hadir/total tampil
      - (d) Verify polling: Network tab → request `live-stats` setiap 5 detik
      - (e) Demo scan QR via HP mahasiswa → verify hadir count naik dalam 5 detik
      - (f) Diamkan sampai countdown 00:00 → verify Expired Overlay muncul + tombol Refresh Kode
      - (g) Klik Refresh Kode → verify countdown reset
      - (h) Tutup window → verify Network tab no more polling
      - (i) Login mahasiswa → akses URL `/sesi/[id]/qr` direct → verify blocked (redirect login)
      - (j) Login dosen lain → akses URL session bukan miliknya → verify redirect (ownership gate)
    - User SHALL document hasil di `dev-log.md` atau `CHANGELOG.md` (entri `[ADD]`)
    - _Requirements: 18.1, 18.2, 18.3_

## Notes

- Tasks dengan `*` adalah opsional (Property test 2.2 untuk pure helper countdown). Optional karena `npm run type-check` + manual smoke test sudah cover primary verification path.
- Setiap task reference spesifik `_Requirements: X.Y_` untuk traceability.
- Task 4.1 final checkpoint memastikan tidak ada regresi setelah semua sub-task selesai.
- Task 4.2 manual smoke test eksplisit user-action, dipisahkan dari coding agent scope.
- Top-level tasks 0, 1, 2, 3 adalah core implementation dan WAJIB diimplementasi semua.
- All implementation MUST follow rules:
  - `02-quality-debugging-verification.md` (verify before claim)
  - `10-web-conventions.md` (web App Router structure)
  - `13-web-nextjs-patterns.md` (Server vs Client Component, route handlers)
  - `14-web-supabase-patterns.md` (RLS, admin client after auth check, parallel query)
  - `04-security-and-privacy.md` (rate limit, error sanitize, no Tier 1 exposure)
  - `03-design-and-libraries.md` (no new deps, qrcode.react, Lucide, clsx+tailwind-merge)
- File yang akan dibuat (5 file baru):
  1. `mypresensi-web/app/api/admin/sessions/[id]/live-stats/route.ts`
  2. `mypresensi-web/app/(qr-projector)/layout.tsx`
  3. `mypresensi-web/app/(qr-projector)/sesi/[id]/qr/page.tsx`
  4. `mypresensi-web/app/(qr-projector)/sesi/[id]/qr/qr-display-client.tsx`
  5. (Optional) `mypresensi-web/app/(qr-projector)/qr-projector.css` jika gradient/glow tidak achievable di pure Tailwind
- File yang akan dimodifikasi (2 file existing):
  1. `mypresensi-web/app/(dashboard)/sesi/session-list.tsx` (tambah tombol)
  2. `mypresensi-web/app/(dashboard)/matakuliah/sessions-modal.tsx` (tambah tombol)
- Tidak ada migration DB. Tidak ada perubahan model. Tidak ada perubahan API mobile.
