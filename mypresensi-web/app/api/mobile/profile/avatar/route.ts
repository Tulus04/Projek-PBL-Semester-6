// app/api/mobile/profile/avatar/route.ts
// Endpoint mahasiswa upload foto avatar profil-nya sendiri.
//
// Bucket: 'avatars' (public, sudah ada sejak migration awal).
// Path convention: '<user.id>.jpg' (upsert — replace foto lama otomatis).
// Setelah upload, server update kolom profiles.avatar_url ke public URL Supabase.
//
// Pola yang sama dipakai web Server Action `uploadAvatar` di app/lib/actions/profile.ts.
// Kita reuse bucket existing untuk hindari duplication.
//
// SECURITY:
// - Bearer JWT + role mahasiswa + is_active (authenticateRequest)
// - Magic bytes validation (defense terhadap rename + spoof Content-Type)
// - File size limit 5 MB
// - Rate limit 5 upload / 10 menit per (user + device)
// - Path locked ke user.id (mahasiswa A tidak bisa replace avatar mahasiswa B)
// - Audit log mobile_avatar_upload

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
  isAllowedImageMime,
  validateMagicBytes,
} from '../../_lib/storage-utils'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'

// Rate limit: max 5 upload per 10 menit per (user + device)
const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_CONFIG = { windowMs: 10 * 60_000, max: 5 }

const BUCKET_NAME = 'avatars'

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
        'Terlalu banyak upload avatar. Coba lagi dalam 10 menit.',
        429,
      )
    }

    // 3. PARSE multipart
    let formData: FormData
    try {
      formData = await req.formData()
    } catch {
      return errorResponse('Format request tidak valid', 400)
    }

    const fileEntry = formData.get('file')
    if (!(fileEntry instanceof Blob)) {
      return errorResponse('File tidak ditemukan', 400)
    }

    // 4. VALIDATE size
    if (fileEntry.size === 0) {
      return errorResponse('File kosong', 400)
    }
    if (fileEntry.size > MAX_IMAGE_SIZE_BYTES) {
      return errorResponse(
        `Foto terlalu besar. Maksimal ${MAX_IMAGE_SIZE_BYTES / 1024 / 1024} MB.`,
        400,
      )
    }

    // 5. VALIDATE mime
    const declaredMime = (fileEntry.type || '').toLowerCase()
    if (!isAllowedImageMime(declaredMime)) {
      return errorResponse(
        `Format foto tidak didukung. Gunakan ${Array.from(ALLOWED_IMAGE_MIME).join(', ')}.`,
        400,
      )
    }

    // 6. VALIDATE magic bytes
    const arrayBuffer = await fileEntry.arrayBuffer()
    const buffer = Buffer.from(arrayBuffer)
    if (!validateMagicBytes(buffer, declaredMime)) {
      return errorResponse(
        'Isi file tidak cocok dengan format yang diklaim. Gunakan file gambar yang valid.',
        400,
      )
    }

    // 7. UPLOAD via service_role.
    // Path '<user.id>.jpg' — sama dengan pola web (upsert true → replace foto lama otomatis).
    // Selalu store sebagai .jpg karena bucket policy avatars bukan path-prefix-locked.
    const path = `${user.id}.jpg`
    const adminClient = createAdminClient()

    const { error: uploadError } = await adminClient.storage
      .from(BUCKET_NAME)
      .upload(path, buffer, {
        contentType: declaredMime,
        cacheControl: '3600',
        upsert: true, // Replace foto lama
      })

    if (uploadError) {
      console.error('[AVATAR UPLOAD] Storage error:', uploadError)
      return errorResponse('Gagal mengunggah foto', 500)
    }

    // 8. Generate public URL + cache buster
    const { data: urlData } = adminClient.storage
      .from(BUCKET_NAME)
      .getPublicUrl(path)

    if (!urlData?.publicUrl) {
      return errorResponse('Gagal mendapatkan URL foto', 500)
    }

    // Tambah cache-busting query agar mobile yang sudah cache URL lama dapat versi baru
    const publicUrlWithBuster = `${urlData.publicUrl}?t=${Date.now()}`

    // 9. UPDATE profiles.avatar_url
    const { error: updateError } = await adminClient
      .from('profiles')
      .update({ avatar_url: publicUrlWithBuster })
      .eq('id', user.id)

    if (updateError) {
      console.error('[AVATAR UPLOAD] Profile update error:', updateError)
      // Non-fatal — file sudah ke-upload. Tetap return URL ke client agar UI update.
    }

    // 10. AUDIT
    await logAudit({
      action: 'mobile_avatar_upload',
      userId: user.id,
      ipAddress,
      details: {
        student_id: user.id,
        student_nim: user.nim_nip,
        size: fileEntry.size,
        mime: declaredMime,
        device_id: deviceId,
        user_agent: userAgent,
      },
    })

    // 11. RESPONSE
    return successResponse(
      {
        avatar_url: publicUrlWithBuster,
        message: 'Foto profil berhasil diperbarui',
      },
      200,
    )
  } catch (err) {
    console.error('[AVATAR UPLOAD] Unexpected error:', err)
    return errorResponse('Terjadi kesalahan server', 500)
  }
}
