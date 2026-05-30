# BUG-019 — Exploration Evidence (Layer B Manual Field Reproduction)

**Bug**: QR Scan Unify Camera Plugin — kamera back freeze setelah lifecycle handoff
plugin (`mobile_scanner` ↔ `package:camera`) di OEM ColorOS Camera2 HAL.

**Spec**: `.kiro/specs/qr-scan-unify-camera-plugin/`
(bugfix.md, design.md, tasks.md)

**Layer**: B — Manual field reproduction di RMX5000 (representative OEM device).
Layer A = static structural assertion `pubspec.yaml`
(`mypresensi-mobile/test/bugfix/bug_019_dual_plugin_assertion_test.dart`).

**Status**: 🟡 Pre-fix counterexample (template) — menunggu user execute manual
reproduction & paste evidence. Section "Post-Fix Verification" akan diisi di
Task 3.5 setelah implementasi fix.

---

## 1. Why Layer B Diperlukan

Layer A (assertion `pubspec.yaml`) hanya prove **structural condition** — yaitu
runtime aplikasi punya 2 plugin camera (`|activePlugins ∩ {mobile_scanner,
camera}| == 2`). Ini satu dari 3 komponen `isBugCondition`. Dua komponen lain
hanya bisa di-verify lewat field reproduction:

| Komponen `isBugCondition` | Coverage | Tool |
|---|---|---|
| `\|activePlugins ∩ {mobile_scanner, camera}\| == 2` | Layer A | `flutter test` static |
| `deviceClass ∈ {OEM_COLOROS, OEM_MIUI, OEM_FUNTOUCH, OEM_ONEUI}` | **Layer B** | RMX5000 fisik |
| `cameraHandoff == true` | **Layer B** | manual repro push→pop |

Pure unit test tidak bisa simulate **OEM Camera2 HAL behavior** — driver native
ColorOS yang gagal release/re-acquire `CameraDevice` adalah black box. Field
test di RMX5000 satu-satunya cara surface counterexample konkret.

---

## 2. Device Information (Wajib Diisi User)

| Field | Value |
|---|---|
| Device model | Realme RMX5000 (`...` — isi varian lengkap dari Settings → About) |
| Brand / OEM skin | Realme / ColorOS |
| ColorOS version | `...` (mis. ColorOS 14.0.1) |
| Android version | `...` (mis. Android 14, API 34) |
| Build number | `...` (Settings → About → Build number) |
| Chipset | MediaTek Helio entry-level (`...` — verifikasi via CPU-Z) |
| RAM / Storage | `...` GB / `...` GB |
| Tanggal repro | YYYY-MM-DD |
| Tester | `...` |

**Negative control device** (untuk konfirmasi bug device-specific):

| Field | Value |
|---|---|
| Device | Pixel 9a emulator API 36 (Stock Android) atau Pixel fisik |
| Android version | API 36 (Android 15) |
| Tanggal repro | YYYY-MM-DD |

---

## 3. Pre-Repro Setup

### 3.1 Build pre-fix debug APK

Working directory: `mypresensi-mobile/`

```powershell
# Verifikasi UNFIXED state — pubspec.yaml MASIH punya `mobile_scanner`
Select-String -Path pubspec.yaml -Pattern "mobile_scanner|^  camera:"
# Expected output (pre-fix):
#   pubspec.yaml:NN:  camera: ^0.12.0+1
#   pubspec.yaml:NN:  mobile_scanner: ^7.2.0

# 1. Pastikan dependencies up-to-date
flutter pub get

# 2. Static analyze — baseline 0 issues
flutter analyze

# 3. Build APK debug
flutter build apk --debug
```

Output expected: `build/app/outputs/flutter-apk/app-debug.apk`.

### 3.2 Install ke RMX5000

Hubungkan device via USB (USB debugging ON di Developer options).

