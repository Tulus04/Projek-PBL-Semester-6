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

/// Interceptor untuk handle error global — terutama 401 auto-logout & token refresh
class _ErrorInterceptor extends Interceptor {
  static Future<void>? _refreshTokenFuture;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    switch (err.response?.statusCode) {
      case 401:
        final requestOptions = err.requestOptions;
        final isLoginRequest = requestOptions.path.contains('/auth/login');
        final isRefreshRequest = requestOptions.path.contains('/auth/refresh');

        if (!isLoginRequest && !isRefreshRequest) {
          debugPrint('[AUTH] Token expired (401) on: ${requestOptions.path}');
          try {
            // Gunakan future caching untuk mencegah request refresh ganda secara paralel
            _refreshTokenFuture ??= _performTokenRefresh();
            
            await _refreshTokenFuture;
            _refreshTokenFuture = null; // reset setelah selesai

            // Ambil token baru dan retry request asli
            final newAccessToken = await SecureStorage.getAccessToken();
            if (newAccessToken != null && newAccessToken.isNotEmpty) {
              requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              
              final options = Options(
                method: requestOptions.method,
                headers: requestOptions.headers,
              );
              
              final cloneReq = await DioClient.instance.request(
                requestOptions.path,
                options: options,
                data: requestOptions.data,
                queryParameters: requestOptions.queryParameters,
              );
              
              return handler.resolve(cloneReq);
            }
          } catch (refreshErr) {
            _refreshTokenFuture = null;
            debugPrint('[AUTH] Token refresh failed: $refreshErr — triggering logout');
            if (DioClient._logoutCallback != null) {
              await DioClient._logoutCallback!();
            }
          }
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

  Future<void> _performTokenRefresh() async {
    final refreshToken = await SecureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('No refresh token stored');
    }

    debugPrint('[AUTH] Performing token refresh...');
    final refreshDio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
    ));

    final response = await refreshDio.post(
      '/api/mobile/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

    final data = response.data;
    final newAccessToken = data['access_token'] as String;
    final newRefreshToken = data['refresh_token'] as String;

    await SecureStorage.saveTokens(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );
    debugPrint('[AUTH] Token refreshed successfully!');
  }
}
