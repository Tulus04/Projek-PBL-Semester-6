# Implementation Plan: Phase 5 Mobile UI Rebuild

## Overview

Convert the feature design into a series of prompts for a code-generation LLM that will implement each step with incremental progress. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

Implementation order (per Decisions Table §Migration Plan):
1. **Backend prerequisite** — migration index + endpoint baru `/api/mobile/sessions/eligible-for-leave` + mobile model/provider/repo (dibutuhkan oleh wizard step 1).
2. **History rebuild** — paling self-contained, quick win.
3. **Home rebuild** — mid complexity (termasuk AI FAB + 3-state + reuse helper widgets).
4. **Submit leave wizard refactor** — paling kompleks (4-step state machine + integrate endpoint baru).
5. **(Optional)** Web `globals.css` token sync.
6. Manual smoke test (user-action, not implementable by agent).

Bahasa: Dart / Flutter (mobile) + TypeScript (web backend) + SQL (migration). Setiap rebuild WAJIB lulus `flutter analyze` di `mypresensi-mobile/` dan `npm run type-check` di `mypresensi-web/` dengan output bersih sebelum task ditandai selesai (Requirement 26).

## Tasks

- [x] 0. Backend Prerequisite — New Endpoint + DB Migration

  - [x] 0.1 Create migration `020_sessions_started_at_index.sql`
    - File path: `mypresensi-web/supabase/migrations/020_sessions_started_at_index.sql`
    - SQL: `CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at DESC);`
    - Komentar header: tujuan + referensi spec phase-5
    - _Requirements: 30.1, 30.2_

  - [x] 0.2 Apply migration via MCP `mcp0_apply_migration`
    - Migration name (timestamp): `<YYYYMMDDhhmmss>_sessions_started_at_index`
    - Verify ter-track di Supabase history via `mcp0_list_migrations`
    - _Requirements: 30.3_

  - [x] 0.3 Verify advisor security & performance after migration
    - Run `mcp0_get_advisors({ type: 'security' })` → 0 issue baru
    - Run `mcp0_get_advisors({ type: 'performance' })` → 0 unused index warning baru terkait migration ini
    - _Requirements: 30.4, 30.5_

  - [x] 0.4 Implement endpoint `GET /api/mobile/sessions/eligible-for-leave/route.ts`
    - File path: `mypresensi-web/app/api/mobile/sessions/eligible-for-leave/route.ts`
    - Komentar header Bahasa Indonesia: tujuan + catatan keamanan
    - Implement per design.md §Backend Endpoint Baru:
      - Auth via `authenticateRequest(req)` → guard 401
      - Rate limit 30 req / 5 menit per (user+device) — pakai helper `checkRateLimit` existing (jika ada di `_lib/`); kalau belum ada, sesuaikan dengan pola existing di `attendance/submit/route.ts`
      - Ambil `enrolled course_ids` via `enrollments`
      - Query 1: sesi dalam 7 hari terakhir + JOIN courses + dosen profile
      - Query 2 + 3 parallel via `Promise.all`: attendance status='hadir' + leave_requests status pending/approved
      - Build excluded set, partition ke `active_sessions` vs `recent_sessions`
      - Return via `successResponse({ active_sessions, recent_sessions })`
    - TIDAK ada `logAudit` (read-only endpoint)
    - _Requirements: 29.1, 29.2, 29.3, 29.4, 29.5, 29.6, 29.7, 29.8, 29.9, 29.10, 29.11, 29.12_

  - [x] 0.5 Update mobile API endpoint constant
    - File path: `mypresensi-mobile/lib/core/network/api_endpoints.dart`
    - Tambah `static const String sessionsEligibleForLeave = '/api/mobile/sessions/eligible-for-leave';`
    - _Requirements: 29.1_

  - [x] 0.6 Add `EligibleSessionsResponse` model to `attendance_models.dart`
    - File path: `mypresensi-mobile/lib/features/attendance/data/attendance_models.dart`
    - Class immutable dengan dua field `List<ActiveSession>` (activeSessions + recentSessions)
    - Factory `fromJson` parse dua array
    - _Requirements: 29.3_

  - [x] 0.7 Add `getEligibleSessionsForLeave()` method to `AttendanceRepository`
    - File path: `mypresensi-mobile/lib/features/attendance/data/attendance_repository.dart`
    - GET via Dio ke `ApiEndpoints.sessionsEligibleForLeave`
    - Return `EligibleSessionsResponse`
    - Handle error via existing `_handleError` pattern
    - _Requirements: 29.1, 29.3_

  - [x] 0.8 Add `eligibleSessionsForLeaveProvider` provider
    - File path: `mypresensi-mobile/lib/features/attendance/providers/attendance_provider.dart`
    - `FutureProvider.autoDispose<EligibleSessionsResponse>` watching `attendanceRepositoryProvider.getEligibleSessionsForLeave()`
    - _Requirements: 20.3_

  - [x] 0.9 Verify backend endpoint — `npm run type-check`
    - cwd: `mypresensi-web/`
    - Expected: exit 0
    - _Requirements: 26.1_

  - [x] 0.10 Verify mobile model + provider — `flutter analyze`
    - cwd: `mypresensi-mobile/`
    - Expected: "No issues found."
    - _Requirements: 26.1_

