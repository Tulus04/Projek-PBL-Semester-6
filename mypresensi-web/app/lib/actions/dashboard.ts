'use server'
// app/lib/actions/dashboard.ts
// Server-side data fetching untuk dashboard berdasarkan role.
// Memisahkan query admin (global) dan dosen (filtered by dosen_id).

import { createAdminClient, createClient } from '@/lib/supabase/server'
import { STATUS_COLORS } from '@/lib/utils'

// ==========================================
// TIPE DATA DASHBOARD
// ==========================================

export interface DashboardSummary {
  totalMataKuliah: number
  totalSesi: number
  totalHadir: number
  totalAlpa: number
  totalIzinSakit: number
  pendingLeaveRequests: number
}

export interface CourseCardData {
  id: string
  code: string
  name: string
  semester: number
  totalPeserta: number
  totalSesi: number
  sesiAktif: number
  totalHadir: number
  totalPresensi: number // hadir + terlambat + alpa + izin + sakit
}

export interface WeeklyTrendItem {
  day: string       // "Sen", "Sel", "Rab", ...
  date: string      // "07 Apr"
  hadir: number
  izin: number
  alpa: number
}

export interface AttendanceRatio {
  name: string
  value: number
  color: string
}

export interface RecentAttendance {
  id: string
  status: string
  scanned_at: string
  studentName: string
  studentNim: string
  courseName: string
  topic: string
}

export interface DosenDashboardData {
  dosenName: string
  summary: DashboardSummary
  courses: CourseCardData[]
  weeklyTrend: WeeklyTrendItem[]
  attendanceRatio: AttendanceRatio[]
  recentAttendances: RecentAttendance[]
}

// ==========================================
// HELPER TREND & TIMEZONE
// ==========================================

/** Hitung TrendData dari current & previous count. */
function computeTrend(current: number, previous: number, periodLabel: string): TrendData {
  const deltaAbs = current - previous
  let deltaPct: number | null = null
  if (previous === 0) {
    deltaPct = current > 0 ? null : 0  // null = "baru" (no baseline)
  } else {
    deltaPct = Math.round(((current - previous) / previous) * 100 * 10) / 10
  }
  return { current, previous, deltaAbs, deltaPct, periodLabel }
}

/** Hitung batas UTC awal dan akhir untuk suatu hari berdasarkan offset timezone (misal WITA = 8) */
function getDayBoundsUTC(offsetHours: number, daysAgo: number = 0) {
  const now = new Date();
  const localTime = now.getTime() + (offsetHours * 60 * 60 * 1000);
  const targetDate = new Date(localTime);
  targetDate.setUTCDate(targetDate.getUTCDate() - daysAgo);
  
  const year = targetDate.getUTCFullYear();
  const month = targetDate.getUTCMonth();
  const date = targetDate.getUTCDate();
  
  const start = new Date(Date.UTC(year, month, date, 0, 0, 0, 0));
  start.setTime(start.getTime() - (offsetHours * 60 * 60 * 1000));
  
  const end = new Date(Date.UTC(year, month, date, 23, 59, 59, 999));
  end.setTime(end.getTime() - (offsetHours * 60 * 60 * 1000));
  
  return { start: start.toISOString(), end: end.toISOString(), targetDate };
}

// ==========================================
// DATA FETCHING DOSEN
// ==========================================

