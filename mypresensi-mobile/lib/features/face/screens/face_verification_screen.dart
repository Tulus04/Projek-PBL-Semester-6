// lib/features/face/screens/face_verification_screen.dart
// Screen verifikasi wajah saat submit presensi.
// Flow: Kamera → Extract live embedding (TFLite) → POST ke server → Server compare → Result.
// Auto-close setelah match atau timeout 15 detik.
//
// SECURITY: Comparison server-side (POST /api/mobile/face/verify) sesuai rule
// 04-security-and-privacy Section B.2. Mobile TIDAK menerima stored embedding.
// Status registrasi user di-cek via auth profile flag `is_face_registered`.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/face_config_models.dart';
import '../data/face_models.dart';
import '../providers/face_provider.dart';
import '../widgets/face_camera_overlay.dart';

class FaceVerificationScreen extends ConsumerStatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  ConsumerState<FaceVerificationScreen> createState() =>
      _FaceVerificationScreenState();
}

class _FaceVerificationScreenState
    extends ConsumerState<FaceVerificationScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  List<CameraDescription> _cameras = [];
  Timer? _timeoutTimer;
  int _remainingSeconds = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      final authState = ref.read(authProvider);
      final isFaceRegistered = authState.user?.isFaceRegistered ?? false;

      if (!isFaceRegistered) {
        if (mounted) {
          await _disposeAndPop();
        }
        return;
      }

      ref.read(faceConfigProvider);

      final permissionStatus = await Permission.camera.request();
      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                permissionStatus.isPermanentlyDenied
                    ? 'Izin kamera ditolak. Buka Pengaturan untuk mengaktifkan.'
                    : 'Izin kamera diperlukan untuk verifikasi wajah.',
              ),
              backgroundColor: AppColors.danger,
              action: permissionStatus.isPermanentlyDenied
                  ? SnackBarAction(
                      label: 'Pengaturan',
                      textColor: Colors.white,
                      onPressed: openAppSettings,
                    )
                  : null,
            ),
          );
          context.pop(null);
        }
        return;
      }

      // 3. Peringatan aksesoris (kacamata/masker)
      final understood = await _showAccessoriesWarningDialog();
      if (!mounted || understood != true) {
        if (mounted) context.pop();
        return;
      }

      _cameras = await availableCameras();
      final frontCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() => _isCameraInitialized = true);

      final service = ref.read(faceDetectionServiceProvider);
      service.initialize();
      ref.read(faceVerificationProvider.notifier).reset();

      _cameraController!.startImageStream(_onCameraFrame);

      _startTimeout();
    } catch (e) {
      debugPrint('[FACE VERIFY] Init error: $e');
      if (mounted) {
        await _disposeAndPop();
      }
    }
  }

  void _startTimeout() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _remainingSeconds--);

      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wajah gagal dideteksi, waktu habis.'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _disposeAndPop();
      }
    });
  }

  void _onCameraFrame(CameraImage image) {
    if (_cameras.isEmpty) return;

    final frontCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    final detector = ref.read(faceDetectionServiceProvider);

    detector.processFrame(image, frontCamera).then((result) {
      if (!mounted) return;

      ref.read(faceVerificationProvider.notifier).onFrame(
            result: result,
            cameraImage: image,
            camera: frontCamera,
          );
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    final controller = _cameraController;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream();
      }
      controller.dispose();
    }
    super.dispose();
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

  Future<void> _disposeAndPop([Object? result]) async {
    _timeoutTimer?.cancel();
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (e) {
        debugPrint('[FACE VERIFY] stopImageStream error (ignored): $e');
      }
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('[FACE VERIFY] dispose error (ignored): $e');
      }
    }
    if (mounted) {
      context.pop(result);
    }
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Presensi?'),
        content: const Text('Apakah Anda yakin ingin membatalkan proses presensi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verifyState = ref.watch(faceVerificationProvider);

    ref.listen<FaceVerificationState>(faceVerificationProvider, (prev, next) {
      if (prev?.status != VerificationStatus.matched &&
          next.status == VerificationStatus.matched) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            final result = FaceVerificationResult(
              confidence: next.confidence ?? 0.0,
              isMatched: true,
              isLivenessPassed: next.isLivenessPassed,
            );
            _disposeAndPop(result);
          }
        });
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

    double progress = 0.0;
    Color progressColor = AppColors.primary;
    String hintLabel = 'Posisikan wajah di dalam oval';
    
    if (verifyState.status == VerificationStatus.matched) {
      progress = 1.0;
      progressColor = AppColors.success;
      hintLabel = 'Wajah Cocok!';
    } else if (verifyState.errorMessage != null) {
      hintLabel = verifyState.errorMessage!;
      progressColor = AppColors.warning;
    } else if (verifyState.isProcessing) {
      hintLabel = 'Mencocokkan Wajah...';
      progressColor = AppColors.primary;
    }

    final confidencePercent = verifyState.confidence != null
        ? (verifyState.confidence! * 100).toStringAsFixed(0)
        : '--';

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await _showExitConfirmation(context);
        if (confirm == true && context.mounted) {
          _disposeAndPop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            FaceCameraOverlay(
              title: 'Verifikasi Wajah',
              onBack: () async {
                final confirm = await _showExitConfirmation(context);
                if (confirm == true && context.mounted) {
                  _disposeAndPop();
                }
              },
            cameraPreview: cameraWidget,
            progress: progress,
            progressColor: progressColor,
            isVerifying: true,
            isProcessing: verifyState.isProcessing,
            hintLabel: hintLabel,
            hintSub: verifyState.status == VerificationStatus.matched 
                ? 'Kemiripan: $confidencePercent% — Menyimpan presensi...'
                : (verifyState.confidence != null ? 'Kemiripan saat ini: $confidencePercent%' : 'Posisikan wajah di dalam oval'),
            trailingAppBar: _buildSkipButtonIfOptional(),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: 1.0 - (_remainingSeconds / 15.0),
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 2,
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildSkipButtonIfOptional() {
    final configAsync = ref.watch(faceConfigProvider);
    return configAsync.when(
      data: (config) {
        if (config.verificationMode != FaceVerificationMode.optional) {
          return const SizedBox.shrink();
        }
        return TextButton(
          onPressed: () => _disposeAndPop(),
          child: const Text(
            'Lewati',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
