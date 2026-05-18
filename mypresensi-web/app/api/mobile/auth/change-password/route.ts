// app/api/mobile/auth/change-password/route.ts
// Endpoint ganti password untuk mobile app mahasiswa.
// Memerlukan Bearer JWT — hanya user yang sudah login bisa akses.
// Setelah berhasil, set must_change_password = false di profiles.

import { NextRequest } from 'next/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { getDeviceId } from '../../_lib/rate-limit'
import { z } from 'zod'

const changePasswordSchema = z
  .object({
    newPassword: z
      .string()
      .min(8, 'Password baru minimal 8 karakter')
      .regex(/[A-Z]/, 'Harus mengandung minimal 1 huruf kapital')
      .regex(/[0-9]/, 'Harus mengandung minimal 1 angka'),
    confirmPassword: z.string().min(1, 'Konfirmasi password wajib diisi'),
  })
  .refine((data) => data.newPassword === data.confirmPassword, {
    message: 'Password tidak cocok',
    path: ['confirmPassword'],
  })

export async function POST(req: NextRequest) {
  try {
    // 1. Ambil Bearer token dari header
    const authHeader = req.headers.get('authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return Response.json(
        { error: 'Token tidak ditemukan. Silakan login ulang.' },
        { status: 401 }
      )
    }

    const token = authHeader.replace('Bearer ', '')

    // 2. Parse & validate body
    const body = await req.json()
    const parsed = changePasswordSchema.safeParse(body)

    if (!parsed.success) {
      const fieldErrors = parsed.error.flatten().fieldErrors
      const firstError =
        fieldErrors.newPassword?.[0] ??
        fieldErrors.confirmPassword?.[0] ??
        'Input tidak valid'
      return Response.json({ error: firstError }, { status: 400 })
    }

    // 3. Verifikasi token — buat Supabase client dengan token user
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
    const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

    const supabaseUser = createSupabaseClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      },
    })

    const {
      data: { user },
      error: userError,
    } = await supabaseUser.auth.getUser(token)

    if (userError || !user) {
      return Response.json(
        { error: 'Sesi tidak valid. Silakan login ulang.' },
        { status: 401 }
      )
    }

    // 4. Update password di Supabase Auth (via admin client)
    const adminClient = createAdminClient()

    const { error: updateError } = await adminClient.auth.admin.updateUserById(
      user.id,
      { password: parsed.data.newPassword }
    )

    if (updateError) {
      // Log full error untuk diagnose — JANGAN expose ke client.
      console.error('[CHANGE_PASSWORD] Supabase auth update error:', {
        userId: user.id,
        errorMessage: updateError.message,
        errorCode: updateError.code,
        errorStatus: updateError.status,
      })

      // Cek apakah password sama dengan yang lama
      if (updateError.message?.includes('same password')) {
        return Response.json(
          { error: 'Password baru tidak boleh sama dengan password lama.' },
          { status: 400 }
        )
      }
      // Cek apakah password lemah (Supabase HIBP / weak password check)
      if (
        updateError.message?.toLowerCase().includes('weak') ||
        updateError.message?.toLowerCase().includes('compromised') ||
        updateError.message?.toLowerCase().includes('pwned')
      ) {
        return Response.json(
          {
            error:
              'Password terlalu mudah ditebak atau pernah bocor. Pakai kombinasi unik (huruf besar + kecil + angka + simbol).',
          },
          { status: 400 }
        )
      }
      // Cek policy length minimum dari Supabase Auth (kalau dashboard set > 8)
      if (updateError.message?.toLowerCase().includes('password')) {
        return Response.json(
          { error: `Password tidak diterima: ${updateError.message}` },
          { status: 400 }
        )
      }
      return Response.json(
        { error: 'Gagal mengubah password. Silakan coba lagi.' },
        { status: 500 }
      )
    }

    // 5. Update must_change_password = false di profiles
    const { error: profileError } = await adminClient
      .from('profiles')
      .update({
        must_change_password: false,
        updated_at: new Date().toISOString(),
      })
      .eq('id', user.id)

    if (profileError) {
      // Password sudah berubah tapi flag gagal update — log error tapi jangan block user
      console.error('[CHANGE_PASSWORD] Failed to update profile flag:', profileError)
    }

    // 6. Audit log — capture device_id untuk forensic
    const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    await logAudit({
      action: 'mobile_change_password',
      userId: user.id,
      ipAddress,
      details: {
        user_id: user.id,
        email: user.email,
        device_id: getDeviceId(req),
        user_agent: req.headers.get('user-agent') ?? null,
      },
    })

    return Response.json({
      success: true,
      message: 'Password berhasil diubah.',
    })
  } catch {
    return Response.json(
      { error: 'Terjadi kesalahan server.' },
      { status: 500 }
    )
  }
}