export async function getDosenDashboardData(): Promise<DosenDashboardData> {
  const supabase = createClient()
  const adminClient = createAdminClient()

  // 1. Ambil user yang sedang login
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Unauthorized')

  const { data: profile } = await adminClient
    .from('profiles')
    .select('id, full_name, role')
    .eq('id', user.id)
    .single()

  if (!profile) throw new Error('Profile not found')
  const dosenId = profile.id

  // 2. Ambil mata kuliah yang diampu
  const { data: courses } = await adminClient
    .from('courses')
    .select('id, code, name, semester')
    .eq('dosen_id', dosenId)
    .eq('is_active', true)
    .order('code')

  const courseList = courses ?? []
  const courseIds = courseList.map(c => c.id)

  // Jika dosen belum punya MK, return data kosong
  if (courseIds.length === 0) {
    return {
      dosenName: profile.full_name,
      summary: { totalMataKuliah: 0, totalSesi: 0, totalHadir: 0, totalAlpa: 0, totalIzinSakit: 0, pendingLeaveRequests: 0 },
      courses: [],
      weeklyTrend: [],
      attendanceRatio: [],
      recentAttendances: [],
    }
  }

  // 3. Ambil semua sesi dari MK dosen
  const { data: sessions } = await adminClient
    .from('sessions')
    .select('id, course_id, is_active')
    .in('course_id', courseIds)

  const sessionList = sessions ?? []
  const sessionIds = sessionList.map(s => s.id)

  // 4. Ambil semua attendance dari sesi dosen
  const { data: attendances } = sessionIds.length > 0
    ? await adminClient
        .from('attendances')
        .select('id, session_id, status, scanned_at')
        .in('session_id', sessionIds)
    : { data: [] }

  const allAttendances = attendances ?? []

  // 5. Hitung enrollment per course
  const enrollmentCounts: Record<string, number> = {}
  if (courseIds.length > 0) {
    for (const cid of courseIds) {
      const { count } = await adminClient
        .from('enrollments')
        .select('*', { count: 'exact', head: true })
        .eq('course_id', cid)
      enrollmentCounts[cid] = count ?? 0
    }
  }

  // 6. Hitung pending leave requests
  let pendingLeaveRequests = 0
  if (sessionIds.length > 0) {
    const { count } = await adminClient
      .from('leave_requests')
      .select('*', { count: 'exact', head: true })
      .in('session_id', sessionIds)
      .eq('status', 'pending')
    pendingLeaveRequests = count ?? 0
  }

  // ==========================================
  // PROSES DATA
  // ==========================================

  // Summary — terlambat dihitung sebagai sub-bagian "Hadir" (inclusive)
  const totalHadir = allAttendances.filter(a => a.status === 'hadir' || a.status === 'terlambat').length
  const totalAlpa = allAttendances.filter(a => a.status === 'alpa').length
  const totalIzinSakit = allAttendances.filter(a => a.status === 'izin' || a.status === 'sakit').length

  const summary: DashboardSummary = {
    totalMataKuliah: courseList.length,
    totalSesi: sessionList.length,
    totalHadir,
    totalAlpa,
    totalIzinSakit,
    pendingLeaveRequests,
  }

  // Course cards
  const courseCards: CourseCardData[] = courseList.map(course => {
    const courseSessions = sessionList.filter(s => s.course_id === course.id)
    const courseSessionIds = courseSessions.map(s => s.id)
    const courseAttendances = allAttendances.filter(a => courseSessionIds.includes(a.session_id))

    return {
      id: course.id,
      code: course.code,
      name: course.name,
      semester: course.semester,
      totalPeserta: enrollmentCounts[course.id] ?? 0,
      totalSesi: courseSessions.length,
      sesiAktif: courseSessions.filter(s => s.is_active).length,
      // totalHadir inklusif: hadir + terlambat (per migration 013)
      totalHadir: courseAttendances.filter(a => a.status === 'hadir' || a.status === 'terlambat').length,
      totalPresensi: courseAttendances.length,
    }
  })

  // Weekly trend (7 hari terakhir) - Sesuaikan dengan WITA (UTC+8)
  const WITA_OFFSET = 8
  const dayLabels = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
  const monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des']
  const weeklyTrend: WeeklyTrendItem[] = []

  for (let i = 6; i >= 0; i--) {
    const bounds = getDayBoundsUTC(WITA_OFFSET, i)
    const dayAttendances = allAttendances.filter(a => a.scanned_at >= bounds.start && a.scanned_at <= bounds.end)

    weeklyTrend.push({
      day: dayLabels[bounds.targetDate.getUTCDay()],
      date: `${bounds.targetDate.getUTCDate().toString().padStart(2, '0')} ${monthLabels[bounds.targetDate.getUTCMonth()]}`,
      hadir: dayAttendances.filter(a => a.status === 'hadir' || a.status === 'terlambat').length,
      izin: dayAttendances.filter(a => a.status === 'izin' || a.status === 'sakit').length,
      alpa: dayAttendances.filter(a => a.status === 'alpa').length,
    })
  }

  // Attendance ratio (donut chart) — terlambat tampil terpisah untuk insight
  const totalTerlambatDosen = allAttendances.filter(a => a.status === 'terlambat').length
  const totalHadirOnTime = allAttendances.filter(a => a.status === 'hadir').length
  const attendanceRatio: AttendanceRatio[] = [
    { name: 'Hadir', value: totalHadirOnTime, color: STATUS_COLORS.hadir },
    { name: 'Terlambat', value: totalTerlambatDosen, color: STATUS_COLORS.terlambat },
    { name: 'Izin/Sakit', value: totalIzinSakit, color: STATUS_COLORS.izin },
    { name: 'Alpa', value: totalAlpa, color: STATUS_COLORS.alpa },
  ].filter(item => item.value > 0)

  // Recent attendances (8 terbaru)
  let recentAttendances: RecentAttendance[] = []
  if (sessionIds.length > 0) {
    const { data: recentData } = await adminClient
      .from('attendances')
      .select(`
        id, status, scanned_at,
        student:profiles!student_id(full_name, nim_nip),
        session:sessions!session_id(topic, course:courses!course_id(name))
      `)
      .in('session_id', sessionIds)
      .order('scanned_at', { ascending: false })
      .limit(8)

    recentAttendances = (recentData ?? []).map((att: Record<string, unknown>) => {
      const student = att.student as Record<string, string> | null
      const session = att.session as Record<string, unknown> | null
      const course = session?.course as Record<string, string> | null

      return {
        id: att.id as string,
        status: att.status as string,
        scanned_at: att.scanned_at as string,
        studentName: student?.full_name ?? '-',
        studentNim: student?.nim_nip ?? '',
        courseName: course?.name ?? '-',
        topic: (session?.topic as string) ?? '-',
      }
    })
  }

  return {
    dosenName: profile.full_name,
    summary,
    courses: courseCards,
    weeklyTrend,
    attendanceRatio,
    recentAttendances,
  }
}

