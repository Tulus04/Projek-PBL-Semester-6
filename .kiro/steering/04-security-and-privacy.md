---
inclusion: always
description: Aturan keamanan & privasi untuk MyPresensi — data classification, biometric handling, threat modeling checklist, sensitive field rules. Wajib dipatuhi.
---

# Security & Privacy — MyPresensi

MyPresensi proses data sensitif tinggi: **biometrik (face embeddings)**, **lokasi real-time GPS**, **data akademik mahasiswa**. Treat seperti production system enterprise.

## A. Data Classification

| Tier | Contoh | Aturan |
|------|--------|--------|
| **Tier 1 — Highly Sensitive** | Face embeddings (192-d), password hash, JWT token, service_role key, session_code aktif | Encrypt at rest (Supabase default), TIDAK pernah di-log, TIDAK pernah di-expose ke client/mobile, akses hanya `service_role` |
| **Tier 2 — Sensitive (PII)** | Email, NIM, NIP, full_name, foto profil, GPS coords (live), is_mock_location flag | RLS strict per-row, audit log saat akses massal, encrypt in transit (HTTPS), retain sesuai kebijakan |
| **Tier 3 — Internal** | Course list, schedule, attendance status, leave request | RLS per-role (dosen lihat MK-nya, mhs lihat dirinya sendiri), normal handling |
| **Tier 4 — Public** | Logo TRPL, halaman login, asset statis | Boleh akses anon |

**Aturan emas**: Field Tier 1 TIDAK pernah masuk ke response API, log file, error message, atau audit log details. Kalau perlu reference, pakai foreign key ID, jangan nilai aslinya.

## B. Biometric Data — Face Embeddings

Face embeddings adalah **data biometrik personal**. UU PDP Indonesia mengkategorikan ini sebagai **data spesifik** yang butuh proteksi ekstra.

### Aturan Wajib
1. **Storage**: hanya tabel `face_embeddings` (RLS aktif, hanya pemilik & service_role yang akses).
2. **Network**: TIDAK pernah dikirim mentah lewat response. Comparison dilakukan **server-side** di endpoint `/api/mobile/face/verify`. Mobile hanya kirim embedding kandidat untuk dibandingkan, server kembalikan boolean match + similarity score (tanpa bocorin embedding asli).
3. **Logging**: JANGAN log array embedding ke console / audit_logs. Kalau perlu debug, log similarity score saja.
4. **Retention**:
   - Saat **mahasiswa di-delete** (admin trigger atau soft-delete) → cascade DELETE row di `face_embeddings`.
   - Mahasiswa berhak **request hapus** face data via fitur "Hapus Wajah Terdaftar" di profil mobile (perlu diimplementasi sebagai fitur — saat ini belum ada).
   - Embedding lama (>1 tahun tidak login) → review kebijakan retention; saat ini default keep selama akun aktif.
5. **Consent**: Saat first-time face register, mobile WAJIB tampilkan dialog persetujuan dalam Bahasa Indonesia: "Wajah Anda akan disimpan sebagai data biometrik untuk verifikasi presensi. Data ini hanya digunakan internal kampus dan dapat dihapus kapan saja melalui menu Profil. Lanjutkan?". User klik "Setuju" baru proses berlanjut. Tolak = tidak boleh register.
6. **Source of truth**: 1 mahasiswa = 1 embedding (UNIQUE constraint di `student_id`). Update embedding = OVERWRITE, bukan append.

### Yang TIDAK Boleh
- ❌ Simpan foto wajah mentah (RGB image) di Supabase Storage. Hanya embedding (float[192]).
- ❌ Kirim embedding ke pihak ketiga / external service.
- ❌ Pakai embedding untuk identifikasi tanpa consent (mis. tracking, statistik wajah).
- ❌ Tampilkan embedding di UI admin/dosen dalam bentuk array — boleh "Sudah terdaftar / Belum" + tanggal saja.

## C. Sensitive Field Rules

