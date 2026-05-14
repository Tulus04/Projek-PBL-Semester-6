'use server'
// app/lib/actions/at-risk.ts
// Server actions untuk fitur At-Risk Students Widget — deteksi mahasiswa berisiko
// dengan persentase kehadiran rendah (default <70% dalam 30 hari terakhir).
// Data berasal dari SQL function get_at_risk_students() (migration 015).
// Catatan keamanan: WAJIB requireRole sebelum panggil — admin lihat semua, dosen filter MK miliknya.

import { createAdminClient } from '@/lib/supabase/server'
import { requireRole } from '@/lib/auth-guard'

// ==========================================
// TIPE DATA
// ==========================================

export interface AtRiskStudent {
  studentId: string
  fullName: string
  nimNip: string
  kelas: string | null
  semester: number | null
  avatarUrl: string | null
  expectedSessions: number
  attendedSessions: number
  attendancePct: number
  lastAttendedAt: string | null
  // Tier dihitung di server berdasarkan threshold settings
  tier: 'critical' | 'warning'
}

export interface AtRiskSettings {
  thresholdPct: number    // default 70 — di bawah ini = at-risk
  criticalPct: number     // default 50 — di bawah ini = kritis (badge merah)
  windowDays: number      // default 30 hari
  minSessions: number     // default 3 sesi
}

export interface AtRiskSummary {
  totalCount: number          // total mhs at-risk
  criticalCount: number       // mhs di bawah criticalPct
  warningCount: number        // mhs antara criticalPct..thresholdPct
  topStudents: AtRiskStudent[]  // 3-5 mhs terburuk untuk widget dashboard
  settings: AtRiskSettings
}

// ==========================================
// HELPERS
// ==========================================

/**
 * Ambil 4 setting at-risk dari tabel settings.
 * Fallback ke default kalau setting belum ada (graceful degradation).
 */
async function getAtRiskSettings(): Promise<AtRiskSettings> {
  const adminClient = createAdminClient()

  const { data } = await adminClient
    .from('settings')
    .select('key, value')
    .in('key', ['at_risk_threshold_pct', 'at_risk_critical_pct', 'at_risk_window_days', 'at_risk_min_sessions'])

  const settingsMap = new Map((data ?? []).map(s => [s.key, s.value]))

  return {
    thresholdPct: parseFloat(settingsMap.get('at_risk_threshold_pct') ?? '70'),
    criticalPct: parseFloat(settingsMap.get('at_risk_critical_pct') ?? '50'),
    windowDays: parseInt(settingsMap.get('at_risk_window_days') ?? '30', 10),
    minSessions: parseInt(settingsMap.get('at_risk_min_sessions') ?? '3', 10),
  }
}

/**
 * Map raw row dari RPC ke AtRiskStudent dengan tier classification.
 */
function mapRowToStudent(row: RawAtRiskRow, criticalPct: number): AtRiskStudent {
  return {
    studentId: row.student_id,
    fullName: row.full_name,
    nimNip: row.nim_nip,
    kelas: row.kelas,
    semester: row.semester,
    avatarUrl: row.avatar_url,
    expectedSessions: Number(row.expected_sessions),
    attendedSessions: Number(row.attended_sessions),
    attendancePct: Number(row.attendance_pct),
    lastAttendedAt: row.last_attended_at,
    tier: Number(row.attendance_pct) < criticalPct ? 'critical' : 'warning',
  }
}

interface RawAtRiskRow {
  student_id: string
  full_name: string
  nim_nip: string
  kelas: string | null
  semester: number | null
  avatar_url: string | null
  expected_sessions: number | string
  attended_sessions: number | string
  attendance_pct: number | string
  last_attended_at: string | null
}

// ==========================================
// PUBLIC SERVER ACTIONS
// ==========================================

/**
 * Ambil ringkasan at-risk untuk widget di dashboard admin.
 * Return: total count, critical count, warning count, top 3 mhs terburuk.
 * Auth: admin only.
 */
export async function getAtRiskSummary(): Promise<AtRiskSummary> {
  await requireRole(['admin'])

  const settings = await getAtRiskSettings()
  const adminClient = createAdminClient()

  const { data, error } = await adminClient.rpc('get_at_risk_students', {
    p_threshold_pct: settings.thresholdPct,
    p_window_days: settings.windowDays,
    p_min_sessions: settings.minSessions,
    p_dosen_id: null,
  })

  if (error) {
    console.error('[getAtRiskSummary] RPC error:', error.message)
    return { totalCount: 0, criticalCount: 0, warningCount: 0, topStudents: [], settings }
  }

  const rows = (data ?? []) as RawAtRiskRow[]
  const students = rows.map(r => mapRowToStudent(r, settings.criticalPct))

  return {
    totalCount: students.length,
    criticalCount: students.filter(s => s.tier === 'critical').length,
    warningCount: students.filter(s => s.tier === 'warning').length,
    topStudents: students.slice(0, 3),
    settings,
  }
}

/**
 * Ambil full list at-risk students untuk halaman detail /dashboard/at-risk.
 * Auth: admin only (dosen variant: tunda — pass p_dosen_id nanti).
 */
export async function getAtRiskStudents(): Promise<{
  students: AtRiskStudent[]
  settings: AtRiskSettings
}> {
  await requireRole(['admin'])

  const settings = await getAtRiskSettings()
  const adminClient = createAdminClient()

  const { data, error } = await adminClient.rpc('get_at_risk_students', {
    p_threshold_pct: settings.thresholdPct,
    p_window_days: settings.windowDays,
    p_min_sessions: settings.minSessions,
    p_dosen_id: null,
  })

  if (error) {
    console.error('[getAtRiskStudents] RPC error:', error.message)
    return { students: [], settings }
  }

  const rows = (data ?? []) as RawAtRiskRow[]
  const students = rows.map(r => mapRowToStudent(r, settings.criticalPct))

  return { students, settings }
}