- [x] 1. Rebuild History Screen (mockup `mobile-riwayat.html`)

  - [x] 1.1 Read `mobile-riwayat.html` mockup and identify components needed
    - Identify section: app bar, hero summary (gradient + 5-stat + progress bar), filter chip 6-status, smart-date group header, riwayat item card, bottom sheet detail dengan face thumb
    - List existing helper widgets to reuse: `HeroCard`, `AppCard`, `KpiIconBox`, `SemanticIcon`
    - List icons from `IconsaxPlusBold.*` yang akan dipakai per status (success/info/warning/danger)
    - _Requirements: 9.1, 9.2, 10.1, 11.1, 12.1, 13.1_

  - [x] 1.2 Add `_historyFilterProvider` (screen-scoped Riverpod NotifierProvider)
    - Buat enum `_HistoryFilter { semua, hadir, telat, izin, sakit, alpa }` di file yang sama
    - Buat `_HistoryFilterNotifier extends Notifier<_HistoryFilter>` dengan method `set(v)` dan default `semua`
    - _Requirements: 10.3, 20.2_

  - [x] 1.3 Implement helper `groupHistoryBySmartDate(records)` as private function
    - Algorithm sesuai design.md §Algorithm 3
    - Return list of `({String label, int count, List<AttendanceRecord> items})` dengan order tetap (hari_ini → kemarin → minggu_ini → bulan_ini → lebih_lama), skip empty bucket
    - Format label hari/tanggal untuk "Hari Ini" dan "Kemarin" pakai locale ID (manual mapping `weekday` → "Senin"/"Selasa"/dll dan `month` → "Mei"/"Juni"/dll)
    - _Requirements: 11.1, 11.2, 11.4, 11.5_

  - [ ]* 1.4 Write property test for `groupHistoryBySmartDate`
    - **Property 3: Smart-Date Grouping Partition and Stability**
    - **Validates: Requirements 11.1, 11.2, 11.4, 11.5**
    - Generate random list `List<AttendanceRecord>` dengan campuran `scannedAt` di seluruh range (hari ini sampai > 30 hari lalu), assert: union semua `items` = input list (no drop, no duplicate); per group `items` order matches input subsequence; group order strict; empty bucket omitted

  - [x] 1.5 Implement helper `filterByStatus(records, filter)` as private function
    - Pure pattern match enum `_HistoryFilter` → predicate
    - Mapping `telat` → `r.status == 'terlambat'` (label TELAT, enum DB `terlambat`)
    - _Requirements: 10.4, 10.5_

  - [ ]* 1.6 Write property test for `filterByStatus`
    - **Property 2: History Filter Correctness**
    - **Validates: Requirements 10.4, 10.5**
    - For all (records, filter), assert subsequence relation + predicate match per filter

  - [x] 1.7 Implement `_HistoryHero` widget wrapping `HeroCard`
    - Props: `summary: AttendanceSummary`
    - Render: persentase besar (font 36 weight 800), label kategori (Sangat Baik ≥ 90%, Baik 75-89%, Cukup 60-74%, Perlu Diperhatikan < 60%), progress bar gradient, 5-stat detail row dengan icon `IconsaxPlusBold.{tick_circle, clock, note_2, health, close_circle}`
    - Pakai `AppShadows.hero`, `AppColors.primaryGradient`, gold radial glow signature
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 21.4_

  - [x] 1.8 Implement `_HistoryFilterChips` widget
    - Props: `counts: Map<_HistoryFilter, int>`
    - Horizontal scrollable Row dengan 6 chip (Semua, Hadir, Telat, Izin, Sakit, Alpa)
    - Active state: filled `AppColors.primary` + text white
    - Inactive state: filled `AppColors.surface` + border `AppColors.border` + text `AppColors.textSecondary`
    - Format text `"{Label} ({count})"` per chip
    - Watch `_historyFilterProvider`, set on tap
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 1.9 Implement `_DateGroupHeader` widget
    - Props: `label: String`, `count: int`
    - Render label uppercase dengan letter-spacing 0.3, count "X SESI" di kanan
    - Padding fromLTRB(20, 14, 20, 6), font Plus Jakarta Sans
    - _Requirements: 11.3_

  - [x] 1.10 Implement `_HistoryItemCard` widget
    - Props: `record: AttendanceRecord`, `onTap: VoidCallback`
    - Wrap dalam `AppCard` (radius 14)
    - Leading: `KpiIconBox` 44x44 sesuai status (hadir→success, terlambat→info, izin→warning, sakit→warning, alpa→danger)
    - Center: nama MK (Plus Jakarta Sans w700 13.5, ellipsis 1-line), meta row dengan `IconsaxPlusBold.clock_circle` + jam scan + (jika `distanceMeters != null`) `IconsaxPlusBold.location` + jarak meter
    - Trailing: status pill duotone dengan label uppercase
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 21.3, 22.3_

  - [x] 1.11 Implement `_HistoryDetailSheet` widget
    - Props: `record: AttendanceRecord`
    - Render: handle drag bar 36x4 di atas, status banner duotone tint sesuai status (judul + sub-text), 5 detail rows (MK, Waktu Presensi, Lokasi (conditional), Verifikasi Wajah (conditional with `_FaceMatchThumb`), Perangkat (placeholder))
    - NO mutation buttons (Property 10 enforcement)
    - Bottom padding 24px clearance
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

  - [x] 1.12 Implement `_FaceMatchThumb` widget
    - Props: `confidence: double`, `threshold: double` (= 0.65)
    - Render: 56x56 box dengan placeholder gradient avatar + border `AppColors.success` 2px, di sebelah kanan label "Cocok {pct}%" + "Threshold {pct}% · Liveness OK"
    - _Requirements: 13.4_

  - [x] 1.13 Wire `HistoryScreen` dengan provider + sub-widgets
    - Watch `historyProvider` dan `_historyFilterProvider`
    - 3-state handling: loading → `ListLoadingPlaceholder`, data → CustomScrollView (hero + filterChips + grouped list), error → `ErrorState` dengan retry
    - Handle filtered-empty state dengan icon + pesan ramah per filter (mengikuti pattern existing di MyLeaveRequestsScreen `_buildFilterEmptyState`)
    - Tap item → `showModalBottomSheet` → `_HistoryDetailSheet`
    - Pull-to-refresh via `RefreshIndicator` invalidate `historyProvider`
    - _Requirements: 9.1, 10.6, 11.1, 12.6, 13.6, 24.4, 24.5, 24.6_

  - [x] 1.14 Verify History rebuild — run `flutter analyze`
    - cwd: `mypresensi-mobile/`
    - Expected output: "No issues found."
    - Fix all warnings/errors before marking task complete
    - _Requirements: 26.1_

