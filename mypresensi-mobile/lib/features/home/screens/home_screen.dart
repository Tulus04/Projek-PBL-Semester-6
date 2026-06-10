// lib/features/home/screens/home_screen.dart
// Beranda mahasiswa v7 — sesuai mockup mobile-home.html (Phase 5 rebuild).
// Layout: appbar (brand+notif+avatar) → greeting → hero sesi (active/empty/loading)
// → ringkasan hari ini 3-stat → quick action 4-grid → activity feed → AI chat FAB.
// Activity feed ditambah 22 Mei 2026 (sesuai mockup section "Aktivitas Terakhir").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/hero_card.dart';
import '../../attendance/data/attendance_models.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../history/providers/history_provider.dart';
import '../providers/home_calendar_provider.dart';
import '../widgets/home_history_calendar_card.dart';
import '../widgets/stat_ring_card.dart';

// ============================================================================
// Pure helpers — date label, weather icon, today summary.
// ============================================================================

const List<String> _idWeekdayNames = [
  'Senin', // 1
  'Selasa', // 2
  'Rabu', // 3
  'Kamis', // 4
  'Jumat', // 5
  'Sabtu', // 6
  'Minggu', // 7
];

const List<String> _idMonthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _idWeekday(int weekday) {
  if (weekday < 1 || weekday > 7) return '';
  return _idWeekdayNames[weekday - 1];
}

String _idMonth(int month) {
  if (month < 1 || month > 12) return '';
  return _idMonthNames[month - 1];
}

/// Resolve label sapa berdasarkan jam lokal:
/// - 5-10  → Selamat pagi
/// - 11-14 → Selamat siang
/// - 15-17 → Selamat sore
/// - 18-04 → Selamat malam
///
/// Output format: "Selamat {bagian} — {hari}, {tgl} {bulan} {tahun}".
String _resolveDateLabel(DateTime now) {
  final hour = now.hour;
  final String greeting;
  if (hour >= 5 && hour <= 10) {
    greeting = 'Selamat pagi';
  } else if (hour >= 11 && hour <= 14) {
    greeting = 'Selamat siang';
  } else if (hour >= 15 && hour <= 17) {
    greeting = 'Selamat sore';
  } else {
    greeting = 'Selamat malam';
  }
  final hari = _idWeekday(now.weekday);
  final bulan = _idMonth(now.month);
  return '$greeting — $hari, ${now.day} $bulan ${now.year}';
}

/// Icon cuaca berdasarkan jam (fintech vibe — bukan literal cuaca real).
/// Bucket sama dengan greeting:
/// - pagi  → cloud_sunny (matahari terbit)
/// - siang → sun (matahari terik)
/// - sore  → cloud (langit menjelang sore)
/// - malam → moon
///
/// Catatan: `iconsax_plus 1.0.0` tidak punya `sun_1`/`sun_2`. `cloud_sunny`
/// dipakai sebagai pengganti pagi karena visualnya matahari + awan tipis.
IconData _resolveWeatherIcon(int hour) {
  if (hour >= 5 && hour <= 10) return IconsaxPlusBold.cloud_sunny;
  if (hour >= 11 && hour <= 14) return IconsaxPlusBold.sun;
  if (hour >= 15 && hour <= 17) return IconsaxPlusBold.cloud;
  return IconsaxPlusBold.moon;
}



/// Format jam ISO `started_at` → "HH:mm".
String _formatTimeFromIso(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  } catch (_) {
    return '--:--';
  }
}

