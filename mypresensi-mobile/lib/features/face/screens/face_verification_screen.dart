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
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/face_models.dart';
import '../providers/face_provider.dart';

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
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // 1. Gate: pastikan user sudah register wajah.
      // Cek dari auth profile (flag `is_face_registered`) — TIDAK fetch
      // embedding karena sekarang server-side comparison.
      final authState = ref.read(authProvider);
      final isFaceRegistered = authState.user?.isFaceRegistered ?? false;

      if (!isFaceRegistered) {
        if (mounted) {
          // User belum register → kembali ke caller dengan null
          context.pop(null);
        }
        return;
      }

      // 2. Trigger fetch face config in parallel (cached, non-blocking).
      // Sekarang config hanya untuk display info (threshold) — server yang
      // putuskan match/no-match berdasarkan settings yang sama.
      ref.read(faceConfigProvider);

      // 3. Initialize camera
      _cameras = await availableCameras();
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

      // 4. Initialize face detection service + reset verification state
      final service = ref.read(faceDetectionServiceProvider);
      service.initialize();
      ref.read(faceVerificationProvider.notifier).reset();

      // 5. Start camera stream
      _cameraController!.startImageStream(_onCameraFrame);

      // 6. Start timeout timer
      _startTimeout();
    } catch (e) {
      debugPrint('[FACE VERIFY] Init error: $e');
      if (mounted) {
        context.pop(null);
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
        // Timeout — return null (gagal verify)
        context.pop(null);
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

      // Provider akan extract embedding via TFLite, lalu POST ke server.
      // Server compare dengan stored embedding milik user (tidak pernah
      // ke client) dan return match/similarity/threshold.
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
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verifyState = ref.watch(faceVerificationProvider);

    // Auto-pop saat matched
    ref.listen<FaceVerificationState>(faceVerificationProvider, (prev, next) {
      if (prev?.status != VerificationStatus.matched &&
          next.status == VerificationStatus.matched) {
        _timeoutTimer?.cancel();
        _cameraController?.stopImageStream();

        // Capture navigator before async gap
        final navigator = GoRouter.of(context);
        final result = FaceVerificationResult(
          confidence: next.confidence ?? 0.0,
          isMatched: true,
          isLivenessPassed: next.isLivenessPassed,
        );

        // Delay sedikit untuk feedback visual
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            navigator.pop(result);
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Verifikasi Wajah'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(null),
        ),
        actions: [
          // Countdown timer
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _remainingSeconds <= 5
                      ? AppColors.danger.withAlpha(200)
                      : Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_remainingSeconds}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
            child: _buildCameraPreview(verifyState),
          ),

          // Bottom info
          Expanded(
            flex: 1,
            child: _buildBottomPanel(verifyState),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(FaceVerificationState verifyState) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Menyiapkan kamera...',
              style: TextStyle(color: Colors.white70),
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

        // Oval guide
        Container(
          width: 250,
          height: 330,
          decoration: BoxDecoration(
            border: Border.all(
              color: verifyState.status == VerificationStatus.matched
                  ? AppColors.success
                  : Colors.white54,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(125),
          ),
        ),

        // Match indicator
        if (verifyState.status == VerificationStatus.matched)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Wajah Terverifikasi!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // Instruksi
        if (verifyState.status == VerificationStatus.verifying)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Hadapkan wajah ke kamera',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomPanel(FaceVerificationState verifyState) {
    final confidencePercent = verifyState.confidence != null
        ? (verifyState.confidence! * 100).toStringAsFixed(0)
        : '--';

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Confidence meter
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Kemiripan: ',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Text(
                '$confidencePercent%',
                style: TextStyle(
                  color: verifyState.status == VerificationStatus.matched
                      ? AppColors.success
                      : Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verifyState.status == VerificationStatus.matched
                ? 'Wajah cocok — melanjutkan presensi...'
                : 'Arahkan wajah ke kamera untuk verifikasi',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),

          const SizedBox(height: 16),

          // Skip button (untuk mode optional)
          TextButton(
            onPressed: () => context.pop(null),
            child: const Text(
              'Lewati Verifikasi',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
