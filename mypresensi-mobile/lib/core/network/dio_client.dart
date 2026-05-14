// lib/core/network/dio_client.dart
// HTTP client global dengan interceptor: auto-auth, 401 logout, error log.
// Singleton pattern — reset saat logout.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';

/// Callback untuk trigger logout dari interceptor (injected dari UI layer)
typedef LogoutCallback = Future<void> Function();

class DioClient {
  static Dio? _instance;
  static LogoutCallback? _logoutCallback;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  /// Register callback logout — dipanggil dari main.dart setelah ProviderScope siap
  static void setLogoutCallback(LogoutCallback callback) {
    _logoutCallback = callback;
  }

  /// Reset client (dipanggil saat logout)
  static void reset() {
    _instance?.close();
    _instance = null;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Device ID interceptor — auto-attach X-Device-Id header (semua request)
    dio.interceptors.add(_DeviceIdInterceptor());

    // Auth interceptor — auto-attach Bearer token
    dio.interceptors.add(_AuthInterceptor());

    // Error interceptor — handle 401, 429, 500
    dio.interceptors.add(_ErrorInterceptor());

    // Log interceptor (debug only)
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
        error: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ));
    }

    debugPrint('[DIO] Client created — baseUrl: ${AppConfig.baseUrl}');
    return dio;
  }
}

/// Interceptor untuk attach `X-Device-Id` ke SEMUA request (termasuk login).
/// Server pakai header ini untuk:
/// 1. Rate limit per-device (composite key: userId:deviceId)
/// 2. Audit forensic — track device asal request
class _DeviceIdInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final deviceId = await SecureStorage.getOrCreateDeviceId();
    options.headers['X-Device-Id'] = deviceId;
    return handler.next(options);
  }
}

/// Interceptor untuk otomatis menambahkan Bearer token ke setiap request
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth untuk login endpoint
    if (options.path.contains('/auth/login')) {
      return handler.next(options);
    }

    final token = await SecureStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }
}

/// Interceptor untuk handle error global — terutama 401 auto-logout
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.response?.statusCode) {
      case 401:
        // Token expired — trigger auto-logout jika bukan dari login endpoint
        final isLoginRequest =
            err.requestOptions.path.contains('/auth/login');
        if (!isLoginRequest && DioClient._logoutCallback != null) {
          debugPrint('[AUTH] Token expired — triggering auto-logout');
          DioClient._logoutCallback!();
        }
        break;
      case 429:
        debugPrint('[RATE LIMIT] Terlalu banyak permintaan');
        break;
      case 500:
        debugPrint('[SERVER] Internal server error');
        break;
    }

    return handler.next(err);
  }
}
