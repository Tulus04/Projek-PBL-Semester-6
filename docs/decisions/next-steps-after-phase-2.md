# Next Steps Setelah Phase 2 Selesai

> **Tanggal**: 17 Mei 2026 (after Phase 2 implementation)
> **Audit oleh**: Kiro
> **Source of truth**: `docs/decisions/security-architecture-final.md` + `docs/rekap-security-v7-phase1-2.md`
> **Replaces**: Phase order di security-architecture-final.md

---

## Status Saat Ini

✅ **Phase 1**: Document Honest Update (selesai)
✅ **Phase 1.5**: Face wajib di kedua mode (selesai, deviation dari plan awal)
✅ **Phase 2**: Implementasi Face WAJIB backend + mobile + DB (selesai, type-check + flutter analyze pass)
❌ **Phase 3**: QR Rolling 5 detik (belum)
❌ **Phase 4**: Manual override dosen (DIHAPUS dari roadmap di Phase 1.5)
❌ **Phase 5**: UI Mockup Implementation (belum, baru direncanakan)

---

## Rekomendasi Urutan Berikutnya

**Bukan Phase 3 (QR Rolling) langsung**. Alasan:

1. Phase 2 baru implementasi → **harus smoke test manual dulu** sebelum tambah fitur baru
2. UI mockup yang sudah dipoles **belum di-port ke Flutter** → ini differentiator demo PBL
3. QR rolling = polish security, tanpa rolling Face+GPS sudah cover threat utama (titip absen, fake GPS)

**Urutan baru**:

```
Phase 2.5: Smoke Test Manual (3-7 hari)
   ↓
Phase 5: UI Mockup Implementation (2-3 minggu, paling besar effort)
   ↓
Phase 3: QR Rolling 5s (3-5 hari)
   ↓
Phase 6: Demo Prep & Field Test (1 minggu)
```

---

## Phase 2.5 — Smoke Test Manual (Mulai 18 Mei)

### Goal
Pastikan Phase 2 benar-benar bekerja di real device, bukan cuma type-check pass.

### Test Plan

#### Setup
```bash
# Mobile
cd mypresensi-mobile
flutter run --debug

# Web (sesi aktif)
cd mypresensi-web
npm run dev
```

Pastikan:
- Setting `face_verification_mode = 'required'` di DB
- Akun mahasiswa test sudah ada
- Akun dosen test sudah ada

#### Happy Path Test
1. Login mahasiswa → home screen muncul
2. Buka Profil → Daftar Wajah → capture wajah → simpan
3. Dosen buka Mulai Sesi → QR muncul di proyektor
4. Mahasiswa scan QR
   - Expected: app cek face mode → "required" → cek isFaceRegistered → true → push /face-verify
5. Face verify (kamera 15 detik) → match
   - Expected: lanjut submit dengan face result
6. Submit ke server → success
   - Expected: navigasi ke success screen + status "hadir"

#### Sad Path Test (4 skenario)

**Test 1 — Belum register wajah**
1. Login mahasiswa BARU yang belum register
2. Scan QR
3. Expected: dialog "Wajah Belum Didaftarkan" → tombol "Daftar Sekarang" → /face-register
4. Tap "Batal" → Expected: kembali ke scanner

**Test 2 — User cancel face verify**
1. Mahasiswa sudah register wajah
2. Scan QR → push /face-verify
3. Tap tombol back / cancel
4. Expected: pesan error "Verifikasi wajah dibatalkan" → kembali ke scanner

**Test 3 — Face mismatch (pose orang lain)**
1. Mahasiswa A login, register wajah A
2. Mahasiswa B (face berbeda) coba scan QR pakai akun A
3. Face verify → mismatch
4. Submit ke server tetap → server reject 403 + error_code "face_mismatch"
5. Expected: dialog "Wajah Tidak Cocok" → tombol "Coba Lagi"

**Test 4 — Mode online**
1. Dosen buat sesi mode "online"
2. Mahasiswa scan QR (boleh dari mana saja, GPS skip)
3. Expected: face verify TETAP muncul (Phase 1.5: wajib di kedua mode)
4. Face match → submit → success

