// lib/features/leave_requests/screens/my_leave_requests_screen.dart
// Daftar pengajuan izin/sakit milik mahasiswa.
// Header ringkasan (pending/approved/rejected) + list item dengan badge status.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../data/leave_models.dart';
import '../providers/leave_provider.dart';

class MyLeaveRequestsScreen extends ConsumerWidget {
  const MyLeaveRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myLeaveRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengajuan Saya'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<bool>('/leave-request/submit');
          if (result == true) {
            ref.invalidate(myLeaveRequestsProvider);
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Ajukan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
              // ListView wrapper agar pull-to-refresh tetap jalan saat error
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

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Summary card
        SliverToBoxAdapter(
          child: _buildSummaryCard(response.summary),
        ),

        // List
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = response.requests[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildRequestItem(item),
                );
              },
              childCount: response.requests.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(LeaveSummary summary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          _buildStatBox(
            label: 'Menunggu',
            value: summary.pending,
            color: AppColors.warning,
          ),
          _divider(),
          _buildStatBox(
            label: 'Disetujui',
            value: summary.approved,
            color: AppColors.success,
          ),
          _divider(),
          _buildStatBox(
            label: 'Ditolak',
            value: summary.rejected,
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildRequestItem(LeaveRequestItem item) {
    final session = item.session;
    final statusColor = _getStatusColor(item.status);
    final typeIcon = item.type == LeaveType.sakit
        ? Icons.healing_outlined
        : Icons.event_note_outlined;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: type icon + course + status badge
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session?.courseName ?? '(Sesi tidak ditemukan)',
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
                      session != null
                          ? 'Pertemuan ${session.sessionNumber} · ${item.type.label}'
                          : item.type.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(item.status, statusColor),
            ],
          ),

          const SizedBox(height: 12),

          // Reason
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.reason,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),

          // Review note (jika ada)
          if (item.reviewNote != null && item.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Catatan dosen: ${item.reviewNote}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Footer: timestamp
          Row(
            children: [
              Icon(
                Icons.access_time_outlined,
                size: 12,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                'Diajukan ${item.timeAgo}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(LeaveStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.pending:
        return AppColors.warning;
      case LeaveStatus.approved:
        return AppColors.success;
      case LeaveStatus.rejected:
        return AppColors.danger;
      case LeaveStatus.unknown:
        return AppColors.textTertiary;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      // ListView wrapper agar pull-to-refresh tetap jalan saat empty
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 60),
        EmptyState(
          icon: Icons.event_note_outlined,
          title: 'Belum ada pengajuan izin',
          description:
              'Pengajuan izin atau sakit Anda akan muncul di sini. Tekan tombol "Ajukan" di pojok kanan bawah untuk membuat pengajuan baru.',
        ),
      ],
    );
  }
}
