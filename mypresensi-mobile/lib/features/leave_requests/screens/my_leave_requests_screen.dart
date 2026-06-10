// lib/features/leave_requests/screens/my_leave_requests_screen.dart
// Riwayat Izin v7 — sesuai mockup mobile-my-leave-requests.html (17 Mei 2026).
// Layout: appbar dengan subtitle count → filter chip 4 status → list group by
// "Menunggu Review" / "Selesai" → FAB extended "Ajukan Izin".
// Tab "Izin" di bottom nav point ke screen ini.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../data/leave_models.dart';
import '../providers/leave_provider.dart';

/// Filter state — Notifier lokal screen ini (Riverpod 3 pattern).
final _filterProvider = NotifierProvider<_FilterNotifier, _LeaveFilter>(_FilterNotifier.new);

class _FilterNotifier extends Notifier<_LeaveFilter> {
  @override
  _LeaveFilter build() => _LeaveFilter.all;

  void set(_LeaveFilter v) => state = v;
}

enum _LeaveFilter { all, pending, approved, rejected }

class MyLeaveRequestsScreen extends ConsumerWidget {
  const MyLeaveRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myLeaveRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: requestsAsync.maybeWhen(
          data: (response) => _AppBarTitle(summary: response.summary),
          orElse: () => const _AppBarTitle(summary: null),
        ),
      ),
      // FAB extended "Ajukan Izin" — pattern Material You.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<bool>('/leave-request/submit');
          if (result == true) {
            ref.invalidate(myLeaveRequestsProvider);
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
          icon: const Icon(IconsaxPlusBold.add_circle, size: 20),
          label: const Text(
            'Ajukan Izin',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(myLeaveRequestsProvider);
            await ref.read(myLeaveRequestsProvider.future);
          },
          child: requestsAsync.when(
            data: (response) => _buildContent(context, ref, response),
            loading: () => const ListLoadingPlaceholder(itemCount: 4),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                ErrorState(
                  title: 'Gagal memuat pengajuan',
                  message: friendlyErrorMessage(e),
                  onRetry: () => ref.invalidate(myLeaveRequestsProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    MyLeaveRequestsResponse response,
  ) {
    if (response.requests.isEmpty) {
      return _buildEmptyState(context);
    }

    final activeFilter = ref.watch(_filterProvider);
    final filtered = _applyFilter(response.requests, activeFilter);

    // Group: pending di atas, selesai (approved+rejected) di bawah.
    final pending = filtered.where((r) => r.status == LeaveStatus.pending).toList();
    final selesai = filtered.where((r) => r.status != LeaveStatus.pending).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Filter chip row
        SliverToBoxAdapter(
          child: _FilterChipsRow(
            counts: {
              _LeaveFilter.all: response.requests.length,
              _LeaveFilter.pending: response.summary.pending,
              _LeaveFilter.approved: response.summary.approved,
              _LeaveFilter.rejected: response.summary.rejected,
            },
          ),
        ),

        // Empty state untuk filter tertentu
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildFilterEmptyState(activeFilter),
          )
        else ...[
          // Section: Menunggu Review
          if (pending.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: _SectionHeader(label: 'Menunggu Review'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LeaveItemCard(item: pending[index]),
                  ),
                  childCount: pending.length,
                ),
              ),
            ),
          ],

          // Section: Selesai
          if (selesai.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: _SectionHeader(label: 'Selesai'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LeaveItemCard(item: selesai[index]),
                  ),
                  childCount: selesai.length,
                ),
              ),
            ),
          ],
        ],

        // Bottom padding untuk FAB clearance
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  List<LeaveRequestItem> _applyFilter(
    List<LeaveRequestItem> items,
    _LeaveFilter filter,
  ) {
    return switch (filter) {
      _LeaveFilter.all => items,
      _LeaveFilter.pending =>
        items.where((r) => r.status == LeaveStatus.pending).toList(),
      _LeaveFilter.approved =>
        items.where((r) => r.status == LeaveStatus.approved).toList(),
      _LeaveFilter.rejected =>
        items.where((r) => r.status == LeaveStatus.rejected).toList(),
    };
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 80),
        // Empty illustration — circle dengan icon document-add
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              IconsaxPlusBold.document_text_1,
              size: 56,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Belum ada pengajuan izin',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Kalau kamu berhalangan hadir karena sakit atau ada urusan penting, ajukan izin di sini supaya tercatat dan bisa direview dosen.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.55,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        Center(
          child: SizedBox(
            width: 240,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/leave-request/submit'),
              icon: const Icon(IconsaxPlusBold.add_circle, size: 18),
              label: const Text('Ajukan Izin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterEmptyState(_LeaveFilter filter) {
    final (msg, icon) = switch (filter) {
      _LeaveFilter.pending => (
          'Tidak ada pengajuan menunggu',
          IconsaxPlusBold.clock,
        ),
      _LeaveFilter.approved => (
          'Belum ada pengajuan disetujui',
          IconsaxPlusBold.tick_circle,
        ),
      _LeaveFilter.rejected => (
          'Tidak ada pengajuan ditolak',
          IconsaxPlusBold.close_circle,
        ),
      _LeaveFilter.all => (
          'Tidak ada pengajuan',
          IconsaxPlusBold.document_text_1,
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 14,
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
// Sub-widgets
// ============================================================================

/// AppBar title — "Riwayat Izin" + subtitle count.
class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.summary});
  final LeaveSummary? summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Riwayat Izin',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        if (summary != null && summary!.total > 0) ...[
          const SizedBox(height: 2),
          Text(
            '${summary!.total} pengajuan${summary!.pending > 0 ? " · ${summary!.pending} menunggu" : ""}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Filter chip row — horizontal scrollable, 4 filter status.
class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow({required this.counts});
  final Map<_LeaveFilter, int> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_filterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              icon: IconsaxPlusBold.element_3,
              label: 'Semua',
              active: active == _LeaveFilter.all,
              onTap: () => ref.read(_filterProvider.notifier).set(_LeaveFilter.all),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              icon: IconsaxPlusBold.clock,
              label: 'Menunggu',
              active: active == _LeaveFilter.pending,
              onTap: () => ref.read(_filterProvider.notifier).set(_LeaveFilter.pending),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              icon: IconsaxPlusBold.tick_circle,
              label: 'Disetujui',
              active: active == _LeaveFilter.approved,
              onTap: () => ref.read(_filterProvider.notifier).set(_LeaveFilter.approved),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              icon: IconsaxPlusBold.close_circle,
              label: 'Ditolak',
              active: active == _LeaveFilter.rejected,
              onTap: () => ref.read(_filterProvider.notifier).set(_LeaveFilter.rejected),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header — uppercase label kecil.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppColors.textTertiary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Card item pengajuan — duotone icon + nama MK + meta + alasan + status pill.
class _LeaveItemCard extends StatelessWidget {
  const _LeaveItemCard({required this.item});
  final LeaveRequestItem item;

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconColor, iconData) = switch (item.status) {
      LeaveStatus.pending => (AppColors.warningTint, AppColors.warning, IconsaxPlusBold.clock),
      LeaveStatus.approved => (AppColors.successTint, AppColors.success, IconsaxPlusBold.tick_circle),
      LeaveStatus.rejected => (AppColors.dangerTint, AppColors.danger, IconsaxPlusBold.close_circle),
      LeaveStatus.unknown => (AppColors.surfaceSunken, AppColors.textTertiary, IconsaxPlusBold.minus_cirlce),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type icon (duotone)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 21),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course name
                Text(
                  item.session?.courseName ?? '(Sesi tidak ditemukan)',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Meta: pertemuan + type
                Row(
                  children: [
                    const Icon(
                      IconsaxPlusBold.calendar_1,
                      size: 11,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.session != null
                            ? 'Pertemuan ${item.session!.sessionNumber} · ${item.type.label}'
                            : item.type.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Reason (clamped 2 lines)
                Text(
                  item.reason,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Review note kalau ada (hanya rejected/approved dengan note)
                if (item.reviewNote != null && item.reviewNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(item.status).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          IconsaxPlusBold.message_text,
                          size: 11,
                          color: _statusColor(item.status),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Catatan: ${item.reviewNote}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Status row: pill + lampiran tag + timestamp
                Row(
                  children: [
                    _StatusPill(status: item.status),
                    if (item.evidenceUrl != null && item.evidenceUrl!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        IconsaxPlusBold.document_normal,
                        size: 12,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'Lampiran',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      item.timeAgo,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Color _statusColor(LeaveStatus status) => switch (status) {
        LeaveStatus.pending => AppColors.warning,
        LeaveStatus.approved => AppColors.success,
        LeaveStatus.rejected => AppColors.danger,
        LeaveStatus.unknown => AppColors.textTertiary,
      };
}

/// Pill status — duotone tint bg + solid text.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = switch (status) {
      LeaveStatus.pending => (
          AppColors.warningTint,
          AppColors.warning,
          IconsaxPlusBold.clock,
          'MENUNGGU',
        ),
      LeaveStatus.approved => (
          AppColors.successTint,
          AppColors.success,
          IconsaxPlusBold.tick_circle,
          'DISETUJUI',
        ),
      LeaveStatus.rejected => (
          AppColors.dangerTint,
          AppColors.danger,
          IconsaxPlusBold.close_circle,
          'DITOLAK',
        ),
      LeaveStatus.unknown => (
          AppColors.surfaceSunken,
          AppColors.textTertiary,
          IconsaxPlusBold.minus_cirlce,
          'STATUS?',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
