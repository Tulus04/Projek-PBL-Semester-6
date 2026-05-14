// lib/features/face/data/face_config_models.dart
// Model untuk response GET /api/mobile/settings/face-config.

/// Mode verifikasi wajah saat presensi.
enum FaceVerificationMode {
  /// Verifikasi wajah opsional — mahasiswa bisa skip.
  optional,

  /// Verifikasi wajah wajib sebelum submit presensi.
  required,
}

class FaceConfig {
  /// Cosine similarity minimum untuk match wajah (0.0 - 1.0).
  /// Default 0.65 sesuai LFW benchmark MobileFaceNet 192-d.
  final double confidenceThreshold;

  /// Mode verifikasi wajah saat presensi.
  final FaceVerificationMode verificationMode;

  /// Sumber data: 'database' (dari tabel settings) atau 'fallback' (default).
  /// Berguna untuk debug — kalau 'fallback' berarti DB error atau setting belum di-set.
  final String source;

  const FaceConfig({
    required this.confidenceThreshold,
    required this.verificationMode,
    required this.source,
  });

  /// Default values — sinkron dengan FaceEmbeddingService.defaultThreshold.
  /// Pakai saat network error / repository gagal fetch.
  factory FaceConfig.fallback() {
    return const FaceConfig(
      confidenceThreshold: 0.65,
      verificationMode: FaceVerificationMode.optional,
      source: 'local_fallback',
    );
  }

  factory FaceConfig.fromJson(Map<String, dynamic> json) {
    final modeRaw = json['verification_mode'] as String?;
    FaceVerificationMode mode = FaceVerificationMode.optional;
    if (modeRaw == 'required') mode = FaceVerificationMode.required;

    final thresholdRaw = json['confidence_threshold'];
    double threshold = 0.65;
    if (thresholdRaw is num) {
      final parsed = thresholdRaw.toDouble();
      if (parsed >= 0 && parsed <= 1) threshold = parsed;
    }

    return FaceConfig(
      confidenceThreshold: threshold,
      verificationMode: mode,
      source: json['source'] as String? ?? 'unknown',
    );
  }
}
