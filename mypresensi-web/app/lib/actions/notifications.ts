'use server'
// app/lib/actions/notifications.ts
// Server Actions untuk sistem notifikasi in-app.
// Mengelola fetch, mark-read, dan create notifikasi.
// Menggunakan createAdminClient() untuk semua operasi database.

import { createAdminClient, createClient } from '@/lib/supabase/server'
import type { NotificationType } from '@/types/database'

// ==========================================
// TIPE DATA NOTIFIKASI (internal)
// ==========================================

export interface NotificationItem {
  id: string
  title: string
  message: string
  type: NotificationType
  href: string | null
  is_read: boolean
  created_at: string
}

// ==========================================
// FETCH NOTIFIKASI
// ==========================================

/**
 * Ambil daftar notifikasi user yang sedang login.
 * Default limit 20, terbaru pertama.
 */
export async function getNotifications(limit = 20): Promise<{
  notifications: NotificationItem[]
  error: string | null
}> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) return { notifications: [], error: 'Unauthorized' }

  const adminClient = createAdminClient()
  const { data, error } = await adminClient
    .from('notifications')
    .select('id, title, message, type, href, is_read, created_at')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(limit)

  if (error) return { notifications: [], error: error.message }

  return { notifications: (data ?? []) as NotificationItem[], error: null }
}

/**
 * Hitung jumlah notifikasi belum dibaca untuk badge counter.
 */
export async function getUnreadCount(): Promise<number> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) return 0

  const adminClient = createAdminClient()
  const { count } = await adminClient
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .eq('is_read', false)

  return count ?? 0
}

// ==========================================
// MARK AS READ
// ==========================================

/**
 * Tandai satu notifikasi sebagai sudah dibaca.
 */
export async function markAsRead(notificationId: string): Promise<{ error: string | null }> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) return { error: 'Unauthorized' }

  const adminClient = createAdminClient()
  const { error } = await adminClient
    .from('notifications')
    .update({ is_read: true })
    .eq('id', notificationId)
    .eq('user_id', user.id) // Pastikan user hanya bisa update miliknya

  return { error: error?.message ?? null }
}

/**
 * Tandai semua notifikasi user sebagai sudah dibaca.
 */
export async function markAllAsRead(): Promise<{ error: string | null }> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) return { error: 'Unauthorized' }

  const adminClient = createAdminClient()
  const { error } = await adminClient
    .from('notifications')
    .update({ is_read: true })
    .eq('user_id', user.id)
    .eq('is_read', false)

  return { error: error?.message ?? null }
}

// ==========================================
// CREATE NOTIFIKASI (helper internal)
// ==========================================

/**
 * Helper untuk membuat notifikasi dari server actions lain.
 * Dipanggil setelah event penting terjadi.
 */
export async function createNotification({
  userId,
  title,
  message,
  type = 'info',
  href,
}: {
  userId: string
  title: string
  message: string
  type?: NotificationType
  href?: string
}): Promise<void> {
  const adminClient = createAdminClient()

  await adminClient.from('notifications').insert({
    user_id: userId,
    title,
    message,
    type,
    href: href ?? null,
  })
}

/**
 * Helper untuk membuat notifikasi ke banyak user sekaligus.
 * Contoh: notifikasi sesi dimulai ke semua mahasiswa enrolled.
 */
export async function createBulkNotifications(
  notifications: {
    userId: string
    title: string
    message: string
    type?: NotificationType
    href?: string
  }[]
): Promise<void> {
  if (notifications.length === 0) return

  const adminClient = createAdminClient()

  const rows = notifications.map((n) => ({
    user_id: n.userId,
    title: n.title,
    message: n.message,
    type: n.type ?? 'info',
    href: n.href ?? null,
  }))

  await adminClient.from('notifications').insert(rows)
}
