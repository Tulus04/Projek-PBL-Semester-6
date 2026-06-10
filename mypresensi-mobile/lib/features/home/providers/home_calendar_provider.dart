// lib/features/home/providers/home_calendar_provider.dart
// State management untuk week strip + agenda Beranda.
// Menyimpan minggu terpilih dan hari terpilih — konsumen: WeekStripBar, DayAgendaList.
// Reuse historyProvider untuk data; tidak fetch ulang, hanya slice/group.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/week_utils.dart';

// ============================================================================
// State — immutable record minggu + hari terpilih
// ============================================================================

class HomeCalendarState {
  final DateTime selectedWeekStart; // Senin minggu aktif (midnight lokal)
  final DateTime selectedDay; // Hari yang di-tap (default: hari ini)

  const HomeCalendarState({
    required this.selectedWeekStart,
    required this.selectedDay,
  });

  HomeCalendarState copyWith({
    DateTime? selectedWeekStart,
    DateTime? selectedDay,
  }) {
    return HomeCalendarState(
      selectedWeekStart: selectedWeekStart ?? this.selectedWeekStart,
      selectedDay: selectedDay ?? this.selectedDay,
    );
  }
}

// ============================================================================
// Notifier — logika navigasi week strip + tap hari
// ============================================================================

class HomeCalendarNotifier extends Notifier<HomeCalendarState> {
  // Range semester: Jan 2026 -> 4 minggu ke depan.
  static final DateTime _minWeek = weekStart(DateTime(2026, 1, 1));

  DateTime get _maxWeek {
    final now = DateTime.now();
    return weekStart(DateTime(now.year, now.month, now.day));
  }

  @override
  HomeCalendarState build() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return HomeCalendarState(
      selectedWeekStart: weekStart(today),
      selectedDay: today,
    );
  }

  /// Geser minggu sebanyak [delta] minggu (+1 maju, -1 mundur).
  /// Klamping ke range kalender.
  void shiftWeek(int delta) {
    final newWeek = addWeeks(state.selectedWeekStart, delta);
    final clamped = clampWeekStart(newWeek, min: _minWeek, max: _maxWeek);
    // Pilih hari pertama minggu baru (Senin) sebagai default,
    // kecuali minggu ini mengandung hari ini → pilih hari ini.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayWeek = weekStart(today);
    final newDay = clamped == todayWeek ? today : clamped;
    state = state.copyWith(selectedWeekStart: clamped, selectedDay: newDay);
  }

  /// Tap hari tertentu di week strip.
  void selectDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    state = state.copyWith(selectedDay: normalizedDay);
  }

  /// Reset ke minggu ini + hari ini (saat pull-to-refresh).
  void resetToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    state = HomeCalendarState(
      selectedWeekStart: weekStart(today),
      selectedDay: today,
    );
  }

  /// Cek apakah bisa mundur 1 minggu.
  bool get canGoBack {
    final prev = addWeeks(state.selectedWeekStart, -1);
    return !prev.isBefore(_minWeek);
  }

  /// Cek apakah bisa maju 1 minggu.
  bool get canGoForward {
    final next = addWeeks(state.selectedWeekStart, 1);
    return !next.isAfter(_maxWeek);
  }
}

// ============================================================================
// Provider — global, non-autoDispose (state bertahan selama app hidup)
// ============================================================================

final homeCalendarProvider =
    NotifierProvider<HomeCalendarNotifier, HomeCalendarState>(
      HomeCalendarNotifier.new,
    );
