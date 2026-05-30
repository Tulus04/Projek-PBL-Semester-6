// app/api/mobile/activity/recent/route.ts
// Endpoint Activity Feed mobile — gabungkan attendance + leave_requests
// terakhir, sorted by tanggal DESC, limit configurable (default 5).
// Dipakai di Beranda mobile untuk section "Aktivitas Terakhir".
//
// Query param:
//   limit (optional, default 5, max 20)
//
// Response:
//   { activities: [{ type, title, subtitle, status, color, icon, occurred_at }, ...] }
//
// CATATAN: dataset gabungan harus disort di server (bukan client) karena
// pagination/limit dilakukan setelah sort. Kalau client merge + sort, ada
// risiko miss item karena dataset terlalu besar.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'

type ActivityItem = {
  type: 'attendance' | 'leave_request'
  id: string
  title: string
  subtitle: string
  status: 'success' | 'warning' | 'danger' | 'info'
  occurred_at: string
}

export async function GET(req: NextRequest) {
  const auth = await authenticateRequest(req)
  if (auth.error) return errorResponse(auth.error, auth.status)

  const user = auth.user!
  const adminClient = createAdminClient()

  // Parse limit (default 5, max 20 untuk hindari abuse)
  const limitRaw = req.nextUrl.searchParams.get('limit')
  const limit = Math.min(Math.max(parseInt(limitRaw ?? '5', 10) || 5, 1), 20)

  // Fetch lebih banyak dari limit agar setelah merge masih ada cukup item
  // (pesimis: kalau ada 5 attendance + 5 leave, fetch 10 dari masing-masing
  // supaya merge result tetap > limit setelah sort)
  const fetchLimit = limit * 2

  // 1. Fetch attendance terbaru
  const { data: attendances, error: attErr } = await adminClient
    .from('attendances')
    .select(`
      id, status, scanned_at, distance_meters, is_location_valid,
      session:sessions!attendances_session_id_fkey(
        id, session_number,
        course:courses!sessions_course_id_fkey(code, name)
      )
    `)
    .eq('student_id', user.id)
    .order('scanned_at', { ascending: false })
    .limit(fetchLimit)

  if (attErr) {
    return errorResponse('Gagal memuat aktivitas presensi', 500)
  }

  // 2. Fetch leave_requests terbaru
  const { data: leaves, error: leaveErr } = await adminClient
    .from('leave_requests')
    .select(`
      id, type, reason, status, created_at, reviewed_at,
      session:sessions!leave_requests_session_id_fkey(
        id, session_number,
        course:courses!sessions_course_id_fkey(code, name)
      )
    `)
    .eq('student_id', user.id)
    .order('created_at', { ascending: false })
    .limit(fetchLimit)

  if (leaveErr) {
    return errorResponse('Gagal memuat aktivitas izin', 500)
  }

  // 3. Map attendances → ActivityItem
  const attendanceActivities: ActivityItem[] = (attendances ?? [])
    .map((a) => {
      const sessionArr = a.session as unknown as
        | Array<{
            id: string
            session_number: number
            course: Array<{ code: string; name: string }> | { code: string; name: string } | null
          }>
        | { id: string; session_number: number; course: Array<{ code: string; name: string }> | { code: string; name: string } | null }
        | null
      const session = Array.isArray(sessionArr) ? sessionArr[0] : sessionArr
      if (!session) return null

      const courseData = session.course
      const course = Array.isArray(courseData) ? courseData[0] : courseData
      const courseName = course?.name ?? 'Mata Kuliah'

      let title: string
      let status: ActivityItem['status']
      let subtitle: string

      const distanceLabel = a.distance_meters != null
        ? `Jarak ${Math.round(a.distance_meters)}m`
        : ''
      const locationLabel = a.is_location_valid === true
        ? 'Lokasi sesuai'
        : a.is_location_valid === false
          ? 'Lokasi luar radius'
          : ''

      switch (a.status) {
        case 'hadir':
          title = `Presensi ${courseName} berhasil`
          status = 'success'
          subtitle = [locationLabel, distanceLabel].filter(Boolean).join(' · ')
          break
        case 'terlambat':
          title = `Presensi ${courseName} terlambat`
          status = 'warning'
          subtitle = [locationLabel, distanceLabel].filter(Boolean).join(' · ')
          break
        case 'izin':
          title = `Izin ${courseName} disetujui`
          status = 'info'
          subtitle = `Sesi ${session.session_number}`
          break
        case 'sakit':
          title = `Sakit ${courseName} disetujui`
          status = 'info'
          subtitle = `Sesi ${session.session_number}`
          break
        case 'alpa':
          title = `Alpa di ${courseName}`
          status = 'danger'
          subtitle = `Sesi ${session.session_number}`
          break
        default:
          title = `Presensi ${courseName}`
          status = 'info'
          subtitle = a.status as string
      }

      return {
        type: 'attendance' as const,
        id: a.id,
        title,
        subtitle,
        status,
        occurred_at: a.scanned_at as string,
      } as ActivityItem
    })
    .filter((x): x is ActivityItem => x !== null)

  // 4. Map leave_requests → ActivityItem
  const leaveActivities: ActivityItem[] = (leaves ?? []).map((l) => {
    const sessionArr = l.session as unknown as
      | Array<{
          id: string
          session_number: number
          course: Array<{ code: string; name: string }> | { code: string; name: string } | null
        }>
      | { id: string; session_number: number; course: Array<{ code: string; name: string }> | { code: string; name: string } | null }
      | null
    const session = Array.isArray(sessionArr) ? sessionArr[0] : sessionArr
    const courseData = session?.course
    const course = Array.isArray(courseData) ? courseData[0] : courseData
    const courseName = course?.name ?? 'Mata Kuliah'

    const typeLabel = l.type === 'sakit' ? 'Sakit' : 'Izin'
    let title: string
    let status: ActivityItem['status']

    switch (l.status) {
      case 'approved':
        title = `Pengajuan ${typeLabel} ${courseName} disetujui`
        status = 'success'
        break
      case 'rejected':
        title = `Pengajuan ${typeLabel} ${courseName} ditolak`
        status = 'danger'
        break
      case 'pending':
      default:
        title = `Pengajuan ${typeLabel} ${courseName} menunggu review`
        status = 'warning'
        break
    }

    // Pakai reviewed_at kalau sudah review, fallback ke created_at
    const occurredAt = (l.reviewed_at as string | null) ?? (l.created_at as string)
    const subtitle = l.reason
      ? (l.reason as string).length > 60
        ? `${(l.reason as string).slice(0, 60)}...`
        : (l.reason as string)
      : `Sesi ${session?.session_number ?? '-'}`

    return {
      type: 'leave_request' as const,
      id: l.id as string,
      title,
      subtitle,
      status,
      occurred_at: occurredAt,
    }
  })

  // 5. Merge + sort by occurred_at DESC + take top N
  const merged = [...attendanceActivities, ...leaveActivities]
    .sort((a, b) => b.occurred_at.localeCompare(a.occurred_at))
    .slice(0, limit)

  return successResponse({ activities: merged })
}
