// lib/core/network/api_endpoints.dart
// Semua endpoint path untuk API mobile — sentralisasi untuk menghindari typo

class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/api/mobile/auth/login';
  static const String changePassword = '/api/mobile/auth/change-password';

  // Profile
  static const String profile = '/api/mobile/profile';
  static const String profileAvatar = '/api/mobile/profile/avatar';

  // Sessions
  static const String activeSessions = '/api/mobile/sessions/active';
  static const String sessionsEligibleForLeave = '/api/mobile/sessions/eligible-for-leave';

  // Attendance
  static const String submitAttendance = '/api/mobile/attendance/submit';
  static const String attendanceHistory = '/api/mobile/attendance/history';

  // Notifications
  static const String notifications = '/api/mobile/notifications';

  // Leave Requests (izin/sakit)
  static const String leaveRequestSubmit = '/api/mobile/leave-requests/submit';
  static const String leaveRequestsMy = '/api/mobile/leave-requests/my';
  static const String leaveRequestUpload = '/api/mobile/leave-requests/upload-evidence';

  // Settings (read-only) — dinamis dari tabel `settings` web admin
  static const String faceConfig = '/api/mobile/settings/face-config';

  // Face — hapus data biometrik milik mahasiswa sendiri (UU PDP hak hapus)
  static const String faceMine = '/api/mobile/face/me';

  // Face — verifikasi wajah server-side (POST live embedding, server compare).
  // Mengganti pendekatan lama yang download stored embedding ke client.
  static const String faceVerify = '/api/mobile/face/verify';

  // AI Assistant
  static const String aiChat = '/api/mobile/ai/chat';
}
