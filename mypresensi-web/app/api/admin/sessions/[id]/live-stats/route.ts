// app/api/admin/sessions/[id]/live-stats/route.ts
// Endpoint live stats untuk QR Display Fullscreen mode.
// Return jumlah mahasiswa hadir + total enrolled untuk satu sesi spesifik.
// Read-only — tidak ada audit log (read endpoint tidak audit untuk hindari spam).
//
// Security:
//   - Cookie session (web SSR) via requireRole(['admin','dosen'])
//   - Ownership check via canAccessCourse — dosen hanya bisa akses sesi MK miliknya
//   - Admin bypass ownership (global access)
//   - createAdminClient() dipanggil SETELAH auth + ownership check (defense in depth)
//   - Tidak expose Tier 1 fields (session_code, etc) di response
//   - Rate limit 60 req / 60 detik per (userId, sessionId) — polling normal 12 req/min
//     plus margin untuk multiple windows / refresh manual.

import { NextRequest, NextResponse } from 'next/server'
import { requireRole, canAccessCourse } from '@/lib/auth-guard'
import { createAdminClient } from '@/lib/supabase/server'
import {
  buildRateLimitKey,
  checkSlidingRateLimit,
} from '../../../../mobile/_lib/rate-limit'

// ===========================
// Rate Limiter (in-memory, per user+session)
// Sliding window: max 60 request per 60 detik per (userId, sessionId)
// ===========================
const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_CONFIG = { windowMs: 60_000, max: 60 }

interface RouteContext {
  params: Promise<{ id: string }>
}

export async function GET(req: NextRequest, ctx: RouteContext) {
  try {
    // 1. Auth — cookie session, role admin/dosen
    let user
    try {
      user = await requireRole(['admin', 'dosen'])
    } catch {
      return NextResponse.json(
        { error: 'Tidak terautentikasi' },
        { status: 401 },
      )
    }

    const { id: sessionId } = await ctx.params

    // 2. Rate limit — composite key (userId, sessionId)
    const rlKey = buildRateLimitKey(user.id, sessionId)
    if (!checkSlidingRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return NextResponse.json(
        { error: 'Terlalu banyak permintaan. Coba lagi sebentar lagi.' },
        { status: 429 },
      )
    }

    const adminClient = createAdminClient()

    // 3. Fetch session.course_id untuk ownership check
    const { data: session, error: sessionError } = await adminClient
      .from('sessions')
      .select('id, course_id')
      .eq('id', sessionId)
      .maybeSingle()

    if (sessionError) {
      return NextResponse.json(
        { error: 'Gagal mengambil data sesi.' },
        { status: 500 },
      )
    }

    if (!session) {
      return NextResponse.json(
        { error: 'Sesi tidak ditemukan.' },
        { status: 404 },
      )
    }

    // 4. Ownership check — dosen hanya bisa lihat sesi MK miliknya, admin bypass
    const allowed = await canAccessCourse(user.id, user.role, session.course_id)
    if (!allowed) {
      return NextResponse.json(
        { error: 'Tidak ada akses ke sesi ini.' },
        { status: 403 },
      )
    }

    // 5. Parallel fetch — hadir count + total enrolled
    const [hadirRes, totalRes] = await Promise.all([
      adminClient
        .from('attendances')
        .select('id', { count: 'exact', head: true })
        .eq('session_id', sessionId)
        .in('status', ['hadir', 'terlambat']),
      adminClient
        .from('enrollments')
        .select('id', { count: 'exact', head: true })
        .eq('course_id', session.course_id),
    ])

    if (hadirRes.error || totalRes.error) {
      return NextResponse.json(
        { error: 'Gagal mengambil statistik.' },
        { status: 500 },
      )
    }

    const hadir = hadirRes.count ?? 0
    const total = totalRes.count ?? 0

    // 6. Response — TANPA session_code atau field sensitif lain
    return NextResponse.json({ hadir, total }, { status: 200 })
  } catch {
    return NextResponse.json(
      { error: 'Terjadi kesalahan server.' },
      { status: 500 },
    )
  }
}
