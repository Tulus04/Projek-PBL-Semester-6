// lib/features/notifications/screens/notification_screen.dart
// Halaman notifikasi v7 — sesuai mockup mobile-notifications.html (17 Mei 2026).
// Layout: 2 tab (Semua / Belum Dibaca) → list duotone item dengan unread indicator.
// Empty state copy natural: "Belum ada kabar baru".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../data/notification_models.dart';
import '../providers/notification_provider.dart';

/// Filter state — 2 tab: Semua / Belum Dibaca.
final _notifFilterProvider =
    NotifierProvider<_NotifFilterNotifier, _NotifFilter>(_NotifFilterNotifier.new);

class _NotifFilterNotifier extends Notifier<_NotifFilter> {
  @override
  _NotifFilter build() => _NotifFilter.all;

  void set(_NotifFilter v) => state = v;
}

enum _NotifFilter { all, unread }

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: notifAsync.maybeWhen(
          data: (data) => _AppBarTitle(unreadCount: data.unreadCount),
          orElse: () => const _AppBarTitle(unreadCount: 0),
        ),
      ),
      body: notifAsync.when(
        data: (data) => _buildContent(context, ref, data),
        loading: () => const ListLoadingPlaceholder(itemCount: 5),
        error: (error, _) => ErrorState(
          title: 'Gagal memuat notifikasi',
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(notificationProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    NotificationResponse data,
  ) {
    final activeFilter = ref.watch(_notifFilterProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(notificationProvider),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Tab filter
          SliverToBoxAdapter(
            child: _NotifTabBar(
              unreadCount: data.unreadCount,
              activeFilter: activeFilter,
              onChanged: (f) => ref.read(_notifFilterProvider.notifier).set(f),
            ),
          ),

          // Apply filter
          ...(() {
            final filtered = activeFilter == _NotifFilter.unread
                ? data.notifications.where((n) => !n.isRead).toList()
                : data.notifications;

            if (filtered.isEmpty) {
              return [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmpty(activeFilter),
                ),
              ];
            }

            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _NotifCard(notif: filtered[index]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
            ];
          })(),
        ],
      ),
    );
  }

  Widget _buildEmpty(_NotifFilter filter) {
    final (title, desc, icon) = filter == _NotifFilter.unread
        ? (
            'Semua sudah kamu baca',
            'Notifikasi baru akan muncul di sini saat ada update.',
            IconsaxPlusBold.tick_circle,
          )
        : (
            'Belum ada kabar baru',
            'Saat dosen membuka sesi, izinmu disetujui, atau ada pengingat penting, semuanya akan tampil di sini.',
            IconsaxPlusBold.notification_bing,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Empty illustration circle
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Sub-widgets
// ============================================================================

/// AppBar title — "Notifikasi" + subtitle count belum dibaca.
class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.unreadCount});
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Notifikasi',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        if (unreadCount > 0) ...[
          const SizedBox(height: 2),
          Text(
            '$unreadCount belum dibaca',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Semua sudah dibaca',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tab bar 2-tab: Semua / Belum Dibaca dengan badge count.
class _NotifTabBar extends StatelessWidget {
  const _NotifTabBar({
    required this.unreadCount,
    required this.activeFilter,
    required this.onChanged,
  });

  final int unreadCount;
  final _NotifFilter activeFilter;
  final ValueChanged<_NotifFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          _TabItem(
            label: 'Semua',
            active: activeFilter == _NotifFilter.all,
            onTap: () => onChanged(_NotifFilter.all),
          ),
          _TabItem(
            label: 'Belum Dibaca',
            badgeCount: unreadCount,
            active: activeFilter == _NotifFilter.unread,
            onTap: () => onChanged(_NotifFilter.unread),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? AppColors.primary : AppColors.textTertiary,
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (active)
                Positioned(
                  bottom: -1,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(999)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card item notifikasi — duotone icon + title + body + meta + unread dot.
class _NotifCard extends ConsumerStatefulWidget {
  const _NotifCard({required this.notif});
  final AppNotification notif;

  @override
  ConsumerState<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends ConsumerState<_NotifCard> {
  late bool _isRead;

  @override
  void initState() {
    super.initState();
    _isRead = widget.notif.isRead;
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !_isRead;
    final (iconColor, iconBg, icon) = _resolveTypeStyle(widget.notif.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isUnread) {
            // Optimistic update: langsung matikan titik biru
            setState(() {
              _isRead = true;
            });
            // Jalankan API call di background (fire & forget)
            ref.read(notificationRepositoryProvider).markAsRead(widget.notif.id);
          }

          if (widget.notif.title.contains('Sesi Presensi Dimulai')) {
            _showSessionBottomSheet(context);
            return;
          }

          if (widget.notif.href != null && widget.notif.href!.isNotEmpty) {
            if (widget.notif.href!.startsWith('/izin?id=')) {
              final id = widget.notif.href!.split('id=')[1];
              context.push('/leave-request/detail?id=$id');
            } else {
              context.push(widget.notif.href!);
            }
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
        // Tint background sangat halus untuk unread
        gradient: isUnread
            ? const LinearGradient(
                colors: [AppColors.primarySurface, AppColors.surface],
              )
            : null,
      ),
      padding: EdgeInsets.fromLTRB(isUnread ? 16 : 14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread dot kiri (kalau unread)
          if (isUnread)
            Container(
              margin: const EdgeInsets.only(top: 4, right: 8),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          // Type icon (duotone)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.notif.title,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.notif.message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Meta tag — clock + timeAgo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        IconsaxPlusBold.clock,
                        size: 11,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        widget.notif.timeAgo,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }

  void _showSessionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.warningTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(IconsaxPlusBold.clock, size: 32, color: AppColors.warning),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sesi Presensi Dimulai',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.notif.message,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.pop();
                    context.push('/scan');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Scan QR Sekarang',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Nanti Saja',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Resolve style berdasarkan type field dari server: info/success/warning/error.
  (Color iconColor, Color iconBg, IconData icon) _resolveTypeStyle(String type) {
    switch (type) {
      case 'success':
        return (
          AppColors.success,
          AppColors.successTint,
          IconsaxPlusBold.tick_circle,
        );
      case 'warning':
        return (
          AppColors.warning,
          AppColors.warningTint,
          IconsaxPlusBold.warning_2,
        );
      case 'error':
        return (
          AppColors.danger,
          AppColors.dangerTint,
          IconsaxPlusBold.danger,
        );
      case 'info':
      default:
        return (
          AppColors.primary,
          AppColors.primarySurface,
          IconsaxPlusBold.notification_bing,
        );
    }
  }
}
