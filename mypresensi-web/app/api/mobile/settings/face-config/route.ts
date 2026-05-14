// app/api/mobile/settings/face-config/route.ts
// Endpoint baca konfigurasi face recognition (threshold + mode) dari tabel settings.
// Read-only — tidak butuh rate limit ketat & tidak butuh audit log.
// Mobile cache di FutureProvider 1 jam, fallback ke default jika gagal.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'

// Default values — sinkron dengan FaceEmbeddingService.defaultThreshold di mobile
const DEFAULT_THRESHOLD = 0.65
const DEFAULT_MODE: 'optional' | 'required' = 'optional'

export async function GET(req: NextRequest) {
  try {
    // 1. AUTH — semua mahasiswa aktif boleh baca
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)

    // 2. Fetch dari settings table
    const supabase = createAdminClient()
    const { data, error } = await supabase
      .from('settings')
      .select('key, value')
      .in('key', ['face_confidence_threshold', 'face_verification_mode'])

    if (error) {
      // Fallback ke default jika DB error — jangan blokir face flow
      return successResponse({
        confidence_threshold: DEFAULT_THRESHOLD,
        verification_mode: DEFAULT_MODE,
        source: 'fallback',
      })
    }

    // 3. Parse hasil
    const settingsMap = new Map<string, string>()
    for (const row of data ?? []) {
      settingsMap.set(row.key, row.value)
    }

    // Parse threshold (string → float)
    const thresholdRaw = settingsMap.get('face_confidence_threshold')
    let confidence_threshold = DEFAULT_THRESHOLD
    if (thresholdRaw) {
      const parsed = parseFloat(thresholdRaw)
      if (!isNaN(parsed) && parsed >= 0 && parsed <= 1) {
        confidence_threshold = parsed
      }
    }

    // Parse mode (string enum)
    const modeRaw = settingsMap.get('face_verification_mode')
    let verification_mode: 'optional' | 'required' = DEFAULT_MODE
    if (modeRaw === 'required' || modeRaw === 'optional') {
      verification_mode = modeRaw
    }

    return successResponse({
      confidence_threshold,
      verification_mode,
      source: 'database',
    })
  } catch {
    return errorResponse('Terjadi kesalahan server.', 500)
  }
}
