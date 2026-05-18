// lib/features/leave_requests/data/leave_repository.dart
// Repository untuk pengajuan izin/sakit — wrap API call POST submit & GET my.
// Pesan error di-translate ke Bahasa Indonesia mengikuti pola repository lain.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'leave_models.dart';

class LeaveRepository {
  Dio get _dio => DioClient.instance;

  /// Submit pengajuan izin/sakit ke server.
  /// Throws String berisi pesan Bahasa Indonesia jika gagal.
  Future<SubmitLeaveResponse> submit(SubmitLeaveRequest request) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.leaveRequestSubmit,
        data: request.toJson(),
      );
      final result = SubmitLeaveResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      debugPrint('[LEAVE] Submit OK: ${result.id} status=${result.status.name}');
      return result;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload bukti foto ke server. Server validasi mime + size + magic bytes,
  /// place ke bucket `leave-evidence` lalu return path.
  ///
  /// Path nanti dipasang di [SubmitLeaveRequest.evidencePath] saat submit.
  /// Throws String berisi pesan Bahasa Indonesia jika gagal.
  Future<UploadEvidenceResponse> uploadEvidence(File file) async {
    try {
      // Tentukan content type dari ekstensi (image_picker biasanya kasih JPEG)
      final lower = file.path.toLowerCase();
      String contentType;
      if (lower.endsWith('.png')) {
        contentType = 'image/png';
      } else if (lower.endsWith('.webp')) {
        contentType = 'image/webp';
      } else {
        contentType = 'image/jpeg';
      }

      final multipartFile = await MultipartFile.fromFile(
        file.path,
        contentType: DioMediaType.parse(contentType),
      );
      final formData = FormData.fromMap({'file': multipartFile});

      final response = await _dio.post(
        ApiEndpoints.leaveRequestUpload,
        data: formData,
        options: Options(
          headers: {
            // Dio akan auto-set boundary; cukup pastikan header tidak override
            // Content-Type dari FormData.
          },
        ),
      );

      final result = UploadEvidenceResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      debugPrint('[LEAVE] Upload OK: ${result.path}');
      return result;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Ambil daftar pengajuan milik mahasiswa yang login.
  /// [statusFilter] opsional: 'pending' | 'approved' | 'rejected'.
  Future<MyLeaveRequestsResponse> getMyRequests({
    String? statusFilter,
    int limit = 50,
  }) async {
    try {
      // Susun query params secara dinamis — `if` map literal tidak konsisten
      // dengan typing Dio, jadi pakai Map mutable.
      final qp = <String, dynamic>{'limit': limit};
      if (statusFilter != null && statusFilter.isNotEmpty) {
        qp['status'] = statusFilter;
      }

      final response = await _dio.get(
        ApiEndpoints.leaveRequestsMy,
        queryParameters: qp,
      );
      final result = MyLeaveRequestsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      debugPrint(
        '[LEAVE] Fetched ${result.requests.length} requests '
        '(p=${result.summary.pending} a=${result.summary.approved} r=${result.summary.rejected})',
      );
      return result;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Translate DioException → pesan Bahasa Indonesia ramah user.
  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final serverError = data['error'] as String?;
        if (serverError != null && serverError.isNotEmpty) {
          return serverError;
        }
      }
      switch (e.response?.statusCode) {
        case 400:
          return 'Data yang dikirim tidak valid.';
        case 401:
          return 'Sesi login habis. Silakan login ulang.';
        case 403:
          return 'Anda tidak memiliki akses untuk operasi ini.';
        case 404:
          return 'Sesi tidak ditemukan.';
        case 409:
          return 'Pengajuan untuk sesi ini sudah ada.';
        case 429:
          return 'Terlalu banyak pengajuan. Coba lagi nanti.';
        case 500:
          return 'Server bermasalah. Coba lagi nanti.';
        default:
          return 'Terjadi kesalahan. (${e.response?.statusCode})';
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
