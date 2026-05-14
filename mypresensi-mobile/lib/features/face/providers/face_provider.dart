// lib/features/face/providers/face_provider.dart
// Riverpod providers untuk fitur face recognition (MobileFaceNet via TFLite).
//
// PERUBAHAN PENTING vs versi lama:
// 1. Embedding TIDAK lagi diambil dari ML Kit landmarks (heuristic).
//    Sekarang via `FaceEmbeddingService` (MobileFaceNet TFLite, 192-d).
// 2. Capture embedding dilakukan di pose **lookStraight** (step 1),
//    BUKAN di akhir (turnRight). Bug arsitektural lama: embedding
//    yang di-store adalah pose menoleh ke kanan, sedangkan saat verify
//    user di-instruksikan menghadap lurus → cosine similarity rendah.
// 3. Multi-frame averaging: kumpulkan 5–10 embedding di pose lurus,
//    average + L2 normalize → embedding final lebih stabil dari noise frame.

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/face_models.dart';
import '../data/face_config_models.dart';
import '../data/face_repository.dart';
import '../services/face_detection_service.dart';
import '../services/face_embedding_service.dart';
import '../../../shared/utils/error_mapper.dart';

// ============================================================
// Providers
// ============================================================

final faceRepositoryProvider = Provider<FaceRepository>((ref) {
  return FaceRepository();
});

