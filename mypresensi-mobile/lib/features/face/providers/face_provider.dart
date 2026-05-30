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

import '../data/face_config_models.dart';
import '../data/face_repository.dart';
import '../services/face_detection_service.dart';
import '../services/face_embedding_service.dart';
import '../services/liveness_hold_tracker.dart';
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
  ///
  /// SAFETY NET: kalau sudah lewat fase capture (livenessStep != lookStraight)
  /// dan belum sampai finalize, **PRIORITASKAN instruksi step liveness** —
  /// jangan tampilkan "Posisikan wajah" lagi meski status sempat `detecting`
  /// karena ML Kit miss face beberapa frame. User tidak boleh dibikin bingung
  /// soal step yang sebenarnya. Pesan glitch dipindah ke `livenessHint`.
  String get livenessInstruction {
    final inLivenessPhase = livenessStep != LivenessStep.lookStraight &&
        livenessStep != LivenessStep.completed;
    final isTransientStatus = status == RegistrationStatus.detecting ||
        status == RegistrationStatus.livenessCheck;

    if (inLivenessPhase && isTransientStatus) {
      switch (livenessStep) {
        case LivenessStep.blinkEyes:
          return 'Kedipkan kedua mata';
        case LivenessStep.turnLeft:
          return 'Miringkan sedikit kepala ke kiri';
        case LivenessStep.turnRight:
          return 'Miringkan sedikit kepala ke kanan';
        default:
          break;
      }
    }

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
            return 'Miringkan sedikit kepala ke kiri';
          case LivenessStep.turnRight:
            return 'Miringkan sedikit kepala ke kanan';
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

  /// Hint kecil di bawah instruksi utama — untuk glitch sementara
  /// (wajah hilang frame, terlalu kecil) tanpa ganti instruksi step utama.
  /// Null = tidak tampilkan.
  String? get livenessHint {
    final inLivenessPhase = livenessStep != LivenessStep.lookStraight &&
        livenessStep != LivenessStep.completed;
    if (!inLivenessPhase) return null;
    if (errorMessage == null || errorMessage!.isEmpty) return null;
    // Hanya tampilkan untuk error transien — bukan error final state.
    if (status == RegistrationStatus.error) return null;
    return errorMessage;
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
  // Akumulasi bukti hold pose liveness di-delegate ke `LivenessHoldTracker`
  // (pure, testable). Caller tanggung-jawab panggil `_holdTracker.reset()`
  // saat memulai step baru, kehilangan wajah, multiple faces, wajah terlalu
  // kecil, atau saat advance ke step berikutnya.
  final LivenessHoldTracker _holdTracker = LivenessHoldTracker();
  bool _isInCooldown = false;
  bool _isExtractingEmbedding = false; // Hindari overlap inference
  int _debugFrameCounter = 0;

  static const _noFaceThreshold = 5;
  static const _cooldownDuration = Duration(milliseconds: 500);

  /// Mulai proses registrasi.
  /// Caller harus pastikan kamera sudah ready & embedding service sudah init.
  void startRegistration() {
    final detector = ref.read(faceDetectionServiceProvider);
    detector.initialize();

    _capturedEmbeddings.clear();
    _noFaceFrameCount = 0;
    _holdTracker.reset();
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
      if (_noFaceFrameCount >= _noFaceThreshold) {
        // BUG-013 Iterasi 3 (RMX5000): reset hold window dipindah KE DALAM
        // guard threshold ini supaya tracker hanya di-reset kalau wajah
        // benar-benar hilang persistent (>=5 frame consecutive). Sebelumnya
        // reset terjadi di SETIAP frame transien, override toleransi internal
        // tracker (`_maxFailStreakAllowed=5`) dan menyebabkan `passedCount`
        // oscillate (1→3→2→1→7) di logcat user saat noleh ~40-45° (samping
        // wajah bikin ML Kit miss-detect 1-2 frame). Dengan guard ini, jitter
        // transien biarkan tracker pakai toleransi internalnya; baru kalau
        // wajah persistent hilang, reset eksternal eksekusi.
        _holdTracker.reset();
        // PENTING: kalau sudah di fase liveness (blink/turnLeft/turnRight),
        // JANGAN regress status ke detecting — itu bikin UI menampilkan
        // "Posisikan wajah, hadap lurus" padahal user diminta noleh.
        // Cukup set errorMessage sebagai hint kecil — UI tetap tampilkan
        // instruksi step yang benar (lihat livenessInstruction safety net).
        final inLivenessPhase =
            state.livenessStep != LivenessStep.lookStraight &&
            state.livenessStep != LivenessStep.completed;
        if (inLivenessPhase) {
          if (state.errorMessage == null) {
            state = state.copyWith(
              errorMessage: 'Wajah keluar dari frame',
            );
          }
        } else if (state.status != RegistrationStatus.detecting) {
          state = state.copyWith(
            status: RegistrationStatus.detecting,
            errorMessage: null,
          );
        }
      }
      return;
    }
    _noFaceFrameCount = 0;
    // Wajah kembali — clear hint kalau ada.
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }

    // === Kasus 2: Multiple faces ===
    if (result.multipleFaces) {
      // Reset hold window.
      _holdTracker.reset();
      final inLivenessPhase =
          state.livenessStep != LivenessStep.lookStraight &&
          state.livenessStep != LivenessStep.completed;
      if (inLivenessPhase) {
        // Jangan regress status di fase liveness — cukup set hint.
        if (state.errorMessage != 'Harap hanya 1 wajah di depan kamera') {
          state = state.copyWith(
            errorMessage: 'Harap hanya 1 wajah di depan kamera',
          );
        }
      } else {
        state = state.copyWith(
          status: RegistrationStatus.detecting,
          errorMessage: 'Harap hanya 1 wajah di depan kamera',
        );
      }
      return;
    }

    // === Kasus 3: Wajah terlalu kecil ===
    final faceRatio = result.faceWidthRatio ?? 0;
    if (faceRatio < 0.25) {
      // CATATAN: untuk turnLeft/turnRight, samping wajah memang membuat ratio
      // turun. Threshold 0.25 sangat kecil, tapi pose samping ekstrem (yaw
      // 36-45°) di Realme RMX5000 kadang trigger transien karena perspektif
      // wajah dari samping. BUG-013 Iterasi 3: di fase liveness, JANGAN reset
      // tracker — toleransi internal tracker (`_maxFailStreakAllowed=5`)
      // sudah handle jitter transien per-frame. Reset eksternal di sini
      // override toleransi itu dan bikin `passedCount` oscillate aneh saat
      // user sudah stabil noleh. Reset hanya di fase capture lookStraight
      // (di mana user diminta hadap lurus, jadi ratio<0.25 berarti memang
      // jauh dari oval, bukan glitch noleh).
      final inLivenessPhase =
          state.livenessStep != LivenessStep.lookStraight &&
          state.livenessStep != LivenessStep.completed;
      if (!inLivenessPhase) {
        _holdTracker.reset();
      }
      if (inLivenessPhase) {
        if (state.errorMessage != 'Dekatkan wajah ke dalam oval') {
          state = state.copyWith(
            errorMessage: 'Dekatkan wajah ke dalam oval',
          );
        }
      } else if (state.status == RegistrationStatus.detecting ||
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
  ///
  /// Akumulasi bukti hold di-delegate ke `LivenessHoldTracker` (pure, testable).
  /// Behavior runtime di Task 1 identik dengan logic LAMA continuity wall-clock
  /// (lihat catatan di `liveness_hold_tracker.dart`). Fix algoritma hybrid baru
  /// dilakukan di Task 3.
  Future<void> _handleLivenessFrame(FaceDetectionResult result) async {
    final detector = ref.read(faceDetectionServiceProvider);
    final passed = detector.checkLivenessStep(state.livenessStep, result);
    final now = DateTime.now().millisecondsSinceEpoch;

    final tick = _holdTracker.tick(
      passed: passed,
      step: state.livenessStep,
      nowMs: now,
    );

    _debugFrameCounter++;
    if (_debugFrameCounter % 5 == 0) {
      debugPrint(
        '[FACE LIVE] step=${state.livenessStep.name} '
        'yaw=${result.headAngleY?.toStringAsFixed(1)} '
        'leftEye=${result.leftEyeOpenProb?.toStringAsFixed(2)} '
        'rightEye=${result.rightEyeOpenProb?.toStringAsFixed(2)} '
        'passed=$passed holdMs=${tick.holdMs} '
        'passedCount=${tick.passedFrameCount} failStreak=${tick.failStreak}',
      );
    }

    if (tick.stepCompleted) {
      debugPrint('[FACE LIVE] ✅ Step ${state.livenessStep.name} PASSED '
          '(passedCount=${tick.passedFrameCount} held ${tick.holdMs}ms)');
      _holdTracker.reset();
      _advanceLivenessStep();
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
    _holdTracker.reset();
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

      // Invalidate cache config — mobile akan refetch saat masuk face flow lagi
      // (mis. user mau register ulang). Tidak perlu invalidate stored embedding
      // karena sekarang verification server-side, mobile tidak cache embedding.
      ref.invalidate(faceConfigProvider);

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

  /// Throttle POST verify ke server. Frame rate kamera 5-7 fps di RMX5000
  /// = 5-7 POST/s tanpa throttle, langsung kena rate limit server (429).
  /// 1500ms cooldown = ≤1 POST/1.5s = ~40 POST/menit, di bawah default
  /// rate limit server. Cukup untuk dapat 5-10 sample konsisten dalam
  /// 15 detik timeout window untuk decide match.
  static const _verifyThrottleMs = 1500;
  int? _lastVerifyAtMs;

  /// Process frame saat verify.
  /// Live embedding di-extract di mobile (TFLite), kirim ke server,
  /// server compare dengan stored embedding milik user.
  /// Mobile TIDAK pernah menerima stored embedding (server-side comparison
  /// sesuai rule 04-security-and-privacy Section B.2).
  Future<void> onFrame({
    required FaceDetectionResult result,
    required CameraImage cameraImage,
    required CameraDescription camera,
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

    // Hindari overlap inference + overlap network call
    if (_isExtracting) return;

    // Throttle POST ke server. Frame rate 5-7 fps di entry-level device
    // tanpa throttle = 429 rate limit. Skip frame kalau jarak < 1500ms
    // dari POST terakhir (state tetap jalan di frame berikutnya).
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastVerifyAtMs != null &&
        nowMs - _lastVerifyAtMs! < _verifyThrottleMs) {
      return;
    }
    _lastVerifyAtMs = nowMs;

    _isExtracting = true;

    try {
      final embeddingService = ref.read(faceEmbeddingServiceProvider);
      if (!embeddingService.isReady) {
        await embeddingService.initialize();
      }

      // 1. Extract live embedding dari frame kamera (TFLite, on-device)
      final liveEmbedding = await embeddingService.extractEmbedding(
        cameraImage: cameraImage,
        boundingBox: result.boundingBox!,
        sensorOrientation: camera.sensorOrientation,
        isFrontCamera: camera.lensDirection == CameraLensDirection.front,
      );

      if (liveEmbedding == null) {
        return;
      }

      // 2. Kirim ke server untuk comparison vs stored embedding
      final repo = ref.read(faceRepositoryProvider);
      final response = await repo.verifyEmbedding(liveEmbedding);

      state = state.copyWith(
        status: response.match
            ? VerificationStatus.matched
            : VerificationStatus.verifying,
        confidence: response.similarity,
        isLivenessPassed: true,
        errorMessage: null,
      );

      if (response.match) {
        debugPrint(
          '[FACE VERIFY] ✅ Matched! similarity=${(response.similarity * 100).toStringAsFixed(1)}% '
          '(threshold ${(response.threshold * 100).toStringAsFixed(0)}%)',
        );
      }
    } catch (e, st) {
      debugPrint('[FACE VERIFY] Error: $e\n$st');
      // Network/server error — log saja, jangan flip state ke error.
      // Frame berikutnya akan retry otomatis. Kalau persistent, timeout
      // 15s di screen yang akan handle ke pop(null).
    } finally {
      _isExtracting = false;
    }
  }

  void reset() {
    state = const FaceVerificationState();
    _lastVerifyAtMs = null;
  }
}
