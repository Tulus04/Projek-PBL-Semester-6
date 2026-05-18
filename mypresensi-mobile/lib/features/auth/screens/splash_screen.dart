// lib/features/auth/screens/splash_screen.dart
// Splash screen — menampilkan logo TRPL dengan animasi premium staggered.
// Flow: Native splash dismiss → Logo scale-up + glow breathing →
// Teks slide-up dari bawah → Loading shimmer → Fade-out → Router redirect

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // === Animation Controllers ===
  late AnimationController _entryController;    // Logo + glow masuk (0→2s)
  late AnimationController _textController;     // Teks slide-up (0→1.5s)
  late AnimationController _breathController;   // Glow breathing loop
  late AnimationController _exitController;     // Fade-out sebelum navigate

  // === Entry Animations ===
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoElevation;

  // === Text Animations (slide-up dari bawah + fade) ===
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _institutionFade;
  late Animation<Offset> _institutionSlide;
  late Animation<double> _loadingFade;
  late Animation<double> _versionFade;

  // === Exit Animation ===
  late Animation<double> _exitFade;

  // Timers
  Timer? _textTimer;
  Timer? _authTimer;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // ─── Entry: Logo muncul (2 detik) ───
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Logo scale: 0.3 → 1.0 dengan easeOutCubic (smooth, no jarring bounce)
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    // Logo fade: 0 → 1
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0, 0.35, curve: Curves.easeOut),
      ),
    );

    // Logo elevation/shadow ramp-up
    _logoElevation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    // ─── Glow Breathing (loop, 2.5s per cycle) ───
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // ─── Text slide-up dari bawah (1.5 detik, staggered) ───
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Title "MyPresensi" — pertama muncul
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0, 0.35, curve: Curves.easeOutCubic),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.8), // mulai dari bawah
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0, 0.40, curve: Curves.easeOutCubic),
      ),
    );

    // Subtitle "Sistem Presensi Digital" — delay sedikit
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.15, 0.50, curve: Curves.easeOutCubic),
      ),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.15, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    // Institution "TRPL · Politani Samarinda" — delay lagi
    _institutionFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.30, 0.60, curve: Curves.easeOutCubic),
      ),
    );
    _institutionSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.30, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    // Loading indicator — muncul terakhir
    _loadingFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
      ),
    );

    // Version — muncul bersamaan loading
    _versionFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
      ),
    );

    // ─── Exit fade-out (500ms) ───
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );
  }

  void _startSequence() {
    // Step 0: Hapus native splash (background polos)
    FlutterNativeSplash.remove();

    // Step 1: Logo muncul
    _entryController.forward();

    // Step 1b: Glow breathing mulai setelah logo visible (800ms)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _breathController.repeat(reverse: true);
    });

    // Step 2: Teks slide-up dari bawah (delay 600ms setelah logo mulai)
    _textTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _textController.forward();
    });

    // Step 3: Cek auth di background (1.5s)
    _authTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      ref.read(authProvider.notifier).checkAuthStatus();
    });

    // Step 4: Fade-out + tandai splash selesai (3.2s)
    _exitTimer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      _exitController.forward().then((_) async {
        if (!mounted) return;
        // Cek onboarding flag SEBELUM lanjut ke auth flow.
        // Kalau user belum pernah lihat onboarding → tampilkan onboarding dulu.
        final prefs = await SharedPreferences.getInstance();
        final hasSeenOnboarding =
            prefs.getBool('hasSeenOnboarding') ?? false;
        if (!mounted) return;

        if (!hasSeenOnboarding) {
          // Bypass auth redirect — langsung ke onboarding screen.
          // Setelah onboarding selesai, user akan di-route ke /login (lihat
          // OnboardingScreen._handleFinish).
          ref.read(authProvider.notifier).markSplashCompleted();
          if (mounted) {
            // Pakai go() bukan replace karena route stack dari splash kosong.
            // Sequence: splash → onboarding → login → home.
            // (router redirect tetap akan re-evaluate — tapi karena auth status
            // unauthenticated, ia akan coba route ke /login. Onboarding
            // di-protect dengan flag, jadi user-controlled flow lewat go().)
            // Note: redirect logic perlu disesuaikan agar /onboarding tidak
            // di-bounce ke /login saat unauthenticated.
            // ignore: use_build_context_synchronously
            Future.microtask(() {
              if (mounted) GoRouter.of(context).go('/onboarding');
            });
          }
        } else {
          ref.read(authProvider.notifier).markSplashCompleted();
        }
      });
    });
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _authTimer?.cancel();
    _exitTimer?.cancel();
    _entryController.dispose();
    _textController.dispose();
    _breathController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final logoSize = screenWidth * 0.28;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _entryController,
          _textController,
          _breathController,
          _exitController,
        ]),
        builder: (context, child) {
          return FadeTransition(
            opacity: _exitController.isAnimating || _exitController.isCompleted
                ? _exitFade
                : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.4, 1.0],
                  colors: [
                    Color(0xFFF8FAFD),
                    Color(0xFFF0F4F8),
                    Color(0xFFE4ECF4),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.12),

                    // ═══ Logo TRPL dengan glow breathing ═══
                    _buildLogo(logoSize),

                    const SizedBox(height: 28),

                    // ═══ Title: MyPresensi ═══
                    _buildTitle(),

                    const SizedBox(height: 8),

                    // ═══ Subtitle: Sistem Presensi Digital ═══
                    _buildSubtitle(),

                    const SizedBox(height: 6),

                    // ═══ Institution ═══
                    _buildInstitution(),

                    const Spacer(),

                    // ═══ Loading shimmer ═══
                    _buildLoadingIndicator(),

                    const SizedBox(height: 20),

                    // ═══ Version footer ═══
                    _buildVersion(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Logo dengan glow breathing effect ───
  Widget _buildLogo(double size) {
    // Breathing glow: sine wave 0.08 → 0.28
    final breathValue = _breathController.value;
    final glowAlpha = 0.08 + (math.sin(breathValue * math.pi) * 0.20);

    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              // Glow breathing
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: glowAlpha * _logoElevation.value,
                ),
                blurRadius: 40 + (breathValue * 12),
                spreadRadius: 2 + (breathValue * 4),
              ),
              // Drop shadow
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.05 * _logoElevation.value,
                ),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/trpl_logo.jpg',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Title dengan slide-up effect ───
  Widget _buildTitle() {
    return FadeTransition(
      opacity: _titleFade,
      child: SlideTransition(
        position: _titleSlide,
        child: const Text(
          'MyPresensi',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  // ─── Subtitle dengan slide-up staggered ───
  Widget _buildSubtitle() {
    return FadeTransition(
      opacity: _subtitleFade,
      child: SlideTransition(
        position: _subtitleSlide,
        child: const Text(
          'Sistem Presensi Digital',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ─── Institution dengan slide-up staggered ───
  Widget _buildInstitution() {
    return FadeTransition(
      opacity: _institutionFade,
      child: SlideTransition(
        position: _institutionSlide,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'TRPL · Politani Samarinda',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 20,
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Loading: custom shimmer bar ───
  Widget _buildLoadingIndicator() {
    return FadeTransition(
      opacity: _loadingFade,
      child: Column(
        children: [
          // Shimmer loading bar
          Container(
            width: 48,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
            child: AnimatedBuilder(
              animation: _breathController,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.3 + (_breathController.value * 0.7),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.primary.withValues(alpha: 0.40),
                          AppColors.primary.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Mempersiapkan aplikasi...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textTertiary.withValues(alpha: 0.7),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Version footer ───
  Widget _buildVersion() {
    return FadeTransition(
      opacity: _versionFade,
      child: Text(
        'v1.0.0',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary.withValues(alpha: 0.4),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
