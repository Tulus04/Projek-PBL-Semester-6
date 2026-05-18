// lib/features/onboarding/screens/onboarding_screen.dart
// Onboarding 3-step (Welcome → Cara Pakai → Get Started) yang muncul
// hanya saat first install (cek SharedPreferences.hasSeenOnboarding).
//
// Mockup referensi: docs/ui-research/mockups/mobile-onboarding.html
// Spec: .kiro/specs/onboarding-mobile/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _totalPages = 3;
  static const _onboardingFlagKey = 'hasSeenOnboarding';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingFlagKey, true);
  }

  Future<void> _handleSkip() async {
    await _markOnboardingSeen();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _handleFinish() async {
    await _markOnboardingSeen();
    if (!mounted) return;
    context.go('/login');
  }

  void _handleNext() {
    if (_currentPage == _totalPages - 1) {
      _handleFinish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.6],
                colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
              ),
            ),
          ),
          // Top-right primary radial glow
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
          ),
          // Top-left amber radial glow
          Positioned(
            top: -60,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _OnboardingTopbar(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  showSkip: _currentPage < _totalPages - 1,
                  onSkip: _handleSkip,
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                    },
                    children: const [
                      _OnboardingStep1(),
                      _OnboardingStep2(),
                      _OnboardingStep3(),
                    ],
                  ),
                ),
                _OnboardingFooter(
                  isLastPage: _currentPage == _totalPages - 1,
                  onTap: _handleNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Topbar — Skip + Step Indicator
// ============================================================================

class _OnboardingTopbar extends StatelessWidget {
  const _OnboardingTopbar({
    required this.currentPage,
    required this.totalPages,
    required this.showSkip,
    required this.onSkip,
  });

  final int currentPage;
  final int totalPages;
  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      child: Row(
        children: [
          // Skip button (atau placeholder spacer)
          // Width 88 untuk akomodasi text "Lewati" + padding tanpa wrap.
          SizedBox(
            width: 88,
            child: showSkip
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text(
                        'Lewati',
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                    ),
                  )
                : null,
          ),
          // Step indicator
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (i) {
                final isActive = i == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 88),
        ],
      ),
    );
  }
}

// ============================================================================
// Step 1: Welcome
// ============================================================================

class _OnboardingStep1 extends StatelessWidget {
  const _OnboardingStep1();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Brand tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.20),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  IconsaxPlusBold.verify,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'POLITANI SAMARINDA',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Illustration card primary gradient
          _IllustrationCard(
            icon: IconsaxPlusBold.like_1,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            iconColor: Colors.white,
            shadowColor: AppColors.primary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'Selamat Datang di MyPresensi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 28,
              height: 1.2,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            'Sistem absensi pintar dengan tiga lapis verifikasi — QR Code, GPS, dan Face Recognition. Khusus mahasiswa Prodi TRPL Politeknik Pertanian Negeri Samarinda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Step 2: Cara Pakai
// ============================================================================

class _OnboardingStep2 extends StatelessWidget {
  const _OnboardingStep2();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        children: [
          _IllustrationCard(
            icon: IconsaxPlusBold.shield_tick,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFECFDF5), Color(0xFFDCFCE7)],
            ),
            iconColor: AppColors.success,
            shadowColor: AppColors.success.withValues(alpha: 0.30),
          ),
          const SizedBox(height: 20),

          const Text(
            'Cara Kerja Presensi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 26,
              height: 1.2,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tiga langkah verifikasi memastikan kehadiran kamu valid dan aman dari titip absen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Feature list
          _FeatureListItem(
            icon: IconsaxPlusBold.scan_barcode,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primary.withValues(alpha: 0.10),
            title: '1. Scan QR Code Sesi',
            description:
                'Dosen tampilkan QR di kelas, kamu scan via aplikasi untuk konfirmasi sesi yang benar.',
          ),
          const SizedBox(height: 12),
          _FeatureListItem(
            icon: IconsaxPlusBold.location,
            iconColor: const Color(0xFFB45309),
            iconBgColor: AppColors.accent.withValues(alpha: 0.15),
            title: '2. Verifikasi Lokasi GPS',
            description:
                'Pastikan kamu benar-benar di area kampus dengan radius geofence yang ditentukan dosen.',
          ),
          const SizedBox(height: 12),
          _FeatureListItem(
            icon: IconsaxPlusBold.scan,
            iconColor: AppColors.success,
            iconBgColor: AppColors.success.withValues(alpha: 0.10),
            title: '3. Face Recognition',
            description:
                'Pastikan kamu sendiri yang absen, bukan orang lain pakai HP-mu.',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Step 3: Get Started
// ============================================================================

class _OnboardingStep3 extends StatelessWidget {
  const _OnboardingStep3();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IllustrationCard(
            icon: IconsaxPlusBold.airplane,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
            ),
            iconColor: const Color(0xFFB45309),
            shadowColor: AppColors.accent.withValues(alpha: 0.30),
          ),
          const SizedBox(height: 24),

          const Text(
            'Siap Untuk Mulai?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 28,
              height: 1.2,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Login dengan NIM dan password yang dibagikan kampus. Jika password belum kamu ganti, kamu akan diminta ganti password dulu sebelum bisa pakai aplikasi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Privacy summary
          _PrivacyPoint(
            text: 'Data kamu disimpan aman dan hanya dipakai internal kampus',
          ),
          const SizedBox(height: 8),
          _PrivacyPoint(
            text: 'Bisa hapus data wajah kapan saja lewat menu Profil',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Sub-component: Illustration Card
// ============================================================================

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.shadowColor,
  });

  final IconData icon;
  final Gradient gradient;
  final Color iconColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top-right gold accent
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
          ),
          // Icon
          Center(
            child: Icon(
              icon,
              size: 90,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Sub-component: Feature List Item
// ============================================================================

class _FeatureListItem extends StatelessWidget {
  const _FeatureListItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Sub-component: Privacy Point
// ============================================================================

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            IconsaxPlusBold.tick_circle,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Footer button
// ============================================================================

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.isLastPage,
    required this.onTap,
  });

  final bool isLastPage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: AppColors.primary.withValues(alpha: 0.55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ).copyWith(
            elevation: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) return 4;
              return 6;
            }),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(isLastPage ? 'Masuk Sekarang' : 'Lanjut'),
              const SizedBox(width: 8),
              Icon(
                isLastPage ? IconsaxPlusBold.login : IconsaxPlusBold.arrow_right_3,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
