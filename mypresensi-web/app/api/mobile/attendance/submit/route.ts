// app/api/mobile/attendance/submit/route.ts
// Endpoint PALING KRITIS — submit presensi mahasiswa dari mobile app.
// Validasi 6 layer: session valid, code check, enrollment, duplicate, GPS, face recognition.
// Phase 2 v7 (17 Mei 2026): Layer 6 face WAJIB di KEDUA mode (offline + online).
// Rate limited: max 10 request per menit per (user + device) — composite key
// agar 1 device bermasalah tidak block device lain dari user yang sama.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../../_lib/auth'
import {
  buildRateLimitKey,
  checkSlidingRateLimit,
  getDeviceId,
} from '../../_lib/rate-limit'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { verifyWithTolerance, getCurrentWindow } from '@/lib/utils/totp'
import { z } from 'zod'

// ===========================
// Zod Schema
// ===========================
const submitSchema = z.object({
  session_id: z.string().uuid('QR tidak valid'),
  qr_token: z.string().uuid('Token QR tidak valid').optional(),
  session_code: z.string().length(6, 'QR tidak valid').optional(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  is_mock_location: z.boolean().default(false),
  face_confidence: z.number().min(0).max(1).nullable().optional(),
  is_face_matched: z.boolean().nullable().optional(),
  is_liveness_passed: z.boolean().nullable().optional(),
  device_model: z.string().max(100).nullable().optional(),
  device_os: z.string().max(50).nullable().optional(),
  wifi_ssid: z.string().max(100).nullable().optional(),
})

// ===========================
// Haversine Distance (meters)
// ===========================
function haversineDistance(
  lat1: number, lng1: number,
  lat2: number, lng2: number
): number {
  const R = 6371000 // Earth radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLng = (lng2 - lng1) * Math.PI / 180
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

// ===========================
// Rate Limiter (in-memory, per user+device)
// Sliding window: max 10 request per menit per (userId, deviceId)
// ===========================
const rateLimitMap = new Map<string, number[]>()
const RATE_LIMIT_CONFIG = { windowMs: 60_000, max: 10 }

export async function POST(req: NextRequest) {
  try {
    // 1. Auth check
    const auth = await authenticateRequest(req)
    if (auth.error) return errorResponse(auth.error, auth.status)

    const user = auth.user!
    const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
    const userAgent = req.headers.get('user-agent') ?? null
    const deviceId = getDeviceId(req)

    // 2. Rate limit check — composite key user+device
    const rlKey = buildRateLimitKey(user.id, deviceId)
    if (!checkSlidingRateLimit(rateLimitMap, rlKey, RATE_LIMIT_CONFIG)) {
      return errorResponse('Terlalu banyak percobaan, coba 1 menit lagi', 429)
    }

    // 3. Parse & validate body
    const body = await req.json()
    const parsed = submitSchema.safeParse(body)

    if (!parsed.success) {
      const firstError = parsed.error.errors[0]?.message ?? 'Input tidak valid'
      return errorResponse(firstError, 400)
    }

    const input = parsed.data
    const adminClient = createAdminClient()

    // 4. LAYER 1: Validasi sesi exists & aktif
    const { data: session, error: sessionError } = await adminClient
      .from('sessions')
      .select('id, course_id, is_active, session_code, session_code_seed, session_code_expires_at, location_lat, location_lng, radius_meters, mode, session_number, topic, started_at, courses(code, name)')
      .eq('id', input.session_id)
      .single()

    if (sessionError || !session) {
      return errorResponse('Sesi tidak ditemukan', 404)
    }

    if (!session.is_active) {
      return errorResponse('Sesi sudah berakhir', 400)
    }

    // 5. LAYER 2: Validasi session_code atau qr_token (QR Gating Phase)
    let qrVerifyMethod: 'token' | 'totp' | 'static_legacy' = 'token'
    let qrWindowOffset: number | null = null

    if (input.qr_token) {
      // Menggunakan token QR hasil gating (QR Pintu Masuk)
      const { data: tokenRow } = await adminClient
        .from('attendance_qr_tokens')
        .select('token, expires_at')
        .eq('token', input.qr_token)
        .eq('student_id', user.id)
        .eq('session_id', input.session_id)
        .single()

      if (!tokenRow) {
        return errorResponse('Izin QR tidak valid', 400)
      }

      if (new Date(tokenRow.expires_at) < new Date()) {
        return errorResponse('Waktu pemindaian wajah & lokasi sudah habis (lebih dari 1 menit)', 400)
      }
    } else if (input.session_code) {
      // Backward compatibility untuk versi app lama
      if (session.session_code_seed) {
        qrVerifyMethod = 'totp'
        const currentWindow = getCurrentWindow()
        const verify = verifyWithTolerance(
          session.session_code_seed,
          input.session_code,
          currentWindow,
          // tolerance mengikuti TOLERANCE_DEFAULT
        )

        if (!verify.match) {
          await logAudit({
            action: 'qr_code_invalid_attempt',
            userId: user.id,
            ipAddress,
            details: {
              session_id: input.session_id,
              qr_verify_method: 'totp',
              current_window: currentWindow,
              student_nim: user.nim_nip,
              stage: 'submit',
            },
          })
          return errorResponse('QR sudah kedaluwarsa', 400)
        }
        qrWindowOffset = verify.offset
      } else {
        qrVerifyMethod = 'static_legacy'
        if (session.session_code !== input.session_code) {
          return errorResponse('QR tidak valid', 400)
        }
        if (session.session_code_expires_at) {
          const expiry = new Date(session.session_code_expires_at)
          if (expiry < new Date()) {
            return errorResponse('QR sudah kedaluwarsa', 400)
          }
        }
      }
    } else {
      return errorResponse('Token atau Kode QR harus diisi', 400)
    }

    // 6. LAYER 3: Validasi enrollment — mahasiswa terdaftar di MK ini
    const { data: enrollment } = await adminClient
      .from('enrollments')
      .select('id')
      .eq('course_id', session.course_id)
      .eq('student_id', user.id)
      .limit(1)
      .maybeSingle()

    if (!enrollment) {
      return errorResponse('Anda tidak terdaftar di mata kuliah ini', 400)
    }

    // 7. LAYER 4: Validasi duplicate — belum pernah submit untuk sesi ini
    const { data: existing } = await adminClient
      .from('attendances')
      .select('id')
      .eq('session_id', input.session_id)
      .eq('student_id', user.id)
      .limit(1)
      .maybeSingle()

    if (existing) {
      return errorResponse('Anda sudah presensi di sesi ini', 409)
    }

    // 8. LAYER 5: GPS calculation — mode-aware
    // Mode online → GPS dilewat (mahasiswa bisa presensi dari mana saja)
    // Mode offline → hitung jarak Haversine server-side
    let isLocationValid: boolean
    let distanceRounded: number

    if (session.mode === 'online') {
      // Sesi daring — skip GPS validation
      isLocationValid = true
      distanceRounded = 0
    } else {
      // Sesi tatap muka — validasi jarak GPS
      const distance = haversineDistance(
        input.latitude, input.longitude,
        session.location_lat, session.location_lng
      )
      distanceRounded = Math.round(distance)
      isLocationValid = distance <= session.radius_meters
    }

    // Flag mock location — REJECT presensi jika lokasi palsu terdeteksi
    if (input.is_mock_location) {
      await logAudit({
        action: 'mock_location_detected',
        userId: user.id,
        ipAddress,
        details: {
          student_id: user.id,
          session_id: input.session_id,
          latitude: input.latitude,
          longitude: input.longitude,
          device_id: deviceId,
          user_agent: userAgent,
        },
      })
      return errorResponse('Lokasi palsu terdeteksi', 403)
    }

    // 9. LAYER 6: Face Recognition Gate (Phase 2 v7, 17 Mei 2026)
    // Cek setting face_verification_mode dari DB.
    // Mode 'required' → face WAJIB di KEDUA mode (offline + online).
    // Mode 'optional' → backward compat: skip gate (legacy behavior).
    // Setting di-set ke 'required' sejak Phase 2 v7 — defense in depth Layer 3.
    const { data: faceModeRow } = await adminClient
      .from('settings')
      .select('value')
      .eq('key', 'face_verification_mode')
      .maybeSingle()

    const faceMode = faceModeRow?.value === 'required' ? 'required' : 'optional'

    if (faceMode === 'required') {
      // 9a. Wajah belum terdaftar — redirect ke face registration screen
      if (!user.is_face_registered) {
        await logAudit({
          action: 'face_not_registered_attempt',
          userId: user.id,
          ipAddress,
          details: {
            student_id: user.id,
            student_nim: user.nim_nip,
            session_id: input.session_id,
            session_mode: session.mode,
            device_id: deviceId,
            user_agent: userAgent,
          },
        })
        return errorResponse(
          'Wajah belum didaftarkan',
          403,
          'face_not_registered',
        )
      }

      // 9b. Face match gagal / tidak dilakukan — minta verify ulang
      // input.is_face_matched harus eksplisit true (bukan null/undefined/false)
      if (input.is_face_matched !== true) {
        await logAudit({
          action: 'face_mismatch_attempt',
          userId: user.id,
          ipAddress,
          details: {
            student_id: user.id,
            student_nim: user.nim_nip,
            session_id: input.session_id,
            session_mode: session.mode,
            face_confidence: input.face_confidence ?? null,
            device_id: deviceId,
            user_agent: userAgent,
          },
        })
        return errorResponse(
          'Verifikasi wajah gagal',
          403,
          'face_mismatch',
        )
      }
    }

    // 10. Auto-classify status — 'hadir' atau 'terlambat'
    // Berdasarkan selisih waktu submit vs sessions.started_at.
    // Threshold dari setting `late_threshold_minutes` (default 15).
    const now = new Date()
    const nowIso = now.toISOString()

    let attendanceStatus: 'hadir' | 'terlambat' = 'hadir'
    let lateBySeconds: number | null = null

    if (session.started_at) {
      // Fetch threshold dari settings (fallback 15 menit jika setting hilang)
      const { data: thresholdRow } = await adminClient
        .from('settings')
        .select('value')
        .eq('key', 'late_threshold_minutes')
        .maybeSingle()

      const thresholdMinutes = thresholdRow?.value
        ? parseInt(thresholdRow.value, 10)
        : 15
      const safeThreshold = isNaN(thresholdMinutes) || thresholdMinutes < 0 ? 15 : thresholdMinutes

      const startedAt = new Date(session.started_at)
      const diffMs = now.getTime() - startedAt.getTime()
      const diffMinutes = diffMs / 60_000
      lateBySeconds = Math.max(0, Math.round(diffMs / 1000))

      if (diffMinutes > safeThreshold) {
        attendanceStatus = 'terlambat'
      }
    }

    const { error: insertError } = await adminClient
      .from('attendances')
      .insert({
        session_id: input.session_id,
        student_id: user.id,
        status: attendanceStatus,
        scanned_at: nowIso,
        student_lat: input.latitude,
        student_lng: input.longitude,
        distance_meters: distanceRounded,
        is_location_valid: isLocationValid,
        is_mock_location: input.is_mock_location,
        wifi_ssid: input.wifi_ssid ?? null,
        face_confidence: input.face_confidence ?? null,
        is_face_matched: input.is_face_matched ?? null,
        is_liveness_passed: input.is_liveness_passed ?? null,
        device_model: input.device_model ?? null,
        device_os: input.device_os ?? null,
        ip_address: ipAddress,
        session_mode: session.mode,
      })

    if (insertError) {
      // Handle UNIQUE constraint violation
      if (insertError.code === '23505') {
        return errorResponse('Anda sudah presensi di sesi ini', 409)
      }
      return errorResponse('Gagal menyimpan presensi', 500)
    }

    // 10. Audit log
    await logAudit({
      action: 'mobile_attendance_submit',
      userId: user.id,
      ipAddress,
      details: {
        student_id: user.id,
        student_nim: user.nim_nip,
        session_id: input.session_id,
        session_number: session.session_number,
        topic: session.topic,
        status: attendanceStatus,
        late_by_seconds: lateBySeconds,
        distance_meters: distanceRounded,
        is_location_valid: isLocationValid,
        is_mock_location: input.is_mock_location,
        face_confidence: input.face_confidence,
        device: input.device_model,
        device_id: deviceId,
        user_agent: userAgent,
        qr_verify_method: qrVerifyMethod,
        qr_window_offset: qrWindowOffset,
      },
    })

    // 11. Response — status hasil auto-classify
    const lateMinutes = lateBySeconds != null ? Math.floor(lateBySeconds / 60) : null
    let message: string
    if (attendanceStatus === 'terlambat') {
      message = `Presensi tercatat dengan status TERLAMBAT (${lateMinutes} menit dari mulai sesi).`
    } else if (!isLocationValid) {
      message = `Presensi tercatat, namun lokasi Anda di luar radius (jarak: ${distanceRounded}m, batas: ${session.radius_meters}m)`
    } else {
      message = `Presensi berhasil! Jarak: ${distanceRounded}m`
    }

    return successResponse({
      status: attendanceStatus,
      distance_meters: distanceRounded,
      is_location_valid: isLocationValid,
      late_by_seconds: lateBySeconds,
      scanned_at: nowIso,
      message,
      course_name: session.courses ? `${(session.courses as any).code} - ${(session.courses as any).name}` : null,
      session_topic: session.topic,
      session_number: session.session_number,
    }, 201)
  } catch {
    return errorResponse('Terjadi kesalahan server', 500)
  }
}
