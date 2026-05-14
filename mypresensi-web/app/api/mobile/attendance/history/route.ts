// app/api/mobile/attendance/history/route.ts
// Endpoint riwayat kehadiran mahasiswa.
// Mendukung filter per course_id via query param.
// Menyertakan summary statistik (total, hadir, terlambat, izin, sakit, alpa, persentase).
// Persentase kehadiran inklusif: (hadir + terlambat) / total — karena terlambat
// tetap dianggap hadir (sub-variant).

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'

export async function GET(req: NextRequest) {
  const auth = await authenticateRequest(req)
  if (auth.error) return errorResponse(auth.error, auth.status)

  const user = auth.user!
  const adminClient = createAdminClient()

  // Optional filter: course_id
  const courseId = req.nextUrl.searchParams.get('course_id')

  // 1. Ambil semua attendance + session + course info
  const query = adminClient
    .from('attendances')
    .select(`
      id, status, scanned_at, distance_meters, is_location_valid, face_confidence,
      session:sessions!attendances_session_id_fkey(
        id, session_number, topic, course_id,
        course:courses!sessions_course_id_fkey(code, name)
      )
    `)
    .eq('student_id', user.id)
    .order('scanned_at', { ascending: false })

  const { data: attendances, error } = await query

  if (error) {
    return errorResponse('Gagal mengambil riwayat kehadiran.', 500)
  }

  // 2. Map & filter
  const history = (attendances ?? [])
    .map((a) => {
      const sessionArr = a.session as unknown as Array<{
        id: string; session_number: number; topic: string | null; course_id: string;
        course: Array<{ code: string; name: string }> | { code: string; name: string } | null
      }> | null
      const session = sessionArr?.[0]
      if (!session) return null

      const courseData = session.course
      const course = Array.isArray(courseData) ? courseData[0] : courseData

      // Filter by course_id if provided
      if (courseId && session.course_id !== courseId) return null

      return {
        id: a.id,
        session_number: session.session_number,
        topic: session.topic,
        course_code: course?.code ?? '-',
        course_name: course?.name ?? '-',
        status: a.status,
        scanned_at: a.scanned_at,
        distance_meters: a.distance_meters,
        is_location_valid: a.is_location_valid,
        face_confidence: a.face_confidence,
      }
    })
    .filter(Boolean)

  // 3. Hitung summary — terlambat termasuk variant hadir untuk persentase kehadiran.
  const hadir = history.filter((h) => h!.status === 'hadir').length
  const terlambat = history.filter((h) => h!.status === 'terlambat').length
  const izin = history.filter((h) => h!.status === 'izin').length
  const sakit = history.filter((h) => h!.status === 'sakit').length
  const alpa = history.filter((h) => h!.status === 'alpa').length
  const total = history.length
  // Persentase inklusif: hadir + terlambat dianggap "hadir" untuk perhitungan kehadiran
  const totalHadirInclusive = hadir + terlambat
  const percentage = total > 0 ? Math.round((totalHadirInclusive / total) * 100 * 10) / 10 : 0

  return successResponse({
    history,
    summary: {
      total_sessions: total,
      hadir,
      terlambat,
      izin,
      sakit,
      alpa,
      percentage,
    },
  })
}
