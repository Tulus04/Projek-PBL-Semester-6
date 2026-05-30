# QR Scan Unify Camera Plugin — Bugfix Design (BUG-019)

## Overview

BUG-019 adalah **plugin conflict di Camera2 HAL** — `mobile_scanner` 7.2.0 dan `package:camera` 0.12.x sama-sama claim back camera, dan driver Camera2 HAL ColorOS (Realme RMX5000, MediaTek Helio entry-level) tidak konsisten release/re-acquire resource saat handoff antar plugin Flutter dalam 1 session app. Akibatnya: setelah user push dari `ScanQrScreen` ke `/face-verify` atau `/face-register` lalu pop balik, kamera back **freeze** di frame terakhir (atau blank putih) — user harus kill & restart app untuk scan ulang.

**Strategi fix (Path A — sudah confirmed user)**: **unify** semua kebutuhan kamera ke satu plugin Flutter (`package:camera`, yang sudah di-lock di rule 03 dan dipakai face flow). `mobile_scanner` dihapus total. Decode QR diganti pakai `google_mlkit_barcode_scanning` — package serumpun dengan `google_mlkit_face_detection 0.13.2` (sudah di-lock), share platform base ML Kit yang sama → dependency tree bersih, no conflict.

**Hasil yang diharapkan**: hanya 1 plugin Flutter yang claim Camera2 HAL kapan pun → tidak ada race condition lifecycle → camera back hidup kembali setelah pop dari face flow di OEM ColorOS device. Sebagai bonus: APK shrink karena `mobile_scanner` (+ native dependency-nya) drop, dan dependency tree lebih homogen (semua kamera + ML lewat ML Kit + `package:camera`).

## Glossary

- **Bug_Condition (C)**: Kondisi yang trigger bug — runtime aplikasi punya 2 plugin Flutter aktif (`mobile_scanner` + `package:camera`) yang lifecycle-nya overlap di OEM Camera2 HAL ColorOS (RMX5000 dan kelas device serupa).
- **Property (P)**: Kamera back di `ScanQrScreen` HIDUP (live frame) dan ready scan QR baru setelah user pop dari `/face-verify` atau `/face-register`, tanpa user perlu kill app.
- **Preservation**: Semua perilaku non-bug (kontrak provider attendance, dialog flow, face screens, server-side validation, torch toggle, parse QR JSON) tetap **identik** dengan kondisi pre-fix.
- **`MobileScanner` widget** (`mobile_scanner` 7.2.0): widget yang sekarang dipakai di `ScanQrScreen` — owner internal `MobileScannerController` yang claim Camera2 HAL back camera. **Akan dihapus.**
- **`CameraController` (`package:camera`)**: controller resmi Flutter team — akan dipakai di `ScanQrScreen` untuk preview + image stream. Sudah dipakai di `face_registration_screen.dart` & `face_verification_screen.dart`.
- **`BarcodeScanner` (ML Kit)**: dari package `google_mlkit_barcode_scanning` — decode QR dari `InputImage`. Pattern API mirror dengan `FaceDetector` di `face_detection_service.dart`.
- **`QrDecoderService`**: service baru yang encapsulate `BarcodeScanner`, expose `decodeFromCameraImage(CameraImage, CameraDescription)` → `Future<String?>`. Singleton dengan flag `_isProcessing` (mirror `FaceDetectionService`).
- **Throttle 200ms**: skip frame kalau timestamp delta dari decode terakhir < 200ms — hindari over-process yang waste CPU + battery.
- **`attendanceSubmitProvider`**: Riverpod notifier di `lib/features/attendance/providers/attendance_provider.dart` — owner method `parseQrCode(String)` dan `submitFromQr(QrCodeData, faceResult: ...)`. **Tidak berubah** (kontrak preserved).
- **`faceConfigProvider`**: provider yang fetch `face_verification_mode` dari `/api/mobile/face/config`. **Tidak berubah**.

## Bug Details

### Bug Condition

Bug muncul saat di runtime aplikasi yang sama berjalan lifecycle handoff antara 2 plugin Flutter berbeda yang sama-sama claim Camera2 HAL: `mobile_scanner` 7.2.0 (back camera, di `ScanQrScreen`) dan `package:camera` 0.12.x (front camera, di face screens). OEM Camera2 HAL driver ColorOS RMX5000 tidak release resource dengan benar saat plugin lain claim — saat plugin asal ingin claim ulang setelah pop, HAL tolak `openCameraDeviceUserAsync`.

**Formal Specification:**

