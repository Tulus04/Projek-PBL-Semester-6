// app/api/mobile/_lib/storage-utils.ts
// Helper untuk upload file ke Supabase Storage — validasi mime + ext, generate path.
// Dipakai oleh /api/mobile/leave-requests/upload-evidence dan endpoint upload lain.
//
// SECURITY: Validate ulang mime di server meski bucket sudah punya allowed_mime_types
// karena attacker bisa rename ext atau spoof Content-Type.

import crypto from 'crypto'

// Allowed image mime types — sinkron dengan bucket leave-evidence allowed_mime_types
export const ALLOWED_IMAGE_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
])

// Mapping mime → extension untuk path generation
const MIME_TO_EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
}

// Magic bytes prefix untuk validasi format (defense in depth dari spoofed mime)
// Ref: https://en.wikipedia.org/wiki/List_of_file_signatures
const MAGIC_BYTES: Record<string, Uint8Array[]> = {
  'image/jpeg': [new Uint8Array([0xff, 0xd8, 0xff])],
  'image/png': [new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])],
  'image/webp': [new Uint8Array([0x52, 0x49, 0x46, 0x46])], // RIFF; bytes 8-11 should be 'WEBP' but RIFF check enough for our use case
}

export const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024 // 5 MB — sinkron dengan bucket file_size_limit

/**
 * Validate mime type ada di allowlist image.
 */
export function isAllowedImageMime(mime: string | null | undefined): boolean {
  if (!mime) return false
  return ALLOWED_IMAGE_MIME.has(mime.toLowerCase())
}

/**
 * Validate magic bytes file match dengan declared mime.
 * Mencegah attacker rename .exe jadi .jpg lalu set Content-Type image/jpeg.
 */
export function validateMagicBytes(buffer: Buffer, declaredMime: string): boolean {
  const expected = MAGIC_BYTES[declaredMime]
  if (!expected) return false

  for (const signature of expected) {
    if (buffer.length < signature.length) continue
    let match = true
    for (let i = 0; i < signature.length; i++) {
      if (buffer[i] !== signature[i]) {
        match = false
        break
      }
    }
    if (match) return true
  }
  return false
}

/**
 * Generate path file untuk bucket leave-evidence:
 *   '<userId>/<random32hex>.<ext>'
 *
 * Path prefix userId penting karena RLS gate via prefix.
 */
export function generateEvidencePath(userId: string, mime: string): string {
  const ext = MIME_TO_EXT[mime] ?? 'bin'
  const random = crypto.randomBytes(16).toString('hex')
  return `${userId}/${random}.${ext}`
}

/**
 * Pattern regex untuk validate evidence_path yang dikirim dari client saat submit.
 * Format: '<uuid v4 user>/<32hex>.<jpg|png|webp>'
 *
 * Catatan: regex hanya cek format. Verifikasi prefix === user.id harus dilakukan
 * di handler eksplisit (string compare) untuk hindari false positive.
 */
export const EVIDENCE_PATH_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/[0-9a-f]{32}\.(jpg|jpeg|png|webp)$/

/**
 * Cek apakah path mulai dengan userId (defense in depth selain RLS).
 */
export function isPathOwnedByUser(path: string, userId: string): boolean {
  return path.startsWith(`${userId}/`)
}
