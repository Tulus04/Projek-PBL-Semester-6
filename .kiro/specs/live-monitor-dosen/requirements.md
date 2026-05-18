# Requirements Document

## Introduction

Spec ini menambahkan **halaman Live Monitor sesi presensi untuk dosen** di route `/sesi/[id]/live`. Showcase fitur paling impressive untuk PBL portfolio: dosen membuka halaman saat mengajar, melihat geofence ring SVG dengan dot mahasiswa muncul real-time saat scan QR (<2 detik), activity feed scroll, KPI cards animasi counter, student grid dengan filter status. Reference visual: Stripe Atlas Live, Linear Insights, Supabase Realtime Dashboard. Mockup: `docs/ui-research/mockups/live-monitor.html`.

Ini Phase **B2** dari roadmap (TODO.md Prioritas 2 nomor 1: "Live Monitor"). Prerequisite Phase B1 (QR Display) dan Phase C1 (Realtime infrastructure) **sudah selesai** sebelum spec ini.

User decisions yang sudah diputuskan:
- Geofence visualization = SVG circle stylized (bukan Leaflet/Mapbox)
- Akses = sub-route `/sesi/[id]/live` per sesi spesifik

Effort estimasi: **5-7 jam**.

## Glossary

- **Live_Monitor_Page**: Server Component baru di `app/(dashboard)/sesi/[id]/live/page.tsx`.
- **Live_Monitor_Client**: Client Component `live-monitor-client.tsx` — interactive UI dengan Realtime subscription.
- **Live_State_Endpoint**: Endpoint baru `GET /api/admin/sessions/[id]/live-state` — return full state untuk initial fetch + reconnect refresh.
- **Geofence_Ring**: Komponen SVG dengan 3 concentric circles (radius 50m/100m/150m) yang menampilkan dot mahasiswa positioned via Haversine bearing.
- **Student_Dot**: Lingkaran SVG kecil yang merepresentasikan mahasiswa di geofence ring. Warna sesuai status (success=hadir, info=telat, warning=izin/sakit, danger=ditolak/alpa, gray=belum).
- **Activity_Feed**: List 20 event terbaru, prepend saat ada INSERT Realtime.
- **KPI_Bar**: Row 4 cards di top: Hadir / Telat / Belum / Total. Animated counter saat update.
- **Student_Grid**: Grid mahasiswa terdaftar di MK (dari enrollments) dengan filter chip 5 status.
- **Status_Badge**: Pill badge "LIVE - Sesi Aktif" dengan pulse-dot animation.
- **End_Session_Button**: Tombol "Akhiri Sesi" yang trigger `toggleSessionAction` server action.
- **useRealtimeAttendances**: Hook dari Phase C1 di `app/lib/realtime/use-realtime-attendances.ts`.
- **Filter_Chip**: 5 chip filter status (Semua/Hadir/Telat/Belum/Ditolak) untuk Student_Grid.
- **Polar_Position**: Algorithm computeDotPosition (lihat design.md §Algorithm 1) — convert lat/lng ke pixel SVG.
- **requireRole + canAccessCourse**: Helper dari `app/lib/auth-guard.ts` (existing).

## Requirements

### Requirement 1: Route + Auth Gate

#### Acceptance Criteria

1. THE Web_App SHALL menyediakan route baru `/sesi/[id]/live` dengan page Server Component di `app/(dashboard)/sesi/[id]/live/page.tsx`.
2. THE route SHALL berada di route group `(dashboard)` (sidebar + topbar tetap visible) — BUKAN di `(qr-projector)`.
3. WHEN unauthenticated user akses, THE route SHALL redirect ke `/login` (via middleware existing).
4. WHEN mahasiswa akses, THE route SHALL redirect ke `/login` atau halaman error (per `requireRole`).
5. WHEN dosen non-owner akses session bukan miliknya, THE route SHALL redirect ke `/sesi?error=no-access` via `canAccessCourse` check.
6. WHEN admin akses, THE route SHALL allow tanpa ownership check (admin global).

### Requirement 2: Initial State Fetch SSR

#### Acceptance Criteria

1. THE Live_Monitor_Page SHALL fetch session detail via single JOIN query (sessions + courses + dosen profile).
2. THE Live_Monitor_Page SHALL fetch initial students + attendances + stats via helper `fetchInitialLiveState()` parallel via `Promise.all`.
3. THE initial students list SHALL = enrollments di course + JOIN attendances (untuk status filling).
4. WHEN session tidak ditemukan, THE Live_Monitor_Page SHALL return `notFound()` (404).
5. THE Live_Monitor_Page SHALL pass props lengkap ke Live_Monitor_Client tanpa client-side re-fetch.

### Requirement 3: Live State Endpoint

#### Acceptance Criteria

1. THE Web_App backend SHALL menyediakan endpoint `GET /api/admin/sessions/[id]/live-state` di file `app/api/admin/sessions/[id]/live-state/route.ts`.
2. THE endpoint SHALL `requireRole(['admin', 'dosen'])` + `canAccessCourse` ownership check.
3. THE endpoint SHALL menerapkan rate limit 30 req/menit per (user, session).
4. THE endpoint SHALL return shape `{ students: StudentLiveRow[], stats: LiveStats }`:
   - `StudentLiveRow`: student_id, full_name, nim, avatar_url, status, scanned_at, student_lat, student_lng, distance_meters, is_mock_location, face_confidence
   - `LiveStats`: hadir, terlambat, belum, total, ditolak (mock_location)
