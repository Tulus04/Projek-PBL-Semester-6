// app/lib/actions/students.ts
// Server Actions untuk manajemen data mahasiswa.
// Semua operasi CRUD berjalan di server — tidak ada di browser.

'use server'

import { revalidatePath } from 'next/cache'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'

// ============================================
// VALIDATION SCHEMAS
// ============================================

const studentSchema = z.object({
  full_name: z.string().min(3, 'Nama minimal 3 karakter').max(100),
  nim_nip: z
    .string()
    .min(5, 'NIM minimal 5 karakter')
    .max(20, 'NIM maksimal 20 karakter'),
  email: z.string().email('Email tidak valid'),
  semester: z.coerce.number().min(1).max(14).optional(),
  kelas: z.string().max(10).optional(),
  phone: z.string().max(20).optional(),
})

export type StudentFormState = {
  error: string | null
  success: boolean
  fieldErrors?: Record<string, string[]>
}

// ============================================
// ACTION: GET ALL STUDENTS (with search & pagination)
// ============================================

export async function getStudents({
  search = '',
  page = 1,
  perPage = 20,
  semester,
  kelas,
}: {
  search?: string
  page?: number
  perPage?: number
  semester?: number
  kelas?: string
} = {}) {
  const supabase = createAdminClient()
  const from = (page - 1) * perPage
  const to = from + perPage - 1

  let query = supabase
    .from('profiles')
    .select('*', { count: 'exact' })
    .eq('role', 'mahasiswa')
    .order('full_name', { ascending: true })

  if (search) {
    query = query.or(`full_name.ilike.%${search}%,nim_nip.ilike.%${search}%`)
  }

  if (semester) {
    query = query.eq('semester', semester)
  }

  if (kelas) {
    query = query.eq('kelas', kelas)
  }

  const { data, count, error } = await query.range(from, to)

  // Fetch emails from auth.users untuk setiap mahasiswa
  let studentsWithEmail = data ?? []
  if (data && data.length > 0) {
    const emailMap = new Map<string, string>()
    for (const s of data) {
      const { data: authUser } = await supabase.auth.admin.getUserById(s.id)
      if (authUser?.user?.email) {
        emailMap.set(s.id, authUser.user.email)
      }
    }
    studentsWithEmail = data.map((s) => ({
      ...s,
      email: emailMap.get(s.id) ?? null,
    }))
  }

  return {
    students: studentsWithEmail,
    total: count ?? 0,
    page,
    perPage,
    totalPages: Math.ceil((count ?? 0) / perPage),
    error: error?.message ?? null,
  }
}

// ============================================
// ACTION: ADD STUDENT
// ============================================

