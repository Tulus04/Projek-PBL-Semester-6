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

  /// Verifikasi QR Gate secara real-time
  /// Return qr_token jika sukses, throw exception jika gagal.
  Future<String> verifyQr(QrCodeData qrData) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.verifyQr,
        data: {
          'session_id': qrData.sessionId,
          'session_code': qrData.sessionCode,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final qrToken = data['qr_token'] as String;
      
      debugPrint('[ATTENDANCE] QR verified, token: $qrToken');
      return qrToken;
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
            serverError ?? 'Terjadi kesalahan',
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
          return 'QR tidak valid';
        case 401:
          return 'Sesi berakhir, login ulang';
        case 403:
          return 'Akses ditolak';
        case 404:
          return 'Sesi tidak ditemukan';
        case 409:
          return 'Anda sudah presensi di sesi ini';
        case 429:
          return 'Terlalu banyak percobaan';
        case 500:
          return 'Server bermasalah';
        default:
          return 'Gagal presensi';
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Koneksi timeout';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak ada koneksi internet';
    }

    return 'Terjadi kesalahan';
  }
}
