'use server'
// app/lib/actions/profile.ts
// Server Actions untuk manajemen profil user (self-service).
// Semua role (admin, dosen, mahasiswa) bisa mengedit profil sendiri.

import { revalidatePath } from 'next/cache'
import { z } from 'zod'
import { createClient, createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'

// ============================================
// HELPER: Upload avatar ke Supabase Storage
// ============================================
async function uploadAvatar(
  supabase: ReturnType<typeof createAdminClient>,
  userId: string,
  avatarFile: File | Blob
): Promise<string | null> {
  const fileExt = 'jpg'
  const filePath = `${userId}.${fileExt}`

  const arrayBuffer = await avatarFile.arrayBuffer()
  const fileBuffer = new Uint8Array(arrayBuffer)

  const { error: uploadError } = await supabase.storage
    .from('avatars')
    .upload(filePath, fileBuffer, {
      contentType: 'image/jpeg',
      cacheControl: '3600',
      upsert: true,
    })

  if (uploadError) {
    console.error('Upload avatar error:', uploadError)
    return null
  }

  const { data: urlData } = supabase.storage
    .from('avatars')
    .getPublicUrl(filePath)

  return urlData?.publicUrl ?? null
}

// ============================================
// VALIDATION SCHEMAS
// ============================================
const profileSchema = z.object({
  full_name: z.string().min(3, 'Nama minimal 3 karakter').max(100, 'Nama maksimal 100 karakter'),
  phone: z.string().max(20, 'Nomor telepon terlalu panjang').optional().or(z.literal('')),
})

const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1, 'Password lama wajib diisi'),
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
// Types
// ============================================
export type ProfileFormState = {
  error: string | null
  success: boolean
  fieldErrors?: Record<string, string[]>
}

// ============================================
// ACTION: Ambil profil user yang sedang login
// ============================================
export async function getMyProfile() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) return { error: 'Tidak terautentikasi', profile: null, email: null }

  const adminClient = createAdminClient()
  const { data: profile, error } = await adminClient
    .from('profiles')
    .select('id, full_name, nim_nip, role, phone, avatar_url, semester, kelas, is_active, created_at')
    .eq('id', user.id)
    .single()

  return {
    error: error?.message ?? null,
    profile,
    email: user.email ?? null,
  }
}

// ============================================
// ACTION: Update profil (nama, telepon, avatar)
// ============================================
export async function updateProfileAction(formData: FormData): Promise<ProfileFormState> {
  // 1. Autentikasi — pastikan user login
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return { error: 'Sesi telah berakhir. Silakan login ulang.', success: false }
  }

  // 2. Validasi input
  const raw = {
    full_name: formData.get('full_name') as string,
    phone: (formData.get('phone') as string) || '',
  }

  const parsed = profileSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Data tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  const adminClient = createAdminClient()

  // 3. Handle avatar upload jika ada
  const avatarFile = formData.get('avatar') as File | null
  let avatarUrl: string | null | undefined = undefined // undefined = tidak berubah

  if (avatarFile && avatarFile.size > 0) {
    // Validasi ukuran file (max 2MB)
    if (avatarFile.size > 2 * 1024 * 1024) {
      return { error: 'Ukuran foto maksimal 2MB.', success: false }
    }
    avatarUrl = await uploadAvatar(adminClient, user.id, avatarFile)
    if (!avatarUrl) {
      return { error: 'Gagal mengupload foto profil.', success: false }
    }
  }

  // 4. Update profil di database
  const updateData: Record<string, string | undefined> = {
    full_name: parsed.data.full_name,
    phone: parsed.data.phone || undefined,
  }

  if (avatarUrl !== undefined) {
    updateData.avatar_url = avatarUrl
  }

  const { error: updateError } = await adminClient
    .from('profiles')
    .update(updateData)
    .eq('id', user.id)

  if (updateError) {
    return { error: `Gagal menyimpan profil: ${updateError.message}`, success: false }
  }

  // 5. Audit log
  await logAudit({
    action: 'update_own_profile',
    details: {
      full_name: parsed.data.full_name,
      phone: parsed.data.phone,
      avatar_changed: avatarUrl !== undefined,
    },
  })

  revalidatePath('/', 'layout')
  return { error: null, success: true }
}

// ============================================
// ACTION: Ganti password (self-service)
// ============================================
export async function changeOwnPasswordAction(formData: FormData): Promise<ProfileFormState> {
  // 1. Validasi input
  const raw = {
    currentPassword: formData.get('currentPassword') as string,
    newPassword: formData.get('newPassword') as string,
    confirmPassword: formData.get('confirmPassword') as string,
  }

  const parsed = changePasswordSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Data tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  // 2. Verifikasi password lama dengan cara re-login
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user?.email) {
    return { error: 'Sesi telah berakhir. Silakan login ulang.', success: false }
  }

  const { error: verifyError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password: parsed.data.currentPassword,
  })

  if (verifyError) {
    return { error: 'Password lama salah.', success: false }
  }

  // 3. Update password baru
  const { error: updateError } = await supabase.auth.updateUser({
    password: parsed.data.newPassword,
  })

  if (updateError) {
    if (updateError.message.includes('same password') || updateError.message.includes('different password')) {
      return { error: 'Password baru tidak boleh sama dengan password lama.', success: false }
    }
    return { error: 'Gagal mengubah password. Silakan coba lagi.', success: false }
  }

  // 4. Audit log
  await logAudit({
    action: 'change_own_password',
    details: { user_id: user.id },
  })

  return { error: null, success: true }
}
