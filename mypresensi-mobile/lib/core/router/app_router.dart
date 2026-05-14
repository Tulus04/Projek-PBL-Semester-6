// lib/core/router/app_router.dart
// GoRouter config — redirect guard berdasarkan auth state.
// Menggunakan Riverpod yang benar: JANGAN re-create GoRouter setiap state berubah.
// Gunakan refreshListenable agar GoRouter me-reevaluate redirect saja.
// Semua route menggunakan custom transition untuk UX yang smooth.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../features/attendance/screens/scan_qr_screen.dart';
import '../../features/attendance/screens/attendance_result_screen.dart';
import '../../features/face/screens/face_registration_screen.dart';
import '../../features/face/screens/face_verification_screen.dart';
import '../../features/leave_requests/screens/my_leave_requests_screen.dart';
import '../../features/leave_requests/screens/submit_leave_request_screen.dart';
import '../../shared/widgets/app_shell.dart';

/// Listenable yang dipicu setiap auth state berubah,
/// agar GoRouter hanya re-evaluate redirect (bukan rebuild instansi baru).
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

// === Transition Helpers ===

/// Fade transition — untuk perpindahan konteks (login → home, splash → login)
CustomTransitionPage<void> _fadeTransition({
  required GoRouterState state,
  required Widget child,
  Duration duration = const Duration(milliseconds: 350),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    },
  );
}

/// Slide from right — untuk push screen (detail, scan, face)
CustomTransitionPage<void> _slideTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0.0), // Masuk dari kanan
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      final fadeIn = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOut),
      );

      return SlideTransition(
        position: slideIn,
        child: FadeTransition(opacity: fadeIn, child: child),
      );
    },
  );
}

/// Fade + scale-up — untuk masuk ke home setelah login (celebratory feel)
CustomTransitionPage<void> _fadeScaleTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      );

      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final currentPath = state.matchedLocation;
      final isOnSplash = currentPath == '/splash';
      final isOnLogin = currentPath == '/login';
      final isOnChangePassword = currentPath == '/change-password';

      // 1. Splash animation belum selesai → tetap di splash
      if (!authState.splashCompleted) {
        return isOnSplash ? null : '/splash';
      }

      // 2. Sedang loading (login in progress) → JANGAN redirect.
      if (authState.status == AuthStatus.loading ||
          authState.status == AuthStatus.initial) {
        return null;
      }

      // 3. Force Change Password
      if (authState.mustChangePassword) {
        return isOnChangePassword ? null : '/change-password';
      }

      // 4. Authenticated → arahkan ke home jika masih di splash/login
      if (authState.isAuthenticated) {
        if (isOnSplash || isOnLogin || isOnChangePassword) {
          return '/';
        }
        return null;
      }

      // 5. Unauthenticated / Error → arahkan ke login
      return isOnLogin ? null : '/login';
    },
    routes: [
      // === Auth screens — fade transition ===
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _fadeTransition(
          state: state,
          child: const SplashScreen(),
          duration: const Duration(milliseconds: 500),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadeTransition(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/change-password',
        pageBuilder: (context, state) => _fadeTransition(
          state: state,
          child: const ChangePasswordScreen(),
        ),
      ),

      // === Home — fade + scale-up (celebratory masuk app) ===
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fadeScaleTransition(
          state: state,
          child: const AppShell(),
        ),
      ),

      // === Push screens — slide from right ===
      GoRoute(
        path: '/scan',
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const ScanQrScreen(),
        ),
      ),
      GoRoute(
        path: '/attendance-result',
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const AttendanceResultScreen(),
        ),
      ),
      GoRoute(
        path: '/face-register',
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const FaceRegistrationScreen(),
        ),
      ),
      GoRoute(
        path: '/face-verify',
        // Threshold dibaca dari faceConfigProvider (server settings) di dalam screen.
        // Caller boleh pass `extra: <double>` untuk override (testing only).
        pageBuilder: (context, state) {
          final overrideThreshold = state.extra is double ? state.extra as double : null;
          return _slideTransition(
            state: state,
            child: FaceVerificationScreen(threshold: overrideThreshold),
          );
        },
      ),

      // === Leave requests (izin/sakit) — slide from right ===
      GoRoute(
        path: '/leave-requests',
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const MyLeaveRequestsScreen(),
        ),
      ),
      GoRoute(
        path: '/leave-request/submit',
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const SubmitLeaveRequestScreen(),
        ),
      ),
    ],
  );
});

