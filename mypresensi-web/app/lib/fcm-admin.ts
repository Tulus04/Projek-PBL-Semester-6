// app/lib/fcm-admin.ts
// Firebase Admin SDK singleton + utility kirim push notification (FCM).
// Catatan keamanan:
//   - Service account JSON dari env var FIREBASE_SERVICE_ACCOUNT (single-line). JANGAN commit.
//   - Payload TIDAK pernah memuat data sensitif (embedding, password, JWT, full PII).
//   - fcm_token diakses/di-update via createAdminClient() (service_role) — bypass RLS aman
//     karena ini server-side setelah trigger terotorisasi.

import * as admin from 'firebase-admin'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'

/**
 * Tipe push notification — dipakai mobile untuk routing + kategori.
 */
export type PushType = 'leave_status' | 'session_start' | 'face_reminder' | 'announcement'

export interface SendPushOptions {
  studentId: string
  title: string
  body: string
  route: string
  type: PushType
  relatedId?: string
}

export interface SendPushResult {
  success: boolean
  messageId?: string
  error?: string
}

/**
 * Inisialisasi Firebase Admin SDK sekali saja (singleton).
 * Throw kalau env var tidak ada / tidak parseable — caller harus handle.
 */
function getMessaging(): admin.messaging.Messaging {
  if (!admin.apps.length) {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT
    if (!raw) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT env var tidak di-set')
    }

    let serviceAccount: admin.ServiceAccount
    try {
      serviceAccount = JSON.parse(raw) as admin.ServiceAccount
    } catch {
      throw new Error('FIREBASE_SERVICE_ACCOUNT tidak parseable sebagai JSON')
    }

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    })
  }
  return admin.messaging()
}

/**
 * Algorithm 1: kirim push ke satu mahasiswa.
 * - Skip kalau fcm_token null (audit 'fcm_push_skipped').
 * - Token invalid/expired → clear dari DB (audit 'fcm_token_invalid').
 * - Sukses/gagal lain → audit 'fcm_push_sent' / 'fcm_push_failed'.
 * Tidak pernah throw ke caller — selalu return SendPushResult.
 */
export async function sendPushNotification(opts: SendPushOptions): Promise<SendPushResult> {
  const { studentId, title, body, route, type, relatedId } = opts

  const supabase = createAdminClient()

  // 1. Ambil token
  const { data: profile, error: fetchError } = await supabase
    .from('profiles')
    .select('fcm_token')
    .eq('id', studentId)
    .single()

  if (fetchError || !profile?.fcm_token) {
    await logAudit({
      action: 'fcm_push_skipped',
      userId: studentId,
      details: { reason: 'no_token', type, route },
    })
    return { success: false, error: 'no_token' }
  }

  const fcmToken = profile.fcm_token as string

  // 2. Susun data payload (semua value HARUS string untuk FCM data message)
  const data: Record<string, string> = { route, type }
  if (relatedId) data.related_id = relatedId

  // 3. Kirim
  try {
    const messaging = getMessaging()
    const messageId = await messaging.send({
      token: fcmToken,
      notification: { title, body },
      data,
    })

    await logAudit({
      action: 'fcm_push_sent',
      userId: studentId,
      details: { type, route, messageId },
    })
    return { success: true, messageId }
  } catch (err) {
    const error = err as { code?: string; message?: string }

    // Token expired/invalid → clear dari DB supaya tidak spam retry
    if (error.code === 'messaging/registration-token-not-registered') {
      await supabase
        .from('profiles')
        .update({ fcm_token: null, fcm_token_updated_at: new Date().toISOString() })
        .eq('id', studentId)
      await logAudit({
        action: 'fcm_token_invalid',
        userId: studentId,
        details: { type, route, error: error.code },
      })
    } else {
      await logAudit({
        action: 'fcm_push_failed',
        userId: studentId,
        details: { type, route, error: error.message ?? 'unknown' },
      })
    }
    return { success: false, error: error.message ?? error.code ?? 'unknown' }
  }
}

/**
 * Kirim push BATCH ke banyak mahasiswa (mis. saat sesi baru dimulai).
 * - Ambil hanya student yang punya fcm_token (skip null).
 * - Chunk per 500 token (limit FCM sendEachForMulticast).
 * - Token invalid di-clear dari DB.
 * - Audit 1 entry ringkasan per pemanggilan.
 */
export async function sendPushToMany(
  studentIds: string[],
  payload: { title: string; body: string; route: string; type: PushType; relatedId?: string },
): Promise<{ successCount: number; failureCount: number; skipped: number }> {
  if (studentIds.length === 0) {
    return { successCount: 0, failureCount: 0, skipped: 0 }
  }

  const supabase = createAdminClient()

  // Ambil token non-null untuk student terkait
  const { data: rows } = await supabase
    .from('profiles')
    .select('id, fcm_token')
    .in('id', studentIds)
    .not('fcm_token', 'is', null)

  const tokenRows = (rows ?? []) as Array<{ id: string; fcm_token: string }>
  const skipped = studentIds.length - tokenRows.length

  if (tokenRows.length === 0) {
    await logAudit({
      action: 'fcm_push_skipped',
      details: { reason: 'no_tokens', type: payload.type, route: payload.route, total: studentIds.length },
    })
    return { successCount: 0, failureCount: 0, skipped }
  }

  const data: Record<string, string> = { route: payload.route, type: payload.type }
  if (payload.relatedId) data.related_id = payload.relatedId

  let successCount = 0
  let failureCount = 0
  const invalidTokenStudentIds: string[] = []

  const messaging = getMessaging()
  const CHUNK = 500
  for (let i = 0; i < tokenRows.length; i += CHUNK) {
    const chunk = tokenRows.slice(i, i + CHUNK)
    try {
      const res = await messaging.sendEachForMulticast({
        tokens: chunk.map((r) => r.fcm_token),
        notification: { title: payload.title, body: payload.body },
        data,
      })
      successCount += res.successCount
      failureCount += res.failureCount

      // Deteksi token invalid per index untuk di-clear
      res.responses.forEach((r, idx) => {
        if (!r.success && r.error?.code === 'messaging/registration-token-not-registered') {
          invalidTokenStudentIds.push(chunk[idx].id)
        }
      })
    } catch (err) {
      failureCount += chunk.length
      const error = err as { message?: string }
      await logAudit({
        action: 'fcm_push_failed',
        details: { type: payload.type, route: payload.route, error: error.message ?? 'batch_error' },
      })
    }
  }

  // Clear token invalid (batch)
  if (invalidTokenStudentIds.length > 0) {
    await supabase
      .from('profiles')
      .update({ fcm_token: null, fcm_token_updated_at: new Date().toISOString() })
      .in('id', invalidTokenStudentIds)
  }

  await logAudit({
    action: 'fcm_push_sent',
    details: {
      type: payload.type,
      route: payload.route,
      successCount,
      failureCount,
      skipped,
      invalidated: invalidTokenStudentIds.length,
    },
  })

  return { successCount, failureCount, skipped }
}