// ==========================================
// TIPE DATA ADMIN DASHBOARD
// ==========================================

/** Single KPI trend dengan periode pembanding. */
export interface TrendData {
  current: number          // nilai saat ini
  previous: number         // nilai periode pembanding
  deltaAbs: number         // selisih absolut (current - previous)
  deltaPct: number | null  // persen perubahan (null jika previous=0 dan current>0 → "baru")
  periodLabel: string      // label deskripsi pembanding (mis. "vs minggu lalu")
}

/** 6 trend KPI di admin dashboard. */
export interface KpiTrends {
  totalMahasiswa: TrendData
  totalDosen: TrendData
  totalHadir: TrendData
  totalAlpa: TrendData
  totalIzin: TrendData
  pendingLeaveRequests: TrendData
}

export interface AdminDashboardData {
  totalMahasiswa: number
  totalDosen: number
  totalHadir: number
  totalAlpa: number
  totalIzin: number
  pendingLeaveRequests: number
  trends: KpiTrends
  weeklyTrend: WeeklyTrendItem[]
  attendanceRatio: AttendanceRatio[]
  courseOverview: { name: string; code: string; totalHadir: number; totalAlpa: number; totalIzin: number }[]
  recentAttendances: Record<string, unknown>[]
}



// ==========================================
// DATA FETCHING ADMIN
// ==========================================