```powershell
# Verifikasi device terdeteksi
adb devices

# Install (uninstall dulu kalau sudah ada — clean state CAMERA permission)
adb uninstall ac.id.politani.mypresensi_mobile  ; # ignore error kalau belum install
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### 3.3 Akun test

Login pakai akun mahasiswa dari `credentials-MUSTREAD.txt`. Untuk Repro 2
(Cancel Register), butuh akun mahasiswa yang **belum register wajah** —
kalau semua akun sudah register, minta admin reset face row di Supabase
(`DELETE FROM public.face_embeddings WHERE student_id = '<uid>'`).

### 3.4 Logcat capture window

Buka 1 PowerShell terminal khusus untuk `adb logcat` paralel — kita capture
trace Camera2 HAL selama tiga skenario repro berurutan.

```powershell
# Clear buffer dulu biar output bersih per skenario
adb logcat -c

# Tag yang relevan (tracing Camera2 HAL):
#   CameraDevice         — open / close camera
#   CameraManager        — claim / release HAL
#   BufferQueueConsumer  — buffer producer/consumer attach
#   ImageReader          — surface lifecycle
#   MobileScanner        — internal log mobile_scanner (kalau ada)
adb logcat -v time CameraDevice:V CameraManager:V BufferQueueConsumer:V ImageReader:V MobileScanner:V *:S
```

Setelah tiap repro, copy potongan output ke section yang sesuai di bawah,
ATAU dump full log ke file dan reference path-nya:

```powershell
# Dump ke file per skenario (jalankan setelah skenario selesai)
adb logcat -d -v time -s "CameraDevice","CameraManager","BufferQueueConsumer","ImageReader","MobileScanner" `
  > docs/bugfix/bug-019-logcat-prefix-1.txt
```

---

## 4. Repro Skenario 1 — Cancel Verify

**Hipotesis**: Plugin handoff `mobile_scanner` → `package:camera` (face verify) →
`mobile_scanner` (pop balik) merusak Camera2 HAL state. Kamera back freeze
di frame terakhir setelah pop.

### 4.1 Pre-conditions
- Mahasiswa login: `<email mahasiswa terdaftar wajah>`
- Mode `face_verification_mode = required` (cek admin web → Settings)
- Sesi presensi aktif untuk MK enrolled mahasiswa (`hari ini`)

### 4.2 Steps
1. Cold start app (`adb shell am force-stop ac.id.politani.mypresensi_mobile`,
   buka manual via launcher).
2. Login mahasiswa.
3. Tab **Scan** → grant CAMERA permission kalau diminta.
4. **Observe baseline**: kamera back HIDUP (frame live), arahkan ke QR aktif
   yang dosen tampilkan. → konfirmasi pre-conditions OK.
5. QR ter-decode → push otomatis ke `/face-verify`.
6. Di face-verify screen, tap tombol **close** (cancel) di top-bar.
7. **Pop balik ke `ScanQrScreen`**.

### 4.3 Expected Pre-Fix Outcome
- ❌ Kamera back **freeze di frame terakhir** sebelum push (atau blank putih).
- ❌ Tidak ada decode QR baru meski user arahkan ke QR berbeda — `_onDetect`
  callback tidak fire.
- ❌ Logcat menunjukkan urutan:
  ```
  BufferQueueConsumer connect ...
  ImageReader disconnect ...
  System onCameraAvailable: 1
  ```
  TANPA `openCameraDeviceUserAsync` setelah pop — HAL menolak claim ulang
  back camera dalam 1 session app.

### 4.4 Evidence (DIISI USER)

**Screencast / screenshot path**: `docs/bugfix/evidence/bug-019-repro-1-prefix.{mp4,png}`
(buat folder `evidence/` kalau belum ada, JANGAN commit file > 5 MB).

**Logcat snippet kunci** (5–10 baris paling relevan, paste literal output):

```
[paste logcat snippet di sini]
```

**Logcat full file**: `docs/bugfix/bug-019-logcat-prefix-1.txt`

**Counterexample summary**:
- Behavior observed: `[mis. kamera blank putih 8 detik tanpa recovery]`
- Last live frame timestamp pre-pop: `[mis. 14:23:01.234]`
- First frame post-pop: `[mis. NEVER — kamera tidak update sampai user kill app]`

---

## 5. Repro Skenario 2 — Cancel Register

**Hipotesis**: Sama dengan skenario 1 tapi via path face-register (mahasiswa
yang belum register wajah). Plugin handoff identik → bug condition sama.

