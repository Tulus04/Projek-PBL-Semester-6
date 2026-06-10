// app/api/mobile/profile/fcm-token/route.ts
// Endpoint registrasi FCM token mahasiswa untuk push notification.
//
// SECURITY:
//   - Bearer JWT + role mahasiswa + is_active (authenticateRequest)
//   - student_id SELALU dari auth.user.id, BUKAN body (anti-IDOR)
//   - fcm_token TIDAK pernah di-return ke response (write-only dari sisi mobile)
//   - Update via createAdminClient() (service_role) setelah auth check

import { NextRequest } from 'next/server'
import { z } from 'zod'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'

// ===========================
// Zod Schema
// ===========================
const fcmTokenSchema = z.object({
  fcm_token: z
    .string()
    .min(1, 'Token tidak boleh kosong')
    .max(1000, 'Token tidak valid'),
})

export async function POST(req: NextRequest) {
  try {
    // 1. AUTH — Bearer JWT + role mahasiswa + is_active
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)
    const user = auth.user!

    // 2. Parse + validasi body
    let json: unknown
    try {
      json = await req.json()
    } catch {
      return errorResponse('Format request tidak valid', 400)
    }

    const parsed = fcmTokenSchema.safeParse(json)
    if (!parsed.success) {
      const firstError = parsed.error.errors[0]?.message ?? 'Data tidak valid'
      return errorResponse(firstError, 400)
    }

    // 3. UPDATE profiles — student_id dari auth, bukan body
    const supabase = createAdminClient()
    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        fcm_token: parsed.data.fcm_token,
        fcm_token_updated_at: new Date().toISOString(),
      })
      .eq('id', user.id)

    if (updateError) {
      return errorResponse('Gagal menyimpan token notifikasi', 500)
    }

    // 4. AUDIT — pass userId + ipAddress eksplisit (Bearer context tanpa cookie)
    const ipAddress =
      req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    await logAudit({
      action: 'mobile_fcm_token_register',
      userId: user.id,
      ipAddress,
      details: { user_agent: req.headers.get('user-agent') ?? null },
    })

    return successResponse({ ok: true })
  } catch {
    return errorResponse('Terjadi kesalahan. Coba beberapa saat lagi.', 500)
  }
}
