// lib/shared/utils/error_mapper.dart
// Helper konversi exception → pesan error Bahasa Indonesia ramah user.
// Dipakai di provider catch block agar tidak expose DioException atau stack trace ke UI.
//
// Pola pakai:
//   } catch (e) {
//     state = state.copyWith(errorMessage: friendlyErrorMessage(e));
//   }
//
// Repository tetap pakai _handleDioError() sendiri (sudah throw String Indonesia).
// Helper ini jaring untuk SISA exception (FormatException, TimeoutException,
// LateInitializationError, dll) yang lolos dari repository.

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

/// Konversi exception apapun menjadi pesan Bahasa Indonesia yang aman ditampilkan ke user.
///
/// Aturan resolusi (urut):
/// 1. `String` (sudah dari repository `_handleDioError`) → return as-is.
/// 2. `DioException` → parse `response.data['error']` atau fallback per status.
/// 3. `TimeoutException` / `SocketException` → pesan network.
/// 4. `FormatException` → "Format data tidak valid".
/// 5. Generic `Exception` → strip prefix "Exception: " agar tidak teknis.
/// 6. Lainnya → pesan umum.
String friendlyErrorMessage(Object error) {
  // 1. Sudah string (dari repository) — biasanya sudah pesan Indonesia
  if (error is String) {
    return error.isNotEmpty ? error : 'Terjadi kesalahan tidak diketahui.';
  }

  // 2. Dio exception (jaring kalau ada repository yang lupa wrap)
  if (error is DioException) {
    return _mapDioException(error);
  }

  // 3. Network-level exception
  if (error is TimeoutException) {
    return 'Permintaan timeout. Periksa koneksi internet Anda.';
  }
  if (error is SocketException) {
    return 'Tidak dapat terhubung ke server. Pastikan jaringan tersedia.';
  }
  if (error is HttpException) {
    return 'Gangguan pada koneksi jaringan. Coba lagi.';
  }

  // 4. Parse / format error
  if (error is FormatException) {
    return 'Format data tidak valid. Coba muat ulang halaman.';
  }

  // 5. Generic Exception — strip prefix teknis
  if (error is Exception) {
    final raw = error.toString();
    // Pattern "Exception: <pesan>" → ambil pesan saja
    final match = RegExp(r'^Exception:\s*(.+)$').firstMatch(raw);
    if (match != null) {
      final msg = match.group(1)?.trim() ?? '';
      if (msg.isNotEmpty) return msg;
    }
    // Pattern "_Exception<x>: <pesan>" → fallback umum
    return 'Terjadi kesalahan. Coba lagi nanti.';
  }

  // 6. Apapun selainnya (Error / type lain) — pesan umum
  return 'Terjadi kesalahan tidak diketahui. Coba lagi nanti.';
}

/// Mapping DioException → pesan Bahasa Indonesia.
/// Dipakai sebagai fallback jika repository tidak sempat handle.
String _mapDioException(DioException e) {
  // Coba parse error dari server response
  if (e.response?.data is Map<String, dynamic>) {
    final data = e.response!.data as Map<String, dynamic>;
    final msg = data['error'] as String?;
    if (msg != null && msg.isNotEmpty) return msg;
  }

  // Fallback per status code
  switch (e.response?.statusCode) {
    case 400:
      return 'Data yang dikirim tidak valid.';
    case 401:
      return 'Sesi berakhir. Silakan login ulang.';
    case 403:
      return 'Akses ditolak.';
    case 404:
      return 'Data tidak ditemukan.';
    case 409:
      return 'Data sudah ada. Operasi tidak bisa dilakukan dua kali.';
    case 429:
      return 'Terlalu banyak permintaan. Tunggu beberapa saat.';
    case 500:
    case 502:
    case 503:
      return 'Server sedang bermasalah. Coba lagi nanti.';
  }

  // Network error (no response)
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Koneksi timeout. Periksa jaringan Anda.';
    case DioExceptionType.connectionError:
      return 'Tidak dapat terhubung ke server. Pastikan jaringan tersedia.';
    case DioExceptionType.cancel:
      return 'Permintaan dibatalkan.';
    case DioExceptionType.badCertificate:
      return 'Sertifikat keamanan tidak valid.';
    default:
      return 'Terjadi kesalahan jaringan. Coba lagi.';
  }
}
