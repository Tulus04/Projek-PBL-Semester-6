// lib/features/face/screens/face_registration_screen.dart
// Screen registrasi wajah mahasiswa — one-time setup.
// Flow: Consent UU PDP → Permission kamera → Liveness check (4 step) →
//       Capture embedding (7-frame averaging) → Upload ke server.
// Compliance: rule 04-security B.5 (consent biometrik), rule 21-android-platform
//             (runtime permission Android 6+).

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/face_provider.dart';
import '../widgets/face_camera_overlay.dart';

class FaceRegistrationScreen extends ConsumerStatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  ConsumerState<FaceRegistrationScreen> createState() =>
      _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState
    extends ConsumerState<FaceRegistrationScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    // Tunda flow registrasi sampai widget siap dirender — kalau langsung di
    // initState, dialog showDialog tidak bisa muncul karena widget tree belum
    // mount. Pakai postFrameCallback supaya context ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  /// Flow: consent UU PDP → permission kamera → init kamera.
  /// Tolak di salah satu step → pop screen kembali ke halaman sebelumnya.
  Future<void> _startFlow() async {
    if (!mounted) return;

    // 1. Consent UU PDP biometrik (rule 04-security B.5)
    final consentGiven = await _showBiometricConsentDialog();
    if (!mounted || consentGiven != true) {
      if (mounted) context.pop();
      return;
    }

    // 2. Runtime permission kamera (Android 6+)
    final permissionOk = await _requestCameraPermission();
    if (!mounted || !permissionOk) return;

    // 3. Peringatan aksesoris (kacamata/masker)
    final understood = await _showAccessoriesWarningDialog();
    if (!mounted || understood != true) {
      if (mounted) context.pop();
      return;
    }

    // 4. Init kamera + start face detection
    await _initCamera();
  }

  /// Dialog persetujuan UU PDP — biometrik = data spesifik (UU 27/2022 Pasal 4).
  /// Wording sesuai rule 04-security B.5. JANGAN ubah tanpa diskusi compliance.
  Future<bool?> _showBiometricConsentDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.face_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Persetujuan Data Biometrik',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Wajah Anda akan disimpan sebagai data biometrik untuk verifikasi presensi. '
          'Data ini hanya digunakan internal kampus dan dapat dihapus kapan saja '
          'melalui menu Profil. Lanjutkan?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Tolak',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Setuju',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dialog peringatan untuk melepas kacamata tebal, masker, atau aksesoris
  /// yang menutupi wajah sebelum mulai memindai.
  Future<bool?> _showAccessoriesWarningDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Perhatian',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Mohon lepaskan kacamata tebal, masker, atau aksesoris lain yang menutupi wajah Anda sebelum mulai memindai.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Request runtime permission kamera (Android 6+ wajib).
  /// Return true = granted, false = denied/permanentlyDenied (sudah handle UI).
  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();

    if (status.isGranted) return true;

    if (!mounted) return false;

    if (status.isPermanentlyDenied) {
      // User pernah pilih "Don't ask again" — request().request() tidak
      // akan munculkan dialog OS lagi. Harus arahkan ke Settings manual.
      await _showPermissionDeniedDialog(permanent: true);
    } else {
      // Denied biasa — tampilkan info ramah, biarkan user back.
      await _showPermissionDeniedDialog(permanent: false);
    }

    if (mounted) context.pop();
    return false;
  }

  /// Dialog ramah saat permission ditolak. permanent=true → tombol Buka
  /// Pengaturan untuk grant manual. permanent=false → cuma OK kembali.
  Future<void> _showPermissionDeniedDialog({required bool permanent}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Izin Kamera Diperlukan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          permanent
              ? 'Izin kamera ditolak permanen. Buka Pengaturan aplikasi dan '
                  'aktifkan izin kamera untuk dapat mendaftarkan wajah.'
              : 'Aplikasi membutuhkan akses kamera untuk mendaftarkan wajah '
                  'Anda. Coba lagi dan pilih "Izinkan" pada dialog izin.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kembali'),
          ),
          if (permanent)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Buka Pengaturan'),
            ),
        ],
      ),
    );
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();

      // Gunakan front camera
      final frontCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      // Resolution `high` (~720p) lebih stabil untuk feature extraction
      // MobileFaceNet vs `medium` (~480p) yang noise-prone.
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() => _isCameraInitialized = true);

      // Start face detection
      ref.read(faceRegistrationProvider.notifier).startRegistration();

      // Start image stream untuk ML Kit
      _cameraController!.startImageStream(_onCameraFrame);
    } catch (e) {
      debugPrint('[FACE REG] Camera init error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka kamera: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_cameras.isEmpty) return;

    final frontCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    final detector = ref.read(faceDetectionServiceProvider);

    detector.processFrame(image, frontCamera).then((result) {
      // result == null berarti frame di-skip (throttle / detector sibuk) —
      // JANGAN diteruskan ke provider, bukan berarti wajah hilang.
      if (!mounted || result == null) return;
      // Provider butuh CameraImage + camera untuk preprocess + TFLite inference
      ref.read(faceRegistrationProvider.notifier).onFrame(
            result: result,
            cameraImage: image,
            camera: frontCamera,
          );
    });
  }

  @override
  void dispose() {
    // Guard: stopImageStream throw kalau dipanggil saat stream sudah
    // berhenti (mis. sudah di-stop di listener finalizing). Tanpa guard
    // ini, exception bubble up → dispose abort → CameraController tidak
    // release native HAL → MobileScanner di parent screen freeze
    // (BUG-019 root cause).
    final controller = _cameraController;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream();
      }
      controller.dispose();
    }
    super.dispose();
  }

  /// Tear down camera dengan await proper sebelum pop. Dipakai di tiap
  /// path keluar (cancel button, success, consent declined) supaya
  /// CameraX max-1-open invariant terpenuhi sebelum ScanQrScreen
  /// (caller) re-init back camera.
  Future<void> _disposeAndPop([Object? result]) async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (e) {
        debugPrint('[FACE REGISTER] stopImageStream error (ignored): $e');
      }
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('[FACE REGISTER] dispose error (ignored): $e');
      }
    }
    if (mounted) {
      context.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regState = ref.watch(faceRegistrationProvider);

    // Auto-upload saat fase finalizing dimulai
    ref.listen<FaceRegistrationState>(faceRegistrationProvider, (prev, next) {
      if (prev?.status != RegistrationStatus.finalizing &&
          next.status == RegistrationStatus.finalizing) {
        final controller = _cameraController;
        if (controller != null && controller.value.isStreamingImages) {
          controller.stopImageStream();
        }
        ref.read(faceRegistrationProvider.notifier).uploadEmbedding();
      }
    });

    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // Kalkulasi Progress (0.0 - 1.0)
    double progress = 0.0;
    String? progressLabel;
    
    if (regState.status == RegistrationStatus.capturingPose) {
      progress = (regState.embeddingsCollected / 7.0) * 0.4;
      progressLabel = 'Sampel ${regState.embeddingsCollected} dari 7';
    } else if (regState.status == RegistrationStatus.livenessCheck) {
      // livenessStepsCompleted start from 1 (after lookStraight)
      int currentLiveness = (regState.livenessStepsCompleted - 1).clamp(0, 3);
      progress = 0.4 + (currentLiveness / 3.0) * 0.6;
      progressLabel = 'Verifikasi ${currentLiveness + 1} dari 3';
    } else if (regState.status == RegistrationStatus.finalizing ||
               regState.status == RegistrationStatus.uploading ||
               regState.status == RegistrationStatus.success) {
      progress = 1.0;
    }

    Color progressColor = AppColors.primary;
    if (regState.status == RegistrationStatus.success) {
      progressColor = AppColors.success;
    } else if (regState.status == RegistrationStatus.error) {
      progressColor = AppColors.danger;
    } else if (regState.errorMessage != null && regState.status != RegistrationStatus.uploading) {
      progressColor = AppColors.warning;
    }

    // Tentukan Hint Utama
    String hintLabel = 'Posisikan Wajah';
    if (regState.status == RegistrationStatus.success) {
      hintLabel = 'Berhasil';
    } else if (regState.status == RegistrationStatus.error) {
      hintLabel = 'Gagal';
    } else if (regState.status == RegistrationStatus.uploading || regState.status == RegistrationStatus.finalizing) {
      hintLabel = 'Memproses';
    } else if (regState.status == RegistrationStatus.livenessCheck) {
      hintLabel = 'Ikuti Instruksi';
    } else if (regState.status == RegistrationStatus.capturingPose) {
      hintLabel = 'Tahan Posisi';
    }

    // Widget kamera
    final cameraWidget = ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 0,
            height: _cameraController!.value.previewSize?.width ?? 0,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FaceCameraOverlay(
            title: 'Daftar Wajah',
            onBack: () => _disposeAndPop(),
            cameraPreview: cameraWidget,
            progress: progress,
            progressColor: progressColor,
            progressLabel: progressLabel,
            hintLabel: hintLabel,
            hintSub: regState.livenessInstruction,
          ),
          
          // Overlay Error / Success Buttons
          if (regState.status == RegistrationStatus.success || regState.status == RegistrationStatus.error || regState.status == RegistrationStatus.uploading)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 40,
              left: 24,
              right: 24,
              child: _buildResultPanel(regState),
            ),
        ],
      ),
    );
  }

  Widget _buildResultPanel(FaceRegistrationState regState) {
    if (regState.status == RegistrationStatus.uploading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    
    if (regState.status == RegistrationStatus.success) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _disposeAndPop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Selesai',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    
    if (regState.status == RegistrationStatus.error) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            ref.read(faceRegistrationProvider.notifier).reset();
            ref.read(faceRegistrationProvider.notifier).startRegistration();
            _cameraController?.startImageStream(_onCameraFrame);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Coba Lagi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