```
FUNCTION isBugCondition(input)
  INPUT: input of type RuntimeState
    - input.activePlugins   : Set of CameraPlugin     // plugin Flutter yang lifecycle-nya aktif & pernah claim camera HAL di session ini
    - input.deviceClass     : DeviceClass             // OEM_COLOROS | OEM_MIUI | OEM_FUNTOUCH | OEM_ONEUI | STOCK_ANDROID | IOS
    - input.cameraHandoff   : boolean                 // true bila ada minimal 1 push→pop lifecycle antar plugin (mis. mobile_scanner → package:camera → mobile_scanner)
  OUTPUT: boolean

  RETURN |input.activePlugins| >= 2
         AND {mobile_scanner, package:camera} ⊆ input.activePlugins
         AND input.deviceClass IN {OEM_COLOROS, OEM_MIUI, OEM_FUNTOUCH, OEM_ONEUI}
         AND input.cameraHandoff = true
END FUNCTION
```

**Behavior pre-fix saat C(input) = true**: setelah `cameraHandoff` selesai dan user kembali ke `ScanQrScreen`, `MobileScanner` widget gagal acquire ulang back camera — preview freeze di frame terakhir atau blank putih. `_onDetect` callback tidak pernah fire lagi karena image stream mati. User stuck — harus kill app.

**Behavior post-fix saat C(input) = true**: bug condition **tidak akan tercapai** karena setelah refactor, `|input.activePlugins ∩ {mobile_scanner, package:camera}|` ≤ 1 (hanya `package:camera`) — `mobile_scanner` sudah di-drop dari `pubspec.yaml`. Persyaratan `{mobile_scanner, package:camera} ⊆ activePlugins` tidak pernah terpenuhi.

### Examples

**Example 1 — Battle utama bug (RMX5000, mode `face_verification_mode = required`)**:
- Pre-fix: User di tab Scan → scan QR valid → push `/face-verify` → tap close (cancel) → pop balik ke `ScanQrScreen` → kamera **freeze** di frame terakhir.
- Post-fix: Sama persis flow, tapi `ScanQrScreen` pakai `package:camera` + `qrDecoderService` → setelah pop, `initState` (atau `didChangeAppLifecycleState` resume) re-create `CameraController` → preview **hidup** dengan live frame ready scan baru.

**Example 2 — Cancel registrasi wajah baru**:
- Pre-fix: User di tab Scan (mode `required`, belum register wajah) → scan QR valid → dialog "Wajah Belum Didaftarkan" → tap "Daftar Sekarang" → push `/face-register` → user back tanpa register → pop ke `ScanQrScreen` → kamera **blank putih**.
- Post-fix: Sama persis flow, kamera back hidup kembali setelah pop.

**Example 3 — Stock Android device (Pixel 9a)**:
- Pre-fix: Flow scan→face→balik bekerja normal di Stock Android (Camera2 HAL stock release/re-acquire dengan benar). Bug **tidak muncul**.
- Post-fix: Flow tetap bekerja normal — preservation requirement 3.1 terpenuhi (no regression).

**Example 4 — Edge case: torch state transition**:
- Pre-fix: User tap torch on saat scan → push face → pop balik → torch state ambigu (`MobileScanner` controller dispose).
- Post-fix: Torch via `controller.setFlashMode(FlashMode.torch / FlashMode.off)` di `package:camera` — state ter-attach ke `CameraController` baru di `initState` setelah pop (default off, user re-toggle kalau perlu). Behavior konsisten + paritas fungsional preservation 2.5.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**

1. **Kontrak provider attendance**: `attendanceSubmitProvider`, `attendanceSubmitProvider.notifier.parseQrCode(String)`, `attendanceSubmitProvider.notifier.submitFromQr(QrCodeData, faceResult: ...)`, `attendanceSubmitProvider.notifier.reset()`, dan `AttendanceSubmitState` enum — **tidak berubah satu baris pun**.
2. **Kontrak face provider**: `faceConfigProvider` + `FaceVerificationMode` enum + `FaceVerificationResult` model — tidak berubah.
3. **Face screens**: `face_registration_screen.dart` + `face_verification_screen.dart` tetap pakai `package:camera` `ResolutionPreset.high` + `imageFormatGroup: ImageFormatGroup.nv21` (Android) — tidak boleh ada perubahan di kedua file ini.
4. **Routing**: route `/scan`, `/face-verify`, `/face-register`, `/attendance-result` di `app_router.dart` tetap sama. `app_shell.dart` Scan tab tetap pakai `context.push('/scan')`.
5. **Dialog flows**: `_showFaceNotRegisteredDialog`, `_showFaceMismatchDialog`, `_showError` snackbar (BUG-018 fix) — preserved verbatim, hanya context-nya yang baru (di-host oleh `ScanQrScreen` versi refactor).
6. **Submit flow & error handling**: routing `error_code` (`face_not_registered` / `face_mismatch` / generic) ke dialog yang sesuai — tidak berubah.
7. **UI overlay scan**: corner border `_CornerBorderPainter`, top bar (back + title "Scan QR Presensi" + torch toggle), bottom panel "Arahkan kamera ke QR Code", loading overlay GPS/submit — visually identical setelah refactor.
8. **Server-side validation 5 layer**: sesi aktif → kode cocok → enrolled → belum submit → GPS in-radius (mode offline) atau skip (online), TOTP rolling, anti-mock-GPS, audit log `mobile_attendance_submit` — tidak berubah (server side).
9. **Permission CAMERA**: tetap diminta lewat `permission_handler` runtime request, reuse permission yang sama dengan face flow (tidak ada permission baru di-prompt user).
10. **`minSdk` 26** (Android 8.0 Oreo) — tidak naik, tidak turun.

