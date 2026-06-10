// lib/features/home/widgets/home_history_calendar_card.dart
// Container widget untuk riwayat kehadiran di Beranda (format kalender).
// Menangani 3-state dari historyProvider: loading skeleton, error state,
// empty state, dan loaded state.
// Integrasi ke week_strip_bar dan day_agenda_list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../history/data/attendance_status_style.dart';
import '../../history/providers/history_provider.dart';
import '../providers/home_calendar_provider.dart';
import 'day_agenda_list.dart';
import 'week_strip_bar.dart';

class HomeHistoryCalendarCard extends ConsumerWidget {
  const HomeHistoryCalendarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calState = ref.watch(homeCalendarProvider);
    final historyAsync = ref.watch(historyProvider);

    return historyAsync.when(
      loading: () => const _CalendarCardSkeleton(),
      error: (err, _) => AppCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 16,
        child: ErrorState(
          icon: IconsaxPlusBold.cloud_cross,
          title: 'Gagal memuat riwayat',
          message: friendlyErrorMessage(err),
          onRetry: () => ref.invalidate(historyProvider),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      data: (res) {
        final grouped = groupByLocalDate(res.history);
        final selectedRecords = grouped[dateKey(calState.selectedDay)] ?? const [];

        return AppCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card: Title + "Kalender penuh" button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Kehadiran',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.read(currentTabProvider.notifier).setTab(1),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Kalender penuh',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
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
              const SizedBox(height: 14),

              // Week Strip horizontal
              WeekStripBar(groupedRecords: grouped),
              const SizedBox(height: 12),

              // Status Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: const [
                    _LegendItem(color: AppColors.success, label: 'Hadir'),
                    _LegendItem(color: AppColors.info, label: 'Telat'),
                    _LegendItem(color: AppColors.warning, label: 'Izin/Sakit'),
                    _LegendItem(color: AppColors.danger, label: 'Alpa'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 14),

              // Agenda list / Empty state
              if (res.history.isEmpty)
                const EmptyState(
                  icon: IconsaxPlusBold.calendar_2,
                  title: 'Belum ada riwayat',
                  description: 'Riwayat kehadiran kelas kamu akan muncul di sini.',
                  padding: EdgeInsets.symmetric(vertical: 24),
                )
              else
                DayAgendaList(
                  selectedDay: calState.selectedDay,
                  records: selectedRecords,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// _LegendItem — Keterangan warna + dot
// ============================================================================

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _CalendarCardSkeleton — Placeholder saat loading
// ============================================================================

class _CalendarCardSkeleton extends StatelessWidget {
  const _CalendarCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card Skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              LoadingSkeleton(height: 15, width: 130),
              LoadingSkeleton(height: 12, width: 90),
            ],
          ),
          const SizedBox(height: 16),

          // Nav Header Skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              LoadingSkeleton(height: 32, width: 32, borderRadius: BorderRadius.all(Radius.circular(10))),
              LoadingSkeleton(height: 14, width: 80),
              LoadingSkeleton(height: 32, width: 32, borderRadius: BorderRadius.all(Radius.circular(10))),
            ],
          ),
          const SizedBox(height: 14),

          // Week strip skeleton — 7 cells
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                const Expanded(
                  child: LoadingSkeleton(
                    height: 52,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Legend skeleton
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    LoadingSkeleton.circle(size: 6),
                    SizedBox(width: 4),
                    LoadingSkeleton(height: 10, width: 40),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),

          // Agenda list skeleton — 1 item
          Row(
            children: [
              const LoadingSkeleton(
                height: 36,
                width: 36,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    LoadingSkeleton(height: 13, width: 140),
                    SizedBox(height: 6),
                    LoadingSkeleton(height: 11, width: 100),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const LoadingSkeleton(
                height: 18,
                width: 50,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
