# Implementation Plan: Live Monitor Dosen Web

## Overview

Implementation order:
1. **Backend endpoint** `/api/admin/sessions/[id]/live-state` — prerequisite untuk client SSR + reconnect refresh.
2. **Frontend page** Server Component dengan auth + initial fetch.
3. **Frontend client** dengan Realtime subscription + sub-components.
4. **Frontend wiring** tombol di `session-list.tsx`.
5. **Verification** — type-check + lint + build.
6. **Manual smoke test** — 2-window real-time interaction.

Effort estimasi: **5-7 jam**.

## Tasks

- [x] 0. Backend Endpoint — Live State

  - [x] 0.1 Implement endpoint `GET /api/admin/sessions/[id]/live-state/route.ts`
    - File path: `mypresensi-web/app/api/admin/sessions/[id]/live-state/route.ts`
    - Auth: `requireRole(['admin', 'dosen'])` + `canAccessCourse` ownership
    - Rate limit: 30 req/menit per `(user.id, sessionId)` reuse `_lib/rate-limit.ts`
    - Fetch session.course_id (single field) untuk ownership
    - Parallel fetch via `Promise.all`:
      - `enrollments` JOIN `profiles` WHERE `course_id = session.course_id` (return: student_id, full_name, nim, avatar_url)
      - `attendances` WHERE `session_id` (return: student_id, status, scanned_at, lat, lng, distance, mock, face_confidence)
    - Merge: untuk setiap enrollment cari attendance match → kalau ada, fill status; kalau tidak, status='belum'
    - Compute stats: hadir/terlambat/belum/total/ditolak (mock_location)
    - Return `{ students: StudentLiveRow[], stats: LiveStats }`
    - TIDAK return session_code atau Tier 1 fields
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 0.2 Verify backend — `npm run type-check` + `npm run lint`
    - cwd: `mypresensi-web/`
    - Expected: type-check exit 0, lint 0 baru
    - _Requirements: 14.1_

- [x] 1. Frontend Page

  - [x] 1.1 Create `app/(dashboard)/sesi/[id]/live/page.tsx`
    - File path: `mypresensi-web/app/(dashboard)/sesi/[id]/live/page.tsx`
    - Server Component (default, tidak `'use client'`)
    - Komentar header Bahasa Indonesia
    - Auth: `requireRole(['admin', 'dosen'])` di awal
    - Fetch session via JOIN query (sama pattern Phase B1 page.tsx)
    - WHEN session null → `notFound()`
    - WHEN ownership fail → `redirect('/sesi?error=no-access')`
    - Fetch initial state via helper `fetchInitialLiveState(client, sessionId, courseId)` (boleh inline atau extract ke utility)
    - `generateMetadata` async: title `${courseName} · Pertemuan ${N} — Live Monitor`
    - Render `<LiveMonitorClient {...props} />`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 1.2 Verify page — `npm run type-check`
    - Expected: exit 0 (atau ada error dari client component yang belum ada — itu OK, akan resolved di task 2)
    - _Requirements: 14.1_

- [x] 2. Frontend Client

  - [x] 2.1 Create main `live-monitor-client.tsx`
    - File path: `mypresensi-web/app/(dashboard)/sesi/[id]/live/live-monitor-client.tsx`
    - `'use client'` directive baris pertama (after komentar header)
    - Komentar header Bahasa Indonesia
    - Implement `LiveMonitorClient(props)` per design.md §Components and Interfaces - Component 2
    - State management:
      - `students` Map<string, StudentLiveRow>
      - `stats` LiveStats
      - `activity` Array<ActivityEvent> (max 20)
      - `filterChip` 'semua'|'hadir'|'telat'|'belum'|'ditolak'
      - `syncStatus` RealtimeChannelStatus
      - `countdownSec`, `isEnding`
    - Hook `useRealtimeAttendances({ sessionId, onInsert, onStatusChange, enabled: isActive })`
    - `onInsert` callback per Algorithm 2 design.md (update Map, increment stats, prepend activity, dot transition)
    - `onStatusChange`: setSyncStatus + kalau dari error ke SUBSCRIBED, re-fetch `/live-state` untuk close gap
    - Countdown timer setInterval 1s (reuse pattern Phase B1)
    - Button "Akhiri Sesi": SweetAlert confirm → `toggleSessionAction(sessionId)` → router.replace('/sesi')
    - Button "Refresh Kode": `refreshSessionCode(sessionId)` → router.refresh()
    - Layout: 2-col split (geofence kiri 480px, main content kanan)
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 9.3, 9.4, 9.5, 9.6, 9.7, 10.1, 10.2, 10.3, 10.4, 12.1, 13.1, 13.2_

  - [x] 2.2 Implement sub-component `<MonitorTopbar>`
    - File: same as 2.1 (private function)
    - Render: brand + course info + Status_Badge "LIVE" pulse-dot + OTP mini + countdown + Refresh Kode + End Session
    - _Requirements: 9.1, 9.2, 10.1, 10.3, 13.3_

  - [x] 2.3 Implement sub-component `<MonitorKpiBar>`
    - File: same as 2.1 (private function)
    - 4 cards: Hadir / Telat / Belum / Total
    - Counter animation count-up via useEffect + setInterval ms-stepping (no library)
    - Icon Lucide + count + label
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 2.4 Implement sub-component `<GeofenceRing>` + `<StudentDot>`
    - File: same as 2.1 (private functions)
    - SVG 380px persegi
    - 3 concentric circles dashed border (radius 50/100/150m proportional ke 50%/66%/100% radius SVG)
    - Center marker map-pin icon + label "Pusat Kampus"
    - For each student dengan student_lat/lng non-null: render `<StudentDot>` di posisi computed via `computeDotPosition` algorithm
    - Dot styling per status (success/info/warning/danger)
    - Dot transition CSS `cx 0.3s, cy 0.3s` untuk smooth move animation
    - Tooltip on hover: nama + jam + distance
    - WHERE distance > 150m: dot di tepi ring 150m + outline danger
    - WHERE distance > 300m: increment "X mahasiswa terlalu jauh" banner counter
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [x] 2.5 Implement helper `computeDotPosition` pure function
    - Per design.md §Algorithm 1
    - Pure function: takes (centerLat, centerLng, studentLat, studentLng, ringSizePx, ringRadiusMeters)
    - Returns `{ x: number, y: number, withinRange: boolean }`
    - Haversine distance + bearing atan2 → polar to cartesian
    - Tempat: same file 2.1 atau extract ke `app/lib/geofence.ts` kalau dipakai di tempat lain (defer untuk MVP)
    - _Requirements: 5.7_

  - [ ]* 2.6 Write unit test for `computeDotPosition`
    - File: `app/lib/geofence.test.ts` (kalau extract) atau skip kalau inline
    - Test cases:
      - center 0,0 + student 0,0 → x=center, y=center, withinRange=true
      - student 1m utara dari center → x=center, y=center-small, withinRange=true
      - student 200m timur dari center (di luar 150m) → withinRange=false, dot di tepi
      - null GPS → x=center, y=center, withinRange=false
    - **Validates**: Property 5 (Geofence Position Stability)

  - [x] 2.7 Implement sub-component `<ActivityFeed>`
    - File: same as 2.1
    - List scrollable max 20 events
    - Event item: avatar/initial + nama + status badge + timestamp relatif
    - Empty state: "Menunggu mahasiswa scan QR..." dengan icon clock
    - Animation slide-in untuk event baru (CSS keyframes atau Tailwind animate-in)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 2.8 Implement sub-component `<StudentGrid>` + `<StudentCard>` + `<FilterChips>`
    - File: same as 2.1
    - FilterChips 5 chip dengan count per status
    - Student grid responsive (4-col desktop, 2-col tablet)
    - Card: avatar, nama, NIM, status badge
    - Filter logic: `students.filter(s => filterChip === 'semua' || s.status mapped to chip)`
    - Animation pulse highlight saat status change (className toggle 1 detik)
    - Empty state per filter
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

  - [x] 2.9 Verify client component — `npm run type-check` + `npm run lint`
    - Expected: type-check exit 0, lint 0 errors 0 warnings
    - _Requirements: 14.1_

