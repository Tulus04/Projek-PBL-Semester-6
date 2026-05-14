// lib/features/notifications/data/notification_models.dart
// Model data untuk notifikasi in-app.
// Mapping dari response GET /api/mobile/notifications.

/// Satu item notifikasi
class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'info', 'warning', 'success', 'error'
  final String? href;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.href,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
      href: json['href'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  /// Waktu relatif sederhana: "Baru saja", "5 menit lalu", "2 jam lalu", dsb.
  String get timeAgo {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);

      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';

      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d/$m/${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }
}

/// Response lengkap dari API notifications
class NotificationResponse {
  final List<AppNotification> notifications;
  final int unreadCount;

  const NotificationResponse({
    required this.notifications,
    required this.unreadCount,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    final list = json['notifications'] as List<dynamic>? ?? [];
    return NotificationResponse(
      notifications: list
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
