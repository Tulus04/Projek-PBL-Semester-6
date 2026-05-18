# MyPresensi — Security Architecture v7 (Honest Reality Check)

> **Status**: FINAL — siap eksekusi
> **Source**: Diskusi audit security Kiro × Riki, 17 Mei 2026
> **Replaces**: Plan v6 (`docs/plans/implementation_plan.md`) — over-promise security claims
> **Verifikasi**: Semua keputusan di file ini sudah cross-reference dengan code aktual (`submit/route.ts`, `face-utils.ts`, migrations 001-019)

---

## Filosofi Perubahan v6 → v7

Plan v6 menyebut "6 layer security" + banyak fitur enterprise (freeRASP, AES-256, cert pinning, liveness challenge, WiFi SSID, teleportation, cell tower). **Kenyataannya hanya 2-3 layer yang benar-benar implementasi**. V7 ini:

1. **HONEST**: Hanya klaim apa yang benar-benar di-implement
2. **REALISTIC**: Cocok skala PBL Politani Samarinda (~50 mahasiswa per kelas)
3. **DEFENSE IN DEPTH**: 3 layer yang cover threat **berbeda**, bukan belt-and-suspenders

**Threat model yang dipakai**: 95% serangan = mahasiswa malas dengan trik basic (titip absen, fake GPS app, screenshot QR). BUKAN APT/state-sponsored.

---

## DECISION ITEMS YANG MASIH PERLU KONFIRMASI

> ⚠️ **Sebelum mulai implementasi, konfirmasi 2 item di bawah ini.**

### Pending Decision #1: Mekanisme QR

User menyebut 2 hal yang **mutually exclusive** di diskusi:
- **A1**: QR rotating tiap 5 detik (TOTP-like)
- **A2**: QR tanpa OTP (statis, 1 kode per sesi)

**Pilihan akhir**: ⏳ **Belum ditentukan**

| Option | Pro | Con |
|--------|-----|-----|
| **A1**: Rolling 5s + tolerance ±2 window (15s effective) | Anti-share screenshot kuat | Risk false reject saat network lambat |
| **A2**: QR statis (session_id only) | Simpel, no rotation logic | Hilangkan tool dosen "refresh kode"; share screenshot OK kalau face wajib |
| **A3** (rekomendasi Kiro): Rolling **30 detik** + tolerance ±1 (industry standard, Google Authenticator pattern) | Realistic untuk user flow 11-22 detik | Anda sudah menolak 30s |

### Pending Decision #2: Edge Case "Kamera Mahasiswa Rusak"

User mengusulkan "login dari HP teman". Kiro push back keras (security risk credential sharing).

**Pilihan akhir**: ⏳ **Belum ditentukan**

| Option | Pro | Con |
|--------|-----|-----|
| **B1**: Dosen manual override via web dashboard (rekomendasi Kiro) | Audit trail jelas, no credential sharing, abuse mudah detect | Ada friction (mahasiswa lapor dosen) |
| **B2**: Login dari HP teman (sesuai usulan user) | Simpler dari sisi mahasiswa | Credential sharing menjadi norm, audit kacau, threat fundamental |
| **B3**: Toggle "skip face one-time" oleh dosen per mahasiswa | Middle ground, tidak butuh credential share | Effort UI dosen lebih kompleks |

---

## Layer 1: QR Code (Session-Specific)

