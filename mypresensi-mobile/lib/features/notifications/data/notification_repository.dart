// lib/features/notifications/data/notification_repository.dart
// Repository untuk notifikasi — API call ke server.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'notification_models.dart';

class NotificationRepository {
  Dio get _dio => DioClient.instance;

  /// Ambil daftar notifikasi.
  /// [limit] default 50, max 100.
  Future<NotificationResponse> getNotifications({int limit = 50}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.notifications,
        queryParameters: {'limit': limit},
      );

      final result = NotificationResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      debugPrint(
        '[NOTIF] Fetched ${result.notifications.length} items, '
        'unread: ${result.unreadCount}',
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
      return 'Koneksi timeout. Periksa jaringan Anda.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak dapat terhubung ke server.';
    }
    return 'Gagal memuat notifikasi.';
  }
}
