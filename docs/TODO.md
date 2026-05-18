# MyPresensi — Task & Roadmap

> Terakhir diperbarui: **16 Mei 2026**
> Sumber: 7 sesi audit & development (Mobile UI Refinement, UI/UX Research, Refuse window.confirm, Implement Terlambat, MyPresensi Audit & Enhancement, UI Design and Usability, Roadmap Task Prioritization)

---

## A. Status Completed (Referensi)

Tidak perlu dikerjakan lagi. Tercatat di `CHANGELOG.md` dan `dev-log.md`.

### Roadmap Tier 1-2 — SEMUA CLOSED

| ID | Item | Sesi |
|----|------|------|
| T1-#1 | DioException friendly error mapping (`error_mapper.dart`) | Implement Terlambat |
| T1-#2 | 3-state mobile widgets (`LoadingSkeleton` / `EmptyState` / `ErrorState`) | Mobile UI Refinement |
| T1-#3 | Mobile baca threshold face dari settings API (`faceConfigProvider`) | Implement Terlambat |
| T2-#4 | Hak hapus face data UU PDP (`DELETE /api/mobile/face/me` + UI 2-step) | Mobile UI Refinement |
| T2-#5 | Rate limit per-device (composite key `userId:deviceId` + migration 014) | Mobile UI Refinement |
| T2-#6 | Status "Terlambat" 4-layer (DB → server → UI web → UI mobile) | Implement Terlambat |
| T3-#8 | DB Backup & Recovery Runbook (`docs/runbook/db-recovery.md`) | Mobile UI Refinement |
| **T0-#10** | **Server-side face verification** (POST /face/verify + hapus GET /face/embedding) — fix violation rule 04-security Section B.2 | **Server-Side Face Verification (Kiro)** |
| **T0-#11** | **Revoke `get_at_risk_students` RPC dari anon+authenticated** (migration 018) — fix 2 Supabase advisor `*_security_definer_function_executable` | **At-Risk RPC Revoke Public (Kiro)** |
| **P3-#1** | **Upload bukti izin/sakit** (bucket private `leave-evidence` + endpoint upload + image_picker mobile + signed URL web admin/dosen) — migration 019 | **Leave Evidence Upload (Kiro)** |
| **P3-#3** | **Image picker avatar mobile** (endpoint `/api/mobile/profile/avatar` reuse bucket avatars + camera badge UI tappable) | **Avatar Upload Mobile (Kiro)** |

### Bug Fixes — SEMUA CLOSED

| Bug | Deskripsi |
|-----|-----------|
| BUG-008 | `window.confirm()` → SweetAlert2 (7 file refactored) |
| BUG-009 | QR field mismatch (`sid` vs `session_id`) |
| BUG-010 | Face recognition MobileFaceNet migration (7-frame averaging) |
| BUG-011 | Audit logger mobile context loss (user_id null) |

### Security Hardening — CLOSED

- Migrations 006-014 applied (security hardening → FK indexes → RLS initplan → consolidate policies → late status → device_id audit)
- `session_code` Tier 1 leak di audit_logs → fixed + 829 row sanitized
- Lint cleanup web 17 errors → 0
- Dead code web + mobile dibersihkan
- `.gitignore` 3-tier hardening
- Smoke test `npm run test:smoke` (8/8 PASS, CI-ready)

### Reusable Components — CLOSED

- Web: `<EmptyState />` + `<Pagination />` (7+5 file refactored)
- Mobile: `LoadingSkeleton` / `EmptyState` / `ErrorState` reusable widgets

### UI Mockups — CLOSED (21 mockup + 2 CSS token)

Semua file di `docs/ui-research/mockups/`. Detail: lihat bagian C (Audit Gap).

---

## B. Task Pending — Prioritas

### Prioritas 1 — Aksi Manual (5-15 menit, WAJIB segera)

| # | Task | Estimasi | Catatan |
|---|------|----------|---------|
| 1 | ~~Revoke token lama Supabase~~ | ~~2 menit~~ | ✅ Selesai (user) |
| 2 | **Enable HIBP password protection** | 1 menit | ⚠️ **DEFERRED** — Pro plan only. Toggle grayed out di Free tier. Aktifkan saat upgrade plan. Defense pengganti sudah ada: min length 6, password requirements (lower+upper+digit), rate limit login. |
| 3 | ~~Cleanup backup~~ | ~~1 menit~~ | ✅ File sudah tidak ada (`C:\Users\riki\.codeium\windsurf\mcp_config.json.bak`) — verified 2026-05-16 |

