// lib/features/attendance/data/attendance_repository.dart
// Repository layer untuk fitur presensi — handle API call ke server.
// Semua API call di-wrap try-catch, throw pesan user-friendly Bahasa Indonesia.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'attendance_models.dart';

class AttendanceRepository {
  Dio get _dio => DioClient.instance;

  /// Ambil daftar sesi aktif dari semua MK yang di-enroll mahasiswa
  Future<List<ActiveSession>> getActiveSessions() async {
    try {
      final response = await _dio.get(ApiEndpoints.activeSessions);
      final data = response.data;

      final sessionsJson = data['sessions'] as List<dynamic>? ?? [];
      final sessions = sessionsJson
          .map((json) => ActiveSession.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[ATTENDANCE] Fetched ${sessions.length} active sessions');
      return sessions;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Ambil daftar sesi yang eligible untuk diajukan izin/sakit oleh mahasiswa.
  ///
  /// Endpoint return dua group:
  /// - `active_sessions`: sesi yang sedang berlangsung (mahasiswa belum hadir
  ///   dan belum punya leave_request pending/approved).
  /// - `recent_sessions`: sesi yang sudah lewat (≤ 7 hari terakhir) tapi belum
  ///   di-handle (belum hadir, belum ada leave_request pending/approved).
  ///
  /// Backend sudah filter — UI tidak perlu re-filter. Dipakai oleh wizard
  /// "Ajukan Izin" step 1 (Pilih Sesi).
  Future<EligibleSessionsResponse> getEligibleSessionsForLeave() async {
    try {
      final response = await _dio.get(ApiEndpoints.sessionsEligibleForLeave);
      final result = EligibleSessionsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      debugPrint(
        '[ATTENDANCE] Fetched eligible sessions for leave: '
        '${result.activeSessions.length} active, '
        '${result.recentSessions.length} recent',
      );
      return result;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Submit presensi ke server
  /// Return [AttendanceSubmitResponse] jika berhasil, throw String jika gagal
  Future<AttendanceSubmitResponse> submitAttendance(
    AttendanceSubmitRequest request,
  ) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.submitAttendance,
        data: request.toJson(),
      );

      final result = AttendanceSubmitResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      debugPrint(
        '[ATTENDANCE] Submit berhasil: ${result.status}, jarak: ${result.distanceMeters}m',
      );
      return result;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio error → throw pesan user-friendly Bahasa Indonesia.
  /// Jika server response body punya `error_code`, throw [AttendanceSubmitException]
  /// dengan field tersebut. Caller bisa cek `e.errorCode` untuk routing UI khusus
  /// (mis. `face_not_registered` → dialog redirect ke /face-register).
  Object _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      final statusCode = e.response?.statusCode;

      if (data is Map<String, dynamic>) {
        final serverError = data['error'] as String?;
        final errorCode = data['error_code'] as String?;

        // Server kirim error_code → throw structured exception
        if (errorCode != null && errorCode.isNotEmpty) {
          return AttendanceSubmitException(
            serverError ?? 'Terjadi kesalahan.',
            errorCode: errorCode,
            statusCode: statusCode,
          );
        }

        if (serverError != null && serverError.isNotEmpty) {
          return serverError;
        }
      }
      switch (statusCode) {
        case 400:
          return 'Data tidak valid. Pastikan QR code benar.';
        case 401:
          return 'Sesi login habis. Silakan login ulang.';
        case 403:
          return 'Anda tidak memiliki akses.';
        case 404:
          return 'Sesi tidak ditemukan.';
        case 409:
          return 'Anda sudah melakukan presensi untuk sesi ini.';
        case 429:
          return 'Terlalu banyak percobaan. Tunggu beberapa saat.';
        case 500:
          return 'Server sedang bermasalah. Coba lagi nanti.';
        default:
          return 'Terjadi kesalahan. ($statusCode)';
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Koneksi timeout. Periksa jaringan Anda.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak dapat terhubung ke server.';
    }

    return 'Terjadi kesalahan yang tidak diketahui.';
  }
}
