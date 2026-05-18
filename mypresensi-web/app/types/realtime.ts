// app/types/realtime.ts
// Type definitions untuk Supabase Realtime channel attendances.
// Konsumen utama: hook `useRealtimeAttendances` di
// `app/lib/realtime/use-realtime-attendances.ts`.
//
// Spec referensi: `.kiro/specs/realtime-attendances-channel/`
// Requirement     : 2.1, 2.2, 2.3, 2.4

import type { RealtimePostgresChangesPayload } from '@supabase/supabase-js'

/**
 * Row attendance dari Postgres Changes payload (CDC stream).
 *
 * Match schema tabel `attendances` di `database.ts`. REPLICA IDENTITY FULL
 * (migration 021) memastikan payload event INCLUDE seluruh kolom row.
 *
 * **PERHATIAN**: payload mengandung field potensi sensitif:
 * - `device_model`, `device_os` (Tier 2 PII per rule 04-security)
 * - `ip_address` (Tier 2 PII)
 * - `student_lat`, `student_lng` (lokasi real-time, Tier 2)
 *
 * Caller TIDAK BOLEH `console.log(row)` di production code path. Lihat
 * Requirement 9.x di spec.
 */
export interface RealtimeAttendanceRow {
  id: string
  session_id: string
  student_id: string
  status: string // 'hadir' | 'terlambat' | 'izin' | 'sakit' | 'alpa'
  scanned_at: string // ISO 8601
  student_lat: number | null
  student_lng: number | null
  distance_meters: number | null
  is_location_valid: boolean | null
  is_mock_location: boolean | null
  face_confidence: number | null
  is_face_matched: boolean | null
  device_model: string | null
  device_os: string | null
  ip_address: string | null
  created_at: string
}

/**
 * Type alias untuk payload Postgres Changes event di tabel attendances.
 * Re-export dari `@supabase/supabase-js` dengan generic narrowed.
 */
export type RealtimeAttendancePayload = RealtimePostgresChangesPayload<RealtimeAttendanceRow>

/**
 * Status channel Supabase Realtime — di-emit dari `.subscribe(callback)`.
 *
 * Lifecycle umum:
 * - `CONNECTING`: subscribe baru saja diinitiate
 * - `SUBSCRIBED`: berhasil terhubung, ready menerima event
 * - `CHANNEL_ERROR`: gagal subscribe (RLS reject, auth invalid, dll)
 * - `TIMED_OUT`: server tidak respon dalam window
 * - `CLOSED`: channel ditutup (manual unsubscribe atau forced disconnect)
 */
export type RealtimeChannelStatus =
  | 'SUBSCRIBED'
  | 'CHANNEL_ERROR'
  | 'TIMED_OUT'
  | 'CLOSED'
  | 'CONNECTING'

/**
 * Options untuk hook `useRealtimeAttendances`.
 */
export interface UseRealtimeAttendancesOptions {
  /**
   * Session ID untuk filter — channel akan filter event server-side dengan
   * `session_id=eq.${sessionId}`. Tidak boleh kosong saat enabled=true.
   */
  sessionId: string

  /**
   * Callback dipanggil saat ada INSERT row baru di tabel attendances yang
   * lolos RLS + filter sessionId. Diinvoke dari useEffect handler — caller
   * disarankan pakai `useCallback` atau setState yang stable.
   *
   * **PERHATIAN**: row mengandung Tier 2 PII. JANGAN `console.log(row)`
   * sembarangan di production.
   */
  onInsert: (row: RealtimeAttendanceRow) => void

  /**
   * Callback opsional dipanggil setiap status channel berubah.
   * Caller bisa pakai untuk render badge "Sync aktif" / "Reconnecting".
   */
  onStatusChange?: (status: RealtimeChannelStatus) => void

  /**
   * Auto-disable jika false. Default: true.
   * Berguna untuk conditional subscribe (mis. tunggu sessionId valid).
   */
  enabled?: boolean
}