### 5.1 Pre-conditions
- Mahasiswa login: `<email mahasiswa BELUM register wajah>`
- Mode `face_verification_mode = required`
- Sesi presensi aktif

### 5.2 Steps
1. Cold start app (force-stop dulu).
2. Login mahasiswa.
3. Tab **Scan** → grant CAMERA permission.
4. Scan QR aktif → decode sukses.
5. Dialog "Wajah Belum Didaftarkan" muncul → tap **"Daftar Sekarang"**.
6. Push ke `/face-register`.
7. Di face-register screen, tekan back **TANPA complete registrasi**.
8. **Pop balik ke `ScanQrScreen`**.

### 5.3 Expected Pre-Fix Outcome
- ❌ Kamera back **blank putih** (atau freeze frame terakhir).
- ❌ Sama seperti Skenario 1 — `_onDetect` mati, scan QR tidak bisa retry
  dalam session yang sama.

### 5.4 Evidence (DIISI USER)

**Screencast / screenshot**: `docs/bugfix/evidence/bug-019-repro-2-prefix.{mp4,png}`

**Logcat snippet**:

```
[paste logcat snippet di sini]
```

**Logcat full file**: `docs/bugfix/bug-019-logcat-prefix-2.txt`

**Counterexample summary**:
- Behavior observed: `[...]`
- Difference dari Skenario 1: `[...]` (kalau ada — biasanya identik)

---

## 6. Repro Skenario 3 — Repeat 3x dalam 1 Session

**Hipotesis**: Bug deterministic per-session app — sekali HAL stuck, tidak
recover sampai user kill app. Repeat 3 cycle harus tetap freeze.

### 6.1 Steps
1. Cold start app.
2. Login mahasiswa terdaftar wajah.
3. **Cycle 1**: Tab Scan → scan QR valid → push verify → cancel → pop.
4. (Tanpa kill app) **Cycle 2**: switch tab Beranda lalu balik tab Scan,
   arahkan ke QR baru → observe.
5. (Tanpa kill app) **Cycle 3**: ulangi step 4.
6. Setelah 3 cycle, **kill app** (`force-stop`) → buka ulang → observe.

### 6.2 Expected Pre-Fix Outcome
- ❌ Cycle 1: freeze (sama dengan Skenario 1).
- ❌ Cycle 2 & 3: tetap freeze — tidak ada self-recovery dalam session.
- ✅ Setelah `force-stop` + cold start: kamera HIDUP lagi (konfirmasi state
  reset hanya bisa via process restart, bukan widget remount).

### 6.3 Evidence (DIISI USER)

**Screencast** (recording 60–90 detik full 3 cycle): `docs/bugfix/evidence/bug-019-repro-3-prefix.mp4`

**Logcat full file**: `docs/bugfix/bug-019-logcat-prefix-3.txt`

**Cycle observation table**:

| Cycle | Kamera state setelah pop | `openCameraDeviceUserAsync` di logcat? | Recover tanpa kill? |
|---|---|---|---|
| 1 | `[freeze / blank]` | `[No / Yes]` | No |
| 2 | `[...]` | `[...]` | No |
| 3 | `[...]` | `[...]` | No |
| Post force-stop | hidup | Yes | n/a |

---

## 7. Negative Control — Pixel 9a (Stock Android)

**Hipotesis**: Bug **tidak** muncul di Stock Android — Camera2 HAL Pixel
release/re-acquire dengan benar saat plugin lain claim. Konfirmasi bug
device-class-specific (OEM ColorOS quirk), bukan bug umum Flutter layer.

### 7.1 Setup
- Pixel 9a emulator API 36 (lihat workflow `/run-emulator`) ATAU Pixel fisik.
- Same APK debug yang di-install ke RMX5000 (Skenario 1–3).

### 7.2 Steps
Re-execute Skenario 1 (Cancel Verify) dan Skenario 2 (Cancel Register) di
Pixel 9a — langkah persis sama.

### 7.3 Expected Outcome
- ✅ Skenario 1 di Pixel 9a: kamera back **hidup** setelah pop dari
  `/face-verify`. Scan QR baru work normal. `openCameraDeviceUserAsync`
  muncul di logcat post-pop.
