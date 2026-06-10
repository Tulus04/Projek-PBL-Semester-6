// lib/features/home/widgets/week_strip_bar.dart
// Week strip horizontal Beranda — 7 day cells (Sn–Mg) dengan status tint,
// navigasi prev/next week, dan label bulan. Reuse attendance_status_style
// helpers dan homeCalendarProvider.
// Library lock: kustom widget, BUKAN table_calendar (yang hanya di tab Riwayat).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../history/data/attendance_status_style.dart';
import '../../history/data/history_models.dart';
import '../data/week_utils.dart';
import '../providers/home_calendar_provider.dart';

// ============================================================================
// Bahasa Indonesia — label pendek hari
// ============================================================================

const List<String> _idWeekdaysShort = ['Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mg'];

const List<String> _idMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

// ============================================================================
// WeekStripBar — main widget
// ============================================================================

class WeekStripBar extends ConsumerWidget {
  const WeekStripBar({super.key, required this.groupedRecords});

  /// Attendance records sudah di-group per tanggal (dari groupByLocalDate).
  final Map<DateTime, List<AttendanceRecord>> groupedRecords;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calState = ref.watch(homeCalendarProvider);
    final notifier = ref.read(homeCalendarProvider.notifier);
    final days = daysOfWeek(calState.selectedWeekStart);

    // Label bulan: "Jun 2026" — ambil dari Senin minggu ini
    final ws = calState.selectedWeekStart;
    final monthLabel = '${_idMonths[ws.month - 1]} ${ws.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: ← bulan tahun →
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
          child: Row(
            children: [
              // Tombol mundur
              _NavChevron(
                icon: IconsaxPlusBold.arrow_left_3,
                enabled: notifier.canGoBack,
                onTap: () => notifier.shiftWeek(-1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tombol maju
              _NavChevron(
                icon: IconsaxPlusBold.arrow_right_3,
                enabled: notifier.canGoForward,
                onTap: () => notifier.shiftWeek(1),
              ),
            ],
          ),
        ),

        // 7 day cells
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _DayCell(
                  day: days[i],
                  label: _idWeekdaysShort[i],
                  records: groupedRecords[dateKey(days[i])] ?? const [],
                  isSelected: _isSameDay(days[i], calState.selectedDay),
                  isToday: _isSameDay(days[i], DateTime.now()),
                  onTap: () {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    if (days[i].isAfter(today)) return;
                    notifier.selectDay(days[i]);
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// _NavChevron — tombol navigasi minggu (kiri/kanan)
// ============================================================================

class _NavChevron extends StatelessWidget {
  const _NavChevron({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled ? AppColors.surface : AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(10),
            boxShadow: enabled ? AppShadows.card : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _DayCell — satu sel hari di strip (label hari + tanggal + status tint)
// ============================================================================

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.label,
    required this.records,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final String label;
  final List<AttendanceRecord> records;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasRecord = records.isNotEmpty;
    final dominant = hasRecord ? dominantStatus(records) : '';

    // Warna
    Color bgColor;
    Color dayTextColor;
    Color dateTextColor;
    List<BoxShadow>? shadow;

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final isFuture = day.isAfter(todayNormalized);

    if (isFuture) {
      bgColor = AppColors.surface;
      dayTextColor = AppColors.textTertiary.withValues(alpha: 0.5);
      dateTextColor = AppColors.textTertiary.withValues(alpha: 0.5);
      shadow = null;
    } else if (isSelected) {
      bgColor = AppColors.primary;
      dayTextColor = Colors.white.withValues(alpha: 0.85);
      dateTextColor = Colors.white;
      shadow = AppShadows.button;
    } else if (hasRecord) {
      bgColor = statusTint(dominant);
      dayTextColor = statusFg(dominant).withValues(alpha: 0.70);
      dateTextColor = statusFg(dominant);
    } else {
      bgColor = AppColors.surface;
      dayTextColor = AppColors.textTertiary;
      dateTextColor = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
          boxShadow: shadow ?? (hasRecord ? null : AppShadows.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label hari (Sn, Sl, ...)
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: dayTextColor,
              ),
            ),
            const SizedBox(height: 4),
            // Tanggal
            Text(
              '${day.day}',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 15,
                fontWeight: isSelected || isToday || hasRecord
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: dateTextColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            // Dot indicator (max 3)
            if (hasRecord) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < records.take(3).length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.85)
                            : statusFg(records[i].status),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Helper — compare tanggal saja (tanpa jam)
// ============================================================================

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