**Scope:**

Semua input yang **tidak** memenuhi `isBugCondition` (yaitu: device Stock Android atau iOS, ATAU runtime hanya 1 plugin camera aktif, ATAU tidak ada cameraHandoff antar plugin) harus ber-behavior **identik** dengan kondisi pre-fix. Termasuk:

- User di Stock Android device melakukan flow scan → face → balik (preservation 3.1).
- User scan QR valid format JSON `{session_id, code}` (preservation 3.2).
- User scan QR invalid format (preservation 3.3).
- Mode `required` dengan flow dialog "Wajah Belum Didaftarkan" → register sukses → balik scan (preservation 3.4).
- Mode `required` dengan flow face-verify happy path (preservation 3.5).
- Mode `optional` legacy submit langsung (preservation 3.6).
- Server return error code `face_not_registered` / `face_mismatch` / generic (preservation 3.7).
- First-time CAMERA permission request (preservation 3.8).
- Face register/verify screens running (preservation 3.9).
- Server-side 5 layer validation (preservation 3.10).
- Happy path scan → submit → result tanpa face flow (preservation 3.11).
- Torch toggle Stock Android (preservation 3.12).
- `flutter analyze` 0 issues + `flutter build apk --debug` exit 0 (preservation 3.13).
- `minSdk` 26 (preservation 3.14).

## Hypothesized Root Cause

Berdasarkan 7 iterasi workaround in-place yang gagal (`pause/start`, `recreate controller`, `force re-mount via Key`, `tear-down + rebuild conditional render`, `pop-and-restart`, `dispose+await+rebuild`, `setState bypass`) dan logcat reading dari device RMX5000 (`BufferQueueConsumer connect` → `ImageReader disconnect` → `System onCameraAvailable: 1`, tapi **tidak ada `openCameraDeviceUserAsync` setelah pop**), root cause utama:

1. **Plugin Conflict di Camera2 HAL Layer (root cause utama, confidence tinggi)**:
   - `mobile_scanner` 7.2.0 dan `package:camera` 0.12.x adalah **dua plugin Flutter independen** dengan native code Android terpisah.
   - Keduanya memanggil `CameraManager.openCamera()` di Camera2 API Android, dan masing-masing manage lifecycle `CameraDevice` sendiri.
   - OEM ColorOS Camera2 HAL driver tidak konsisten release `CameraDevice` saat plugin lain claim — saat `package:camera` claim front, HAL "lupa" lepas back yang tadinya di-claim `mobile_scanner`. Saat `MobileScanner` widget rebuild setelah pop, HAL tolak claim ulang.
   - **Bukti**: bug **tidak muncul** di Stock Android (Pixel) dan iOS — HAL stock + iOS AVFoundation handle multi-plugin dengan benar. Bug **muncul konsisten** di kelas device OEM (ColorOS RMX5000 confirmed; MIUI/FunTouch/OneUI suspected based on common Camera2 HAL quirk).
   - **Implication**: bug **tidak fixable** dari layer Flutter pakai workaround in-place — semua layer Flutter dependent ke native HAL driver. Solusi harus **eliminate** salah satu plugin = unify.

2. **Internal Lifecycle Race di `MobileScanner` Widget (root cause sekunder)**:
   - `MobileScanner` widget package `mobile_scanner` punya internal `MobileScannerController` yang dispose otomatis di widget `dispose()` lifecycle.
   - Saat user pop dari face screen, `ScanQrScreen` `initState` jalan ulang dan create controller baru — tapi tidak ada hook untuk koordinasi dengan native HAL state.
   - 7 iterasi workaround (force re-mount via Key, dispose+rebuild manual) gagal karena ini **race condition** vs internal package lifecycle, tidak fixable dari layer aplikasi.
   - **Implication**: ganti `MobileScanner` widget dengan `CameraPreview` + manual stream yang kita kontrol penuh = lifecycle deterministic, no race.

