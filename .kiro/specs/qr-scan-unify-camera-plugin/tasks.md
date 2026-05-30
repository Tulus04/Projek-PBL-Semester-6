# Implementation Plan — BUG-019 QR Scan Unify Camera Plugin

## Overview

Bugfix flow untuk plugin conflict di Camera2 HAL ColorOS RMX5000 — `mobile_scanner` 7.2.0 dan `package:camera` 0.12.x sama-sama claim back camera, OEM HAL gagal release/re-acquire setelah handoff. Strategi: **unify ke 1 plugin** — drop `mobile_scanner`, refactor `ScanQrScreen` ke `package:camera` + `QrDecoderService` (BARU) yang pakai `google_mlkit_barcode_scanning`.

**Effort estimate**: 4–6 jam (exploration evidence di RMX5000 60 menit, preservation baseline 60 menit, fix implementation 90 menit, verifikasi static + manual 90–120 menit).

**Aturan kunci**:

- Task 1 dan Task 2 dijalankan terhadap **UNFIXED code**. Task 1 (Bug Condition) WAJIB FAIL terhadap unfixed — kegagalan itu bukti bug exists. Task 2 (Preservation) WAJIB PASS terhadap unfixed — itulah baseline yang dijaga setelah fix.
- Task 3.5 (re-run Property 1) HARUS PASS post-fix; task 3.6 (re-run Property 2) HARUS tetap PASS post-fix.
- Identifier kode dalam Inggris, komentar header file dalam Bahasa Indonesia (rule 02 §A.6).
- Library lock (rule 03): tidak boleh ganti `package:camera`, `google_mlkit_face_detection`. Boleh tambah `google_mlkit_barcode_scanning` (ekstensi serumpun ML Kit yang sudah locked).
- `face_registration_screen.dart`, `face_verification_screen.dart`, `attendance_provider.dart`, `face_provider.dart`, `app_router.dart`, `app_shell.dart`, server-side, dan `AndroidManifest.xml` **TIDAK boleh disentuh** (preservation guarantee design §Files NOT Touched).

**Files baru** (3):
1. `mypresensi-mobile/lib/features/attendance/services/qr_decoder_service.dart`
2. `mypresensi-mobile/test/bugfix/bug_019_dual_plugin_assertion_test.dart`
3. `mypresensi-mobile/test/attendance/parse_qr_code_property_test.dart`

**Files modified** (4):
1. `mypresensi-mobile/pubspec.yaml` — drop `mobile_scanner`, add `google_mlkit_barcode_scanning`
2. `mypresensi-mobile/lib/features/attendance/screens/scan_qr_screen.dart` — refactor full
3. `mypresensi-mobile/CHANGELOG.md` — entry sesi
4. `dev-log.md` (root) — Bug Retro Discipline entry

