// app/api/mobile/face/me/route.ts
// Endpoint untuk mahasiswa hapus data wajahnya sendiri (UU PDP Pasal 5-15 — hak hapus).
//
// Hanya menerima DELETE method (RESTful). Setelah hapus:
//   1. Row di `face_embeddings` dihapus (cascade saat user di-delete juga,
//      tapi ini self-delete saat akun masih aktif).
//   2. `profiles.is_face_registered` di-set false → user perlu register ulang
//      kalau mau verifikasi wajah lagi (saat sesi face_verification_mode=required).
//   3. Audit log `mobile_face_delete` mencatat aksi + device_id untuk forensic.
//
// Rate limit ketat: max 3 delete per jam per device — cegah spam audit log.
//
// Security:
//   - WAJIB Bearer JWT (authenticateRequest); user hanya bisa hapus miliknya sendiri.
//   - Pesan error generik (tidak bocor struktur DB).

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

// Rate limit: max 3 delete per jam per (user + device).
// Counter window — strict, karena ini operasi destruktif.
const rateLimitMap = new Map<string, CounterRateLimitEntry>()
const RATE_LIMIT_CONFIG = { windowMs: 60 * 60_000, max: 3 }

export async function DELETE(req: NextRequest) {
  try {
    // 1. Auth
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)
    const user = auth.user!

    const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    const userAgent = req.headers.get('user-agent') ?? null
    const deviceId = getDeviceId(req)

    // 2. Rate limit — composite key user+device
    const rlKey = buildRateLimitKey(user.id, deviceId)
    if (!checkCounterRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return errorResponse(
        'Terlalu banyak permintaan hapus data wajah. Coba lagi dalam 1 jam.',
        429,
      )
    }

    const adminClient = createAdminClient()

    // 3. Cek apakah memang ada embedding tersimpan
    const { data: existing } = await adminClient
      .from('face_embeddings')
      .select('id, embedding_hash, registered_at')
      .eq('user_id', user.id)
      .maybeSingle()

    if (!existing) {
      return errorResponse('Wajah belum didaftarkan', 404)
    }

    // 4. Hapus row di face_embeddings (HARD DELETE — UU PDP hak hapus)
    const { error: deleteError } = await adminClient
      .from('face_embeddings')
      .delete()
      .eq('user_id', user.id)

    if (deleteError) {
      console.error('[FACE DELETE] Delete error:', deleteError)
      return errorResponse('Gagal menghapus data wajah', 500)
    }

    // 5. Update flag profiles.is_face_registered = false
    const { error: profileError } = await adminClient
      .from('profiles')
      .update({ is_face_registered: false })
      .eq('id', user.id)

    if (profileError) {
      // Non-kritis — embedding sudah terhapus. Log tapi tidak block.
      console.error('[FACE DELETE] Profile flag update error:', profileError)
    }

    // 6. Audit log — WAJIB lengkap karena ini operasi sensitif (data biometrik)
    await logAudit({
      action: 'mobile_face_delete',
      userId: user.id,
      ipAddress,
      details: {
        student_id: user.id,
        student_nim: user.nim_nip,
        // Catat hash embedding lama (bukan embedding) untuk forensic — jika user klaim
        // "saya tidak hapus", admin bisa verifikasi via hash di audit lama.
        previous_embedding_hash: existing.embedding_hash,
        previously_registered_at: existing.registered_at,
        device_id: deviceId,
        user_agent: userAgent,
      },
    })

    // 7. Response
    return successResponse({
      success: true,
      message: 'Data wajah berhasil dihapus',
    }, 200)
  } catch (err) {
    console.error('[FACE DELETE] Unexpected error:', err)
    return errorResponse('Terjadi kesalahan server', 500)
  }
}
