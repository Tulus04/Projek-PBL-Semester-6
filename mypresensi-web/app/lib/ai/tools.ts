// app/lib/ai/tools.ts
// Server-side data tools untuk AI Chatbot MyPresensi.
// SECURITY: Semua query pakai service role setelah auth/role check di Route Handler.
// Jangan return token, embedding wajah, password, atau data sensitif Tier 1.

import { createAdminClient } from '@/lib/supabase/server'

export type WebAiRole = 'admin' | 'dosen'

interface WebToolContext {
  userId: string
  role: WebAiRole
}

interface MobileToolContext {
  userId: string
}

function formatPct(value: number) {
  return Number.isFinite(value) ? `${value.toFixed(1)}%` : '0,0%'
}

export async function checkAiRateLimit(userId: string, endpoint: string) {
  const supabase = createAdminClient()
  const windowStart = new Date(Date.now() - 60_000).toISOString()

  const { count } = await supabase
    .from('rate_limit_log')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('endpoint', endpoint)
    .gte('requested_at', windowStart)

  if ((count ?? 0) >= 10) {
    return {
      allowed: false,
      message: 'Terlalu banyak pertanyaan dalam 1 menit. Tunggu sebentar lalu coba lagi.',
    }
  }

  await supabase.from('rate_limit_log').insert({ user_id: userId, endpoint })
  return { allowed: true, message: null }
}

export async function buildWebAiContext({ userId, role }: WebToolContext) {
  const [atRisk, pendingLeaves, trend, courses] = await Promise.all([
    listAtRiskStudents({ userId, role }),
    countPendingLeaves({ userId, role }),
    getAttendanceTrend({ userId, role, days: 30 }),
    getCourseStats({ userId, role }),
  ])

  return [
    'KONTEKS DATA DASHBOARD (hasil query server-side):',
    atRisk,
    pendingLeaves,
    trend,
    courses,
  ].join('\n\n')
}

export async function buildMobileAiContext({ userId }: MobileToolContext) {
  const [summary, courses, leaves, risk] = await Promise.all([
    getMyAttendanceSummary(userId),
    getMyCourses(userId),
    getMyLeaveRequests(userId),
    checkMyAtRiskStatus(userId),
  ])

  return [
    'KONTEKS DATA MAHASISWA LOGIN (hasil query server-side):',
    summary,
    courses,
    leaves,
    risk,
    getFeatureHelpReference(),
  ].join('\n\n')
}

async function listAtRiskStudents({ userId, role }: WebToolContext) {
  const supabase = createAdminClient()
  const dosenId = role === 'dosen' ? userId : null

  const { data, error } = await supabase.rpc('get_at_risk_students', {
    p_threshold_pct: 70,
    p_window_days: 30,
    p_min_sessions: 3,
    p_dosen_id: dosenId,
  })

  if (error) return `Tool list_at_risk_students gagal: ${error.message}`

  const rows = (data ?? []) as Array<{
    full_name: string
    nim_nip: string
    kelas: string | null
    expected_sessions: number
    attended_sessions: number
    attendance_pct: number | string
  }>

  if (rows.length === 0) return 'Tool list_at_risk_students: tidak ada mahasiswa berisiko saat ini.'

  return [
    `Tool list_at_risk_students: ${rows.length} mahasiswa berisiko.`,
    ...rows.slice(0, 10).map((row, index) => {
      const pct = Number(row.attendance_pct)
      const tier = pct < 50 ? 'KRITIS' : 'PERHATIAN'
      return `${index + 1}. ${row.full_name} (${row.nim_nip}, kelas ${row.kelas ?? '-'}) — ${formatPct(pct)} (${row.attended_sessions}/${row.expected_sessions}) — ${tier}`
    }),
  ].join('\n')
}

