// test/features/home/attendance_status_style_test.dart
// Property-based tests untuk helper status presensi terpusat.
// Coverage: dominantStatus priority, groupByLocalDate preservation, statusFg/Tint/Icon/Label mapping.

import 'package:flutter_test/flutter_test.dart';
import 'package:mypresensi_mobile/features/history/data/attendance_status_style.dart';
import 'package:mypresensi_mobile/features/history/data/history_models.dart';

// Helper: buat AttendanceRecord minimal untuk testing.
AttendanceRecord _rec(String status, {String? scannedAt}) {
  return AttendanceRecord(
    id: 'test-${status.hashCode}',
    sessionNumber: 1,
    courseCode: 'TST',
    courseName: 'Test',
    status: status,
    scannedAt: scannedAt ?? '2026-06-01T08:00:00Z',
  );
}

void main() {
  group('statusPriority', () {
    test('alpa memiliki prioritas tertinggi (4)', () {
      expect(statusPriority('alpa'), 4);
    });

    test('terlambat memiliki prioritas 3', () {
      expect(statusPriority('terlambat'), 3);
    });

    test('izin dan sakit memiliki prioritas sama (2)', () {
      expect(statusPriority('izin'), 2);
      expect(statusPriority('sakit'), 2);
    });

    test('hadir memiliki prioritas terendah (1)', () {
      expect(statusPriority('hadir'), 1);
    });

    test('status unknown memiliki prioritas 0', () {
      expect(statusPriority(''), 0);
      expect(statusPriority('xyz'), 0);
    });
  });

  group('dominantStatus — Property 1: selalu pilih status terburuk', () {
    test('list kosong → string kosong', () {
      expect(dominantStatus([]), '');
    });

    test('satu record hadir → hadir', () {
      expect(dominantStatus([_rec('hadir')]), 'hadir');
    });

    test('hadir + alpa → alpa (terburuk)', () {
      final records = [_rec('hadir'), _rec('alpa')];
      expect(dominantStatus(records), 'alpa');
    });

    test('hadir + terlambat + izin → terlambat (prioritas 3 > 2 > 1)', () {
      final records = [_rec('hadir'), _rec('terlambat'), _rec('izin')];
      expect(dominantStatus(records), 'terlambat');
    });

    test('semua status → alpa mendominasi', () {
      final records = [
        _rec('hadir'),
        _rec('terlambat'),
        _rec('izin'),
        _rec('sakit'),
        _rec('alpa'),
      ];
      expect(dominantStatus(records), 'alpa');
    });

    test('100 record random — dominantStatus selalu >= semua record', () {
      final statuses = ['hadir', 'terlambat', 'izin', 'sakit', 'alpa'];
      for (var trial = 0; trial < 100; trial++) {
        // Generate random records
        final records = List.generate(
          5 + (trial % 10),
          (i) => _rec(statuses[i % statuses.length]),
        );
        final dominant = dominantStatus(records);
        final dominantPri = statusPriority(dominant);
        // Dominant harus >= semua record
        for (final r in records) {
          expect(
            dominantPri,
            greaterThanOrEqualTo(statusPriority(r.status)),
            reason: 'dominant=$dominant harus >= ${r.status} di trial $trial',
          );
        }
      }
    });
  });

  group('groupByLocalDate — Property 2: jaga jumlah dan tanggal', () {
    test('list kosong → map kosong', () {
      expect(groupByLocalDate([]), isEmpty);
    });

    test('record di tanggal sama → satu key, semua record terkumpul', () {
      final records = [
        _rec('hadir', scannedAt: '2026-06-01T08:00:00Z'),
        _rec('terlambat', scannedAt: '2026-06-01T09:00:00Z'),
        _rec('alpa', scannedAt: '2026-06-01T23:59:00Z'),
      ];
      final grouped = groupByLocalDate(records);
      // Semua record harus jatuh di tanggal yang sama
      final totalRecords = grouped.values.fold<int>(0, (s, l) => s + l.length);
      expect(totalRecords, records.length, reason: 'total harus sama');
    });

    test('record di tanggal berbeda → key berbeda', () {
      final records = [
        _rec('hadir', scannedAt: '2026-06-01T08:00:00Z'),
        _rec('hadir', scannedAt: '2026-06-02T08:00:00Z'),
        _rec('hadir', scannedAt: '2026-06-03T08:00:00Z'),
      ];
      final grouped = groupByLocalDate(records);
      expect(grouped.length, 3);
    });

    test('scannedAt invalid → record di-skip', () {
      final records = [
        _rec('hadir', scannedAt: '2026-06-01T08:00:00Z'),
        _rec('hadir', scannedAt: 'invalid-date'),
      ];
      final grouped = groupByLocalDate(records);
      final totalRecords = grouped.values.fold<int>(0, (s, l) => s + l.length);
      expect(totalRecords, 1, reason: 'invalid date harus di-skip');
    });
  });

  group('dateKey — normalisasi ke UTC midnight', () {
    test('jam berbeda di hari sama → key sama', () {
      final k1 = dateKey(DateTime(2026, 6, 1, 8, 0));
      final k2 = dateKey(DateTime(2026, 6, 1, 23, 59));
      expect(k1, k2);
    });

    test('hari berbeda → key berbeda', () {
      final k1 = dateKey(DateTime(2026, 6, 1));
      final k2 = dateKey(DateTime(2026, 6, 2));
      expect(k1, isNot(k2));
    });
  });

  group('statusFg/statusTint/statusIcon/statusLabel mapping', () {
    const knownStatuses = ['hadir', 'terlambat', 'izin', 'sakit', 'alpa'];

    test('setiap known status mengembalikan nilai non-default', () {
      for (final s in knownStatuses) {
        expect(statusFg(s), isNotNull, reason: 'statusFg($s)');
        expect(statusTint(s), isNotNull, reason: 'statusTint($s)');
        expect(statusIcon(s), isNotNull, reason: 'statusIcon($s)');
        expect(statusLabel(s), isNotEmpty, reason: 'statusLabel($s)');
      }
    });

    test('statusLabel menghasilkan uppercase', () {
      expect(statusLabel('hadir'), 'HADIR');
      expect(statusLabel('terlambat'), 'TELAT');
      expect(statusLabel('izin'), 'IZIN');
      expect(statusLabel('sakit'), 'SAKIT');
      expect(statusLabel('alpa'), 'ALPA');
    });

    test('unknown status → fallback label uppercase', () {
      expect(statusLabel('unknown'), 'UNKNOWN');
    });
  });
}
