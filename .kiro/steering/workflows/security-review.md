---
inclusion: manual
description: Pre-merge security review checklist untuk fitur baru yang menyentuh data sensitif (auth, attendance, face, izin, profile, password reset, audit). Wajib lewati semua checkpoint sebelum merge.
---

# /security-review — Pre-Merge Security Checklist

Workflow untuk audit keamanan fitur baru sebelum merge ke `main` atau dianggap selesai. Berbasis `04-security-and-privacy.md`.

## Kapan pakai workflow ini?

Wajib jalankan untuk fitur yang menyentuh:
- Auth (login, logout, password reset, JWT validation)
- Attendance (submit, GPS, mock detection)
- Face (register, verify, embedding)
- Izin (leave request, approval)
- Profile (update email, avatar, password)
- Audit log (read access, export)
- Settings (terutama yang affect security: rate limit, threshold, expiry)
- Tabel/migration baru
- Endpoint mobile baru (`/api/mobile/*`)

Untuk perubahan UI murni (warna, layout, copy text) — tidak perlu workflow ini.

---

## Checkpoint 1 — Authentication & Authorization

### Server (Web / API Mobile)
- [ ] **Auth check ada di awal handler**:
  - Server Action: `requireRole(['admin', 'dosen'])` atau `getCurrentUserProfile()`
  - Route Handler mobile: `authenticateRequest(req)`
- [ ] **Role yang diizinkan eksplisit** — tidak ada role allowlist berbentuk `if (role !== 'foo')` (negation logic mudah salah).
- [ ] **Ownership check** kalau resource per-user (mis. `canAccessCourse(userId, role, courseId)` untuk dosen yang hanya boleh kelola MK miliknya).
- [ ] **Admin bypass** terdokumentasi — admin boleh akses semua MK, tapi WAJIB tetap lewat `requireRole(['admin'])`.
- [ ] **`createAdminClient()` HANYA dipakai SETELAH** auth check di atasnya.

### Client (Web Component / Mobile UI)
- [ ] Tidak ada call `createAdminClient()` dari Client Component (`'use client'`).
- [ ] Tidak ada service_role key di-bundle ke client (cek `npm run build` output).
- [ ] Mobile: tidak ada hardcode JWT atau API key di kode.

---

## Checkpoint 2 — Input Validation

- [ ] **Zod schema** untuk SEMUA input dari client (formData, request body, query params).
- [ ] **Pesan error Zod dalam Bahasa Indonesia** ("Nama minimal 3 karakter" bukan "name must be at least 3 chars").
- [ ] **Field yang TIDAK trust dari client** dieksplisitkan:
  - `user_id` di body → IGNORE, ambil dari `auth.user.id`
  - `role` di body → IGNORE, ambil dari `profiles.role`
  - GPS coords → server hitung Haversine sendiri
  - `is_mock_location` → kirim apa adanya, server reject jika true
- [ ] **Mass assignment dicegah** — eksplisit list field yang di-update, bukan `Object.assign(record, body)`.
- [ ] **Numeric range valid**:
  - `radius_meters > 0`
  - `expiry_minutes > 0 && < 60`
  - `confidence_threshold >= 0 && <= 1`
- [ ] **Enum value valid** — pakai `z.enum([...])` atau CHECK constraint DB.

---

## Checkpoint 3 — Rate Limiting & Abuse Prevention

- [ ] **Endpoint kritis** punya rate limit:
  - Login: `max_login_attempts` di settings + `lockout_minutes`
  - Submit attendance: 10/menit per user (lihat `/api/mobile/attendance/submit`)
  - Face register: 3/15 menit per user
  - Password reset: 3/hari per akun
- [ ] **Limit basis** sesuai dengan attack vector:
  - Login → per email/IP (anonim)
  - Submit → per user (authenticated)
  - Public form → per IP
- [ ] **Response 429** dengan pesan ramah Indonesia: "Terlalu banyak permintaan. Coba lagi dalam beberapa menit."
- [ ] **Penalty progresif** untuk repeated abuse (kalau ada): lockout makin lama tiap kena.

---

## Checkpoint 4 — Data Exposure

### Response Body
- [ ] Field Tier 1 (face embedding, password hash, JWT, session_code aktif) **tidak pernah** di-return ke client.
- [ ] Field Tier 2 (email, NIM) hanya di-return ke owner / admin / dosen yang berhak.
- [ ] `JOIN` Supabase: pakai `.select('id, name, ...')` eksplisit, bukan `.select('*')`.
- [ ] `.select('user:profiles(...)')` — pastikan field yang ikut tidak bocor (mis. jangan ikut `password_hash` kalau ada).

### Error Message
- [ ] Tidak bocor struktur DB (mis. "duplicate key value violates unique constraint 'users_email_key'" → ganti jadi "Email sudah terdaftar").
- [ ] Tidak bocor user enumeration ("User dengan email X tidak ada" → "Email atau password salah").
- [ ] Tidak ada stack trace di production response.
- [ ] Pesan error spesifik tetap aman secara semantik (mis. "Format NIM tidak valid" OK, "INSERT failed: column nim doesn't exist" TIDAK OK).

### Logging
- [ ] Tidak ada `console.log(token)` / `debugPrint(jwt)`.
- [ ] Tidak ada `console.log(embedding)` (array biometrik).
- [ ] Audit log details tidak masukkan field Tier 1.
- [ ] Production log level set appropriate (info untuk operasi normal, error untuk failure).

