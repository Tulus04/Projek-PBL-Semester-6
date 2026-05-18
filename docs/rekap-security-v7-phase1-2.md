# Rekap Pekerjaan: Security Architecture v7 — Phase 1 + Phase 2

**Tanggal**: 17 Mei 2026  
**Dikerjakan oleh**: Riki (pair programming dengan Cascade AI)  
**Tujuan**: Upgrade keamanan sistem presensi MyPresensi dari arsitektur lama (v6) yang over-promise ke arsitektur jujur (v7) dengan implementasi nyata.

---

## Latar Belakang

Arsitektur keamanan v6 **mengklaim 6 layer** (WiFi SSID, teleportation detection, cell tower, freeRASP, AES-256, cert pinning, liveness active challenge) — tetapi **hampir semuanya tidak pernah diimplementasi**. Setelah audit bersama, v7 dirancang ulang ke **3-layer defense in depth** yang benar-benar jalan:

```
Layer 1: QR Rolling 5 detik (anti share / replay kode QR)
Layer 2: GPS Haversine + Mock GPS Detection (anti fake lokasi)
Layer 3: Face Recognition WAJIB (anti titip absen)
```

---

## Phase 1 — Dokumentasi Jujur (Tidak Sentuh Kode)

**Tujuan**: Rewrite semua dokumen agar mencerminkan realita kode yang ada. Tidak ada kode yang diubah.

### File yang Diubah

| File | Apa yang Dilakukan |
|------|-------------------|
| `docs/plans/implementation_plan.md` | **Total rewrite v6 → v7.** Hapus semua klaim palsu (6-Layer Anti-Fake GPS → 3-Layer Defense in Depth). Tambah tabel "Klaim yang Dihapus" + "Threat yang Ter-cover" + "Threat yang Tidak Ter-cover (Acceptable Risk)". Cross-check setiap klaim ke kode aktual. |
| `workflow_mypresensi.md` | Update diagram alur Mermaid. Tambah penjelasan jujur per-layer: QR rolling 5 detik, GPS Haversine + mock detection, Face MobileFaceNet 192-D cosine ≥ 0.65. Tambah section "Yang TIDAK di-cover" dan flowchart Manual Override Dosen. |
| `CHANGELOG.md` | Catat semua perubahan Phase 1 dengan format standar. |

### Keputusan yang Dikunci di Phase 1

| Keputusan | Pilihan | Alasan |
|-----------|---------|--------|
| QR Rolling | **A1: Dinamis 5 detik (TOTP-like)** | Anti share QR — kode berubah terus, screenshot jadi useless setelah 5 detik |
| Edge case kamera rusak | **B1: Dosen Manual Override via web** | Dosen bisa tandai hadir manual + wajib isi alasan + tercatat di audit log |

---

## Phase 1.5 — Penyesuaian Keputusan

**Perubahan keputusan**: Face verification awalnya wajib **hanya di mode offline**. Diubah menjadi **wajib di KEDUA mode (offline + online)**.

**Alasan**: Mode online artinya mahasiswa bisa submit dari mana saja (skip GPS check). Kalau face juga di-skip, maka **tidak ada sama sekali** yang memverifikasi identitas mahasiswa. Titip absen jadi terlalu mudah.

**File yang diubah**: `implementation_plan.md`, `workflow_mypresensi.md`, `CHANGELOG.md` (hanya adjustment teks, bukan kode).

---

## Phase 2 — Implementasi Face WAJIB Kedua Mode ✅

**Tujuan**: Enforce face verification di backend (server gate) + mobile (pre-flight check + UI dialog). Defense in depth: mobile cek duluan (fast feedback), server tetap gate sebagai fallback.

### A. Backend — 3 File Diubah

#### 1. `mypresensi-web/app/api/mobile/_lib/auth.ts`

**Perubahan**: Extend fungsi `errorResponse()` agar bisa terima parameter `errorCode` opsional.

```typescript
// SEBELUM:
export function errorResponse(message: string, status: number) {
  return Response.json({ error: message }, { status })
}

// SESUDAH:
export function errorResponse(message: string, status: number, errorCode?: string) {
  const body: Record<string, unknown> = { error: message }
  if (errorCode) body.error_code = errorCode
  return Response.json(body, { status })
}
```