### `session_code` (OTP 6 digit)
- **Generate**: `crypto.randomInt(100000, 999999)` di server saat dosen klik "Mulai Sesi".
- **Storage**: kolom `sessions.session_code` (text), dengan `session_code_expires_at`.
- **Akses**: HANYA dosen pemilik MK yang lihat (web UI dosen + QR display). TIDAK pernah di-return via GET endpoint mobile.
- **TTL**: default 3 menit (`settings.session_code_expiry_minutes`). Setelah expired, tetap di DB tapi reject saat verifikasi submit.
- **Refresh**: dosen bisa generate ulang via "Refresh Kode" → invalidate yang lama (UNIQUE per session — yang baru overwrite).

### `audit_logs`
- **Insert**: hanya via `createAdminClient()` (RLS deny untuk non-service_role sejak migration 006). Lihat `app/lib/audit-logger.ts`.
- **Read**: hanya admin via halaman `/audit`. JANGAN expose ke `/api/mobile/*`.
- **Content**: jangan masukkan field Tier 1 ke `details` JSON. OK simpan: user_id (otomatis), action, target_id, sebelum-sesudah field non-sensitif.
- **IP capture — TIDAK otomatis**: `audit-logger.ts` saat ini hardcode `ip_address: null` karena Server Action tidak punya akses langsung ke client IP. Untuk endpoint mobile (`/api/mobile/*`) yang punya akses `req.headers.get('x-forwarded-for')`, **passing IP manual** lewat `details`:
  ```ts
  const ipAddress = req.headers.get('x-forwarded-for') ?? req.headers.get('x-real-ip') ?? null
  await logAudit({
    action: 'mobile_attendance_submit',
    details: { student_id: user.id, ip: ipAddress, user_agent: req.headers.get('user-agent'), /* ... */ },
  })
  ```
  Catatan: kolom `attendances.ip_address` SUDAH capture IP otomatis di `attendance/submit/route.ts:204` — itu DI tabel attendances, BUKAN di audit_logs. Jangan campur kedua mekanisme.

### `attendances.distance_meters` & GPS coords
- Server-side hitung Haversine di `/api/mobile/attendance/submit` — **tidak trust** GPS coords mentah dari client untuk penentuan in-radius.
- Coords mentah disimpan di `attendances.student_lat`, `attendances.student_lng` untuk audit (kalau ada dispute), TAPI gating logika pakai hasil hitung server.
- `is_mock_location = true` → **REJECT 403** + `logAudit('mock_location_detected')`. Server tidak insert presensi.
- Mode sesi `online` → skip GPS check (mahasiswa boleh dari mana saja, `distance_meters = 0`, `is_location_valid = true`). Mode `offline` → enforce radius dari `sessions.location_lat/location_lng` dan `sessions.radius_meters`.

### Password
- Di-hash bcrypt oleh Supabase Auth — TIDAK ada kolom `password` di tabel public.
- Default password mahasiswa: `<NIM>@politani` + flag `must_change_password = true` → mahasiswa wajib ganti via web sebelum bisa login mobile.
- Password reset: pakai `supabase.auth.admin.updateUserById(id, { password: newPwd })` + set `must_change_password = true`. Jangan kirim password baru lewat email (untuk saat ini cetak manual atau tampilkan ke admin).

## D. Threat Model — Wajib Cek per Fitur

Sebelum implementasi fitur yang menyentuh Tier 1/2 data, jawab checklist ini:

### 1. Authentication & Authorization
- [ ] Siapa yang boleh akses fitur ini? (admin/dosen/mahasiswa/anon)
- [ ] Layer mana yang gate? (middleware? server action? RLS? semuanya?)
- [ ] Apakah ada IDOR risk? (user A bisa akses data user B dengan tweak ID di URL/body?) → cek ownership eksplisit
- [ ] JWT validation — apakah `authenticateRequest()` dipanggil? Bearer token diparse benar?

### 2. Input Validation
- [ ] Apakah pakai Zod schema? Pesan error Bahasa Indonesia?
- [ ] Field mana dari client yang DI-TRUST? Yang DI-IGNORE? (mis. `user_id` di body → IGNORE, ambil dari `auth.user.id`)
- [ ] Apakah ada mass assignment risk? (loop `Object.assign(record, body)` tanpa whitelist?)
- [ ] Numeric range (radius_meters > 0?), string length (full_name ≤ 100?), enum value (status valid?) — semua dicek?