---

## Checkpoint 5 — Audit & Monitoring

- [ ] **`logAudit()` dipanggil** untuk SEMUA mutasi penting (create/update/delete/toggle/reset).
- [ ] **Action name snake_case** dan konsisten dengan yang sudah ada (`create_session`, `mobile_attendance_submit`, dll). Cari nama serupa di `app/lib/actions/*.ts` sebelum bikin baru.
- [ ] **Details JSON informatif**: who, what, before-after (untuk update). Tidak masukkan secret.
- [ ] **`logAudit` pakai admin client** (sejak migration 006, RLS reject insert dari non-service_role).

---

## Checkpoint 6 — Database & RLS

- [ ] **RLS aktif** di tabel baru: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`
- [ ] **Minimal 1 policy SELECT** ada (default DENY tanpa policy).
- [ ] **Policy pakai `auth.uid()`** bukan parameter dari client.
- [ ] **`mcp0_get_advisors({ type: 'security' })`** dijalankan, 0 issue baru.
- [ ] **Function SECURITY DEFINER** punya `SET search_path = public, pg_temp`.
- [ ] **FK punya index** untuk performance (cek `mcp0_get_advisors({ type: 'performance' })`).
- [ ] **CHECK constraint** untuk enum value (`status IN ('hadir', 'izin', 'sakit', 'alpa')`).
- [ ] **UNIQUE constraint** untuk integrity (`(session_id, student_id)` untuk attendance).
- [ ] **CASCADE behavior** sesuai (delete user → cascade `face_embeddings`, `attendances`, `notifications`).

---

## Checkpoint 7 — Session & Token Security

- [ ] **JWT expiry** sesuai (Supabase default 1 jam, dengan refresh token untuk renew).
- [ ] **Refresh token** disimpan secure (mobile: `flutter_secure_storage`, web: httpOnly cookie via Supabase SSR).
- [ ] **Logout** clear semua: storage + Dio reset + state (di-test).
- [ ] **JWT signature** divalidasi server-side (Supabase auto, JANGAN parse JWT manual tanpa verify).
- [ ] **Session timeout** setelah idle (untuk web, opsional — mobile tetap login sampai logout).

---

## Checkpoint 8 — Privacy & Consent

### Untuk fitur biometric (face)
- [ ] **Dialog consent** ditampilkan sebelum first-time face register: "Wajah Anda akan disimpan sebagai data biometrik untuk verifikasi presensi..."
- [ ] **Tolak consent** = tidak bisa register, dengan path alternatif (mis. fallback ke PIN/OTP saja).
- [ ] **Hak hapus**: ada tombol "Hapus Wajah Terdaftar" di profil mobile (jika fitur ini ada di scope; kalau belum, dokumentasikan sebagai TODO).
- [ ] **Saat user di-delete**: cascade delete `face_embeddings` (lewat FK ON DELETE CASCADE).

### Untuk fitur lokasi
- [ ] **Permission rationale** ditampilkan: "Aplikasi memerlukan akses lokasi untuk verifikasi kehadiran di area kampus."
- [ ] **Lokasi hanya diambil saat submit** (bukan terus-menerus / background).
- [ ] **Tidak ada tracking** mahasiswa di luar konteks presensi.

---

## Checkpoint 9 — Migration & Schema Change

Hanya untuk PR yang mengandung migration baru:
- [ ] File `00X_<nama>.sql` ada di `supabase/migrations/`.
- [ ] **Idempotent**: `IF NOT EXISTS`, `ON CONFLICT DO NOTHING`.
- [ ] **`ENABLE ROW LEVEL SECURITY`** segera setelah `CREATE TABLE`.
- [ ] **Policy** untuk role yang relevan.
- [ ] **Index** untuk kolom WHERE/JOIN/ORDER BY.
- [ ] **Trigger updated_at** kalau ada kolom tersebut.
- [ ] **Apply via MCP** (`mcp0_apply_migration`) atau dokumentasikan manual apply di CHANGELOG.
- [ ] **`app/types/database.ts`** ter-update.
- [ ] **`mcp0_get_advisors`** security: 0 issue baru.

---

## Checkpoint 10 — Smoke Test Final

Setelah semua checkbox di atas tercentang:

```powershell
# Web
cd mypresensi-web
npm run type-check
npm run lint
npm run build      # untuk pre-merge

# Mobile (jika fitur menyentuh mobile)
cd ../mypresensi-mobile
flutter analyze
flutter pub get
flutter build apk --debug
```

- [ ] Type-check / analyze: 0 errors
- [ ] Build berhasil (exit 0)
- [ ] Login → akses fitur → mutasi → audit log muncul → logout → login ulang → state clean
- [ ] Negative test: tanpa auth → 401, dengan role salah → 403, input invalid → 400 dengan pesan Indonesia
- [ ] Dengan mock GPS (release build/HP fisik) → 403 + audit `mock_location_detected`

---

## Output

Kalau SEMUA checkpoint pass → fitur boleh merge. Catat di CHANGELOG dengan tag `[SEC]` atau `[ADD]`.

Kalau ADA checkpoint yang tidak pass → STOP, perbaiki dulu sebelum merge. JANGAN bilang "selesai" tanpa pass semua.

## Catatan

Workflow ini WAJIB untuk fitur sensitif. Untuk perubahan kecil (tweak UI, fix typo), tidak perlu — tapi untuk apapun yang menyentuh data Tier 1/2 atau auth flow, JANGAN skip.
