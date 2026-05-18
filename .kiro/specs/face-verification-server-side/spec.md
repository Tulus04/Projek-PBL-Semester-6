# Spec: Server-Side Face Verification

> **Status**: In Progress
> **Created**: 2026-05-16
> **Priority**: T0 (Security blocker — melanggar `04-security-and-privacy.md` Section B.2)
> **Estimated effort**: 1-2 jam

## Konteks

Saat ini face verification berjalan **client-side**: mobile request `GET /api/mobile/face/embedding` → server kirim raw 192-d embedding → mobile hitung cosine similarity & putuskan match.

Pendekatan ini melanggar 3 prinsip security MyPresensi:

1. **Rule eksplisit** di `.kiro/steering/04-security-and-privacy.md` Section B.2: "Comparison dilakukan **server-side** di endpoint `/api/mobile/face/verify`. Mobile hanya kirim embedding kandidat untuk dibandingkan, server kembalikan boolean match + similarity score (tanpa bocorin embedding asli)."
2. **Data minimization (UU PDP Pasal 4)**: face embedding adalah "data spesifik" yang butuh proteksi ekstra — pengirimannya ke client memperluas attack surface.
3. **Trust boundary**: APK direverse-engineer → threshold di-set 0 → semua wajah cocok. Server tidak punya kontrol.

## Requirements

### R1 — Endpoint baru `POST /api/mobile/face/verify`
1.1. Terima body `{ embedding: number[] }` dengan length **exact 192** (sesuai output MobileFaceNet).
1.2. Validasi setiap nilai range `[-1, 1]` (output L2-normalized).
1.3. Auth via Bearer JWT, role mahasiswa, akun aktif (pakai helper `authenticateRequest`).
1.4. Rate limit: **10 verify per menit per (userId, deviceId)** — sliding window.
1.5. Server fetch stored embedding milik user dari `face_embeddings` table (admin client, bypass RLS aman karena step 1.3 sudah authorize).
1.6. Jika user belum register wajah → return 404 dengan pesan "Wajah belum didaftarkan."
1.7. Server fetch threshold dari `settings.face_confidence_threshold` dengan fallback `0.65`.
1.8. Server hitung cosine similarity (L2-normalized embeddings → dot product).
1.9. Response success: `{ match: boolean, similarity: number, threshold: number }` — return ketiganya untuk diagnostic UI mobile (similarity 0.4 saat threshold 0.65 → "wajah agak tidak cocok, coba pencahayaan lebih baik").
1.10. Audit log `mobile_face_verify` dengan `userId`, `ipAddress`, `details: { matched, similarity, threshold, device_id, user_agent }`. Jangan log embedding mentah.

### R2 — Hapus endpoint `GET /api/mobile/face/embedding`
2.1. File `app/api/mobile/face/embedding/route.ts` dihapus.
2.2. Mobile tidak pernah lagi panggil endpoint ini.

### R3 — Refactor mobile face flow
3.1. Tambah `verifyEmbedding(liveEmbedding)` di `FaceRepository`, return `FaceVerifyResponse` model baru.
3.2. Hapus `getStoredEmbedding()` di `FaceRepository`.
3.3. Hapus `storedEmbeddingProvider` di `face_provider.dart`.
3.4. Refactor `FaceVerificationNotifier.onFrame()`:
   - Hilangkan parameter `storedEmbedding` & `threshold`
   - Setelah extract live embedding, panggil `repo.verifyEmbedding(live)`
   - State `confidence` di-update dari response server
3.5. Refactor `face_verification_screen.dart`:
   - Hilangkan logic `_loadEmbeddingAndInitCamera` yang fetch stored embedding (cukup init camera + check `is_face_registered` flag)
   - Saat call `onFrame`, tidak perlu pass `storedEmbedding` & `threshold` lagi
3.6. Tambah konstanta `ApiEndpoints.faceVerify` di `api_endpoints.dart`.

### R4 — Backward compatibility
4.1. Tidak ada — ini security fix, mobile lama yang masih panggil `/face/embedding` akan dapat 404. Ini intentional untuk paksa upgrade.

### R5 — Konsistensi rules dan dokumen
5.1. Update `00-mypresensi-overview.md` jika ada referensi ke flow lama (cek dulu, mungkin tidak ada).
5.2. Update `CHANGELOG.md` dengan entri `[SEC]`.
5.3. Update `docs/TODO.md` untuk move face verify ke "Completed".

## Design

### Endpoint Server: `POST /api/mobile/face/verify`

**File**: `mypresensi-web/app/api/mobile/face/verify/route.ts`

**Pseudocode**:
```ts
1. authenticateRequest(req) → user
2. checkSlidingRateLimit(userId+deviceId, { windowMs: 60_000, max: 10 })
3. parse body → Zod schema { embedding: array(192).min(-1).max(1) }
4. fetch from face_embeddings where user_id = user.id → row
   if not found → 404 "Wajah belum didaftarkan."
5. decode stored embedding (base64 BYTEA → Float64Array → number[])
6. fetch from settings where key = 'face_confidence_threshold'
   threshold = parseFloat(value) || 0.65
7. similarity = cosineSimilarity(input, stored)  // simple dot product (both L2 normalized)
8. matched = similarity >= threshold
9. logAudit({ action: 'mobile_face_verify', userId, ipAddress, details })
10. return { match, similarity, threshold }
```

**Helper baru**: `cosineSimilarity(a: number[], b: number[]): number` — di `_lib/face-utils.ts` untuk reusability. Server-side version (TypeScript), terpisah dari Dart.

### Mobile: `FaceRepository.verifyEmbedding`