- [x] 2. Checkpoint — Ensure all History tests pass and no regression
  - Ensure all tests pass, ask the user if questions arise.

- [-] 3. Rebuild Home Screen (mockup `mobile-home.html`)

  - [x] 3.1 Read `mobile-home.html` mockup Frame 1/2/3 and identify components
    - Frame 1 (active): home appbar, greeting, hero session active, today summary, quick actions, activity feed (omitted per D5)
    - Frame 2 (empty): empty hero with dashed border, today summary all-zero state
    - Frame 3 (loading): skeleton placeholders
    - List icons needed: `IconsaxPlusBold.{notification, sun_2, cloud_sun, scan_barcode, clipboard_list, note_2, document_text, user_circle, calendar_2, clock_circle, location, user, qr_code}`
    - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1, 6.1_

  - [x] 3.2 Implement helper `_resolveDateLabel(DateTime)` and `_resolveWeatherIcon(int hour)`
    - `_resolveDateLabel` → format "Selamat {pagi|siang|sore|malam} — {hari}, {tgl} {bulan} {tahun}" lengkap dengan locale ID manual mapping
    - `_resolveWeatherIcon` → `IconsaxPlusBold.sun_2`/`cloud_sun`/`cloud`/`moon_fog` based on hour buckets (5-10 pagi, 11-14 siang, 15-17 sore, 18-04 malam)
    - _Requirements: 23.1_

  - [x] 3.3 Implement helper `_computeTodaySummary(List<ActiveSession>)`
    - Per design.md §Algorithm 4
    - Return `({int hadir, int sisa, int alpa, int total})` dengan alpa selalu 0
    - _Requirements: 5.2, 5.3, 5.4_

  - [ ]* 3.4 Write property test for `_computeTodaySummary`
    - **Property 1: Today Summary Conservation**
    - **Validates: Requirements 5.2, 5.3, 5.4**
    - Generate random `List<ActiveSession>` (mix `alreadySubmitted`), assert `hadir + sisa == sessions.length` AND `alpa == 0` AND `total == sessions.length`

  - [x] 3.5 Implement `_HomeAppBar` widget
    - Props: `userInitials: String`, `unreadBadge: bool`
    - Layout: brand "MyPresensi" (w800 17px primary), notif icon 38x38 dengan optional dot danger, avatar circle 34x34 gradient primary→primaryHover dengan inisial putih
    - Tap notif → `currentTabProvider.setTab(3)` (notification tab)
    - Tap avatar → `currentTabProvider.setTab(4)` (profile tab)
    - _Requirements: 22.1_

  - [x] 3.6 Implement `_GreetingHeader` widget
    - Props: `firstName: String`, `dateLabel: String`, `weatherIcon: IconData`
    - Layout: "Halo, {firstName}" w800 22, dibawahnya weather icon (color `AppColors.accent`) + dateLabel
    - _Requirements: 23.1_

  - [x] 3.7 Implement `_HeroSessionActive` widget
    - Props: `session: ActiveSession`, `onScanTap: VoidCallback`
    - Wrap `HeroCard` (sudah ada) → di dalamnya: `_PulseDot` + badge "SESI AKTIF SEKARANG", title nama MK w800 18, meta 3-line (dosen, lokasi, jam), tombol pill putih full-width "Scan QR Sekarang" dengan icon `IconsaxPlusBold.scan_barcode`
    - Tombol → `onScanTap` → `context.push('/scan')`
    - Implement `_PulseDot` sub-widget dengan AnimationController scale 1.0↔1.4 + opacity 1.0↔0.5, repeat, duration 1.5s
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 21.4_

  - [x] 3.8 Implement `_HeroSessionEmpty` widget
    - Props: `nextSession: ActiveSession?` (placeholder for future, default null)
    - Render: dashed border `AppColors.borderStrong` 1.5px, radius 18, padding 24, icon container 56x56 `AppColors.primarySurface` + `IconsaxPlusBold.calendar_2` color `AppColors.primary`, judul "Tidak ada sesi aktif saat ini" w700 15, paragraf penjelas
    - WHERE `nextSession != null`: render mini info card (icon + title + meta) — implementasi minimal karena backend belum support
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 3.9 Implement `_HeroSkeleton` widget
    - Render shimmer-style container 180px height, radius 18, background `AppColors.surfaceSunken` dengan animasi opacity 0.5↔1.0 loop 1.4s via AnimationController
    - _Requirements: 4.1, 4.2_

  - [x] 3.10 Implement `_TodaySummaryRow` widget
    - Props: `hadir: int`, `sisa: int`, `alpa: int`, `totalToday: int`
    - 3-column grid with stat cards: "Hadir" (text `{hadir}/{total}` color `AppColors.success`), "Sisa Sesi" (color `AppColors.primary`), "Alpa" (color `AppColors.danger`)
    - Setiap card pakai `AppCard` radius 14, padding 14x12
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 3.11 Implement `_QuickActionGrid` widget
    - Props: 4 callbacks (onScanTap/onHistoryTap/onLeaveTap/onProfileTap)
    - 4-column grid dengan `AppCard` per item, leading `KpiIconBox` 40x40:
      - Scan QR → `KpiColor.featured` (gold) icon `IconsaxPlusBold.scan_barcode`
      - Riwayat → `KpiColor.success` icon `IconsaxPlusBold.clipboard_text` (atau `task_square`)
      - Izin → `KpiColor.warning` icon `IconsaxPlusBold.note_2` (atau `document_text`)
      - Profil → `KpiColor.info` icon `IconsaxPlusBold.user_circle` (atau `user`)
    - Label di bawah icon, font Plus Jakarta Sans w600 11
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 22.3_

  - [x] 3.11b Implement `_AiChatFab` widget
    - Props: `onTap: VoidCallback`
    - FAB bulat 56×56, gradient `AppColors.accent` → `AppColors.accentSoft`, `AppShadows.fab`
    - Icon `IconsaxPlusBold.message_question` putih size 24
    - Tap → `context.push('/ai-chat')` (route sudah ada di `app_router.dart`)
    - Tetap visible di state loading (tidak skeleton)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.6, 22.1_

  - [x] 3.12 Wire `HomeScreen` dengan provider + sub-widgets
    - Replace existing `home_screen.dart` body
    - Watch `activeSessionsProvider` dan `authProvider`
    - Stagger animation 4 sections (existing pattern dipertahankan: `_animated(0..3, child)`)
    - Welcome toast logic dipertahankan (`_HomeScreenState._hasShownWelcome` static + `resetWelcome()`)
    - Hero render via `sessionsAsync.when(data: ..., loading: ..., error: ...)` → `_HeroSessionActive` / `_HeroSessionEmpty` / `_HeroSkeleton` / `ErrorState`
    - Today summary render via `sessionsAsync.maybeWhen(data: ..., orElse: SizedBox)`
    - Quick action grid always rendered
    - Body wrapped in `Stack` dengan `_AiChatFab` overlay di bottom-right (Positioned bottom: 16, right: 16)
    - NO activity feed section
    - Pull-to-refresh via `RefreshIndicator` invalidate `activeSessionsProvider` + `authProvider.notifier.refreshProfile()` (existing)
    - _Requirements: 2.1, 3.1, 4.1, 4.3, 5.1, 6.1, 7.1, 7.4, 7.5, 8.1, 24.1, 24.2, 24.3_

  - [x] 3.13 Verify Home rebuild — run `flutter analyze`
    - cwd: `mypresensi-mobile/`
    - Expected output: "No issues found."
    - Fix all warnings/errors before marking task complete
    - _Requirements: 26.1_

