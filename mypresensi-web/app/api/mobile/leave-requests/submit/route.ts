// app/api/mobile/leave-requests/submit/route.ts
// Endpoint mahasiswa mengajukan izin/sakit untuk sebuah sesi.
// Validasi: enrolled di MK, sesi belum berakhir, belum ada request approved/pending untuk sesi sama.
// Rate limited: max 5 request per 10 menit per (user + device).

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import {
  buildRateLimitKey,
  checkSlidingRateLimit,
  getDeviceId,
} from '../../_lib/rate-limit'
import {
  EVIDENCE_PATH_REGEX,
  isPathOwnedByUser,
} from '../../_lib/storage-utils'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { z } from 'zod'

// ===========================
// Zod Schema
// ===========================
const submitSchema = z.object({
  session_id: z.string().uuid('Sesi tidak valid'),
  type: z.enum(['izin', 'sakit'], {
    errorMap: () => ({ message: 'Tipe tidak valid' }),
  }),
  reason: z
    .string()
    .min(10, 'Alasan minimal 10 karakter')
    .max(500, 'Alasan maksimal 500 karakter'),
  // evidence_path: hasil upload via /upload-evidence — format
  // '<uuid_user>/<32hex>.<jpg|png|webp>'. Optional.
  // Server akan validate prefix === user.id sebagai defense in depth selain RLS.
  evidence_path: z
    .string({ required_error: 'Wajib melampirkan bukti' })
    .regex(EVIDENCE_PATH_REGEX, 'Bukti tidak valid'),
})

// ===========================
// Rate Limiter (in-memory, per user+device)
// Sliding window: max 5 request per 10 menit per (userId, deviceId)
// ===========================
const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_CONFIG = { windowMs: 10 * 60_000, max: 5 }

export async function POST(req: NextRequest) {
  try {
    // 1. AUTH
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)
    const user = auth.user!
    const deviceId = getDeviceId(req)

    // 2. RATE LIMIT — composite key user+device
    const rlKey = buildRateLimitKey(user.id, deviceId)
    if (!checkSlidingRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return errorResponse('Terlalu banyak pengajuan, coba 10 menit lagi', 429)
    }

    // 3. VALIDASI INPUT
    const body = await req.json()
    const parsed = submitSchema.safeParse(body)
    if (!parsed.success) {
      return errorResponse(parsed.error.errors[0]?.message ?? 'Input tidak valid', 400)
    }
    const input = parsed.data

    // 3a. Defense in depth: kalau evidence_path dikirim, prefix harus user.id sendiri.
    // Mencegah attacker submit dengan path yang menunjuk file user lain.
    if (input.evidence_path && !isPathOwnedByUser(input.evidence_path, user.id)) {
      return errorResponse('Bukti tidak valid', 403)
    }

    const supabase = createAdminClient()

    // 4. CEK SESI ADA & BELUM BERAKHIR
    const { data: session, error: sessionError } = await supabase
      .from('sessions')
      .select('id, course_id, is_active, started_at, ended_at, session_number, topic, course:courses!sessions_course_id_fkey(name)')
      .eq('id', input.session_id)
      .single()

    if (sessionError || !session) {
      return errorResponse('Sesi tidak ditemukan', 404)
    }

    if (session.ended_at) {
      return errorResponse('Sesi sudah berakhir', 400)
    }

    // 5. CEK ENROLLMENT
    const { data: enrollment } = await supabase
      .from('enrollments')
      .select('id')
      .eq('course_id', session.course_id)
      .eq('student_id', user.id)
      .limit(1)
      .maybeSingle()

    if (!enrollment) {
      return errorResponse('Anda tidak terdaftar di mata kuliah ini', 403)
    }

    // 6. CEK DUPLIKASI: belum ada request pending/approved untuk sesi sama
    const { data: existingRequest } = await supabase
      .from('leave_requests')
      .select('id, status')
      .eq('student_id', user.id)
      .eq('session_id', input.session_id)
      .in('status', ['pending', 'approved'])
      .limit(1)
      .maybeSingle()

    if (existingRequest) {
      const msg =
        existingRequest.status === 'approved'
          ? 'Pengajuan izin Anda untuk sesi ini sudah disetujui.'
          : 'Anda sudah mengajukan izin untuk sesi ini, mohon tunggu review dosen.'
      return errorResponse(msg, 409)
    }

    // 7. CEK SUDAH PRESENSI? (kalau sudah hadir, tidak perlu izin)
    const { data: existingAttendance } = await supabase
      .from('attendances')
      .select('id, status')
      .eq('student_id', user.id)
      .eq('session_id', input.session_id)
      .limit(1)
      .maybeSingle()

    if (existingAttendance && existingAttendance.status === 'hadir') {
      return errorResponse('Anda sudah hadir di sesi ini', 409)
    }

    // 8. INSERT
    const { data: inserted, error: insertError } = await supabase
      .from('leave_requests')
      .insert({
        student_id: user.id,
        session_id: input.session_id,
        type: input.type,
        reason: input.reason,
        // Kolom legacy `evidence_url` sekarang menyimpan PATH (bukan full URL).
        // Web admin/dosen akan generate signed URL on-demand via server action.
        evidence_url: input.evidence_path ?? null,
        status: 'pending',
      })
      .select('id, created_at')
      .single()

    if (insertError) {
      return errorResponse(`Gagal menyimpan pengajuan: ${insertError.message}`, 500)
    }

    // 9. AUDIT
    const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    await logAudit({
      action: 'mobile_leave_request_submit',
      userId: user.id,
      ipAddress,
      details: {
        request_id: inserted?.id,
        student_id: user.id,
        student_nim: user.nim_nip,
        session_id: input.session_id,
        type: input.type,
        has_evidence: !!input.evidence_path,
        device_id: deviceId,
        user_agent: req.headers.get('user-agent') ?? null,
      },
    })

    // 10. RESPONSE
    return successResponse(
      {
        id: inserted?.id,
        status: 'pending',
        message: `Pengajuan ${input.type} berhasil dikirim. Menunggu persetujuan dosen.`,
        created_at: inserted?.created_at,
      },
      201
    )
  } catch {
    return errorResponse('Terjadi kesalahan server', 500)
  }
}
