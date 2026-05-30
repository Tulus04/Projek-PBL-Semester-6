// lib/features/attendance/data/attendance_models.dart
// Model data untuk fitur presensi — sesi aktif, request submit, response submit.
// Digunakan oleh AttendanceRepository dan provider.

/// Model sesi aktif dari GET /api/mobile/sessions/active
///
/// Catatan: model ini juga di-reuse oleh response
/// GET /api/mobile/sessions/eligible-for-leave (lihat [EligibleSessionsResponse]).
/// Endpoint eligible-for-leave TIDAK return field `mode`, `location_lat`,
/// `location_lng`, `radius_meters`, `already_submitted` — semuanya akan default
/// ke nilai aman (offline / 0 / 150 / false) yang tidak dipakai di flow izin.
/// Field [dosenName] hanya terisi dari endpoint eligible-for-leave; di
/// /sessions/active akan null karena backend tidak return.
class ActiveSession {
  final String id;
  final String courseCode;
  final String courseName;
  final int sessionNumber;
  final String? topic;
  final String mode; // 'offline' atau 'online'
  final double locationLat;
  final double locationLng;
  final int radiusMeters;
  final String startedAt;
  final bool alreadySubmitted;
  final String? dosenName;

  const ActiveSession({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.sessionNumber,
    this.topic,
    required this.mode,
    required this.locationLat,
    required this.locationLng,
    required this.radiusMeters,
    required this.startedAt,
    required this.alreadySubmitted,
    this.dosenName,
  });

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      id: json['id'] as String,
      courseCode: json['course_code'] as String? ?? '-',
      courseName: json['course_name'] as String? ?? '-',
      sessionNumber: json['session_number'] as int? ?? 0,
      topic: json['topic'] as String?,
      mode: json['mode'] as String? ?? 'offline',
      locationLat: (json['location_lat'] as num?)?.toDouble() ?? 0.0,
      locationLng: (json['location_lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: json['radius_meters'] as int? ?? 150,
      startedAt: json['started_at'] as String? ?? '',
      alreadySubmitted: json['already_submitted'] as bool? ?? false,
      dosenName: json['dosen_name'] as String?,
    );
  }

  /// Label singkat untuk display: "Pertemuan 3 — Basis Data"
  String get displayLabel => 'Pertemuan $sessionNumber — $courseName';
}

/// Data yang dikirim ke POST /api/mobile/attendance/submit
class AttendanceSubmitRequest {
  final String sessionId;
  final String sessionCode;
  final double latitude;
  final double longitude;
  final bool isMockLocation;
  final String? deviceModel;
  final String? deviceOs;
  final String? wifiSsid;
  // Face recognition fields (opsional, belum diimplementasi)
  final double? faceConfidence;
  final bool? isFaceMatched;
  final bool? isLivenessPassed;

  const AttendanceSubmitRequest({
    required this.sessionId,
    required this.sessionCode,
    required this.latitude,
    required this.longitude,
    this.isMockLocation = false,
    this.deviceModel,
    this.deviceOs,
    this.wifiSsid,
    this.faceConfidence,
    this.isFaceMatched,
    this.isLivenessPassed,
  });

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'session_code': sessionCode,
      'latitude': latitude,
      'longitude': longitude,
      'is_mock_location': isMockLocation,
      if (deviceModel != null) 'device_model': deviceModel,
      if (deviceOs != null) 'device_os': deviceOs,
      if (wifiSsid != null) 'wifi_ssid': wifiSsid,
      if (faceConfidence != null) 'face_confidence': faceConfidence,
      if (isFaceMatched != null) 'is_face_matched': isFaceMatched,
      if (isLivenessPassed != null) 'is_liveness_passed': isLivenessPassed,
    };
  }
}

/// Response dari POST /api/mobile/attendance/submit
class AttendanceSubmitResponse {
  final String status;
  final int distanceMeters;
  final bool isLocationValid;
  final String scannedAt;
  final String message;