- [x] 4. Checkpoint — Ensure Home rebuild integrates with shell
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Refactor Submit Leave Request to 4-Step Wizard (mockup `mobile-leave-request.html`)

  - [x] 5.1 Read `mobile-leave-request.html` mockup all 4 steps and identify components
    - Step 1: step bar header, session-pick-item list dengan radio + status badge, info-banner empty
    - Step 2: selected-session-card read-only, type-grid 1×2 (Sakit/Izin), textarea + counter live
    - Step 3: upload-zone placeholder ATAU file-preview dengan thumbnail + X
    - Step 4: review-card dengan rows read-only
    - Footer: pill button full-width dengan label dinamis + icon arrow
    - _Requirements: 14.1, 14.2, 15.1, 16.1, 17.1, 18.1_

  - [x] 5.2 Define `WizardStep` enum and `WizardState` class
    - Enum: `pickSession, typeAndReason, evidence, review`
    - State class immutable dengan `copyWith`: `step, selectedSession, selectedType, reason, pickedImage, evidencePath, isUploadingEvidence, evidenceErrorText`
    - Computed getter `canAdvance: bool` per step (returns `false` saat invariant tidak terpenuhi)
    - _Requirements: 14.1, 19.1_

  - [x] 5.3 Implement `advanceWizardStep` and `goBackWizardStep` as private methods
    - Per design.md §Algorithm 1 dan §Algorithm 2
    - `advance` async untuk handle upload di step evidence
    - `goBack` synchronous, return `(newState, shouldPopRoute)`
    - Block back saat `isUploadingEvidence == true`
    - _Requirements: 14.5, 14.6, 17.7, 19.1, 19.2, 19.3_

  - [ ]* 5.4 Write property test for wizard advance state machine
    - **Property 4: Wizard Advance Linearity**
    - **Validates: Requirement 14.1**
    - Mock `LeaveRepository.uploadEvidence` to return synthetic path; assert sequence of 4 `advanceWizardStep` calls produces steps `[pickSession→typeAndReason→evidence→review]`

  - [ ]* 5.5 Write property test for wizard reversibility and preservation
    - **Property 5: Wizard Step Reversibility and Data Preservation**
    - **Validates: Requirements 14.5, 14.6, 19.1, 19.2**
    - For random WizardState `s` with `s.step > pickSession`, assert `goBackWizardStep(s).newState.step == previousStep(s.step)` AND fields preserved AND `advance(back(s)).step == s.step`; for `s.step == pickSession` assert `(s, true)` returned

  - [ ]* 5.6 Write property test for wizard back blocked during upload
    - **Property 6: Wizard Back Blocked During Upload**
    - **Validates: Requirement 17.7**
    - Construct state with `step == evidence` and `isUploadingEvidence == true`, assert `goBackWizardStep` returns `(s, false)` unchanged

  - [ ]* 5.7 Write property test for wizard advance idempotent on pre-uploaded evidence
    - **Property 7: Wizard Advance Idempotent on Pre-Uploaded Evidence**
    - **Validates: Requirement 19.3**
    - Mock LeaveRepository to throw if called; advance state with `evidencePath != null`; assert step transitions to review without exception (proving no upload call)

  - [x] 5.8 Implement `_StepBar` widget
    - Props: `currentStep: WizardStep`
    - 4 lingkaran 28x28 + 3 connector line:
      - Active: filled `AppColors.primary` + ring `AppColors.primarySurface` 3px + label color primary
      - Done: filled `AppColors.success` + icon check + label color textPrimary
      - Pending: `AppColors.surfaceSunken` + label tertiary
    - Connector line: 2px tinggi, `AppColors.border` (pending) atau `AppColors.success` (done)
    - _Requirements: 14.2, 14.3_

  - [x] 5.9 Implement `_SessionPickItem` widget
    - Props: `session: ActiveSession`, `selected: bool`, `onTap: VoidCallback`, `statusBadge: String?`
    - Render: tanggal box 48px (day name + date number gradient), info MK + jam + dosen, status badge pill, radio circle 22px (filled saat selected)
    - Selected state: border `AppColors.primary` + bg `AppColors.primarySurface`
    - _Requirements: 15.2, 15.3, 15.4_

  - [x] 5.10 Implement `_StepPickSession` widget
    - Props: `selected: ActiveSession?`, `onPick: ValueChanged<ActiveSession>`
    - Watch `eligibleSessionsForLeaveProvider` (NEW provider, lihat task 0.8) — bukan `activeSessionsProvider`
    - Render dua section dengan section header bila list non-empty:
      - Group A: "Sedang berlangsung" (icon `IconsaxPlusBold.radar` warna success) — render hanya jika `response.activeSessions.isNotEmpty`. Status badge per item: "AKTIF"
      - Group B: "Belum sempat hadir" (icon `IconsaxPlusBold.previous` warna textSecondary) — render hanya jika `response.recentSessions.isNotEmpty`. Status badge per item: "KEMARIN" jika selisih 1 hari, "{N} HARI LALU" jika ≥ 2 hari
    - Empty state (kedua list kosong): info-banner dengan icon + paragraf
    - 3-state handling (loading skeleton / data / error dengan retry)
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 24.7_

  - [x] 5.11 Implement `_SelectedSessionBadge` widget
    - Props: `session: ActiveSession`
    - Render: tanggal box + info MK + jam + dosen dalam container `AppColors.primarySurface` + border `AppColors.primary`
    - Read-only di Step 2
    - _Requirements: 16.1_

  - [x] 5.12 Implement `_TypeTile` widget
    - Props: `icon: IconData`, `label: String`, `selected: bool`, `onTap: VoidCallback`
    - 1×2 grid item: icon-wrap 48x48 (default surfaceSunken, selected primary), label "Sakit"/"Izin"
    - NO subtitle (Requirement 16.5)
    - Selected state: border `AppColors.primary` + bg `AppColors.primarySurface`
    - Sakit pakai `IconsaxPlusBold.health`, Izin pakai `IconsaxPlusBold.note_2` (atau `document_text`)
    - _Requirements: 16.2, 16.4, 16.5_

  - [x] 5.13 Implement `_StepTypeAndReason` widget
    - Props: `session, type, reason, onTypeChanged, onReasonChanged`
    - Render: `_SelectedSessionBadge` di atas, label "Jenis Izin *" + grid `_TypeTile` 2-item, label "Alasan *" + textarea + counter karakter live
    - Counter: hijau saat ≥ 10 char (trim), abu-abu saat < 10
    - _Requirements: 16.1, 16.2, 16.6, 16.7_

  - [x] 5.14 Implement `_StepEvidence` widget — reuse existing logic
    - Props: `pickedImage, errorText, isUploading, onPick, onRemove`
    - Reuse pattern dari existing `_buildEvidenceSection` extension method:
      - Empty state: upload zone (dashed border `AppColors.primary`, bg `AppColors.primarySurface`, icon + "Tambahkan Foto Bukti" + "JPG / PNG / WEBP, maks 5 MB")
      - Picked state: thumbnail 180px height + tombol X overlay top-right, tombol "Ganti Foto" di bawah
    - Tap zone → `onPick()` → trigger bottom sheet picker (gallery/camera)
    - Show `errorText` jika ada
    - _Requirements: 17.1, 17.2, 17.3_

  - [x] 5.15 Implement `_StepReview` widget
    - Props: `session, type, reason, evidencePath`
    - Render: review card dengan 4 row read-only:
      - "SESI" → `{nama MK} · Pertemuan {N} · {jam}` + sub `{dosen}`
      - "JENIS" → "Sakit" atau "Izin" dengan icon
      - "ALASAN" → full text reason (max 500 char)
      - "LAMPIRAN" → "1 file dilampirkan" atau "Tidak ada lampiran"
    - Pakai `AppCard` radius 14
    - _Requirements: 18.1_

  - [x] 5.16 Implement `_WizardFooter` widget
    - Props: `label, icon, enabled, loading, onTap`
    - Pill button full-width radius 999, padding 13x20, font Plus Jakarta Sans w700 14
    - Background `AppColors.primary`, foreground white, disabled state `withValues(alpha: 0.6)`
    - Loading state: `CircularProgressIndicator` 18x18 putih + label
    - Container parent dengan `AppShadows.fab` (peridiotically when CTA prominent)
    - _Requirements: 14.4_

  - [x] 5.17 Wire `SubmitLeaveRequestScreen` (refactor existing)
    - Replace existing single-form body dengan wizard
    - Stateful (existing `ConsumerStatefulWidget` pattern dipertahankan)
    - State: `_state: WizardState`, methods `_advance()` dan `_goBack()`
    - Use `WillPopScope` / `PopScope` untuk intercept system back: `goBackWizardStep` → kalau `(s, false)` setState else allow pop
    - Body: `Column` → `_StepBar` (header), `Expanded` `_StepContent` (per-step), `_WizardFooter` (footer)
    - `_StepContent` switch by `_state.step` → render `_StepPickSession` / `_StepTypeAndReason` / `_StepEvidence` / `_StepReview`
    - Step 4 footer onTap → call `submitLeaveProvider.submit(...)`, success → snackbar + delay 800ms + `context.pop(true)`, fail → snackbar danger
    - Reuse existing `_pickEvidence(source)`, `_showEvidencePickerSheet()`, `_removeEvidence()` methods
    - Reuse existing `_showSnackbar(message, isError)` method
    - _Requirements: 14.1, 14.2, 14.5, 14.6, 15.1, 16.6, 16.8, 17.4, 17.5, 17.6, 17.7, 17.8, 18.3, 18.4, 18.5, 18.6, 19.1, 19.2, 19.3, 23.3, 25.3, 25.4_

  - [x] 5.18 Verify Submit Leave wizard refactor — run `flutter analyze`
    - cwd: `mypresensi-mobile/`
    - Expected output: "No issues found."
    - Fix all warnings/errors before marking task complete
    - _Requirements: 26.1_