- ✅ Skenario 2 di Pixel 9a: kamera back hidup setelah pop dari
  `/face-register`. Scan QR baru work normal.

### 7.4 Evidence (DIISI USER)

**Screencast** (1 cycle Pixel 9a, baseline normal): `docs/bugfix/evidence/bug-019-pixel9a-control.mp4`

**Observation**: kamera back hidup post-pop = bug device-specific confirmed.
**Logcat snippet** (presence of `openCameraDeviceUserAsync` post-pop):

```
[paste logcat snippet]
```

---

## 8. Counterexample — Ringkasan Konkret

Setelah tiga skenario di RMX5000 selesai, isi tabel ringkasan ini sebagai
**bukti formal** counterexample yang men-trigger bug condition:

| # | Input | Device | Camera state post-pop | Decode QR retry? | HAL log claim ulang? |
|---|-------|--------|-----------------------|------------------|----------------------|
| 1 | scan→verify→cancel→pop | RMX5000 ColorOS | freeze/blank | ❌ | ❌ no `openCameraDeviceUserAsync` |
| 2 | scan→register→back→pop | RMX5000 ColorOS | freeze/blank | ❌ | ❌ no `openCameraDeviceUserAsync` |
| 3 | repeat scenario 1 (3 cycles) | RMX5000 ColorOS | freeze cycle 1–3 | ❌ semua cycle | ❌ no recovery dalam session |
| 4 | scan→verify→cancel→pop | Pixel 9a Stock | live frame | ✅ | ✅ `openCameraDeviceUserAsync` post-pop |

**Kesimpulan**: Skenario 1, 2, 3 = `isBugCondition(input) == true` AND behavior
observed ≠ Expected Behavior (Property 1). Skenario 4 = `isBugCondition == false`
AND behavior identik dengan baseline pre-fix (preservation maintained). Confirm
root cause analysis #1 dari design.md (Plugin Conflict di Camera2 HAL Layer).

**Layer A test result**: FAIL (intersection size = 2: `mobile_scanner` AND
`camera` keduanya present di `pubspec.yaml`). Layer A counterexample literal
ada di output `flutter test test/bugfix/bug_019_dual_plugin_assertion_test.dart`.

---

## 9. Post-Fix Verification

> **STATUS**: 🟡 PARTIAL — Layer A automated test sudah PASS post-fix
> (auto-confirmed by Task 3.5). Layer B field reproduction di RMX5000
> **menunggu user/QA execute** (butuh device fisik — tidak bisa dijalankan
> oleh agen otomatis).

### 9.1 Layer A re-run — ✅ AUTO-CONFIRMED

**Command**:

```
flutter test test/bugfix/bug_019_dual_plugin_assertion_test.dart
```

Working directory: `mypresensi-mobile/`. Dijalankan oleh agen Kiro dalam
Task 3.5 setelah `mobile_scanner` di-drop dari `pubspec.yaml`
(Task 3.1) dan `google_mlkit_barcode_scanning: ^0.14.0` ditambahkan.

**Result**: ✅ **PASS** — 2/2 tests passed (00:01).

```
test.dart                                                +2: All tests passed!
Exit Code: 0
```

**Interpretasi structural** (Layer A meng-cover komponen pertama dari
`isBugCondition`):

| Komponen `isBugCondition` | Pre-fix | Post-fix |
|---|---|---|
| `\|activePlugins ∩ {mobile_scanner, camera}\|` | `2` (FAIL) | `1` (PASS) |
| Plugin tersisa | `{mobile_scanner, camera}` | `{camera}` |
| Bug condition tercapai? | ✅ ya (3 komponen) | ❌ tidak (komponen 1 false) |

Karena `isBugCondition` adalah **conjunction** (AND) dari 3 komponen,
falsifikasi komponen 1 sudah cukup untuk men-falsifikasi keseluruhan
predikat — runtime aplikasi post-fix **tidak akan pernah masuk** kondisi
"dual plugin claim Camera2 HAL secara concurrent". Komponen 2
(`deviceClass ∈ {OEM_*}`) dan komponen 3 (`cameraHandoff == true`) tetap
mungkin terjadi (RMX5000 + lifecycle handoff push→pop), tapi tanpa
komponen 1 race condition tidak ada.

