import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import { buildRateLimitKey, checkSlidingRateLimit, getDeviceId } from '../../_lib/rate-limit'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { verifyWithTolerance, getCurrentWindow } from '@/lib/utils/totp'
import { z } from 'zod'

const verifyQrSchema = z.object({
  session_id: z.string().uuid('QR tidak valid'),
  session_code: z.string().length(6, 'QR tidak valid'),
})

const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_CONFIG = { windowMs: 60_000, max: 20 }

export async function POST(req: NextRequest) {
  try {
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)

    const user = auth.user!
    const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    const deviceId = getDeviceId(req)

    const rlKey = buildRateLimitKey(user.id, deviceId) + ':verify-qr'
    if (!checkSlidingRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return errorResponse('Terlalu banyak percobaan, coba 1 menit lagi', 429)
    }

    const body = await req.json()
    const parsed = verifyQrSchema.safeParse(body)
    if (!parsed.success) {
      return errorResponse(parsed.error.errors[0]?.message ?? 'Input tidak valid', 400)
    }
    const input = parsed.data

    const adminClient = createAdminClient()

    const { data: session, error: sessionError } = await adminClient
      .from('sessions')
      .select('id, course_id, is_active, session_code, session_code_seed, session_code_expires_at')
      .eq('id', input.session_id)
      .single()

    if (sessionError || !session) {
      return errorResponse('Sesi tidak ditemukan', 404)
    }
    if (!session.is_active) {
      return errorResponse('Sesi sudah berakhir', 400)
    }

    let qrVerifyMethod: 'totp' | 'static_legacy' = 'totp'
    let qrWindowOffset: number | null = null

    if (session.session_code_seed) {
      const currentWindow = getCurrentWindow()
      // Tolerance akan mengikuti TOLERANCE_DEFAULT dari totp.ts (yaitu 1 = 15s)
      const verify = verifyWithTolerance(
        session.session_code_seed,
        input.session_code,
        currentWindow,
      )

      if (!verify.match) {
        await logAudit({
          action: 'qr_code_invalid_attempt',
          userId: user.id,
          ipAddress,
          details: {
            session_id: input.session_id,
            qr_verify_method: 'totp',
            current_window: currentWindow,
            student_nim: user.nim_nip,
            stage: 'qr_gate',
          },
        })
        return errorResponse('QR sudah kedaluwarsa', 400)
      }
      qrWindowOffset = verify.offset
    } else {
      qrVerifyMethod = 'static_legacy'
      if (session.session_code !== input.session_code) {
        return errorResponse('QR tidak valid', 400)
      }
      if (session.session_code_expires_at) {
        const expiry = new Date(session.session_code_expires_at)
        if (expiry < new Date()) {
          return errorResponse('QR sudah kedaluwarsa', 400)
        }
      }
    }

    // Insert QR token clearance valid for 5 minutes
    const { data: tokenRow, error: tokenError } = await adminClient
      .from('attendance_qr_tokens')
      .insert({
        student_id: user.id,
        session_id: session.id,
      })
      .select('token')
      .single()

    if (tokenError || !tokenRow) {
      return errorResponse('Gagal membuat izin QR', 500)
    }

    await logAudit({
      action: 'qr_gate_passed',
      userId: user.id,
      ipAddress,
      details: {
        session_id: input.session_id,
        qr_verify_method: qrVerifyMethod,
        qr_window_offset: qrWindowOffset,
      },
    })

    return successResponse({
      qr_token: tokenRow.token,
      message: 'QR valid, silakan lanjutkan',
    }, 200)
  } catch (err) {
    console.error('[VerifyQR Error]', err)
    return errorResponse('Terjadi kesalahan server', 500)
  }
}
