// app/lib/utils/totp.ts
// TOTP-like generator untuk Rolling QR (Phase 3 v7).
// Pure function — HMAC-SHA1 + dynamic truncation per RFC 6238 (tweaked window length).
// SECURITY: seed harus 32-byte hex (64 char) generated via crypto.randomBytes.
// Tidak boleh digunakan untuk auth credentials — only ephemeral session QR.

import { createHmac, timingSafeEqual } from 'crypto'

// Konstanta module-level — tightening future cukup ganti angka di sini, tidak
// perlu edit consumer (submit endpoint, admin endpoint).
//
// CONFIG: 5 detik per window + ±12 tolerance = 125 detik effective acceptance
// (window 0 + 12 ke kiri + 12 ke kanan = 25 window × 5s).
//
// History tuning:
//   - v1 (initial): ±2 = 25s effective. Terlalu ketat untuk flow scan QR →
//     face verify → submit di RMX5000. Face verify timeout intrinsic 15s
//     (face_verification_screen.dart) + scan delay 2s + submit network 1-3s
//     = total 18-20s. Tolerance 25s tipis margin, sering reject "Kode QR
//     sudah lewat" (lihat audit_logs `qr_code_invalid_attempt`, BUG-015).
//   - v2 (BUG-015 fix, 2026-05-23): ±12 = 125s effective. Cukup buat
//     full flow scan→verify→submit dengan margin nyaman, tetap kuat anti-
//     share via WhatsApp (capture+upload+receive+scan biasanya >2 menit di
//     network mobile real-world).
//
// Anti-share rationale: share screenshot via WhatsApp/Telegram butuh:
//   1. User screenshot QR (~3-5s untuk apps switch)
//   2. Upload ke chat (~5-15s di 4G + compression)
//   3. Teman buka chat & download (~5-30s tergantung notification)
//   4. Teman scan dari layar HP-nya (~5-10s)
//   = total realistic 20-60+ detik di 4G normal, sering >2 menit di kondisi
//   spotty network kelas. 125s tolerance tetap dominan reject share scenario.
const WINDOW_SIZE_MS = 5_000 // 5 detik per window
const DIGIT_COUNT = 6
const TOLERANCE_DEFAULT = 0 // 0 window = HANYA berlaku di 5 detik tersebut (Strict 5 detik)

export interface TotpVerifyResult {
  match: boolean
  offset: number | null // -tolerance..+tolerance saat match, null saat tidak match
  window: number // window yang dipakai server saat verifikasi
}

/**
 * Compute TOTP code untuk window tertentu.
 *
 * Determinisik — input `(seedHex, window)` yang sama SELALU return string yang sama.
 * Algorithm: RFC 6238 dynamic truncation di atas HMAC-SHA1, modulus 10^6.
 *
 * @param seedHex hex 64-char (32 byte) secret seed
 * @param window integer window number (>= 0). Lihat {@link getCurrentWindow}.
 * @returns 6-digit zero-padded string (mis. `"042831"`)
 */
export function generateCode(seedHex: string, window: number): string {
  // Convert hex seed → Buffer 32 byte
  const seedBytes = Buffer.from(seedHex, 'hex')

  // Convert window integer → 8-byte big-endian Buffer (RFC 6238 counter)
  const windowBuf = Buffer.alloc(8)
  windowBuf.writeBigUInt64BE(BigInt(window), 0)

  // HMAC-SHA1 → 20-byte digest
  const hmac = createHmac('sha1', seedBytes)
  hmac.update(windowBuf)
  const digest = hmac.digest()

  // Dynamic truncation per RFC 6238 §5.3
  const truncOffset = digest[19] & 0x0f
  const binary =
    ((digest[truncOffset] & 0x7f) << 24) |
    ((digest[truncOffset + 1] & 0xff) << 16) |
    ((digest[truncOffset + 2] & 0xff) << 8) |
    (digest[truncOffset + 3] & 0xff)

  // Ambil DIGIT_COUNT digit terakhir, zero-pad
  const modulus = 10 ** DIGIT_COUNT
  return (binary % modulus).toString().padStart(DIGIT_COUNT, '0')
}

/**
 * Get current window number berdasarkan timestamp ms.
 *
 * `window = floor(nowMs / WINDOW_SIZE_MS)` — monotonik naik.
 * Default `nowMs = Date.now()`. Override untuk test determinisme.
 */
export function getCurrentWindow(nowMs: number = Date.now()): number {
  return Math.floor(nowMs / WINDOW_SIZE_MS)
}

/**
 * Verify input code dengan tolerance window.
 *
 * Loop dari offset 0 dulu (happy-path = no lag), lalu `[-1, +1, -2, +2, ...]`
 * supaya match window saat ini didahulukan tanpa over-checking saat user lambat.
 * Return offset pertama yang match. Komparasi pakai {@link timingSafeEqual}
 * untuk mitigasi side-channel timing attack.
 *
 * Input malformed (length salah / non-digit) → return `match: false` tanpa throw.
 *
 * @param seedHex secret seed (hex 64-char)
 * @param inputCode 6-digit string dari client
 * @param currentWindow window saat ini di server (lihat {@link getCurrentWindow})
 * @param tolerance jumlah window di tiap arah (default 12 = 25 window total = 125s)
 */
export function verifyWithTolerance(
  seedHex: string,
  inputCode: string,
  currentWindow: number,
  tolerance: number = TOLERANCE_DEFAULT,
): TotpVerifyResult {
  // Sanitasi input — wajib 6-digit numerik. Reject tanpa throw.
  if (
    typeof inputCode !== 'string' ||
    inputCode.length !== DIGIT_COUNT ||
    !/^\d{6}$/.test(inputCode)
  ) {
    return { match: false, offset: null, window: currentWindow }
  }

  // Defensive: normalisasi tolerance ke int >= 0.
  const tol = Math.max(0, Math.floor(tolerance))

  // Build candidate offsets: [0, -1, +1, -2, +2, ...]
  const offsets: number[] = [0]
  for (let i = 1; i <= tol; i++) {
    offsets.push(-i)
    offsets.push(i)
  }

  const inputBuf = Buffer.from(inputCode, 'utf8')

  for (const offset of offsets) {
    const candidate = generateCode(seedHex, currentWindow + offset)
    const candidateBuf = Buffer.from(candidate, 'utf8')
    // timingSafeEqual: kedua buffer harus sama panjang. Dijamin karena
    // generateCode SELALU return string sepanjang DIGIT_COUNT.
    if (
      candidateBuf.length === inputBuf.length &&
      timingSafeEqual(candidateBuf, inputBuf)
    ) {
      return { match: true, offset, window: currentWindow }
    }
  }

  return { match: false, offset: null, window: currentWindow }
}

/**
 * Hitung sisa milisecond hingga window berikutnya.
 *
 * Untuk countdown UI (label "Kode berlaku" di display dosen + projector).
 * Return value selalu di range `(0, WINDOW_SIZE_MS]` — tidak pernah 0
 * (saat tepat di boundary, return = WINDOW_SIZE_MS karena modulus 0).
 */
export function msUntilNextWindow(nowMs: number = Date.now()): number {
  return WINDOW_SIZE_MS - (nowMs % WINDOW_SIZE_MS)
}
