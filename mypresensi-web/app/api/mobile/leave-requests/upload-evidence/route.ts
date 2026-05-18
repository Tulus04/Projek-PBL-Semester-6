// app/api/mobile/leave-requests/upload-evidence/route.ts
// Endpoint upload bukti izin/sakit — terima multipart file, validasi, place di
// bucket leave-evidence. Return path (bukan full URL) yang nanti dikirim
// mahasiswa di body POST submit.
//
// SECURITY:
// - Bearer JWT + role mahasiswa + is_active (authenticateRequest)
// - Mime + magic bytes validation (defense terhadap rename + spoof Content-Type)
// - File size limit 5 MB di endpoint + bucket-level
// - Rate limit 10 upload / 15 menit per (user + device)
// - Path generation pakai prefix userId → RLS gate via prefix berfungsi
// - Audit log mobile_leave_evidence_upload

import { NextRequest } from 'next/server'
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
  ALLOWED_IMAGE_MIME,
  MAX_IMAGE_SIZE_BYTES,
  generateEvidencePath,
  isAllowedImageMime,
  validateMagicBytes,
} from '../../_lib/storage-utils'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'

// Rate limit: max 10 upload per 15 menit per (user + device)
const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_CONFIG = { windowMs: 15 * 60_000, max: 10 }

const BUCKET_NAME = 'leave-evidence'

export async function POST(req: NextRequest) {
  try {
    // 1. AUTH
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)
    const user = auth.user!

    const ipAddress =
      req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    const userAgent = req.headers.get('user-agent') ?? null
    const deviceId = getDeviceId(req)

    // 2. RATE LIMIT
    const rlKey = buildRateLimitKey(user.id, deviceId)
    if (!checkSlidingRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return errorResponse(
        'Terlalu banyak upload. Coba lagi dalam 15 menit.',
        429,
      )
    }

    // 3. PARSE multipart
    let formData: FormData
    try {
      formData = await req.formData()
    } catch {
      return errorResponse('Format request tidak valid (harus multipart).', 400)
    }

    const fileEntry = formData.get('file')
    if (!(fileEntry instanceof Blob)) {
      return errorResponse('File tidak ditemukan dalam request.', 400)
    }

    // 4. VALIDATE size
    if (fileEntry.size === 0) {
      return errorResponse('File kosong.', 400)
    }
    if (fileEntry.size > MAX_IMAGE_SIZE_BYTES) {
      return errorResponse(
        `File terlalu besar. Maksimal ${MAX_IMAGE_SIZE_BYTES / 1024 / 1024} MB.`,
        400,
      )
    }

    // 5. VALIDATE mime
    const declaredMime = (fileEntry.type || '').toLowerCase()
    if (!isAllowedImageMime(declaredMime)) {
      return errorResponse(
        `Format file tidak didukung. Gunakan ${Array.from(ALLOWED_IMAGE_MIME).join(', ')}.`,
        400,
      )
    }

    // 6. VALIDATE magic bytes (defense in depth)
    const arrayBuffer = await fileEntry.arrayBuffer()
    const buffer = Buffer.from(arrayBuffer)
    if (!validateMagicBytes(buffer, declaredMime)) {
      return errorResponse(
        'Isi file tidak cocok dengan format yang diklaim. Gunakan file gambar yang valid.',
        400,
      )
    }

    // 7. GENERATE path & UPLOAD via service_role
    const path = generateEvidencePath(user.id, declaredMime)
    const adminClient = createAdminClient()

    const { error: uploadError } = await adminClient.storage
      .from(BUCKET_NAME)
      .upload(path, buffer, {
        contentType: declaredMime,
        upsert: false, // Prevent accidental overwrite
      })

    if (uploadError) {
      console.error('[LEAVE EVIDENCE UPLOAD] Storage error:', uploadError)
      return errorResponse(
        'Gagal mengunggah file. Coba lagi.',
        500,
      )
    }

    // 8. AUDIT
    await logAudit({
      action: 'mobile_leave_evidence_upload',
      userId: user.id,
      ipAddress,
      details: {
        student_id: user.id,
        student_nim: user.nim_nip,
        path,
        size: fileEntry.size,
        mime: declaredMime,
        device_id: deviceId,
        user_agent: userAgent,
      },
    })

    // 9. RESPONSE — return path saja (bukan full URL).
    // Mobile akan kirim path ini di body POST submit.
    return successResponse({ path }, 201)
  } catch (err) {
    console.error('[LEAVE EVIDENCE UPLOAD] Unexpected error:', err)
    return errorResponse('Terjadi kesalahan server.', 500)
  }
}