#### Backward Compatibility Test
1. Admin update setting `face_verification_mode = 'optional'` di DB
2. Mahasiswa scan QR
3. Expected: skip face verify, submit langsung tanpa face check

### Output
- File log hasil test (manual notes OK)
- Bug list (kalau ada)
- Checklist confirmation per skenario

### Effort: 1-3 hari (depending on bug found)

---

## Phase 5 — UI Mockup Implementation (Mulai ~21 Mei)

### Goal
Port semua mockup HTML ke Flutter screen sesuai design system v7.

### Pre-Requisites
1. Tambah library `iconsax_plus: ^1.0.0` ke `pubspec.yaml` mobile (untuk Solar Bold Duotone)
2. Reconcile color token: pakai `#2D86FF` di `app_colors.dart` mobile + update `globals.css` web
3. Setup theme update di `app_theme.dart` Flutter

### Urutan Implementasi (by Priority)

#### 5.1 Profile Screen (mobile-profile.html)
**Effort**: 1-2 hari
**File**: `mypresensi-mobile/lib/features/profile/screens/profile_screen.dart`

Yang dikerjakan:
- Update avatar widget: tap-able dengan camera badge edit (P3-#3 sudah impl)
- Settings group structure: Akun / Keamanan & Privasi / Aplikasi
- Toggle switch untuk Izin Lokasi (caution gold color)
- Logout danger row
- Bottom nav 5-tab konsisten

Backend cek:
- `POST /api/mobile/profile/avatar` (sudah ada)
- `DELETE /api/mobile/face/me` (sudah ada untuk hapus wajah)

#### 5.2 My Leave Requests Screen (mobile-my-leave-requests.html) — BARU
**Effort**: 1-2 hari
**File**: `mypresensi-mobile/lib/features/leave_requests/screens/my_leave_requests_screen.dart` (BUAT BARU)

Yang dikerjakan:
- List pengajuan izin user dengan filter chip (Semua / Menunggu / Disetujui / Ditolak)
- Group by status: "Menunggu Review" di atas, "Selesai" di bawah
- FAB "Ajukan Izin" → navigate ke wizard
- Empty state dengan CTA primary

Backend cek:
- `GET /api/mobile/leave-requests/my` (sudah ada)

Routing update:
- Tab "Izin" di bottom nav → screen ini (gateway)

#### 5.3 History Screen (mobile-riwayat.html)
**Effort**: 1-2 hari
**File**: `mypresensi-mobile/lib/features/history/screens/history_screen.dart`

Yang dikerjakan:
- Filter chip 6 status (Semua / Hadir / Telat / Izin / Sakit / Alpa) — note: TELAT bukan TERLAMBAT
- Hero summary 5 stat (Hadir / Telat / Izin / Sakit / Alpa)
- Group by smart-date
- Bottom sheet detail saat tap item (5 row: MK / Waktu / Lokasi / Wajah / Perangkat)
- Pill TELAT warna info biru distinct dari HADIR

Backend cek:
- `GET /api/mobile/history` (sudah ada)

#### 5.4 Notifications Screen (mobile-notifications.html)
**Effort**: 1 hari
**File**: `mypresensi-mobile/lib/features/notifications/screens/notification_screen.dart`

Yang dikerjakan:
- 2 tab: Semua / Belum Dibaca (no "Penting" — backend tidak support)
- Group by tanggal
- Swipe action: kanan → mark read, kiri → hapus
- Empty state: "Belum ada kabar baru"
- Copy natural Indonesia (sudah final di mockup)

Backend cek:
- `GET /api/mobile/notifications` (sudah ada)
- `PATCH /api/mobile/notifications/[id]/read` (cek apakah sudah ada)

#### 5.5 Home Screen (mobile-home.html)
**Effort**: 1-2 hari
**File**: `mypresensi-mobile/lib/features/home/screens/home_screen.dart`

Yang dikerjakan:
- 3 state: Sesi Aktif / Tidak Ada Sesi / Loading skeleton
- Hero card sesi aktif (gradient + gold glow + Scan QR CTA)
- Quick action grid 4 item (Scan QR featured gold)
- Activity feed 3-5 item

Backend cek:
- `GET /api/mobile/sessions/active` (sudah ada)
- `GET /api/mobile/dashboard` (cek apakah sudah ada untuk activity feed)

#### 5.6 Submit Leave Request Screen (mobile-leave-request.html) — UPDATE
**Effort**: 1 hari
**File**: `mypresensi-mobile/lib/features/leave_requests/screens/submit_leave_request_screen.dart`

Yang dikerjakan:
- 4-step wizard: Pilih Sesi → Tipe & Alasan → Lampiran → Review
- Step 1: list sesi belum dihadiri (aktif sekarang + backdate 7 hari)
- Step 2: type tile (Sakit / Izin) tanpa subtitle, icon `solar:pills-bold-duotone` untuk Sakit
- Step 3: single file upload (sesuai backend)
- Step 4: status timeline (read-only)
- Tombol back custom dihapus, hanya CTA full-width "Lanjut" dengan panah

Backend cek:
- `POST /api/mobile/leave-requests/submit` (sudah ada)
- `POST /api/mobile/leave-requests/upload-evidence` (sudah ada)

### Verification per Screen
Setiap screen WAJIB pass:
- `flutter analyze` no issues
- Manual visual test: 3-state (loading skeleton + empty ramah + error retry)
- Bottom nav konsisten 5-tab
- Token color sesuai `#2D86FF`
- Icon Solar Bold Duotone

### Effort Total: 2-3 minggu

---

## Phase 3 — QR Rolling 5 Detik (Mulai ~7 Juni, setelah UI selesai)

### Goal
Implementasi rolling QR (TOTP-like) supaya kode berubah tiap 5 detik, anti-share screenshot.

### Detail Implementation
Ada di `docs/decisions/security-architecture-final.md` Phase 3 sub-A1.

### Effort: 4-6 jam

---

## Phase 6 — Demo Prep & Field Test (Mulai ~14 Juni)

### Goal
Aplikasi siap presentasi PBL ke dosen pembimbing.

### Checklist
- [ ] Field test 3 kondisi cahaya: terang, remang, outdoor (face accuracy)
- [ ] Field test 3 device: low-end (entry Xiaomi), mid-range (Redmi Note), flagship
- [ ] Test mock GPS reject di release build (debug build skip mock detection)
- [ ] Demo video recording (5-7 menit): full flow
- [ ] Slide presentasi
- [ ] README final
- [ ] `.gitignore` audit (no secret leaked)
- [ ] APK release build with obfuscation

---

## Yang TIDAK Saya Sarankan Sekarang

❌ **Live Monitor sesi web** (Phase 3 di TODO.md) — nice-to-have, butuh Supabase Realtime
❌ **AI Chatbot polish** — sudah discussed soft-deprecate
❌ **OCR surat dokter** — feature creep, defer ke pasca-PBL
❌ **Push notification FCM** — polling cukup untuk demo
❌ **Cert pinning, freeRASP, AES-256** — sudah resmi skipped di plan v7

---

## Pesan Buat Windsurf

Saat eksekusi:
1. **Test before move on**: jangan langsung lanjut phase berikutnya tanpa smoke test manual phase sebelumnya
2. **Library lock**: tambah `iconsax_plus` perlu update `pubspec.yaml` + diskusi user (per rule 03-design-and-libraries)
3. **Token reconciliation**: putuskan dengan user — `#2D86FF` mockup atau `#5483AD` web
4. **Verify before claim**: type-check + flutter analyze pass + manual screenshot bukti UX bekerja
5. **Update CHANGELOG.md** per phase dengan format standar `| HH:MM | [TYPE] | path | desc |`

---

## Status File ini

**Tanggal**: 17 Mei 2026 setelah Phase 2 selesai
**Disetujui**: Pending review user
**Estimated total effort sampai demo**: 4 minggu (sampai ~14 Juni 2026)