```dart
Future<FaceVerifyResponse> verifyEmbedding(List<double> liveEmbedding) async {
  final response = await _dio.post(
    ApiEndpoints.faceVerify,
    data: { 'embedding': liveEmbedding },
  );
  return FaceVerifyResponse.fromJson(response.data);
}
```

### Mobile: Model baru `FaceVerifyResponse`

```dart
class FaceVerifyResponse {
  final bool match;
  final double similarity;
  final double threshold;
  // ...
}
```

### Mobile: `FaceVerificationNotifier.onFrame`

```dart
Future<void> onFrame({
  required FaceDetectionResult result,
  required CameraImage cameraImage,
  required CameraDescription camera,
  // REMOVED: storedEmbedding, threshold
}) async {
  // ... validasi face detection result
  
  final live = await embeddingService.extractEmbedding(...);
  if (live == null) return;
  
  try {
    final repo = ref.read(faceRepositoryProvider);
    final response = await repo.verifyEmbedding(live);
    
    state = state.copyWith(
      status: response.match ? VerificationStatus.matched : VerificationStatus.verifying,
      confidence: response.similarity,
      isLivenessPassed: true,
    );
  } catch (e) {
    // Network/server error — log tapi jangan crash
  }
}
```

### Threat Model Verification

**Attack vector yang ditutup**:
- ✅ Reverse-engineer APK & ubah threshold → server yang putuskan, ignore client
- ✅ Steal stored embedding via JWT theft → endpoint `/embedding` dihapus, embedding tidak pernah keluar server
- ✅ Brute force similarity untuk reconstruct face → rate limit 10/menit + audit log

**Attack vector yang tidak relevan**:
- ⚠️ User kirim live embedding palsu (berhasil match) → bukan attack vektor baru, sudah ada via flow lama. Mitigation tetap di liveness check (blink + turn) sebelum embedding diekstrak.
- ⚠️ MITM intercept verify request → HTTPS production cover, dev cleartext OK karena network local.

## Tasks

Status legenda: `[ ]` not started · `[~]` in progress · `[x]` done

### Server (Web Next.js)

- [x] **T1.1** Buat helper `_lib/face-utils.ts` dengan function `cosineSimilarity(a, b)` + `decodeStoredEmbedding(base64)` (reusable, ada unit test target nanti)
- [x] **T1.2** Buat `app/api/mobile/face/verify/route.ts` dengan flow lengkap (auth → rate limit → Zod → fetch stored → similarity → audit → response)
- [x] **T1.3** Hapus `app/api/mobile/face/embedding/route.ts`
- [x] **T1.4** Update Zod schema register di `face/register/route.ts`: `.length(192)` ganti `.min(100).max(2000)` untuk strict validation
- [x] **T1.5** Run `npm run type-check` di `mypresensi-web/` — 0 errors

### Mobile (Flutter)

- [x] **T2.1** Tambah konstanta `faceVerify = '/api/mobile/face/verify'` di `core/network/api_endpoints.dart`
- [x] **T2.2** Tambah model `FaceVerifyResponse` di `data/face_models.dart`
- [x] **T2.3** Tambah method `verifyEmbedding(liveEmbedding)` di `data/face_repository.dart`
- [x] **T2.4** Hapus method `getStoredEmbedding()` di `data/face_repository.dart`
- [x] **T2.5** Hapus `storedEmbeddingProvider` di `providers/face_provider.dart` + invalidate-nya di `FaceDeletionNotifier`
- [x] **T2.6** Refactor `FaceVerificationNotifier.onFrame()`: hilangkan param `storedEmbedding` & `threshold`, panggil `verifyEmbedding`
- [x] **T2.7** Refactor `face_verification_screen.dart`:
  - Hilangkan `_storedEmbedding` field & `_loadEmbeddingAndInitCamera` yang fetch embedding
  - Init camera langsung, gate di `is_face_registered` (cek ke auth profile, bukan fetch embedding)
  - Hilangkan param `widget.threshold` (tidak relevan lagi — server yang putuskan)
- [x] **T2.8** Run `flutter analyze` di `mypresensi-mobile/` — 0 issues

### Dokumentasi

- [x] **T3.1** Update `CHANGELOG.md` dengan entri `[SEC]` untuk perubahan ini
- [x] **T3.2** Update `docs/TODO.md` — tambah entri ke Completed
- [x] **T3.3** Tulis ringkasan ke `dev-log.md` (kalau user request)

### Verifikasi (manual smoke test, bukan automated)

- [ ] **T4.1** User test: verify wajah sendiri → match (similarity > threshold) — dilakukan user di emulator/HP
- [ ] **T4.2** User test: verify wajah orang lain → no-match — dilakukan user
- [ ] **T4.3** User test: verify tanpa register dulu → 404 dengan pesan ramah — dilakukan user
- [ ] **T4.4** User test: try call old `/face/embedding` via curl → 404 (endpoint dihapus) — dilakukan user

## Out of Scope

- Hot-reload threshold dari mobile (tetap pakai pola sekarang: server settings, mobile cache via faceConfigProvider — tapi sekarang `confidenceThreshold` di mobile **tidak dipakai lagi** di flow verify, hanya untuk display info kalau perlu)
- Caching stored embedding di server memory (mungkin nanti, tapi untuk PBL skala kecil tidak perlu)
- Progressive penalty untuk failed verify (tidak perlu, rate limit cukup)
- Batch verify (1 user satu waktu, no need)

## Open Questions

Tidak ada — semua keputusan sudah dikonfirmasi user via prompt sebelumnya:
- ✓ Endpoint baru `POST /face/verify`, bukan integrasi ke attendance/submit
- ✓ Hapus `GET /face/embedding`
- ✓ Rate limit 10/menit/user+device
- ✓ Return similarity score + match boolean
