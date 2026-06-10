// app/api/mobile/sessions/eligible-for-leave/route.ts
// Endpoint daftar sesi yang eligible untuk diajukan izin oleh mahasiswa.
// Mengembalikan dua array: active_sessions (sesi sedang berlangsung) dan
// recent_sessions (sesi sudah lewat <= 7 hari, mahasiswa belum hadir/belum izin).
// Read-only — tidak ada audit log (read endpoint tidak audit untuk hindari spam).
//
// Security:
//   - Bearer JWT + role mahasiswa + is_active=true (authenticateRequest)
//   - student_id selalu diambil dari auth.user.id, bukan body/query (anti-IDOR)
//   - Tidak expose Tier 1 fields (session_code, face_embedding, JWT)
//   - createAdminClient() dipanggil SETELAH auth check (pattern existing /active)
//   - Rate limit 30 req / 5 menit per (user + device) — endpoint read, longgar
//     dibanding endpoint write tapi tetap melindungi dari abuse polling.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import {
  buildRateLimitKey,
  checkSlidingRateLimit,
  getDeviceId,
} from '../../_lib/rate-limit'
import { createAdminClient } from '@/lib/supabase/server'

// ===========================
// Rate Limiter (in-memory, per user+device)
// Sliding window: max 30 request per 5 menit per (userId, deviceId)
// ===========================
const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_CONFIG = { windowMs: 5 * 60_000, max: 30 }

// Tipe baris hasil JOIN dari Supabase. Supabase mengembalikan relasi sebagai
// array (untuk join) — kita normalisasi ke nilai pertama saat mapping.
interface SessionRow {
  id: string
  course_id: string
  session_number: number
  topic: string | null
  started_at: string
  ended_at: string | null
  is_active: boolean
  course: {
    code: string
    name: string
    dosen: { full_name: string } | null
  } | null
}

interface EligibleSession {
  id: string
  course_code: string
  course_name: string
  session_number: number
  topic: string | null
  started_at: string
  ended_at: string | null
  dosen_name: string | null
}

function mapToEligibleSession(row: SessionRow): EligibleSession {
  const courseData = row.course as any
  const course = Array.isArray(courseData) ? courseData[0] : courseData
  const dosenData = course?.dosen
  const dosen = Array.isArray(dosenData) ? dosenData[0] : dosenData
  return {
    id: row.id,
    course_code: course?.code ?? '-',
    course_name: course?.name ?? '-',
    session_number: row.session_number,
    topic: row.topic,
    started_at: row.started_at,
    ended_at: row.ended_at,
    dosen_name: dosen?.full_name ?? null,
  }
}

export async function GET(req: NextRequest) {
  try {
    // 1. AUTH — Bearer JWT + role mahasiswa + is_active
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)
    const user = auth.user!

    // 2. RATE LIMIT — composite key user+device (30 req / 5 menit)
    const deviceId = getDeviceId(req)
    const rlKey = buildRateLimitKey(user.id, deviceId)
    if (!checkSlidingRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return errorResponse(
        'Terlalu banyak permintaan. Coba lagi dalam beberapa menit.',
        429,
      )
    }

    const adminClient = createAdminClient()

    // 3. Ambil enrolled course_ids
    const { data: enrollments, error: enrollmentError } = await adminClient
      .from('enrollments')
      .select('course_id')
      .eq('student_id', user.id)

    if (enrollmentError) {
      return errorResponse('Gagal mengambil data mata kuliah', 500)
    }

    if (!enrollments || enrollments.length === 0) {
      return successResponse({ active_sessions: [], recent_sessions: [] })
    }

    const courseIds = enrollments.map((e) => e.course_id as string)

    // 4. Cutoff 7 hari ke belakang (sesi recent)
    const sevenDaysAgo = new Date(
      Date.now() - 7 * 24 * 60 * 60 * 1000,
    ).toISOString()

    // 5. Ambil semua sesi (aktif + recent) dalam SATU query — JOIN courses + dosen
    //    Sort started_at DESC sehingga sesi terbaru muncul di atas (Req 29.12).
    const { data: sessionsData, error: sessionsError } = await adminClient
      .from('sessions')
      .select(`
        id, course_id, session_number, topic,
        started_at, ended_at, is_active,
        course:courses!sessions_course_id_fkey(
          code, name,
          dosen:profiles!courses_dosen_id_fkey(full_name)
        )
      `)
      .in('course_id', courseIds)
      .gte('started_at', sevenDaysAgo)
      .order('started_at', { ascending: false })

    if (sessionsError) {
      return errorResponse('Gagal mengambil data sesi', 500)
    }

    const sessions = (sessionsData ?? []) as unknown as SessionRow[]

    if (sessions.length === 0) {
      return successResponse({ active_sessions: [], recent_sessions: [] })
    }

    const sessionIds = sessions.map((s) => s.id)

    // 6. PARALLEL fetch exclusion sets (Req 29.7):
    //    - attendances dengan status='hadir' → mahasiswa sudah hadir, tidak perlu izin
    //    - leave_requests pending/approved → sudah ada pengajuan, tidak boleh duplikat
    const [attendedRes, leavedRes] = await Promise.all([
      adminClient
        .from('attendances')
        .select('session_id')
        .eq('student_id', user.id)
        .eq('status', 'hadir')
        .in('session_id', sessionIds),
      adminClient
        .from('leave_requests')
        .select('session_id')
        .eq('student_id', user.id)
        .in('status', ['pending', 'approved'])
        .in('session_id', sessionIds),
    ])

    if (attendedRes.error || leavedRes.error) {
      return errorResponse('Gagal mengambil data kehadiran', 500)
    }

    const excludedSet = new Set<string>([
      ...(attendedRes.data ?? []).map((a) => a.session_id as string),
      ...(leavedRes.data ?? []).map((l) => l.session_id as string),
    ])

    // 7. Partition ke active_sessions (is_active=true) vs recent_sessions (is_active=false)
    //    Order DESC dipertahankan dari hasil query (sort sudah ada di langkah 5).
    const activeSessions: EligibleSession[] = []
    const recentSessions: EligibleSession[] = []

    for (const s of sessions) {
      if (excludedSet.has(s.id)) continue
      const item = mapToEligibleSession(s)
      if (s.is_active) {
        activeSessions.push(item)
      } else {
        recentSessions.push(item)
      }
    }

    // 8. Response — TANPA session_code, face_embedding, atau field sensitif lain
    return successResponse({
      active_sessions: activeSessions,
      recent_sessions: recentSessions,
    })
  } catch {
    return errorResponse('Terjadi kesalahan server', 500)
  }
}