**Evidence files** (untuk dokumentasi RMX5000 manual repro):
1. `docs/bugfix/bug-019-exploration-evidence.md` — pre-fix counterexample + post-fix verification
2. `docs/bugfix/bug-019-preservation-baseline.md` — Stock Android baseline + post-fix match table

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "name": "Exploration + preservation tests pada UNFIXED code",
      "tasks": ["1", "2"],
      "depends_on": []
    },
    {
      "wave": 2,
      "name": "Apply fix (sequential sub-tasks)",
      "tasks": ["3.1", "3.2", "3.3", "3.4"],
      "depends_on": ["1", "2"]
    },
    {
      "wave": 3,
      "name": "Re-verify Property 1 + Property 2 post-fix",
      "tasks": ["3.5", "3.6"],
      "depends_on": ["3.3"]
    },
    {
      "wave": 4,
      "name": "Final checkpoint + verification log",
      "tasks": ["4"],
      "depends_on": ["3.5", "3.6"]
    }
  ]
}
```

| ID | Task | Depends on |
|----|------|------------|
| 1 | **Property 1: Bug Condition** — Exploration test (EXPECTED FAIL pre-fix) | – |
| 2 | **Property 2: Preservation** — Property tests + baseline (EXPECTED PASS pre-fix) | – |
| 3.1 | Update `pubspec.yaml` — drop `mobile_scanner`, add `google_mlkit_barcode_scanning` | 1, 2 |
| 3.2 | Buat `QrDecoderService` (FILE BARU) | 3.1 |
| 3.3 | Refactor `ScanQrScreen` ke `package:camera` + `QrDecoderService` | 3.2 |
| 3.4 | Update `CHANGELOG.md` + `dev-log.md` | 3.3 |
| 3.5 | **Property 1: Expected Behavior** — Re-run exploration test (EXPECTED PASS post-fix) | 3.3 |
| 3.6 | **Property 2: Preservation** — Re-run preservation tests (EXPECTED PASS post-fix) | 3.3 |
| 4 | Checkpoint — semua test pass + verification log | 3.5, 3.6 |

## Tasks

- [x] 1. Tulis exploration test Bug Condition (BEFORE implementing the fix)
  - **Property 1: Bug Condition** — Camera Reinitialized After Lifecycle Handoff (RMX5000)
  - **CRITICAL**: Test ini WAJIB FAIL di unfixed code — failure adalah bukti bug exists
  - **DO NOT attempt to fix the test or the code when it fails** — tujuan task ini *surface* counterexample, bukan fix
  - **NOTE**: Test ini encode expected behavior — akan validate fix saat PASSES setelah implementasi (task 3.5)
  - **GOAL**: Surface counterexample konkret yang demonstrate bug exists di OEM ColorOS Camera2 HAL
  - **Scoped PBT Approach**: Bug ini deterministic per-device — scope property ke concrete failing case di **RMX5000 (ColorOS)** sebagai representative OEM device. Hipotesis class: MIUI/FunTouch/OneUI similar Camera2 HAL behavior, tapi confirmed scope = RMX5000.

  **Bug Condition (dari design `isBugCondition`)**:
  - `|input.activePlugins ∩ {mobile_scanner, package:camera}| == 2`
  - `input.deviceClass ∈ {OEM_COLOROS, OEM_MIUI, OEM_FUNTOUCH, OEM_ONEUI}`
  - `input.cameraHandoff == true` (push ScanQrScreen → /face-verify or /face-register → pop)

  **Test pendekatan (2 layer)**:

  **Layer A — Static structural assertion** (file: `test/bugfix/bug_019_dual_plugin_assertion_test.dart`):
  - Property: `pubspec.yaml` SHALL NOT contain both `mobile_scanner` AND `package:camera` as active dependencies — only one camera plugin allowed at runtime.
  - Generator: parse `pubspec.yaml` deps + dev_deps, intersect dengan set `{mobile_scanner, camera}`.
  - Assertion: intersection size ≤ 1.
  - **Pre-fix expectation**: FAIL (`mobile_scanner: ^7.2.0` AND `camera: ^0.12.0+1` both present → intersection = 2). Counterexample: literal `pubspec.yaml` content showing both lines.
  - **Post-fix expectation**: PASS (`mobile_scanner` removed → intersection = 1).

  **Layer B — Manual field reproduction on RMX5000** (file: `docs/bugfix/bug-019-exploration-evidence.md` — buat baru):
  - Build pre-fix debug APK: `flutter build apk --debug`, `adb install build/app/outputs/flutter-apk/app-debug.apk`
  - Reproduksi 3 cycle (untuk konsistensi konfirmasi root cause analysis #1):
    1. **Repro 1 (Cancel Verify)**: Login mahasiswa terdaftar wajah → tab Scan → scan QR aktif valid (mode `required`) → push `/face-verify` → tap close (cancel) → pop balik ke `ScanQrScreen` → **observe**: kamera back FREEZE di frame terakhir ≥ 5 detik atau blank putih.
    2. **Repro 2 (Cancel Register)**: Login mahasiswa belum register → tab Scan → scan QR valid → dialog "Wajah Belum Didaftarkan" → "Daftar Sekarang" → push `/face-register` → back tanpa register → pop → **observe**: kamera back blank putih.
    3. **Repro 3 (Repeat 3x)**: Cycle scan→cancel→balik 3x dalam 1 session app → **observe**: kamera tetap freeze setelah cycle pertama (no recovery dalam 1 session).
  - Capture logcat per repro: `adb logcat -d -v time -s "CameraDevice","CameraManager","BufferQueueConsumer","ImageReader" > docs/bugfix/bug-019-logcat-prefix-{1,2,3}.txt`
  - **EXPECTED OUTCOME (pre-fix)**: Repro 1, 2, 3 semua menunjukkan freeze/blank kamera setelah pop. Logcat trace memuat `BufferQueueConsumer connect` → `ImageReader disconnect` → `System onCameraAvailable: 1` TANPA `openCameraDeviceUserAsync` setelahnya. Test FAILS.
  - Document counterexample concrete di `docs/bugfix/bug-019-exploration-evidence.md`:
    - Device: Realme RMX5000, ColorOS version, Android API level
    - Reproduksi command + langkah
    - Logcat snippet (5-10 baris kunci tanpa `openCameraDeviceUserAsync` post-pop)
    - Screenshot/screencast (kalau ada akses) frame freeze

  **Negative control (untuk confirm bug device-specific)**:
  - Repro 1 + 2 sama persis di **Pixel 9a emulator API 36 (Stock Android)** → **expect**: kamera hidup normal. Konfirmasi bug bukan di Flutter layer general, tapi di OEM HAL layer.

  - Mark task complete saat: (a) Layer A test ditulis dan FAIL pre-fix, (b) Layer B evidence file lengkap dengan logcat + counterexample documented, (c) negative control Pixel 9a confirmed bug NOT triggered di Stock Android.
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Tulis preservation property tests (BEFORE implementing the fix)
  - **Property 2: Preservation** — QR Parse Contract & Submit Pipeline Identity
  - **IMPORTANT**: Follow observation-first methodology — observe behavior di UNFIXED code dulu, lalu encode pattern-nya jadi property-based test
  - **GOAL**: Lock down kontrak `attendanceSubmitProvider.parseQrCode(String) → QrCodeData?` dan UI error routing supaya post-fix tidak introduce regressi

  **Test pendekatan (2 layer)**:

  **Layer A — PBT untuk `parseQrCode` purity** (file: `test/attendance/parse_qr_code_property_test.dart`):
  - **Observation pada UNFIXED code**: panggil `attendanceSubmitProvider.notifier.parseQrCode(s)` untuk beragam input dan record output:
    - Valid: `{"session_id":"<uuid>","code":"<6-digit>"}` → returns `QrCodeData(sessionId: ..., code: ...)` non-null
    - Invalid (non-JSON): `"hello world"`, `"123456"` → returns `null`
    - Invalid (JSON malformed): `"{session_id: x}"`, `"{}"` → returns `null`
    - Invalid (missing fields): `'{"session_id":"x"}'`, `'{"code":"123456"}'` → returns `null`
    - Edge (unicode/empty): `""`, `"\u{1F600}"` → returns `null`
  - **Property generator** (pakai `flutter_test` + `dart:math` saja, no new dependency — rule 03):
    - `validQrGen`: random UUID v4 (dari `Random` + format string) + random 6-digit code → JSON encode
    - `invalidQrGen`: random ASCII string panjang 0-200 yang TIDAK valid JSON dengan 2 field wajib
  - **Properties**:
    1. **Purity valid**: `∀ s ∈ validQrGen. parseQrCode(s) != null AND parseQrCode(s).sessionId == extracted_uuid AND parseQrCode(s).code == extracted_code`
    2. **Purity invalid**: `∀ s ∈ invalidQrGen. parseQrCode(s) == null`
    3. **Idempotence/no state leakage**: `∀ s. parseQrCode(s) == parseQrCode(s)` (call 2x return identik, no internal state mutation)
  - **Trial count**: 100 valid samples + 100 invalid samples
  - **Pre-fix expectation**: PASS (test pada `attendance_provider.dart` yang TIDAK akan diubah → kontrak preserved)
  - **Post-fix expectation**: PASS (`attendance_provider.dart` masih tidak di-touch)

  **Layer B — Manual preservation QA matrix** (file: `docs/bugfix/bug-019-preservation-baseline.md` — buat baru):
  - Run UNFIXED code di **Pixel 9a emulator API 36** (Stock Android, bug TIDAK trigger di sini → safe untuk capture baseline behavior).
  - Observe & record (screenshot per item) behavior berikut (semua = `¬isBugCondition`):
    1. **Happy path mode `required`**: scan QR valid → face verify sukses → submit → result page → **expected baseline**: result tampil dengan status `hadir`, audit_logs row tercatat di server.
    2. **Happy path mode `optional`**: scan QR valid → submit langsung tanpa face → result.
    3. **QR invalid format**: scan QR non-JSON → snackbar "QR code tidak valid. Pastikan Anda memindai QR presensi yang benar."
    4. **Wajah Belum Didaftarkan dialog (preservation 3.4)**: mode `required` + belum register → scan valid → dialog dengan CTA "Daftar Sekarang" / "Nanti Saja".
    5. **Server error `face_not_registered`**: mock server response → `_showFaceNotRegisteredDialog` muncul.
    6. **Server error `face_mismatch`**: mock server response → `_showFaceMismatchDialog` muncul.
    7. **Server error generic**: mock 500 → `_showError` snackbar.
    8. **Torch toggle**: tap icon torch di top bar → flash on/off + icon update.
    9. **CAMERA permission first request**: clear app data → tab Scan → permission dialog muncul.
    10. **Visual UI**: top bar (back + title "Scan QR Presensi" + torch), corner border `_CornerBorderPainter`, bottom panel "Arahkan kamera ke QR Code", loading overlay GPS/submit.
  - **Pre-fix expectation**: 10 items semua PASS dengan screenshot baseline tersimpan.
  - **Post-fix expectation**: 10 items behave IDENTIK dengan baseline (screenshot post-fix matches).

  - Mark task complete saat: (a) Layer A PBT ditulis dan PASS di unfixed code (run `flutter test test/attendance/parse_qr_code_property_test.dart`), (b) Layer B baseline file dengan 10 screenshot tersimpan.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14_

- [x] 3. Fix BUG-019 — Unify camera plugin ke `package:camera` + `google_mlkit_barcode_scanning`

  - [x] 3.1 Update `pubspec.yaml` — drop `mobile_scanner`, tambah `google_mlkit_barcode_scanning`
    - Hapus baris `mobile_scanner: ^7.2.0` di section `# === Device ===`
    - Tambah `google_mlkit_barcode_scanning: ^0.14.0` (verify dependency tree resolve clean dengan `google_mlkit_face_detection: ^0.13.2` saat `flutter pub get`)
    - Run `flutter pub get` (cwd: `mypresensi-mobile/`) → expect 0 conflict
    - Run `flutter analyze` → expect 0 issues
    - File: `mypresensi-mobile/pubspec.yaml`
    - _Bug_Condition: isBugCondition(input) where input.activePlugins ⊇ {mobile_scanner, package:camera} — drop mobile_scanner sehingga intersection ≤ 1_
    - _Expected_Behavior: setelah fix, runtime activePlugins ∩ {mobile_scanner, package:camera} = {package:camera} (size 1) → bug condition tidak pernah tercapai_
    - _Preservation: dependency `camera: ^0.12.0+1` + `google_mlkit_face_detection: ^0.13.2` tidak berubah; rule 03 library lock untuk face flow preserved_
    - _Requirements: 2.4_

  - [x] 3.2 Buat `QrDecoderService` (FILE BARU)
    - File baru: `mypresensi-mobile/lib/features/attendance/services/qr_decoder_service.dart`
    - Komentar header Bahasa Indonesia: tujuan service + catatan keamanan (rule 02 §A.6)
    - Class `QrDecoderService` dengan API mirror `face_detection_service.dart`:
      - Field: `BarcodeScanner? _barcodeScanner`, `bool _isProcessing`, `int _lastDecodeMs`, `static const int _throttleMs = 200`
      - Method `void initialize()` — construct `BarcodeScanner` singleton dengan format `[BarcodeFormat.qrCode]`
      - Method `Future<String?> decodeFromCameraImage(CameraImage image, CameraDescription camera)` — throttle 200ms + re-entrance guard `_isProcessing` + konversi `CameraImage → InputImage` (reuse pattern `_convertCameraImage`, `_concatenatePlanes`, `_getInputImageRotation` dari `face_detection_service.dart`, duplikasi inline OK)
      - Return: `barcodes.first.rawValue` kalau list tidak kosong & `rawValue != null`, else `null`
      - Method `Future<void> dispose()` — close ML Kit scanner
    - **Throttle behavior**: kalau `DateTime.now().millisecondsSinceEpoch - _lastDecodeMs < _throttleMs` → return `null` (skip frame). Update `_lastDecodeMs` setelah decode selesai.
    - **Re-entrance**: kalau `_isProcessing == true` saat call masuk → return `null` segera.
    - _Bug_Condition: bagian dari unify plugin — service ini meng-host decode QR via ML Kit (single backend) menggantikan ZXing native dari mobile_scanner_
    - _Expected_Behavior: decoder pure function dari QR content; throttle + re-entrance guard mencegah CPU saturation ≥ 5 fps dari image stream_
    - _Preservation: kontrak `attendanceSubmitProvider.parseQrCode(String)` tidak berubah — service ini hanya produce raw string yang sama format-nya dengan output `mobile_scanner`_
    - _Requirements: 2.3, 2.4_

  - [x] 3.3 Refactor `ScanQrScreen` ke `package:camera` + `QrDecoderService`
    - File: `mypresensi-mobile/lib/features/attendance/screens/scan_qr_screen.dart`
    - **Hapus**: `import 'package:mobile_scanner/mobile_scanner.dart'`, `MobileScannerController _scannerController`, widget `MobileScanner(...)`, `_onDetect(BarcodeCapture)` lama, `ValueListenableBuilder(_scannerController)` untuk torch icon
    - **Tambah import**: `package:camera/camera.dart`, `package:permission_handler/permission_handler.dart`, `../services/qr_decoder_service.dart`
    - **State baru**: `CameraController? _cameraController`, `CameraDescription? _camera`, `QrDecoderService _qrDecoder = QrDecoderService()`, `bool _isCameraReady`, `bool _isTorchOn`, `bool _permissionDenied`, mixin `WidgetsBindingObserver`
    - **`initState()` async sequence**:
      1. Reset `attendanceSubmitProvider` (preserved verbatim)
      2. `WidgetsBinding.instance.addObserver(this)`
      3. Request CAMERA permission via `permission_handler` → kalau denied set `_permissionDenied = true`
      4. `availableCameras()` → cari `CameraLensDirection.back`
      5. Construct `CameraController(camera, ResolutionPreset.medium, imageFormatGroup: ImageFormatGroup.nv21, enableAudio: false)` (medium cukup untuk QR, hemat CPU vs `high` di face)
      6. `await _cameraController!.initialize()`
      7. `_qrDecoder.initialize()`
      8. `await _cameraController!.startImageStream(_onCameraFrame)`
      9. `setState(() => _isCameraReady = true)`
    - **`_onCameraFrame(CameraImage image)`**:
      1. Guard `_isProcessing` (preserved dari logic existing untuk submit lock)
      2. `final raw = await _qrDecoder.decodeFromCameraImage(image, _camera!)`; kalau `null` → return
      3. `final qrData = ref.read(attendanceSubmitProvider.notifier).parseQrCode(raw)` (kontrak preserved)
      4. `qrData == null` → `_showError('QR code tidak valid. Pastikan Anda memindai QR presensi yang benar.')` (preserved)
      5. Valid → `setState(() => _isProcessing = true)`, `await _cameraController!.stopImageStream()`, call `_processSubmit(qrData)` (preserved verbatim)
    - **`dispose()`**:
      1. `WidgetsBinding.instance.removeObserver(this)`
      2. `_cameraController?.stopImageStream()` defensive (jika masih streaming)
      3. `_cameraController?.dispose()`
      4. `_qrDecoder.dispose()`
      5. `super.dispose()`
    - **`didChangeAppLifecycleState`** (defensive — Plan B mitigasi root cause refute):
      - `AppLifecycleState.resumed` → cek `_cameraController?.value.isInitialized`; kalau tidak → re-init full
      - `AppLifecycleState.inactive | paused` → `_cameraController?.dispose()` + flag dispose
    - **`_toggleTorch()`** (preservation 2.5, 3.12):
      - `final newState = !_isTorchOn`
      - `await _cameraController!.setFlashMode(newState ? FlashMode.torch : FlashMode.off)`
      - `setState(() => _isTorchOn = newState)`
    - **`build()`**:
      - `_permissionDenied` → permission UI fallback (Bahasa Indonesia ramah + tombol "Buka Pengaturan" via `openAppSettings()`)
      - `!_isCameraReady` → loading full screen ("Mempersiapkan kamera...")
      - Ready → `Stack` dengan `CameraPreview(_cameraController!)` base + overlay frame (`_buildScanOverlay` preserved verbatim) + top bar (`_buildTopBar` preserved, torch icon dari `_isTorchOn` plain `setState`) + bottom panel (`_buildBottomPanel` preserved verbatim) + loading overlay (`_buildLoadingOverlay` preserved verbatim)
    - **PRESERVED VERBATIM**: `_processSubmit`, `_showFaceNotRegisteredDialog`, `_showFaceMismatchDialog`, `_showError`, `_buildScanOverlay`, `_buildTopBar`, `_buildBottomPanel`, `_buildLoadingOverlay`, `_CornerBorderPainter`, BUG-018 fix (`markFaceRegistered` + `invalidate(faceConfigProvider)` setelah register sukses)
    - Komentar header file Bahasa Indonesia: jelaskan refactor BUG-019 + reference spec `qr-scan-unify-camera-plugin`
    - _Bug_Condition: refactor ini eliminate `mobile_scanner` widget dari `ScanQrScreen` — runtime hanya 1 plugin Flutter (`package:camera`) yang claim Camera2 HAL_
    - _Expected_Behavior: setelah pop dari face flow, `initState` re-create `CameraController` → preview hidup ≤ 2 detik, image stream ≥ 5 fps, decode latency ≤ 1 detik (Property 1)_
    - _Preservation: submit pipeline (`_processSubmit`), dialog flows, error routing, UI overlay, BUG-018 fix — semua preserved verbatim (Property 2)_
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.11, 3.12_

  - [x] 3.4 Update `CHANGELOG.md` + `dev-log.md`
    - `mypresensi-mobile/CHANGELOG.md`: tambah entry sesi sesuai konvensi rule 05 §C — `[FIX]` `scan_qr_screen.dart`, `[ADD]` `qr_decoder_service.dart`, `[CHORE]` `pubspec.yaml`. Reference BUG-019.
    - `dev-log.md` (root): append entry BUG-019 dengan Bug Retro Discipline format (rule 06 §D) — Symptom, Root cause, Why slipped past, Prevention, Files affected.
    - _Requirements: 3.13_

  - [x] 3.5 Verify Property 1: Bug Condition exploration test now PASSES
    - **Property 1: Expected Behavior** — Camera Reinitialized After Lifecycle Handoff (RMX5000)
    - **IMPORTANT**: Re-run SAME tests dari task 1 — JANGAN tulis test baru. Test dari task 1 encode expected behavior.
    - **Layer A re-run**: `flutter test test/bugfix/bug_019_dual_plugin_assertion_test.dart`
      - **EXPECTED OUTCOME**: PASS (`mobile_scanner` sudah dihapus dari `pubspec.yaml` → intersection {mobile_scanner, camera} = {camera}, size 1)
    - **Layer B re-run pada RMX5000**:
      - Build post-fix debug APK: `flutter build apk --debug`, `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
      - Re-execute Repro 1 (Cancel Verify), Repro 2 (Cancel Register), Repro 3 (Repeat 3x) dari task 1
      - Capture logcat post-fix: `adb logcat -d -v time -s "CameraDevice","CameraManager","BufferQueueConsumer","ImageReader" > docs/bugfix/bug-019-logcat-postfix-{1,2,3}.txt`
      - **EXPECTED OUTCOME**: kamera hidup ≤ 2 detik setelah pop di SETIAP cycle, scan QR baru work dengan latency ≤ 1 detik, logcat memuat `openCameraDeviceUserAsync` setelah pop (HAL re-acquire success)
      - Append result + screenshots/screencast ke `docs/bugfix/bug-019-exploration-evidence.md` (section "Post-Fix Verification")
    - **Latency parity check**: ukur decode latency 5 sample QR scan post-fix di RMX5000 → median ≤ 1 detik (paritas dengan baseline `mobile_scanner` pre-fix)
    - **Refute path**: kalau RMX5000 MASIH freeze → root cause analysis #1 refuted → STOP, eskalasi ke user untuk re-hypothesize (Plan B sudah ter-encode di task 3.3 via `WidgetsBindingObserver`; kalau Plan B juga tidak cukup, kemungkinan butuh investigasi `package:camera` OEM bug)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6 (Expected Behavior Properties dari design)_

  - [x] 3.6 Verify Property 2: Preservation tests still PASS (no regressions)
    - **Property 2: Preservation** — QR Parse Contract & Submit Pipeline Identity
    - **IMPORTANT**: Re-run SAME tests dari task 2 — JANGAN tulis test baru
    - **Layer A re-run**: `flutter test test/attendance/parse_qr_code_property_test.dart`
      - **EXPECTED OUTCOME**: PASS — `attendance_provider.dart` tidak diubah, `parseQrCode` kontrak identik
      - Verify via `git diff lib/features/attendance/providers/attendance_provider.dart` → expect 0 lines changed (Property 2 sub-point #2 invariant)
    - **Layer B re-run pada Pixel 9a emulator API 36**:
      - Re-execute 10 preservation QA items dari task 2 (mode `required`, mode `optional`, QR invalid, dialog wajah belum daftar, server errors, torch, permission, UI overlay)
      - Capture screenshot post-fix per item
      - **EXPECTED OUTCOME**: 10 items behave IDENTIK dengan baseline pre-fix dari task 2 — no visual regression, no behavioral regression
      - Append match table ke `docs/bugfix/bug-019-preservation-baseline.md` (section "Post-Fix Match")
    - **Build & static checks** (Iron Law rule 06 §A.1):
      - `flutter analyze` → expect 0 issues
      - `flutter build apk --debug` → expect exit 0
      - Verify `minSdk` masih 26 di `android/app/build.gradle.kts`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14_

- [x] 4. Checkpoint — Ensure all tests pass
  - Confirm Property 1 (Bug Condition exploration) PASSES post-fix:
    - Layer A static assertion: PASS
    - Layer B RMX5000 field reproduction: kamera hidup ≤ 2 detik setelah pop di 3 cycle, latency ≤ 1 detik, logcat trace `openCameraDeviceUserAsync` confirmed
  - Confirm Property 2 (Preservation) PASSES post-fix:
    - Layer A `parseQrCode` PBT: PASS (200 trials)
    - Layer B 10 manual QA items match baseline pre-fix
  - Confirm verification log table per rule 06 §B:

    | Check | Result |
    |-------|--------|
    | `flutter analyze` | ✅ 0 issues (target) |
    | `flutter test` (PBT + assertion) | ✅ all pass (target) |
    | `flutter build apk --debug` | ✅ exit 0 (target) |
    | RMX5000 field test (post-fix) | ⏳ user confirm via screenshot/screencast (rule 06 Law 4) |
    | Pixel 9a preservation match | ⏳ user confirm via screenshot match table |
    | `pubspec.yaml` — `mobile_scanner` removed | ✅ verified via `flutter pub deps` (target) |
    | `attendance_provider.dart` git diff | ✅ 0 lines changed (target) |
    | CHANGELOG.md + dev-log.md updated | ✅ entries BUG-019 (target) |

  - Kalau ada test failure atau RMX5000 reproduction post-fix masih freeze:
    - **STOP** — JANGAN klaim selesai (rule 06 §E anti-pattern)
    - Tanya user dengan bukti konkret (logcat snippet + reproduksi langkah)
    - Re-investigate root cause (Plan B `WidgetsBindingObserver` sudah implemented; kalau Plan B juga gagal, eskalasi untuk re-hypothesize)
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14_

## Notes

### Mengapa task ordering ini

1. **Task 1 dan Task 2 sebelum fix**:
   - Task 1 (Bug Condition exploration) WAJIB FAIL pada unfixed code → kegagalan = bukti bug exists. Ini protokol bug condition methodology — surface counterexample dulu, baru fix.
   - Task 2 (Preservation) WAJIB PASS pada unfixed code → menjamin baseline behavior yang harus dijaga. Observation-first: observe dulu di unfixed code, baru encode jadi property test.
   - Kalau fix duluan, kita kehilangan kemampuan untuk **prove** bug dan **prove** non-regression.

2. **Task 3.1 → 3.2 → 3.3 sequential**:
   - 3.1 (`pubspec.yaml`) harus jalan dulu supaya `google_mlkit_barcode_scanning` tersedia untuk import di 3.2.
   - 3.2 (`QrDecoderService`) harus ada sebelum 3.3 (refactor `ScanQrScreen`) karena screen import service.

3. **Task 3.5 dan 3.6 setelah implementasi**:
   - Re-run TEST YANG SAMA dari task 1 dan 2 — TIDAK boleh tulis test baru. Test yang sama yang FAIL pre-fix harus PASS post-fix (Property 1) dan test yang PASS pre-fix harus tetap PASS post-fix (Property 2).
   - Ini cara membuktikan fix bekerja **dan** tidak introduce regressi.

### Kenapa PBT untuk preservation, manual QA untuk UI

- **Decoder purity** (Layer A task 2) cocok untuk PBT: input domain QR string bisa di-generate, output deterministic, properties simple (purity + idempotence). 100 random samples lebih kuat dari 5 hardcoded test case.
- **UI behavior** (Layer B task 2) tidak cocok untuk PBT: visual layout, dialog flow, error routing → manual QA dengan screenshot baseline lebih praktis. Overhead PBT untuk UI > nilai yang didapat dalam scope bugfix ini.

### Kenapa RMX5000 manual repro WAJIB

- Bug ini **tidak reproduce di emulator atau Stock Android** — root cause di OEM Camera2 HAL ColorOS. Test otomatis di CI tidak bisa catch ini.
- Layer A (static assertion `pubspec.yaml`) hanya prove **structural condition** (`isBugCondition` requires 2 plugins) — tidak prove **behavioral fix** di HAL layer.
- Layer B (field repro di RMX5000) adalah satu-satunya cara prove fix bekerja **at the runtime layer**. Rule 06 Law 4 (screenshot-as-proof) apply di sini.
- Refute path: kalau RMX5000 masih freeze post-fix → root cause analysis #1 keliru → eskalasi ke user, JANGAN klaim selesai (rule 06 §E).

### Library lock compliance (rule 03)

- ❌ TIDAK boleh ganti `package:camera` → tetap `^0.12.0+1`
- ❌ TIDAK boleh ganti `google_mlkit_face_detection` → tetap `^0.13.2`
- ✅ BOLEH tambah `google_mlkit_barcode_scanning` (ekstensi serumpun ML Kit, share platform base) → ini sebenarnya **mengurangi** dependency complexity (drop ZXing native dari `mobile_scanner`, unify ke 1 ML backend)
- ❌ TIDAK boleh tambah PBT framework baru di Flutter — pakai `flutter_test` + `dart:math` saja untuk generator (sesuai pattern face-liveness-pose-hold spec)

### Files NOT Touched (preservation guarantee)

Sesuai design §Files NOT Touched:
- `lib/features/attendance/providers/attendance_provider.dart`
- `lib/features/attendance/data/attendance_models.dart`
- `lib/features/face/providers/face_provider.dart`
- `lib/features/face/screens/face_registration_screen.dart`
- `lib/features/face/screens/face_verification_screen.dart`
- `lib/features/face/services/*.dart`
- `lib/core/router/app_router.dart`
- `lib/shared/widgets/app_shell.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/build.gradle.kts`
- `mypresensi-web/**`
