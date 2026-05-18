// app/api/admin/sessions/[id]/live-state/route.ts
// Endpoint live state untuk Live Monitor Dosen.
// Return students enrolled di MK + status hadir per session + stats agregat.
// Read-only — tidak ada audit log (read endpoint tidak audit untuk hindari spam).
//
// Security:
//   - Cookie session via requireRole(['admin','dosen'])
//   - Ownership check via canAccessCourse — dosen hanya bisa akses sesi MK miliknya
//   - Admin bypass ownership (global access)
//   - createAdminClient() dipanggil SETELAH auth + ownership check
//   - Tidak expose Tier 1 fields (session_code, etc) di response
//   - Rate limit 30 req / 60 detik per (userId, sessionId)
//
// Konsumen utama: `/sesi/[id]/live` page (Server Component initial fetch +
// Live Monitor Client untuk reconnect refresh setelah Realtime CHANNEL_ERROR).

import { NextRequest, NextResponse } from 'next/server'
import { requireRole, canAccessCourse } from '@/lib/auth-guard'
import { createAdminClient } from '@/lib/supabase/server'
import {
  buildRateLimitKey,
  checkSlidingRateLimit,
} from '../../../../mobile/_lib/rate-limit'

const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_CONFIG = { windowMs: 60_000, max: 30 }

interface RouteContext {
  params: Promise<{ id: string }>
}

interface AttendanceRow {
  student_id: string
  status: string
  scanned_at: string | null
  student_lat: number | null
  student_lng: number | null
  distance_meters: number | null
  is_mock_location: boolean | null
  face_confidence: number | null
}

interface EnrollmentRow {
  student_id: string
  profile: Array<{
    id: string
    full_name: string
    nim_nip: string | null
    avatar_url: string | null
  }> | null
}

export async function GET(req: NextRequest, ctx: RouteContext) {
  try {
    // 1. Auth
    let user
    try {
      user = await requireRole(['admin', 'dosen'])
    } catch {
      return NextResponse.json(
        { error: 'Tidak terautentikasi' },
        { status: 401 },
      )
    }

    const { id: sessionId } = await ctx.params

    // 2. Rate limit
    const rlKey = buildRateLimitKey(user.id, sessionId)
    if (!checkSlidingRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return NextResponse.json(
        { error: 'Terlalu banyak permintaan. Coba lagi sebentar.' },
        { status: 429 },
      )
    }

    const adminClient = createAdminClient()

    // 3. Fetch session.course_id untuk ownership check
    const { data: session, error: sessionError } = await adminClient
      .from('sessions')
      .select('id, course_id')
      .eq('id', sessionId)
      .maybeSingle()

    if (sessionError) {
      return NextResponse.json(
        { error: 'Gagal mengambil data sesi.' },
        { status: 500 },
      )
    }

    if (!session) {
      return NextResponse.json(
        { error: 'Sesi tidak ditemukan.' },
        { status: 404 },
      )
    }

    // 4. Ownership check
    const allowed = await canAccessCourse(user.id, user.role, session.course_id)
    if (!allowed) {
      return NextResponse.json(
        { error: 'Tidak ada akses ke sesi ini.' },
        { status: 403 },
      )
    }

    // 5. Parallel fetch enrollments + attendances
    const [enrollmentsRes, attendancesRes] = await Promise.all([
      adminClient
        .from('enrollments')
        .select(`
          student_id,
          profile:profiles!enrollments_student_id_fkey(id, full_name, nim_nip, avatar_url)
        `)
        .eq('course_id', session.course_id),
      adminClient
        .from('attendances')
        .select(`
          student_id, status, scanned_at,
          student_lat, student_lng, distance_meters,
          is_mock_location, face_confidence
        `)
        .eq('session_id', sessionId),
    ])

    if (enrollmentsRes.error || attendancesRes.error) {
      return NextResponse.json(
        { error: 'Gagal mengambil data live state.' },
        { status: 500 },
      )
    }

    const enrollments = (enrollmentsRes.data ?? []) as unknown as EnrollmentRow[]
    const attendances = (attendancesRes.data ?? []) as AttendanceRow[]

    // Map student_id → attendance for fast lookup
    const attendanceMap = new Map<string, AttendanceRow>()
    for (const a of attendances) {
      attendanceMap.set(a.student_id, a)
    }

    // 6. Merge: untuk setiap enrollment, isi status dari attendance kalau ada,
    //    kalau tidak default 'belum'.
    const students = enrollments.map((e) => {
      const attendance = attendanceMap.get(e.student_id)
      const profile = e.profile?.[0]
      const status = attendance
        ? attendance.is_mock_location
          ? 'ditolak'
          : attendance.status
        : 'belum'
      return {
        student_id: e.student_id,
        full_name: profile?.full_name ?? '-',
        nim: profile?.nim_nip ?? null,
        avatar_url: profile?.avatar_url ?? null,
        status,
        scanned_at: attendance?.scanned_at ?? null,
        student_lat: attendance?.student_lat ?? null,
        student_lng: attendance?.student_lng ?? null,
        distance_meters: attendance?.distance_meters ?? null,
        is_mock_location: attendance?.is_mock_location ?? null,
        face_confidence: attendance?.face_confidence ?? null,
      }
    })

    // 7. Compute stats
    let hadir = 0
    let terlambat = 0
    let belum = 0
    let ditolak = 0
    for (const s of students) {
      switch (s.status) {
        case 'hadir':
          hadir++
          break
        case 'terlambat':
          terlambat++
          break
        case 'ditolak':
          ditolak++
          break
        case 'belum':
          belum++
          break
        // izin/sakit/alpa tidak masuk hadir/belum/ditolak — tidak di-count di stats live
      }
    }

    return NextResponse.json(
      {
        students,
        stats: {
          hadir,
          terlambat,
          belum,
          ditolak,
          total: students.length,
        },
      },
      { status: 200 },
    )
  } catch {
    return NextResponse.json(
      { error: 'Terjadi kesalahan server.' },
      { status: 500 },
    )
  }
}
