// app/lib/auth-guard.ts
// Helper reusable untuk cek role dan ownership pada server actions & page-level.
// Defense-in-depth layer: setiap mutasi WAJIB validasi role sebelum eksekusi.

import { createClient, createAdminClient } from '@/lib/supabase/server'

export interface CurrentUser {
  id: string
  role: string
}

/**
 * Ambil profile (id + role) user yang sedang login.
 * Return null jika user belum login atau profile tidak ditemukan.
 */
export async function getCurrentUserProfile(): Promise<CurrentUser | null> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null

  const adminClient = createAdminClient()
  const { data: profile } = await adminClient
    .from('profiles')
    .select('id, role')
    .eq('id', user.id)
    .single()

  if (!profile) return null

  return { id: profile.id, role: profile.role }
}

/**
 * Validasi bahwa user memiliki salah satu role yang diizinkan.
 * Throw error jika tidak authorized — caller harus handle error.
 */
export async function requireRole(allowedRoles: string[]): Promise<CurrentUser> {
  const profile = await getCurrentUserProfile()
  if (!profile) {
    throw new Error('Unauthorized: user belum login')
  }
  if (!allowedRoles.includes(profile.role)) {
    throw new Error(`Unauthorized: role '${profile.role}' tidak diizinkan`)
  }
  return profile
}

/**
 * Validasi bahwa dosen memiliki ownership terhadap sebuah course.
 * Admin bypass ownership check (bisa akses semua).
 * Return true jika authorized, false jika tidak.
 */
export async function canAccessCourse(userId: string, role: string, courseId: string): Promise<boolean> {
  // Admin bisa akses semua course
  if (role === 'admin') return true

  // Dosen hanya bisa akses course yang dia ampu
  const adminClient = createAdminClient()
  const { data: course } = await adminClient
    .from('courses')
    .select('dosen_id')
    .eq('id', courseId)
    .single()

  return course?.dosen_id === userId
}
