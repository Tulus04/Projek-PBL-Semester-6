// app/api/mobile/sessions/active/route.ts
// Endpoint daftar sesi aktif dari semua MK yang di-enroll mahasiswa.
// TIDAK meng-expose session_code — mahasiswa harus scan QR atau ketik manual.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'

export async function GET(req: NextRequest) {
  const auth = await authenticateRequest(req)
  if (auth.error) return errorResponse(auth.error, auth.status)

  const user = auth.user!
  const adminClient = createAdminClient()

  // 1. Ambil course_ids yang di-enroll
  const { data: enrollments } = await adminClient
    .from('enrollments')
    .select('course_id')
    .eq('student_id', user.id)

  if (!enrollments || enrollments.length === 0) {
    return successResponse({ sessions: [] })
  }

  const courseIds = enrollments.map((e) => e.course_id)

  // 2. Ambil sesi aktif dari course tersebut
  const { data: sessions, error } = await adminClient
    .from('sessions')
    .select(`
      id, course_id, session_number, topic, mode,
      location_lat, location_lng, radius_meters,
      started_at,
      course:courses!sessions_course_id_fkey(code, name),
      dosen:profiles!sessions_dosen_id_fkey(full_name)
    `)
    .in('course_id', courseIds)
    .eq('is_active', true)

  if (error) {
    return errorResponse('Gagal mengambil data sesi', 500)
  }

  // 3. Cek mana yang sudah di-submit
  const sessionIds = (sessions ?? []).map((s) => s.id)
  let submittedSet = new Set<string>()

  if (sessionIds.length > 0) {
    const { data: attendances } = await adminClient
      .from('attendances')
      .select('session_id')
      .eq('student_id', user.id)
      .in('session_id', sessionIds)

    if (attendances) {
      submittedSet = new Set(attendances.map((a) => a.session_id))
    }
  }

  // 4. Map ke response — TANPA session_code
  const result = (sessions ?? []).map((s) => {
    // Supabase returns related one-to-one/many-to-one records as a single object, not an array
    const course = s.course as unknown as { code: string; name: string } | null
    const dosen = s.dosen as unknown as { full_name: string } | null

    return {
      id: s.id,
      course_code: course?.code ?? '-',
      course_name: course?.name ?? '-',
      dosen_name: dosen?.full_name ?? null,
      session_number: s.session_number,
      topic: s.topic,
      mode: s.mode,
      location_lat: s.location_lat,
      location_lng: s.location_lng,
      radius_meters: s.radius_meters,
      started_at: s.started_at,
      already_submitted: submittedSet.has(s.id),
    }
  })

  return successResponse({ sessions: result })
}
