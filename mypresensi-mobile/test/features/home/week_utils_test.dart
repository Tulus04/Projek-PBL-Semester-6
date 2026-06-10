// test/features/home/week_utils_test.dart
// Property-based tests untuk fungsi pure week_utils.dart.
// Coverage: weekStart idempoten & Senin, addWeeks round-trip, clampWeekStart bounds,
// daysOfWeek length & consecutive.

import 'package:flutter_test/flutter_test.dart';
import 'package:mypresensi_mobile/features/home/data/week_utils.dart';

void main() {
  group('weekStart — Property 3: idempoten & selalu Senin', () {
    test('weekStart mengembalikan Senin (weekday == 1)', () {
      // Test semua hari dalam seminggu
      for (var day = 1; day <= 7; day++) {
        final date = DateTime(2026, 6, day); // Jun 1 = Minggu, Jun 2 = Senin...
        final ws = weekStart(date);
        expect(ws.weekday, 1, reason: 'weekStart($date) harus Senin, got weekday=${ws.weekday}');
      }
    });

    test('weekStart idempoten: weekStart(weekStart(d)) == weekStart(d)', () {
      // 100 hari berurutan
      for (var i = 0; i < 100; i++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: i));
        final ws1 = weekStart(date);
        final ws2 = weekStart(ws1);
        expect(ws1, ws2, reason: 'idempoten gagal untuk $date');
      }
    });

    test('weekStart mengembalikan midnight lokal (jam 0)', () {
      final date = DateTime(2026, 6, 5, 14, 30, 25);
      final ws = weekStart(date);
      expect(ws.hour, 0);
      expect(ws.minute, 0);
      expect(ws.second, 0);
    });
  });

  group('addWeeks — Property 4: navigasi konsisten', () {
    test('addWeeks(ws, 1) maju 7 hari', () {
      final ws = DateTime(2026, 6, 1); // Senin
      final next = addWeeks(ws, 1);
      expect(next.difference(ws).inDays, 7);
    });

    test('addWeeks(ws, -1) mundur 7 hari', () {
      final ws = DateTime(2026, 6, 9); // Senin
      final prev = addWeeks(ws, -1);
      expect(ws.difference(prev).inDays, 7);
    });

    test('round-trip: addWeeks(addWeeks(ws, n), -n) == ws', () {
      final ws = DateTime(2026, 6, 2);
      for (var n = -10; n <= 10; n++) {
        final roundTrip = addWeeks(addWeeks(ws, n), -n);
        expect(roundTrip, ws, reason: 'round-trip gagal untuk delta=$n');
      }
    });

    test('addWeeks(ws, 0) == ws', () {
      final ws = DateTime(2026, 6, 2);
      expect(addWeeks(ws, 0), ws);
    });
  });

  group('clampWeekStart — batas min/max', () {
    final min = DateTime(2026, 1, 5); // Senin pertama Jan 2026
    final max = DateTime(2026, 12, 28); // Senin terakhir Des 2026

    test('ws di antara min & max → kembalikan ws', () {
      final ws = DateTime(2026, 6, 2);
      expect(clampWeekStart(ws, min: min, max: max), ws);
    });

    test('ws sebelum min → kembalikan min', () {
      final ws = DateTime(2025, 12, 29);
      expect(clampWeekStart(ws, min: min, max: max), min);
    });

    test('ws setelah max → kembalikan max', () {
      final ws = DateTime(2027, 1, 5);
      expect(clampWeekStart(ws, min: min, max: max), max);
    });

    test('ws == min → kembalikan min', () {
      expect(clampWeekStart(min, min: min, max: max), min);
    });

    test('ws == max → kembalikan max', () {
      expect(clampWeekStart(max, min: min, max: max), max);
    });
  });

  group('daysOfWeek — Property 6: hari terpilih dalam minggu aktif', () {
    test('daysOfWeek mengembalikan 7 tanggal', () {
      final ws = DateTime(2026, 6, 1); // Senin
      final days = daysOfWeek(ws);
      expect(days.length, 7);
    });

    test('hari pertama = weekStart (Senin), terakhir = Minggu', () {
      final ws = DateTime(2026, 6, 1); // Senin
      final days = daysOfWeek(ws);
      expect(days.first.weekday, 1); // Senin
      expect(days.last.weekday, 7); // Minggu
    });

    test('7 hari berurutan, naik 1 per elemen', () {
      final ws = DateTime(2026, 6, 2);
      final days = daysOfWeek(ws);
      for (var i = 1; i < days.length; i++) {
        final diff = days[i].difference(days[i - 1]).inDays;
        expect(diff, 1, reason: 'hari ke-$i harus +1 dari hari ke-${i - 1}');
      }
    });

    test('semua hari midnight lokal', () {
      final ws = DateTime(2026, 6, 2);
      for (final day in daysOfWeek(ws)) {
        expect(day.hour, 0);
        expect(day.minute, 0);
        expect(day.second, 0);
      }
    });

    test('100 minggu berbeda — selalu 7 hari, selalu Senin-Minggu', () {
      for (var i = 0; i < 100; i++) {
        final base = DateTime(2026, 1, 5).add(Duration(days: i * 7)); // Senin bergeser
        final ws = weekStart(base);
        final days = daysOfWeek(ws);
        expect(days.length, 7, reason: 'minggu $i harus 7 hari');
        expect(days.first.weekday, 1, reason: 'minggu $i hari pertama harus Senin');
        expect(days.last.weekday, 7, reason: 'minggu $i hari terakhir harus Minggu');
      }
    });
  });
}
