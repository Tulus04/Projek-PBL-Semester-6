// lib/features/history/data/attendance_status_style.dart
// Helper status presensi terpusat (DRY): prioritas status dominan, mapping
// warna/ikon/label, serta grouping record per tanggal lokal.
// Logika ini di-reuse oleh Beranda (week strip + agenda) dan tab Riwayat
// (kalender bulan penuh) agar tidak ada duplikasi. Sinkron dengan token
// warna AppColors (rule 22-mobile-design-system).

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import 'history_models.dart';

// ============================================================================
// Status priority — pilih status dominan untuk tinted background day cell.
// Order: alpa (paling buruk, prioritas tertinggi) → telat → izin/sakit → hadir.
// ============================================================================

int statusPriority(String status) {
  switch (status) {
    case 'alpa':
      return 4;
    case 'terlambat':
      return 3;
    case 'izin':
    case 'sakit':
      return 2;
    case 'hadir':
      return 1;
    default:
      return 0;
  }
}

String dominantStatus(List<AttendanceRecord> records) {
  if (records.isEmpty) return '';
  return records.reduce(
    (a, b) => statusPriority(a.status) >= statusPriority(b.status) ? a : b,
  ).status;
}

// ============================================================================
// Color helpers (sinkron dengan history_screen.dart status mapping).
// ============================================================================

Color statusFg(String status) {
  switch (status) {
    case 'hadir':
      return AppColors.success;
    case 'terlambat':
      return AppColors.info;
    case 'izin':
    case 'sakit':
      return AppColors.warning;
    case 'alpa':
      return AppColors.danger;
    default:
      return AppColors.textSecondary;
  }
}

Color statusTint(String status) {
  switch (status) {
    case 'hadir':
      return AppColors.successTint;
    case 'terlambat':
      return AppColors.infoTint;
    case 'izin':
    case 'sakit':
      return AppColors.warningTint;
    case 'alpa':
      return AppColors.dangerTint;
    default:
      return AppColors.surfaceSunken;
  }
}

IconData statusIcon(String status) {
  switch (status) {
    case 'hadir':
      return IconsaxPlusBold.tick_circle;
    case 'terlambat':
      return IconsaxPlusBold.clock;
    case 'izin':
      return IconsaxPlusBold.note_2;
    case 'sakit':
      return IconsaxPlusBold.health;
    case 'alpa':
      return IconsaxPlusBold.close_circle;
    default:
      return IconsaxPlusBold.clock;
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'hadir':
      return 'HADIR';
    case 'terlambat':
      return 'TELAT';
    case 'izin':
      return 'IZIN';
    case 'sakit':
      return 'SAKIT';
    case 'alpa':
      return 'ALPA';
    default:
      return status.toUpperCase();
  }
}

// ============================================================================
// Algoritma — group records by local-date key
// ============================================================================

/// Key untuk peta per-tanggal: pakai DateTime UTC midnight tanggal lokal,
/// supaya gampang dibandingkan dengan `isSameDay` dari table_calendar.
DateTime dateKey(DateTime localDt) =>
    DateTime.utc(localDt.year, localDt.month, localDt.day);

/// Group records berdasarkan tanggal LOKAL `scannedAt` —
/// menghasilkan map `<tanggal, list record>`.
Map<DateTime, List<AttendanceRecord>> groupByLocalDate(
  List<AttendanceRecord> records,
) {
  final result = <DateTime, List<AttendanceRecord>>{};
  for (final r in records) {
    DateTime dt;
    try {
      dt = DateTime.parse(r.scannedAt).toLocal();
    } catch (_) {
      continue;
    }
    final key = dateKey(dt);
    (result[key] ??= <AttendanceRecord>[]).add(r);
  }
  return result;
}