**Verifikasi tambahan structural** (rule 06 §B): cek
`pubspec.yaml` line yang masih punya `camera`, dan tidak ada lagi
`mobile_scanner`:

```
camera: ^0.12.0+1                              # back camera scan QR + face flow
google_mlkit_barcode_scanning: ^0.14.0          # ML Kit QR decoder (BUG-019)
google_mlkit_face_detection: ^0.13.2            # face detection (preserved)
# mobile_scanner — REMOVED (BUG-019)
```

### 9.2 Layer B re-run di RMX5000 — ⏳ MENUNGGU USER/QA

> **Mengapa tidak bisa dijalankan agen Kiro**: Layer B butuh device
> fisik RMX5000 (atau emulator yang men-simulate ColorOS Camera2 HAL —
> tidak ada). Agen Kiro tidak punya akses `adb` ke device user. Layer B
> = **screenshot-as-proof** (rule 06 Law 4) — wajib bukti visual user.

**Pre-conditions sebelum mulai**:

1. Pastikan `git status` (cwd: root project) bersih atau commit dulu
   perubahan Task 3.1–3.4 (`pubspec.yaml`, `qr_decoder_service.dart`,
   `scan_qr_screen.dart`, `CHANGELOG.md`, `dev-log.md`).
2. Pastikan `flutter pub get` sudah jalan tanpa conflict
   (Task 3.1 sudah verifikasi).
3. Pastikan akun mahasiswa test tersedia di
   `credentials-MUSTREAD.txt` — **2 akun** dibutuhkan: satu yang sudah
   register wajah (Repro 1) dan satu yang belum register (Repro 2).
4. Pastikan ada sesi presensi aktif di MK enrolled mahasiswa hari ini
   (dosen klik "Mulai Sesi" dari web → QR aktif sekitar 3 menit).

**Build & install post-fix debug APK**:

Working directory: `mypresensi-mobile/` (PowerShell dari root project,
atau `cd` ke folder ini).

```powershell
# 1. Static analyze baseline
flutter analyze

# 2. Build debug APK post-fix
flutter build apk --debug

# 3. Verifikasi APK terbentuk
Get-ChildItem build/app/outputs/flutter-apk/app-debug.apk | Select-Object Name, Length

# 4. Hubungkan RMX5000 via USB (USB debugging ON di Developer options)
adb devices
# Output expected: device id RMX5000 + status `device`

# 5. Uninstall versi pre-fix dulu (clean state CAMERA permission + kill stale data)
adb uninstall ac.id.politani.mypresensi_mobile  ; # ignore error kalau belum install

# 6. Install post-fix APK
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

**Logcat capture window** (1 PowerShell terminal terpisah, biarkan
streaming selama 3 skenario repro):

```powershell
# Clear buffer
adb logcat -c

# Tail dengan tag Camera2 HAL relevan (gunakan ini untuk lihat live)
adb logcat -v time CameraDevice:V CameraManager:V BufferQueueConsumer:V ImageReader:V *:S
```

#### 9.2.1 Repro 1 Post-Fix — Cancel Verify

**Steps** (mirror Repro 1 pre-fix dari §4):

1. Cold start app (`adb shell am force-stop ac.id.politani.mypresensi_mobile`,
   buka manual via launcher).
2. Login mahasiswa **terdaftar wajah**.
3. Tab **Scan** → grant CAMERA permission kalau diminta.
4. **Observe**: kamera back hidup (frame live), arahkan ke QR aktif.
5. QR ter-decode → push otomatis ke `/face-verify`.
6. Di face-verify screen, tap tombol **close** (cancel).
7. **Pop balik ke `ScanQrScreen`** → **observe**: kamera back HIDUP
   ≤ 2 detik (NO freeze, NO blank).
8. Arahkan kamera ke QR yang sama atau berbeda → **expect** decode
   sukses ≤ 1 detik (latency parity).

**Capture logcat snapshot** ke file:

```powershell
adb logcat -d -v time -s "CameraDevice","CameraManager","BufferQueueConsumer","ImageReader" `
  > docs/bugfix/bug-019-logcat-postfix-1.txt
```

