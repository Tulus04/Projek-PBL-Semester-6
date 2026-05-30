// lib/features/attendance/screens/scan_qr_screen.dart
// Halaman scanner QR code — full-screen kamera dengan overlay frame.
// Setelah scan berhasil, auto-submit presensi (GPS + API call).
// Menampilkan loading overlay saat proses submit berlangsung.
//
// REFAKTOR BUG-019 (spec `qr-scan-unify-camera-plugin`, sesi 2026-05-15):
// Migrasi dari `mobile_scanner` ke `package:camera` + `QrDecoderService`
// (`google_mlkit_barcode_scanning`). Tujuan: menyatukan kamera ke 1 plugin
// Flutter agar Camera2 HAL OEM (ColorOS RMX5000, MIUI, FunTouch, OneUI)
// tidak gagal release/re-acquire setelah lifecycle handoff ke face flow.
// Sebelumnya `mobile_scanner` (back) + `package:camera` (front) berebut
// HAL → preview freeze setelah pop dari `/face-verify` atau
// `/face-register`. 7 iterasi workaround in-place gagal — fix at the root
// dengan eliminasi plugin conflict.
//
// PRESERVATION (Property 2 di design):
//   • Kontrak `attendanceSubmitProvider.parseQrCode/submitFromQr` tidak berubah.
//   • Dialog flow + error routing (face_not_registered, face_mismatch, generic) preserved.
//   • UI overlay (top bar, corner border, bottom panel, loading overlay) visually identical.
//   • BUG-018 fix (markFaceRegistered + invalidate faceConfigProvider) preserved.
//   • CAMERA permission tetap via `permission_handler` runtime request.

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../face/data/face_config_models.dart';
import '../../face/data/face_models.dart';
import '../../face/providers/face_provider.dart';
import '../data/attendance_models.dart';
import '../providers/attendance_provider.dart';
import '../services/qr_decoder_service.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen>
    with WidgetsBindingObserver {
  /// Controller `package:camera` — back camera, ResolutionPreset.medium
  /// (cukup untuk QR static, hemat CPU vs `high` di face).
  CameraController? _cameraController;

  /// Description back camera yang dipakai — disimpan untuk re-init di
  /// lifecycle observer + dipassing ke `QrDecoderService` per frame.
  CameraDescription? _camera;

  /// Decoder QR via ML Kit Barcode Scanning. Owner singleton scanner native.
  final QrDecoderService _qrDecoder = QrDecoderService();

  /// Flag siap render `CameraPreview` — false saat init / re-init.
  bool _isCameraReady = false;

  /// Status flash back camera. Plain `setState` (tidak pakai
  /// `ValueListenableBuilder` seperti `mobile_scanner` lama).
  bool _isTorchOn = false;

  /// Flag user menolak izin CAMERA — tampil UI fallback dengan tombol
  /// "Buka Pengaturan".
  bool _permissionDenied = false;

  /// Submit lock — prevent double-scan saat processing in-flight.
  bool _isProcessing = false;

  /// True selama ScanQrScreen sedang push child screen (`/face-verify`
  /// atau `/face-register`) dan menunggu hasil pop. Selama true,
  /// `didChangeAppLifecycleState(resumed)` SKIP auto-init kamera —
  /// karena re-init sudah jadi tanggung jawab `_processSubmit` /
  /// `_showFaceNotRegisteredDialog` setelah pop. Tanpa flag ini,
  /// resume event saat user pop dari face flow akan men-trigger init
  /// kedua paralel → race condition di RMX5000 (kamera open lalu
  /// langsung close).
  bool _isAwaitingFaceFlow = false;

  /// Serialization lock untuk camera lifecycle. Mencegah race antara
  /// `didChangeAppLifecycleState(resumed)` (yang re-init kamera saat OS
  /// kill) dan explicit `_initCamera()` setelah pop dari `/face-verify`
  /// atau `/face-register`. Tanpa lock, dua `_initCamera()` paralel
  /// akan saling overwrite `_cameraController` field — controller A
  /// orphan, controller B initialized, tapi setState/lifecycle handler
  /// dispose B saat A masih try start stream → CameraDevice OPEN lalu
  /// langsung CLOSED (lihat log RMX5000 sesi 2026-05-15).
  ///
  /// Pola: setiap entry ke `_initCamera`/`_disposeCamera` `await` future
  /// ini, lalu set future-nya ke operasi sendiri. Caller berikutnya
  /// menunggu sampai operasi selesai, baru re-evaluate kondisi (mis.
  /// kalau init kedua datang sementara init pertama sudah sukses,
  /// caller kedua bail-out tanpa duplikasi).
  Future<void>? _cameraOp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Reset submit state saat masuk scanner (preserved dari pre-fix flow).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceSubmitProvider.notifier).reset();
    });

    _initCamera();
  }

  /// Async sequence init camera + decoder dengan retry pada CameraException.
  /// Retry diperlukan karena CameraX max 1 kamera open — saat kamera face
  /// verify baru dispose tapi Camera2 HAL belum sepenuhnya release back
  /// camera, init pertama bisa fail dengan error "CameraAccessException".
  /// Retry dengan delay 200ms (max 3x) memberi HAL waktu release resource.
  ///
  /// Serialized via `_cameraOp` — kalau ada operasi pending (init/dispose),
  /// tunggu selesai dulu, baru cek apakah controller sudah live. Mencegah
  /// race dual-init dari `didChangeAppLifecycleState(resumed)` + explicit
  /// re-init setelah pop dari `/face-verify`.
  Future<void> _initCamera() async {
    // Tunggu operasi pending sebelumnya (kalau ada).
    final pending = _cameraOp;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // operasi sebelumnya error → kita tetap lanjut init.
      }
    }
    if (!mounted) return;
    // Setelah operasi sebelumnya selesai, kalau controller sudah live →
    // tidak perlu init lagi (caller kedua bail-out).
    final existing = _cameraController;
    if (existing != null && existing.value.isInitialized && _isCameraReady) {
      return;
    }

    final op = _runInitCamera();
    _cameraOp = op;
    try {
      await op;
    } finally {
      // Hanya clear kalau yang kita simpan masih operasi ini (bisa saja
      // operasi lain sudah replace di tengah jalan).
      if (identical(_cameraOp, op)) {
        _cameraOp = null;
      }
    }
  }

  /// Inner init — retry loop (3x, 200ms delay) untuk CameraException.
  Future<void> _runInitCamera() async {
    const maxRetries = 3;
    const retryDelayMs = 200;

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (!mounted) return;
      try {
        await _initCameraOnce();
        return; // sukses
      } on CameraException catch (e) {
        debugPrint(
          '[SCAN QR] Init attempt ${attempt + 1}/$maxRetries failed: '
          '${e.code} ${e.description}',
        );
        // Cleanup partial state sebelum retry — pakai inner dispose
        // (bukan `_disposeCamera()`) karena kita SUDAH di dalam lock,
        // calling `_disposeCamera()` akan deadlock pada `_cameraOp`.
        await _runDisposeCamera();
        if (attempt < maxRetries - 1) {
          await Future.delayed(const Duration(milliseconds: retryDelayMs));
        } else {
          // Last attempt failed — show error.
          if (mounted) {
            _showError('Gagal membuka kamera');
          }
        }
      } catch (e) {
        debugPrint('[SCAN QR] Init unexpected error: $e');
        if (mounted) {
          _showError('Gagal membuka kamera');
        }
        return;
      }
    }
  }

  /// Single init attempt — dipanggil dari `_initCamera` dengan retry wrapper.
  Future<void> _initCameraOnce() async {
    // 1. Runtime permission CAMERA (Android 6+).
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        setState(() => _permissionDenied = true);
      }
      return;
    }

    // 2. Cari back camera. Kalau tidak ada → fallback ke camera pertama.
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) {
        _showError('Kamera tidak tersedia');
      }
      return;
    }

    _camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // 3. Construct controller. ResolutionPreset.medium cukup untuk QR
    // (static target), hemat CPU vs `high` yang dipakai face.
    // imageFormatGroup NV21 = standar Android, didukung ML Kit.
    _cameraController = CameraController(
      _camera!,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.nv21,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) {
      await _cameraController?.dispose();
      return;
    }

    // 4. Init ML Kit barcode scanner (idempotent).
    _qrDecoder.initialize();

    // 5. Start image stream → callback `_onCameraFrame` per frame.
    await _cameraController!.startImageStream(_onCameraFrame);
    if (!mounted) {
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      return;
    }

    setState(() => _isCameraReady = true);
  }

  /// Callback per frame — decode QR via ML Kit, parse, submit.
  ///
  /// Re-entrance: `_isProcessing` flag mencegah double-fire saat ada
  /// submit in-flight. `_qrDecoder` punya guard internal sendiri
  /// (throttle 200ms + processing flag) sehingga aman dipanggil per
  /// frame tanpa CPU saturation.
  Future<void> _onCameraFrame(CameraImage image) async {
    if (_isProcessing) return;
    if (_camera == null) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    final raw = await _qrDecoder.decodeFromCameraImage(image, _camera!);
    if (raw == null) return;
    if (!mounted) return;

    // Kontrak provider preserved — parser sama, validasi JSON sama.
    final qrData =
        ref.read(attendanceSubmitProvider.notifier).parseQrCode(raw);
    if (qrData == null) {
      _showError('QR tidak valid');
      return;
    }

    // Cegah double-scan + stop stream untuk hemat CPU saat processing.
    setState(() => _isProcessing = true);
    if (_cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint('[SCAN QR] stopImageStream error (ignored): $e');
      }
    }

    // Auto-submit (preserved verbatim).
    await _processSubmit(qrData);

    // Setelah submit selesai (sukses → sudah pushReplacement, tidak lagi
    // mounted; gagal/cancel → `_processSubmit` reset `_isProcessing=false`),
    // restart image stream supaya user bisa scan ulang.
    if (mounted &&
        !_isProcessing &&
        _cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.startImageStream(_onCameraFrame);
      } catch (e) {
        debugPrint('[SCAN QR] startImageStream restart error: $e');
      }
    }
  }

  Future<FaceVerificationResult?> _pushFaceVerify(BuildContext context) {
    return context.push<FaceVerificationResult?>('/face-verify');
  }

  Future<void> _processSubmit(QrCodeData qrData) async {
    // === Pre-flight: cek face_verification_mode ===
    // Phase 2 v7 (17 Mei 2026): kalau mode 'required', mahasiswa harus:
    //   1. Sudah daftar wajah (is_face_registered = true), kalau belum → dialog redirect
    //   2. Verify wajah dulu via /face-verify, hasilnya dikirim ke server saat submit
    // Kalau mode 'optional' (legacy), submit langsung tanpa face verify.
    FaceVerificationResult? faceResult;

    try {
      final faceConfig = await ref.read(faceConfigProvider.future);

      if (faceConfig.verificationMode == FaceVerificationMode.required) {
        // Cek apakah user sudah register wajah
        final isFaceRegistered =
            ref.read(authProvider).user?.isFaceRegistered ?? false;

        if (!isFaceRegistered) {
          if (!mounted) return;
          // Dispose kamera sebelum push ke face register agar kamera
          // belakang ScanQrScreen melepas resource Camera2 HAL.
          // CameraX hanya allow 1 kamera open (Open count max=1) — tanpa
          // dispose explicit, controller jadi zombie state setelah pop.
          await _disposeCamera();
          await _showFaceNotRegisteredDialog();
          if (mounted) {
            setState(() => _isProcessing = false);
            // Re-init kamera setelah dialog selesai.
            await _initCamera();
          }
          return;
        }

        // Push face verification screen, tunggu result.
        // FIX BUG-019: dispose kamera back DULU sebelum push ke face
        // verify (yang akan claim front camera). CameraX max 1 kamera
        // open — kalau back camera tidak di-dispose explicit, sistem
        // paksa close tapi controller di sini tetap pegang state lama
        // → freeze setelah pop. Re-init setelah pop balik.
        if (!mounted) return;
        await _disposeCamera();
        if (!context.mounted) return;
        // Set flag SEBELUM push — supaya `didChangeAppLifecycleState`
        // skip auto-init saat ScanQrScreen "paused" karena push child.
        _isAwaitingFaceFlow = true;
        // ignore: use_build_context_synchronously
        final result = await _pushFaceVerify(context);
        // Clear flag SEGERA setelah pop — sebelum delay & re-init.
        _isAwaitingFaceFlow = false;

        if (!mounted) return;

        // Beri waktu Camera2 HAL release front camera resource setelah
        // face_verification_screen dispose. Tanpa delay, _initCamera bisa
        // race dengan dispose front camera → CameraAccessException
        // (CameraX max 1 open).
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        if (result == null) {
          // User cancel (intentional) — JANGAN tampilkan snackbar merah,
          // user yang cancel sendiri tidak butuh error feedback. Cukup
          // silent re-init kamera supaya user bisa scan ulang. Smooth UX
          // priority over informational notice.
          setState(() => _isProcessing = false);
          await _initCamera();
          return;
        }

        faceResult = result;
        // Sukses verify → re-init kamera kalau submit gagal nanti.
        // (Kalau submit sukses, screen pushReplacement ke result page,
        // kamera akan ke-dispose otomatis di dispose() lifecycle.)
      }
    } catch (e) {
      // Network error fetch config — fallback: lanjut submit, server akan gate kalau perlu
      debugPrint('[SCAN QR] Face config fetch error: $e');
    }

    if (!mounted) return;

    // === Submit ke server ===
    final success = await ref
        .read(attendanceSubmitProvider.notifier)
        .submitFromQr(qrData, faceResult: faceResult);

    if (!mounted) return;

    if (success) {
      // Navigate ke result screen.
      context.pushReplacement('/attendance-result');
      return;
    }

    // === Handle error — cek error_code untuk routing dialog yang sesuai ===
    final submitState = ref.read(attendanceSubmitProvider);
    final errCode = submitState.errorCode;
    final errMsg = submitState.errorMessage ?? 'Gagal submit presensi.';

    if (errCode == 'face_not_registered') {
      // Defense in depth: server reject walau pre-flight pass.
      await _showFaceNotRegisteredDialog();
    } else if (errCode == 'face_mismatch') {
      await _showFaceMismatchDialog(errMsg);
    } else {
      _showError(errMsg);
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      // Re-init kamera setelah error supaya user bisa scan ulang
      // (kalau kamera sudah di-dispose di phase verify push).
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        await _initCamera();
      }
    }
  }

  /// Dialog: wajah belum terdaftar — ajak ke face registration screen.
  ///
  /// Returns `true` kalau user pilih "Daftar Sekarang" DAN registrasi
  /// sukses (server confirm row `face_embeddings` tersimpan). Caller
  /// tanggung jawab pop ScanQrScreen + snackbar (BUG-019).
  ///
  /// Returns `false` kalau user pilih "Nanti Saja" atau register cancel/error.
  Future<bool> _showFaceNotRegisteredDialog() async {
    if (!mounted) return false;
    final shouldRegister = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            IconsaxPlusBold.user_octagon,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        title: const Text(
          'Wajah Belum Didaftarkan',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Sebelum melakukan presensi, Anda perlu mendaftarkan wajah terlebih dahulu. Proses ini hanya perlu dilakukan sekali.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          // Stack vertikal — primary action di atas (paling tebal),
          // secondary "Nanti Saja" sebagai TextButton di bawah.
          // Pattern Material 3 untuk modal action yang lebih scannable
          // dibanding side-by-side spaceBetween (yang ambigu).
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.14,
                    ),
                  ),
                  child: const Text('Daftar Sekarang'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textTertiary,
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                child: const Text('Nanti Saja'),
              ),
            ],
          ),
        ],
      ),
    );

    if (shouldRegister == true && mounted) {
      // FIX BUG-019: dispose kamera back DULU sebelum push ke
      // /face-register (yang akan claim front camera). Sama dengan
      // logic push verify — CameraX max 1 kamera open. Path ini juga
      // dipakai dari _processSubmit setelah server return error
      // `face_not_registered` (defense in depth) — di situ kamera juga
      // perlu di-dispose karena sebelumnya sempat re-init.
      await _disposeCamera();
      if (!context.mounted) return false;
      _isAwaitingFaceFlow = true;
      // ignore: use_build_context_synchronously
      final registered = await context.push<bool>('/face-register');
      _isAwaitingFaceFlow = false;
      if (!mounted) return false;

      if (registered == true) {
        // Update local auth flag — prevent dialog muncul lagi saat scan
        // ulang. Tanpa ini, `_isFaceRegistered` masih false di state local
        // walau DB sudah ada row face_embeddings (BUG-018).
        ref.read(authProvider.notifier).markFaceRegistered();
        // Invalidate face config supaya provider re-fetch dari server
        // (defensive — kalau ada admin yang ganti config bersamaan).
        ref.invalidate(faceConfigProvider);
        return true;
      }
    }
    return false;
  }

  /// Dialog: wajah tidak cocok — minta retry.
  Future<void> _showFaceMismatchDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.warningTint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            IconsaxPlusBold.shield_cross,
            color: AppColors.warning,
            size: 32,
          ),
        ),
        title: const Text(
          'Wajah Tidak Cocok',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.14,
                ),
              ),
              child: const Text('Coba Lagi'),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Toggle flash back camera. Replace `MobileScannerController.toggleTorch`
  /// dengan `CameraController.setFlashMode` (preservation 2.5, 3.12).
  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    final newState = !_isTorchOn;
    try {
      await _cameraController!.setFlashMode(
        newState ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) return;
      setState(() => _isTorchOn = newState);
    } catch (e) {
      debugPrint('[SCAN QR] Toggle torch error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Defensive (Plan B mitigasi root cause refute): handle background→
    // foreground edge case. Kalau OS kill camera saat app paused, re-init
    // saat resumed.
    //
    // PENTING: skip auto-init saat `_isAwaitingFaceFlow=true`. Itu artinya
    // user di tengah flow `/face-verify` atau `/face-register` — re-init
    // adalah tanggung jawab `_processSubmit` setelah pop, BUKAN lifecycle
    // observer. Tanpa skip, dua `_initCamera()` paralel akan race dan di
    // device RMX5000 berakhir di kamera "open lalu langsung close"
    // (lihat log sesi 2026-05-15).
    if (state == AppLifecycleState.resumed) {
      if (_isAwaitingFaceFlow) return;
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) {
        _initCamera();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Selama menunggu hasil face flow, JANGAN dispose kamera lagi —
      // sudah didispose explicit di `_processSubmit` sebelum push, dan
      // kalau kita dispose ulang di sini bisa nge-trigger setState saat
      // child route mounting. Biarkan lifecycle face screen yang manage
      // kamera-nya sendiri.
      if (_isAwaitingFaceFlow) return;
      _disposeCamera();
    }
  }

  /// Tear down camera + decoder. Dipanggil dari `dispose()` dan
  /// `didChangeAppLifecycleState(paused/inactive)`, juga sebelum push
  /// ke `/face-verify` atau `/face-register` untuk release Camera2 HAL.
  ///
  /// Serialized via `_cameraOp` — kalau ada operasi pending (init/dispose),
  /// tunggu selesai dulu. Mencegah race controller A initialized
  /// sementara controller B dispose dipanggil paralel.
  Future<void> _disposeCamera() async {
    final pending = _cameraOp;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // operasi sebelumnya error → tetap lanjut dispose.
      }
    }
    if (_cameraController == null) return;

    final op = _runDisposeCamera();
    _cameraOp = op;
    try {
      await op;
    } finally {
      if (identical(_cameraOp, op)) {
        _cameraOp = null;
      }
    }
  }

  /// Inner dispose — actual stop stream + dispose controller.
  /// JANGAN dipanggil langsung dari luar; pakai `_disposeCamera()` yang
  /// punya lock. Kecuali sudah berada di dalam lock (mis. retry inner
  /// loop di `_runInitCamera`).
  Future<void> _runDisposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraReady = false;
        _isTorchOn = false;
      });
    } else {
      _isCameraReady = false;
      _isTorchOn = false;
    }
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (e) {
        debugPrint('[SCAN QR] stopImageStream on dispose error (ignored): $e');
      }
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('[SCAN QR] CameraController dispose error (ignored): $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Defensive sequencing — stop stream + dispose camera + dispose decoder.
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          controller.stopImageStream();
        }
      } catch (e) {
        debugPrint('[SCAN QR] stopImageStream on dispose error (ignored): $e');
      }
      controller.dispose();
    }
    _qrDecoder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(attendanceSubmitProvider);
    final isLoading = submitState.status == SubmitStatus.gettingLocation ||
        submitState.status == SubmitStatus.submitting;

    if (_permissionDenied) {
      return _buildPermissionDeniedScaffold();
    }

    final cameraReady = _isCameraReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    // Fade transition antara loading scaffold ↔ camera preview supaya
    // peralihan smooth (mis. setelah pop dari face-verify cancel, kamera
    // re-init ~500ms). Tanpa AnimatedSwitcher, frame transisi terlihat
    // "blink" hitam → langsung preview.
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: cameraReady
            ? _buildCameraStack(context, submitState, isLoading)
            : _buildLoadingScaffold(),
      ),
    );
  }

  Widget _buildCameraStack(
    BuildContext context,
    AttendanceSubmitState submitState,
    bool isLoading,
  ) {
    // Key memastikan AnimatedSwitcher treat as different child saat
    // controller berubah identity (post re-init).
    return Stack(
      key: const ValueKey('camera-stack'),
      children: [
        // === Camera ===
        Positioned.fill(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),
        ),

        // === Overlay ===
        _buildScanOverlay(context),

        // === Top Bar ===
        _buildTopBar(context),

        // === Bottom Instructions ===
        _buildBottomPanel(context, submitState),

        // === Loading overlay ===
        if (isLoading) _buildLoadingOverlay(submitState),
      ],
    );
  }

  Widget _buildPermissionDeniedScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Scan QR Presensi',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.warningTint,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  IconsaxPlusBold.camera_slash,
                  color: AppColors.warning,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Izin Kamera Diperlukan',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Untuk memindai QR presensi, MyPresensi memerlukan akses ke kamera Anda. Buka pengaturan untuk mengaktifkan izin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.14,
                    ),
                  ),
                  child: const Text('Buka Pengaturan'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () async {
                    setState(() => _permissionDenied = false);
                    await _initCamera();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    // Subtle loading — minim friction. Hanya spinner kecil tanpa teks
    // bombastis "Mempersiapkan kamera..." karena window ini biasanya
    // <1 detik (transisi pop dari face flow). Teks panjang bikin user
    // mengira ada masalah; spinner mini = "lagi switching".
    //
    // Return Container (bukan Scaffold) — caller `AnimatedSwitcher`
    // sudah membungkus dalam Scaffold root.
    return Container(
      key: const ValueKey('loading-scaffold'),
      color: Colors.black,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              Material(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
              ),
              // Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Scan QR Presensi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Torch toggle — plain `setState` dari `_isTorchOn` (replace
              // `ValueListenableBuilder(_scannerController)` mobile_scanner lama).
              Material(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _toggleTorch,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: _isTorchOn ? AppColors.warning : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        final top = (constraints.maxHeight - scanAreaSize) / 2 - 40;

        return Stack(
          children: [
            // Semi-transparent overlay di seluruh layar
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.5),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                      ),
                    ),
                    // Lubang transparan di tengah
                    Positioned(
                      top: top,
                      left: (constraints.maxWidth - scanAreaSize) / 2,
                      child: Container(
                        width: scanAreaSize,
                        height: scanAreaSize,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Corner borders
            Positioned(
              top: top,
              left: (constraints.maxWidth - scanAreaSize) / 2,
              child: SizedBox(
                width: scanAreaSize,
                height: scanAreaSize,
                child: CustomPaint(
                  painter: _CornerBorderPainter(
                    color: AppColors.primary,
                    strokeWidth: 3,
                    cornerLength: 28,
                    borderRadius: 20,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomPanel(BuildContext context, AttendanceSubmitState state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_2,
                size: 32,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              const Text(
                'Arahkan kamera ke QR Code',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'QR code ditampilkan oleh dosen di layar kelas',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(AttendanceSubmitState state) {
    final isGps = state.status == SubmitStatus.gettingLocation;
    final label = isGps ? 'Mengambil lokasi GPS...' : 'Mengirim presensi...';
    final icon = isGps ? Icons.location_searching : Icons.cloud_upload;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Mohon tunggu sebentar...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter untuk sudut-sudut frame scanner
class _CornerBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double borderRadius;

  _CornerBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final l = cornerLength;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(l, 0),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(w - l, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, l),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, h - l)
        ..lineTo(0, h - r)
        ..quadraticBezierTo(0, h, r, h)
        ..lineTo(l, h),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(w - l, h)
        ..lineTo(w - r, h)
        ..quadraticBezierTo(w, h, w, h - r)
        ..lineTo(w, h - l),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
