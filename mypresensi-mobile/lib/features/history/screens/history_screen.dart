// lib/features/history/screens/history_screen.dart
// Halaman riwayat kehadiran mahasiswa — summary card + list records.
// Data dari GET /api/mobile/attendance/history, pull-to-refresh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../data/history_models.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Kehadiran')),
      body: historyAsync.when(
        data: (data) => _buildContent(context, ref, data),
        loading: () => const ListLoadingPlaceholder(itemCount: 5),
        error: (error, _) => ErrorState(
          title: 'Gagal memuat riwayat',
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(historyProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    HistoryResponse data,
  ) {
    if (data.history.isEmpty) {
      return _buildEmpty(context, ref);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(historyProvider),
      child: CustomScrollView(
        slivers: [
          // Summary card
          SliverToBoxAdapter(
            child: _buildSummaryCard(context, data.summary),
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Daftar Kehadiran',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          // List records
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final record = data.history[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildRecordCard(context, record),
                  );
                },
                childCount: data.history.length,
              ),
            ),
          ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, AttendanceSummary summary) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          // Persentase besar
          Text(
            '${summary.percentage}%',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tingkat Kehadiran',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Stats row — 5 column (Hadir / Telat / Izin / Sakit / Alpa)
          Row(
            children: [
              _buildStatItem('Hadir', summary.hadir, AppColors.success),
              _buildStatItem('Telat', summary.terlambat, AppColors.warning),
              _buildStatItem('Izin', summary.izin, AppColors.info),
              _buildStatItem('Sakit', summary.sakit, AppColors.warning),
              _buildStatItem('Alpa', summary.alpa, AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, AttendanceRecord record) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Status badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _statusColor(record.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _statusIcon(record.status),
              color: _statusColor(record.status),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.courseName,
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
                  'Pertemuan ${record.sessionNumber}${record.topic != null ? ' — ${record.topic}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  record.formattedDate,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Status label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(record.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(record.status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _statusColor(record.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    // Pakai RefreshIndicator wrapper supaya pull-to-refresh tetap berfungsi
    // walau list kosong (mahasiswa baru, belum pernah presensi).
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(historyProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icon: Icons.history_rounded,
            title: 'Belum ada riwayat kehadiran',
            description:
                'Riwayat presensi Anda akan muncul di sini setelah scan QR di sesi pertemuan.',
          ),
        ],
      ),
    );
  }

  // === Helper: status styling ===

  Color _statusColor(String status) {
    switch (status) {
      case 'hadir':
        return AppColors.success;
      case 'terlambat':
        return AppColors.warning;
      case 'izin':
        return AppColors.info;
      case 'sakit':
        return AppColors.warning;
      case 'alpa':
        return AppColors.danger;
      default:
        return AppColors.textTertiary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'hadir':
        return Icons.check_circle_outline;
      case 'terlambat':
        return Icons.schedule;
      case 'izin':
        return Icons.mail_outline;
      case 'sakit':
        return Icons.local_hospital_outlined;
      case 'alpa':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'hadir':
        return 'Hadir';
      case 'terlambat':
        return 'Terlambat';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpa':
        return 'Alpa';
      default:
        return status;
    }
  }
}
