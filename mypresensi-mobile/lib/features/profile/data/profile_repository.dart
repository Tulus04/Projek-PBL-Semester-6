// lib/features/profile/data/profile_repository.dart
// Repository untuk fitur profil mahasiswa — upload foto avatar.
// Backend: bucket avatars existing (public) dengan path '<user.id>.jpg'.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

class ProfileRepository {
  Dio get _dio => DioClient.instance;

  /// Upload foto avatar ke server. Server validasi mime + size + magic bytes,
  /// upload ke bucket `avatars` (path `<user.id>.jpg` upsert), update kolom
  /// `profiles.avatar_url`, return public URL dengan cache buster.
  ///
  /// Throws String berisi pesan Bahasa Indonesia jika gagal.
  Future<String> uploadAvatar(File file) async {
    try {
      // Detect content type dari extension (image_picker umumnya JPEG)
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
        ApiEndpoints.profileAvatar,
        data: formData,
      );

      final data = response.data as Map<String, dynamic>;
      final url = data['avatar_url'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('Server tidak mengembalikan URL foto.');
      }
      debugPrint('[PROFILE] Avatar uploaded: $url');
      return url;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final msg = e.response!.data['error'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    switch (e.response?.statusCode) {
      case 400:
        return 'Foto tidak valid';
      case 401:
        return 'Sesi berakhir, login ulang';
      case 403:
        return 'Akses ditolak';
      case 429:
        return 'Terlalu banyak upload';
      case 500:
        return 'Server bermasalah';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak ada koneksi internet';
    }
    return 'Gagal mengunggah foto';
  }
}
