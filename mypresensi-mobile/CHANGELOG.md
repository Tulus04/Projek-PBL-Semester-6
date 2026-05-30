# CHANGELOG — mypresensi-mobile

> Format: `| HH:MM | [TYPE] | <file/path> | <Penjelasan singkat Bahasa Indonesia> |`
> Jenis: `[ADD]` file/fitur baru | `[MOD]` modifikasi | `[FIX]` perbaikan bug | `[DEL]` hapus | `[CFG]` konfigurasi | `[CHORE]` build/deps/config | `[SEC]` security hardening | `[DOC]` dokumentasi | `[STYLE]` formatting

---

## [2026-05-25] — Sesi: BUG-019 Fix — Unify Camera Plugin (mobile_scanner → package:camera + ML Kit Barcode)

### Target Sesi
Refactor `ScanQrScreen` ke single-plugin Camera2 HAL claim. Hapus `mobile_scanner` total, ganti decoder QR ke `google_mlkit_barcode_scanning` di atas `package:camera` (yang sudah dipakai face flow). Eliminate dual-plugin Camera2 HAL conflict di OEM ColorOS RMX5000 yang bikin kamera back freeze setelah pop dari `/face-verify` atau `/face-register`. Spec referensi: `.kiro/specs/qr-scan-unify-camera-plugin/`.

### Mobile — Implementation BUG-019

| Waktu | Jenis | File | Deskripsi |
|-------|-------|------|-----------|
| 14:30 | [CHORE] | `mypresensi-mobile/pubspec.yaml` | BUG-019 unify plugin: drop `mobile_scanner: ^7.2.0`, tambah `google_mlkit_barcode_scanning: ^0.14.0`. Verify `flutter pub get` resolve clean dengan `google_mlkit_face_detection: ^0.13.2` (ekstensi serumpun ML Kit). Library lock rule 03: `camera: ^0.12.0+1` + `google_mlkit_face_detection: ^0.13.2` preserved |
| 14:45 | [ADD] | `mypresensi-mobile/lib/features/attendance/services/qr_decoder_service.dart` | File baru. Service `QrDecoderService` mirror pattern `face_detection_service.dart`: singleton `BarcodeScanner` ML Kit (format `[BarcodeFormat.qrCode]`), method `decodeFromCameraImage(CameraImage, CameraDescription) → String?` dengan throttle 200ms + re-entrance guard `_isProcessing`, helper `_convertCameraImage` / `_concatenatePlanes` / `_getInputImageRotation` inline. Kontrak `attendanceSubmitProvider.parseQrCode(String)` tidak berubah |
| 15:00 | [FIX] | `mypresensi-mobile/lib/features/attendance/screens/scan_qr_screen.dart` | BUG-019 root cause fix: refactor full ke `package:camera` + `QrDecoderService`. Hapus `MobileScannerController`, widget `MobileScanner`, `ValueListenableBuilder` torch, `_onDetect(BarcodeCapture)`. State baru: `CameraController? _cameraController`, `CameraDescription? _camera`, `QrDecoderService _qrDecoder`, mixin `WidgetsBindingObserver` (Plan B defensive lifecycle). `initState` async: request CAMERA permission → `availableCameras()` → `CameraController(back, ResolutionPreset.medium, nv21, audio:false)` → `initialize` → `startImageStream(_onCameraFrame)`. `_onCameraFrame` decode via `_qrDecoder` → `parseQrCode` (preserved) → kalau valid `stopImageStream` + `_processSubmit`. `_toggleTorch` pakai `setFlashMode`. `dispose` urut: removeObserver → stopImageStream → controller.dispose → qrDecoder.dispose. PRESERVED VERBATIM: `_processSubmit`, `_showFaceNotRegisteredDialog`, `_showFaceMismatchDialog`, `_showError`, `_buildScanOverlay`, `_buildTopBar`, `_buildBottomPanel`, `_buildLoadingOverlay`, `_CornerBorderPainter`, BUG-018 fix |

### Verifikasi BUG-019 (dilakukan di task 3.5 / 3.6 oleh tim QA)

| Item | Hasil |
|------|-------|
| Layer A static — `bug_019_dual_plugin_assertion_test.dart` | ⏳ task 3.5 |
| Layer A preservation PBT — `parse_qr_code_property_test.dart` | ⏳ task 3.6 |
| `flutter analyze` | ⏳ task 3.6 |
| `flutter build apk --debug` | ⏳ task 3.6 |
| Layer B field test RMX5000 (3 cycle: cancel verify / cancel register / repeat 3x) | ⏳ user runtime confirmation (rule 06 Law 4) |
| Layer B preservation Pixel 9a emulator API 36 (10 QA items match) | ⏳ user runtime confirmation |
| `pubspec.yaml` — `mobile_scanner` removed | ✅ task 3.1 |
| `attendance_provider.dart` git diff | ✅ 0 lines changed (preservation guarantee) |

### Catatan
- **Spec referensi**: `.kiro/specs/qr-scan-unify-camera-plugin/{requirements,design,tasks}.md`
- **Root cause final** (setelah 7 iterasi gagal in-place fix): Camera2 HAL driver di OEM ColorOS RMX5000 (MediaTek Helio entry-level) tidak konsisten release/re-acquire camera resource saat 2 plugin Flutter (`mobile_scanner` + `package:camera`) sama-sama claim HAL dalam 1 lifecycle session. Bug **tidak fixable di app layer** dengan workaround apapun. Path A (refactor unify plugin) approved oleh user di sesi 2026-05-24.
- **Library lock compliance (rule 03)**: `camera: ^0.12.0+1` + `google_mlkit_face_detection: ^0.13.2` tetap. `google_mlkit_barcode_scanning: ^0.14.0` ekstensi serumpun ML Kit (share platform base, **mengurangi** complexity dependency dengan drop ZXing native dari `mobile_scanner`).
- **Files NOT touched (preservation guarantee)**: `attendance_provider.dart`, `attendance_models.dart`, `face_provider.dart`, `face_registration_screen.dart`, `face_verification_screen.dart`, semua face services, `app_router.dart`, `app_shell.dart`, `AndroidManifest.xml`, `build.gradle.kts`.
- **Pending user**: runtime confirmation via field test di RMX5000 dengan logcat post-fix (`openCameraDeviceUserAsync` setelah pop dari face flow → confirm HAL re-acquire success).
