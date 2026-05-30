// app/api/mobile/notifications/route.ts
// Endpoint notifikasi in-app untuk mahasiswa.
// Return daftar notifikasi + unread count.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'

export async function GET(req: NextRequest) {
  const auth = await authenticateRequest(req)
  if (auth.error) return errorResponse(auth.error, auth.status)

  const user = auth.user!
  const adminClient = createAdminClient()

  // Parse limit param
  const limitParam = req.nextUrl.searchParams.get('limit')
  const limit = Math.min(Math.max(parseInt(limitParam ?? '20', 10) || 20, 1), 100)

  // 1. Ambil notifikasi
  const { data: notifications, error } = await adminClient
    .from('notifications')
    .select('id, title, message, type, href, is_read, created_at')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(limit)

  if (error) {
    return errorResponse('Gagal mengambil notifikasi', 500)
  }

  // 2. Hitung unread count
  const { count } = await adminClient
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .eq('is_read', false)

  return successResponse({
    notifications: notifications ?? [],
    unread_count: count ?? 0,
  })
}