async function countPendingLeaves({ userId, role }: WebToolContext) {
  const supabase = createAdminClient()
  let query = supabase
    .from('leave_requests')
    .select('id, type, reason, student:profiles!student_id(full_name, nim_nip), session:sessions!session_id(dosen_id, course:courses(code, name))', { count: 'exact' })
    .eq('status', 'pending')
    .order('created_at', { ascending: false })
    .limit(5)

  if (role === 'dosen') {
    query = query.eq('session.dosen_id', userId)
  }

  const { data, count, error } = await query
  if (error) return `Tool count_pending_leaves gagal: ${error.message}`

  const items = (data ?? []) as unknown as Array<{
    type: string
    reason: string | null
    student: { full_name: string; nim_nip: string } | null
    session: { course: { code: string; name: string } | null } | null
  }>

  return [
    `Tool count_pending_leaves: ${count ?? 0} pengajuan izin/sakit menunggu approval.`,
    ...items.map((item, index) => `${index + 1}. ${item.student?.full_name ?? 'Mahasiswa'} (${item.student?.nim_nip ?? '-'}) — ${item.type} — ${item.session?.course?.code ?? '-'} ${item.session?.course?.name ?? ''} — alasan: ${item.reason ?? '-'}`),
  ].join('\n')
}

async function getAttendanceTrend({ userId, role, days }: WebToolContext & { days: number }) {
  const supabase = createAdminClient()
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString()

  let query = supabase
    .from('attendances')
    .select('status, session:sessions!inner(dosen_id, course:courses(code, name))')
    .gte('scanned_at', since)

  if (role === 'dosen') {
    query = query.eq('session.dosen_id', userId)
  }

  const { data, error } = await query
  if (error) return `Tool get_attendance_trend gagal: ${error.message}`

  const counts: Record<string, number> = { hadir: 0, terlambat: 0, izin: 0, sakit: 0, alpa: 0 }
  for (const row of data ?? []) {
    const status = (row as { status: string }).status
    counts[status] = (counts[status] ?? 0) + 1
  }

  const total = Object.values(counts).reduce((sum, value) => sum + value, 0)
  const positive = counts.hadir + counts.terlambat
  const pct = total > 0 ? (positive / total) * 100 : 0

  return `Tool get_attendance_trend: ${total} catatan presensi dalam ${days} hari terakhir. Hadir/terlambat: ${positive} (${formatPct(pct)}), alpa: ${counts.alpa}, izin: ${counts.izin}, sakit: ${counts.sakit}.`
}

async function getCourseStats({ userId, role }: WebToolContext) {
  const supabase = createAdminClient()
  let courseQuery = supabase
    .from('courses')
    .select('id, code, name, dosen_id, enrollments(id), sessions(id)')
    .eq('is_active', true)
    .order('code')
    .limit(8)

  if (role === 'dosen') {
    courseQuery = courseQuery.eq('dosen_id', userId)
  }

  const { data, error } = await courseQuery
  if (error) return `Tool get_course_stats gagal: ${error.message}`

  const rows = (data ?? []) as unknown as Array<{
    code: string
    name: string
    enrollments: unknown[] | null
    sessions: unknown[] | null
  }>

  if (rows.length === 0) return 'Tool get_course_stats: belum ada mata kuliah aktif.'

  return [
    `Tool get_course_stats: ${rows.length} mata kuliah aktif.`,
    ...rows.map((course) => `${course.code} — ${course.name}: ${course.enrollments?.length ?? 0} mahasiswa, ${course.sessions?.length ?? 0} sesi`),
  ].join('\n')
}

async function getMyAttendanceSummary(userId: string) {
  const supabase = createAdminClient()

  const { data, error } = await supabase
    .from('attendances')
    .select('status, scanned_at, session:sessions(course:courses(code, name))')
    .eq('student_id', userId)
    .order('scanned_at', { ascending: false })
    .limit(100)

  if (error) return `Tool get_my_attendance_summary gagal: ${error.message}`

  const rows = (data ?? []) as Array<{ status: string; scanned_at: string | null }>
  const counts: Record<string, number> = { hadir: 0, terlambat: 0, izin: 0, sakit: 0, alpa: 0 }
  for (const row of rows) counts[row.status] = (counts[row.status] ?? 0) + 1

  const total = rows.length
  const positive = counts.hadir + counts.terlambat
  const pct = total > 0 ? (positive / total) * 100 : 0

  return `Tool get_my_attendance_summary: total ${total} presensi. Hadir/terlambat: ${positive} (${formatPct(pct)}), alpa: ${counts.alpa}, izin: ${counts.izin}, sakit: ${counts.sakit}.`
}

