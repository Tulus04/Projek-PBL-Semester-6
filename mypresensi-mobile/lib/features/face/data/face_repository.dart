// lib/features/face/data/face_repository.dart
// Repository untuk fitur face recognition — API calls ke endpoints face.
// Pattern: UI → Provider → Repository → Dio → API.

import 'package:flutter/foundation.dart';
import 'face_models.dart';
import 'face_config_models.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';

class FaceRepository {
  /// GET /api/mobile/settings/face-config — Ambil threshold + mode dari server.
  /// Caller WAJIB pakai try-catch dan fallback ke [FaceConfig.fallback] jika error,
  /// agar face flow tetap jalan saat network down.
  Future<FaceConfig> getFaceConfig() async {
    try {
      final dio = DioClient.instance;
      final response = await dio.get(ApiEndpoints.faceConfig);
      final config = FaceConfig.fromJson(response.data as Map<String, dynamic>);
      debugPrint(
        '[FACE REPO] Fetched config: threshold=${config.confidenceThreshold} '
        'mode=${config.verificationMode.name} source=${config.source}',
      );
      return config;
    } catch (e) {
      debugPrint('[FACE REPO] getFaceConfig error: $e — pakai fallback');
      rethrow;
    }
  }

  /// POST /api/mobile/face/register — Upload face embedding
  Future<FaceRegistrationResponse> registerFaceEmbedding(
    List<double> embedding,
  ) async {
    try {
      final dio = DioClient.instance;
      final response = await dio.post(
        '/api/mobile/face/register',
        data: FaceRegistrationRequest(embedding: embedding).toJson(),
      );

      return FaceRegistrationResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[FACE REPO] Register error: $e');

      // Parse error message dari server
      final errorMsg = _extractErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// GET /api/mobile/face/embedding — Download stored embedding
  Future<FaceEmbedding> getStoredEmbedding() async {
    try {
      final dio = DioClient.instance;
      final response = await dio.get('/api/mobile/face/embedding');

      return FaceEmbedding.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[FACE REPO] Get embedding error: $e');

      final errorMsg = _extractErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// DELETE /api/mobile/face/me — Hapus data biometrik milik sendiri.
  /// Implementasi UU PDP Pasal 5-15 (hak hapus data pribadi).
  /// Server hard-delete row di `face_embeddings` + set
  /// `profiles.is_face_registered=false`.
  Future<void> deleteMyFaceData() async {
    try {
      final dio = DioClient.instance;
      await dio.delete(ApiEndpoints.faceMine);
      debugPrint('[FACE REPO] Face data deleted');
    } catch (e) {
      debugPrint('[FACE REPO] Delete error: $e');
      final errorMsg = _extractErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Extract error message dari Dio exception
  String _extractErrorMessage(dynamic error) {
    try {
      if (error.toString().contains('DioException')) {
        final response = (error as dynamic).response;
        if (response != null && response.data != null) {
          final data = response.data;
          if (data is Map<String, dynamic> && data.containsKey('error')) {
            return data['error'] as String;
          }
        }
      }
    } catch (_) {
      // Fallback
    }
    return 'Terjadi kesalahan. Coba lagi.';
  }
}