- [x] 3. Frontend Wiring — Tombol Buka Live Monitor

  - [x] 3.1 Modify `session-list.tsx` — tambah tombol di active session card
    - File path: `mypresensi-web/app/(dashboard)/sesi/session-list.tsx`
    - Tambah import `Activity` atau `Radio` dari `lucide-react`
    - Tambah `<Link href={\`/sesi/${activeSession.id}/live\`}>` di action row (after Tampilkan Fullscreen Phase B1, before Salin Kode)
    - Style outline secondary (border-primary/30 bg-primary/5 text-primary hover:bg-primary/10)
    - Icon `<Activity size={13} />` + label "Live Monitor"
    - JANGAN ubah business logic existing
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

  - [x] 3.2 Verify wiring — `npm run type-check` + `npm run lint`
    - Expected: type-check exit 0, lint 0 baru
    - _Requirements: 14.1_

- [ ] 4. Final Checkpoint

  - [x] 4.1 Run full project verification
    - cwd: `mypresensi-web/`
    - `npm run type-check` → exit 0
    - `npm run lint` → 0 errors 0 warnings baru
    - `npm run build` → exit 0
    - Verify route `/sesi/[id]/live` registered di build output
    - Verify endpoint `/api/admin/sessions/[id]/live-state` registered
    - _Requirements: 14.2_

  - [~] 4.2 Manual smoke test (user-action)
    - **NOTE**: Task ini dilakukan oleh user manual.
    - Per Requirement 15.1 acceptance criteria:
      - (a) Login dosen → /sesi → klik tombol "Live Monitor"
      - (b) Verify navigate ke /sesi/[id]/live
      - (c) Verify visual: geofence ring 3 circles, KPI bar 4 cards, activity feed empty state, student grid semua "Belum"
      - (d) Window B: mahasiswa scan QR
      - (e) Verify dalam <2 detik: dot muncul, activity prepend, KPI Hadir +1, student card status update + animation
      - (f) Repeat 2-3 mahasiswa lain
      - (g) Test mock GPS → verify dot ditolak merah + banner danger
      - (h) Klik "Akhiri Sesi" → confirm → redirect /sesi
    - User SHALL document hasil di `dev-log.md` atau `CHANGELOG.md`
    - _Requirements: 15.1, 15.2_

## Notes

- Task 2.6 PBT optional `*` — skip kalau time tight, manual smoke test cover.
- Setiap task reference `_Requirements: X.Y_`.
- File baru (5):
  1. `app/api/admin/sessions/[id]/live-state/route.ts`
  2. `app/(dashboard)/sesi/[id]/live/page.tsx`
  3. `app/(dashboard)/sesi/[id]/live/live-monitor-client.tsx`
  4. (Optional) `app/lib/geofence.ts` (kalau extract `computeDotPosition`)
  5. (Optional) `app/lib/geofence.test.ts` (PBT optional)
- File modified (1):
  1. `app/(dashboard)/sesi/session-list.tsx` (tambah tombol)
- Tidak ada migration. Tidak ada dependency baru.
- Reuse: `useRealtimeAttendances` (Phase C1), `requireRole`/`canAccessCourse`, `refreshSessionCode`/`toggleSessionAction` server actions, `QRCodeSVG`, `@/lib/swal`, design tokens existing.
