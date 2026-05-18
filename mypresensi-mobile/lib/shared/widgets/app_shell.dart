// lib/shared/widgets/app_shell.dart
// Shell widget dengan bottom navigation 5-tab v7 (17 Mei 2026):
// Beranda · Riwayat · Izin · Notifikasi · Profil.
// Catatan migrasi: tab AI Chat dihapus (di-soft-deprecate), dipindah ke menu
// Profil sebagai opsional. Tab Izin = gateway list pengajuan + FAB ajukan baru.
// Konsisten dengan mockup HTML mobile-* dan rule 22-mobile-design-system §C.8.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/leave_requests/screens/my_leave_requests_screen.dart';
import '../../features/notifications/screens/notification_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

// Tab index provider — Notifier pattern (Riverpod v3).
// Index mapping:
//   0 = Beranda · 1 = Riwayat · 2 = Izin · 3 = Notifikasi · 4 = Profil
final currentTabProvider = NotifierProvider<CurrentTabNotifier, int>(CurrentTabNotifier.new);

class CurrentTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  DateTime? _lastBackPress;

  // Order WAJIB match dengan _buildNavItem indeks di bottom nav.
  static const _screens = [
    HomeScreen(),
    HistoryScreen(),
    MyLeaveRequestsScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentTabProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // Jika bukan di tab Beranda, kembali ke Beranda dulu
        if (currentTab != 0) {
          ref.read(currentTabProvider.notifier).setTab(0);
          return;
        }

        // Di tab Beranda — double-back to exit
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          // Izinkan keluar
          Navigator.of(context).pop();
          return;
        }

        _lastBackPress = now;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Tekan sekali lagi untuk keluar',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
            backgroundColor: AppColors.textPrimary.withValues(alpha: 0.85),
          ),
        );
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentTab),
            child: _screens[currentTab],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: AppShadows.bottomNav,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  // Iconsax Bold — solid duotone-ish fintech vibe.
                  // (Note: package v1.0.0 belum punya Bulk; Bold adalah variant
                  //  paling solid yang tersedia. Visual masih jauh lebih premium
                  //  dari Material flat.)
                  // Active state monochrome primary, inactive monochrome neutral.
                  // Eksepsi semantic system per rule 22 §C.8.
                  _NavItem(index: 0, icon: IconsaxPlusBold.home_2, label: 'Beranda'),
                  _NavItem(index: 1, icon: IconsaxPlusBold.task_square, label: 'Riwayat'),
                  _NavItem(index: 2, icon: IconsaxPlusBold.note_2, label: 'Izin'),
                  _NavItem(index: 3, icon: IconsaxPlusBold.notification, label: 'Notifikasi'),
                  _NavItem(index: 4, icon: IconsaxPlusBold.user, label: 'Profil'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(currentTabProvider) == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ref.read(currentTabProvider.notifier).setTab(index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? AppColors.primary : AppColors.textTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? AppColors.primary : AppColors.textTertiary,
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
