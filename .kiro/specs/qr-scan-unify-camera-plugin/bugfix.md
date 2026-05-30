# Bugfix Requirements Document — BUG-019: QR Scan Unify Camera Plugin

## Introduction

BUG-019 adalah bug Camera2 HAL plugin conflict di OEM ColorOS (Realme RMX5000, MediaTek Helio entry-level). Saat user di tab Scan, scan QR valid, lalu push ke `/face-verify` atau `/face-register`, kemudian pop balik ke `ScanQrScreen`, kamera back **freeze di frame terakhir** (atau tampil blank putih). User tidak bisa scan ulang dalam session app yang sama — harus kill & restart app.

Root cause: dua plugin Flutter berebut Camera2 HAL — `mobile_scanner` 7.2.0 untuk back camera (scan QR) dan `package:camera` 0.12.x untuk front camera (face register/verify). Driver Camera2 HAL ColorOS tidak konsisten release/re-acquire camera resource saat plugin lain claim. Logcat menunjukkan urutan `BufferQueueConsumer connect` → `ImageReader disconnect` → `System onCameraAvailable: 1` tapi **tidak ada `openCameraDeviceUserAsync` setelah balik dari face screen** — HAL menolak claim ulang dalam 1 session app.

**7 iterasi workaround in-place sudah gagal** (pause/start, recreate controller, force re-mount via Key, tear-down + rebuild conditional render, pop-and-restart): semua race condition vs internal `MobileScanner` widget lifecycle, tidak fixable dari layer Flutter. Stock Android dan iOS tidak terdampak, tapi kelas device OEM (ColorOS / MIUI / FunTouch / OneUI) prevalent di kalangan target user (mahasiswa Politani) — bug ini blocking flow presensi inti.

**Path forward (user sudah confirm Path A)**: unify plugin camera. Hapus `mobile_scanner` total, pakai `package:camera` (yang sudah dipakai di face screens) untuk SCAN QR juga. Decode QR dari image stream pakai `google_mlkit_barcode_scanning` (ekstensi natural dari `google_mlkit_face_detection` yang sudah locked di rule 03). Cuma 1 plugin claim camera HAL = no race condition.

**Impact**: BUG-019 affect user inti (mahasiswa Politani dengan device entry-level OEM) di flow utama (scan presensi). Tanpa fix, user harus kill & restart app setiap kali balik dari face flow — UX rusak total. Dengan fix, plugin conflict di-eliminate at the root, sekaligus menghilangkan dependency `mobile_scanner` (mengurangi APK size & rebuild reliability).

## Bug Analysis

### Current Behavior (Defect)

Berikut perilaku salah yang terjadi pada UNFIXED code (saat ini menggunakan `mobile_scanner` di `ScanQrScreen` + `package:camera` di face screens):

1.1 WHEN user di tab Scan → scan QR valid → push ke `/face-verify` → tap close button (cancel) → pop balik ke `ScanQrScreen` di OEM ColorOS device THEN `MobileScanner` widget menampilkan kamera back preview FREEZE di frame terakhir sebelum push (atau blank putih) dan tidak bisa scan QR baru.

1.2 WHEN user di tab Scan → scan QR valid → push ke `/face-register` → complete atau cancel registrasi → pop balik ke `ScanQrScreen` di OEM ColorOS device THEN `MobileScanner` widget menampilkan kamera back preview FREEZE atau blank dan tidak bisa scan QR baru.

1.3 WHEN user mengalami kondisi 1.1 atau 1.2 lalu menekan back / switch tab / re-enter Scan tab THEN kamera tetap freeze karena Camera2 HAL menolak `openCameraDeviceUserAsync` ulang dalam 1 session app yang sama.

1.4 WHEN system memiliki dua plugin Flutter aktif yang sama-sama claim Camera2 HAL (`mobile_scanner` + `package:camera`) di lifecycle yang sama THEN OEM Camera2 HAL ColorOS tidak konsisten release/re-acquire camera resource sehingga preview rusak setelah handoff antar plugin.

### Expected Behavior (Correct)

Setelah fix (FIXED code menggunakan `package:camera` + `google_mlkit_barcode_scanning` untuk scan QR, menghapus `mobile_scanner`):

2.1 WHEN user di tab Scan → scan QR valid → push ke `/face-verify` → tap close button (cancel) → pop balik ke `ScanQrScreen` di OEM ColorOS device THEN system SHALL menampilkan kamera back preview yang HIDUP (live frame) dan ready menerima scan QR baru tanpa user perlu kill app.

2.2 WHEN user di tab Scan → scan QR valid → push ke `/face-register` → complete atau cancel registrasi → pop balik ke `ScanQrScreen` di OEM ColorOS device THEN system SHALL menampilkan kamera back preview yang HIDUP (live frame) dan ready menerima scan QR baru tanpa user perlu kill app.

2.3 WHEN user mengalami kondisi 2.1 atau 2.2 lalu scan QR baru di sesi berbeda atau sesi yang sama THEN system SHALL men-decode QR code dengan latency ≤ 1 detik per scan attempt di RMX5000 (paritas dengan latency `mobile_scanner` saat ini).

