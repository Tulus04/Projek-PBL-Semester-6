// lib/features/home/data/activity_repository.dart
// Repository fetch Activity Feed dari endpoint /api/mobile/activity/recent.
// Pesan error mengikuti pola repository lain (Bahasa Indonesia ramah, parse
// e.response.data.error dari server kalau ada).

import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'activity_models.dart';

class ActivityRepository {
  Dio get _dio => DioClient.instance;

  /// Fetch [limit] activity terakhir dari server (default 5).
  /// Server gabungkan attendance + leave_requests, sort by tanggal DESC.
  Future<List<ActivityItem>> getRecentActivities({int limit = 5}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.activityRecent,
        queryParameters: {'limit': limit},
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['activities'] as List<dynamic>?) ?? const <dynamic>[];
      return list
          .map((raw) => ActivityItem.fromJson(raw as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final msg = e.response!.data['error'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    switch (e.response?.statusCode) {
      case 401:
        return 'Sesi berakhir, login ulang';
      case 500:
        return 'Server bermasalah';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak ada koneksi internet';
    }
    return 'Gagal memuat aktivitas';
  }
}
