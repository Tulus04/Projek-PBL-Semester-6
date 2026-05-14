// lib/features/history/data/history_models.dart
// Model data untuk fitur riwayat kehadiran.
// Mapping dari response GET /api/mobile/attendance/history.

/// Satu record riwayat kehadiran
class AttendanceRecord {
  final String id;
  final int sessionNumber;
  final String? topic;
  final String courseCode;
  final String courseName;
  final String status; // 'hadir', 'terlambat', 'izin', 'sakit', 'alpa'
  final String scannedAt;
  final int? distanceMeters;
  final bool? isLocationValid;
  final double? faceConfidence;

  const AttendanceRecord({
    required this.id,
    required this.sessionNumber,
    this.topic,
    required this.courseCode,
    required this.courseName,
    required this.status,
    required this.scannedAt,
    this.distanceMeters,
    this.isLocationValid,
    this.faceConfidence,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      sessionNumber: json['session_number'] as int? ?? 0,
      topic: json['topic'] as String?,
      courseCode: json['course_code'] as String? ?? '-',
      courseName: json['course_name'] as String? ?? '-',
      status: json['status'] as String? ?? 'alpa',
      scannedAt: json['scanned_at'] as String? ?? '',
      distanceMeters: json['distance_meters'] as int?,
      isLocationValid: json['is_location_valid'] as bool?,
      faceConfidence: (json['face_confidence'] as num?)?.toDouble(),
    );
  }

  /// Label untuk display: "Basis Data — Pertemuan 3"
  String get displayLabel => '$courseName — Pertemuan $sessionNumber';

  /// Formatted date: "10/04/2026 14:30"
  String get formattedDate {
    try {
      final dt = DateTime.parse(scannedAt).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/${dt.year} $h:$min';
    } catch (_) {
      return scannedAt;
    }
  }
}

/// Ringkasan kehadiran keseluruhan.
/// `percentage` sudah inklusif: (hadir + terlambat) / total.
class AttendanceSummary {
  final int totalSessions;
  final int hadir;
  final int terlambat;
  final int izin;
  final int sakit;
  final int alpa;
  final double percentage;

  const AttendanceSummary({
    required this.totalSessions,
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.sakit,
    required this.alpa,
    required this.percentage,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      totalSessions: json['total_sessions'] as int? ?? 0,
      hadir: json['hadir'] as int? ?? 0,
      terlambat: json['terlambat'] as int? ?? 0,
      izin: json['izin'] as int? ?? 0,
      sakit: json['sakit'] as int? ?? 0,
      alpa: json['alpa'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Response lengkap dari API history
class HistoryResponse {
  final List<AttendanceRecord> history;
  final AttendanceSummary summary;

  const HistoryResponse({
    required this.history,
    required this.summary,
  });

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    final historyJson = json['history'] as List<dynamic>? ?? [];
    return HistoryResponse(
      history: historyJson
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: AttendanceSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
