'use server'
// app/lib/audit-logger.ts
// Utility untuk mencatat aktivitas ke tabel audit_logs.
// Mendukung 2 konteks:
//   1. Server Action (web) — fallback ambil user dari cookie session.
//   2. Route Handler mobile (Bearer auth) — caller WAJIB pass `userId` & `ipAddress` eksplisit
//      karena Bearer context TIDAK punya cookie session.
//
// JANGAN masukkan field sensitif (token, embedding, password) ke `details`.

import { createAdminClient, createClient } from '@/lib/supabase/server'

interface AuditLogEntry {
  action: string
  details?: Record<string, unknown>
  /**
   * Optional explicit user_id (UUID).
   * - Server Action: boleh kosong → diambil dari cookie session.
   * - Route Handler mobile: WAJIB pass `user.id` setelah authenticateRequest().
   */
  userId?: string | null
  /**
   * Optional client IP address. Ambil dari `req.headers.get('x-forwarded-for')`
   * atau `req.headers.get('x-real-ip')` di Route Handler.
   * Server Action tidak punya akses ke headers → boleh null.
   */
  ipAddress?: string | null
}

/**
 * Mencatat aktivitas ke audit_logs.
 * Tidak pernah throw — failure di-log via console tapi tidak break flow utama.
 */
export async function logAudit({ action, details, userId, ipAddress }: AuditLogEntry) {
  try {
    let resolvedUserId: string | null = userId ?? null

    // Fallback: kalau caller tidak pass userId, coba ambil dari cookie session.
    // Ini bekerja untuk Server Action (web admin/dosen), tapi return null
    // untuk Route Handler mobile (Bearer context tanpa cookie).
    if (!resolvedUserId) {
      try {
        const supabase = createClient()
        const { data: { user } } = await supabase.auth.getUser()
        resolvedUserId = user?.id ?? null
      } catch {
        // Cookie not available (mobile context) — biarkan null
      }
    }

    const adminClient = createAdminClient()
    await adminClient.from('audit_logs').insert({
      user_id: resolvedUserId,
      action,
      details: details ?? null,
      ip_address: ipAddress ?? null,
    })
  } catch (err) {
    // Audit logging should never break the main flow
    console.error('[AUDIT] Failed to log:', err)
  }
}
