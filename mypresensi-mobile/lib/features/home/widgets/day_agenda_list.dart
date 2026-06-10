// lib/features/home/widgets/day_agenda_list.dart
// Daftar record presensi untuk hari terpilih di Beranda.
// Ditampilkan di bawah week strip — menggantikan Activity Feed.
// Reuse attendance_status_style helpers. Design: list card kompak, status pill.

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../history/data/attendance_status_style.dart';
import '../../history/data/history_models.dart';

// ============================================================================
// Bahasa Indonesia
// ============================================================================

const List<String> _idWeekdaysFull = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

const List<String> _idMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String _formatTimeOnly(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '--:--';
  }
}

// ============================================================================
// DayAgendaList — main widget
// ============================================================================

class DayAgendaList extends StatelessWidget {
  const DayAgendaList({
    super.key,
    required this.selectedDay,
    required this.records,
  });

  final DateTime selectedDay;
  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_idWeekdaysFull[selectedDay.weekday - 1]}, ${selectedDay.day} ${_idMonths[selectedDay.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (records.isNotEmpty)
                Text(
                  '${records.length} sesi',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),

        // Body: list / empty
        if (records.isEmpty)
          const _AgendaEmpty()
        else
          Column(
            children: [
              for (int i = 0; i < records.length; i++) ...[
                _AgendaItem(record: records[i]),
                if (i < records.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

// ============================================================================
// _AgendaItem — satu record presensi
// ============================================================================

class _AgendaItem extends StatelessWidget {
  const _AgendaItem({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final fg = statusFg(record.status);
    final tint = statusTint(record.status);
    final time = _formatTimeOnly(record.scannedAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Leading icon box
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon(record.status), color: fg, size: 18),
          ),
          const SizedBox(width: 12),

          // Center text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.courseName,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 1,
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
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pertemuan ${record.sessionNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel(record.status),
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _AgendaEmpty — empty state
// ============================================================================

class _AgendaEmpty extends StatelessWidget {
  const _AgendaEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              IconsaxPlusBold.calendar_2,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tidak ada presensi',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Belum ada catatan kehadiran di hari ini.',
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
