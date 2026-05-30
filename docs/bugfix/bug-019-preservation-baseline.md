# BUG-019 — Preservation Baseline (Layer B Manual QA Matrix)

**Bug**: QR Scan Unify Camera Plugin — refactor `ScanQrScreen` dari
`mobile_scanner` ke `package:camera` + `google_mlkit_barcode_scanning`.

**Spec**: `.kiro/specs/qr-scan-unify-camera-plugin/`
(bugfix.md, design.md, tasks.md)

**Property**: Property 2 — Preservation. Untuk semua input yang tidak
memenuhi `isBugCondition` (Stock Android emulator = device class non-OEM,
bug TIDAK trigger di sini), behavior pre-fix dan post-fix WAJIB identik.

**Layer**: B — Manual QA matrix di Pixel 9a emulator API 36 (Stock
Android, safe baseline). Layer A = property-based test
`mypresensi-mobile/test/attendance/parse_qr_code_property_test.dart`
yang lock down kontrak `parseQrCode` purity.

**Status**: 🟡 Pre-fix baseline (template) — section "Pre-Fix Baseline"
diisi user dengan screenshot per item saat manual QA dengan UNFIXED APK.
Section "Post-Fix Match" dibiarkan kosong, akan diisi di Task 3.6
setelah refactor `ScanQrScreen` selesai.

---

## 1. Why Layer B Diperlukan