- [x] 6. Checkpoint — Final mobile rebuild verification
  - Ensure all tests pass, ask the user if questions arise.
  - Run `flutter analyze` in `mypresensi-mobile/` one more time across whole project
  - _Requirements: 26.2, 26.3_

- [ ] 7. (Optional) Web `globals.css` token sync
  - [ ]* 7.1 Update `mypresensi-web/app/globals.css` `--color-primary`
    - Update `--color-primary` from `#5483AD` → `#2D86FF`
    - Update derived tokens (`--color-primary-hover`, `--color-primary-dark`, `--color-primary-surface`) sesuai pattern di `docs/ui-research/mockups/_tokens.css`
    - Run `npm run type-check` and `npm run lint` in `mypresensi-web/`
    - Run `npm run build` to verify CSS variables resolve
    - _Requirements: 27.1, 27.2_

- [~] 8. Manual smoke test (user-action)
  - **NOTE**: This task is performed by the user manually, NOT by the coding agent. Marking this task complete is the user's responsibility after they verify visual + integration outcomes per Requirement 28.
  - User SHALL perform smoke test using account from `mypresensi-web/.dev-accounts.md`:
    - (a) Login mahasiswa → tab Beranda dengan dan tanpa sesi aktif (verify hero state, today summary, quick action grid, no AI FAB)
    - (b) Tab Riwayat → verify hero summary, filter chip count, smart-date grouping, tap item → bottom sheet detail (verify swipe-down close, no buttons)
    - (c) Tab Izin → FAB "Ajukan Izin" → wizard 4-step happy path (no evidence) → submit → verify success snackbar + list refresh
    - (d) Wizard 4-step dengan lampiran foto → upload progress visible → submit → verify success
    - (e) Wizard step navigation backward (system back) → verify data preserved
  - User SHALL document results di `dev-log.md` atau `CHANGELOG.md` (entri `[MOD]` per screen)
  - _Requirements: 28.1, 28.2, 28.3_

