// app/api/mobile/leave-requests/my/route.ts
// Endpoint daftar pengajuan izin/sakit milik mahasiswa yang login.
// Mendukung filter: status (pending|approved|rejected) via query param.
// Response sudah join dengan info sesi & mata kuliah agar mobile tidak perlu request tambahan.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'

export async function GET(req: NextRequest) {
  const auth = await authenticateRequest(req)
  if (auth.error) return errorResponse(auth.error, auth.status)

  const user = auth.user!
  const adminClient = createAdminClient()

  // Optional filter: status
  const statusParam = req.nextUrl.searchParams.get('status')
  const validStatuses = ['pending', 'approved', 'rejected']
  const statusFilter =
    statusParam && validStatuses.includes(statusParam) ? statusParam : null

  // Optional limit
  const limitParam = req.nextUrl.searchParams.get('limit')
  const limit = Math.min(Math.max(parseInt(limitParam ?? '50', 10) || 50, 1), 100)

  let query = adminClient
    .from('leave_requests')
    .select(`
      id, type, reason, evidence_url, status, review_note, created_at, reviewed_at,
      session:sessions!leave_requests_session_id_fkey(
        id, session_number, topic, started_at,
        course:courses!sessions_course_id_fkey(code, name)
      )
    `)
    .eq('student_id', user.id)
    .order('created_at', { ascending: false })
    .limit(limit)

  if (statusFilter) {
    query = query.eq('status', statusFilter)
  }

  const { data: requests, error } = await query

  if (error) {
    return errorResponse('Gagal mengambil daftar pengajuan', 500)
  }

  // Hitung ringkasan
  let pending = 0
  let approved = 0
  let rejected = 0
  for (const r of requests ?? []) {
    if (r.status === 'pending') pending++
    else if (r.status === 'approved') approved++
    else if (r.status === 'rejected') rejected++
  }

  // Map ke flat structure agar mobile lebih mudah konsumsi
  const result = (requests ?? []).map((r) => {
    const sessionArr = r.session as unknown as Array<{
      id: string
      session_number: number
      topic: string | null
      started_at: string | null
      course: Array<{ code: string; name: string }> | { code: string; name: string } | null
    }> | null
    const session = sessionArr?.[0]
    const courseData = session?.course
    const course = Array.isArray(courseData) ? courseData[0] : courseData

    return {
      id: r.id,
      type: r.type,
      reason: r.reason,
      evidence_url: r.evidence_url,
      status: r.status,
      review_note: r.review_note,
      created_at: r.created_at,
      reviewed_at: r.reviewed_at,
      session: session
        ? {
            id: session.id,
            session_number: session.session_number,
            topic: session.topic,
            started_at: session.started_at,
            course_code: course?.code ?? '-',
            course_name: course?.name ?? '-',
          }
        : null,
    }
  })

  return successResponse({
    requests: result,
    summary: {
      total: result.length,
      pending,
      approved,
      rejected,
    },
  })
}