async function getMyCourses(userId: string) {
  const supabase = createAdminClient()
  const { data, error } = await supabase
    .from('enrollments')
    .select('academic_year, course:courses(code, name, semester, dosen:profiles!dosen_id(full_name))')
    .eq('student_id', userId)
    .order('academic_year', { ascending: false })

  if (error) return `Tool get_my_courses gagal: ${error.message}`

  const rows = (data ?? []) as unknown as Array<{
    academic_year: string
    course: { code: string; name: string; semester: number; dosen: { full_name: string } | null } | null
  }>

  if (rows.length === 0) return 'Tool get_my_courses: Anda belum terdaftar di mata kuliah mana pun.'

  return [
    `Tool get_my_courses: ${rows.length} mata kuliah terdaftar.`,
    ...rows.map((row) => `${row.course?.code ?? '-'} — ${row.course?.name ?? '-'} (Semester ${row.course?.semester ?? '-'}, dosen ${row.course?.dosen?.full_name ?? '-'})`),
  ].join('\n')
}

async function getMyLeaveRequests(userId: string) {
  const supabase = createAdminClient()
  const { data, error } = await supabase
    .from('leave_requests')
    .select('type, reason, status, created_at, session:sessions(topic, course:courses(code, name))')
    .eq('student_id', userId)
    .order('created_at', { ascending: false })
    .limit(5)

  if (error) return `Tool get_my_leave_requests gagal: ${error.message}`

  const rows = (data ?? []) as unknown as Array<{
    type: string
    reason: string | null
    status: string
    created_at: string
    session: { topic: string | null; course: { code: string; name: string } | null } | null
  }>

  if (rows.length === 0) return 'Tool get_my_leave_requests: belum ada pengajuan izin/sakit.'

  return [
    `Tool get_my_leave_requests: ${rows.length} pengajuan terbaru.`,
    ...rows.map((row, index) => `${index + 1}. ${row.type} — ${row.status} — ${row.session?.course?.code ?? '-'} ${row.session?.course?.name ?? ''} — alasan: ${row.reason ?? '-'}`),
  ].join('\n')
}

async function checkMyAtRiskStatus(userId: string) {
  const supabase = createAdminClient()
  const { data: profile } = await supabase
    .from('profiles')
    .select('full_name, nim_nip')
    .eq('id', userId)
    .single()

  const { data, error } = await supabase.rpc('get_at_risk_students', {
    p_threshold_pct: 70,
    p_window_days: 30,
    p_min_sessions: 3,
    p_dosen_id: null,
  })

  if (error) return `Tool check_my_at_risk_status gagal: ${error.message}`

  const rows = (data ?? []) as Array<{ nim_nip: string; attendance_pct: number | string; expected_sessions: number; attended_sessions: number }>
  const mine = rows.find((row) => row.nim_nip === profile?.nim_nip)

  if (!mine) return 'Tool check_my_at_risk_status: Anda tidak termasuk mahasiswa berisiko saat ini.'

  const pct = Number(mine.attendance_pct)
  const tier = pct < 50 ? 'KRITIS' : 'PERHATIAN'
  return `Tool check_my_at_risk_status: Anda termasuk at-risk tier ${tier}. Kehadiran ${formatPct(pct)} (${mine.attended_sessions}/${mine.expected_sessions} sesi). Target aman minimal 70%.`
}

function getFeatureHelpReference() {
  return `Tool explain_feature reference:
- qr_scan: Buka tab Scan, arahkan kamera ke QR dosen, pastikan sesi masih aktif.
- face_register: Daftarkan wajah di Profil, gunakan cahaya cukup, lepas masker/kacamata gelap, ikuti instruksi pose.
- leave_request: Buka menu Izin/Sakit, pilih sesi, isi alasan jelas, kirim, lalu tunggu approval dosen/admin.
- mock_gps: Sistem menolak fake GPS. Matikan aplikasi fake GPS dan developer mock location.
- password_reset: Hubungi admin prodi untuk reset password. Setelah reset, login dan ganti password baru.
- attendance_status: hadir/terlambat dihitung positif; izin/sakit butuh approval; alpa berarti tidak hadir.
- geofence: Untuk sesi offline, lokasi harus dalam radius kampus/sesi yang ditentukan dosen.`
}