## Notes

- Tasks marked with `*` are optional. Includes property tests (1.4, 1.6, 3.4, 5.4, 5.5, 5.6, 5.7) for pure-logic helpers, and the optional web token sync (7.1). Property tests provide additional confidence for state machines and grouping algorithms but are not strictly required to ship the UI rebuild — `flutter analyze` and manual smoke test cover the primary verification path.
- Each task references specific requirements via `_Requirements: X.Y_` for traceability.
- Checkpoints (tasks 2, 4, 6) ensure incremental validation between major rebuild stages — they invite user review before proceeding to next screen rebuild.
- Property tests reference design properties via `**Property N: Title**` and `**Validates: Requirements X.Y**` headers as per spec convention.
- Unit tests for visual / widget tree are intentionally NOT included — they would require flutter_test pumpWidget infrastructure that is high cost relative to value for UI fidelity which is better verified via manual smoke test (Property reflection in design.md and prework analysis support this decision).
- Top-level tasks 1, 3, 5 are core implementation and MUST be implemented; sub-tasks within them follow inner implementation/verification structure.
- All implementation MUST follow rules: `02-quality-debugging-verification.md` (verify before claim), `20-mobile-conventions.md` (Riverpod/GoRouter/Dio patterns), `22-mobile-design-system.md` (token + shadow + icon discipline), `03-design-and-libraries.md` (no new dependencies, Bahasa Indonesia copy).