3. **Dependency Tree Dual ML Backend (root cause tersier, dependency hygiene)**:
   - `mobile_scanner` pakai ZXing native (Android) untuk decode barcode.
   - `google_mlkit_face_detection` (sudah locked) pakai Google ML Kit native.
   - Project punya 2 ML backend native paralel — APK lebih besar, dependency conflict potential.
   - Pakai `google_mlkit_barcode_scanning` (ekstensi natural ML Kit) hilangkan ZXing → 1 ML backend → APK shrink + dependency homogen.

**Refute path**: kalau setelah implementasi fix kamera **masih freeze** di RMX5000, hipotesis di atas refuted dan kita perlu re-investigate. Kemungkinan: (a) `package:camera` sendiri punya bug di OEM (jarang, package resmi Flutter team), (b) `permission_handler` flow merusak HAL state, (c) Android lifecycle (`onPause`/`onResume`) yang tidak ter-handle saat pop GoRouter. Mitigasi: tambah lifecycle observer (`WidgetsBindingObserver.didChangeAppLifecycleState`) untuk dispose+reinit explicit. **Tapi** ini Plan B — Plan A confidence tinggi karena fix-nya at the root (eliminate plugin conflict).

## Correctness Properties

Property 1: Bug Condition — Camera Reinitialized After Lifecycle Handoff

_For any_ runtime state where the user mounts `ScanQrScreen`, navigates to `/face-verify` or `/face-register` (push), and then returns to `ScanQrScreen` (pop) on an OEM ColorOS device (RMX5000 or equivalent class) — the fixed `ScanQrScreen` SHALL produce a `CameraController` whose `value.isInitialized == true` within 2 seconds of pop, deliver live image frames to `_onCameraFrame` callback at ≥ 5 frames/second, and successfully decode a valid QR JSON via `qrDecoderService.decodeFromCameraImage` with end-to-end latency ≤ 1 second — **without** the user killing or restarting the app. This satisfies functional parity with the latency baseline of `mobile_scanner` while eliminating the freeze symptom.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.6**

Property 2: Preservation — QR Decoder & Submit Contract Identity

_For any_ input where `isBugCondition(input) == false` (i.e., the runtime is not in the dual-plugin-handoff state — either the device is Stock Android/iOS, or there is no plugin handoff, or only one camera plugin is active), the fixed code SHALL:

1. **Decoder purity**: For any valid QR raw string `s` of format `{"session_id":"<uuid>","code":"<6-digit>"}`, `qrDecoderService.decodeFromCameraImage(simulated_image_with_QR(s), camera)` SHALL return a value `equals(s)`. For any invalid QR (non-JSON, missing fields, empty bytes), it SHALL return `null`. The decoder behaves as a **pure function** of the QR content — no side effects, no state mutation across calls.
2. **Submit pipeline identity**: For any valid `QrCodeData` `q` and optional `FaceVerificationResult` `f`, `attendanceSubmitProvider.notifier.submitFromQr(q, faceResult: f)` SHALL produce **identical** state transitions and HTTP request body as the pre-fix code (provider not modified).
3. **UI behavior identity**: Top bar (back + title + torch), overlay frame, bottom panel "Arahkan kamera ke QR Code", loading overlays, dialog flows (`_showFaceNotRegisteredDialog`, `_showFaceMismatchDialog`, `_showError`), error code routing — visually and functionally identical to pre-fix.
4. **Build & analyze**: `flutter analyze` 0 issues; `flutter build apk --debug` exit 0; `minSdk` remains 26.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14**

## Fix Implementation

### Changes Required

Asumsi root cause analysis #1 (plugin conflict di Camera2 HAL) benar, fix unify ke `package:camera` + `google_mlkit_barcode_scanning`.

**File 1**: `mypresensi-mobile/pubspec.yaml`

**Specific Changes**:

1. **DROP**: hapus baris `mobile_scanner: ^7.2.0` di section `# === Device ===`.
2. **ADD**: tambah `google_mlkit_barcode_scanning: ^0.14.0` (atau versi yang share platform base sama dengan `google_mlkit_face_detection: ^0.13.2` — wajib verify saat install agar dependency tree resolve clean; cek `pub get` output).
3. **VERIFY**: `flutter pub get` sukses, tidak ada conflict resolution. `flutter analyze` masih 0 issues.

**File 2** (BARU): `mypresensi-mobile/lib/features/attendance/services/qr_decoder_service.dart`

**Specific Changes**:

1. **Service kelas baru** dengan API mirror `face_detection_service.dart`:
   ```
   class QrDecoderService {
     BarcodeScanner? _barcodeScanner;
     bool _isProcessing = false;
     int _lastDecodeMs = 0;
     static const int _throttleMs = 200;

     void initialize();                                                          // construct BarcodeScanner singleton
     Future<String?> decodeFromCameraImage(CameraImage, CameraDescription);      // throttled decode
     Future<void> dispose();                                                     // close ML Kit scanner
   }
   ```
