// lib/features/home/screens/home_screen.dart
// Dashboard utama mahasiswa — greeting, sesi aktif, daftar MK

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../attendance/data/attendance_models.dart';
import '../../../shared/widgets/app_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// Reset welcome toast flag — panggil saat logout
  static void resetWelcome() => _HomeScreenState.resetWelcome();

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  static bool _hasShownWelcome = false;

  /// Reset flag — panggil saat logout agar toast muncul lagi
  static void resetWelcome() => _hasShownWelcome = false;

  // Animation controllers per-section
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  static const _sectionCount = 4;
  static const _staggerDelay = Duration(milliseconds: 100);
  static const _animDuration = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _sectionCount,
      (i) => AnimationController(duration: _animDuration, vsync: this),
    );

    _fadeAnims = _controllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOut);
    }).toList();

    _slideAnims = _controllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 20),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));
    }).toList();

    // Stagger-start animations
    for (var i = 0; i < _sectionCount; i++) {
      Future.delayed(_staggerDelay * (i + 1), () {
        if (mounted) _controllers[i].forward();
      });
    }

    // Show welcome toast sekali setelah login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownWelcome) {
        _hasShownWelcome = true;
        final name = ref.read(authProvider).user?.fullName ?? 'Mahasiswa';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selamat datang, $name!',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  /// Helper: wrap widget dengan fade+slide animation per index
  Widget _animated(int index, Widget child) {
    return AnimatedBuilder(
      animation: _controllers[index],
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnims[index].value,
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

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await ref.read(authProvider.notifier).refreshProfile();
            ref.invalidate(activeSessionsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // === Header Greeting ===
              SliverToBoxAdapter(
                child: _animated(0, _buildGreetingHeader(context, user?.fullName ?? 'Mahasiswa')),
              ),

              // === Quick Actions ===
              SliverToBoxAdapter(
                child: _animated(1, _buildQuickActions(context, ref)),
              ),

              // === Sesi Aktif ===
              SliverToBoxAdapter(
                child: _animated(2, _buildActiveSessionSection(context, ref)),
              ),

              // === Info Card ===
              SliverToBoxAdapter(
                child: _animated(3, Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _buildInfoCard(context, user),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(BuildContext context, String name) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData icon;

    if (hour < 11) {
      greeting = 'Selamat Pagi';
      icon = Icons.wb_sunny_outlined;
    } else if (hour < 15) {
      greeting = 'Selamat Siang';
      icon = Icons.wb_sunny;
    } else if (hour < 18) {
      greeting = 'Selamat Sore';
      icon = Icons.wb_twilight;
    } else {
      greeting = 'Selamat Malam';
      icon = Icons.nightlight_outlined;
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  name.split(' ').first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.fingerprint,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildActionButton(
            context,
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan QR',
            color: AppColors.primary,
            onTap: () => context.push('/scan'),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            context,
            icon: Icons.history_rounded,
            label: 'Riwayat',
            color: AppColors.success,
            onTap: () {
              // Navigate ke history tab (index 2)
              ref.read(currentTabProvider.notifier).setTab(2);
            },
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            context,
            icon: Icons.notifications_outlined,
            label: 'Notifikasi',
            color: AppColors.warning,
            onTap: () {
              // Navigate ke notifications tab (index 3)
              ref.read(currentTabProvider.notifier).setTab(3);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessionSection(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(activeSessionsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                sessionsAsync.when(
                  data: (sessions) {
                    final active = sessions.where((s) => !s.alreadySubmitted).toList();
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active.isNotEmpty ? AppColors.success : AppColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                  loading: () => Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  error: (e, _) => Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sesi Aktif',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            sessionsAsync.when(
              data: (sessions) {
                final active = sessions.where((s) => !s.alreadySubmitted).toList();
                if (active.isEmpty) {
                  return _buildEmptySessionState(context);
                }
                return Column(
                  children: active.map((session) => _buildSessionItem(context, session)).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, _) => Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 36, color: AppColors.danger),
                    const SizedBox(height: 8),
                    Text(
                      'Gagal memuat sesi',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(activeSessionsProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySessionState(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada sesi aktif saat ini',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Sesi presensi akan muncul di sini saat dosen membuka kelas',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, ActiveSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.class_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.courseName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Pertemuan ${session.sessionNumber}${session.topic != null ? ' — ${session.topic}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => context.push('/scan'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Scan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Akun',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(context, 'NIM', user?.nimNip ?? '-'),
          const Divider(height: 20),
          _buildInfoRow(context, 'Semester', user?.semester?.toString() ?? '-'),
          const Divider(height: 20),
          _buildInfoRow(context, 'Kelas', user?.kelas ?? '-'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
