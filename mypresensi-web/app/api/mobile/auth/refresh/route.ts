// app/api/mobile/auth/refresh/route.ts
// Endpoint untuk refresh token session mahasiswa (mobile).
// Verifikasi refresh_token via Supabase Auth, kembalikan access_token + refresh_token baru.
// Menerapkan profil check untuk memastikan akun mahasiswa masih aktif.

import { NextRequest } from 'next/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { createAdminClient } from '@/lib/supabase/server'
import { z } from 'zod'

const refreshSchema = z.object({
  refresh_token: z.string().min(1, 'Refresh token required'),
})

export async function POST(req: NextRequest) {
  try {
    // 1. Parse & validate body
    const body = await req.json()
    const parsed = refreshSchema.safeParse(body)

    if (!parsed.success) {
      return Response.json({ error: 'Refresh token tidak valid.' }, { status: 400 })
    }

    const { refresh_token } = parsed.data

    // 2. Hubungi Supabase Auth untuk merotasi/refresh token
    const supabase = createSupabaseClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    )

    const { data: authData, error: authError } = await supabase.auth.refreshSession({
      refresh_token,
    })

    if (authError || !authData.session || !authData.user) {
      return Response.json(
        { error: 'Sesi berakhir. Silakan login ulang.' },
        { status: 401 }
      )
    }

    // 3. Verifikasi profil di database (early gate jika dinonaktifkan)
    const adminClient = createAdminClient()
    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('id, role, is_active')
      .eq('id', authData.user.id)
      .single()

    if (profileError || !profile) {
      return Response.json({ error: 'Profil tidak ditemukan.' }, { status: 404 })
    }

    // 4. Validasi role mahasiswa
    if (profile.role !== 'mahasiswa') {
      return Response.json(
        { error: 'Akses ditolak. API ini hanya untuk mahasiswa.' },
        { status: 403 }
      )
    }

    // 5. Validasi akun aktif
    if (!profile.is_active) {
      return Response.json(
        { error: 'Akun Anda dinonaktifkan. Hubungi admin.' },
        { status: 403 }
      )
    }

    // 6. Return token baru
    return Response.json({
      access_token: authData.session.access_token,
      refresh_token: authData.session.refresh_token,
      expires_at: authData.session.expires_at,
    })
  } catch (err) {
    console.error('[AUTH REFRESH] Unexpected error:', err)
    return Response.json({ error: 'Terjadi kesalahan server.' }, { status: 500 })
  }
}