5. THE endpoint SHALL TIDAK mengexpose session_code di response.
6. WHEN auth fail → 401, ownership fail → 403, session not found → 404, rate limit → 429.

### Requirement 4: Realtime Subscription

#### Acceptance Criteria

1. THE Live_Monitor_Client SHALL `useRealtimeAttendances({ sessionId, onInsert, onStatusChange })` dari hook Phase C1.
2. WHEN INSERT event diterima, THE client SHALL update state students Map (by student_id), increment stats, prepend activity feed.
3. WHEN status `CHANNEL_ERROR` atau `TIMED_OUT`, THE client SHALL menampilkan banner "Sync terganggu, mencoba reconnect".
4. WHEN status balik ke `SUBSCRIBED` setelah error, THE client SHALL re-fetch `/live-state` untuk close gap events selama disconnect.
5. WHEN client unmount, THE Realtime subscription SHALL cleanup via hook (Phase C1 sudah handle).

### Requirement 5: Geofence Ring Visualization

#### Acceptance Criteria

1. THE Live_Monitor_Client SHALL menampilkan SVG geofence stage berukuran ~380px persegi dengan 3 concentric circles: ring 150m outer (radius 50% of stage), 100m middle, 50m inner.
2. THE rings SHALL menggunakan dashed border `stroke-dasharray` dengan stroke color `AppColors.primary` 0.4 alpha (atau setara).
3. THE center point SHALL ditandai marker icon `lucide:map-pin` color primary + label "Pusat Kampus" small text.
4. THE Student_Dot SHALL render untuk setiap mahasiswa yang sudah scan (status hadir/terlambat/ditolak) dengan:
   - Posisi via algorithm `computeDotPosition` (Polar coordinates dari Haversine bearing)
   - Color sesuai status: success (hadir) / info (telat) / danger (ditolak/mock_location)
   - Outer ring small saat scan baru (animation pulse 1 detik)
   - Tooltip on hover: nama mahasiswa + jam scan + distance meter
5. WHERE distance > 150m (di luar ring), THE Student_Dot SHALL render di tepi ring 150m dengan outline danger.
6. WHERE distance > 300m (terlalu jauh), THE Live_Monitor_Client SHALL menampilkan banner kecil "X mahasiswa terlalu jauh, tidak ditampilkan di peta".
7. THE Student_Dot positioning SHALL pure deterministic (Property 5 design) — sama input GPS = sama output pixel.

### Requirement 6: KPI Bar

#### Acceptance Criteria

1. THE Live_Monitor_Client SHALL menampilkan KPI_Bar di header dengan 4 cards: Hadir, Telat, Belum, Total.
2. THE KPI cards SHALL menggunakan KPI icon style existing (lucide icon + count + label).
3. WHEN stats berubah (dari Realtime event), THE counter SHALL animate count-up dari old → new value dengan duration 800ms (manual setInterval ms-stepping, no library).
4. THE Total card SHALL display jumlah enrollments (tidak berubah selama session).

### Requirement 7: Activity Feed

#### Acceptance Criteria

1. THE Live_Monitor_Client SHALL menampilkan Activity_Feed sidebar dengan list scrollable max 20 event.
2. WHEN INSERT event Realtime diterima, THE client SHALL prepend ke top (newest first) dengan animation slide-in 300ms.
3. THE event item SHALL display: avatar mahasiswa (atau initial), nama, status badge, timestamp (format relatif "2 menit lalu" atau jam absolut).
4. WHEN feed mencapai cap 20, THE oldest event SHALL slide out dari bottom.
5. WHERE feed empty (belum ada scan), THE feed SHALL menampilkan empty state "Menunggu mahasiswa scan QR..." dengan icon clock.

### Requirement 8: Student Grid + Filter

#### Acceptance Criteria

1. THE Live_Monitor_Client SHALL menampilkan Student_Grid dengan card per mahasiswa enrolled di MK.
2. THE Student_Card SHALL display: avatar, nama, NIM, status badge.
3. THE Filter_Chip SHALL memiliki 5 chip: Semua, Hadir, Telat, Belum, Ditolak. Active state filled primary, inactive outline.
4. WHEN user klik chip, THE grid SHALL filter sesuai status. Chip "Semua" reset filter.
5. THE chip SHALL display count per status (e.g. "Hadir (22)").
6. WHERE filter status menghasilkan list kosong, THE grid SHALL menampilkan empty state ramah.
7. WHEN status mahasiswa berubah dari "belum" ke "hadir" via Realtime event, THE Student_Card SHALL animate transition (pulse highlight 1 detik) untuk visual feedback.

### Requirement 9: Status Badge + End Session

#### Acceptance Criteria

