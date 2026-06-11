'use server'
// app/lib/actions/recent-activity.ts
// Server action untuk Recent Activity Feed widget di dashboard.
// Source: tabel audit_logs (sudah ada untuk forensic/security tracking).
// Format human-readable: ambil 15 entry terbaru + JOIN profiles untuk nama user.

import { createAdminClient } from '@/lib/supabase/server'
import { requireRole } from '@/lib/auth-guard'

// ==========================================
// TIPE DATA
// ==========================================

export interface ActivityItem {
  id: string
  action: string                     // raw action name (snake_case)
  actionLabel: string                // label Bahasa Indonesia
  actionIcon: ActivityIconType       // icon variant
  actorName: string                  // nama user yang melakukan, "Sistem" kalau null
  actorRole: string | null           // 'admin' | 'dosen' | 'mahasiswa' | null
  description: string                // 1-line ringkas Bahasa Indonesia
  createdAt: string                  // ISO timestamp
  /** Tier visual: positif (success), negatif (danger), netral (default), warning. */
  tier: 'success' | 'danger' | 'warning' | 'info' | 'neutral'
}

export type ActivityIconType =
  | 'login' | 'logout'
  | 'session' | 'attendance'
  | 'face' | 'leave'
  | 'user' | 'security'
  | 'settings' | 'export'
  | 'default'

// ==========================================
// HELPER FORMATTING
// ==========================================

interface ActionConfig {
  label: string
  icon: ActivityIconType
  tier: ActivityItem['tier']
  /** Optional formatter untuk description berdasarkan details JSON. */
  describe?: (details: Record<string, unknown> | null, actorName: string) => string
}

/** Mapping action name → metadata UI. Snake_case sesuai konvensi audit. */
const ACTION_MAP: Record<string, ActionConfig> = {
  // Auth
  login: { label: 'Login', icon: 'login', tier: 'info' },
  mobile_login: { label: 'Login Mobile', icon: 'login', tier: 'info' },
  logout: { label: 'Logout', icon: 'logout', tier: 'neutral' },
  failed_login: { label: 'Login Gagal', icon: 'security', tier: 'warning' },
  // Sesi
  create_session: {
    label: 'Buat Sesi', icon: 'session', tier: 'info',
    describe: (d, name) => `${name} membuat sesi baru${d?.course_name ? ` di ${d.course_name}` : ''}`,
  },
  start_session: {
    label: 'Mulai Sesi', icon: 'session', tier: 'success',
    describe: (d, name) => `${name} memulai sesi${d?.course_name ? ` ${d.course_name}` : ''}`,
  },
  end_session: {
    label: 'Akhiri Sesi', icon: 'session', tier: 'neutral',
    describe: (d, name) => `${name} mengakhiri sesi${d?.course_name ? ` ${d.course_name}` : ''}`,
  },
  refresh_session_code: { label: 'Refresh Kode', icon: 'session', tier: 'info' },
  // Attendance
  mobile_attendance_submit: {
    label: 'Submit Presensi', icon: 'attendance', tier: 'success',
    describe: (d, name) => `${name} melakukan presensi${d?.status ? ` (${d.status})` : ''}`,
  },
  mock_location_detected: {
    label: 'Mock GPS Terdeteksi', icon: 'security', tier: 'danger',
    describe: (_, name) => `${name} terdeteksi memakai mock GPS — presensi ditolak`,
  },
  qr_gate_passed: {
    label: 'Pemindaian QR', icon: 'attendance', tier: 'info',
    describe: (_, name) => `${name} berhasil memindai kode QR`,
  },
  // Face
  mobile_face_verify: {
    label: 'Verifikasi Wajah', icon: 'face', tier: 'info',
    describe: (_, name) => `${name} berhasil melakukan verifikasi wajah`,
  },
  mobile_face_register: {
    label: 'Daftar Wajah', icon: 'face', tier: 'success',
    describe: (_, name) => `${name} mendaftarkan data wajah`,
  },
  mobile_face_delete: {
    label: 'Hapus Data Wajah', icon: 'face', tier: 'warning',
    describe: (_, name) => `${name} menghapus data wajah terdaftar`,
  },
  // Leave
  mobile_leave_request_submit: {
    label: 'Ajukan Izin', icon: 'leave', tier: 'info',
    describe: (d, name) => `${name} mengajukan ${d?.type ?? 'izin'}`,
  },
  approve_leave_request: { label: 'Setujui Izin', icon: 'leave', tier: 'success' },
  reject_leave_request: { label: 'Tolak Izin', icon: 'leave', tier: 'warning' },
  // User mgmt
  create_student: { label: 'Tambah Mahasiswa', icon: 'user', tier: 'info' },
  update_student: { label: 'Edit Mahasiswa', icon: 'user', tier: 'info' },
  delete_student: { label: 'Hapus Mahasiswa', icon: 'user', tier: 'warning' },
  reset_student_password: { label: 'Reset Password Mhs', icon: 'security', tier: 'warning' },
  import_students_csv: {
    label: 'Import CSV', icon: 'user', tier: 'info',
    describe: (d, name) => `${name} import ${d?.count ?? '?'} mahasiswa via CSV`,
  },
  create_dosen: { label: 'Tambah Dosen', icon: 'user', tier: 'info' },
  update_dosen: { label: 'Edit Dosen', icon: 'user', tier: 'info' },
  delete_dosen: { label: 'Hapus Dosen', icon: 'user', tier: 'warning' },
  // Settings
  update_settings: { label: 'Update Pengaturan', icon: 'settings', tier: 'info' },
  // Export
  export_attendance: { label: 'Export Rekap', icon: 'export', tier: 'info' },
  // Password
  mobile_change_password: { label: 'Ganti Password', icon: 'security', tier: 'info' },
}

function getActionConfig(action: string): ActionConfig {
  return ACTION_MAP[action] ?? {
    label: action.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
    icon: 'default',
    tier: 'neutral',
  }
}

// ==========================================
// SERVER ACTION
// ==========================================

/**
 * Ambil 15 audit log terbaru, format ke ActivityItem siap render.
 * Auth: admin only (audit log = info sensitif sistem).
 */
export async function getRecentActivity(limit = 15): Promise<ActivityItem[]> {
  await requireRole(['admin'])

  const adminClient = createAdminClient()

  const { data, error } = await adminClient
    .from('audit_logs')
    .select(`
      id, action, details, created_at,
      user:profiles!user_id(full_name, role)
    `)
    .order('created_at', { ascending: false })
    .limit(limit)

  if (error) {
    console.error('[getRecentActivity] error:', error.message)
    return []
  }

  return (data ?? []).map(row => {
    const config = getActionConfig(row.action)
    const userRaw = row.user as unknown as { full_name: string; role: string } | null
    const actorName = userRaw?.full_name ?? 'Sistem'
    const actorRole = userRaw?.role ?? null

    const description = config.describe
      ? config.describe(row.details as Record<string, unknown> | null, actorName)
      : `${actorName} ${config.label.toLowerCase()}`

    return {
      id: row.id,
      action: row.action,
      actionLabel: config.label,
      actionIcon: config.icon,
      actorName,
      actorRole,
      description,
      createdAt: row.created_at ?? new Date().toISOString(),
      tier: config.tier,
    }
  })
}