2.4 WHEN aplikasi runtime aktif THEN system SHALL menggunakan SATU plugin camera (`package:camera`) untuk semua kebutuhan kamera (scan QR back camera + face register/verify front camera) sehingga tidak ada dua plugin Flutter yang berebut Camera2 HAL pada lifecycle yang sama.

2.5 WHEN user toggle torch di `ScanQrScreen` THEN system SHALL meng-on/off-kan flash back camera sesuai input (paritas fungsional dengan torch toggle existing di `mobile_scanner`).

2.6 WHEN user push dari Scan ke face screen lalu pop balik THEN `ScanQrScreen` SHALL men-dispose `CameraController` saat `dispose()` lifecycle dan men-initialize ulang saat `initState()` (atau `didChangeAppLifecycleState` resume) sehingga camera resource tertata clean tanpa leak.

### Unchanged Behavior (Regression Prevention)

Perilaku yang HARUS tetap sama setelah fix:

3.1 WHEN user di Stock Android device atau iOS device melakukan flow scan QR → face verify → balik ke Scan THEN system SHALL CONTINUE TO menampilkan kamera back hidup dan ready scan baru (tidak mengintroduksi regresi di device yang sebelumnya OK).

3.2 WHEN user scan QR valid (format JSON `{session_id, code}`) THEN system SHALL CONTINUE TO men-parse via `attendanceSubmitProvider.parseQrCode(rawValue)` dan trigger `submitFromQr(qrData, faceResult: ...)` flow tanpa perubahan kontrak (provider & repository attendance tidak berubah).

3.3 WHEN user scan QR yang format-nya tidak valid (non-JSON, JSON tanpa field wajib) THEN system SHALL CONTINUE TO menampilkan snackbar error Bahasa Indonesia "QR code tidak valid. Pastikan Anda memindai QR presensi yang benar." tanpa crash.

3.4 WHEN `face_verification_mode` = `required` dan user belum register wajah saat scan QR valid THEN system SHALL CONTINUE TO menampilkan dialog "Wajah Belum Didaftarkan" dengan CTA "Daftar Sekarang" / "Nanti Saja" (logic gate face mode tidak berubah).

3.5 WHEN `face_verification_mode` = `required` dan user sudah register wajah saat scan QR valid THEN system SHALL CONTINUE TO push ke `/face-verify`, menerima `FaceVerificationResult` dari pop, dan submit ke server dengan field `faceConfidence`/`isFaceMatched`/`isLivenessPassed` (kontrak submit tidak berubah).

3.6 WHEN `face_verification_mode` = `optional` dan user scan QR valid THEN system SHALL CONTINUE TO submit langsung tanpa face verify (backward compat).

3.7 WHEN server return error code `face_not_registered`, `face_mismatch`, atau error generik saat submit attendance THEN system SHALL CONTINUE TO menampilkan dialog/snackbar yang sesuai (`_showFaceNotRegisteredDialog`, `_showFaceMismatchDialog`, `_showError`) dengan kontrak yang sama.

3.8 WHEN user buka tab Scan untuk pertama kali (cold start) THEN system SHALL CONTINUE TO meminta `CAMERA` permission via runtime request (atau pakai permission yang sudah granted untuk face flow) tanpa minta permission baru karena `package:camera` reuse permission yang sama dengan `mobile_scanner`.

3.9 WHEN face register/verify screens (`/face-register`, `/face-verify`) running THEN system SHALL CONTINUE TO menggunakan `package:camera` `ResolutionPreset.high` dengan `imageFormatGroup: ImageFormatGroup.nv21` (Android) untuk capture frame face — tidak ada perubahan di face screens.

3.10 WHEN user submit attendance dengan QR yang valid THEN system SHALL CONTINUE TO mempertahankan kontrak server-side validation 5 layer (sesi aktif → kode cocok → enrolled → belum submit → GPS in-radius / mode online), TOTP rolling, anti-mock-GPS, dan audit log `mobile_attendance_submit` (tidak ada perubahan server-side).

3.11 WHEN user di tab Scan tanpa interaksi dengan face flow (scan QR → submit → result → kembali ke Scan) THEN system SHALL CONTINUE TO menampilkan kamera back preview yang hidup dan responsive (tidak mengintroduksi regresi di flow happy-path).

3.12 WHEN user toggle torch saat pre-fix di Stock Android THEN system SHALL CONTINUE TO meng-on/off-kan flash back camera (torch toggle preservation).

3.13 WHEN APK di-build dengan `flutter build apk --debug` setelah fix THEN system SHALL CONTINUE TO sukses (exit 0) dan `flutter analyze` 0 issues (paritas dengan kondisi pre-fix).

3.14 WHEN APK di-install di device dengan `minSdk` 26 (Android 8.0 Oreo) THEN system SHALL CONTINUE TO bisa run scan QR feature (tidak menaikkan minSdk requirement).