1. THE Live_Monitor_Client SHALL menampilkan Status_Badge "LIVE - Sesi Aktif" dengan pulse-dot animasi di topbar.
2. WHEN session.is_active berubah ke false, THE badge SHALL update ke "Sesi Berakhir" + tombol "Kembali ke Daftar Sesi".
3. THE Live_Monitor_Client SHALL menampilkan tombol End_Session_Button "Akhiri Sesi" dengan icon stop-circle danger.
4. WHEN user klik tombol, THE client SHALL menampilkan SweetAlert2 confirm "Akhiri sesi sekarang? Mahasiswa tidak akan bisa scan lagi."
5. WHEN user konfirmasi, THE client SHALL panggil `toggleSessionAction(sessionId)` server action.
6. WHEN action sukses, THE client SHALL `router.replace('/sesi')` setelah delay 500ms.
7. WHEN action fail, THE client SHALL menampilkan toast danger via `@/lib/swal`.

### Requirement 10: OTP Display Mini

#### Acceptance Criteria

1. THE Live_Monitor_Client SHALL menampilkan OTP code 6-digit + countdown timer mini di topbar (read-only, untuk dosen yang lupa).
2. THE countdown SHALL use same algorithm computeCountdown (Phase B1) dengan setInterval 1s.
3. THE Live_Monitor_Client SHALL menampilkan tombol "Refresh Kode" small icon yang trigger `refreshSessionCode(sessionId)` server action existing.
4. WHEN refresh sukses, THE client SHALL `router.refresh()` untuk fetch session terbaru.

### Requirement 11: Tombol Buka Live Monitor di /sesi page

#### Acceptance Criteria

1. THE `session-list.tsx` SHALL menampilkan tombol "Buka Live Monitor" di action button row active session card (kondisi `session.is_active`).
2. THE tombol SHALL menggunakan tag `<Link>` dengan `href="/sesi/${id}/live"` (NAVIGATE same window, BUKAN `target="_blank"` — Live Monitor untuk dosen primary monitor).
3. THE tombol SHALL menggunakan icon Lucide `Activity` atau `Radio` plus label "Live Monitor".
4. THE tombol SHALL menggunakan style outline secondary (mirip tombol Tampilkan Fullscreen Phase B1).

### Requirement 12: Bahasa Indonesia Copy

#### Acceptance Criteria

1. THE Live_Monitor_Client SHALL menampilkan semua label visible dalam Bahasa Indonesia.
2. THE Live_State_Endpoint SHALL return error dalam Bahasa Indonesia.
3. THE SweetAlert confirm SHALL menggunakan copy ramah Bahasa Indonesia.

### Requirement 13: Visual Fidelity

#### Acceptance Criteria

1. THE Live_Monitor_Client SHALL match mockup `live-monitor.html` dalam: layout 2-col split (geofence ring kiri 480px + main content kanan), KPI bar gradient subtle, activity feed sidebar, student grid 4-col responsive.
2. THE component SHALL menggunakan design tokens dari `globals.css` (`--color-primary`, `--color-success`, etc).
3. THE Status_Badge live-pulse animation SHALL match Phase B1 pattern (green dot scale + opacity).

### Requirement 14: Verification Gate

#### Acceptance Criteria

1. WHEN engineer menyelesaikan endpoint, THE engineer SHALL `npm run type-check` + `npm run lint` pass.
2. WHEN engineer menyelesaikan whole feature, THE engineer SHALL `npm run build` exit 0.

### Requirement 15: Manual Smoke Test

#### Acceptance Criteria

1. WHEN whole implementation complete, THE pemilik produk SHALL smoke test:
   - (a) Login dosen → buka /sesi → klik tombol "Live Monitor" pada active session
   - (b) Window baru di tab yang sama (navigate) ke /sesi/[id]/live
   - (c) Verify visual: geofence ring 380px center, 3 concentric circles, KPI bar 4 cards, activity feed empty state, student grid dengan semua mahasiswa status "Belum"
   - (d) Window B: mahasiswa scan QR di mobile emulator
   - (e) Verify Window A: dot muncul di geofence ring dalam <2 detik, activity prepend, KPI Hadir +1, student card status berubah ke Hadir dengan animation pulse
   - (f) Repeat dengan 2-3 mahasiswa lain, beberapa status hadir, beberapa terlambat (kalau session sudah lewat threshold)
   - (g) Test mock GPS: mahasiswa pakai Fake GPS app → verify dot status "Ditolak" merah, banner danger
   - (h) Klik "Akhiri Sesi" → confirm modal → action sukses → redirect /sesi
2. THE smoke test SHALL menggunakan akun dari `mypresensi-web/.dev-accounts.md`.

### Requirement 16: Out of Scope

#### Acceptance Criteria

1. THE spec ini SHALL TIDAK pakai Leaflet/Mapbox untuk real map — pure SVG sesuai user decision.
2. THE spec ini SHALL TIDAK include chat dosen → mahasiswa.
3. THE spec ini SHALL TIDAK upgrade Phase B1 QR Display ke Realtime (separate spec future).
4. THE spec ini SHALL TIDAK ada onboarding tour fitur baru.
5. THE spec ini SHALL TIDAK responsive untuk mobile (<1024px) — Live Monitor untuk laptop dosen.
