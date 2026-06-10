// lib/features/history/providers/history_provider.dart
// Riverpod providers untuk fitur riwayat kehadiran.
// FutureProvider auto-dispose — data di-refresh setiap kali tab dibuka.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/history_models.dart';
import '../data/history_repository.dart';

// Repository provider
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository();
});

final historyProvider = FutureProvider.autoDispose<HistoryResponse>((
  ref,
) async {
  final repo = ref.read(historyRepositoryProvider);
  
  List<AttendanceRecord> remoteHistory = [];
  AttendanceSummary remoteSummary = const AttendanceSummary(
    totalSessions: 0,
    hadir: 0,
    terlambat: 0,
    izin: 0,
    sakit: 0,
    alpa: 0,
    percentage: 0.0,
  );

  try {
    final response = await repo.getHistory();
    remoteHistory = response.history;
    remoteSummary = response.summary;
  } catch (e) {
    // Log error and fallback gracefully
  }

  // -- INJECT DUMMY DATA UNTUK DEMO --
  final now = DateTime.now();
  final todayLocal = DateTime(now.year, now.month, now.day);
  
  final dummy1 = AttendanceRecord(
    id: 'dummy1',
    sessionNumber: 1,
    courseCode: 'DUMMY1',
    courseName: 'Matkul Pagi (Dummy)',
    status: 'hadir',
    scannedAt: todayLocal.add(const Duration(hours: 8)).toUtc().toIso8601String(),
  );
  final dummy2 = AttendanceRecord(
    id: 'dummy2',
    sessionNumber: 2,
    courseCode: 'DUMMY2',
    courseName: 'Matkul Siang (Dummy)',
    status: 'alpa',
    scannedAt: todayLocal.add(const Duration(hours: 13)).toUtc().toIso8601String(),
  );
  final dummy3 = AttendanceRecord(
    id: 'dummy3',
    sessionNumber: 3,
    courseCode: 'DUMMY3',
    courseName: 'Matkul Sore (Dummy)',
    status: 'sakit',
    scannedAt: todayLocal.subtract(const Duration(days: 1)).add(const Duration(hours: 9)).toUtc().toIso8601String(),
  );
  final dummy4 = AttendanceRecord(
    id: 'dummy4',
    sessionNumber: 4,
    courseCode: 'DUMMY4',
    courseName: 'Matkul Malam (Dummy)',
    status: 'izin',
    scannedAt: todayLocal.subtract(const Duration(days: 2)).add(const Duration(hours: 10)).toUtc().toIso8601String(),
  );
  final dummy5 = AttendanceRecord(
    id: 'dummy5',
    sessionNumber: 5,
    courseCode: 'DUMMY5',
    courseName: 'Matkul Ekstra (Dummy)',
    status: 'terlambat',
    scannedAt: todayLocal.subtract(const Duration(days: 3)).add(const Duration(hours: 11)).toUtc().toIso8601String(),
  );

  final newTotal = remoteSummary.totalSessions + 5;
  final newHadir = remoteSummary.hadir + 1;
  final newAlpa = remoteSummary.alpa + 1;
  final newSakit = remoteSummary.sakit + 1;
  final newIzin = remoteSummary.izin + 1;
  final newTerlambat = remoteSummary.terlambat + 1;
  
  final newPercentage = newTotal > 0
      ? ((newHadir + newTerlambat) / newTotal) * 100
      : 0.0;

  return HistoryResponse(
    summary: AttendanceSummary(
      totalSessions: newTotal,
      hadir: newHadir,
      terlambat: newTerlambat,
      izin: newIzin,
      sakit: newSakit,
      alpa: newAlpa,
      percentage: newPercentage,
    ),
    history: [dummy1, dummy2, dummy3, dummy4, dummy5, ...remoteHistory],
  );
});