2. **Konversi `CameraImage` → `InputImage`**: reuse pattern `_convertCameraImage`, `_concatenatePlanes`, `_getInputImageRotation` dari `face_detection_service.dart` — bisa di-extract ke util shared kalau code duplication signifikan, tapi DEFAULT-nya **duplikasi inline** untuk avoid scope creep di bugfix ini.
3. **Throttle**: kalau `DateTime.now().millisecondsSinceEpoch - _lastDecodeMs < _throttleMs` → return `null` (skip frame). Update `_lastDecodeMs` setelah decode selesai.
4. **Re-entrance guard**: flag `_isProcessing` mirror `FaceDetectionService` — kalau frame baru masuk saat decode sebelumnya belum selesai → return `null`.
5. **Output**: kalau ML Kit return list barcode tidak kosong, return `barcodes.first.rawValue`. Kalau list kosong atau `rawValue == null` → return `null`. Format barcode tidak di-filter (QR / Code128 / dll) — kontrak parse tetap di `attendanceSubmitProvider.parseQrCode`, biar QR JSON `{session_id, code}` lolos parse, format lain auto-rejected via JSON parse failure.
6. **Comment header Bahasa Indonesia singkat** sesuai konvensi rule 02 §A.6 — jelaskan tujuan + catatan keamanan.

**File 3** (REFACTOR): `mypresensi-mobile/lib/features/attendance/screens/scan_qr_screen.dart`

**Specific Changes**:

1. **Hapus import & usage `mobile_scanner`**: `import 'package:mobile_scanner/mobile_scanner.dart'`, `MobileScannerController _scannerController`, `MobileScanner(...)` widget, `_onDetect(BarcodeCapture)` signature lama.
2. **Tambah import**: `package:camera/camera.dart`, `package:permission_handler/permission_handler.dart`, `../services/qr_decoder_service.dart`.
3. **State baru**: `CameraController? _cameraController`, `CameraDescription? _camera`, `QrDecoderService _qrDecoder = QrDecoderService()`, `bool _isCameraReady = false`, `bool _isTorchOn = false`, `bool _permissionDenied = false`.
4. **`initState()`** baru — async sequence:
   - Reset `attendanceSubmitProvider` (preserved).
   - Request CAMERA permission via `permission_handler` (reuse pattern face flow). Kalau denied → set `_permissionDenied = true`, tampilkan UI fallback (icon + text "Izin kamera diperlukan untuk scan QR..." + tombol "Buka Pengaturan" via `openAppSettings()`).
   - `availableCameras()` → cari `CameraLensDirection.back`. Kalau tidak ada → tampilkan error.
   - `_cameraController = CameraController(camera, ResolutionPreset.medium, imageFormatGroup: ImageFormatGroup.nv21, enableAudio: false)`. **`ResolutionPreset.medium`** cukup untuk QR (vs `high` di face) — hemat CPU + battery.
   - `await _cameraController!.initialize()`.
   - `_qrDecoder.initialize()`.
   - `await _cameraController!.startImageStream(_onCameraFrame)`.
   - `setState(() => _isCameraReady = true)`.
5. **`_onCameraFrame(CameraImage)`** baru:
   - Guard `_isProcessing` (preserved dari logic existing).
   - Call `final raw = await _qrDecoder.decodeFromCameraImage(image, _camera!)`.
   - Kalau `raw == null` → return.
   - Call `final qrData = ref.read(attendanceSubmitProvider.notifier).parseQrCode(raw)` — kontrak preserved.
   - Kalau `qrData == null` → `_showError('QR code tidak valid...')` — preserved.
   - Kalau valid: `setState(() => _isProcessing = true)`, `await _cameraController!.stopImageStream()` (avoid frame masuk saat processing), call `_processSubmit(qrData)` — logic submit preserved verbatim dari existing.
6. **`dispose()`** baru:
   - `_cameraController?.stopImageStream()` (kalau masih streaming).
   - `_cameraController?.dispose()`.
   - `_qrDecoder.dispose()`.
   - `super.dispose()`.
