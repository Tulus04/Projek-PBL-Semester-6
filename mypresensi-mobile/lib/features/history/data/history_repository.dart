// lib/features/history/data/history_repository.dart
// Repository untuk fitur riwayat kehadiran — API call ke server.
// Mendukung filter per course_id (opsional).

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'history_models.dart';

class HistoryRepository {
  Dio get _dio => DioClient.instance;

  /// Ambil riwayat kehadiran mahasiswa.
  /// [courseId] opsional — filter berdasarkan mata kuliah.
  Future<HistoryResponse> getHistory({String? courseId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (courseId != null && courseId.isNotEmpty) {
        queryParams['course_id'] = courseId;
      }

      final response = await _dio.get(
        ApiEndpoints.attendanceHistory,
        queryParameters: queryParams,
      );

      final result = HistoryResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      debugPrint(
        '[HISTORY] Fetched ${result.history.length} records, '
        'kehadiran: ${result.summary.percentage}%',
      );
      return result;
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
    return 'Gagal memuat riwayat';
  }
}
