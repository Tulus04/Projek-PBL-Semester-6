// lib/core/config/app_config.dart
// Konfigurasi global aplikasi MyPresensi Mobile.
// Base URL diatur via --dart-define atau auto-detect emulator/physical device
// menggunakan device_info_plus untuk deteksi yang akurat.

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'MyPresensi';
  static const String appVersion = '1.0.0';
  static const String orgName = 'TRPL · Politani Samarinda';

  // IP LAN laptop — ganti sesuai jaringan lokal kamu.
  // Cek IP saat ini dengan: ipconfig (Windows) atau ifconfig (Mac/Linux).
  // Wi-Fi adapter biasanya 192.168.x.x atau 10.x.x.x (tergantung router).
  static const String _lanIp = '192.168.1.18';

  /// Cache emulator status agar tidak perlu check berulang
  static bool? _isEmulatorCached;

  /// Inisialisasi config — panggil sekali di main() sebelum runApp
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _isEmulatorCached = !androidInfo.isPhysicalDevice;

      if (kDebugMode) {
        print('═══════════════════════════════════════');
        print('📱 Device: ${androidInfo.model}');
        print('🏭 Brand: ${androidInfo.brand}');
        print('🤖 Physical device: ${androidInfo.isPhysicalDevice}');
        print('🌐 Base URL: $baseUrl');
        print('═══════════════════════════════════════');
      }
    }
  }

  /// Base URL untuk API.
  /// - Override via: --dart-define=API_BASE_URL=http://x.x.x.x:3000
  /// - Emulator Android: 10.0.2.2 (localhost alias bawaan emulator)
  /// - Physical device: IP LAN laptop (_lanIp)
  static String get baseUrl {
    // Priority 1: Environment variable override
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Priority 2: Auto-detect based on device type
    if (Platform.isAndroid) {
      final isEmulator = _isEmulatorCached ?? false;
      return isEmulator
          ? 'http://10.0.2.2:3000'
          : 'http://$_lanIp:3000';
    }

    // Fallback: desktop/iOS development
    return 'http://localhost:3000';
  }

  /// Apakah running di emulator
  static bool get isEmulator => _isEmulatorCached ?? false;

  static const String apiPrefix = '/api/mobile';

  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
}