**Implementasi (placeholder, tergantung Pending Decision #1)**:
- Encode `session_id` + `code` (kalau A1) atau cuma `session_id` (kalau A2)
- Mobile scan via `mobile_scanner` package (sudah ada)
- Display di proyektor dosen (web SSR refresh)

**Threat coverage**:
- ✅ Anti replay attack (kombinasi rolling + duplicate check)
- ✅ Session-specific binding (bukan QR global app)
- ⚠️ Anti-share screenshot — **tergantung kombinasi dengan face wajib**

**Effort**: 4-8 jam tergantung pilihan A1/A2

---

## Layer 2: GPS + Mock Detection

### Sudah Implementasi (KEEP)

- ✅ `Geolocator` untuk lat/lng (`geolocator ^14.0.2`)
- ✅ `Position.isMocked` flag → reject 403 di backend
- ✅ Server-side Haversine distance calculation
- ✅ Radius default 150m (dari `settings.geofence_radius_meters`)
- ✅ Mode-aware: offline = enforce, online = skip
- ✅ Audit log `mock_location_detected`

### TIDAK Diimplementasi (skip dari Plan v6)

| Klaim Plan v6 | Alasan Skip |
|---------------|-------------|
| WiFi SSID matching `Politani_Samarinda_University` | False positive tinggi (mahasiswa data seluler) + bypass mudah (50m WiFi range) + operational nightmare (WiFi sering down) |
| Teleportation detection (>100 km/h reject) | Edge case bias (motor 80 km/h), GPS jitter indoor 50-100m |
| GPS vs Cell Tower cross-ref | Privacy concern UU PDP, iOS unsupported, akurasi 5-10 km tidak cukup untuk radius 150m |

---

## Layer 3: Face Recognition (WAJIB di Mode Offline)

### Keputusan Final

- **Mode offline (tatap muka)**: Face match **WAJIB** (gate)
- **Mode online (daring)**: Face **optional** (skip OK)
- Threshold cosine similarity **0.65** (dari `settings.face_confidence_threshold`)
- Embedding **192-D** (MobileFaceNet, bukan 128D seperti klaim v6)
- Backend validate via `/api/mobile/face/verify` (sudah ada — T0-#10 closed)
- Setting `face_verification_mode` (migration 003) **dipakai aktual** (sebelumnya dead config)

### Mahasiswa Belum Register Wajah

- Tidak langsung implementasi gate face di submit → first redirect ke registrasi wajah
- Endpoint `POST /api/mobile/face/register` (sudah ada)
- Mobile flow: deteksi `is_face_registered = false` → tampilkan dialog "Wajah belum terdaftar, daftar dulu" → arahkan ke `face_registration_screen`

### TIDAK Diimplementasi (skip dari Plan v6)

| Klaim Plan v6 | Alasan Skip |
|---------------|-------------|
| Liveness Active Challenge (kedip + senyum random urutan) | Mudah di-bypass dengan video real-time. Implementasi server-side liveness butuh ML model spesialis (Onfido/Jumio level) |
| Texture analysis | Same — butuh model deep learning yang bukan PBL scope |
| Embedding AES-256 encryption | Supabase encrypted at rest (default) + RLS sudah cukup proteksi |

### Liveness yang DITERIMA (basic)

- ML Kit `google_mlkit_face_detection` deteksi wajah real-time
- Cek `face.landmarks` ada (bukan static foto buram tanpa landmark)
- TIDAK pakai active challenge (kedip-senyum random)
- Cuma "presence detection": ada wajah yang ML Kit recognize sebagai wajah real

---

## Status Kehadiran (Final)

5 enum sesuai DB schema (migration 001 + migration 014):

| Status | Color | Trigger |
|--------|-------|---------|
| `hadir` 🟢 | Success green | Verified semua layer, dalam toleransi waktu |
| `terlambat` 🟡 | Info blue | Verified tapi >15 menit dari `started_at` (auto-classify, threshold dari `settings.late_threshold_minutes`) |
| `izin` 🔵 | Warning gold | Disetujui dosen via review |
| `sakit` 🟠 | Warning gold | Disetujui dosen + lampiran (kalau ada) |
| `alpa` 🔴 | Danger red | Tidak hadir, tidak ada keterangan, sesi sudah ditutup |

---

## Bottom Navigation Mobile (Final)

5 tab konsisten lintas screen:

| Tab | Icon | Target |
|-----|------|--------|
| Beranda | `solar:home-2-bold-duotone` | Home dashboard |
| Riwayat | `solar:clipboard-list-bold-duotone` | History kehadiran |
| Izin | `solar:document-text-bold-duotone` | Riwayat & ajukan izin |
| Notifikasi | `solar:bell-bold-duotone` | Inbox |
| Profil | `solar:user-bold-duotone` | Settings |

**Sudah konsisten di mockup**: home, mockup (showcase), riwayat, notifications, my-leave-requests, profile. **PERLU dicek**: ai-chat, login, splash-onboarding (sebagian flow tanpa bottom nav OK).

---

## Implementasi Sequence (Saran Urutan Kerja)

### Phase 1 — Document Honest Update (2-3 jam)

**Files to update**:
- `docs/plans/implementation_plan.md` v6 → v7
  - Hapus klaim 6-layer security
  - Tulis 3-layer realistic (QR + GPS + Face)
  - Hapus klaim: WiFi SSID, teleportation, cell tower, freeRASP, AES-256, cert pinning, liveness active challenge
  - Update embedding 128D → 192D
  - Update bottom nav 4 tab → 5 tab
  - Update status 4 → 5 (+ terlambat)
  - Update dosen platform "Mobile App" → "Web only"

- `workflow_mypresensi.md`
  - Diagram Mermaid security flow → 3 layer
  - Status kehadiran tabel → 5 enum
  - Workflow dosen → web only
  - Hapus block "6 layer anti fake GPS" jadi 2 layer

**Verifikasi**: Cross-check setiap klaim di plan dengan code aktual sebelum write.

---

### Phase 2 — Backend Face WAJIB di Mode Offline (3-4 jam)

**File**: `mypresensi-web/app/api/mobile/attendance/submit/route.ts`

**Logika tambahan setelah GPS check, sebelum insert**:

```typescript
// Cek apakah face wajib
const { data: modeSetting } = await adminClient
  .from('settings')
  .select('value')
  .eq('key', 'face_verification_mode')
  .maybeSingle()

const faceMode = modeSetting?.value ?? 'optional'
const isFaceRequired = (faceMode === 'required') || (faceMode === 'optional' && session.mode === 'offline')

if (isFaceRequired) {
  // Cek mahasiswa sudah register wajah
  const { data: profile } = await adminClient
    .from('profiles')
    .select('is_face_registered')
    .eq('id', user.id)
    .single()

  if (!profile?.is_face_registered) {
    return errorResponse('Wajah belum terdaftar. Buka Profil → Daftar Wajah dulu.', 403)
  }

  // Validasi face match
  if (!input.is_face_matched) {
    await logAudit({
      action: 'face_mismatch_reject',
      userId: user.id,
      ipAddress,
      details: { session_id, face_confidence: input.face_confidence }
    })
    return errorResponse('Verifikasi wajah gagal. Coba di tempat lebih terang.', 403)
  }

  // Cek confidence threshold
  const { data: threshSetting } = await adminClient
    .from('settings')
    .select('value')
    .eq('key', 'face_confidence_threshold')
    .maybeSingle()

  const threshold = parseFloat(threshSetting?.value ?? '0.65')
  if ((input.face_confidence ?? 0) < threshold) {
    return errorResponse(
      `Tingkat kecocokan wajah terlalu rendah (${Math.round((input.face_confidence ?? 0) * 100)}%). Coba lagi.`,
      403
    )
  }
}
```

**Migration tambahan** (kalau perlu):
- Pastikan setting `face_verification_mode` exists (migration 003 sudah ada)
- Pastikan setting `face_confidence_threshold = 0.65` exists (migration 005 sudah ada)

**Mobile**: Update `attendance_submit_service.dart` untuk handle 403 face errors dengan UX friendly message.

**Verifikasi**:
- Manual QA: register wajah → submit OK
- Manual QA: tanpa register wajah, submit di mode offline → reject 403 + arahkan ke registrasi
- Manual QA: face mismatch → reject 403
- Manual QA: face di mode online → tetap accept tanpa face

---

### Phase 3 — QR Architecture (PENDING DECISION #1)

**Sub-phase 3A — Kalau pilih A1 (Rolling 5s)** (4-6 jam):

```sql
-- Migration: tambah column untuk TOTP-like seed
ALTER TABLE sessions ADD COLUMN session_code_seed TEXT;
```

**Backend function**:
```typescript
function generateRollingCode(seed: string, windowSeconds: number = 5): string {
  const window = Math.floor(Date.now() / 1000 / windowSeconds)
  const hash = crypto.createHmac('sha256', seed).update(window.toString()).digest('hex')
  return parseInt(hash.substring(0, 8), 16).toString().padStart(6, '0').substring(0, 6)
}

function validateRollingCode(seed: string, submittedCode: string, tolerance: number = 2): boolean {
  for (let offset = 0; offset <= tolerance; offset++) {
    const window = Math.floor(Date.now() / 1000 / 5) - offset
    const hash = crypto.createHmac('sha256', seed).update(window.toString()).digest('hex')
    const expectedCode = parseInt(hash.substring(0, 8), 16).toString().padStart(6, '0').substring(0, 6)
    if (expectedCode === submittedCode) return true
  }
  return false
}
```

**Web display**: SSE atau polling 1s untuk refresh QR setiap 5s
**Mobile**: tetap mobile_scanner, no change needed

**Sub-phase 3B — Kalau pilih A2 (Statis)** (1-2 jam):
- Hapus logic rotating
- QR encode `session_id` only
- Validation: `session_id` valid + `is_active=true`
- Tombol dosen "Refresh Kode" jadi "Akhiri & Buat Sesi Baru" (drastic)

---

### Phase 4 — Manual Override Dosen (PENDING DECISION #2)

**Kalau pilih B1 (Dosen Manual Override)** (3-4 jam):

```sql
-- Migration
ALTER TABLE attendances ADD COLUMN is_manual_override BOOLEAN DEFAULT FALSE;
ALTER TABLE attendances ADD COLUMN override_reason TEXT;
ALTER TABLE attendances ADD COLUMN override_by UUID REFERENCES profiles(id);
```

**Endpoint baru**: `POST /api/web/attendance/manual-approve`
- Auth: requireRole(['dosen', 'admin'])
- Input: { session_id, student_id, reason }
- Validasi: dosen ownership of session
- Insert attendance dengan is_manual_override=true + audit log

**Web UI**: Di sesi aktif dashboard dosen, tombol "Tandai Hadir Manual" per mahasiswa yang belum absen.

**Audit log**: action `manual_attendance_override` + alasan + dosen approver.

**Kalau pilih B2 (Login HP teman)**: ⚠️ Saya rekomendasi **JANGAN**. Risk credential sharing terlalu tinggi. Tapi kalau user tetap pilih, perlu:
- Update auth flow untuk allow login multiple device (currently single-device-bound mungkin)
- Audit log device fingerprint anomaly
- Dokumentasi explicit risk untuk dosen pembimbing

**Kalau pilih B3 (Skip face one-time)**: middle ground, butuh:
- Setting per (session_id, student_id) "face_skip_until"
- UI dosen tap "Allow tanpa face untuk Mahasiswa X sesi ini"
- Backend cek setting saat validate face

---

## Threat Model Coverage Matrix

### Yang TER-COVER

| Threat Scenario | Prevented By | Severity |
|-----------------|--------------|----------|
| Mahasiswa absen dari kos | GPS (Layer 2) | HIGH |
| Fake GPS app | Mock detection (Layer 2) | HIGH |
| Screenshot QR + share via WA | Rolling QR (Layer 1, kalau A1) ATAU Face match (Layer 3) | MEDIUM |
| Titip absen ke teman dengan HP teman | Face match wajib (Layer 3) | HIGH |
| Replay attack (intercept payload) | Duplicate check + Rolling QR | LOW (advanced threat) |
| Mahasiswa absen sesi yang sudah expired | Session active check | HIGH |
| Submit kode sesi yang berbeda (typo) | session_code validation | HIGH |
| Mahasiswa kamera rusak | Manual override dosen (Layer 4 — Phase 4) | LOW |

### Yang TIDAK TER-COVER (Acceptable Risk)

| Threat | Why NOT Covered | Mitigation |
|--------|-----------------|------------|
| Attack via rooted device | freeRASP skipped (low ROI PBL) | Audit log device anomaly, dosen review |
| MITM attack public WiFi | Cert pinning skipped (no real threat di kampus) | HTTPS default sudah cukup |
| Mahasiswa fake video face real-time | Active liveness skipped (mudah di-bypass anyway) | Manual review dosen kalau anomali |
| Mahasiswa bolos online lecture | Sengaja: face optional di mode online | Trust dosen kelas online |
| Database breach exfil embedding | Dianggap covered RLS + Supabase encryption at rest | RLS strict + audit log |

---

## File Yang Perlu Dimodifikasi (Summary)

### Phase 1 (docs)
- `docs/plans/implementation_plan.md` (rewrite v6 → v7)
- `workflow_mypresensi.md` (update diagrams + status table)

### Phase 2 (backend + mobile)
- `mypresensi-web/app/api/mobile/attendance/submit/route.ts` (face wajib logic)
- `mypresensi-mobile/lib/features/attendance/services/attendance_submit_service.dart` (handle 403 face errors)
- `mypresensi-mobile/lib/features/attendance/screens/scan_qr_screen.dart` (flow update)

### Phase 3 — Sub A1 (kalau pilih rolling)
- New migration: `020_rolling_qr_seed.sql`
- `mypresensi-web/app/lib/actions/sessions.ts` (TOTP-like generation)
- `mypresensi-web/app/api/mobile/attendance/submit/route.ts` (validate rolling code)
- `mypresensi-web/app/(dashboard)/sesi/qr-display.tsx` (SSE/polling refresh)

### Phase 3 — Sub A2 (kalau pilih statis)
- `mypresensi-web/app/lib/actions/sessions.ts` (simplify — no OTP)
- `mypresensi-web/app/api/mobile/attendance/submit/route.ts` (remove session_code validation)

### Phase 4 (kalau pilih B1)
- New migration: `021_manual_attendance_override.sql`
- New endpoint: `mypresensi-web/app/api/web/attendance/manual-approve/route.ts`
- Web UI: `mypresensi-web/app/(dashboard)/sesi/[id]/active-session-monitor.tsx` (tombol manual approve)

---

## Rules & Workflows yang HARUS Dipatuhi

Semua eksekusi WAJIB cross-reference rules ini:
- `.kiro/steering/04-security-and-privacy.md` (UU PDP, Tier classification)
- `.kiro/steering/02-quality-debugging-verification.md` (verify before claim)
- `.kiro/steering/14-web-supabase-patterns.md` (RLS, query patterns)
- `.kiro/steering/13-web-nextjs-patterns.md` (server vs client, route handlers)
- `.kiro/steering/05-testing-and-release.md` (commit format, CHANGELOG)

Workflow yang relevan:
- `.kiro/steering/workflows/add-supabase-migration.md` (untuk Phase 3, 4)
- `.kiro/steering/workflows/add-mobile-api-endpoint.md` (untuk Phase 4)

---

## Status File ini

**Tanggal**: 17 Mei 2026
**Disetujui oleh**: Riki (user) + Kiro (audit)
**Ready for execution**: ⏳ **Setelah konfirmasi 2 Pending Decisions di atas**


---

## Design System Reference (WAJIB Diikuti Saat Implementasi UI)

Implementasi UI WAJIB sesuai mockup yang sudah dikerjakan di `docs/ui-research/mockups/`. JANGAN bikin design dari nol — semua keputusan visual sudah final.

### Mockup Sebagai Source of Truth

**Halaman utama mahasiswa** (di `docs/ui-research/mockups/`):

| Mockup File | Implementasi Target | Status Mockup |
|-------------|---------------------|---------------|
| `mobile-home.html` | `mypresensi-mobile/lib/features/home/screens/home_screen.dart` | ✅ Final (3 frame: aktif/empty/loading) |
| `mobile-mockup.html` | Showcase 4 screen utama (home/scan/face/result) | ✅ Final |
| `mobile-riwayat.html` | `mypresensi-mobile/lib/features/history/screens/history_screen.dart` | ✅ Final (filter chip + bottom sheet detail) |
| `mobile-notifications.html` | `mypresensi-mobile/lib/features/notifications/screens/notification_screen.dart` | ✅ Final (2 tab + swipe action) |
| `mobile-leave-request.html` | `mypresensi-mobile/lib/features/leave_requests/screens/submit_leave_request_screen.dart` | ✅ Final (4-step wizard) |
| `mobile-my-leave-requests.html` | NEW screen untuk gateway izin | ✅ Final (perlu impl baru) |
| `mobile-profile.html` | `mypresensi-mobile/lib/features/profile/screens/profile_screen.dart` | ✅ Final (avatar tap-able + 3 group settings) |
| `mobile-login.html` | `mypresensi-mobile/lib/features/auth/screens/login_screen.dart` | ✅ Final |
| `mobile-splash-onboarding.html` | `mypresensi-mobile/lib/features/auth/screens/splash_screen.dart` + onboarding baru | Splash ✅, onboarding belum impl |
| `mobile-ai-chat.html` | `mypresensi-mobile/lib/features/ai/screens/ai_chat_screen.dart` | ✅ Final (boleh defer/soft-deprecate) |

**Mockup web admin/dosen** (untuk referensi flow dosen approve izin, monitor sesi):
- `admin-dashboard.html`, `dosen-dashboard.html`, `audit-log.html`, `live-monitor.html`, `qr-display.html`, `settings.html`, `mahasiswa-list.html`, `dosen-list.html`, `matkul-list.html`, `sesi-list.html`, `rekap.html`

### Token Design (CSS → Flutter Theme Mapping)

**Source CSS**: `docs/ui-research/mockups/_tokens.css` + `docs/ui-research/mockups/_mobile.css`
**Target Flutter**: `mypresensi-mobile/lib/core/theme/app_colors.dart` + `app_theme.dart`

#### Color Tokens (HARUS Konsisten)

```
Primary (Biru TRPL): #2D86FF (mockup) / #5483AD (web globals.css)
  → Reconcile: pakai #5483AD (web), atau #2D86FF (mockup)?
  → KEPUTUSAN: pakai mockup (#2D86FF) karena lebih bright untuk mobile.
    Update mypresensi-web/app/globals.css supaya konsisten.
  → Atau alternatif: keep web token #5483AD, update mockup ke #5483AD.
  → ⚠️ DECISION POINT — Riki, pilih mana?

Accent Gold: #F4B400 (Politani gold accent, untuk featured CTA seperti Scan QR)

Status:
- success: #1A7F37 (Hadir)
- warning: #9A6700 (Izin/Sakit/Terlambat)
- danger: #CF222E (Alpa)
- info: #0969DA (badges info)

Text:
- primary: #1C2024
- secondary: #636C76
- tertiary: #9CA3AF

Surface:
- background: #F4F6F8
- surface: #FFFFFF
- border: #E2E6EA
```

#### Typography (HARUS Konsisten)

```
Heading: Plus Jakarta Sans (weight 600, 700, 800)
Body: Inter (weight 400, 500, 600, 700)
Mono: JetBrains Mono (untuk code/ID)
```

Flutter package: `google_fonts ^8.0.2` (sudah ada di pubspec mobile).

### Icon Style (FINAL)

**Mobile WAJIB pakai Solar Bold Duotone** (semua mockup mobile sudah migrate).

Flutter package yang harus dipakai: `iconsax_plus: ^1.0.0` (atau equivalent yang support Solar Bold Duotone). Sudah dilock di rule `03-design-and-libraries.md`.

**Common icon mapping** (Solar Bold Duotone):
- Home: `solar:home-2-bold-duotone`
- Riwayat: `solar:clipboard-list-bold-duotone`
- Izin: `solar:document-text-bold-duotone`
- Notifikasi: `solar:bell-bold-duotone`
- Profil: `solar:user-bold-duotone`
- Scan QR: `solar:qr-code-bold-duotone` (gold featured)
- Wajah: `solar:user-id-bold-duotone`
- Lokasi: `solar:map-point-bold-duotone`
- Kalender: `solar:calendar-bold-duotone`
- Clock: `solar:clock-circle-bold-duotone`
- Sakit (medical): `solar:pills-bold-duotone`
- Logout: `solar:logout-3-bold-duotone`

**Web admin/dosen**: tetap **Lucide React** (per rule `03-design-and-libraries.md` — library lock).

### Pattern UI yang Sudah Difinalisasi

#### 3-State (WAJIB di Setiap Screen List)
- **Loading**: Skeleton shimmer (pakai package `shimmer` saat impl)
- **Empty**: Pesan ramah Indonesia + CTA produktif (BUKAN dead-end)
- **Error**: Pesan friendly + tombol retry

#### Bottom Navigation (5-Tab Konsisten)
Sudah final di mockup. Implementasi pakai Material 3 `NavigationBar` (bukan `BottomNavigationBar` lama).

Active state: icon + label primary color (#2D86FF or chosen).
Inactive: text-tertiary (#9CA3AF).

#### Card Pattern
- Border radius: 14-16px
- Shadow: `var(--sh-card)` di mockup → Flutter `BoxShadow` equivalent
- Padding: 14-16px

#### Button Pattern
- Pill button (radius 999px) untuk CTA primary
- Lebar penuh di mobile
- Filled untuk primary action, outlined untuk secondary

#### Bottom Sheet (untuk Detail)
Pattern di `mobile-riwayat.html` Frame 2 dan `mobile-notifications.html`:
- Handle drag bar 36×4px di atas
- Border radius top 24px
- Max height 88%
- Close via swipe-down atau tap overlay
- TIDAK ada tombol "Tutup" eksplisit (Opsi D dari diskusi)

#### Filter Chip Pattern
Horizontal scrollable, pill shape, active = filled primary.

#### Status Pill Pattern
Per status:
- HADIR: success tint bg + success text
- TERLAMBAT: info tint bg + info text
- IZIN/SAKIT: warning tint bg + warning text
- ALPA: danger tint bg + danger text
- MENUNGGU: warning tint
- DISETUJUI: success tint
- DITOLAK: danger tint

### Bahasa & Copy (Sudah Dipoles, Pertahankan)

Semua copy di mockup sudah dipoles untuk natural Indonesian. Pattern:
- ✅ Possessive: "Wajahmu", "Izinmu", "Lokasimu" (lebih akrab)
- ✅ Sapaan informal dosen: "Pak Budi" / "Bu Dewi" (bukan "Dr. Budi Hartono, M.Kom")
- ✅ Hindari kata "sistem": pakai "kami"
- ✅ Hindari jargon: "fake GPS" bukan "Mock GPS", "verifikasi wajah" bukan "biometrik"
- ✅ Empati di context: "Semoga lekas pulih ya" untuk izin sakit
- ✅ Single exclamation, partikel softener ("ya", "yuk")

Contoh:
- ❌ "Mock GPS aktif di perangkatmu" → ✅ "Kami mendapati aplikasi fake GPS aktif di HP-mu saat presensi tadi"
- ❌ "Pengajuan izin sakit untuk Pemrograman Web Lanjut tanggal 14 Mei sudah disetujui Dewi Maharani, M.Sc." → ✅ "Bu Dewi sudah menyetujui izinmu untuk Pemrograman Web Lanjut. Semoga lekas pulih ya."

### Pending Design Decision #3: Color Token Reconciliation

⚠️ **Belum ditentukan**: Mockup pakai `#2D86FF`, web `globals.css` pakai `#5483AD`. Implementasi harus pilih satu untuk konsistensi.

| Option | Pro | Con |
|--------|-----|-----|
| **C1**: Pakai mockup `#2D86FF` (Biru terang) | Lebih punchy untuk mobile, sesuai mockup yang sudah disetujui | Web sudah live dengan `#5483AD`, harus update token |
| **C2**: Pakai web `#5483AD` (Biru baja TRPL, lebih muted) | Web sudah live, tidak break | Mockup mobile harus update semua color |

Rekomendasi: **C1 (mockup #2D86FF)** karena mobile UX lebih critical visual brand-wise. Update web globals.css saat impl mobile.

### File Riset UI/UX yang Bisa Direferensi

- `docs/ui-research/mobile-references.md` — referensi pattern per-screen
- `docs/ui-research/mobile-premium-references.md` — referensi premium global app (Linear, Cash App, dll)
- `docs/ui-research/admin-web-references.md` — untuk impl web admin/dosen