### Prioritas 2 — Mockup → Implementasi Gap (Lihat bagian C)

| # | Screen | Platform | Estimasi | Catatan |
|---|--------|----------|----------|---------|
| 1 | ~~**Live Monitor** (halaman monitor sesi real-time dosen)~~ | Web | ~~4-8 jam~~ | ✅ **Selesai 2026-05-18** — Route `/sesi/[id]/live` + endpoint live-state + geofence ring SVG + KPI bar + activity feed + student grid + tombol di session-list. Spec: `.kiro/specs/live-monitor-dosen/`. Build success. Smoke test 2-window pending user. |
| 2 | ~~**QR Display Presentasi** (fullscreen projector mode)~~ | Web | ~~2-3 jam~~ | ✅ **Selesai 2026-05-18** — Route `/sesi/[id]/qr` + endpoint live-stats + tombol Tampilkan Fullscreen di session-list & sessions-modal. Spec: `.kiro/specs/qr-display-fullscreen/`. Build success. Smoke test pending user. |
| 3 | ~~**Onboarding Mobile** (3-step welcome flow)~~ | Mobile | ~~2-3 jam~~ | ✅ **Selesai 2026-05-18** — Mockup baru `mobile-onboarding.html` + screen Flutter `onboarding_screen.dart` dengan PageView 3 step (Welcome/Cara Pakai/Get Started) + flag SharedPreferences `hasSeenOnboarding` + splash redirect logic. Spec: `.kiro/specs/onboarding-mobile/`. Smoke test cold install pending user. |

### Prioritas 3 — Fitur Backend/Flow

| # | Fitur | Estimasi | Catatan |
|---|-------|----------|---------|
| 1 | ~~Upload bukti izin/sakit~~ | ~~2-3 jam~~ | ✅ **Selesai 2026-05-16** — bucket private + signed URL + image_picker. Spec: `.kiro/specs/leave-evidence-upload/spec.md`. Smoke test pending user. |
| 2 | ~~**Supabase Realtime** untuk live dashboard dosen~~ | ~~4-6 jam~~ | ✅ **Selesai 2026-05-18** — migration 021 enable publication + REPLICA IDENTITY FULL, type definitions, hook `useRealtimeAttendances`. Spec: `.kiro/specs/realtime-attendances-channel/`. Build success. Smoke test 2-window pending user (atau menunggu Phase B2 Live Monitor). |
| 3 | ~~Image picker avatar mobile~~ | ~~1-2 jam~~ | ✅ **Selesai 2026-05-16** — endpoint POST /profile/avatar, ProfileRepository, profile screen tappable avatar dengan camera badge. Spec: `.kiro/specs/avatar-upload-mobile/spec.md`. Smoke test pending user. |

### Prioritas 4 — Production Readiness (Sebelum Demo)

| # | Task | Estimasi | Catatan |
|---|------|----------|---------|
| 1 | **T3-#7: Smoke test E2E HP fisik** (release build) | 1 sesi | Workflow `/release-build` sudah ada. Test: GPS valid → reject fake GPS → face register + verify |
| 2 | **T3-#9: Monitoring & Alerting** | - | Butuh Supabase **Pro plan**. Alert: `mock_location_detected` > 5/menit, `failed_login` > 10/menit |
| 3 | **Crash reporting** (Sentry / Crashlytics) | 2-3 jam | Skip untuk PBL demo kecuali distribusi luas > 10 user |
| 4 | **FCM Push Notification** | 1-2 hari | Firebase project + `firebase_messaging` + server push. Polling cukup untuk demo |

### Prioritas 5 — Nice-to-Have / Portfolio Enhancement

| # | Item | Estimasi | Catatan |
|---|------|----------|---------|
| 1 | Export Excel native `.xlsx` | 2-3 jam | CSV + PDF sudah cukup. Native xlsx via `exceljs` kalau diminta |
| 2 | Bundle analyzer + performance profiling | 30-60 menit | Lighthouse (web) + Flutter DevTools (mobile) untuk data sebelum optimize |
| 3 | TFLite GPU delegate MobileFaceNet | 30 menit | Potensial 2-3x speedup face inference. Belum ada complaint performa |
| 4 | Rate limit migrasi ke DB-backed | 2-3 jam | Saat ini in-memory (OK single Vercel instance). Butuh Redis/DB kalau scale-out |

---

## C. Audit Gap: Mockup vs Implementasi

