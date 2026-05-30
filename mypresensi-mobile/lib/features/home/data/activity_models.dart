// lib/features/home/data/activity_models.dart
// Model untuk Activity Feed di Beranda — gabungan attendance + leave_requests.
// Decode dari endpoint /api/mobile/activity/recent.

/// Status semantic untuk warna icon + badge di UI.
enum ActivityStatus { success, warning, danger, info }

/// Tipe sumber data activity.
enum ActivityType { attendance, leaveRequest }

class ActivityItem {
  final ActivityType type;
  final String id;
  final String title;
  final String subtitle;
  final ActivityStatus status;
  final DateTime occurredAt;

  const ActivityItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.occurredAt,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      type: _parseType(json['type'] as String?),
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: (json['subtitle'] as String?) ?? '',
      status: _parseStatus(json['status'] as String?),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
    );
  }

  static ActivityType _parseType(String? raw) {
    switch (raw) {
      case 'leave_request':
        return ActivityType.leaveRequest;
      case 'attendance':
      default:
        return ActivityType.attendance;
    }
  }

  static ActivityStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'success':
        return ActivityStatus.success;
      case 'warning':
        return ActivityStatus.warning;
      case 'danger':
        return ActivityStatus.danger;
      case 'info':
      default:
        return ActivityStatus.info;
    }
  }
}
