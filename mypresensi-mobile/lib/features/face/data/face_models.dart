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