final faceDetectionServiceProvider = Provider<FaceDetectionService>((ref) {
  final service = FaceDetectionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Service TFLite — singleton, lazy-init.
/// Service ini stateful (interpreter) jadi sengaja TIDAK auto-dispose
/// agar bisa di-reuse antara registration & verification screen.
final faceEmbeddingServiceProvider = Provider<FaceEmbeddingService>((ref) {
  final service = FaceEmbeddingService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Konfigurasi face dari server (`face_confidence_threshold` + `face_verification_mode`).
///
/// TIDAK auto-dispose — config jarang berubah, cache untuk session app.
/// Admin tweak di `/settings` web → mahasiswa baru kena value baru saat next launch.
///
/// Fallback ke [FaceConfig.fallback] (threshold 0.65, mode optional) jika network error
/// agar face flow tidak blocking.
final faceConfigProvider = FutureProvider<FaceConfig>((ref) async {
  try {
    final repo = ref.read(faceRepositoryProvider);
    return await repo.getFaceConfig();
  } catch (e) {
    debugPrint('[FACE PROVIDER] getFaceConfig failed → fallback: $e');
    return FaceConfig.fallback();
  }
});

/// Stored embedding dari server (untuk face verification).
final storedEmbeddingProvider =
    FutureProvider.autoDispose<FaceEmbedding?>((ref) async {
  try {
    final repo = ref.read(faceRepositoryProvider);
    return await repo.getStoredEmbedding();
  } catch (e) {
    debugPrint('[FACE PROVIDER] No stored embedding: $e');
    return null;
  }
});

// ============================================================
// REGISTRATION
// ============================================================

enum RegistrationStatus {
  idle,
  initializing,    // Menyiapkan kamera + load model
  detecting,       // Menunggu wajah masuk frame
  capturingPose,   // Sedang collect 5-10 embedding di pose lookStraight
  livenessCheck,   // Liveness verification (blink, turnLeft, turnRight)
  finalizing,      // Average embeddings + persiapan upload
  uploading,       // Upload ke server
  success,
  error,
}

class FaceRegistrationState {
  final RegistrationStatus status;
  final LivenessStep livenessStep;
  final int livenessStepsCompleted;
  final int embeddingsCollected; // 0..target untuk progress UI
  final String? errorMessage;
  final String? successMessage;

  const FaceRegistrationState({
    this.status = RegistrationStatus.idle,
    this.livenessStep = LivenessStep.lookStraight,
    this.livenessStepsCompleted = 0,
    this.embeddingsCollected = 0,
    this.errorMessage,
    this.successMessage,
  });

  FaceRegistrationState copyWith({
    RegistrationStatus? status,
    LivenessStep? livenessStep,
    int? livenessStepsCompleted,
    int? embeddingsCollected,
    String? errorMessage,
    String? successMessage,
  }) {
    return FaceRegistrationState(
      status: status ?? this.status,
      livenessStep: livenessStep ?? this.livenessStep,
      livenessStepsCompleted:
          livenessStepsCompleted ?? this.livenessStepsCompleted,
      embeddingsCollected: embeddingsCollected ?? this.embeddingsCollected,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  /// Label instruksi yang ditampilkan di UI.
  String get livenessInstruction {
    switch (status) {
      case RegistrationStatus.capturingPose:
        return 'Tetap hadap lurus — menyimpan data wajah ($embeddingsCollected/$_targetEmbeddings)';
      case RegistrationStatus.detecting:
        return 'Posisikan wajah di dalam oval, hadap lurus';
      case RegistrationStatus.livenessCheck:
        switch (livenessStep) {
          case LivenessStep.blinkEyes:
            return 'Kedipkan kedua mata';
          case LivenessStep.turnLeft:
            return 'Tolehkan kepala ke kiri';
          case LivenessStep.turnRight:
            return 'Tolehkan kepala ke kanan';
          default:
            return 'Verifikasi keaslian wajah...';
        }
      case RegistrationStatus.finalizing:
        return 'Memproses data wajah...';
      case RegistrationStatus.uploading:
        return 'Menyimpan ke server...';
      case RegistrationStatus.success:
        return 'Wajah berhasil didaftarkan!';
      case RegistrationStatus.error:
        return errorMessage ?? 'Terjadi kesalahan';
      default:
        return 'Menyiapkan...';
    }
  }
}

/// Jumlah embedding yang dikumpulkan di pose lookStraight sebelum
/// liveness check dimulai. Lebih banyak = lebih stabil tapi lebih lama.
const int _targetEmbeddings = 7;

final faceRegistrationProvider =
    NotifierProvider<FaceRegistrationNotifier, FaceRegistrationState>(
  FaceRegistrationNotifier.new,
);

class FaceRegistrationNotifier extends Notifier<FaceRegistrationState> {
  @override
  FaceRegistrationState build() => const FaceRegistrationState();

  // === Internal state (tidak di-expose ke UI) ===
  final List<List<double>> _capturedEmbeddings = [];
  int _noFaceFrameCount = 0;
  int _confirmFrameCount = 0;
  bool _isInCooldown = false;
  bool _isExtractingEmbedding = false; // Hindari overlap inference
  int _debugFrameCounter = 0;

  static const _noFaceThreshold = 5;
  static const _cooldownDuration = Duration(milliseconds: 500);

  /// Threshold confirm per-step:
  /// - Blink = 1 frame (aksi transien, kedipan ~200ms)
  /// - Pose = 2 frame (sustained)
  int _getConfirmThreshold(LivenessStep step) {
    return step == LivenessStep.blinkEyes ? 1 : 2;
  }

  /// Mulai proses registrasi.
  /// Caller harus pastikan kamera sudah ready & embedding service sudah init.
  void startRegistration() {
    final detector = ref.read(faceDetectionServiceProvider);
    detector.initialize();

    _capturedEmbeddings.clear();
    _noFaceFrameCount = 0;
    _confirmFrameCount = 0;
    _isInCooldown = false;
    _isExtractingEmbedding = false;
    _debugFrameCounter = 0;

    state = const FaceRegistrationState(
      status: RegistrationStatus.detecting,
      livenessStep: LivenessStep.lookStraight,
      livenessStepsCompleted: 0,
      embeddingsCollected: 0,
    );
  }

  /// Process satu frame dari camera stream.
  /// Caller mengirim CameraImage asli + CameraDescription agar
  /// preprocessing bisa convert + rotate dengan benar.
  Future<void> onFrame({
    required FaceDetectionResult result,
    required CameraImage cameraImage,
    required CameraDescription camera,
  }) async {
    // Ignore semua frame kalau sudah finalizing/uploading/success
    final s = state.status;
    if (s == RegistrationStatus.finalizing ||
        s == RegistrationStatus.uploading ||
        s == RegistrationStatus.success) {
      return;
    }

    // Cooldown antar liveness step
    if (_isInCooldown) return;

    // === Kasus 1: Wajah hilang ===
    if (!result.faceDetected) {
      _noFaceFrameCount++;
      _confirmFrameCount = 0;
      if (_noFaceFrameCount >= _noFaceThreshold &&
          state.status != RegistrationStatus.detecting) {
        state = state.copyWith(
          status: RegistrationStatus.detecting,
          errorMessage: null,
        );
      }
      return;
    }
    _noFaceFrameCount = 0;

    // === Kasus 2: Multiple faces ===
    if (result.multipleFaces) {
      _confirmFrameCount = 0;
      state = state.copyWith(
        status: RegistrationStatus.detecting,
        errorMessage: 'Harap hanya 1 wajah di depan kamera',
      );
      return;
    }

    // === Kasus 3: Wajah terlalu kecil ===
    final faceRatio = result.faceWidthRatio ?? 0;
    if (faceRatio < 0.25) {
      _confirmFrameCount = 0;
      if (state.status == RegistrationStatus.detecting ||
          state.status == RegistrationStatus.capturingPose) {
        state = state.copyWith(
          status: RegistrationStatus.detecting,
          errorMessage: 'Dekatkan wajah ke dalam oval',
        );
      }
      return;
    }

    // === FASE 1: Capture embeddings di pose lookStraight ===
    if (state.livenessStep == LivenessStep.lookStraight) {
      await _handleCapturePoseFrame(result, cameraImage, camera);
      return;
    }

    // === FASE 2: Liveness check (blink → turnLeft → turnRight) ===
    await _handleLivenessFrame(result);
  }

  /// Handle frame saat sedang capture embedding di pose lurus.
  Future<void> _handleCapturePoseFrame(
    FaceDetectionResult result,
    CameraImage cameraImage,
    CameraDescription camera,
  ) async {
    final detector = ref.read(faceDetectionServiceProvider);
    final passed = detector.checkLivenessStep(LivenessStep.lookStraight, result);

    if (!passed || result.boundingBox == null) {
      // Belum lurus / belum ada bbox — tetap di state detecting
      return;
    }

    // Set state ke capturingPose kalau masih di detecting
    if (state.status == RegistrationStatus.detecting) {
      state = state.copyWith(
        status: RegistrationStatus.capturingPose,
        errorMessage: null,
      );
    }

    // Hindari overlap inference (TFLite tidak thread-safe untuk single instance)
    if (_isExtractingEmbedding) return;
    _isExtractingEmbedding = true;

    try {
      final embeddingService = ref.read(faceEmbeddingServiceProvider);
      if (!embeddingService.isReady) {
        // Lazy init — hanya pertama kali
        await embeddingService.initialize();
      }

      final embedding = await embeddingService.extractEmbedding(
        cameraImage: cameraImage,
        boundingBox: result.boundingBox!,
        sensorOrientation: camera.sensorOrientation,
        isFrontCamera: camera.lensDirection == CameraLensDirection.front,
      );

      if (embedding == null) {
        debugPrint('[FACE REG] Inference returned null, skip frame');
        return;
      }

      _capturedEmbeddings.add(embedding);
      state = state.copyWith(embeddingsCollected: _capturedEmbeddings.length);

      _debugFrameCounter++;
      if (_debugFrameCounter % 3 == 0) {
        debugPrint(
          '[FACE REG] Captured ${_capturedEmbeddings.length}/$_targetEmbeddings '
          '(yaw=${result.headAngleY?.toStringAsFixed(1)}, '
          'ratio=${result.faceWidthRatio?.toStringAsFixed(2)})',
        );
      }

      // Sudah cukup → advance ke fase liveness
      if (_capturedEmbeddings.length >= _targetEmbeddings) {
        debugPrint('[FACE REG] ✅ Pose capture done — start liveness check');
        _activateCooldown();
        state = state.copyWith(
          status: RegistrationStatus.livenessCheck,
          livenessStep: LivenessStep.blinkEyes,
          livenessStepsCompleted: 1, // lookStraight sudah dianggap selesai
        );
      }
    } catch (e, st) {
      debugPrint('[FACE REG] Embedding extraction error: $e\n$st');
    } finally {
      _isExtractingEmbedding = false;
    }
  }

  /// Handle frame saat liveness check (blink/turnLeft/turnRight).
  /// HANYA validasi gerakan — TIDAK extract embedding (sudah selesai di fase 1).
  Future<void> _handleLivenessFrame(FaceDetectionResult result) async {
    final detector = ref.read(faceDetectionServiceProvider);
    final passed = detector.checkLivenessStep(state.livenessStep, result);

    _debugFrameCounter++;
    if (_debugFrameCounter % 5 == 0) {
      debugPrint(
        '[FACE LIVE] step=${state.livenessStep.name} '
        'yaw=${result.headAngleY?.toStringAsFixed(1)} '
        'leftEye=${result.leftEyeOpenProb?.toStringAsFixed(2)} '
        'rightEye=${result.rightEyeOpenProb?.toStringAsFixed(2)} '
        'passed=$passed confirm=$_confirmFrameCount',
      );
    }

    if (passed) {
      _confirmFrameCount++;
      if (_confirmFrameCount >= _getConfirmThreshold(state.livenessStep)) {
        debugPrint('[FACE LIVE] ✅ Step ${state.livenessStep.name} PASSED');
        _confirmFrameCount = 0;
        _advanceLivenessStep();
      }
    } else {
      _confirmFrameCount = 0;
    }
  }

  /// Pindah ke step liveness berikutnya, atau finalize kalau sudah selesai.
  void _advanceLivenessStep() {
    final nextSteps = {
      LivenessStep.blinkEyes: LivenessStep.turnLeft,
      LivenessStep.turnLeft: LivenessStep.turnRight,
      LivenessStep.turnRight: LivenessStep.completed,
    };

    final nextStep = nextSteps[state.livenessStep];

    if (nextStep == LivenessStep.completed) {
      // Semua liveness selesai → finalize embedding
      state = state.copyWith(
        status: RegistrationStatus.finalizing,
        livenessStep: LivenessStep.completed,
        livenessStepsCompleted: 4,
      );
      // uploadEmbedding() dipanggil oleh UI lewat ref.listen
    } else if (nextStep != null) {
      _activateCooldown();
      state = state.copyWith(
        livenessStep: nextStep,
        livenessStepsCompleted: state.livenessStepsCompleted + 1,
      );
    }
  }

  void _activateCooldown() {
    _isInCooldown = true;
    Future.delayed(_cooldownDuration, () {
      _isInCooldown = false;
    });
  }

  /// Average semua embedding yang dikumpulkan + L2 normalize, lalu upload.
  /// Dipanggil oleh UI saat status = `finalizing`.
  Future<bool> uploadEmbedding() async {
    if (_capturedEmbeddings.isEmpty) {
      state = state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: 'Tidak ada data wajah. Silakan ulang.',
      );
      return false;
    }

    state = state.copyWith(status: RegistrationStatus.uploading);

    try {
      final averaged =
          FaceEmbeddingService.averageEmbeddings(_capturedEmbeddings);

      debugPrint(
        '[FACE REG] Averaged ${_capturedEmbeddings.length} embeddings → '
        '${averaged.length}-d vector',
      );

      final repo = ref.read(faceRepositoryProvider);
      final response = await repo.registerFaceEmbedding(averaged);

      state = state.copyWith(
        status: RegistrationStatus.success,
        successMessage: response.message,
      );
      debugPrint('[FACE REG] Upload OK: ${response.embeddingHash}');
      return true;
    } catch (e) {
      debugPrint('[FACE REG] Upload error: $e');
      state = state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: friendlyErrorMessage(e),
      );
      return false;
    }
  }

  /// Reset state — untuk coba ulang setelah error
  void reset() {
    _capturedEmbeddings.clear();
    _noFaceFrameCount = 0;
    _confirmFrameCount = 0;
    _isInCooldown = false;
    _isExtractingEmbedding = false;
    _debugFrameCounter = 0;
    state = const FaceRegistrationState();
  }
}

// ============================================================
// VERIFICATION
// ============================================================

enum VerificationStatus {
  idle,
  initializing,
  verifying,
  matched,
  notMatched,
  error,
}

class FaceVerificationState {
  final VerificationStatus status;
  final double? confidence;
  final bool isLivenessPassed;
  final String? errorMessage;

  const FaceVerificationState({
    this.status = VerificationStatus.idle,
    this.confidence,
    this.isLivenessPassed = false,
    this.errorMessage,
  });

  FaceVerificationState copyWith({
    VerificationStatus? status,
    double? confidence,
    bool? isLivenessPassed,
    String? errorMessage,
  }) {
    return FaceVerificationState(
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      isLivenessPassed: isLivenessPassed ?? this.isLivenessPassed,
      errorMessage: errorMessage,
    );
  }
}

final faceVerificationProvider =
    NotifierProvider<FaceVerificationNotifier, FaceVerificationState>(
  FaceVerificationNotifier.new,
);

// ============================================================
// DELETION (UU PDP — hak hapus data biometrik)
// ============================================================

enum FaceDeletionStatus { idle, loading, success, error }

class FaceDeletionState {
  final FaceDeletionStatus status;
  final String? errorMessage;
  final String? successMessage;

  const FaceDeletionState({
    this.status = FaceDeletionStatus.idle,
    this.errorMessage,
    this.successMessage,
  });

  FaceDeletionState copyWith({
    FaceDeletionStatus? status,
    String? errorMessage,
    String? successMessage,
  }) {
    return FaceDeletionState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

final faceDeletionProvider =
    NotifierProvider<FaceDeletionNotifier, FaceDeletionState>(
  FaceDeletionNotifier.new,
);

class FaceDeletionNotifier extends Notifier<FaceDeletionState> {
  @override
  FaceDeletionState build() => const FaceDeletionState();

  /// Hapus data wajah user di server (DELETE /api/mobile/face/me).
  /// Caller bertanggung jawab update auth flag `markFaceUnregistered()`
  /// dan tampilkan feedback UI. Return true jika sukses.
  Future<bool> deleteMyFaceData() async {
    state = state.copyWith(status: FaceDeletionStatus.loading);
    try {
      final repo = ref.read(faceRepositoryProvider);
      await repo.deleteMyFaceData();

      // Invalidate cache embedding & config — sehingga halaman lain
      // (mis. verification screen) refetch dan tahu user belum register.
      ref.invalidate(storedEmbeddingProvider);

      state = state.copyWith(
        status: FaceDeletionStatus.success,
        successMessage: 'Data wajah berhasil dihapus.',
      );
      return true;
    } catch (e) {
      debugPrint('[FACE DELETE] Error: $e');
      state = state.copyWith(
        status: FaceDeletionStatus.error,
        errorMessage: friendlyErrorMessage(e),
      );
      return false;
    }
  }

  void reset() {
    state = const FaceDeletionState();
  }
}

class FaceVerificationNotifier extends Notifier<FaceVerificationState> {
  @override
  FaceVerificationState build() => const FaceVerificationState();

  bool _isExtracting = false;

  /// Process frame saat verify.
  /// Embedding live dibandingkan ke `storedEmbedding` via cosine similarity.
  Future<void> onFrame({
    required FaceDetectionResult result,
    required CameraImage cameraImage,
    required CameraDescription camera,
    required List<double> storedEmbedding,
    required double threshold,
  }) async {
    if (state.status == VerificationStatus.matched) return;

    if (!result.faceDetected || result.boundingBox == null) {
      state = state.copyWith(
        status: VerificationStatus.verifying,
        errorMessage: null,
      );
      return;
    }

    if (result.multipleFaces) {
      state = state.copyWith(
        status: VerificationStatus.verifying,
        errorMessage: 'Hanya 1 wajah di depan kamera',
      );
      return;
    }

    final faceRatio = result.faceWidthRatio ?? 0;
    if (faceRatio < 0.25) {
      state = state.copyWith(
        status: VerificationStatus.verifying,
        errorMessage: 'Dekatkan wajah',
      );
      return;
    }

    // Hindari overlap inference
    if (_isExtracting) return;
    _isExtracting = true;

    try {
      final embeddingService = ref.read(faceEmbeddingServiceProvider);
      if (!embeddingService.isReady) {
        await embeddingService.initialize();
      }

      final liveEmbedding = await embeddingService.extractEmbedding(
        cameraImage: cameraImage,
        boundingBox: result.boundingBox!,
        sensorOrientation: camera.sensorOrientation,
        isFrontCamera: camera.lensDirection == CameraLensDirection.front,
      );

      if (liveEmbedding == null) {
        return;
      }

      final similarity = FaceEmbeddingService.cosineSimilarity(
        liveEmbedding,
        storedEmbedding,
      );
      final clamped = similarity.clamp(0.0, 1.0);
      final isMatched = clamped >= threshold;

      state = state.copyWith(
        status: isMatched
            ? VerificationStatus.matched
            : VerificationStatus.verifying,
        confidence: clamped,
        isLivenessPassed: true,
        errorMessage: null,
      );

      if (isMatched) {
        debugPrint(
          '[FACE VERIFY] ✅ Matched! Confidence: ${(clamped * 100).toStringAsFixed(1)}% '
          '(threshold ${(threshold * 100).toStringAsFixed(0)}%)',
        );
      }
    } catch (e, st) {
      debugPrint('[FACE VERIFY] Error: $e\n$st');
    } finally {
      _isExtracting = false;
    }
  }

  void reset() {
    state = const FaceVerificationState();
  }
}
