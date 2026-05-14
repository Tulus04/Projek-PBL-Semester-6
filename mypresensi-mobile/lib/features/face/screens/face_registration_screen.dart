// lib/features/face/screens/face_registration_screen.dart
// Screen registrasi wajah mahasiswa — one-time setup.
// Flow: Kamera → Liveness check (4 step) → Capture embedding → Upload ke server.
// Menggunakan camera package untuk preview + ML Kit untuk deteksi.

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/face_provider.dart';

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
    _initCamera();
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
      if (!mounted) return;
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
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regState = ref.watch(faceRegistrationProvider);

    // Auto-upload saat fase finalizing dimulai (semua liveness selesai)
    ref.listen<FaceRegistrationState>(faceRegistrationProvider, (prev, next) {
      if (prev?.status != RegistrationStatus.finalizing &&
          next.status == RegistrationStatus.finalizing) {
        // Stop camera stream dulu (tidak butuh frame lagi)
        _cameraController?.stopImageStream();
        // Trigger upload — provider yang average + L2 normalize + POST
        ref.read(faceRegistrationProvider.notifier).uploadEmbedding();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Registrasi Wajah'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
            child: _buildCameraPreview(regState),
          ),

          // Bottom panel
          Expanded(
            flex: 1,
            child: _buildBottomPanel(context, regState),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(FaceRegistrationState regState) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Menyiapkan kamera...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera feed
        ClipRect(
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
        ),

        // Oval guide overlay
        _buildOvalOverlay(regState),

        // Instruksi di atas
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: _buildInstructionBanner(regState),
        ),
      ],
    );
  }

  Widget _buildOvalOverlay(FaceRegistrationState regState) {
    Color borderColor;
    switch (regState.status) {
      case RegistrationStatus.success:
        borderColor = AppColors.success;
        break;
      case RegistrationStatus.livenessCheck:
        borderColor = AppColors.primary;
        break;
      case RegistrationStatus.error:
        borderColor = AppColors.danger;
        break;
      default:
        borderColor = Colors.white54;
    }

    return Container(
      width: 250,
      height: 330,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(125),
      ),
    );
  }

  Widget _buildInstructionBanner(FaceRegistrationState regState) {
    String text;
    Color bgColor;

    // Pakai instruksi terpusat dari state — sudah handle semua case.
    text = regState.livenessInstruction;
    switch (regState.status) {
      case RegistrationStatus.detecting:
        bgColor = regState.errorMessage != null
            ? AppColors.warning.withAlpha(200)
            : Colors.black54;
        break;
      case RegistrationStatus.capturingPose:
        bgColor = AppColors.success.withAlpha(200);
        break;
      case RegistrationStatus.livenessCheck:
        bgColor = AppColors.primary.withAlpha(200);
        break;
      case RegistrationStatus.finalizing:
      case RegistrationStatus.uploading:
        bgColor = AppColors.warning.withAlpha(200);
        break;
      case RegistrationStatus.success:
        bgColor = AppColors.success.withAlpha(200);
        break;
      case RegistrationStatus.error:
        bgColor = AppColors.danger.withAlpha(200);
        break;
      default:
        bgColor = Colors.black54;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: AnimatedContainer(
        key: ValueKey<String>(text),
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, FaceRegistrationState regState) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.black,
      child: Column(
        children: [
          // Liveness progress indicator
          if (regState.status == RegistrationStatus.livenessCheck ||
              regState.status == RegistrationStatus.detecting)
            _buildLivenessProgress(regState),

          const Spacer(),

          // Bottom buttons
          if (regState.status == RegistrationStatus.success)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pop(true),
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
            ),

          if (regState.status == RegistrationStatus.error)
            SizedBox(
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
            ),

          if (regState.status == RegistrationStatus.uploading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildLivenessProgress(FaceRegistrationState regState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isCompleted = index < regState.livenessStepsCompleted;
        final isCurrent = index == regState.livenessStepsCompleted;

        return Container(
          width: 60,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.success
                : isCurrent
                    ? AppColors.primary
                    : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
