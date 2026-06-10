// lib/core/services/fcm_service.dart
// Service FCM push notification: permission, token registration, lifecycle handler.
// Catatan keamanan:
//   - Token dikirim ke backend lewat Dio (Bearer auth otomatis via interceptor).
//   - Payload TIDAK memuat data sensitif (hanya route + type + title + body).
//   - Navigasi deep link via callback yang di-inject dari UI layer (main.dart),
//     supaya service ini tidak perlu tahu detail GoRouter/tab.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';

/// Callback navigasi — di-set dari main.dart. Menerima `route` dari payload notif.
typedef FcmNavigationCallback = void Function(String route);

/// Background message handler — WAJIB top-level + @pragma('vm:entry-point')
/// agar tidak di-strip compiler di release build. Berjalan di isolate terpisah,
/// JANGAN akses provider/UI di sini. Saat ada payload `notification`, sistem
/// Android otomatis menampilkan notif di background/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class FcmService {
  FcmService._();

  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Channel Android untuk banner foreground (FCM tidak auto-show saat foreground).
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mypresensi_default',
    'Notifikasi MyPresensi',
    description: 'Notifikasi presensi, izin, dan sesi kuliah',
    importance: Importance.high,
  );

  static const String _fallbackRoute = '/notifications';

  static FcmNavigationCallback? _onNavigate;
  static bool _handlersReady = false;

  /// Register callback navigasi (dipanggil dari main.dart setelah router siap).
  static void setNavigationCallback(FcmNavigationCallback cb) {
    _onNavigate = cb;
  }

  /// Inisialisasi penuh — dipanggil setelah login sukses.
  /// Permission → local notif channel → lifecycle handlers → register token.
  static Future<void> initialize() async {
    try {
      await _requestPermission();
      await _setupLocalNotifications();
      await _setupHandlers();

      final token = await getCurrentToken();
      if (token != null) {
        await registerTokenWithBackend(token);
      }

      // Re-register otomatis saat Firebase rotate token.
      FirebaseMessaging.instance.onTokenRefresh.listen(registerTokenWithBackend);
    } catch (e) {
      // Jangan pernah break flow login karena FCM gagal init.
      debugPrint('[FCM] initialize error: $e');
    }
  }

  /// Android 13+ runtime permission POST_NOTIFICATIONS (rule 21 — pakai permission_handler).
  static Future<void> _requestPermission() async {
    final status = await Permission.notification.request();
    debugPrint('[FCM] Notification permission: $status');
  }

  static Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        _navigate(payload);
      },
    );

    // Buat channel (idempotent).
    await _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> _setupHandlers() async {
    if (_handlersReady) return;
    _handlersReady = true;

    // Foreground — FCM tidak auto-show, jadi tampilkan banner via local notif.
    FirebaseMessaging.onMessage.listen((message) {
      final notif = message.notification;
      if (notif == null) return;
      final route = message.data['route'];

      _localNotif.show(
        notif.hashCode,
        notif.title,
        notif.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: route,
      );
    });

    // Background → user tap notif sistem → app ke foreground.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigate(message.data['route']);
    });

    // Terminated → app dibuka dari tap notif.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigate(initialMessage.data['route']);
    }
  }

  static void _navigate(String? route) {
    final target = (route == null || route.isEmpty) ? _fallbackRoute : route;
    _onNavigate?.call(target);
  }

  static Future<String?> getCurrentToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  static Future<void> registerTokenWithBackend(String token) async {
    try {
      await DioClient.instance.post(
        ApiEndpoints.profileFcmToken,
        data: {'fcm_token': token},
      );
      debugPrint('[FCM] token registered');
    } catch (e) {
      // Silent fail — polling fallback tetap jalan. Token akan re-register saat refresh.
      debugPrint('[FCM] register token failed: $e');
    }
  }

  /// Hapus token device (saat logout). Push berikutnya ke token lama akan
  /// gagal 'registration-token-not-registered' → server auto-clear dari DB.
  static Future<void> clearToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('[FCM] token deleted');
    } catch (e) {
      debugPrint('[FCM] deleteToken error: $e');
    }
  }
}