// ============================================================================
// HomeScreen — wiring utama
// ============================================================================

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// Reset welcome toast flag — dipanggil dari `AuthNotifier.logout()`.
  /// API contract dipertahankan untuk kompatibilitas auth_provider.dart.
  static void resetWelcome() => _HomeScreenState.resetWelcome();

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  static bool _hasShownWelcome = false;

  /// Reset flag — panggil saat logout agar toast muncul lagi setelah login ulang.
  static void resetWelcome() => _hasShownWelcome = false;

  // Stagger animation per section (greeting, hero, historyCalendar, statsRing).
  static const _sectionCount = 4;
  static const _staggerDelay = Duration(milliseconds: 90);
  static const _animDuration = Duration(milliseconds: 420);

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _sectionCount,
      (_) => AnimationController(duration: _animDuration, vsync: this),
    );
    _fadeAnims = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _slideAnims = _controllers
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    for (var i = 0; i < _sectionCount; i++) {
      Future.delayed(_staggerDelay * (i + 1), () {
        if (mounted) _controllers[i].forward();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownWelcome && mounted) {
        _hasShownWelcome = true;
        final name =
            ref.read(authProvider).user?.fullName.split(' ').first ?? 'Mahasiswa';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(IconsaxPlusBold.tick_circle,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selamat datang, $name!',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Wrapper fade+slide animation per section index.
  Widget _animated(int index, Widget child) {
    return AnimatedBuilder(
      animation: _controllers[index],
      builder: (context, child) {
        return FractionalTranslation(
          translation: _slideAnims[index].value,
          child: Opacity(
            opacity: _fadeAnims[index].value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final sessionsAsync = ref.watch(activeSessionsProvider);
    final now = DateTime.now();
    final dateLabel = _resolveDateLabel(now);
    final weatherIcon = _resolveWeatherIcon(now.hour);
    final firstName =
        (user?.fullName.split(' ').first.trim().isNotEmpty ?? false)
            ? user!.fullName.split(' ').first
            : 'Mahasiswa';
    final initials = user?.initials ?? 'MP';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(activeSessionsProvider);
                ref.invalidate(historyProvider);
                ref.read(homeCalendarProvider.notifier).resetToToday();
                await Future.wait<void>([
                  ref.read(authProvider.notifier).refreshProfile(),
                  ref.read(activeSessionsProvider.future).catchError((_) =>
                      const <ActiveSession>[]),
                  ref.read(historyProvider.future).catchError((_) =>
                      throw Exception('Gagal memuat riwayat')),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
                children: [
                  _HomeAppBar(
                    userInitials: initials,
                    unreadBadge: false,
                  ),
                  const SizedBox(height: 6),
                  _animated(
                    0,
                    _GreetingHeader(
                      firstName: firstName,
                      dateLabel: dateLabel,
                      weatherIcon: weatherIcon,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _animated(1, _buildHeroSection(context, ref, sessionsAsync)),
                  const SizedBox(height: 16),
                  _animated(2, const HomeHistoryCalendarCard()),
                  const SizedBox(height: 18),
                  _animated(3, _buildStatsRingSection()),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: _AiChatFab(
                onTap: () => context.push('/ai-chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Sub-builder: hero zone (active / empty / loading / error) =====
  Widget _buildHeroSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ActiveSession>> sessionsAsync,
  ) {
    return sessionsAsync.when(
      data: (sessions) {
        final pending =
            sessions.where((s) => !s.alreadySubmitted).toList(growable: false);
        if (pending.isEmpty) {
          return const _HeroSessionEmpty();
        }
        final session = pending.first;
        return _HeroSessionActive(
          session: session,
          onScanTap: () => context.push('/scan'),
        );
      },
      loading: () => const _HeroSkeleton(),
      error: (error, _) => _HeroErrorBox(
        message: friendlyErrorMessage(error),
        onRetry: () => ref.invalidate(activeSessionsProvider),
      ),
    );
  }

  // ===== Sub-builder: stats ring =====
  Widget _buildStatsRingSection() {
    final historyAsync = ref.watch(historyProvider);
    return historyAsync.maybeWhen(
      data: (res) => StatRingCard(summary: res.summary),
      orElse: () => const StatsRingSkeleton(),
    );
  }
}

// ============================================================================
// _HomeAppBar — brand + notif icon button + avatar
// ============================================================================

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar({
    required this.userInitials,
    this.unreadBadge = false,
  });

  final String userInitials;
  final bool unreadBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'MyPresensi',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AppColors.primary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Notif icon button — tap → tab Notifikasi (index 3).
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref.read(currentTabProvider.notifier).setTab(3),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.card,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      IconsaxPlusBold.notification,
                      color: AppColors.textSecondary,
                      size: 19,
                    ),
                    if (unreadBadge)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar — tap → tab Profil (index 4).
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref.read(currentTabProvider.notifier).setTab(4),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryHover],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  userInitials,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _GreetingHeader — "Halo, {firstName}" + cuaca + tanggal
// ============================================================================

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.firstName,
    required this.dateLabel,
    required this.weatherIcon,
  });

  final String firstName;
  final String dateLabel;
  final IconData weatherIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, $firstName',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(weatherIcon, size: 16, color: AppColors.accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _HeroSessionActive — gradient + pulse badge + meta + CTA Scan QR
// ============================================================================

class _HeroSessionActive extends StatelessWidget {
  const _HeroSessionActive({required this.session, required this.onScanTap});

  final ActiveSession session;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final lokasi = session.mode == 'online' ? 'Online' : 'Offline · Di lokasi';
    final jam = _formatTimeFromIso(session.startedAt);
    final dosen = (session.dosenName?.trim().isNotEmpty ?? false)
        ? session.dosenName!
        : 'Dosen pengampu';

    return HeroCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PulseBadge(label: 'SESI AKTIF SEKARANG'),
          const SizedBox(height: 12),
          Text(
            session.courseName,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _HeroMetaRow(
            icon: IconsaxPlusBold.user,
            text: dosen,
          ),
          const SizedBox(height: 4),
          _HeroMetaRow(
            icon: IconsaxPlusBold.location,
            text: lokasi,
          ),
          const SizedBox(height: 4),
          _HeroMetaRow(
            icon: IconsaxPlusBold.clock,
            text: 'Mulai $jam',
          ),
          const SizedBox(height: 16),
          _PillButtonScan(onTap: onScanTap),
        ],
      ),
    );
  }
}

class _HeroMetaRow extends StatelessWidget {
  const _HeroMetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PillButtonScan extends StatelessWidget {
  const _PillButtonScan({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  IconsaxPlusBold.scan_barcode,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Scan QR Sekarang',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulse badge "SESI AKTIF SEKARANG" — animasi dot scale + opacity 1.5s loop.
class _PulseBadge extends StatelessWidget {
  const _PulseBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulseDot(),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 0.0 → 1.0 ditengah, easeInOut.
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 1.0 + 0.4 * t;
        final opacity = 1.0 - 0.5 * t;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// _HeroSessionEmpty — dashed border + calendar icon + copy ramah
// ============================================================================

class _HeroSessionEmpty extends StatelessWidget {
  const _HeroSessionEmpty();

  @override
  Widget build(BuildContext context) {
    return _DashedBorderBox(
      borderRadius: 18,
      borderColor: AppColors.borderStrong,
      strokeWidth: 1.5,
      dashLength: 6,
      gapLength: 4,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        width: double.infinity,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Icon(
                IconsaxPlusBold.calendar_2,
                size: 26,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada sesi aktif saat ini',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Belum ada dosen yang memulai sesi. Kamu akan mendapat notifikasi saat sesi dimulai.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom dashed border wrapper — Flutter tidak punya dashed `BorderSide`
/// di stable, dan kita tidak boleh nambah deps baru. CustomPainter ringan.
class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({
    required this.child,
    this.borderRadius = 16,
    this.borderColor = AppColors.borderStrong,
    this.strokeWidth = 1.5,
    this.dashLength = 6,
    this.gapLength = 4,
  });

  final Widget child;
  final double borderRadius;
  final Color borderColor;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        radius: borderRadius,
        color: borderColor,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final double radius;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect.deflate(strokeWidth / 2), Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashLength: dashLength, gapLength: gapLength);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source,
      {required double dashLength, required double gapLength}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

// ============================================================================
// _HeroSkeleton — shimmer placeholder saat sessions loading
// ============================================================================

class _HeroSkeleton extends StatefulWidget {
  const _HeroSkeleton();

  @override
  State<_HeroSkeleton> createState() => _HeroSkeletonState();
}

class _HeroSkeletonState extends State<_HeroSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final opacity = 0.5 + 0.5 * t;
        return Opacity(
          opacity: opacity,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// _HeroErrorBox — fallback saat sessionsAsync error
// ============================================================================

class _HeroErrorBox extends StatelessWidget {
  const _HeroErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      child: ErrorState(
        icon: IconsaxPlusBold.cloud_cross,
        title: 'Gagal memuat sesi',
        message: message,
        onRetry: onRetry,
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}



// ============================================================================
// _AiChatFab — floating bottom-right, gold gradient, AppShadows.fab
// ============================================================================

class _AiChatFab extends StatelessWidget {
  const _AiChatFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.accentSoft],
            ),
            boxShadow: AppShadows.fab,
          ),
          alignment: Alignment.center,
          child: const Icon(
            IconsaxPlusBold.message_question,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

