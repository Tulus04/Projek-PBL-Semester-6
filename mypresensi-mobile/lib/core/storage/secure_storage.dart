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
  // Last login email — persist lintas logout untuk auto-fill di login screen.
  // Email = Tier 2 PII, OK disimpan secure storage (bukan plaintext shared_preferences).
  // BUKAN password — password TIDAK PERNAH disimpan (rule 04-security A).
  static const _lastLoginEmailKey = 'last_login_email';

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

  // === Last Login Email ===
  /// Simpan email terakhir login untuk auto-fill di login screen.
  /// Persist lintas logout (sengaja — UX nyaman di HP single-user).
  static Future<void> saveLastLoginEmail(String email) async {
    await _storage.write(key: _lastLoginEmailKey, value: email);
  }

  /// Ambil email terakhir login. Null kalau belum pernah atau di-clear manual.
  static Future<String?> getLastLoginEmail() async {
    return _storage.read(key: _lastLoginEmailKey);
  }

  /// Hapus email auto-fill (dipanggil dari Settings kalau user mau "lupakan saya").
  static Future<void> clearLastLoginEmail() async {
    await _storage.delete(key: _lastLoginEmailKey);
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
  /// Hapus token + user data, TAPI **pertahankan** device_id + last_login_email.
  /// - device_id: konsistensi rate-limit & audit antar login session.
  /// - last_login_email: UX auto-fill di login screen (persist lintas logout).
  ///   User bisa hapus manual via clearLastLoginEmail() atau "lupakan saya" UI.
  static Future<void> clearAll() async {
    // Backup field yang sengaja persist
    final deviceId = await _storage.read(key: _deviceIdKey);
    final lastEmail = await _storage.read(key: _lastLoginEmailKey);
    await _storage.deleteAll();
    if (deviceId != null && deviceId.isNotEmpty) {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    if (lastEmail != null && lastEmail.isNotEmpty) {
      await _storage.write(key: _lastLoginEmailKey, value: lastEmail);
    }
  }

  // === Check Login Status ===
  static Future<bool> hasToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    return token != null && token.isNotEmpty;
  }
}