**Acceptance criteria** (semua harus terpenuhi):

- [ ] Kamera back HIDUP ≤ 2 detik setelah pop
- [ ] Decode QR baru sukses, latency ≤ 1 detik
- [ ] Logcat memuat `openCameraDeviceUserAsync` setelah pop
  (HAL re-acquire success — BUKTI fix bekerja di HAL layer)
- [ ] Tidak ada exception `CameraAccessException` atau
  `Camera service died` di logcat

**Screencast/screenshot**:
`docs/bugfix/evidence/bug-019-repro-1-postfix.{mp4,png}`
(jangan commit file > 5 MB).

#### 9.2.2 Repro 2 Post-Fix — Cancel Register

**Steps** (mirror Repro 2 pre-fix dari §5):

1. Cold start app (force-stop dulu).
2. Login mahasiswa **belum register wajah**.
3. Tab **Scan** → grant CAMERA permission.
4. Scan QR aktif → decode sukses.
5. Dialog "Wajah Belum Didaftarkan" muncul → tap **"Daftar Sekarang"**.
6. Push ke `/face-register`.
7. Tekan back **TANPA complete registrasi**.
8. **Pop balik ke `ScanQrScreen`** → **observe**: kamera back HIDUP
   ≤ 2 detik.

**Capture logcat snapshot**:

```powershell
adb logcat -d -v time -s "CameraDevice","CameraManager","BufferQueueConsumer","ImageReader" `
  > docs/bugfix/bug-019-logcat-postfix-2.txt
```

**Acceptance criteria**: sama dengan §9.2.1.

**Screencast/screenshot**:
`docs/bugfix/evidence/bug-019-repro-2-postfix.{mp4,png}`.

#### 9.2.3 Repro 3 Post-Fix — Repeat 3x dalam 1 Session

**Steps** (mirror Repro 3 pre-fix dari §6):

1. Cold start app.
2. Login mahasiswa terdaftar wajah.
3. **Cycle 1**: Tab Scan → scan QR valid → push verify → cancel → pop.
   Observe kamera hidup, scan QR baru sukses.
4. (Tanpa kill app) **Cycle 2**: switch tab Beranda lalu balik tab Scan,
   ulangi push verify → cancel → pop.
5. (Tanpa kill app) **Cycle 3**: ulangi cycle 2 sekali lagi.

**Capture logcat snapshot**:

```powershell
adb logcat -d -v time -s "CameraDevice","CameraManager","BufferQueueConsumer","ImageReader" `
  > docs/bugfix/bug-019-logcat-postfix-3.txt
```

**Acceptance criteria**:

- [ ] Kamera back HIDUP di **SETIAP** cycle (cycle 1, 2, 3)
- [ ] Decode QR sukses di setiap cycle
- [ ] Logcat memuat `openCameraDeviceUserAsync` post-pop di setiap cycle
- [ ] Tidak ada degradasi performa antar cycle (latency stabil)

**Screencast** (recording 60–90 detik full 3 cycle):
`docs/bugfix/evidence/bug-019-repro-3-postfix.mp4`.

#### 9.2.4 Latency Parity Check

Ukur decode latency 5 sample QR scan post-fix di RMX5000 — **median ≤
1 detik** (paritas dengan baseline `mobile_scanner` pre-fix).

| Sample | Timestamp scan | Timestamp decode | Latency (ms) |
|---|---|---|---|
| 1 | `[diisi user]` | `[diisi user]` | `[diisi user]` |
| 2 | `[diisi user]` | `[diisi user]` | `[diisi user]` |
| 3 | `[diisi user]` | `[diisi user]` | `[diisi user]` |
| 4 | `[diisi user]` | `[diisi user]` | `[diisi user]` |
| 5 | `[diisi user]` | `[diisi user]` | `[diisi user]` |
| **Median** | – | – | `[hitung]` |

