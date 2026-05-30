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
import '../../../shared/widgets/kpi_icon_box.dart';
import '../../attendance/data/attendance_models.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/activity_models.dart';
import '../providers/activity_provider.dart';

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

/// Hasil hitung ringkasan hari ini — dipakai oleh `_TodaySummaryRow`.
typedef TodaySummary = ({int hadir, int sisa, int alpa, int total});

/// Compute ringkasan dari list `activeSessions` (Algorithm 4 di design.md).
/// `alpa` placeholder 0 hingga endpoint dashboard tersedia (D4).
TodaySummary _computeTodaySummary(List<ActiveSession> sessions) {
  var hadir = 0;
  var sisa = 0;
  for (final s in sessions) {
    if (s.alreadySubmitted) {
      hadir++;
    } else {
      sisa++;
    }
  }
  return (hadir: hadir, sisa: sisa, alpa: 0, total: sessions.length);
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

  // Stagger animation per section (greeting, hero, summary, quickActions, activityFeed).
  static const _sectionCount = 5;
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
                await Future.wait<void>([
                  ref.read(authProvider.notifier).refreshProfile(),
                  ref.read(activeSessionsProvider.future).catchError((_) =>
                      const <ActiveSession>[]),
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
                  _animated(2, _buildSummarySection(sessionsAsync)),
                  const SizedBox(height: 18),
                  _animated(3, _buildQuickActionsSection(context, ref)),
                  const SizedBox(height: 18),
                  _animated(4, _buildActivityFeedSection(context, ref)),
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

  // ===== Sub-builder: today summary =====
  Widget _buildSummarySection(AsyncValue<List<ActiveSession>> sessionsAsync) {
    return sessionsAsync.maybeWhen(
      data: (sessions) {
        final s = _computeTodaySummary(sessions);
        return _TodaySummaryRow(
          hadir: s.hadir,
          sisa: s.sisa,
          alpa: s.alpa,
          totalToday: s.total,
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  // ===== Sub-builder: quick action grid =====
  Widget _buildQuickActionsSection(BuildContext context, WidgetRef ref) {
    return _QuickActionGrid(
      onScanTap: () => context.push('/scan'),
      onHistoryTap: () => ref.read(currentTabProvider.notifier).setTab(1),
      onLeaveTap: () => ref.read(currentTabProvider.notifier).setTab(2),
      onProfileTap: () => ref.read(currentTabProvider.notifier).setTab(4),
    );
  }

  // ===== Sub-builder: Activity Feed =====
  // Menampilkan 3 activity terakhir (attendance + leave_requests gabungan).
  // Sumber data: provider recentActivitiesProvider → endpoint /api/mobile/activity/recent.
  Widget _buildActivityFeedSection(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(recentActivitiesProvider);
    return _ActivityFeedSection(
      activitiesAsync: activitiesAsync,
      onSeeAll: () => ref.read(currentTabProvider.notifier).setTab(1),
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
// _TodaySummaryRow — 3 stat card (Hadir / Sisa Sesi / Alpa)
// ============================================================================

class _TodaySummaryRow extends StatelessWidget {
  const _TodaySummaryRow({
    required this.hadir,
    required this.sisa,
    required this.alpa,
    required this.totalToday,
  });

  final int hadir;
  final int sisa;
  final int alpa;
  final int totalToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Ringkasan Hari Ini',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _TodayStatCard(
                value: '$hadir/$totalToday',
                label: 'Hadir',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TodayStatCard(
                value: '$sisa',
                label: 'Sisa Sesi',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TodayStatCard(
                value: '$alpa',
                label: 'Alpa',
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayStatCard extends StatelessWidget {
  const _TodayStatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _QuickActionGrid — 4 quick actions (Scan QR featured / Riwayat / Izin / Profil)
// ============================================================================

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.onScanTap,
    required this.onHistoryTap,
    required this.onLeaveTap,
    required this.onProfileTap,
  });

  final VoidCallback onScanTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onLeaveTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Aksi Cepat',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _QuickActionItem(
                icon: IconsaxPlusBold.scan_barcode,
                label: 'Scan QR',
                variant: KpiColor.featured,
                onTap: onScanTap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionItem(
                icon: IconsaxPlusBold.clipboard_text,
                label: 'Riwayat',
                variant: KpiColor.success,
                onTap: onHistoryTap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionItem(
                icon: IconsaxPlusBold.note_2,
                label: 'Izin',
                variant: KpiColor.warning,
                onTap: onLeaveTap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionItem(
                icon: IconsaxPlusBold.user,
                label: 'Profil',
                variant: KpiColor.info,
                onTap: onProfileTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.variant,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final KpiColor variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      borderRadius: 14,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KpiIconBox(
            icon: icon,
            variant: variant,
            size: 40,
            borderRadius: 12,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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


// ============================================================================
// _ActivityFeedSection — section "Aktivitas Terakhir" di Beranda
// 3 item terakhir (gabungan attendance + leave_requests) dari endpoint
// /api/mobile/activity/recent. Sesuai mockup mobile-home.html line 728+.
// ============================================================================

class _ActivityFeedSection extends StatelessWidget {
  const _ActivityFeedSection({
    required this.activitiesAsync,
    required this.onSeeAll,
  });

  final AsyncValue<List<ActivityItem>> activitiesAsync;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header: title + "Lihat semua →"
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Aktivitas Terakhir',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSeeAll,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat semua',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        IconsaxPlusBold.arrow_right_3,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Body: loading skeleton / list / empty / error
        activitiesAsync.when(
          loading: () => const _ActivityListSkeleton(),
          error: (err, _) => _ActivityErrorState(
            message: friendlyErrorMessage(err),
          ),
          data: (activities) {
            if (activities.isEmpty) {
              return const _ActivityEmptyState();
            }
            // Tampilkan max 3 item di Beranda (sisanya bisa di-akses via "Lihat semua")
            final visible = activities.take(3).toList(growable: false);
            return Column(
              children: [
                for (int i = 0; i < visible.length; i++) ...[
                  _ActivityItemCard(item: visible[i]),
                  if (i < visible.length - 1) const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ActivityItemCard extends StatelessWidget {
  const _ActivityItemCard({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = _resolveStatusVisuals(item.status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duotone icon box
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          // Title + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      IconsaxPlusBold.clock,
                      size: 11,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatRelativeTime(item.occurredAt) +
                            (item.subtitle.isNotEmpty ? ' · ${item.subtitle}' : ''),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Map ActivityStatus → (foreground, background, icon).
  static (Color, Color, IconData) _resolveStatusVisuals(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.success:
        return (
          AppColors.success,
          AppColors.success.withValues(alpha: 0.10),
          IconsaxPlusBold.tick_circle,
        );
      case ActivityStatus.warning:
        return (
          AppColors.warning,
          AppColors.warningTint,
          IconsaxPlusBold.danger,
        );
      case ActivityStatus.danger:
        return (
          AppColors.danger,
          AppColors.dangerTint,
          IconsaxPlusBold.close_circle,
        );
      case ActivityStatus.info:
        return (
          AppColors.info,
          AppColors.infoTint,
          IconsaxPlusBold.info_circle,
        );
    }
  }
}

/// Format waktu relatif Bahasa Indonesia: "5 menit lalu", "Kemarin", "3 hari lalu".
String _formatRelativeTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);

  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'Kemarin';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} bulan lalu';
  return '${(diff.inDays / 365).floor()} tahun lalu';
}

class _ActivityListSkeleton extends StatelessWidget {
  const _ActivityListSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar({double w = double.infinity, double h = 12}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.borderStrong.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Column(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(w: 180),
                      const SizedBox(height: 8),
                      bar(w: 120, h: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (i < 2) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              IconsaxPlusBold.clock,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Belum ada aktivitas',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Riwayat presensi & izin akan muncul di sini setelah kamu mulai aktif.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityErrorState extends StatelessWidget {
  const _ActivityErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            IconsaxPlusBold.danger,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
