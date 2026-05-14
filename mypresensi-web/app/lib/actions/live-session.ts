'use server'
// app/lib/actions/live-session.ts
// Server actions untuk fitur Live Session Monitor — fetch sesi aktif dosen
// + list mahasiswa enrolled + initial state attendances.
// Client component akan subscribe Supabase Realtime channel untuk update inkremen.

import { createAdminClient } from '@/lib/supabase/server'
import { requireRole } from '@/lib/auth-guard'

// ==========================================
// TIPE DATA
// ==========================================

export interface EnrolledStudent {
  id: string
  fullName: string
  nimNip: string
  avatarUrl: string | null
}

export interface ActiveSessionInfo {
  sessionId: string
  courseId: string
  courseCode: string
  courseName: string
  topic: string | null
  sessionNumber: number
  mode: 'offline' | 'online'
  startedAt: string
  // Mahasiswa enrolled + status absensi awal (saat fetch)
  enrolledStudents: EnrolledStudent[]
  // Map student_id → status (hadir/terlambat/izin/sakit/alpa) untuk yang sudah submit
  initialAttendances: Record<string, string>
  // Total enrolled
  totalEnrolled: number
  // Sudah absen (apapun statusnya — count)
  totalAttended: number
}

// ==========================================
// SERVER ACTION
// ==========================================

/**
 * Cari sesi aktif milik dosen yang sedang login (atau admin lihat sesi aktif manapun).
 * Sesi aktif = ended_at IS NULL DAN dimulai dalam 8 jam terakhir (cap waktu wajar).
 * Return null kalau tidak ada sesi aktif.
 */
export async function getActiveSessionStatus(): Promise<ActiveSessionInfo | null> {
  const user = await requireRole(['dosen', 'admin'])
  const adminClient = createAdminClient()

  // 1. Cari sesi aktif terbaru milik dosen tersebut.
  // Untuk admin, kita ambil sesi aktif paling baru (admin biasanya cuma overview).
  const eightHoursAgo = new Date()
  eightHoursAgo.setHours(eightHoursAgo.getHours() - 8)

  let sessionQuery = adminClient
    .from('sessions')
    .select(`
      id, course_id, dosen_id, session_number, topic, mode, started_at,
      course:courses!course_id(id, code, name)
    `)
    .is('ended_at', null)
    .gte('started_at', eightHoursAgo.toISOString())
    .order('started_at', { ascending: false })
    .limit(1)

  if (user.role === 'dosen') {
    sessionQuery = sessionQuery.eq('dosen_id', user.id)
  }

  const { data: sessions } = await sessionQuery

  if (!sessions || sessions.length === 0) {
    return null
  }

  // Cast hasil JOIN — Supabase return course sebagai array meski !inner, narrow ke single
  const session = sessions[0] as unknown as {
    id: string
    course_id: string
    dosen_id: string
    session_number: number
    topic: string | null
    mode: 'offline' | 'online'
    started_at: string
    course: { id: string; code: string; name: string } | null
  }

  if (!session.course) {
    // Defensive: kalau course tidak ada (FK rusak), return null
    return null
  }

  // 2. Fetch enrolled students dari course tersebut.
  const { data: enrollments } = await adminClient
    .from('enrollments')
    .select(`
      student_id,
      student:profiles!student_id(id, full_name, nim_nip, avatar_url)
    `)
    .eq('course_id', session.course_id)

  const enrolledStudents: EnrolledStudent[] = (enrollments ?? [])
    .map((e) => {
      const studentRaw = e.student as unknown as {
        id: string
        full_name: string
        nim_nip: string
        avatar_url: string | null
      } | null
      if (!studentRaw) return null
      return {
        id: studentRaw.id,
        fullName: studentRaw.full_name,
        nimNip: studentRaw.nim_nip,
        avatarUrl: studentRaw.avatar_url,
      }
    })
    .filter((s): s is EnrolledStudent => s !== null)
    // Sort alphabetical untuk konsistensi tampilan
    .sort((a, b) => a.fullName.localeCompare(b.fullName, 'id'))

  // 3. Fetch initial attendances untuk sesi ini (yang sudah masuk sebelum subscribe Realtime).
  const { data: attendances } = await adminClient
    .from('attendances')
    .select('student_id, status')
    .eq('session_id', session.id)

  const initialAttendances: Record<string, string> = {}
  for (const a of attendances ?? []) {
    if (a.student_id) {
      initialAttendances[a.student_id] = a.status ?? 'hadir'
    }
  }

  return {
    sessionId: session.id,
    courseId: session.course.id,
    courseCode: session.course.code,
    courseName: session.course.name,
    topic: session.topic,
    sessionNumber: session.session_number,
    mode: session.mode,
    startedAt: session.started_at,
    enrolledStudents,
    initialAttendances,
    totalEnrolled: enrolledStudents.length,
    totalAttended: Object.keys(initialAttendances).length,
  }
}
