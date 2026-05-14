'use server'
// app/lib/actions/leave-requests.ts
// Server Actions untuk persetujuan izin/sakit mahasiswa.
// SECURITY: Dosen hanya melihat leave requests untuk MK yang dia ampu.

import { revalidatePath } from 'next/cache'
import { createAdminClient, createClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { createNotification } from '@/lib/actions/notifications'

export async function getLeaveRequests({
  status,
  page = 1,
  perPage = 15,
  dosenId,
}: {
  status?: string
  page?: number
  perPage?: number
  dosenId?: string
} = {}) {
  const supabase = createAdminClient()
  const from = (page - 1) * perPage
  const to = from + perPage - 1

  // Jika dosenId disediakan, ambil course IDs milik dosen lalu filter session IDs
  let dosenSessionIds: string[] | null = null
  if (dosenId) {
    const { data: dosenCourses } = await supabase
      .from('courses')
      .select('id')
      .eq('dosen_id', dosenId)
    
    if (!dosenCourses || dosenCourses.length === 0) {
      return { requests: [], total: 0, totalPages: 0, error: null }
    }

    const courseIds = dosenCourses.map(c => c.id)
    const { data: dosenSessions } = await supabase
      .from('sessions')
      .select('id')
      .in('course_id', courseIds)

    dosenSessionIds = (dosenSessions ?? []).map(s => s.id)
    if (dosenSessionIds.length === 0) {
      return { requests: [], total: 0, totalPages: 0, error: null }
    }
  }

  let query = supabase
    .from('leave_requests')
    .select(
      `id, type, reason, evidence_url, status, review_note, created_at, reviewed_at,
       student:profiles!student_id(id, full_name, nim_nip, kelas),
       reviewer:profiles!reviewed_by(full_name),
       session:sessions!session_id(session_number, topic, course:courses!course_id(code, name))`,
      { count: 'exact' }
    )
    .order('created_at', { ascending: false })
    .range(from, to)

  if (status && status !== 'all') {
    query = query.eq('status', status)
  }

  // Data isolation: filter berdasarkan session IDs milik dosen
  if (dosenSessionIds) {
    query = query.in('session_id', dosenSessionIds)
  }

  const { data, count, error } = await query

  return {
    requests: data ?? [],
    total: count ?? 0,
    totalPages: Math.ceil((count ?? 0) / perPage),
    error: error?.message ?? null,
  }
}

export async function approveLeaveRequest(requestId: string, reviewNote?: string) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const adminClient = createAdminClient()

  // Get leave request details for updating attendance + notification
  const { data: request } = await adminClient
    .from('leave_requests')
    .select('student_id, session_id, type, session:sessions!session_id(topic, course:courses!course_id(name))')
    .eq('id', requestId)
    .single()

  // Update leave request status
  const { error } = await adminClient
    .from('leave_requests')
    .update({
      status: 'approved',
      reviewed_by: user?.id,
      review_note: reviewNote || null,
      reviewed_at: new Date().toISOString(),
    })
    .eq('id', requestId)

  if (error) return { error: error.message }

  // Update attendance status if exists
  if (request) {
    await adminClient
      .from('attendances')
      .update({ status: request.type }) // 'izin' or 'sakit'
      .eq('student_id', request.student_id)
      .eq('session_id', request.session_id)
  }

  await logAudit({
    action: 'approve_leave',
    details: { request_id: requestId, type: request?.type },
  })

  // Kirim notifikasi ke mahasiswa
  if (request?.student_id) {
    const sessionArr = request.session as unknown as Array<{ topic?: string; course?: Array<{ name?: string }> }> | null
    const session = sessionArr?.[0]
    const courseName = session?.course?.[0]?.name ?? 'Mata Kuliah'
    await createNotification({
      userId: request.student_id,
      title: 'Pengajuan Izin Disetujui',
      message: `Pengajuan ${request.type} Anda untuk ${courseName} telah disetujui.`,
      type: 'success',
      href: '/izin',
    })
  }

  revalidatePath('/izin')
  return { error: null }
}

export async function rejectLeaveRequest(requestId: string, reviewNote?: string) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const adminClient = createAdminClient()

  // Ambil detail untuk notifikasi
  const { data: request } = await adminClient
    .from('leave_requests')
    .select('student_id, type, session:sessions!session_id(topic, course:courses!course_id(name))')
    .eq('id', requestId)
    .single()

  const { error } = await adminClient
    .from('leave_requests')
    .update({
      status: 'rejected',
      reviewed_by: user?.id,
      review_note: reviewNote || null,
      reviewed_at: new Date().toISOString(),
    })
    .eq('id', requestId)

  if (error) return { error: error.message }

  await logAudit({
    action: 'reject_leave',
    details: { request_id: requestId },
  })

  // Kirim notifikasi ke mahasiswa
  if (request?.student_id) {
    const sessionArr = request.session as unknown as Array<{ topic?: string; course?: Array<{ name?: string }> }> | null
    const session = sessionArr?.[0]
    const courseName = session?.course?.[0]?.name ?? 'Mata Kuliah'
    await createNotification({
      userId: request.student_id,
      title: 'Pengajuan Izin Ditolak',
      message: `Pengajuan ${request.type} Anda untuk ${courseName} ditolak.${reviewNote ? ` Catatan: ${reviewNote}` : ''}`,
      type: 'danger',
      href: '/izin',
    })
  }

  revalidatePath('/izin')
  return { error: null }
}
