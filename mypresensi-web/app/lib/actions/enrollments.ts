'use server'
// app/lib/actions/enrollments.ts
// Server Actions untuk manajemen pendaftaran mahasiswa ke mata kuliah.
// SECURITY: Semua action di-guard oleh requireRole + canAccessCourse (ownership check).

import { revalidatePath } from 'next/cache'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { requireRole, canAccessCourse } from '@/lib/auth-guard'

// Ambil semua mahasiswa yang terdaftar di suatu MK
export async function getEnrollmentsByCourse(courseId: string) {
  // SECURITY: Validasi akses — admin atau dosen pemilik MK
  let user
  try {
    user = await requireRole(['admin', 'dosen'])
  } catch {
    return { enrollments: [], error: 'Akses ditolak: Anda harus login terlebih dahulu.' }
  }

  const hasAccess = await canAccessCourse(user.id, user.role, courseId)
  if (!hasAccess) {
    return { enrollments: [], error: 'Akses ditolak: Anda tidak memiliki akses ke mata kuliah ini.' }
  }

  const supabase = createAdminClient()

  const { data, error } = await supabase
    .from('enrollments')
    .select('id, academic_year, student:profiles!student_id(id, full_name, nim_nip, kelas, semester)')
    .eq('course_id', courseId)
    .order('academic_year', { ascending: false })

  return { enrollments: data ?? [], error: error?.message ?? null }
}

// Ambil mahasiswa yang BELUM terdaftar di suatu MK (untuk dropdown tambah), difilter berdasarkan semester MK
export async function getAvailableStudents(courseId: string) {
  // SECURITY: Validasi akses
  let user
  try {
    user = await requireRole(['admin', 'dosen'])
  } catch {
    return { students: [], error: 'Akses ditolak: Anda harus login terlebih dahulu.' }
  }

  const hasAccess = await canAccessCourse(user.id, user.role, courseId)
  if (!hasAccess) {
    return { students: [], error: 'Akses ditolak: Anda tidak memiliki akses ke mata kuliah ini.' }
  }

  const supabase = createAdminClient()

  // Ambil data semester dari mata kuliah
  const { data: courseData, error: courseError } = await supabase
    .from('courses')
    .select('semester')
    .eq('id', courseId)
    .single()

  if (courseError || !courseData) {
    return { students: [], error: 'Gagal mendapatkan data mata kuliah.' }
  }
  
  const courseSemester = courseData.semester

  // Get already enrolled student IDs
  const { data: enrolled } = await supabase
    .from('enrollments')
    .select('student_id')
    .eq('course_id', courseId)

  const enrolledIds = (enrolled ?? []).map((e: { student_id: string }) => e.student_id)

  // Get all active mahasiswa from the same semester
  const query = supabase
    .from('profiles')
    .select('id, full_name, nim_nip, kelas, semester')
    .eq('role', 'mahasiswa')
    .eq('is_active', true)
    .eq('semester', courseSemester)
    .order('full_name')

  const { data: allStudents, error } = await query

  if (error) return { students: [], error: error.message }

  // Filter out already enrolled students
  const available = (allStudents ?? []).filter((s: { id: string }) => !enrolledIds.includes(s.id))
  return { students: available, error: null }
}

// Tambah mahasiswa ke MK
export async function addEnrollmentAction(courseId: string, studentIds: string[], academicYear: string = '2025/2026') {
  // SECURITY: Validasi akses
  let user
  try {
    user = await requireRole(['admin', 'dosen'])
  } catch {
    return { error: 'Akses ditolak: Anda harus login terlebih dahulu.', success: false }
  }

  const hasAccess = await canAccessCourse(user.id, user.role, courseId)
  if (!hasAccess) {
    return { error: 'Akses ditolak: Anda hanya dapat mengelola peserta mata kuliah yang Anda ampu.', success: false }
  }

  const supabase = createAdminClient()

  const rows = studentIds.map((sid) => ({
    course_id: courseId,
    student_id: sid,
    academic_year: academicYear,
  }))

  const { error } = await supabase.from('enrollments').insert(rows)

  if (error) return { error: error.message, success: false }

  await logAudit({
    action: 'add_enrollment',
    details: { course_id: courseId, student_ids: studentIds, count: studentIds.length, added_by: user.role },
  })

  revalidatePath('/matakuliah')
  return { error: null, success: true }
}

// Hapus mahasiswa dari MK
export async function removeEnrollmentAction(enrollmentId: string, courseId: string) {
  // SECURITY: Validasi akses
  let user
  try {
    user = await requireRole(['admin', 'dosen'])
  } catch {
    return { error: 'Akses ditolak: Anda harus login terlebih dahulu.', success: false }
  }

  const hasAccess = await canAccessCourse(user.id, user.role, courseId)
  if (!hasAccess) {
    return { error: 'Akses ditolak: Anda hanya dapat mengelola peserta mata kuliah yang Anda ampu.', success: false }
  }

  const supabase = createAdminClient()

  const { error } = await supabase.from('enrollments').delete().eq('id', enrollmentId)

  if (error) return { error: error.message, success: false }

  await logAudit({
    action: 'remove_enrollment',
    details: { enrollment_id: enrollmentId, course_id: courseId, removed_by: user.role },
  })

  revalidatePath('/matakuliah')
  return { error: null, success: true }
}
