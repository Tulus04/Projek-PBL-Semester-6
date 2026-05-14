// app/api/mobile/_lib/rate-limit.ts
// Rate limiter in-memory shared untuk semua endpoint mobile.
//
// Komposit key: `${userId}:${deviceId}` agar 1 device bermasalah tidak
// block device lain dari user yang sama (mis. user login di HP & emulator).
// Fallback ke `userId` saja jika header X-Device-Id tidak dikirim
// (backward-compat untuk client lama / debug via curl).
//
// Catatan: in-memory map akan reset saat server restart. Untuk production
// scale-out (multi-instance), ganti ke Redis atau Supabase rate_limit_log
// dengan window query. Saat ini single-instance OK.

import { NextRequest } from 'next/server'

/**
 * Ambil device_id dari header `X-Device-Id`. Mobile app inject otomatis via
 * Dio interceptor (`DeviceIdInterceptor`). Kalau client tidak kirim, return null
 * — rate limit tetap jalan tapi pakai userId saja.
 *
 * Validasi: 8-128 char hex/UUID-ish. Tolak input yang aneh untuk hindari
 * abuse map size lewat header palsu.
 */
export function getDeviceId(req: NextRequest): string | null {
  const raw = req.headers.get('x-device-id')
  if (!raw) return null
  const trimmed = raw.trim()
  // Akceptasi: 8-128 char alfanumerik + dash (UUID v4 = 36, hex 32 = 32, dll)
  if (!/^[a-zA-Z0-9-]{8,128}$/.test(trimmed)) return null
  return trimmed
}

/**
 * Bangun composite key untuk rate-limit map.
 * Format: `userId:deviceId` atau `userId:_no_device` jika header absent.
 */
export function buildRateLimitKey(userId: string, deviceId: string | null): string {
  return `${userId}:${deviceId ?? '_no_device'}`
}

// ===========================
// Sliding window rate limiter (timestamps array)
// ===========================
export interface SlidingRateLimit {
  windowMs: number
  max: number
}

/**
 * Sliding window rate limiter — track timestamps per key.
 * Cocok untuk endpoint frequent (attendance/submit, leave-request/submit).
 *
 * @returns true jika request DI-IZINKAN; false jika DI-BLOCK.
 */
export function checkSlidingRateLimit(
  store: Map<string, number[]>,
  key: string,
  config: SlidingRateLimit,
): boolean {
  const now = Date.now()
  const timestamps = (store.get(key) ?? []).filter(
    (t) => now - t < config.windowMs,
  )

  if (timestamps.length >= config.max) {
    // Tetap simpan recent untuk supaya next call masih ke-block
    store.set(key, timestamps)
    return false
  }

  timestamps.push(now)
  store.set(key, timestamps)
  return true
}

// ===========================
// Counter+resetAt rate limiter (object per key)
// ===========================
export interface CounterRateLimitEntry {
  count: number
  resetAt: number
}

export interface CounterRateLimit {
  windowMs: number
  max: number
}

/**
 * Counter window rate limiter — reset hard setelah windowMs.
 * Cocok untuk endpoint jarang & berat (face register: 3/15menit).
 *
 * @returns true jika request DI-IZINKAN; false jika DI-BLOCK.
 */
export function checkCounterRateLimit(
  store: Map<string, CounterRateLimitEntry>,
  key: string,
  config: CounterRateLimit,
): boolean {
  const now = Date.now()
  const entry = store.get(key)

  if (!entry || now > entry.resetAt) {
    store.set(key, { count: 1, resetAt: now + config.windowMs })
    return true
  }

  if (entry.count >= config.max) {
    return false
  }

  entry.count++
  return true
}
