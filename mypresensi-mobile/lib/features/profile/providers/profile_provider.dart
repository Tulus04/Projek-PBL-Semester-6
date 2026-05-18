// lib/features/profile/providers/profile_provider.dart
// Riverpod providers untuk fitur profil — saat ini hanya upload avatar.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/utils/error_mapper.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

enum AvatarUploadStatus { idle, uploading, success, error }

class AvatarUploadState {
  final AvatarUploadStatus status;
  final String? errorMessage;
  final String? successMessage;

  const AvatarUploadState({
    this.status = AvatarUploadStatus.idle,
    this.errorMessage,
    this.successMessage,
  });

  AvatarUploadState copyWith({
    AvatarUploadStatus? status,
    String? errorMessage,
    String? successMessage,
  }) {
    return AvatarUploadState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

final avatarUploadProvider =
    NotifierProvider<AvatarUploadNotifier, AvatarUploadState>(
  AvatarUploadNotifier.new,
);

class AvatarUploadNotifier extends Notifier<AvatarUploadState> {
  @override
  AvatarUploadState build() => const AvatarUploadState();

  /// Upload foto avatar baru. Setelah sukses, update local auth state
  /// (markAvatarUpdated) supaya UI Profile refresh tanpa full reload.
  /// Return true kalau berhasil.
  Future<bool> upload(File file) async {
    state = state.copyWith(
      status: AvatarUploadStatus.uploading,
      errorMessage: null,
    );

    try {
      final repo = ref.read(profileRepositoryProvider);
      final newUrl = await repo.uploadAvatar(file);

      // Update local auth state
      ref.read(authProvider.notifier).markAvatarUpdated(newUrl);

      state = state.copyWith(
        status: AvatarUploadStatus.success,
        successMessage: 'Foto profil berhasil diperbarui.',
      );
      return true;
    } catch (e) {
      debugPrint('[AVATAR] Upload error: $e');
      state = state.copyWith(
        status: AvatarUploadStatus.error,
        errorMessage: friendlyErrorMessage(e),
      );
      return false;
    }
  }

  void reset() {
    state = const AvatarUploadState();
  }
}
