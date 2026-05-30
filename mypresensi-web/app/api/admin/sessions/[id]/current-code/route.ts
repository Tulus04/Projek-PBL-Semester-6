// app/api/admin/sessions/[id]/current-code/route.ts
// Endpoint admin/dosen — return current rolling QR code untuk projector polling.
// Phase 3 v7 Rolling QR TOTP-like (Component 3 + Algorithm 4 di design.md).
//
// Security:
//   - Cookie session via requireRole(['admin','dosen']) — mahasiswa REJECTED
//   - Ownership check via canAccessCourse — dosen hanya MK miliknya, admin bypass
//   - createAdminClient() dipanggil SETELAH auth + ownership check (defense in depth)
//   - JANGAN expose `session_code_seed` di response apa pun (Tier 1 secret)
//   - JANGAN log seed ke console / audit log
//   - TIDAK rate-limited — dosen-only akses, polling 5s = 12 req/min ≪ threshold (R5.13)
//
// Konsumen utama:
//   - `(qr-projector)/sesi/[id]/qr/qr-display-client.tsx` (fullscreen polling)
//   - `(dashboard)/sesi/session-list.tsx` (modal kompak polling)

import { NextRequest, NextResponse } from 'next/server'
import { requireRole, canAccessCourse } from '@/lib/auth-guard'
import { createAdminClient } from '@/lib/supabase/server'
import {
  generateCode,
  getCurrentWindow,
  msUntilNextWindow,
} from '@/lib/utils/totp'

interface RouteContext {
  params: Promise<{ id: string }>
}

interface SessionRow {
  id: string
  course_id: string
  is_active: boolean
  session_code: string | null
  session_code_seed: string | null
  session_code_expires_at: string | null
}

const NO_STORE_HEADERS = { 'Cache-Control': 'no-store' } as const

export async function GET(_req: NextRequest, ctx: RouteContext) {
  try {
    // 1. Auth — cookie session, role admin/dosen wajib
    let user
    try {
      user = await requireRole(['admin', 'dosen'])
    } catch {
      return NextResponse.json(
        { error: 'Tidak terautentikasi' },
        { status: 401, headers: NO_STORE_HEADERS },
      )
    }

    const { id: sessionId } = await ctx.params

    const adminClient = createAdminClient()

    // 2. Fetch session row — JANGAN return seed di response, tapi butuh untuk compute
    const { data: session, error: sessionError } = (await adminClient
      .from('sessions')
      .select(
        'id, course_id, is_active, session_code, session_code_seed, session_code_expires_at',
      )
      .eq('id', sessionId)
      .maybeSingle()) as { data: SessionRow | null; error: unknown }

    if (sessionError) {
      return NextResponse.json(
        { error: 'Terjadi kesalahan server' },
        { status: 500, headers: NO_STORE_HEADERS },
      )
    }

    if (!session) {
      return NextResponse.json(
        { error: 'Sesi tidak ditemukan' },
        { status: 404, headers: NO_STORE_HEADERS },
      )
    }

    // 3. Ownership check — dosen hanya sesi MK miliknya, admin bypass
    const allowed = await canAccessCourse(user.id, user.role, session.course_id)
    if (!allowed) {
      return NextResponse.json(
        { error: 'Akses ditolak' },
        { status: 403, headers: NO_STORE_HEADERS },
      )
    }

    // 4. Sesi tidak aktif → 410 Gone
    if (!session.is_active) {
      return NextResponse.json(
        { error: 'Sesi sudah berakhir' },
        { status: 410, headers: NO_STORE_HEADERS },
      )
    }

    // 5. Branch rolling vs legacy
    if (session.session_code_seed) {
      // Rolling mode — compute fresh TOTP code dari seed + current window.
      // CATATAN KEAMANAN: variabel `seed` lokal scope, tidak boleh masuk response/log.
      const seed = session.session_code_seed
      const currentWindow = getCurrentWindow()
      const currentCode = generateCode(seed, currentWindow)
      const ttlMs = msUntilNextWindow()

      // Best-effort cache update — sessions.session_code di-sync untuk konsistensi
      // dengan UI consumer lama. Tidak blocking, tidak throw kalau gagal.
      try {
        await adminClient
          .from('sessions')
          .update({ session_code: currentCode })
          .eq('id', sessionId)
      } catch {
        // sengaja swallow — cache update opsional, response tetap lanjut
      }

      return NextResponse.json(
        {
          current_code: currentCode,
          window: currentWindow,
          ttl_ms_until_next: ttlMs,
          is_rolling: true,
          is_active: true,
          expires_at: null,
        },
        { status: 200, headers: NO_STORE_HEADERS },
      )
    }

    // Legacy mode — return existing static value tanpa compute
    return NextResponse.json(
      {
        current_code: session.session_code,
        window: null,
        ttl_ms_until_next: 0,
        is_rolling: false,
        is_active: true,
        expires_at: session.session_code_expires_at,
      },
      { status: 200, headers: NO_STORE_HEADERS },
    )
  } catch {
    return NextResponse.json(
      { error: 'Terjadi kesalahan server' },
      { status: 500, headers: NO_STORE_HEADERS },
    )
  }
}