**Kenapa perlu?** Mobile app butuh tahu **jenis error 403 yang mana**:
- `face_not_registered` → tampilkan dialog "Daftar Wajah Dulu"
- `face_mismatch` → tampilkan dialog "Wajah Tidak Cocok, Coba Lagi"
- 403 biasa (tanpa error_code) → pesan generik

#### 2. `mypresensi-web/app/api/mobile/attendance/submit/route.ts`

**Perubahan PALING KRITIS**: Tambah **Layer 6 Face Recognition Gate** (line 183-242).

Sebelumnya endpoint ini punya 5 layer validasi:
1. Sesi aktif
2. Kode cocok & belum expired
3. Mahasiswa enrolled di mata kuliah
4. Belum pernah submit (duplikat check)
5. GPS dalam radius (mode offline) + mock GPS reject

Sekarang tambah **Layer 6**:

```
Cek setting "face_verification_mode" dari DB:
  ├── "optional" → skip (backward compatible, tidak ada perubahan)
  └── "required" →
       ├── is_face_registered = false?
       │   → REJECT 403 + error_code "face_not_registered"
       │   → Audit log: "face_not_registered_attempt"
       │
       └── is_face_matched ≠ true?
           → REJECT 403 + error_code "face_mismatch"
           → Audit log: "face_mismatch_attempt"
```

Audit log menyimpan: student_id, NIM, session_id, mode sesi, device_id, user_agent — lengkap untuk forensik jika ada dispute.

Header comment file juga diupdate dari "5 layer" ke "6 layer".

#### 3. `mypresensi-web/app/api/mobile/settings/face-config/route.ts`

**Perubahan**: Default `DEFAULT_MODE` dari `'optional'` → `'required'`.

Ini fallback kalau DB gagal di-query (network error, tabel hilang). Dengan default `required`, jika ada masalah DB, sistem default ke mode aman (wajib face), bukan mode longgar.

### B. Mobile (Flutter) — 4 File Diubah

#### 1. `lib/features/attendance/data/attendance_models.dart`

**Perubahan**: Tambah class `AttendanceSubmitException`.

```dart
class AttendanceSubmitException implements Exception {
  final String message;
  final String? errorCode;  // "face_not_registered" | "face_mismatch" | null
  final int? statusCode;    // 403, 429, dll
  
  const AttendanceSubmitException(this.message, {this.errorCode, this.statusCode});
}
```

Sebelumnya error dari server cuma dilempar sebagai `String` biasa — tidak ada cara untuk membedakan jenis error.

#### 2. `lib/features/attendance/data/attendance_repository.dart`

**Perubahan**: Update method `_handleError()` untuk parse `error_code` dari response JSON.

```dart
// Kalau response punya error_code → throw AttendanceSubmitException (terstruktur)
if (data['error_code'] != null) {
  throw AttendanceSubmitException(
    data['error'] ?? 'Terjadi kesalahan',
    errorCode: data['error_code'],
    statusCode: response.statusCode,
  );
}

// Kalau tidak ada error_code → throw String message (backward compatible)
throw data['error'] ?? 'Gagal submit presensi';
```

#### 3. `lib/features/attendance/providers/attendance_provider.dart`

**Perubahan**: Tambah field `errorCode` di state + catch `AttendanceSubmitException`.

```dart
class AttendanceSubmitState {
  final AttendanceSubmitStatus status;
  final String? errorMessage;
  final String? errorCode;        // ← BARU
  final AttendanceSubmitResponse? response;
  // ...
}
```

Method `submitFromQr()` sekarang catch `AttendanceSubmitException` dan simpan `errorCode` ke state:

```dart
} on AttendanceSubmitException catch (e) {
  state = state.copyWith(
    status: AttendanceSubmitStatus.error,
    errorMessage: e.message,
    errorCode: e.errorCode,  // ← UI bisa baca ini
  );
  return false;
}
```

#### 4. `lib/features/attendance/screens/scan_qr_screen.dart`

**Perubahan PALING TERLIHAT** — inilah yang user alami saat absen.

**Alur SEBELUM Phase 2:**
```
Scan QR → Submit langsung → Hasil
```

