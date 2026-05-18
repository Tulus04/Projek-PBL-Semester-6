// lib/features/face/data/face_models.dart
// Model data untuk fitur face recognition — embedding, request, response, verification result.
// Digunakan oleh FaceRepository dan provider.

/// Embedding wajah yang tersimpan di server
class FaceEmbedding {
  final List<double> embedding;
  final String embeddingHash;
  final String? registeredAt;

  const FaceEmbedding({
    required this.embedding,
    required this.embeddingHash,
    this.registeredAt,
  });

  factory FaceEmbedding.fromJson(Map<String, dynamic> json) {
    final rawEmbedding = json['embedding'] as List<dynamic>? ?? [];
    return FaceEmbedding(
      embedding: rawEmbedding.map((e) => (e as num).toDouble()).toList(),
      embeddingHash: json['embedding_hash'] as String? ?? '',
      registeredAt: json['registered_at'] as String?,
    );
  }
}

/// Request body untuk POST /api/mobile/face/register
class FaceRegistrationRequest {
  final List<double> embedding;

  const FaceRegistrationRequest({required this.embedding});

  Map<String, dynamic> toJson() => {'embedding': embedding};
}

/// Response dari POST /api/mobile/face/register
class FaceRegistrationResponse {
  final String message;
  final String embeddingHash;

  const FaceRegistrationResponse({
    required this.message,
    required this.embeddingHash,
  });

  factory FaceRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return FaceRegistrationResponse(
      message: json['message'] as String? ?? '',
      embeddingHash: json['embedding_hash'] as String? ?? '',
    );
  }
}

/// Response dari POST /api/mobile/face/verify — hasil verifikasi server-side.
///
/// Server membandingkan live embedding (yang dikirim mobile) dengan stored
/// embedding milik user. Mobile TIDAK pernah menerima stored embedding.
class FaceVerifyResponse {
  /// True jika similarity >= threshold (sesuai settings server).
  final bool match;

  /// Cosine similarity hasil komputasi server, clamped [0, 1].
  /// Nilai mendekati 1 = sangat mirip, mendekati 0 = berbeda.
  final double similarity;

  /// Threshold yang dipakai server saat decision (untuk diagnostic UI).
  /// Default 0.65 sesuai LFW benchmark MobileFaceNet 192-d.
  final double threshold;

  const FaceVerifyResponse({
    required this.match,
    required this.similarity,
    required this.threshold,
  });

  factory FaceVerifyResponse.fromJson(Map<String, dynamic> json) {
    final simRaw = json['similarity'];
    final thrRaw = json['threshold'];
    return FaceVerifyResponse(
      match: json['match'] as bool? ?? false,
      similarity: simRaw is num ? simRaw.toDouble() : 0.0,
      threshold: thrRaw is num ? thrRaw.toDouble() : 0.65,
    );
  }
}

/// Hasil verifikasi wajah (on-device comparison)
class FaceVerificationResult {
  final double confidence; // 0.0 - 1.0
  final bool isMatched;
  final bool isLivenessPassed;

  const FaceVerificationResult({
    required this.confidence,
    required this.isMatched,
    required this.isLivenessPassed,
  });

  /// Label status untuk display
  String get statusLabel {
    if (!isLivenessPassed) return 'Liveness gagal';
    if (!isMatched) return 'Wajah tidak cocok';
    return 'Wajah terverifikasi';
  }
}
