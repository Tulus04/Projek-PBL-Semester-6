// lib/features/history/screens/history_calendar_view.dart
// Calendar heatmap view untuk tab Riwayat (rule 22-mobile-design-system §B-C).
// Toggle dari list view via _HistoryViewMode di history_screen.dart.
//
// Behavior:
//   1. Group attendance + leave records per tanggal (key: yyyy-MM-dd lokal).
//   2. Render TableCalendar dengan custom day cell builder.
//   3. Setiap tanggal dengan record → background tinted sesuai status terburuk
//      (alpa > telat > izin/sakit > hadir), tambah max 3 dot marker di bawah
//      angka tanggal kalau hari itu punya >1 sesi.
//   4. Tap tanggal → buka bottom sheet "Aktivitas tanggal X" — list semua
//      record di hari itu, reuse status pill design system.
//   5. Range: Jan 2026 (semester ini) → bulan saat ini + 1 (forward buffer).
//   6. Default focused: hari ini.
//
// Library: table_calendar ^3.1.3 (approved 22 Mei 2026 per rule 03 §B).

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/attendance_status_style.dart';
import '../data/history_models.dart';

// ============================================================================
// Bahasa Indonesia helpers (duplikat ringan dari history_screen.dart agar
// view ini bisa stand-alone tanpa cross-import privat).
// ============================================================================

const List<String> _idMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

const List<String> _idWeekdaysShort = ['Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mg'];

const List<String> _idWeekdaysFull = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
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
// HistoryCalendarView — main widget
// ============================================================================

class HistoryCalendarView extends StatefulWidget {
  const HistoryCalendarView({super.key, required this.records});

  final List<AttendanceRecord> records;

  @override
  State<HistoryCalendarView> createState() => _HistoryCalendarViewState();
}

class _HistoryCalendarViewState extends State<HistoryCalendarView> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  // Range — Januari 2026 (semester genap 2025/2026) hingga bulan saat ini + 1.
  static final DateTime _firstDay = DateTime.utc(2026, 1, 1);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime.utc(now.year, now.month, now.day);
  }

  DateTime get _lastDay {
    final now = DateTime.now();
    // Bulan saat ini + 1 (untuk forward buffer kalau ada acara minggu depan)
    return DateTime.utc(now.year, now.month + 1, 0); // last day of current month
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupByLocalDate(widget.records);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            borderRadius: 16,
            child: TableCalendar<AttendanceRecord>(
              firstDay: _firstDay,
              lastDay: _lastDay,
              focusedDay: _focusedDay,
              currentDay: DateTime.now(),
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarFormat: CalendarFormat.month,
              availableGestures: AvailableGestures.horizontalSwipe,
              eventLoader: (day) => grouped[dateKey(day)] ?? const [],
              selectedDayPredicate: (day) {
                if (_selectedDay == null) return false;
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
                final dayRecords = grouped[dateKey(selected)] ?? const [];
                if (dayRecords.isNotEmpty) {
                  _showDayDetailSheet(context, selected, dayRecords);
                }
              },
              onPageChanged: (focused) {
                _focusedDay = focused;
              },
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                leftChevronIcon: const Icon(
                  IconsaxPlusBold.arrow_left_2,
                  color: AppColors.primary,
                  size: 20,
                ),
                rightChevronIcon: const Icon(
                  IconsaxPlusBold.arrow_right_3,
                  color: AppColors.primary,
                  size: 20,
                ),
                titleTextStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
                titleTextFormatter: (date, _) =>
                    '${_idMonths[date.month - 1]} ${date.year}',
                headerPadding: const EdgeInsets.symmetric(vertical: 4),
                headerMargin: const EdgeInsets.only(bottom: 8),
              ),
              daysOfWeekHeight: 24,
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                weekendStyle: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                cellMargin: EdgeInsets.all(2),
                cellPadding: EdgeInsets.zero,
              ),
              rowHeight: 46,
              calendarBuilders: CalendarBuilders<AttendanceRecord>(
                dowBuilder: (context, day) {
                  // table_calendar weekday: Sn=1 ... Mg=7. Index sama.
                  final label = _idWeekdaysShort[day.weekday - 1];
                  return Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
                defaultBuilder: (context, day, focusedDay) {
                  final records = grouped[dateKey(day)] ?? const [];
                  return _DayCell(day: day, records: records, isToday: false, isSelected: false);
                },
                todayBuilder: (context, day, focusedDay) {
                  final records = grouped[dateKey(day)] ?? const [];
                  return _DayCell(day: day, records: records, isToday: true, isSelected: false);
                },
                selectedBuilder: (context, day, focusedDay) {
                  final records = grouped[dateKey(day)] ?? const [];
                  return _DayCell(
                    day: day,
                    records: records,
                    isToday: isSameDay(day, DateTime.now()),
                    isSelected: true,
                  );
                },
                markerBuilder: (context, day, events) =>
                    const SizedBox.shrink(), // disable default marker — custom di _DayCell
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Legend status
          const _CalendarLegend(),
        ],
      ),
    );
  }

  void _showDayDetailSheet(
    BuildContext context,
    DateTime day,
    List<AttendanceRecord> records,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.primaryDeep.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (sheetCtx) => _DayDetailSheet(day: day, records: records),
    );
  }
}

// ============================================================================
// _DayCell — render satu tanggal di kalender
// ============================================================================

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.records,
    required this.isToday,
    required this.isSelected,
  });

  final DateTime day;
  final List<AttendanceRecord> records;
  final bool isToday;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final dominant = dominantStatus(records);
    final hasRecord = records.isNotEmpty;

    Color? bgColor;
    Color textColor = AppColors.textPrimary;
    BoxBorder? border;
    List<BoxShadow>? shadow;

    if (isSelected) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
      shadow = AppShadows.button;
    } else if (hasRecord) {
      bgColor = statusTint(dominant);
      textColor = statusFg(dominant);
    }

    if (isToday && !isSelected) {
      border = Border.all(color: AppColors.primary, width: 1.5);
    }

    // Build dot markers (max 3) — warna per status individual record
    final dots = records.take(3).toList(growable: false);

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: border,
        boxShadow: shadow,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: hasRecord || isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 13,
                color: textColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (dots.isNotEmpty)
            Positioned(
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < dots.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.85)
                            : statusFg(dots[i].status),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// _CalendarLegend — keterangan warna di bawah kalender
// ============================================================================

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
    );
  }
}

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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _DayDetailSheet — bottom sheet "Aktivitas tanggal X"
// ============================================================================

class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({required this.day, required this.records});

  final DateTime day;
  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_idWeekdaysFull[day.weekday - 1]}, ${day.day} ${_idMonths[day.month - 1]} ${day.year}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Text(
              dateStr,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${records.length} sesi tercatat',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // List record
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _DayDetailItem(record: records[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetailItem extends StatelessWidget {
  const _DayDetailItem({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final fg = statusFg(record.status);
    final tint = statusTint(record.status);
    final time = _formatTimeOnly(record.scannedAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Leading icon box
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon(record.status), color: fg, size: 20),
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
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      IconsaxPlusBold.clock,
                      size: 11,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pertemuan ${record.sessionNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
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
