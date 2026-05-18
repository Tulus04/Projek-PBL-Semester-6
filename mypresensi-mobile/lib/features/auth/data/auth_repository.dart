// lib/features/auth/data/auth_repository.dart
// Repository layer untuk autentikasi — handle API call login/logout.
// Semua API call di-wrap try-catch, throw pesan user-friendly Bahasa Indonesia.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_model.dart';

/// Custom exception untuk kasus force change password
class ForceChangePasswordException implements Exception {
  final String message;
  const ForceChangePasswordException(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  // PENTING: Gunakan getter, BUKAN field.
  // Setelah logout, DioClient.reset() menutup instance lama.
  // Jika pakai field, referensi ke instance lama tetap tersimpan → request gagal.
  Dio get _dio => DioClient.instance;

  /// Login mahasiswa — return UserModel jika berhasil.
  /// Throws [ForceChangePasswordException] jika harus ganti password dulu.
  /// Throws [String] untuk error lainnya.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data;

      // Simpan token ke secure storage (selalu — bahkan jika must_change_password)
      await SecureStorage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      // Simpan email login terakhir untuk auto-fill di login screen next time.
      // BUKAN password — password TIDAK PERNAH disimpan (rule 04-security A).
      await SecureStorage.saveLastLoginEmail(email);

      // Parse dan simpan user data
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await SecureStorage.saveUserData(user.toJsonString());

      debugPrint('[AUTH] Login berhasil: ${user.fullName} (${user.nimNip})');

      // Cek apakah user harus ganti password dulu
      final mustChange = data['must_change_password'] as bool? ?? false;
      if (mustChange) {
        debugPrint('[AUTH] User harus ganti password terlebih dahulu');
        throw const ForceChangePasswordException(
          'Anda harus mengubah password terlebih dahulu sebelum menggunakan aplikasi.',
        );
      }

      return user;
    } on ForceChangePasswordException {
      rethrow; // Jangan tangkap oleh catch di bawah
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Ganti password — dipanggil dari ChangePasswordScreen.
  /// Setelah Supabase Auth update password, server auto-signin dan return
  /// access_token + refresh_token baru. Mobile WAJIB update token sebelum
  /// request berikutnya (token lama otomatis revoke oleh Supabase saat password
  /// change → 401 di endpoint mana saja, termasuk /profile saat masuk Beranda).
  ///
  /// Return true jika berhasil. Token baru otomatis disimpan ke SecureStorage.
  Future<bool> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.changePassword,
        data: {
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final success = data['success'] as bool? ?? false;
      if (!success) return false;

      // Update token baru kalau server kasih (auto-signin sukses).
      // Kalau null (signInError di server), client tetap return true tapi
      // request berikutnya akan dapat 401 → auto-logout fallback.
      final tokens = data['tokens'] as Map<String, dynamic>?;
      if (tokens != null) {
        await SecureStorage.saveTokens(
          accessToken: tokens['access_token'] as String,
          refreshToken: tokens['refresh_token'] as String,
        );
        debugPrint('[AUTH] Password berhasil diubah + token baru disimpan');
      } else {
        debugPrint('[AUTH] Password berhasil diubah tapi auto-signin gagal — fallback logout');
      }
      return success;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Ambil profil user dari API (dengan token)
  Future<UserModel> getProfile() async {
    try {
      final response = await _dio.get(ApiEndpoints.profile);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Ambil user dari local storage (tanpa API call — instant)
  Future<UserModel?> getSavedUser() async {
    try {
      final jsonString = await SecureStorage.getUserData();
      if (jsonString == null) return null;
      return UserModel.fromJsonString(jsonString);
    } catch (e) {
      debugPrint('[AUTH] Error reading saved user: $e');
      return null;
    }
  }

  /// Cek apakah token sudah tersimpan
  Future<bool> isLoggedIn() async {
    return SecureStorage.hasToken();
  }

  /// Logout — hapus semua data lokal dan reset Dio client
  Future<void> logout() async {
    await SecureStorage.clearAll();
    DioClient.reset();
    debugPrint('[AUTH] Logout — semua data lokal dihapus');
  }

  /// Handle Dio error → throw pesan user-friendly Bahasa Indonesia
  String _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        // Server mengirim pesan error spesifik
        final serverError = data['error'] as String?;
        if (serverError != null && serverError.isNotEmpty) {
          return serverError;
        }
      }
      // Fallback berdasarkan HTTP status code
      switch (e.response?.statusCode) {
        case 400:
          return 'Data yang dikirim tidak valid.';
        case 401:
          return 'Email atau password salah.';
        case 403:
          return 'Akses ditolak.';
        case 404:
          return 'Profil tidak ditemukan.';
        case 429:
          return 'Terlalu banyak percobaan. Tunggu beberapa saat.';
        case 500:
          return 'Server sedang bermasalah. Coba lagi nanti.';
        default:
          return 'Terjadi kesalahan. (${e.response?.statusCode})';
      }
    }

    // Network error
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Koneksi timeout. Periksa jaringan Anda.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak dapat terhubung ke server. Pastikan server web sudah berjalan dan Anda terhubung ke jaringan yang sama.';
    }

    return 'Terjadi kesalahan yang tidak diketahui.';
  }
}