7. **Lifecycle observer (defensive, optional)**: implement `WidgetsBindingObserver.didChangeAppLifecycleState` — saat `AppLifecycleState.resumed` cek `_cameraController` masih initialized; kalau tidak → re-init. Defensive against background→foreground edge case.
8. **`build()`** baru:
   - Kalau `_permissionDenied` → tampilkan permission UI fallback (Bahasa Indonesia ramah + tombol "Buka Pengaturan").
   - Kalau `!_isCameraReady` → tampilkan loading indicator full screen (dengan icon + label "Mempersiapkan kamera...").
   - Kalau ready → `Stack` dengan `CameraPreview(_cameraController!)` di base, lalu overlay frame (`_buildScanOverlay` — preserved verbatim), top bar (`_buildTopBar` — preserved tapi `torch toggle` sekarang call `_toggleTorch()` yang pakai `_cameraController!.setFlashMode(...)`), bottom panel (`_buildBottomPanel` — preserved verbatim), loading overlay (`_buildLoadingOverlay` — preserved verbatim).
9. **Torch toggle baru** (`_toggleTorch`):
   ```
   final newState = !_isTorchOn;
   await _cameraController!.setFlashMode(newState ? FlashMode.torch : FlashMode.off);
   setState(() => _isTorchOn = newState);
   ```
   Replace `ValueListenableBuilder(_scannerController)` dengan plain `setState` — update icon di top bar dari `_isTorchOn`.
10. **`_processSubmit`, `_showFaceNotRegisteredDialog`, `_showFaceMismatchDialog`, `_showError`**: **preserved verbatim** dari existing code — termasuk BUG-018 fix (markFaceRegistered + invalidate config setelah register sukses), error code routing, dialog UI (Iconsax bulk + AppColors token).
11. **Comment header file** Bahasa Indonesia: jelaskan refactor BUG-019 (unify camera plugin), reference spec `qr-scan-unify-camera-plugin`.

**File 4** (UPDATE): `mypresensi-mobile/CHANGELOG.md`

**Specific Changes**: tambah entry sesi sesuai konvensi rule 05 §C — tipe `[FIX]` untuk `scan_qr_screen.dart`, `[ADD]` untuk `qr_decoder_service.dart`, `[CHORE]` untuk `pubspec.yaml`. Reference BUG-019.

**File 5** (UPDATE): `dev-log.md`

**Specific Changes**: append entry BUG-019 dengan format Bug Retro Discipline (rule 06 §D) — Symptom, Root cause, Why slipped past, Prevention, Files affected.

### Files NOT Touched (preservation guarantee)

- `mypresensi-mobile/lib/features/attendance/providers/attendance_provider.dart` — kontrak provider preserved
- `mypresensi-mobile/lib/features/attendance/data/attendance_models.dart` — kontrak model preserved
- `mypresensi-mobile/lib/features/face/providers/face_provider.dart` — preserved
- `mypresensi-mobile/lib/features/face/screens/face_registration_screen.dart` — preserved
- `mypresensi-mobile/lib/features/face/screens/face_verification_screen.dart` — preserved
- `mypresensi-mobile/lib/features/face/services/*.dart` — preserved
- `mypresensi-mobile/lib/core/router/app_router.dart` — preserved
- `mypresensi-mobile/lib/shared/widgets/app_shell.dart` — preserved
- `mypresensi-mobile/android/app/src/main/AndroidManifest.xml` — permission CAMERA sudah ada, tidak ada permission baru
- `mypresensi-mobile/android/app/build.gradle.kts` — `minSdk 26` preserved
- `mypresensi-web/**` — server side tidak berubah

## Testing Strategy

### Validation Approach

