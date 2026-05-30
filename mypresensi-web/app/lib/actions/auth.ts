// src/lib/actions/auth.ts
// Server Actions untuk autentikasi.
// Semua validasi dan auth logic ada di server — tidak ada di browser.

'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient, createAdminClient } from '@/lib/supabase/server'

// ============================================
// VALIDATION SCHEMAS (Zod)
// ============================================

const loginSchema = z.object({
  email: z
    .string()
    .min(1, 'Email wajib diisi')
    .email('Email tidak valid'),
  password: z
    .string()
    .min(1, 'Password wajib diisi')
    .min(6, 'Password minimal 6 karakter'),
})

const changePasswordSchema = z
  .object({
    newPassword: z
      .string()
      .min(8, 'Password minimal 8 karakter')
      .regex(/[A-Z]/, 'Wajib ada huruf kapital')
      .regex(/[0-9]/, 'Wajib ada angka'),
    confirmPassword: z.string().min(1, 'Konfirmasi password wajib diisi'),
  })
  .refine((data) => data.newPassword === data.confirmPassword, {
    message: 'Password tidak cocok',
    path: ['confirmPassword'],
  })

// ============================================
// ACTION: LOGIN
// ============================================

export type LoginState = {
  error: string | null
  fieldErrors?: {
    email?: string[]
    password?: string[]
  }
}

export async function loginAction(
  _prevState: LoginState,
  formData: FormData
): Promise<LoginState> {
  const raw = {
    email: formData.get('email') as string,
    password: formData.get('password') as string,
  }

  // Validasi input
  const parsed = loginSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Input tidak valid',
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  const supabase = createClient()

  const { error } = await supabase.auth.signInWithPassword({
    email: parsed.data.email,
    password: parsed.data.password,
  })

  if (error) {
    // Jangan expose detail error dari Supabase ke user
    if (error.message.includes('Invalid login credentials')) {
      return { error: 'Email atau password salah. Silakan coba lagi.' }
    }
    if (error.message.includes('Email not confirmed')) {
      return { error: 'Email belum dikonfirmasi. Hubungi admin.' }
    }
    return { error: 'Terjadi kesalahan. Silakan coba beberapa saat lagi.' }
  }

  revalidatePath('/', 'layout')
  redirect('/dashboard')
}

// ============================================
// ACTION: LOGOUT
// ============================================

export async function logoutAction() {
  const supabase = createClient()
  await supabase.auth.signOut()
  revalidatePath('/', 'layout')
  redirect('/login')
}

// ============================================
// ACTION: CHANGE PASSWORD (Force Change)
// ============================================

export type ChangePasswordState = {
  error: string | null
  success: boolean
  fieldErrors?: {
    newPassword?: string[]
    confirmPassword?: string[]
  }
}

export async function changePasswordAction(
  _prevState: ChangePasswordState,
  formData: FormData
): Promise<ChangePasswordState> {
  const raw = {
    newPassword: formData.get('newPassword') as string,
    confirmPassword: formData.get('confirmPassword') as string,
  }

  const parsed = changePasswordSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Input tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  const supabase = createClient()

  // Update password di Supabase Auth
  const { error: authError } = await supabase.auth.updateUser({
    password: parsed.data.newPassword,
  })

  if (authError) {
    // Supabase menolak jika password sama dengan sebelumnya
    if (authError.message.includes('same password') || authError.message.includes('different password')) {
      return {
        error: 'Password baru tidak boleh sama dengan password lama.',
        success: false,
      }
    }
    return {
      error: 'Gagal mengubah password. Silakan coba lagi.',
      success: false,
    }
  }

  // Update flag must_change_password di tabel profiles (pakai admin client bypass RLS)
  const { data: { user } } = await supabase.auth.getUser()
  if (user) {
    const adminClient = createAdminClient()
    await adminClient
      .from('profiles')
      .update({ must_change_password: false, updated_at: new Date().toISOString() })
      .eq('id', user.id)
  }

  revalidatePath('/', 'layout')
  redirect('/dashboard')
}
