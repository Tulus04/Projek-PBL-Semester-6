// lib/features/leave_requests/data/leave_models.dart
// Model data untuk fitur pengajuan izin/sakit (leave_requests).
// Mapping dari endpoint POST /api/mobile/leave-requests/submit dan GET /api/mobile/leave-requests/my.

/// Tipe pengajuan: izin (urusan keluarga, dll) atau sakit (medis)
enum LeaveType {
  izin,
  sakit;

  String get apiValue => name; // 'izin' atau 'sakit'

  String get label {
    switch (this) {
      case LeaveType.izin:
        return 'Izin';
      case LeaveType.sakit:
        return 'Sakit';
    }
  }
}

/// Status pengajuan setelah dikirim
enum LeaveStatus {
  pending,
  approved,
  rejected,
  unknown;

  static LeaveStatus fromString(String? value) {
    switch (value) {
      case 'pending':
        return LeaveStatus.pending;
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      default:
        return LeaveStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case LeaveStatus.pending:
        return 'Menunggu Review';
      case LeaveStatus.approved:
        return 'Disetujui';
      case LeaveStatus.rejected:
        return 'Ditolak';
      case LeaveStatus.unknown:
        return '-';
    }
  }
}

/// Body untuk POST /api/mobile/leave-requests/submit
class SubmitLeaveRequest {
  final String sessionId;
  final LeaveType type;
  final String reason;
  final String? evidenceUrl;

  const SubmitLeaveRequest({
    required this.sessionId,
    required this.type,
    required this.reason,
    this.evidenceUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'type': type.apiValue,
      'reason': reason,
      if (evidenceUrl != null && evidenceUrl!.isNotEmpty)
        'evidence_url': evidenceUrl,
    };
  }
}

/// Response dari POST /api/mobile/leave-requests/submit
class SubmitLeaveResponse {
  final String id;
  final LeaveStatus status;
  final String message;
  final String createdAt;

  const SubmitLeaveResponse({
    required this.id,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory SubmitLeaveResponse.fromJson(Map<String, dynamic> json) {
    return SubmitLeaveResponse(
      id: json['id'] as String? ?? '',
      status: LeaveStatus.fromString(json['status'] as String?),
      message: json['message'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// Info sesi yang di-embed dalam item leave request
class LeaveRequestSession {
  final String id;
  final int sessionNumber;
  final String? topic;
  final String? startedAt;
  final String courseCode;
  final String courseName;

  const LeaveRequestSession({
    required this.id,
    required this.sessionNumber,
    this.topic,
    this.startedAt,
    required this.courseCode,
    required this.courseName,
  });

  factory LeaveRequestSession.fromJson(Map<String, dynamic> json) {
    return LeaveRequestSession(
      id: json['id'] as String? ?? '',
      sessionNumber: json['session_number'] as int? ?? 0,
      topic: json['topic'] as String?,
      startedAt: json['started_at'] as String?,
      courseCode: json['course_code'] as String? ?? '-',
      courseName: json['course_name'] as String? ?? '-',
    );
  }

  /// Label singkat: "Pertemuan 3 — Basis Data"
  String get displayLabel => 'Pertemuan $sessionNumber — $courseName';
}

/// Satu item pengajuan izin
class LeaveRequestItem {
  final String id;
  final LeaveType type;
  final String reason;
  final String? evidenceUrl;
  final LeaveStatus status;
  final String? reviewNote;
  final String createdAt;
  final String? reviewedAt;
  final LeaveRequestSession? session;

  const LeaveRequestItem({
    required this.id,
    required this.type,
    required this.reason,
    this.evidenceUrl,
    required this.status,
    this.reviewNote,
    required this.createdAt,
    this.reviewedAt,
    this.session,
  });

  factory LeaveRequestItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'izin';
    final type = typeStr == 'sakit' ? LeaveType.sakit : LeaveType.izin;

    final sessionJson = json['session'] as Map<String, dynamic>?;

    return LeaveRequestItem(
      id: json['id'] as String,
      type: type,
      reason: json['reason'] as String? ?? '',
      evidenceUrl: json['evidence_url'] as String?,
      status: LeaveStatus.fromString(json['status'] as String?),
      reviewNote: json['review_note'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      reviewedAt: json['reviewed_at'] as String?,
      session: sessionJson != null
          ? LeaveRequestSession.fromJson(sessionJson)
          : null,
    );
  }

  /// Waktu relatif: "Baru saja", "5 menit lalu", dst.
  String get timeAgo {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d/$m/${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }
}

/// Ringkasan jumlah per status
class LeaveSummary {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  const LeaveSummary({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  factory LeaveSummary.fromJson(Map<String, dynamic> json) {
    return LeaveSummary(
      total: json['total'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      approved: json['approved'] as int? ?? 0,
      rejected: json['rejected'] as int? ?? 0,
    );
  }

  static const empty = LeaveSummary(total: 0, pending: 0, approved: 0, rejected: 0);
}

/// Response lengkap dari GET /api/mobile/leave-requests/my
class MyLeaveRequestsResponse {
  final List<LeaveRequestItem> requests;
  final LeaveSummary summary;

  const MyLeaveRequestsResponse({
    required this.requests,
    required this.summary,
  });

  factory MyLeaveRequestsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['requests'] as List<dynamic>? ?? [];
    return MyLeaveRequestsResponse(
      requests: list
          .map((e) => LeaveRequestItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: LeaveSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
