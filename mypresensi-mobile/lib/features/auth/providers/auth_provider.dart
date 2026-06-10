// lib/features/auth/providers/auth_provider.dart
// Riverpod provider untuk state autentikasi — seluruh app akses status login.
// Handle: initial check, login, logout, force change password.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../core/services/fcm_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../home/screens/home_screen.dart';
import '../../../shared/widgets/app_shell.dart';

// Provider untuk AuthRepository instance
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// State untuk autentikasi
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  forceChangePassword, // User harus ganti password dulu via web
  error,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final bool splashCompleted; // Flag: splash animation sudah selesai

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.splashCompleted = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool? splashCompleted,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      splashCompleted: splashCompleted ?? this.splashCompleted,
    );
  }

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get mustChangePassword => status == AuthStatus.forceChangePassword;
}

// Provider utama untuk auth state
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Tandai splash animation sudah selesai
  void markSplashCompleted() {
    state = state.copyWith(splashCompleted: true);
  }

  /// Cek status login saat app start (dari secure storage)
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final isLoggedIn = await _repository.isLoggedIn();
      if (isLoggedIn) {
        // Coba ambil user dari local storage dulu (cepat)
        final savedUser = await _repository.getSavedUser();
        if (savedUser != null) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: savedUser,
          );
          debugPrint('[AUTH] Loaded from storage: ${savedUser.fullName}');
          return;
        }
      }
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('[AUTH] Check status error: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Login — return true jika berhasil
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final user = await _repository.login(
        email: email,
        password: password,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        splashCompleted: true,
      );

      // FCM: init + register token setelah login sukses (silent fail di dalam).
      // Tidak di-await — jangan blok transisi ke home.
      FcmService.initialize();

      return true;
    } on ForceChangePasswordException catch (e) {
      // User harus ganti password — tapi tetap simpan user data untuk ChangePasswordScreen
      final savedUser = await _repository.getSavedUser();
      state = AuthState(
        status: AuthStatus.forceChangePassword,
        user: savedUser,
        errorMessage: e.message,
        splashCompleted: true,
      );
      return false;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: friendlyErrorMessage(e),
        splashCompleted: true,
      );
      return false;
    }
  }

  /// Clear error — kembali ke unauthenticated agar bisa retry
  void clearError() {
    if (state.status == AuthStatus.error ||
        state.status == AuthStatus.forceChangePassword) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: null,
      );
    }
  }

  /// Logout — hapus semua data, kembali ke login
  Future<void> logout() async {
    // FCM: hapus token device dulu supaya tidak terima push setelah logout.
    await FcmService.clearToken();
    await _repository.logout();
    HomeScreen.resetWelcome();
    // Reset tab ke Beranda agar re-login tidak menampilkan tab terakhir
    ref.read(currentTabProvider.notifier).setTab(0);
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      splashCompleted: true, // Jangan balik ke splash
    );
  }

  /// Refresh profile dari API (background, silent fail)
  Future<void> refreshProfile() async {
    try {
      final user = await _repository.getProfile();
      state = state.copyWith(user: user);
    } catch (_) {
      // Silent fail — keep existing data
    }
  }

  /// Update local flag isFaceRegistered tanpa mereset auth state.
  /// Menggunakan UserModel baru agar UI update tanpa flash loading.
  void markFaceRegistered() {
    final currentUser = state.user;
    if (currentUser == null) return;

    final updatedUser = UserModel(
      id: currentUser.id,
      fullName: currentUser.fullName,
      nimNip: currentUser.nimNip,
      email: currentUser.email,
      role: currentUser.role,
      semester: currentUser.semester,
      kelas: currentUser.kelas,
      phone: currentUser.phone,
      avatarUrl: currentUser.avatarUrl,
      isFaceRegistered: true,
    );
    state = state.copyWith(user: updatedUser);
    debugPrint('[AUTH] markFaceRegistered: updated locally');
  }

  /// Update avatar URL lokal setelah upload berhasil. Tidak mereset auth state
  /// — UI yang watch authProvider auto-rebuild dengan URL baru.
  void markAvatarUpdated(String newAvatarUrl) {
    final currentUser = state.user;
    if (currentUser == null) return;

    final updatedUser = UserModel(
      id: currentUser.id,
      fullName: currentUser.fullName,
      nimNip: currentUser.nimNip,
      email: currentUser.email,
      role: currentUser.role,
      semester: currentUser.semester,
      kelas: currentUser.kelas,
      phone: currentUser.phone,
      avatarUrl: newAvatarUrl,
      isFaceRegistered: currentUser.isFaceRegistered,
    );
    state = state.copyWith(user: updatedUser);
    debugPrint('[AUTH] markAvatarUpdated: $newAvatarUrl');
  }

  /// Update local flag isFaceRegistered = false setelah user hapus data wajah
  /// (UU PDP hak hapus). Tidak mereset auth state — user tetap login.
  void markFaceUnregistered() {
    final currentUser = state.user;
    if (currentUser == null) return;

    final updatedUser = UserModel(
      id: currentUser.id,
      fullName: currentUser.fullName,
      nimNip: currentUser.nimNip,
      email: currentUser.email,
      role: currentUser.role,
      semester: currentUser.semester,
      kelas: currentUser.kelas,
      phone: currentUser.phone,
      avatarUrl: currentUser.avatarUrl,
      isFaceRegistered: false,
    );
    state = state.copyWith(user: updatedUser);
    debugPrint('[AUTH] markFaceUnregistered: updated locally');
  }

  /// Ganti password — dipanggil dari ChangePasswordScreen
  Future<bool> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final success = await _repository.changePassword(
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (success) {
        // Transisi ke authenticated — user sekarang boleh masuk app
        state = AuthState(
          status: AuthStatus.authenticated,
          user: state.user,
          splashCompleted: true,
        );
      }

      return success;
    } catch (e) {
      return false;
    }
  }
}