Layer A (PBT `parseQrCode`) hanya cover decoder purity (Property 2 sub
point #1 di design.md). Layer B menutupi **3 sub-point sisanya**:

| Property 2 sub-point | Coverage | Tool |
|---|---|---|
| #1 Decoder purity | Layer A | `flutter test` PBT |
| #2 Submit pipeline identity | **Layer B** | Manual QA (item 1, 2, 5, 6, 7) |
| #3 UI behavior identity | **Layer B** | Manual QA (item 3, 4, 8, 9, 10) |
| #4 Build & analyze | (Task 3.6 final) | `flutter analyze` + `flutter build apk --debug` |

UI overlay, dialog flow, dan torch toggle TIDAK cocok untuk PBT karena
overhead-nya jauh lebih besar dari nilai yang didapat (rationale di
design.md §Preservation Checking). Manual QA dengan screenshot baseline
lebih praktis dan langsung visual.

---

## 2. Setup — UNFIXED APK di Pixel 9a Emulator

Working directory: `mypresensi-mobile/`.

### 2.1 Verifikasi UNFIXED state

```powershell
# pubspec.yaml MASIH punya `mobile_scanner` — wajib pre-fix
Select-String -Path pubspec.yaml -Pattern "mobile_scanner|^  camera:"
# Expected output (pre-fix):
#   pubspec.yaml:NN:  camera: ^0.12.0+1
#   pubspec.yaml:NN:  mobile_scanner: ^7.2.0
```

### 2.2 Build pre-fix debug APK

```powershell
flutter pub get
flutter analyze        # baseline 0 issues
flutter build apk --debug
```

Output expected: `build/app/outputs/flutter-apk/app-debug.apk`.

### 2.3 Boot emulator + install

```powershell
# Lihat workflow /run-emulator. Pixel 9a image API 36 (Android 15 Stock).
flutter emulators --launch Pixel_9a_API_36
adb wait-for-device

# Clean install (uninstall dulu untuk test CAMERA permission first-run)
adb uninstall ac.id.politani.mypresensi_mobile  ; # ignore error kalau belum
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### 2.4 Akun test

| Item | Akun | Catatan |
|---|---|---|
| Mahasiswa terdaftar wajah (mode required) | `<email>` | Lihat `credentials-MUSTREAD.txt` |
| Mahasiswa belum register wajah | `<email>` | Untuk item 4. Reset via `DELETE FROM face_embeddings WHERE student_id=...` kalau perlu |
| Sesi presensi aktif | dosen panel web → "Mulai Sesi" | Mode `face_verification_mode` toggle di Settings |

### 2.5 Screenshot folder

Simpan screenshot pre-fix di:

```
docs/bugfix/evidence/preservation/prefix/
  ├── item-01-happy-required.png
  ├── item-02-happy-optional.png
  ├── item-03-qr-invalid.png
  ├── item-04-face-not-registered-dialog.png
  ├── item-05-server-face-not-registered.png
  ├── item-06-server-face-mismatch.png
  ├── item-07-server-generic-error.png
  ├── item-08-torch-toggle.png
  ├── item-09-permission-dialog.png
  └── item-10-visual-ui.png
```

Folder post-fix: `docs/bugfix/evidence/preservation/postfix/` dengan
nama file identik (untuk side-by-side diff). JANGAN commit screenshot
> 5 MB; kompres PNG kalau perlu.

---

## 3. Pre-Fix Baseline — 10 QA Items

Setiap item: **observe** behavior, **capture** screenshot, **fill in**
field "Observed" + path file. Status pre-fix HARUS PASS karena emulator
Stock Android tidak men-trigger bug condition.

### 3.1 Item 1 — Happy path mode `required`

**Pre-conditions**:
- Mode `face_verification_mode = required` (admin web → Settings).
- Mahasiswa login dengan wajah TERDAFTAR.
- Sesi presensi aktif untuk MK enrolled mahasiswa.

**Steps**:
1. Tab Scan → grant CAMERA permission (kalau diminta).
2. Arahkan kamera ke QR aktif yang dosen tampilkan.
3. QR ter-decode → push otomatis ke `/face-verify`.
4. Selesaikan liveness (blink, turnLeft, lookStraight, turnRight).
5. Face-verify pop dengan `FaceVerificationResult` → submit attendance.
6. Result page muncul.

**Expected baseline**:
- ✅ Result page tampil dengan status `hadir`.
- ✅ Snackbar / toast positif.
- ✅ `audit_logs` row baru dengan `action = mobile_attendance_submit`
  (cek di `/audit` web).

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-01-happy-required.png`

**Status pre-fix**: ⏳ Pending

---

### 3.2 Item 2 — Happy path mode `optional`

**Pre-conditions**:
- Mode `face_verification_mode = optional` (toggle di admin web → Settings).
- Mahasiswa login (tidak perlu wajah terdaftar).
- Sesi presensi aktif.

**Steps**:
1. Tab Scan → arahkan kamera ke QR aktif.
2. QR ter-decode → submit langsung TANPA face flow (mode optional).
3. Result page muncul.

**Expected baseline**:
- ✅ Tidak ada push ke `/face-verify` atau `/face-register`.
- ✅ Result page tampil dengan status `hadir`.
- ✅ Tidak ada field face di body request (cek via `audit_logs` detail).

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-02-happy-optional.png`

**Status pre-fix**: ⏳ Pending

---

### 3.3 Item 3 — QR invalid format

**Pre-conditions**:
- Mode bebas (tidak relevan).
- Mahasiswa login.

**Steps**:
1. Tab Scan → arahkan kamera ke QR yang BUKAN format presensi
   (mis. QR alamat URL, QR teks bebas, atau cetak QR dari generator
   online dengan plaintext "hello world").
2. Observe reaction.

**Expected baseline**:
- ✅ Snackbar muncul dengan teks Bahasa Indonesia (literal):
  > "QR code tidak valid. Pastikan Anda memindai QR presensi yang benar."
- ✅ Tidak ada navigasi ke `/face-verify` atau `/attendance-result`.
- ✅ Kamera tetap hidup, ready scan ulang.

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-03-qr-invalid.png`

**Status pre-fix**: ⏳ Pending

---

### 3.4 Item 4 — Wajah Belum Didaftarkan dialog (preservation 3.4)

**Pre-conditions**:
- Mode `face_verification_mode = required`.
- Mahasiswa login dengan wajah BELUM TERDAFTAR (reset face row di
  `face_embeddings` kalau perlu).
- Sesi presensi aktif.

**Steps**:
1. Tab Scan → arahkan kamera ke QR aktif valid.
2. QR ter-decode.
3. Dialog "Wajah Belum Didaftarkan" muncul.

**Expected baseline**:
- ✅ Title dialog: "Wajah Belum Didaftarkan".
- ✅ Body Bahasa Indonesia menjelaskan kenapa user tidak bisa lanjut +
  apa langkah berikutnya.
- ✅ Dua CTA tombol: **"Daftar Sekarang"** (primary) dan **"Nanti Saja"** (secondary).
- ✅ Tap "Daftar Sekarang" → push `/face-register`.
- ✅ Tap "Nanti Saja" → tutup dialog, kembali ke ScanQrScreen kamera hidup.

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-04-face-not-registered-dialog.png`

**Status pre-fix**: ⏳ Pending

---

### 3.5 Item 5 — Server error `face_not_registered`

**Pre-conditions**:
- Mode `face_verification_mode = required`.
- Server di-mock untuk return `error_code = face_not_registered` di
  response 4xx submit endpoint. Cara mock:
  - Opsi A (preferred): jalankan dosen sesi tapi sengaja face row
    mahasiswa di-delete antara face-verify completed dan submit.
  - Opsi B: gunakan Charles Proxy / mitmproxy intercept ke
    `/api/mobile/attendance/submit` → rewrite response 400 dengan body
    `{"error":"...","error_code":"face_not_registered"}`.
  - Opsi C (paling cepat): temporary di server side
    (`mypresensi-web/app/api/mobile/attendance/submit/route.ts`),
    tambah hardcode return `error_code: 'face_not_registered'` saat
    `email == 'test-mock@example.com'` — JANGAN commit.

**Steps**:
1. Scan QR valid mode required.
2. Selesaikan face-verify.
3. Submit attendance (provider call hits server mock).
4. Response 4xx dengan `error_code = face_not_registered`.

**Expected baseline**:
- ✅ Dialog `_showFaceNotRegisteredDialog` muncul (BUKAN snackbar generic).
- ✅ Body Bahasa Indonesia + CTA "Daftar Sekarang" / "Tutup".
- ✅ Tap "Daftar Sekarang" → push `/face-register`.

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-05-server-face-not-registered.png`

**Status pre-fix**: ⏳ Pending

---

### 3.6 Item 6 — Server error `face_mismatch`

**Pre-conditions**:
- Mode `face_verification_mode = required`.
- Server mock return `error_code = face_mismatch` (cara sama dengan item 5).

**Steps**:
1. Scan QR valid mode required.
2. Selesaikan face-verify (cosine similarity di server akan dianggap < threshold via mock).
3. Response 4xx dengan `error_code = face_mismatch`.

**Expected baseline**:
- ✅ Dialog `_showFaceMismatchDialog` muncul (BUKAN snackbar generic).
- ✅ Body Bahasa Indonesia menjelaskan wajah tidak cocok + CTA "Coba Lagi" / "Tutup".
- ✅ Tap "Coba Lagi" → reset state attendanceSubmit, kamera kembali aktif.

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-06-server-face-mismatch.png`

**Status pre-fix**: ⏳ Pending

---

### 3.7 Item 7 — Server error generic (5xx)

**Pre-conditions**:
- Server return 500 Internal Server Error (mock via mitmproxy atau
  matikan server sebentar setelah scan).

**Steps**:
1. Scan QR valid.
2. Submit attendance hits server 500.

**Expected baseline**:
- ✅ Snackbar `_showError` Bahasa Indonesia ramah (mis. "Terjadi
  kesalahan, silakan coba lagi.").
- ✅ TIDAK ada stack trace exposed.
- ✅ Kamera kembali aktif untuk scan ulang.

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-07-server-generic-error.png`

**Status pre-fix**: ⏳ Pending

---

### 3.8 Item 8 — Torch toggle

**Pre-conditions**:
- Tab Scan aktif, kamera back hidup.

**Steps**:
1. Tap icon torch di top bar.
2. Observe flash on + icon update (filled / accent color).
3. Tap lagi.
4. Observe flash off + icon update kembali.

**Expected baseline**:
- ✅ Tap pertama: flash hardware ON (cek di emulator: emulator Pixel
  9a tidak punya flash hardware, jadi observe via icon state saja —
  test ini lebih authoritative di device fisik / RMX5000).
- ✅ Icon state berubah saat toggle (filled vs outline, atau accent
  color change).
- ✅ State icon konsisten dengan state torch (no drift).

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-08-torch-toggle.png`

**Status pre-fix**: ⏳ Pending

**Catatan**: Karena Pixel 9a emulator tidak punya flash hardware,
torch hardware behavior verifikasi lengkap perlu HP fisik. Item ini
focus pada UI state preservation (icon update + tap responsive).

---

### 3.9 Item 9 — CAMERA permission first request

**Pre-conditions**:
- App fresh install (clear app data via
  `adb shell pm clear ac.id.politani.mypresensi_mobile`).
- User belum pernah grant CAMERA permission.

**Steps**:
1. Buka app → login.
2. Tab Scan untuk pertama kali.
3. Permission dialog Android muncul.

**Expected baseline**:
- ✅ Native Android permission dialog muncul: "Allow MyPresensi to
  take pictures and record video?" / Bahasa Indonesia variant.
- ✅ Tap "Allow / Izinkan" → kamera back terbuka, scan ready.
- ✅ Tap "Don't allow / Tolak" → app tampilkan UI fallback Bahasa
  Indonesia + tombol "Buka Pengaturan" yang panggil `openAppSettings()`.

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-09-permission-dialog.png`

**Status pre-fix**: ⏳ Pending

---

### 3.10 Item 10 — Visual UI

**Pre-conditions**:
- Tab Scan aktif, kamera back hidup, no in-flight submit.

**Steps**:
1. Capture full screenshot ScanQrScreen.

**Expected baseline (visual elements yang harus ada)**:
- ✅ **Top bar**:
  - Tombol back (iconsax bulk arrow_left / chevron — kiri).
  - Title "Scan QR Presensi" (Plus Jakarta Sans, font weight 600).
  - Icon torch toggle (kanan).
- ✅ **Center overlay**:
  - Frame scanning dengan corner border (`_CornerBorderPainter`)
    di 4 sudut, warna primary.
- ✅ **Bottom panel**:
  - Card / sheet dengan teks Bahasa Indonesia "Arahkan kamera ke QR Code".
- ✅ **Loading overlay** (saat in-flight submit / GPS):
  - Full-screen scrim semi-transparent + spinner + label progress
    (mis. "Mengambil lokasi GPS...", "Mengirim presensi...").
- ✅ **Color tokens**: pakai `AppColors.primary` (#2D86FF), tidak ada
  hex hardcode random.

**Observed**: `[diisi user]`

**Screenshot**: `docs/bugfix/evidence/preservation/prefix/item-10-visual-ui.png`

**Status pre-fix**: ⏳ Pending

---

## 4. Pre-Fix Baseline Summary

Setelah 10 item selesai di-execute dan screenshot tersimpan, isi tabel
ringkasan ini:

| # | Item | Pre-fix status | Screenshot path |
|---|------|----------------|-----------------|
| 1 | Happy path mode `required` | ⏳ / ✅ / ❌ | `[path]` |
| 2 | Happy path mode `optional` | ⏳ / ✅ / ❌ | `[path]` |
| 3 | QR invalid format | ⏳ / ✅ / ❌ | `[path]` |
| 4 | Wajah Belum Didaftarkan dialog | ⏳ / ✅ / ❌ | `[path]` |
| 5 | Server error `face_not_registered` | ⏳ / ✅ / ❌ | `[path]` |
| 6 | Server error `face_mismatch` | ⏳ / ✅ / ❌ | `[path]` |
| 7 | Server error generic (5xx) | ⏳ / ✅ / ❌ | `[path]` |
| 8 | Torch toggle | ⏳ / ✅ / ❌ | `[path]` |
| 9 | CAMERA permission first request | ⏳ / ✅ / ❌ | `[path]` |
| 10 | Visual UI | ⏳ / ✅ / ❌ | `[path]` |

**Total pre-fix**: `[N/10]` PASS.

**Catatan blocker pre-fix**: kalau ada item yang gagal pre-fix, itu
BUKAN regressi BUG-019 — itu separate bug yang harus di-track terpisah.
Stop dan eskalasi sebelum lanjut ke implementasi fix BUG-019.

---

## 5. Post-Fix Match (Task 3.6)

> **STATUS**: 🟡 PARSIAL — automated checks (§5.2 build/static, §5.3
> provider diff, §5.4 refute path) sudah TERVERIFIKASI post-fix oleh
> agent (commit `a9daabe`, sesi 2026-05-24). Layer B runtime QA matrix
> di §5.1 perlu dijalankan **user secara manual** di emulator Pixel 9a
> API 36 — agent tidak bisa akses emulator/screenshot. Lihat §5.5
> runbook step-by-step.

### 5.1 Post-Fix Match Table (User runtime QA — pending)

Re-execute 10 item identik dengan post-fix APK di Pixel 9a emulator
yang SAMA dengan pre-fix baseline. Compare screenshot side-by-side
dengan baseline pre-fix di `docs/bugfix/evidence/preservation/prefix/`.
Simpan screenshot post-fix di `docs/bugfix/evidence/preservation/postfix/`
dengan nama file identik.

| # | Item | Post-fix status | Match dengan baseline? | Screenshot post-fix |
|---|------|-----------------|------------------------|---------------------|
| 1 | Happy path mode `required` | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-01-happy-required.png` |
| 2 | Happy path mode `optional` | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-02-happy-optional.png` |
| 3 | QR invalid format | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-03-qr-invalid.png` |
| 4 | Wajah Belum Didaftarkan dialog | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-04-face-not-registered-dialog.png` |
| 5 | Server error `face_not_registered` | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-05-server-face-not-registered.png` |
| 6 | Server error `face_mismatch` | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-06-server-face-mismatch.png` |
| 7 | Server error generic (5xx) | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-07-server-generic-error.png` |
| 8 | Torch toggle | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-08-torch-toggle.png` |
| 9 | CAMERA permission first request | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-09-permission-dialog.png` |
| 10 | Visual UI | ⏳ pending user | ⏳ pending | `evidence/preservation/postfix/item-10-visual-ui.png` |

**Total post-fix match**: `⏳ pending` / 10 identik dengan pre-fix
baseline (diisi user setelah runtime QA).

### 5.2 Build & Static Checks (Property 2 sub-point #4) — ✅ AUTOMATED

Diukur post-fix oleh agent pada commit `a9daabe`, working dir
`mypresensi-mobile/`, sesi 2026-05-24:

```powershell
flutter analyze              # ran in 5.7s
flutter build apk --debug    # Gradle assembleDebug 67.5s
Select-String -Path android\app\build.gradle.kts -Pattern "minSdk\s*="
```

| Check | Pre-fix (baseline) | Post-fix (measured) | Status |
|---|---|---|---|
| `flutter analyze` issues | 0 | **0** ("No issues found! (ran in 5.7s)") | ✅ PASS |
| `flutter build apk --debug` exit code | 0 | **0** (`Built build\app\outputs\flutter-apk\app-debug.apk`, 67.5s) | ✅ PASS |
| `flutter build apk --debug` artifact size | n/a | 267.14 MB (debug, unobfuscated — sizing release dilakukan saat task release-build, bukan task ini) | ℹ️ info |
| `minSdk` (build.gradle.kts:27) | 26 | **26** (literal `minSdk = 26`) | ✅ PASS — preservation 3.14 |

### 5.3 Provider Diff Verification (Property 2 sub-point #2) — ✅ AUTOMATED

`attendance_provider.dart` dan `attendance_models.dart` adalah Files
NOT Touched (design.md §Files NOT Touched). Verifikasi via Git
working tree (commit `a9daabe`, sesi 2026-05-24):

```powershell
git diff --stat lib/features/attendance/providers/attendance_provider.dart `
                lib/features/attendance/data/attendance_models.dart
git status --short lib/features/attendance/providers/attendance_provider.dart `
                   lib/features/attendance/data/attendance_models.dart
```

| Verification | Result | Status |
|---|---|---|
| `attendance_provider.dart` `git diff --stat` | empty (0 lines, 0 insertions, 0 deletions) | ✅ PASS |
| `attendance_models.dart` `git diff --stat` | empty (0 lines, 0 insertions, 0 deletions) | ✅ PASS |
| `git status --short` untuk kedua file | empty (no working tree changes) | ✅ PASS |

**Property 2 sub-point #2 invariant**: kontrak
`attendanceSubmitProvider.parseQrCode(String) → QrCodeData?` dan
`submitFromQr(QrCodeData, faceResult: ...)` IDENTIK pre-fix vs
post-fix — TERBUKTI via 0-line diff.

### 5.4 Layer A PBT Re-Run — ✅ AUTOMATED

Re-run Layer A property-based test post-fix:

```powershell
flutter test test/attendance/parse_qr_code_property_test.dart --reporter=expanded
```

| Test ID | Trials | Status |
|---|---|---|
| Property 1 (purity valid): valid QR JSON returns matching QrCodeData | 100 | ✅ PASS |
| Property 2 (purity invalid): non-conforming QR strings return null | 100 | ✅ PASS |
| Property 3 (idempotence): two consecutive parseQrCode calls structurally equal | 100 valid + 100 invalid = 200 | ✅ PASS |
| Hand-picked edge: canonical UUID + 6-digit code returns QrCodeData | 1 | ✅ PASS |
| Hand-picked edge: non-JSON plaintext returns null | 1 | ✅ PASS |
| Hand-picked edge: malformed JSON returns null | 1 | ✅ PASS |
| Hand-picked edge: missing required fields returns null | 1 | ✅ PASS |
| Hand-picked edge: empty / unicode returns null | 1 | ✅ PASS |
| **Total** | **8 tests, 405 trials** | ✅ **All tests passed!** |

Test output `[QR] Parse error: ...` di console adalah `debugPrint`
expected dari `parseQrCode` saat input invalid (logging contract
preserved dari pre-fix code) — TIDAK indikasi kegagalan.

### 5.5 Runbook Layer B (User Manual QA — Pixel 9a Emulator)

Steps untuk user untuk melengkapi §5.1. **Mirror persis flow pre-fix
di §3** dengan post-fix APK. JANGAN ubah flow — preservation invariant
adalah behavior IDENTIK pre-fix vs post-fix.

#### Setup post-fix APK

Working directory: `mypresensi-mobile/`. Post-fix APK sudah di-build
oleh agent di sesi ini:

```powershell
# Verifikasi APK post-fix sudah ada
Get-Item build\app\outputs\flutter-apk\app-debug.apk
# Expected: ~267 MB, timestamp sesi ini
```

Kalau perlu rebuild (mis. ada perubahan baru):

```powershell
flutter clean        # opsional, kalau cache mengganggu
flutter pub get
flutter analyze      # sanity check 0 issues
flutter build apk --debug
```

#### Boot emulator + install (sama dengan §2.3)

```powershell
flutter emulators --launch Pixel_9a_API_36
adb wait-for-device

# Clean install — penting untuk item 9 (CAMERA permission first request)
adb uninstall ac.id.politani.mypresensi_mobile  ; # ignore error kalau belum
adb install build/app/outputs/flutter-apk/app-debug.apk
```

#### Akun test (sama dengan §2.4)

Pakai akun yang SAMA dengan pre-fix baseline supaya state server
identik. Lihat `credentials-MUSTREAD.txt` untuk credential admin / dosen
/ mahasiswa. Mode `face_verification_mode` toggle di admin web →
Settings (item 1, 4, 5, 6 = `required`; item 2 = `optional`).

#### Eksekusi 10 item — SAMA persis dengan §3

Untuk setiap item:

1. Ikuti **Steps** dari §3.1 sampai §3.10 verbatim — JANGAN improvise.
2. Capture screenshot ke
   `docs/bugfix/evidence/preservation/postfix/<nama-file-sama-dengan-prefix>.png`.
3. Compare side-by-side dengan pre-fix baseline:
   - Visual layout identik (top bar, frame overlay, bottom panel,
     loading overlay, dialog)?
   - Behavior identik (snackbar text exact match, dialog CTA label
     match, navigation match, error code routing match)?
4. Update tabel §5.1: "Post-fix status" jadi ✅ / ❌, "Match" jadi
   ✅ identik / ⚠️ different (kalau berbeda, tulis 1 kalimat
   penjelasan).

#### Catatan khusus per item

- **Item 1 & 5 & 6** (mode `required`): kalau user belum register
  wajah, harus ke face-register dulu di session sebelumnya. Atau
  reset face row di Supabase: `DELETE FROM face_embeddings WHERE student_id=...`.
- **Item 5, 6, 7** (server error simulation): pakai opsi A/B/C dari
  §3.5 — Opsi A (delete face row antara face-verify completed dan
  submit) preferred karena tidak perlu mock proxy.
- **Item 8** (torch): Pixel 9a emulator tidak punya flash hardware,
  cek hanya **icon state update** + **tap responsive** (UI state
  preservation). Hardware torch test sebenarnya = HP fisik / RMX5000
  task 3.5.
- **Item 9** (CAMERA permission first request): WAJIB clean install
  (`adb shell pm clear ac.id.politani.mypresensi_mobile` atau
  `adb uninstall` + reinstall).
- **Item 10** (visual UI): screenshot full screen tab Scan — verify
  top bar, corner border `_CornerBorderPainter`, bottom panel teks
  "Arahkan kamera ke QR Code", color tokens dari `AppColors.primary`
  (`#2D86FF`).

#### Threshold pass

Total post-fix match harus **10/10 identik** dengan pre-fix baseline
untuk klaim Property 2 PASS. Kalau ada 1 item ⚠️ different:
- Cek dulu apakah perbedaan adalah expected refactor side-effect
  (mis. flash hardware behavior beda karena `package:camera` vs
  `mobile_scanner` API berbeda — itu acceptable selama UI state
  preserved).
- Kalau perbedaan adalah regressi behavior nyata (mis. snackbar text
  berubah, dialog CTA hilang) → STOP — eskalasi ke agent dengan
  screenshot side-by-side + diff behavior konkret.

### 5.6 Refute Path

Kalau §5.1 menunjukkan item FAIL post-fix (status ❌ atau ⚠️ different
yang BUKAN expected refactor side-effect), itu adalah **regressi yang
diintroduksi oleh fix BUG-019**. STOP — JANGAN klaim Task 3.6 selesai.
Eskalasi ke agent / user dengan:
- Screenshot pre-fix vs post-fix side-by-side.
- Diff behavior konkret (apa yang berubah).
- Hipotesis penyebab (logic preservation di `_processSubmit` /
  dialog flow / overlay yang tidak match `verbatim` claim di
  design.md §Files NOT Touched).

---

## 6. References

- Spec: `.kiro/specs/qr-scan-unify-camera-plugin/`
- Property 2 design: `design.md` §Correctness Properties #Property 2
- Layer A test (PBT): `mypresensi-mobile/test/attendance/parse_qr_code_property_test.dart`
- Bug Condition (Layer A static + Layer B field repro):
  `docs/bugfix/bug-019-exploration-evidence.md`
- Files NOT Touched (preservation guarantee): `design.md` §Fix
  Implementation #Files NOT Touched
- Mobile design system tokens: `.kiro/steering/22-mobile-design-system.md`
  (referensi visual UI item 10)
