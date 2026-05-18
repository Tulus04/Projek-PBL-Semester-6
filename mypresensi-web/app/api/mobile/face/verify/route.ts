// app/api/mobile/face/verify/route.ts
// Endpoint verifikasi wajah server-side — bandingkan live embedding (dari mobile)
// dengan stored embedding milik user di DB. Return match/similarity/threshold.
//
// SECURITY: Comparison dilakukan SERVER-SIDE sesuai rule 04-security-and-privacy
// Section B.2. Stored embedding TIDAK pernah keluar dari server. Mengganti
// pendekatan lama yang client-side (GET /face/embedding) yang sudah dihapus.
//
// Rate limit: 10 verify per menit per (userId + deviceId) — sliding window.
// Audit: setiap call (sukses maupun no-match) tercatat sebagai mobile_face_verify.

import { NextRequest } from 'next/server'
import { z } from 'zod'
import {
  authenticateRequest,
  errorResponse,
  successResponse,
} from '../../_lib/auth'
import {
  buildRateLimitKey,
  checkSlidingRateLimit,
  getDeviceId,
} from '../../_lib/rate-limit'
import {
  cosineSimilarity,
  decodeStoredEmbedding,
} from '../../_lib/face-utils'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'

// ===========================
// Zod Schema
// ===========================
// MobileFaceNet output exact 192-dim, L2-normalized → range [-1, 1].
// Strict length check melindungi dari mobile bug yang kirim wrong size.
const verifySchema = z.object({
  embedding: z
    .array(z.number().min(-1).max(1))
    .length(192, 'Format embedding tidak valid'),
})

// ===========================
// Rate Limiting (in-memory, per user+device)
// Sliding window: 10 verify per 60 detik per (userId, deviceId)
// ===========================
const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_CONFIG = { windowMs: 60_000, max: 10 }

// Default — sinkron dengan FaceEmbeddingService.defaultThreshold di mobile
// dan settings.face_confidence_threshold (migration 005).
const DEFAULT_THRESHOLD = 0.65

// ===========================
// POST — Verify Face Embedding
// ===========================
export async function POST(req: NextRequest) {
  try {
    // 1. Authenticate
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)
    const user = auth.user!

    const ipAddress =
      req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    const userAgent = req.headers.get('user-agent') ?? null
    const deviceId = getDeviceId(req)

    // 2. Rate limit — composite key user+device
    const rlKey = buildRateLimitKey(user.id, deviceId)
    if (!checkSlidingRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return errorResponse(
        'Terlalu banyak permintaan verifikasi wajah. Coba lagi dalam beberapa menit.',
        429,
      )
    }

    // 3. Parse & validate body
    const body = await req.json()
    const parsed = verifySchema.safeParse(body)
    if (!parsed.success) {
      const firstError =
        parsed.error.errors[0]?.message ?? 'Data tidak valid'
      return errorResponse(firstError, 400)
    }
    const { embedding: liveEmbedding } = parsed.data

    // 4. Cek user sudah register wajah (early gate sebelum query embedding)
    if (!user.is_face_registered) {
      return errorResponse('Wajah belum didaftarkan.', 404)
    }

    // 5. Fetch stored embedding
    const adminClient = createAdminClient()
    const { data: storedRow, error: fetchError } = await adminClient
      .from('face_embeddings')
      .select('embedding')
      .eq('user_id', user.id)
      .single()

    if (fetchError || !storedRow) {
      console.error('[FACE VERIFY] Fetch stored error:', fetchError)
      return errorResponse('Data wajah tidak ditemukan.', 404)
    }

    // 6. Decode stored embedding (base64 BYTEA → number[])
    let storedEmbedding: number[]
    try {
      storedEmbedding = decodeStoredEmbedding(storedRow.embedding as string)
    } catch (decodeErr) {
      console.error('[FACE VERIFY] Decode error:', decodeErr)
      return errorResponse(
        'Data wajah rusak. Silakan registrasi ulang.',
        500,
      )
    }

    // Sanity: pastikan dimensinya match dengan live embedding (192-d)
    if (storedEmbedding.length !== liveEmbedding.length) {
      console.error(
        `[FACE VERIFY] Dimension mismatch: stored=${storedEmbedding.length}, live=${liveEmbedding.length}`,
      )
      return errorResponse(
        'Format wajah tersimpan tidak kompatibel. Silakan registrasi ulang.',
        500,
      )
    }

    // 7. Fetch threshold dari settings (fallback ke default)
    let threshold = DEFAULT_THRESHOLD
    const { data: thresholdRow } = await adminClient
      .from('settings')
      .select('value')
      .eq('key', 'face_confidence_threshold')
      .maybeSingle()

    if (thresholdRow?.value) {
      const parsedThreshold = parseFloat(thresholdRow.value as string)
      if (
        !isNaN(parsedThreshold) &&
        parsedThreshold >= 0 &&
        parsedThreshold <= 1
      ) {
        threshold = parsedThreshold
      }
    }

    // 8. Hitung cosine similarity
    const similarity = cosineSimilarity(liveEmbedding, storedEmbedding)
    // Clamp 0..1 untuk display di mobile (negative similarity = wajah berbeda)
    const clamped = Math.max(0, Math.min(1, similarity))
    const matched = clamped >= threshold

    // 9. Audit log — JANGAN log embedding mentah, hanya hasil komputasi
    await logAudit({
      action: 'mobile_face_verify',
      userId: user.id,
      ipAddress,
      details: {
        student_id: user.id,
        student_nim: user.nim_nip,
        matched,
        similarity: Number(clamped.toFixed(4)),
        threshold,
        device_id: deviceId,
        user_agent: userAgent,
      },
    })

    // 10. Response
    return successResponse({
      match: matched,
      similarity: Number(clamped.toFixed(4)),
      threshold,
    })
  } catch (err) {
    console.error('[FACE VERIFY] Unexpected error:', err)
    return errorResponse('Terjadi kesalahan server.', 500)
  }
}
