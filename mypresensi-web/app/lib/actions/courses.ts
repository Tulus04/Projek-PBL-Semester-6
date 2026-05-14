// app/lib/actions/courses.ts
// Server Actions untuk manajemen Mata Kuliah.
// Operasi CRUD berjalan di server dengan RLS bypass via adminClient.
// SECURITY: Admin = full CRUD. Dosen = CRUD hanya pada MK miliknya (ownership check).

'use server'

import { revalidatePath } from 'next/cache'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { requireRole, canAccessCourse } from '@/lib/auth-guard'

// ============================================
// VALIDATION SCHEMAS
// ============================================

const courseSchema = z.object({
  code: z
    .string()
    .min(3, 'Kode MK minimal 3 karakter')
    .max(20, 'Kode MK maksimal 20 karakter'),
  name: z
    .string()
    .min(3, 'Nama MK minimal 3 karakter')
    .max(100, 'Nama MK maksimal 100 karakter'),
  sks: z.coerce
    .number()
    .min(1, 'SKS minimal 1')
    .max(6, 'SKS maksimal 6'),
  semester: z.coerce
    .number()
    .min(1, 'Semester minimal 1')
    .max(8, 'Semester maksimal 8'),
  dosen_id: z.string().uuid('Dosen harus dipilih').optional().or(z.literal('')),
  academic_year: z.string().optional(),
})

export type CourseFormState = {
  error: string | null
  success: boolean
  fieldErrors?: Record<string, string[]>
}

// ============================================
// ACTION: GET ALL COURSES (with search, filter & pagination)
// ============================================

export async function getCourses({
  search = '',
  page = 1,
  perPage = 20,
  semester,
  dosenId,
}: {
  search?: string
  page?: number
  perPage?: number
  semester?: number
  dosenId?: string
} = {}) {
  const supabase = createAdminClient()
  const from = (page - 1) * perPage
  const to = from + perPage - 1

  let query = supabase
    .from('courses')
    .select('*, dosen:profiles!courses_dosen_id_fkey(id, full_name, nim_nip)', { count: 'exact' })
    .order('semester', { ascending: true })
    .order('code', { ascending: true })

  if (search) {
    query = query.or(`code.ilike.%${search}%,name.ilike.%${search}%`)
  }

  if (semester) {
    query = query.eq('semester', semester)
  }

  // Data isolation: dosen hanya lihat MK yang dia ampu
  if (dosenId) {
    query = query.eq('dosen_id', dosenId)
  }

  const { data, count, error } = await query.range(from, to)

  return {
    courses: data ?? [],
    total: count ?? 0,
    page,
    perPage,
    totalPages: Math.ceil((count ?? 0) / perPage),
    error: error?.message ?? null,
  }
}

// ============================================
// ACTION: GET ALL ACTIVE DOSEN (for dropdown)
// ============================================

export async function getActiveDosen() {
  const supabase = createAdminClient()

  const { data, error } = await supabase
    .from('profiles')
    .select('id, full_name, nim_nip')
    .eq('role', 'dosen')
    .eq('is_active', true)
    .order('full_name', { ascending: true })

  return {
    dosen: data ?? [],
    error: error?.message ?? null,
  }
}

// ============================================
// ACTION: ADD COURSE
// ============================================

export async function addCourseAction(
  _prevState: CourseFormState,
  formData: FormData
): Promise<CourseFormState> {
  // SECURITY: Admin dan Dosen boleh tambah MK
  let user
  try {
    user = await requireRole(['admin', 'dosen'])
  } catch {
    return { error: 'Akses ditolak: Anda tidak memiliki izin untuk menambah mata kuliah.', success: false }
  }

  const isAdmin = user.role === 'admin'

  const raw = {
    code: formData.get('code') as string,
    name: formData.get('name') as string,
    sks: formData.get('sks') as string,
    semester: formData.get('semester') as string,
    // Dosen: dosen_id otomatis di-set ke user sendiri (server-side enforcement)
    // Admin: bisa pilih dosen mana saja
    dosen_id: isAdmin ? ((formData.get('dosen_id') as string) || '') : user.id,
    academic_year: (formData.get('academic_year') as string) || '2025/2026',
  }

  const parsed = courseSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Data tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  const supabase = createAdminClient()

  // Cek apakah kode MK sudah ada
  const { data: existing } = await supabase
    .from('courses')
    .select('id')
    .eq('code', parsed.data.code)
    .single()

  if (existing) {
    return { error: `Kode MK "${parsed.data.code}" sudah terdaftar.`, success: false }
  }

  // Insert — dosen_id di-enforce server-side
  const { error: insertError } = await supabase.from('courses').insert({
    code: parsed.data.code,
    name: parsed.data.name,
    sks: parsed.data.sks,
    semester: parsed.data.semester,
    dosen_id: parsed.data.dosen_id || null,
    academic_year: parsed.data.academic_year || '2025/2026',
  })

  if (insertError) {
    return { error: `Gagal menambahkan: ${insertError.message}`, success: false }
  }

  await logAudit({ action: 'create_course', details: { code: parsed.data.code, name: parsed.data.name, created_by: user.role } })

  revalidatePath('/matakuliah')
  return { error: null, success: true }
}