Strategi 2 fase: **(1) surface counterexample bug** di unfixed code untuk konfirmasi root cause, lalu **(2) verify fix** + preservation di fixed code. Karena bug-nya adalah **runtime native HAL conflict di OEM device**, verification utama adalah **manual field test di RMX5000** (user device). PBT cover decoder purity (Property 2 sub-point #1) sebagai automated guarantee.

### Exploratory Bug Condition Checking

**Goal**: Konfirmasi root cause analysis dengan reproduce bug konsisten di RMX5000 sebelum implementasi fix. Refute = re-hypothesize.

**Test Plan**: Manual reproduction di RMX5000 dengan `flutter run` build debug pre-fix, ulangi 3-5 kali untuk konsistensi.

**Test Cases**:

1. **Repro Bug Mode `required` + Cancel Verify**: Login mahasiswa terdaftar wajah → tab Scan → scan QR aktif valid → push `/face-verify` → tap close → pop balik → **observe**: kamera back freeze ≥ 5 detik tanpa recovery (will fail = match symptom).
2. **Repro Bug Mode `required` + Cancel Register**: Login mahasiswa belum register wajah → tab Scan → scan QR valid → dialog "Wajah Belum Didaftarkan" → "Daftar Sekarang" → push `/face-register` → back tanpa register → pop balik → **observe**: kamera back blank putih (will fail = match symptom).
3. **Negative Control Stock Android**: Reproduce sama di Pixel 9a emulator API 36 → **observe**: kamera hidup normal setelah pop → konfirmasi bug device-specific (will pass = expected).
4. **Negative Control Tanpa Face Flow**: Login → tab Scan → scan QR → submit langsung (mode `optional`) → result → tab Beranda → balik tab Scan → **observe**: kamera hidup (will pass = bug HANYA saat plugin handoff).

**Expected Counterexamples**:

- Test 1 & 2: kamera freeze/blank di RMX5000 setelah pop. Konfirmasi root cause #1 (plugin conflict).
- Logcat trace: `BufferQueueConsumer connect` → `ImageReader disconnect` → `System onCameraAvailable: 1` tanpa `openCameraDeviceUserAsync` setelahnya.
- Possible causes (kalau test 3 atau 4 fail di luar ekspektasi): (a) Camera2 HAL bug deeper, (b) lifecycle GoRouter merusak state, (c) `package:camera` sendiri buggy di OEM. Mitigasi → re-hypothesize.

### Fix Checking

**Goal**: Verify fix working — semua input yang sebelumnya `isBugCondition = true` sekarang produce expected behavior (kamera hidup post-pop).

**Pseudocode:**

```
FOR ALL input WHERE isBugCondition_old(input) DO   // device OEM ColorOS, plugin handoff scenario
  state := simulateScanQrScreen_fixed(input)
  ASSERT state.cameraController.isInitialized == true WITHIN 2 seconds of pop
  ASSERT state.imageStream produces frames at >= 5 fps
  ASSERT decodeFromCameraImage(simulatedQR) returns rawValue WITHIN 1 second
END FOR
```

**Test Plan**: Manual field test di RMX5000 dengan APK debug post-fix (`flutter build apk --debug` → `adb install`). Reproduce 3-5 kali untuk konsistensi. Logcat capture untuk konfirmasi `openCameraDeviceUserAsync` jalan setelah pop.

**Test Cases di RMX5000 (user device)**:

1. **Mode `required` + Cancel Verify (post-fix)**: Repro skenario test 1 di atas → **expect**: kamera hidup ≤ 2 detik setelah pop, scan QR baru work, latency decode ≤ 1 detik.
2. **Mode `required` + Cancel Register (post-fix)**: Repro skenario test 2 di atas → **expect**: kamera hidup setelah pop.
3. **Mode `required` + Verify Sukses Submit**: Scan → push verify → liveness pass → pop result → mode happy path → **expect**: result screen tampil, audit `mobile_attendance_submit` tercatat di server (cek `/audit` web).
4. **Repeat Loop 3x**: Scan → cancel → balik → scan → cancel → balik → scan (3 cycle dalam 1 session app) → **expect**: kamera hidup di setiap cycle (no degradation).
5. **Edge — Battery Saver / Background**: Push to background saat scan → resume → **expect**: kamera re-initialize via lifecycle observer.

### Preservation Checking

**Goal**: Verify untuk semua input dengan `¬isBugCondition`, fixed code produce output identik dengan original.

**Pseudocode:**

```
FOR ALL input WHERE NOT isBugCondition(input) DO   // Stock Android, iOS, atau no plugin handoff
  ASSERT scanQrScreen_original(input).visualOutput      == scanQrScreen_fixed(input).visualOutput
  ASSERT scanQrScreen_original(input).submitContract    == scanQrScreen_fixed(input).submitContract
  ASSERT scanQrScreen_original(input).dialogFlow        == scanQrScreen_fixed(input).dialogFlow
  ASSERT scanQrScreen_original(input).errorRouting      == scanQrScreen_fixed(input).errorRouting
  ASSERT qrDecoderService_fixed.decodeFromCameraImage(simulated_image_with_QR(s), camera) == s    // pure function
END FOR
```

**Testing Approach**: Property-based testing **direkomendasikan untuk decoder purity** (Property 2 sub-point #1) karena:

- Generate random valid QR strings (UUID + 6-digit code) + random invalid strings → cover input domain QR string
- Catch edge case di JSON parsing / encoding / unicode yang manual unit test sering miss
- Strong guarantee bahwa decoder behave sebagai pure function — no state leakage antar call

**Untuk preservation lain (UI, dialog, submit pipeline)**: manual QA di Stock Android emulator (Pixel 9a API 36) lebih praktis — assertion visual + behavioral observation. PBT untuk UI overhead-nya lebih besar dari nilai yang didapat di scope bugfix ini.

**Test Plan**: Observe behavior pre-fix di emulator Stock Android untuk baseline, lalu manual QA matching post-fix di emulator yang sama. PBT decoder dijalankan via `flutter test` headless.

**Test Cases**:

1. **Preservation Stock Android Happy Path**: Login → tab Scan (Pixel 9a) → scan QR valid mode `required` → face verify sukses → submit → result. **Expect**: identik pre-fix (visual + state).
2. **Preservation Mode `optional`**: Login → tab Scan → scan QR valid mode `optional` → submit langsung tanpa face. **Expect**: identik pre-fix.
3. **Preservation QR Invalid**: Scan QR non-JSON / JSON tanpa field wajib. **Expect**: snackbar error "QR code tidak valid..." (preserved verbatim).
4. **Preservation Server Error Routing**: Mock server return `error_code: face_not_registered` / `face_mismatch` / generic. **Expect**: dialog/snackbar yang sesuai (preserved).
5. **Preservation Torch Toggle**: Tap torch icon di top bar → flash on/off. **Expect**: icon update + flash physical hardware response.
6. **Preservation Dialog Wajah Belum Daftar**: Mode `required` + belum register → scan QR → dialog muncul → tap "Daftar Sekarang" → push register → sukses → pop → **expect**: BUG-018 fix preserved (`markFaceRegistered` + `invalidate(faceConfigProvider)` + auto-resume scan).

### Unit Tests

- **`QrDecoderService.decodeFromCameraImage` purity**: input `CameraImage` simulated dengan QR `{session_id: <uuid>, code: <6-digit>}` → expect rawValue exactly match.
- **`QrDecoderService` throttle**: 10 frame berturut dalam 50ms → expect 9 dari 10 return `null` (throttled).
- **`QrDecoderService` re-entrance**: simulate concurrent call saat `_isProcessing = true` → expect return `null` segera.
- **`QrDecoderService.dispose`**: setelah dispose, call `decodeFromCameraImage` lagi → expect graceful (return `null`) atau throw `StateError` yang ter-handle di caller.
- **Permission denied path**: simulate `Permission.camera.request()` return `denied` → expect `_permissionDenied = true` + UI fallback render.

### Property-Based Tests

- **Property 2 sub-point #1 — Decoder Purity** (file test: `test/attendance/qr_decoder_service_test.dart`):
   - Generator: random valid QR JSON `{"session_id": <uuid v4>, "code": <6-digit string>}` + random invalid string (bytes, malformed JSON, missing fields, empty, null, unicode emoji).
   - Property: `decodeFromCameraImage(simulated_image_with_QR(s), camera)` for valid `s` returns value `equals(s)`; for invalid returns `null`.
   - Number of trials: 100 random valid + 100 random invalid (default `flutter_test` matchers + custom generator helper).
   - **Note**: PBT framework di Flutter — pakai `flutter_test` + manual generator (no native `quickcheck`-like lib di-lock di rule 03). Acceptable scope karena decoder kontrak sederhana.
- **Property 2 sub-point #2 — Submit Pipeline Identity**: NOT tested via PBT in this spec. Provider tidak berubah → identity guaranteed by file unchanged. Verify via `git diff` — should show 0 lines changed in `attendance_provider.dart`.

### Integration Tests

- **End-to-end di emulator Stock Android (Pixel 9a)**: scan QR test session aktif (manual generate via web `/dosen/sessions/[id]`) → face verify → submit → result page → notifications.
- **End-to-end di RMX5000 (user device)**: same flow, dengan focus repeat 3x dalam 1 session app.
- **Visual feedback**: torch on saat dim environment → frame visible. Loading overlay GPS/submit muncul dengan label correct. Dialog flows render dengan AppColors token + Iconsax bulk icon.
- **Lifecycle**: app background → resume → camera re-initialize. Switch tab Beranda → balik Scan → camera re-initialize.

---

## Verifikasi Phase 2 (Design)

| Check | Result |
|-------|--------|
| `getDiagnostics` | ➖ N/A (markdown file, tidak ada diagnostic provider untuk Bugfix Design Format) |
| Coverage Property 1 ↔ Expected Behavior 2.1, 2.2, 2.3, 2.4, 2.6 | ✅ Mapped |
| Coverage Property 2 ↔ Unchanged Behavior 3.1–3.14 | ✅ Mapped |
| Bug Condition formal pseudocode | ✅ FUNCTION isBugCondition |
| Hypothesized root cause (≥ 3 kategori) | ✅ 3 kategori (HAL conflict, internal lifecycle race, dependency tree) |
| Fix Implementation per file | ✅ pubspec.yaml + qr_decoder_service.dart (BARU) + scan_qr_screen.dart (REFACTOR) |
| Testing Strategy 3 kategori | ✅ Unit + PBT + Integration |
| Files preserved (no-touch list) | ✅ Eksplisit didaftarkan |

**Catatan**: Phase 2 selesai di sini. User klik tombol UI untuk move ke Phase 3 (Tasks). Saya tidak boleh lanjut ke Tasks tanpa konfirmasi.
