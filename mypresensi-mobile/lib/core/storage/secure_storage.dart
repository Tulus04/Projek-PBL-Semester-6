// lib/core/storage/secure_storage.dart
// Wrapper untuk flutter_secure_storage — simpan token dan data sensitif.
//
// Identitas device (`device_id`) di-generate sekali per install, tetap
// persistent meskipun user logout (tidak ikut clearAll). Ini penting untuk
// rate limit per-device dan audit forensic — kalau user login di 2 HP berbeda,
// audit log bisa membedakan mana request datang dari device mana.

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  // Keys
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userDataKey = 'user_data';
  static const _deviceIdKey = 'device_id';

  // === Token ===
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  // Refresh token tetap disimpan via saveTokens() untuk future silent refresh.
  // Getter sengaja dihapus karena belum ada konsumer — tambahkan kembali saat
  // silent refresh flow diimplementasi (lihat roadmap pasca T1-#3).

  // === User Data ===
  static Future<void> saveUserData(String jsonString) async {
    await _storage.write(key: _userDataKey, value: jsonString);
  }

  static Future<String?> getUserData() async {
    return _storage.read(key: _userDataKey);
  }

  // === Device ID ===
  /// Ambil atau generate device_id unik untuk device ini.
  /// Disimpan permanen — TIDAK di-clear saat logout. Identitas device
  /// tetap konsisten antar login session, untuk rate limit per-device
  /// dan audit forensic.
  ///
  /// Format: 32 char hex random (cukup unique untuk single device install).
  /// Bukan UUID v4 strict — tapi entropy 128-bit sama.
  static Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate 16 byte random (128-bit entropy) → 32 hex chars
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    await _storage.write(key: _deviceIdKey, value: hex);
    return hex;
  }

  // === Clear All ===
  /// Hapus token + user data, TAPI **pertahankan** device_id.
  /// Device_id sengaja tetap untuk konsistensi rate-limit & audit antar
  /// login session di device yang sama.
  static Future<void> clearAll() async {
    // Backup device_id sebelum deleteAll
    final deviceId = await _storage.read(key: _deviceIdKey);
    await _storage.deleteAll();
    if (deviceId != null && deviceId.isNotEmpty) {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
  }

  // === Check Login Status ===
  static Future<bool> hasToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    return token != null && token.isNotEmpty;
  }
}
