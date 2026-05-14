// app/api/mobile/auth/login/route.ts
// Endpoint login untuk mobile app mahasiswa.
// Validasi kredensial via Supabase Auth, return access_token + user profile.
// Hanya mengizinkan role 'mahasiswa' yang aktif dan sudah ganti password.

import { NextRequest } from 'next/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { getDeviceId } from '../../_lib/rate-limit'
import { z } from 'zod'

const loginSchema = z.object({
  email: z.string().email('Format email tidak valid'),
  password: z.string().min(6, 'Password minimal 6 karakter'),
})

export async function POST(req: NextRequest) {
  try {
    // 1. Parse & validate body
    const body = await req.json()
    const parsed = loginSchema.safeParse(body)

    if (!parsed.success) {
      const firstError = parsed.error.errors[0]?.message ?? 'Input tidak valid'
      return Response.json({ error: firstError }, { status: 400 })
    }

    const { email, password } = parsed.data

    // 2. Login via Supabase Auth
    const supabase = createSupabaseClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    )

    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    if (authError || !authData.session) {
      return Response.json(
        { error: 'Email atau password salah.' },
        { status: 401 }
      )
    }

    // 3. Fetch profile
    const adminClient = createAdminClient()
    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('id, full_name, nim_nip, role, semester, kelas, phone, avatar_url, is_face_registered, is_active, must_change_password')
      .eq('id', authData.user.id)
      .single()

    if (profileError || !profile) {
      return Response.json({ error: 'Profil tidak ditemukan.' }, { status: 404 })
    }

    // 4. Validasi role — hanya mahasiswa
    if (profile.role !== 'mahasiswa') {
      return Response.json(
        { error: 'Akses ditolak. Aplikasi mobile hanya untuk mahasiswa.' },
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

    // 6. Audit log — capture device_id untuk forensic
    const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    await logAudit({
      action: 'mobile_login',
      userId: profile.id,
      ipAddress,
      details: {
        user_id: profile.id,
        nim: profile.nim_nip,
        must_change_password: profile.must_change_password,
        device_id: getDeviceId(req),
        user_agent: req.headers.get('user-agent') ?? null,
      },
    })

    // 7. Return token + profile + must_change_password flag
    // Mobile app akan redirect ke ChangePasswordScreen jika must_change_password = true
    return Response.json({
      access_token: authData.session.access_token,
      refresh_token: authData.session.refresh_token,
      expires_at: authData.session.expires_at,
      must_change_password: profile.must_change_password ?? false,
      user: {
        id: profile.id,
        full_name: profile.full_name,
        nim_nip: profile.nim_nip,
        role: profile.role,
        semester: profile.semester,
        kelas: profile.kelas,
        phone: profile.phone,
        avatar_url: profile.avatar_url,
        is_face_registered: profile.is_face_registered,
      },
    })
  } catch {
    return Response.json({ error: 'Terjadi kesalahan server.' }, { status: 500 })
  }
}
