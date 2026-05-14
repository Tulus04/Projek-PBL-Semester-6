// src/types/database.ts
// Tipe data yang mencerminkan schema database Supabase.
// Satu source of truth untuk semua data yang mengalir di aplikasi web.

export type UserRole = 'admin' | 'dosen' | 'mahasiswa'
export type AttendanceStatus = 'hadir' | 'terlambat' | 'izin' | 'sakit' | 'alpa'
export type SessionMode = 'offline' | 'online'
export type LeaveRequestStatus = 'pending' | 'approved' | 'rejected'
export type LeaveRequestType = 'izin' | 'sakit'

export interface Profile {
  id: string
  full_name: string
  nim_nip: string
  role: UserRole
  semester: number | null
  kelas: string | null
  phone: string | null
  avatar_url: string | null
  is_face_registered: boolean
  is_active: boolean
  must_change_password: boolean
  created_at: string
  updated_at: string
}

export interface Course {
  id: string
  code: string
  name: string
  sks: number
  semester: number
  dosen_id: string | null
  academic_year: string
  is_active: boolean
  created_at: string
  // Joined fields
  dosen?: Pick<Profile, 'id' | 'full_name' | 'nim_nip'>
}

export interface Enrollment {
  id: string
  course_id: string
  student_id: string
  academic_year: string
  // Joined fields
  course?: Pick<Course, 'id' | 'code' | 'name'>
  student?: Pick<Profile, 'id' | 'full_name' | 'nim_nip'>
}

export interface Session {
  id: string
  course_id: string
  dosen_id: string
  session_number: number
  topic: string | null
  mode: SessionMode
  session_code: string | null
  session_code_expires_at: string | null
  location_lat: number
  location_lng: number
  radius_meters: number
  is_active: boolean
  started_at: string
  ended_at: string | null
  created_at: string
  // Joined fields
  course?: Pick<Course, 'id' | 'code' | 'name'>
  dosen?: Pick<Profile, 'id' | 'full_name'>
}

export interface Attendance {
  id: string
  session_id: string
  student_id: string
  status: AttendanceStatus
  scanned_at: string
  student_lat: number | null
  student_lng: number | null
  distance_meters: number | null
  is_location_valid: boolean | null
  is_mock_location: boolean
  wifi_ssid: string | null
  face_confidence: number | null
  is_face_matched: boolean | null
  is_liveness_passed: boolean | null
  device_model: string | null
  device_os: string | null
  ip_address: string | null
  session_mode: string | null
  // Joined fields
  student?: Pick<Profile, 'id' | 'full_name' | 'nim_nip'>
  session?: Pick<Session, 'id' | 'session_number' | 'topic'>
}

export interface LeaveRequest {
  id: string
  student_id: string
  session_id: string
  type: LeaveRequestType
  reason: string
  evidence_url: string | null
  status: LeaveRequestStatus
  reviewed_by: string | null
  review_note: string | null
  reviewed_at: string | null
  created_at: string
  // Joined fields
  student?: Pick<Profile, 'id' | 'full_name' | 'nim_nip'>
  session?: Pick<Session, 'id' | 'session_number' | 'topic'>
  reviewer?: Pick<Profile, 'id' | 'full_name'>
}

export interface AuditLog {
  id: string
  user_id: string | null
  action: string
  details: Record<string, unknown> | null
  ip_address: string | null
  created_at: string
  // Joined fields
  user?: Pick<Profile, 'id' | 'full_name' | 'role'>
}

export interface SystemSetting {
  id: string
  key: string
  value: string
  description: string | null
  updated_at: string
}

export type NotificationType = 'info' | 'success' | 'warning' | 'danger'

export interface Notification {
  id: string
  user_id: string
  title: string
  message: string
  type: NotificationType
  href: string | null
  is_read: boolean
  created_at: string
}

// Tipe untuk response API yang konsisten
export interface ApiResponse<T> {
  data: T | null
  error: string | null
}

// Tipe untuk data di tabel (pagination)
export interface PaginatedResponse<T> {
  data: T[]
  count: number
  page: number
  pageSize: number
}