### Legenda

- ✅ = Sudah diimplementasi
- 🔴 = GAP — mockup ada, implementasi belum
- ℹ️ = Mockup index/referensi, bukan halaman

### Web Mockups (21 file)

| Mockup File | Implementasi | Status |
|-------------|-------------|--------|
| `admin-dashboard.html` | `(dashboard)/dashboard/page.tsx` | ✅ |
| `ai-chat-mockup.html` | Mobile: `ai_chat_screen.dart` + `api/mobile/ai/chat/route.ts` | ✅ |
| `audit-log.html` | `(dashboard)/audit/page.tsx` | ✅ |
| `dosen-dashboard.html` | `(dashboard)/dashboard/page.tsx` (role-based view) | ✅ |
| `dosen-list.html` | `(dashboard)/dosen/page.tsx` | ✅ |
| `index.html` | Gallery mockup (bukan halaman app) | ℹ️ |
| **`live-monitor.html`** | **Tidak ada halaman dedicated** | 🔴 |
| `login-mockup.html` | `(auth)/login/page.tsx` | ✅ |
| `mahasiswa-list.html` | `(dashboard)/mahasiswa/page.tsx` | ✅ |
| `matkul-list.html` | `(dashboard)/matakuliah/page.tsx` | ✅ |
| **`qr-display.html`** | **QR inline di `session-list.tsx`, bukan fullscreen** | 🔴 |
| `rekap.html` | `(dashboard)/rekap/page.tsx` | ✅ |
| `sesi-list.html` | `(dashboard)/sesi/page.tsx` | ✅ |
| `settings.html` | `(dashboard)/settings/page.tsx` | ✅ |

### Mobile Mockups (7 file)

| Mockup File | Implementasi | Status |
|-------------|-------------|--------|
| `mobile-leave-request.html` | `leave_requests/screens/` (2 screen) + API | ✅ |
| `mobile-login.html` | `auth/screens/login_screen.dart` | ✅ |
| `mobile-mockup.html` | `home/screens/home_screen.dart` | ✅ |
| `mobile-notifications.html` | `notifications/screens/notification_screen.dart` | ✅ |
| `mobile-profile.html` | `profile/screens/profile_screen.dart` | ✅ |
| `mobile-riwayat.html` | `history/screens/history_screen.dart` | ✅ |
| **`mobile-splash-onboarding.html`** | **Splash ✅ — Onboarding ❌** | 🔴 |

### Halaman di Kode Tanpa Mockup (Sudah Diimplementasi)

Halaman-halaman ini sudah dibangun langsung tanpa mockup terpisah:

**Web:**
- `(dashboard)/at-risk/page.tsx` — Halaman mahasiswa berisiko alpa
- `(dashboard)/export/page.tsx` — Export CSV/PDF
- `(dashboard)/izin/page.tsx` — Manajemen izin/sakit (admin/dosen)
- `(dashboard)/profil/page.tsx` — Profil user
- `(auth)/change-password/page.tsx` — Ganti password

**Mobile:**
- `change_password_screen.dart` — Ganti password
- `scan_qr_screen.dart` — Scan QR camera
- `attendance_result_screen.dart` — Hasil submit presensi
- `face_registration_screen.dart` — Registrasi wajah
- `face_verification_screen.dart` — Verifikasi wajah

---

## D. Ringkasan Gap

| Gap | Deskripsi | Impact | Effort |
|-----|-----------|--------|--------|
| **Live Monitor** | Halaman monitoring sesi real-time dosen dengan geofence ring, student dots, activity feed | High (fitur wow untuk demo) | 4-8 jam |
| **QR Display Presentasi** | Fullscreen dark-mode QR untuk proyektor kelas | Medium (UX dosen saat mengajar) | 2-3 jam |
| **Onboarding Mobile** | 3-step welcome flow saat first install | Low (nice-to-have UX) | 2-3 jam |

---

## E. Rekomendasi Urutan Kerja

1. **Aksi manual Prioritas 1** — terutama revoke token Supabase (security)
2. **QR Display Presentasi** — effort rendah, high-impact UX untuk dosen saat demo di kelas
3. **Upload bukti izin** — fitur paling dekat feature-complete (schema sudah siap)
4. **Live Monitor** — fitur showcase terbesar, tapi butuh Supabase Realtime
5. **Onboarding Mobile** — polish terakhir sebelum rilis
6. **Release build + smoke test HP fisik** — milestone sebelum demo ke dosen pembimbing
