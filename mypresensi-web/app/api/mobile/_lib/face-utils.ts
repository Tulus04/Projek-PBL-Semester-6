// app/api/mobile/_lib/face-utils.ts
// Utility server-side untuk face recognition — cosine similarity & decode embedding.
// Dipakai oleh /api/mobile/face/verify (server-side comparison).
//
// SECURITY NOTE: Module ini sengaja kecil & tidak punya state.
// Tidak boleh log embedding mentah ke console / audit_logs (Tier 1 sensitive).

/**
 * Decode stored embedding dari format base64 (BYTEA di Postgres) ke number[].
 *
 * Format penyimpanan: Float64Array → Buffer → base64 string.
 * Reverse: base64 → Buffer → Float64Array → number[].
 *
 * Throws jika decode gagal (corrupt data, dipanggil ulang dengan format lama).
 */
export function decodeStoredEmbedding(base64: string): number[] {
  const buffer = Buffer.from(base64, 'base64')
  // Float64Array butuh ArrayBuffer slice yang aligned ke 8 byte.
  // Buffer.from → Node Buffer; .buffer / .byteOffset / .byteLength tetap valid.
  if (buffer.byteLength % 8 !== 0) {
    throw new Error(
      `Invalid embedding length: ${buffer.byteLength} bytes (expected multiple of 8)`,
    )
  }
  const float64 = new Float64Array(
    buffer.buffer,
    buffer.byteOffset,
    buffer.byteLength / 8,
  )
  return Array.from(float64)
}

/**
 * Cosine similarity antara dua vector embedding.
 * Range: -1 (opposite) sampai 1 (identical).
 *
 * Asumsi: kedua input sudah L2-normalized di mobile (FaceEmbeddingService).
 * Defensive: tetap hitung magnitude untuk safety jika asumsi gagal.
 *
 * @returns similarity score, atau 0 jika dimensi tidak match / vector kosong.
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length || a.length === 0) return 0

  let dot = 0
  let magA = 0
  let magB = 0
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i]
    magA += a[i] * a[i]
    magB += b[i] * b[i]
  }

  const magnitudeProduct = Math.sqrt(magA) * Math.sqrt(magB)
  if (magnitudeProduct === 0) return 0

  return dot / magnitudeProduct
}
