'use client'

// app/lib/realtime/use-realtime-attendances.ts
// React hook reusable untuk subscribe Supabase Realtime channel attendances
// filtered per-session_id. Dipakai oleh dashboard web (Live Monitor masa depan
// + upgrade QR Display Fullscreen dari polling).
//
// Spec referensi: `.kiro/specs/realtime-attendances-channel/`
// Requirement     : 3.1-3.9, 4.1-4.3, 5.1-5.5, 7.1-7.5, 8.1-8.3, 9.1-9.3
//
// Catatan keamanan:
//   - RLS policy "View own or all if admin/dosen" (migration 012) di-evaluate
//     per event delivery oleh Supabase Realtime gateway. Mahasiswa lain tidak
//     terima event attendance bukan miliknya.
//   - JWT auth otomatis attach via cookie session di `createClient()` browser.
//   - Payload mengandung Tier 2 PII (device_os, ip_address, student_lat/lng).
//     Caller TIDAK BOLEH `console.log(row)` di production code path.
//
// Performance:
//   - Cleanup wajib di useEffect return — mencegah ghost channel + Free tier
//     200 concurrent connection limit issue.
//   - useRef untuk callback agar tidak re-subscribe channel saat parent
//     re-render dengan callback identity baru (anti stale closure).

import { useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import type {
  RealtimeAttendanceRow,
  RealtimeChannelStatus,
  UseRealtimeAttendancesOptions,
} from '@/types/realtime'

/**
 * Hook subscribe channel Realtime attendances untuk satu sesi.
 *
 * Usage:
 * ```tsx
 * useRealtimeAttendances({
 *   sessionId: '...',
 *   onInsert: (row) => setAttendances((prev) => [...prev, row]),
 *   onStatusChange: (status) => setSyncStatus(status),
 * })
 * ```
 *
 * @param opts - Lihat [UseRealtimeAttendancesOptions]
 */
export function useRealtimeAttendances(opts: UseRealtimeAttendancesOptions): void {
  const { sessionId, onInsert, onStatusChange, enabled = true } = opts

  // Refs untuk callback — anti stale closure. Update ref setiap render tanpa
  // memicu re-subscribe channel (useEffect deps tidak include callback).
  const onInsertRef = useRef(onInsert)
  const onStatusChangeRef = useRef(onStatusChange)

  useEffect(() => {
    onInsertRef.current = onInsert
  }, [onInsert])

  useEffect(() => {
    onStatusChangeRef.current = onStatusChange
  }, [onStatusChange])

  useEffect(() => {
    // Guard: skip jika disabled atau sessionId belum siap.
    if (!enabled || !sessionId) {
      return
    }

    const supabase = createClient()
    const channelName = `attendances:session=${sessionId}`

    const channel = supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'attendances',
          filter: `session_id=eq.${sessionId}`,
        },
        (payload) => {
          // Cast ke RealtimeAttendanceRow — kita trust REPLICA IDENTITY FULL
          // memberikan full row. Boundary check via TypeScript saja.
          const row = payload.new as RealtimeAttendanceRow
          onInsertRef.current(row)
        },
      )
      .subscribe((status) => {
        onStatusChangeRef.current?.(status as RealtimeChannelStatus)
      })

    return () => {
      // Cleanup: unsubscribe + release channel dari client memory.
      // WAJIB keduanya — tanpa removeChannel, slot Free tier (200 concurrent)
      // akan terakumulasi.
      channel.unsubscribe()
      supabase.removeChannel(channel)
    }
  }, [sessionId, enabled])
}
