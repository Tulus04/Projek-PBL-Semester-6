// lib/features/notifications/providers/notification_provider.dart
// Riverpod providers untuk notifikasi.
// Auto-dispose — data refresh setiap kali tab dibuka.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';

// Repository provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// Notification data provider — auto-dispose, refresh-able
final notificationProvider =
    FutureProvider.autoDispose<NotificationResponse>((ref) async {
  final repo = ref.read(notificationRepositoryProvider);
  return repo.getNotifications();
});