  const AttendanceSubmitResponse({
    required this.status,
    required this.distanceMeters,
    required this.isLocationValid,
    required this.scannedAt,
    required this.message,
  });

  factory AttendanceSubmitResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceSubmitResponse(
      status: json['status'] as String? ?? 'hadir',
      distanceMeters: json['distance_meters'] as int? ?? 0,
      isLocationValid: json['is_location_valid'] as bool? ?? false,
      scannedAt: json['scanned_at'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

/// Data yang di-decode dari QR code
class QrCodeData {
  final String sessionId;
  final String sessionCode;

  const QrCodeData({
    required this.sessionId,
    required this.sessionCode,
  });

  /// Parse JSON dari QR code via Map.
  ///
  /// Format yang didukung (key alias diterima):
  /// - `{ "sid": "...", "code": "..." }` — format aktif (dipakai dashboard web).
  /// - `{ "session_id": "...", "session_code": "..." }` — format legacy.
  /// - `{ "session_id": "...", "code": "..." }` — format campuran (kompat balik).
  ///
  /// Caller WAJIB `jsonDecode` dulu — lihat `parseQrCode` di `AttendanceSubmitNotifier`.
  factory QrCodeData.fromMap(Map<String, dynamic> map) {
    // Terima alias 'sid' (format aktif web) maupun 'session_id' (legacy)
    final sessionId = (map['sid'] ?? map['session_id']) as String?;
    // Terima alias 'code' maupun 'session_code'
    final code = (map['code'] ?? map['session_code']) as String?;

    if (sessionId == null || sessionId.isEmpty) {
      throw const FormatException('QR tidak valid');
    }
    if (code == null || code.isEmpty) {
      throw const FormatException('QR tidak valid');
    }

    return QrCodeData(sessionId: sessionId, sessionCode: code);
  }
}

/// Exception khusus saat submit attendance — membawa `errorCode` dari server
/// agar UI bisa distinguish kasus tertentu (mis. face_not_registered → dialog redirect,
/// face_mismatch → dialog retry).
///
/// Server return `{ error: string, error_code?: string }` di body untuk error 4xx.
/// errorCode null = error generik tanpa special handling.
class AttendanceSubmitException implements Exception {
  final String message;
  final String? errorCode;
  final int? statusCode;

  const AttendanceSubmitException(this.message, {this.errorCode, this.statusCode});

  @override
  String toString() => message;
}

/// Response wrapper untuk GET /api/mobile/sessions/eligible-for-leave.
///
/// Dipakai oleh wizard "Ajukan Izin" step 1 (Pilih Sesi) untuk menampilkan
/// dua group: sesi yang sedang berlangsung ([activeSessions]) dan sesi yang
/// sudah lewat tapi belum di-handle dalam 7 hari terakhir ([recentSessions]).
///
/// Backend menjamin item di kedua list belum punya attendance `hadir` maupun
/// leave_request `pending/approved` — UI tidak perlu re-filter.
class EligibleSessionsResponse {
  final List<ActiveSession> activeSessions;
  final List<ActiveSession> recentSessions;

  const EligibleSessionsResponse({
    required this.activeSessions,
    required this.recentSessions,
  });

  factory EligibleSessionsResponse.fromJson(Map<String, dynamic> json) {
    final active = (json['active_sessions'] as List<dynamic>? ?? const [])
        .map((e) => ActiveSession.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final recent = (json['recent_sessions'] as List<dynamic>? ?? const [])
        .map((e) => ActiveSession.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return EligibleSessionsResponse(
      activeSessions: active,
      recentSessions: recent,
    );
  }

  /// Helper: gabungan kedua list (untuk total count atau check non-empty).
  List<ActiveSession> get all => [...activeSessions, ...recentSessions];

  /// True jika kedua list kosong — UI menampilkan empty state "Tidak ada sesi
  /// yang bisa diajukan izin saat ini."
  bool get isEmpty => activeSessions.isEmpty && recentSessions.isEmpty;
}
