// app/lib/actions/dosen.ts
// Server Actions untuk manajemen data dosen.
// Semua operasi CRUD berjalan di server — tidak ada di browser.

'use server'

import { revalidatePath } from 'next/cache'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/server'
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

  // Convert Blob/File ke ArrayBuffer untuk upload
  const arrayBuffer = await avatarFile.arrayBuffer()
  const fileBuffer = new Uint8Array(arrayBuffer)

  const { error: uploadError } = await supabase.storage
    .from('avatars')
    .upload(filePath, fileBuffer, {
      contentType: 'image/jpeg',
      cacheControl: '3600',
      upsert: true, // Overwrite jika sudah ada
    })

  if (uploadError) {
    console.error('Upload avatar error:', uploadError)
    return null
  }

  // Dapatkan public URL
  const { data: urlData } = supabase.storage
    .from('avatars')
    .getPublicUrl(filePath)

  return urlData?.publicUrl ?? null
}

// ============================================
// VALIDATION SCHEMAS
// ============================================

const dosenSchema = z.object({
  full_name: z.string().min(3, 'Nama minimal 3 karakter').max(100),
  nim_nip: z
    .string()
    .min(5, 'NIP minimal 5 karakter')
    .max(30, 'NIP maksimal 30 karakter'),
  email: z.string().email('Email tidak valid'),
  phone: z.string().max(20).optional(),
})

export type DosenFormState = {
  error: string | null
  success: boolean
  fieldErrors?: Record<string, string[]>
}

// ============================================
// ACTION: GET ALL DOSEN (with search & pagination)
// ============================================

export async function getDosen({
  search = '',
  page = 1,
  perPage = 20,
}: {
  search?: string
  page?: number
  perPage?: number
} = {}) {
  const supabase = createAdminClient()
  const from = (page - 1) * perPage
  const to = from + perPage - 1

  let query = supabase
    .from('profiles')
    .select('*', { count: 'exact' })
    .eq('role', 'dosen')
    .order('full_name', { ascending: true })

  if (search) {
    query = query.or(`full_name.ilike.%${search}%,nim_nip.ilike.%${search}%`)
  }

  const { data, count, error } = await query.range(from, to)

  // Fetch emails from auth.users untuk setiap dosen
  let dosenWithEmail = data ?? []
  if (data && data.length > 0) {
    const emailMap = new Map<string, string>()
    
    // Batch fetch user emails via admin API
    for (const d of data) {
      const { data: authUser } = await supabase.auth.admin.getUserById(d.id)
      if (authUser?.user?.email) {
        emailMap.set(d.id, authUser.user.email)
      }
    }

    dosenWithEmail = data.map((d) => ({
      ...d,
      email: emailMap.get(d.id) ?? null,
    }))
  }

  return {
    dosen: dosenWithEmail,
    total: count ?? 0,
    page,
    perPage,
    totalPages: Math.ceil((count ?? 0) / perPage),
    error: error?.message ?? null,
  }
}

// ============================================
// ACTION: ADD DOSEN
// ============================================

export async function addDosenAction(
  _prevState: DosenFormState,
  formData: FormData
): Promise<DosenFormState> {
  const raw = {
    full_name: formData.get('full_name') as string,
    nim_nip: formData.get('nim_nip') as string,
    email: formData.get('email') as string,
    phone: (formData.get('phone') as string) || undefined,
  }

  const parsed = dosenSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Data tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  const supabase = createAdminClient()

  // Cek apakah NIP sudah terdaftar
  const { data: existing } = await supabase
    .from('profiles')
    .select('id')
    .eq('nim_nip', parsed.data.nim_nip)
    .single()

  if (existing) {
    return { error: `NIP ${parsed.data.nim_nip} sudah terdaftar.`, success: false }
  }

  // Buat user di Supabase Auth (password default: NIP@Politani)
  const defaultPassword = `${parsed.data.nim_nip}@Politani`

  const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
    email: parsed.data.email,
    password: defaultPassword,
    email_confirm: true,
    user_metadata: {
      full_name: parsed.data.full_name,
      nim_nip: parsed.data.nim_nip,
      role: 'dosen',
    },
  })

  if (authError) {
    if (authError.message.includes('already been registered')) {
      return { error: 'Email sudah terdaftar di sistem.', success: false }
    }
    return { error: `Gagal membuat akun: ${authError.message}`, success: false }
  }

  // Update profile fields yang tidak masuk via metadata
  if (authUser?.user) {
    const updateData: Record<string, unknown> = {
      phone: parsed.data.phone ?? null,
      must_change_password: true,
    }

    // Upload avatar jika ada
    const avatarFile = formData.get('avatar') as File | null
    if (avatarFile && avatarFile.size > 0) {
      const avatarUrl = await uploadAvatar(supabase, authUser.user.id, avatarFile)
      if (avatarUrl) {
        updateData.avatar_url = avatarUrl
      }
    }

    await supabase
      .from('profiles')
      .update(updateData)
      .eq('id', authUser.user.id)
  }

  await logAudit({ action: 'create_dosen', details: { full_name: parsed.data.full_name, nim_nip: parsed.data.nim_nip } })

  revalidatePath('/dosen')
  return { error: null, success: true }
}

