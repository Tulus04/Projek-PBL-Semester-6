'use server'
// app/lib/actions/leave-requests.ts
// Server Actions untuk persetujuan izin/sakit mahasiswa.
// SECURITY: Dosen hanya melihat leave requests untuk MK yang dia ampu.

import { revalidatePath } from 'next/cache'
import { createAdminClient, createClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { createNotification } from '@/lib/actions/notifications'
import { sendPushNotification } from '@/lib/fcm-admin'

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

    // FCM push (tambahan; polling/notifications tetap jalan sebagai fallback — D12).
    // Privacy (R14.2): copy generik, tidak bocor detail sensitif.
    try {
      await sendPushNotification({
        studentId: req.student_id,
        title: 'Izin Disetujui',
        body: `Izin untuk ${courseName} pertemuan ${req.session.session_number} disetujui.`,
        route: `/dashboard`,
        type: 'leave_status',
        relatedId: requestId,
      })
    } catch (e) {
      console.error('[FCM] Failed to send push on leave approve:', (e as Error).message)
    }
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
    .select('student_id, type, session:sessions!session_id(session_number, topic, course:courses!course_id(name))')
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
    const req = request as unknown as { session?: { course?: { name?: string } } }
    const courseName = req.session?.course?.name ?? 'Mata Kuliah'
    await createNotification({
      userId: request.student_id,
      title: 'Pengajuan Izin Ditolak',
      message: `Pengajuan ${request.type} Anda untuk ${courseName} ditolak.${reviewNote ? ` Catatan: ${reviewNote}` : ''}`,
      type: 'danger',
      href: '/izin',
    })

    // FCM push (tambahan; polling tetap fallback — D12).
    // Privacy (R14.2): body generik tanpa detail sensitif (tidak sertakan reviewNote).
    try {
      await sendPushNotification({
        studentId: req.student_id,
        title: 'Izin Ditolak',
        body: `Izin untuk ${courseName} pertemuan ${req.session.session_number} ditolak.`,
        route: `/dashboard`,
        type: 'leave_status',
        relatedId: requestId,
      })
    } catch (e) {
      console.error('[FCM] Failed to send push on leave reject:', (e as Error).message)
    }
  }

  revalidatePath('/izin')
  return { error: null }
}

/**
 * Generate signed URL untuk view bukti izin/sakit. Dipakai saat admin/dosen
 * klik tombol "Lihat Bukti" di tabel izin.
 *
 * SECURITY:
 * - Auth via cookie session (`createClient`).
 * - Authorization: admin lihat semua, dosen hanya MK miliknya. RLS storage
 *   sudah enforce, tapi kita tetap cek di server action sebagai defense in depth
 *   dan untuk pesan error yang ramah.
 * - Signed URL TTL 5 menit — cukup untuk klik dan lihat, expired otomatis.
 *
 * @returns { url: string } untuk success, atau { error: string } kalau gagal.
 */
export async function getLeaveEvidenceSignedUrl(requestId: string): Promise<
  { url: string; error: null } | { url: null; error: string }
> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) return { url: null, error: 'Anda harus login terlebih dahulu.' }

  const adminClient = createAdminClient()

  // Cek role user
  const { data: profile } = await adminClient
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  if (!profile || (profile.role !== 'admin' && profile.role !== 'dosen')) {
    return { url: null, error: 'Akses ditolak.' }
  }

  // Ambil leave_request + cek ownership untuk dosen
  const { data: request } = await adminClient
    .from('leave_requests')
    .select(
      `id, evidence_url,
       session:sessions!session_id(course:courses!course_id(dosen_id))`,
    )
    .eq('id', requestId)
    .single()

  if (!request) {
    return { url: null, error: 'Pengajuan tidak ditemukan.' }
  }

  const path = request.evidence_url
  if (!path) {
    return { url: null, error: 'Pengajuan ini tidak menyertakan bukti.' }
  }

  // Defense in depth: dosen hanya bisa lihat bukti pengajuan untuk MK dia ampu
  if (profile.role === 'dosen') {
    type SessionWithCourse = { course?: { dosen_id?: string } | { dosen_id?: string }[] | null }
    const sessionRaw = request.session as unknown as
      | SessionWithCourse
      | SessionWithCourse[]
      | null
    const sessionObj = Array.isArray(sessionRaw) ? sessionRaw[0] : sessionRaw
    const courseRaw = sessionObj?.course
    const courseObj = Array.isArray(courseRaw) ? courseRaw[0] : courseRaw
    const ownerDosenId = courseObj?.dosen_id

    if (!ownerDosenId || ownerDosenId !== user.id) {
      return { url: null, error: 'Akses ditolak. Anda bukan dosen MK terkait.' }
    }
  }

  // Generate signed URL — TTL 5 menit
  const { data: signed, error: signError } = await adminClient.storage
    .from('leave-evidence')
    .createSignedUrl(path, 300)

  if (signError || !signed?.signedUrl) {
    console.error('[getLeaveEvidenceSignedUrl] Sign error:', signError)
    return { url: null, error: 'Gagal membuat link bukti. Coba lagi.' }
  }

  return { url: signed.signedUrl, error: null }
}