export async function addStudentAction(
  _prevState: StudentFormState,
  formData: FormData
): Promise<StudentFormState> {
  const raw = {
    full_name: formData.get('full_name') as string,
    nim_nip: formData.get('nim_nip') as string,
    email: formData.get('email') as string,
    semester: formData.get('semester') ? Number(formData.get('semester')) : undefined,
    kelas: (formData.get('kelas') as string) || undefined,
    phone: (formData.get('phone') as string) || undefined,
  }

  const parsed = studentSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Data tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  const supabase = createAdminClient()

  // Cek apakah NIM sudah terdaftar
  const { data: existing } = await supabase
    .from('profiles')
    .select('id')
    .eq('nim_nip', parsed.data.nim_nip)
    .single()

  if (existing) {
    return { error: `NIM ${parsed.data.nim_nip} sudah terdaftar.`, success: false }
  }

  // Buat user di Supabase Auth (password default: NIM@Politani)
  const defaultPassword = `${parsed.data.nim_nip}@Politani`

  const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
    email: parsed.data.email,
    password: defaultPassword,
    email_confirm: true,
    user_metadata: {
      full_name: parsed.data.full_name,
      nim_nip: parsed.data.nim_nip,
      role: 'mahasiswa',
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
      semester: parsed.data.semester ?? null,
      kelas: parsed.data.kelas ?? null,
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

  await logAudit({ action: 'create_student', details: { full_name: parsed.data.full_name, nim_nip: parsed.data.nim_nip } })

  revalidatePath('/mahasiswa')
  return { error: null, success: true }
}

// ============================================
// ACTION: UPDATE STUDENT
// ============================================

export async function updateStudentAction(
  _prevState: StudentFormState,
  formData: FormData
): Promise<StudentFormState> {
  const studentId = formData.get('student_id') as string
  if (!studentId) return { error: 'ID mahasiswa diperlukan.', success: false }

  const raw = {
    full_name: formData.get('full_name') as string,
    nim_nip: formData.get('nim_nip') as string,
    email: formData.get('email') as string,
    semester: formData.get('semester') ? Number(formData.get('semester')) : undefined,
    kelas: (formData.get('kelas') as string) || undefined,
    phone: (formData.get('phone') as string) || undefined,
  }

  const parsed = studentSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Data tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  const supabase = createAdminClient()

  // Cek NIM duplikat (exclude diri sendiri)
  const { data: existing } = await supabase
    .from('profiles')
    .select('id')
    .eq('nim_nip', parsed.data.nim_nip)
    .neq('id', studentId)
    .single()

  if (existing) {
    return { error: `NIM ${parsed.data.nim_nip} sudah dipakai mahasiswa lain.`, success: false }
  }

  // Update profile
  const updateData: Record<string, unknown> = {
    full_name: parsed.data.full_name,
    nim_nip: parsed.data.nim_nip,
    semester: parsed.data.semester ?? null,
    kelas: parsed.data.kelas ?? null,
    phone: parsed.data.phone ?? null,
  }

  // Upload avatar jika ada
  const avatarFile = formData.get('avatar') as File | null
  if (avatarFile && avatarFile.size > 0) {
    const avatarUrl = await uploadAvatar(supabase, studentId, avatarFile)
    if (avatarUrl) {
      updateData.avatar_url = avatarUrl
    }
  }

  const { error: updateError } = await supabase
    .from('profiles')
    .update(updateData)
    .eq('id', studentId)

  if (updateError) {
    return { error: `Gagal update: ${updateError.message}`, success: false }
  }

  // Update email di auth jika berubah
  await supabase.auth.admin.updateUserById(studentId, {
    email: parsed.data.email,
  })

  await logAudit({ action: 'update_student', details: { student_id: studentId, full_name: parsed.data.full_name } })

  revalidatePath('/mahasiswa')
  return { error: null, success: true }
}

// ============================================
// ACTION: TOGGLE ACTIVE STATUS
// ============================================

export async function toggleStudentStatusAction(
  studentId: string,
  isActive: boolean
) {
  const supabase = createAdminClient()

  const { error } = await supabase
    .from('profiles')
    .update({ is_active: isActive })
    .eq('id', studentId)

  if (error) return { error: error.message }

  await logAudit({ action: 'toggle_student_status', details: { student_id: studentId, is_active: isActive } })

  revalidatePath('/mahasiswa')
  return { error: null }
}

// ============================================
// ACTION: RESET PASSWORD
// ============================================

export async function resetStudentPasswordAction(studentId: string, nimNip: string) {
  const supabase = createAdminClient()
  const defaultPassword = `${nimNip}@Politani`

  const { error } = await supabase.auth.admin.updateUserById(studentId, {
    password: defaultPassword,
  })

  if (error) return { error: error.message }

  // Set must_change_password = true agar dipaksa ganti saat login
  await supabase
    .from('profiles')
    .update({ must_change_password: true })
    .eq('id', studentId)

  await logAudit({ action: 'reset_student_password', details: { student_id: studentId, nim_nip: nimNip } })

  revalidatePath('/mahasiswa')
  return { error: null }
}

// ============================================
// ACTION: IMPORT CSV (Batch Add Students)
// ============================================

export async function importStudentsCSVAction(
  _prevState: StudentFormState,
  formData: FormData
): Promise<StudentFormState & { imported?: number; skipped?: number }> {
  const csvText = formData.get('csv_data') as string

  if (!csvText?.trim()) {
    return { error: 'Data CSV kosong.', success: false }
  }

  const lines = csvText.trim().split('\n').filter(l => l.trim())
  
  // Skip header jika ada
  const startIdx = lines[0].toLowerCase().includes('nama') ? 1 : 0
  
  const supabase = createAdminClient()
  let imported = 0
  let skipped = 0
  const errors: string[] = []

  for (let i = startIdx; i < lines.length; i++) {
    const cols = lines[i].split(',').map(c => c.trim())
    
    if (cols.length < 3) {
      errors.push(`Baris ${i + 1}: format tidak valid (minimal: nama,nim,email)`)
      skipped++
      continue
    }

    const [full_name, nim_nip, email, semester, kelas, phone] = cols

    // Validasi basic
    if (!full_name || !nim_nip || !email) {
      errors.push(`Baris ${i + 1}: data tidak lengkap`)
      skipped++
      continue
    }

    // Cek NIM sudah ada
    const { data: existing } = await supabase
      .from('profiles')
      .select('id')
      .eq('nim_nip', nim_nip)
      .single()

    if (existing) {
      skipped++
      continue
    }

    // Buat user
    const defaultPassword = `${nim_nip}@Politani`
    const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
      email,
      password: defaultPassword,
      email_confirm: true,
      user_metadata: { full_name, nim_nip, role: 'mahasiswa' },
    })

    if (authError) {
      skipped++
      continue
    }

    // Update profile tambahan
    if (authUser?.user) {
      await supabase
        .from('profiles')
        .update({
          semester: semester ? parseInt(semester) : null,
          kelas: kelas || null,
          phone: phone || null,
          must_change_password: true,
        })
        .eq('id', authUser.user.id)
    }

    imported++
  }

  revalidatePath('/mahasiswa')

  if (imported === 0 && skipped > 0) {
    return {
      error: `Tidak ada data yang berhasil diimpor. ${errors[0] || 'Cek format CSV.'}`,
      success: false,
      imported: 0,
      skipped,
    }
  }

  if (imported > 0) {
    await logAudit({ action: 'import_students_csv', details: { imported, skipped } })
  }

  return {
    error: null,
    success: true,
    imported,
    skipped,
  }
}