**Cara ukur** (kasar): tambah `debugPrint('QR decode at ${DateTime.now()}')`
sementara di `_onCameraFrame` di `scan_qr_screen.dart`, atau pakai
stopwatch manual dari frame yang menampilkan QR sampai snackbar/
navigation muncul. Setelah selesai, **revert** debug print sebelum
commit.

#### 9.2.5 Ringkasan Tabel Post-Fix

Setelah ketiga repro selesai, isi tabel ringkasan:

| # | Input | Camera state post-pop | Decode QR retry? | Latency median | `openCameraDeviceUserAsync` di logcat? |
|---|-------|-----------------------|------------------|----------------|---------------------------------------|
| 1 | scan→verify→cancel→pop | `[hidup / freeze]` | `[✅ / ❌]` | `[ms]` | `[Yes / No]` |
| 2 | scan→register→back→pop | `[...]` | `[...]` | `[ms]` | `[...]` |
| 3 | repeat scenario 1 (3 cycles) | `[hidup di 3 cycle / degradasi]` | `[...]` | `[ms]` | `[...]` |

**Expected (success path)**: kolom 3 semua `hidup`, kolom 4 semua `✅`,
kolom 5 median ≤ 1000 ms, kolom 6 semua `Yes`.

### 9.3 Refute Path — Kalau RMX5000 Masih Freeze

**STOP** — JANGAN klaim selesai (rule 06 §E anti-pattern).

Kalau salah satu repro post-fix **gagal acceptance criteria** (kamera
freeze/blank, atau `openCameraDeviceUserAsync` tidak muncul di logcat),
root cause analysis #1 di `design.md` (Plugin Conflict di Camera2 HAL
Layer) **refuted** atau **partial**. Plan B (`WidgetsBindingObserver`
defensive re-init) sudah ter-encode di Task 3.3 di
`scan_qr_screen.dart`.

Kalau Plan B juga tidak cukup, kemungkinan lain yang harus
di-investigate:

1. **`package:camera` sendiri buggy di OEM ColorOS** — investigate
   issue tracker
   <https://github.com/flutter/flutter/issues> + cek version pin lebih
   konservatif (e.g. `0.10.x` LTS).
2. **Lifecycle GoRouter merusak state** — coba `await Future.delayed`
   sebelum `initState` re-init di `didChangeAppLifecycleState`.
3. **Conflict dengan `google_mlkit_face_detection`** — face flow share
   ML Kit native; cek apakah ML Kit BarcodeScanner + FaceDetector
   bisa coexist di same process (kemungkinan kecil — beda model
   binary, ML Kit support multi-detector).

**Eskalasi**: paste:
- Tabel §9.2.5 dengan hasil aktual
- Logcat snippet 10–15 baris post-pop dari skenario yang fail
- Screencast skenario yang fail

ke chat dengan agen Kiro, minta re-hypothesize root cause sebelum
melanjutkan.

### 9.4 Update Tabel Verifikasi Rule 06 §B (Setelah Field Test Selesai)

Setelah Layer B selesai dengan acceptance criteria PASS, update tabel
verifikasi di Task 4 (`tasks.md` Checkpoint):

| Check | Result |
|-------|--------|
| `flutter analyze` | ✅ 0 issues |
| `flutter test` (PBT + assertion) | ✅ all pass |
| `flutter build apk --debug` | ✅ exit 0 |
| **RMX5000 field test (post-fix)** | ✅ user confirm via screenshot/screencast |
| Pixel 9a preservation match | ⏳ pending Task 3.6 |
| `pubspec.yaml` — `mobile_scanner` removed | ✅ verified |
| `attendance_provider.dart` git diff | ✅ 0 lines changed |
| CHANGELOG.md + dev-log.md updated | ✅ entries BUG-019 |

---

## 10. References

- Spec: `.kiro/specs/qr-scan-unify-camera-plugin/`
- Bug Retro Discipline (rule 06 §D): `dev-log.md` entry BUG-019 (akan ditulis
  di Task 3.4 — postmortem setelah fix verified).
- Layer A test: `mypresensi-mobile/test/bugfix/bug_019_dual_plugin_assertion_test.dart`
- Preservation baseline (Layer B preservation, parallel): `docs/bugfix/bug-019-preservation-baseline.md`
  (akan dibuat di Task 2).
