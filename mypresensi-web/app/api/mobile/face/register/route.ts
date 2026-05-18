// app/api/mobile/face/register/route.ts
// Endpoint registrasi wajah mahasiswa — upload face embedding ke database.
// Embedding berupa array float dari face landmarks ML Kit.
// Rate limited: max 3 request per 15 menit per (user + device).

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import {
  buildRateLimitKey,
  checkCounterRateLimit,
  getDeviceId,
  type CounterRateLimitEntry,
} from '../../_lib/rate-limit'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { z } from 'zod'
import crypto from 'crypto'

// ===========================
// Zod Schema
// ===========================
const registerSchema = z.object({
  embedding: z
    .array(z.number().min(-1).max(1))
    .length(192, 'Format embedding tidak valid'),
})

// ===========================
// Rate Limiting (in-memory, per user+device)
// Counter window: max 3 register per 15 menit per (userId, deviceId)
// ===========================
const rateLimitMap = new Map<string, CounterRateLimitEntry>()
const RATE_LIMIT_CONFIG = { windowMs: 15 * 60_000, max: 3 }

// ===========================
// POST — Register Face Embedding
// ===========================
export async function POST(req: NextRequest) {
  try {
    // 1. Authenticate
    const { user, error: authError, status } = await authenticateRequest(req)
    if (authError || !user) {
      return errorResponse(authError ?? 'Unauthorized', status)
    }

    // 2. Rate limit — composite key user+device
    const deviceId = getDeviceId(req)
    const rlKey = buildRateLimitKey(user.id, deviceId)
    if (!checkCounterRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return errorResponse(
        'Terlalu banyak percobaan registrasi wajah. Coba lagi dalam 15 menit.',
        429
      )
    }

    // 3. Parse & validate body
    const body = await req.json()
    const parseResult = registerSchema.safeParse(body)

    if (!parseResult.success) {
      const firstError = parseResult.error.errors[0]?.message ?? 'Data tidak valid'
      return errorResponse(firstError, 400)
    }

    const { embedding } = parseResult.data

    // 4. Hash embedding for integrity
    const embeddingBuffer = Buffer.from(new Float64Array(embedding).buffer)
    const embeddingHash = crypto
      .createHash('sha256')
      .update(embeddingBuffer)
      .digest('hex')

    // 5. Upsert ke face_embeddings table
    const adminClient = createAdminClient()

    const { error: upsertError } = await adminClient
      .from('face_embeddings')
      .upsert(
        {
          user_id: user.id,
          embedding: embeddingBuffer.toString('base64'), // Store as base64 encoded BYTEA
          embedding_hash: embeddingHash,
          registered_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'user_id' }
      )

    if (upsertError) {
      console.error('[FACE REGISTER] Upsert error:', upsertError)
      return errorResponse('Gagal menyimpan data wajah. Coba lagi.', 500)
    }

    // 6. Update profiles.is_face_registered = true
    const { error: profileError } = await adminClient
      .from('profiles')
      .update({ is_face_registered: true })
      .eq('id', user.id)

    if (profileError) {
      console.error('[FACE REGISTER] Profile update error:', profileError)
      // Non-critical — embedding sudah tersimpan
    }

    // 7. Audit log
    const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    await logAudit({
      action: 'mobile_face_register',
      userId: user.id,
      ipAddress,
      details: {
        student_id: user.id,
        student_nim: user.nim_nip,
        embedding_length: embedding.length,
        embedding_hash: embeddingHash,
        device_id: deviceId,
        user_agent: req.headers.get('user-agent') ?? null,
      },
    })

    // 8. Response
    return successResponse({
      message: 'Wajah berhasil didaftarkan.',
      embedding_hash: embeddingHash,
    }, 201)
  } catch {
    return errorResponse('Terjadi kesalahan server.', 500)
  }
}