**Alur SESUDAH Phase 2:**
```
Scan QR berhasil
  → Cek setting face_verification_mode dari server
    → "required"?
      → Cek isFaceRegistered di local state
        → BELUM daftar?
            → Dialog: "Wajah Belum Didaftarkan"
              Tombol "Daftar Sekarang" → navigasi ke /face-register
              Tombol "Batal" → kembali ke scanner
            → STOP (tidak submit)
        
        → SUDAH daftar?
            → Push screen /face-verify (kamera countdown 15 detik)
              → User cancel? → Pesan error "Verifikasi wajah dibatalkan"
              → Berhasil (match)? → Lanjut submit dengan face result
      
    → "optional"? → Submit langsung tanpa face (legacy behavior)

Submit ke server
  → Gagal?
    → Cek errorCode dari server response:
      → "face_not_registered" → Dialog redirect ke /face-register
      → "face_mismatch" → Dialog: "Wajah Tidak Cocok"
            Tombol "Coba Lagi" → kembali ke scanner
      → lainnya → Pesan error generik
  
  → Berhasil? → Navigasi ke halaman sukses
```

**Kenapa ada pengecekan di DUA tempat (mobile + server)?**

- **Mobile pre-flight** (cek isFaceRegistered sebelum submit): **fast feedback** — user langsung tahu tanpa nunggu network call ke server. Hemat bandwidth & waktu.
- **Server gate** (Layer 6 di route.ts): **fallback keamanan** — jaga kalau mobile di-bypass, cache stale, atau ada orang coba submit via curl/Postman langsung.

Ini pola "Defense in Depth" — dua lapis pertahanan di tempat berbeda.

### C. Database (Supabase)

| Perubahan | Detail |
|-----------|--------|
| INSERT setting baru | `face_verification_mode = 'required'` di tabel `settings` |
| Catatan | Sebelumnya row ini tidak ada. Sekarang eksplisit `required`. Admin bisa set kembali ke `'optional'` kalau mau non-aktifkan face wajib. |

### D. Verifikasi

| Perintah | Hasil |
|----------|-------|
| `npm run type-check` (TypeScript strict) | ✅ Exit 0, 0 errors |
| `flutter analyze` (static analysis) | ✅ No issues found |
| DB setting aktif | ✅ `face_verification_mode = 'required'` |

---

## Yang BELUM Dikerjakan

### Phase 3 — QR Rolling 5 Detik Dinamis (Layer 1)

Saat ini QR masih **statis** — isi QR (`session_id + code`) tidak berubah sepanjang sesi. Ini berarti kalau mahasiswa screenshot QR dan share ke grup, semua orang bisa pakai.

Phase 3 akan membuat kode QR **berubah setiap 5 detik** (mirip Google Authenticator):
- Server generate `seed` random saat dosen klik "Mulai Sesi"
- Kode dihitung dari `seed + counter` (counter naik setiap 5 detik)
- Web QR display auto-refresh setiap 5 detik
- Server toleransi ±2 window (efektif 15 detik toleransi) untuk account network latency
- Mobile **tidak ada perubahan** (kode tetap dibaca dari QR)

**Estimasi effort**: 4-6 jam

---

## Daftar File yang Disentuh (Total)

### Phase 1 & 1.5 (Dokumentasi Only)
1. `docs/plans/implementation_plan.md` — rewrite v6 → v7
2. `workflow_mypresensi.md` — update diagram alur
3. `CHANGELOG.md` — catat perubahan

### Phase 2 (Kode + DB)
4. `mypresensi-web/app/api/mobile/_lib/auth.ts` — extend errorResponse
5. `mypresensi-web/app/api/mobile/attendance/submit/route.ts` — Layer 6 Face Gate
6. `mypresensi-web/app/api/mobile/settings/face-config/route.ts` — default required
7. `mypresensi-mobile/lib/features/attendance/data/attendance_models.dart` — AttendanceSubmitException
8. `mypresensi-mobile/lib/features/attendance/data/attendance_repository.dart` — parse error_code
9. `mypresensi-mobile/lib/features/attendance/providers/attendance_provider.dart` — errorCode di state
10. `mypresensi-mobile/lib/features/attendance/screens/scan_qr_screen.dart` — pre-flight + dialogs
11. Supabase DB tabel `settings` — insert `face_verification_mode = 'required'`

---

## Catatan Keamanan

- **Backward compatible**: Kalau admin set `face_verification_mode = 'optional'` di DB → seluruh enforcement Layer 6 di-skip, kembali ke behavior lama.
- **Audit trail lengkap**: Setiap penolakan face tercatat di `audit_logs` dengan detail student_id, NIM, session_id, device_id, user_agent.
- **Tidak ada perubahan UI visual** (desain mockup tetap sama) — yang berubah hanya **flow navigasi** (kapan screen face verify muncul) dan penambahan 2 dialog popup.
