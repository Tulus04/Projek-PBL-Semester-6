// app/api/mobile/profile/route.ts
// Endpoint profil mahasiswa yang sedang login.
// Return data profil lengkap dari tabel profiles.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../_lib/auth'

export async function GET(req: NextRequest) {
  const auth = await authenticateRequest(req)
  if (auth.error) return errorResponse(auth.error, auth.status)

  const user = auth.user!

  return successResponse({
    id: user.id,
    full_name: user.full_name,
    nim_nip: user.nim_nip,
    role: user.role,
    semester: user.semester,
    kelas: user.kelas,
    avatar_url: user.avatar_url,
    is_face_registered: user.is_face_registered,
  })
}