// ============================================
// ACTION: DELETE STUDENT
// ============================================

export async function deleteStudentAction(studentId: string) {
  const supabase = createAdminClient()

  // Hapus avatar dari storage jika ada
  await supabase.storage
    .from('avatars')
    .remove([`${studentId}.jpg`])

  // Hapus user dari auth (profile akan otomatis terhapus via cascade)
  const { error } = await supabase.auth.admin.deleteUser(studentId)

  if (error) {
    return { error: `Gagal menghapus mahasiswa: ${error.message}` }
  }

  await logAudit({ action: 'delete_student', details: { student_id: studentId } })

  revalidatePath('/mahasiswa')
  return { error: null }
}

// ============================================
// HELPER: Upload Avatar
// ============================================

async function uploadAvatar(
  supabase: ReturnType<typeof createAdminClient>,
  userId: string,
  file: File
): Promise<string | null> {
  const filePath = `${userId}.jpg`

  const { error } = await supabase.storage
    .from('avatars')
    .upload(filePath, file, {
      upsert: true,
      contentType: 'image/jpeg',
    })

  if (error) {
    console.error('Avatar upload error:', error)
    return null
  }

  const { data: publicUrl } = supabase.storage
    .from('avatars')
    .getPublicUrl(filePath)

  // Append timestamp to bust cache
  return `${publicUrl.publicUrl}?t=${Date.now()}`
}