// ============================================
// ACTION: UPDATE DOSEN
// ============================================

export async function updateDosenAction(
  _prevState: DosenFormState,
  formData: FormData
): Promise<DosenFormState> {
  const dosenId = formData.get('dosen_id') as string
  if (!dosenId) return { error: 'ID dosen diperlukan.', success: false }

  const raw = {
    full_name: formData.get('full_name') as string,
    nim_nip: formData.get('nim_nip') as string,
    email: formData.get('email') as string,
    phone: (formData.get('phone') as string) || undefined,
  }

  const parsed = dosenSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Data tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  const supabase = createAdminClient()

  // Cek NIP duplikat (exclude diri sendiri)
  const { data: existing } = await supabase
    .from('profiles')
    .select('id')
    .eq('nim_nip', parsed.data.nim_nip)
    .neq('id', dosenId)
    .single()

  if (existing) {
    return { error: `NIP ${parsed.data.nim_nip} sudah dipakai dosen lain.`, success: false }
  }

  // Siapkan data update
  const updateData: Record<string, unknown> = {
    full_name: parsed.data.full_name,
    nim_nip: parsed.data.nim_nip,
    phone: parsed.data.phone ?? null,
  }

  // Upload avatar jika ada
  const avatarFile = formData.get('avatar') as File | null
  if (avatarFile && avatarFile.size > 0) {
    const avatarUrl = await uploadAvatar(supabase, dosenId, avatarFile)
    if (avatarUrl) {
      updateData.avatar_url = avatarUrl
    }
  }

  // Update profile
  const { error: updateError } = await supabase
    .from('profiles')
    .update(updateData)
    .eq('id', dosenId)

  if (updateError) {
    return { error: `Gagal update: ${updateError.message}`, success: false }
  }

  // Update email di auth jika berubah
  await supabase.auth.admin.updateUserById(dosenId, {
    email: parsed.data.email,
  })

  await logAudit({ action: 'update_dosen', details: { dosen_id: dosenId, full_name: parsed.data.full_name } })

  revalidatePath('/dosen')
  return { error: null, success: true }
}

// ============================================
// ACTION: TOGGLE ACTIVE STATUS
// ============================================

export async function toggleDosenStatusAction(
  dosenId: string,
  isActive: boolean
) {
  const supabase = createAdminClient()

  const { error } = await supabase
    .from('profiles')
    .update({ is_active: isActive })
    .eq('id', dosenId)

  if (error) return { error: error.message }

  await logAudit({ action: 'toggle_dosen_status', details: { dosen_id: dosenId, is_active: isActive } })

  revalidatePath('/dosen')
  return { error: null }
}

// ============================================
// ACTION: RESET PASSWORD
// ============================================

export async function resetDosenPasswordAction(dosenId: string, nimNip: string) {
  const supabase = createAdminClient()
  const defaultPassword = `${nimNip}@Politani`

  const { error } = await supabase.auth.admin.updateUserById(dosenId, {
    password: defaultPassword,
  })

  if (error) return { error: error.message }

  // Set must_change_password = true agar dipaksa ganti saat login
  await supabase
    .from('profiles')
    .update({ must_change_password: true })
    .eq('id', dosenId)

  await logAudit({ action: 'reset_dosen_password', details: { dosen_id: dosenId, nim_nip: nimNip } })

  revalidatePath('/dosen')
  return { error: null }
}

// ============================================
// ACTION: DELETE DOSEN
// ============================================

export async function deleteDosenAction(dosenId: string) {
  const supabase = createAdminClient()

  // Hapus avatar dari storage jika ada
  await supabase.storage
    .from('avatars')
    .remove([`${dosenId}.jpg`])

  // Hapus user dari auth (profile akan otomatis terhapus via cascade)
  const { error } = await supabase.auth.admin.deleteUser(dosenId)

  if (error) {
    return { error: `Gagal menghapus dosen: ${error.message}` }
  }

  await logAudit({ action: 'delete_dosen', details: { dosen_id: dosenId } })

  revalidatePath('/dosen')
  return { error: null }
}