export async function getAdminDashboardData(): Promise<AdminDashboardData> {
  const adminClient = createAdminClient()
  const WITA_OFFSET = 8

  // 1. Summary counts (current period)
  // Window pembanding untuk attendance: hari yang sama 7 hari lalu dengan batas UTC dari WITA.
  const todayBounds = getDayBoundsUTC(WITA_OFFSET, 0)
  const lastWeekBounds = getDayBoundsUTC(WITA_OFFSET, 7)
  
  // Window pembanding untuk count user: 7 hari lalu cutoff.
  const sevenDaysAgo = new Date(); sevenDaysAgo.setTime(sevenDaysAgo.getTime() - (7 * 24 * 60 * 60 * 1000))
  // Window pembanding untuk leave_requests pending: rate masuk minggu ini vs minggu lalu.
  const fourteenDaysAgo = new Date(); fourteenDaysAgo.setTime(fourteenDaysAgo.getTime() - (14 * 24 * 60 * 60 * 1000))

  // totalHadir inklusif terlambat (per migration 013) — pakai .in() untuk match multiple status
  const [
    { count: totalMahasiswa },
    { count: totalDosen },
    { count: totalHadir },
    { count: totalAlpa },
    { count: totalIzin },
    { count: pendingLeaveRequests },
    // Trends — 6 query pembanding
    { count: prevMahasiswa },
    { count: prevDosen },
    { count: prevHadir },
    { count: prevAlpa },
    { count: prevIzin },
    { count: prevPendingLeave },
  ] = await Promise.all([
    // Current
    adminClient.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'mahasiswa').eq('is_active', true),
    adminClient.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'dosen').eq('is_active', true),
    adminClient.from('attendances').select('*', { count: 'exact', head: true }).in('status', ['hadir', 'terlambat']).gte('scanned_at', todayBounds.start).lte('scanned_at', todayBounds.end),
    adminClient.from('attendances').select('*', { count: 'exact', head: true }).eq('status', 'alpa').gte('scanned_at', todayBounds.start).lte('scanned_at', todayBounds.end),
    adminClient.from('attendances').select('*', { count: 'exact', head: true }).in('status', ['izin', 'sakit']).gte('scanned_at', todayBounds.start).lte('scanned_at', todayBounds.end),
    adminClient.from('leave_requests').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    // Previous (untuk trend)
    adminClient.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'mahasiswa').eq('is_active', true).lt('created_at', sevenDaysAgo.toISOString()),
    adminClient.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'dosen').eq('is_active', true).lt('created_at', sevenDaysAgo.toISOString()),
    adminClient.from('attendances').select('*', { count: 'exact', head: true }).in('status', ['hadir', 'terlambat']).gte('scanned_at', lastWeekBounds.start).lte('scanned_at', lastWeekBounds.end),
    adminClient.from('attendances').select('*', { count: 'exact', head: true }).eq('status', 'alpa').gte('scanned_at', lastWeekBounds.start).lte('scanned_at', lastWeekBounds.end),
    adminClient.from('attendances').select('*', { count: 'exact', head: true }).in('status', ['izin', 'sakit']).gte('scanned_at', lastWeekBounds.start).lte('scanned_at', lastWeekBounds.end),
    adminClient.from('leave_requests').select('*', { count: 'exact', head: true }).gte('created_at', fourteenDaysAgo.toISOString()).lt('created_at', sevenDaysAgo.toISOString()),
  ])

  // Compute 6 trend
  const trends: KpiTrends = {
    totalMahasiswa: computeTrend(totalMahasiswa ?? 0, prevMahasiswa ?? 0, 'vs minggu lalu'),
    totalDosen: computeTrend(totalDosen ?? 0, prevDosen ?? 0, 'vs minggu lalu'),
    totalHadir: computeTrend(totalHadir ?? 0, prevHadir ?? 0, 'vs hari yang sama'),
    totalAlpa: computeTrend(totalAlpa ?? 0, prevAlpa ?? 0, 'vs hari yang sama'),
    totalIzin: computeTrend(totalIzin ?? 0, prevIzin ?? 0, 'vs hari yang sama'),
    pendingLeaveRequests: computeTrend(pendingLeaveRequests ?? 0, prevPendingLeave ?? 0, 'vs minggu lalu'),
  }

  // 2. Semua attendance 30 hari terakhir untuk weekly trend + ratio
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

  const { data: allAttendances } = await adminClient
    .from('attendances')
    .select('id, session_id, status, scanned_at')
    .gte('scanned_at', thirtyDaysAgo.toISOString())

  const attendanceList = allAttendances ?? []

  // 3. Weekly trend (7 hari terakhir)
  const dayLabels = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
  const monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des']
  const weeklyTrend: WeeklyTrendItem[] = []

  for (let i = 6; i >= 0; i--) {
    const bounds = getDayBoundsUTC(WITA_OFFSET, i)
    const dayAtt = attendanceList.filter(a => a.scanned_at >= bounds.start && a.scanned_at <= bounds.end)

    weeklyTrend.push({
      day: dayLabels[bounds.targetDate.getUTCDay()],
      date: `${bounds.targetDate.getUTCDate().toString().padStart(2, '0')} ${monthLabels[bounds.targetDate.getUTCMonth()]}`,
      // hadir bar inklusif terlambat
      hadir: dayAtt.filter(a => a.status === 'hadir' || a.status === 'terlambat').length,
      izin: dayAtt.filter(a => a.status === 'izin' || a.status === 'sakit').length,
      alpa: dayAtt.filter(a => a.status === 'alpa').length,
    })
  }

  // 4. Attendance ratio (30 hari terakhir) — terlambat slice terpisah
  const totalH = attendanceList.filter(a => a.status === 'hadir').length
  const totalT = attendanceList.filter(a => a.status === 'terlambat').length
  const totalIS = attendanceList.filter(a => a.status === 'izin' || a.status === 'sakit').length
  const totalA = attendanceList.filter(a => a.status === 'alpa').length

  const attendanceRatio: AttendanceRatio[] = [
    { name: 'Hadir', value: totalH, color: STATUS_COLORS.hadir },
    { name: 'Terlambat', value: totalT, color: STATUS_COLORS.terlambat },
    { name: 'Izin/Sakit', value: totalIS, color: STATUS_COLORS.izin },
    { name: 'Alpa', value: totalA, color: STATUS_COLORS.alpa },
  ].filter(item => item.value > 0)

  // 5. Course overview — top 6 mata kuliah per attendance volume
  const { data: courses } = await adminClient
    .from('courses')
    .select('id, code, name')
    .eq('is_active', true)

  const courseList = courses ?? []
  const { data: sessions } = await adminClient
    .from('sessions')
    .select('id, course_id')

  const sessionList = sessions ?? []

  const courseOverview = courseList.map(c => {
    const courseSessions = sessionList.filter(s => s.course_id === c.id)
    const csIds = courseSessions.map(s => s.id)
    const courseAtt = attendanceList.filter(a => csIds.includes(a.session_id))

    return {
      name: c.name.length > 20 ? c.name.substring(0, 20) + '…' : c.name,
      code: c.code,
      // totalHadir inklusif terlambat (per migration 013)
      totalHadir: courseAtt.filter(a => a.status === 'hadir' || a.status === 'terlambat').length,
      totalAlpa: courseAtt.filter(a => a.status === 'alpa').length,
      totalIzin: courseAtt.filter(a => a.status === 'izin' || a.status === 'sakit').length,
    }
  }).sort((a, b) => (b.totalHadir + b.totalAlpa + b.totalIzin) - (a.totalHadir + a.totalAlpa + a.totalIzin)).slice(0, 6)

  // 6. Recent attendances (tabel, max 8)
  const { data: recentData } = await adminClient
    .from('attendances')
    .select(`
      id, status, scanned_at,
      student:profiles!student_id(full_name, nim_nip),
      session:sessions!session_id(topic, course:courses!course_id(name))
    `)
    .gte('scanned_at', todayBounds.start)
    .order('scanned_at', { ascending: false })
    .limit(8)

  return {
    totalMahasiswa: totalMahasiswa ?? 0,
    totalDosen: totalDosen ?? 0,
    totalHadir: totalHadir ?? 0,
    totalAlpa: totalAlpa ?? 0,
    totalIzin: totalIzin ?? 0,
    pendingLeaveRequests: pendingLeaveRequests ?? 0,
    trends,
    weeklyTrend,
    attendanceRatio,
    courseOverview,
    recentAttendances: recentData ?? [],
  }
}