// ============================================
// ACTION: UPDATE COURSE
// ============================================

export async function updateCourseAction(
  _prevState: CourseFormState,
  formData: FormData
): Promise<CourseFormState> {
  // SECURITY: Admin dan Dosen boleh edit MK (dosen hanya MK miliknya)
  let user
  try {
    user = await requireRole(['admin', 'dosen'])
  } catch {
    return { error: 'Akses ditolak: Anda tidak memiliki izin untuk mengedit mata kuliah.', success: false }
  }

  const courseId = formData.get('course_id') as string
  if (!courseId) return { error: 'ID mata kuliah diperlukan.', success: false }

  // SECURITY: Ownership check — dosen hanya bisa edit MK miliknya
  const hasAccess = await canAccessCourse(user.id, user.role, courseId)
  if (!hasAccess) {
    return { error: 'Akses ditolak: Anda hanya dapat mengedit mata kuliah yang Anda ampu.', success: false }
  }

  const isAdmin = user.role === 'admin'

  const raw = {
    code: formData.get('code') as string,
    name: formData.get('name') as string,
    sks: formData.get('sks') as string,
    semester: formData.get('semester') as string,
    // Dosen tidak bisa mengubah dosen_id (tetap dirinya sendiri)
    dosen_id: isAdmin ? ((formData.get('dosen_id') as string) || '') : user.id,
    academic_year: (formData.get('academic_year') as string) || '2025/2026',
  }

  const parsed = courseSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Data tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  const supabase = createAdminClient()

  // Cek kode duplikat (exclude diri sendiri)
  const { data: existing } = await supabase
    .from('courses')
    .select('id')
    .eq('code', parsed.data.code)
    .neq('id', courseId)
    .single()

  if (existing) {
    return { error: `Kode MK "${parsed.data.code}" sudah dipakai.`, success: false }
  }

  const { error: updateError } = await supabase
    .from('courses')
    .update({
      code: parsed.data.code,
      name: parsed.data.name,
      sks: parsed.data.sks,
      semester: parsed.data.semester,
      dosen_id: parsed.data.dosen_id || null,
      academic_year: parsed.data.academic_year || '2025/2026',
    })
    .eq('id', courseId)

  if (updateError) {
    return { error: `Gagal update: ${updateError.message}`, success: false }
  }

  await logAudit({ action: 'update_course', details: { course_id: courseId, code: parsed.data.code, name: parsed.data.name, updated_by: user.role } })

  revalidatePath('/matakuliah')
  return { error: null, success: true }
}

// ============================================
// ACTION: TOGGLE ACTIVE STATUS
// ============================================

export async function toggleCourseStatusAction(
  courseId: string,
  isActive: boolean
) {
  // SECURITY: Admin dan Dosen boleh toggle status (dosen hanya MK miliknya)
  let user
  try {
    user = await requireRole(['admin', 'dosen'])
  } catch {
    return { error: 'Akses ditolak: Anda tidak memiliki izin untuk mengubah status mata kuliah.' }
  }

  // SECURITY: Ownership check
  const hasAccess = await canAccessCourse(user.id, user.role, courseId)
  if (!hasAccess) {
    return { error: 'Akses ditolak: Anda hanya dapat mengubah status mata kuliah yang Anda ampu.' }
  }

  const supabase = createAdminClient()

  const { error } = await supabase
    .from('courses')
    .update({ is_active: isActive })
    .eq('id', courseId)

  if (error) return { error: error.message }

  await logAudit({ action: 'toggle_course_status', details: { course_id: courseId, is_active: isActive, toggled_by: user.role } })

  revalidatePath('/matakuliah')
  return { error: null }
}
