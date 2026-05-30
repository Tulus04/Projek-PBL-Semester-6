// lib/features/ai/data/ai_chat_repository.dart
// Repository AI Assistant — kirim pertanyaan mahasiswa ke endpoint mobile AI.
// SECURITY: token Bearer otomatis dari DioClient; jangan log isi pesan user.

import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

class AiChatRepository {
  Dio get _dio => DioClient.instance;

  Future<String> sendMessage(String message) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.aiChat,
        data: {'message': message},
      );

      final data = response.data as Map<String, dynamic>;
      return data['reply'] as String? ?? 'Maaf, asisten belum menemukan jawaban.';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final msg = (e.response!.data as Map<String, dynamic>)['error'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Koneksi timeout';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak ada koneksi internet';
    }
    return 'AI sedang tidak tersedia';
  }
}
