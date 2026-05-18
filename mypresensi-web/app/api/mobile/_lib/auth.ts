// app/api/mobile/_lib/auth.ts
// Shared auth helper untuk semua mobile API endpoints.
// Validasi Bearer token dari header Authorization via Supabase Auth.
// Hanya mengizinkan role 'mahasiswa' yang aktif.

import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { createAdminClient } from '@/lib/supabase/server'
import { NextRequest } from 'next/server'

export interface AuthenticatedUser {
  id: string
  full_name: string
  nim_nip: string
  role: string
  semester: number | null
  kelas: string | null
  avatar_url: string | null
  is_face_registered: boolean
  is_active: boolean
}

interface AuthResult {
  user: AuthenticatedUser | null
  error: string | null
  status: number
}

/**
 * Validasi Bearer token dari request header.
 * Return user profile jika valid, atau error + status code.
 */
export async function authenticateRequest(req: NextRequest): Promise<AuthResult> {
  // 1. Extract Bearer token
  const authHeader = req.headers.get('authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return { user: null, error: 'Token tidak ditemukan. Sertakan header Authorization: Bearer <token>', status: 401 }
  }

  const token = authHeader.replace('Bearer ', '')

  // 2. Validate token via Supabase Auth
  // Gunakan supabase-js langsung (bukan SSR client) karena ini API Route, bukan Server Component
  const supabaseAuth = createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )

  const { data: { user: authUser }, error: authError } = await supabaseAuth.auth.getUser(token)

  if (authError || !authUser) {
    return { user: null, error: 'Token tidak valid atau sudah kedaluwarsa. Silakan login ulang.', status: 401 }
  }

  // 3. Fetch profile dari database
  const adminClient = createAdminClient()
  const { data: profile, error: profileError } = await adminClient
    .from('profiles')
    .select('id, full_name, nim_nip, role, semester, kelas, avatar_url, is_face_registered, is_active')
    .eq('id', authUser.id)
    .single()

  if (profileError || !profile) {
    return { user: null, error: 'Profil tidak ditemukan.', status: 404 }
  }

  // 4. Check role — hanya mahasiswa yang boleh akses mobile API
  if (profile.role !== 'mahasiswa') {
    return { user: null, error: 'Akses ditolak. API ini hanya untuk mahasiswa.', status: 403 }
  }

  // 5. Check akun aktif
  if (!profile.is_active) {
    return { user: null, error: 'Akun Anda dinonaktifkan. Hubungi admin.', status: 403 }
  }

  return {
    user: profile as AuthenticatedUser,
    error: null,
    status: 200,
  }
}

/**
 * Helper: JSON response standar untuk error.
 * errorCode opsional — dipakai mobile untuk distinguish kasus tertentu (mis. face_not_registered)
 * agar bisa tampilkan dialog redirect yang sesuai.
 */
export function errorResponse(message: string, status: number, errorCode?: string) {
  const body: Record<string, unknown> = { error: message }
  if (errorCode) body.error_code = errorCode
  return Response.json(body, { status })
}

/**
 * Helper: JSON response standar untuk success
 */
export function successResponse(data: Record<string, unknown>, status = 200) {
  return Response.json(data, { status })
}