### 3. Rate Limiting & Abuse Prevention
- [ ] Endpoint kritis (login, submit, face register) punya rate limit?
- [ ] Limit berdasarkan apa? (user_id? IP? device_id?)
- [ ] Apa response saat hit limit? (HTTP 429 + pesan ramah)
- [ ] Brute force: `max_login_attempts` + `lockout_minutes` di-honor?

### 4. Data Exposure
- [ ] Field apa yang di-return ke client? Apakah ada Tier 1 yang bocor?
- [ ] Error message: aman ditampilkan? Tidak bocor struktur DB / SQL / stack?
- [ ] `JOIN` Supabase: apakah ada field tetangga yang ikut ke-fetch padahal tidak perlu?

### 5. Audit & Monitoring
- [ ] `logAudit()` dipanggil untuk mutasi penting?
- [ ] Action name snake_case konsisten?
- [ ] Details JSON cukup informatif untuk forensic, tapi tidak bocor secret?

### 6. Data Integrity
- [ ] UNIQUE constraint di tabel mencegah duplikat? (mis. `(session_id, student_id)` di `attendances`)
- [ ] Foreign key + ON DELETE behavior sesuai? (CASCADE vs SET NULL vs RESTRICT)
- [ ] CHECK constraint melindungi enum / range?

## E. Anti-Patterns

JANGAN lakukan ini, akan langsung di-reject dalam review:

### Web
- ❌ `createAdminClient()` di Client Component (`'use client'` file).
- ❌ Service role key di-import / di-print di komponen.
- ❌ Trust `formData.get('user_id')` tanpa cross-check `auth.user.id`.
- ❌ Pesan error Supabase mentah: `{ error: error.message }` → bocor struktur.
- ❌ `console.log(token)` / `console.log(embedding)` di production code.
- ❌ Tampilkan email user di error: "User dengan email X tidak ditemukan" → user enumeration. Pakai pesan generik "Email atau password salah".

### Mobile
- ❌ Simpan token di `shared_preferences` (pakai `flutter_secure_storage`).
- ❌ Hardcode JWT atau API key di kode.
- ❌ Log Bearer token ke `debugPrint`.
- ❌ Pakai `http://` di release build (cleartextTrafficPermitted=true) tanpa whitelist.
- ❌ Kirim `face_embedding` mentah ke endpoint non-MyPresensi.
- ❌ Trust `position.isMocked = false` dari client tanpa server validation.

### Database
- ❌ Tabel baru tanpa RLS aktif.
- ❌ Policy yang `USING (true)` tanpa filter `auth.uid()`.
- ❌ `GRANT ALL ON ... TO public` atau `TO anon` tanpa alasan.
- ❌ SECURITY DEFINER function tanpa `SET search_path`.
- ❌ Migration yang DROP table production data tanpa backup.

## F. Incident Response (Singkat)

Kalau ada indikasi insiden (data bocor, brute force, akun curian):
1. **Snapshot** state DB (screenshot, query export) — jangan langsung delete bukti.
2. **Cek `audit_logs`** sekitar window waktu insiden — filter by user_id atau action.
3. **Rotate** kredensial yang berpotensi bocor (Supabase service_role key di Settings → API → Reset).
4. **Lockout** akun yang dicurigai (set `is_active = false` di `profiles`).
5. **Document** di `dev-log.md` atau file insiden khusus — apa yang terjadi, kapan ketahuan, mitigasi yang diambil.
6. **Tinggalkan postmortem** untuk rule baru atau perbaikan.

## G. Compliance Note (UU PDP Indonesia)

UU 27/2022 (PDP) berlaku untuk MyPresensi karena memproses data pribadi mahasiswa Politani:
- **Data spesifik** (Pasal 4): biometrik, kesehatan, anak — perlakuan ekstra.
- **Hak subjek data** (Pasal 5-15): akses, koreksi, hapus, withdraw consent.
- **Pemberitahuan pelanggaran** (Pasal 46): wajib lapor 3×24 jam ke pemilik data + otoritas kalau ada kebocoran.
- **DPO/PIC**: untuk skala kampus, dosen pembimbing PBL atau IT kampus bisa jadi titik kontak.

Implementasi fitur baru WAJIB dipertimbangkan dari sudut hak subjek data — terutama "hak hapus".
