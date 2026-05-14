// app/api/mobile/face/embedding/route.ts
// Endpoint untuk mengambil embedding wajah yang sudah diregistrasi.
// Hanya bisa akses embedding milik sendiri — dijaga oleh auth.
// Digunakan oleh mobile app untuk face verification on-device.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'

// ===========================
// GET — Retrieve Stored Face Embedding
// ===========================
export async function GET(req: NextRequest) {
  try {
    // 1. Authenticate
    const { user, error: authError, status } = await authenticateRequest(req)
    if (authError || !user) {
      return errorResponse(authError ?? 'Unauthorized', status)
    }

    // 2. Check apakah sudah register wajah
    if (!user.is_face_registered) {
      return errorResponse('Wajah belum didaftarkan.', 404)
    }

    // 3. Fetch embedding dari database
    const adminClient = createAdminClient()

    const { data, error: fetchError } = await adminClient
      .from('face_embeddings')
      .select('embedding, embedding_hash, registered_at')
      .eq('user_id', user.id)
      .single()

    if (fetchError || !data) {
      console.error('[FACE EMBEDDING] Fetch error:', fetchError)
      return errorResponse('Data wajah tidak ditemukan.', 404)
    }

    // 4. Decode embedding dari base64 BYTEA ke number array
    let embeddingArray: number[] = []
    try {
      const buffer = Buffer.from(data.embedding, 'base64')
      const float64 = new Float64Array(buffer.buffer, buffer.byteOffset, buffer.byteLength / 8)
      embeddingArray = Array.from(float64)
    } catch (decodeError) {
      console.error('[FACE EMBEDDING] Decode error:', decodeError)
      return errorResponse('Gagal memproses data wajah. Silakan registrasi ulang.', 500)
    }

    // 5. Response
    return successResponse({
      embedding: embeddingArray,
      embedding_hash: data.embedding_hash,
      registered_at: data.registered_at,
    })
  } catch {
    return errorResponse('Terjadi kesalahan server.', 500)
  }
}
