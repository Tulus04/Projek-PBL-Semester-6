---
inclusion: always
description: Overview proyek MyPresensi (PBL TRPL Politani) — arsitektur, role, dan struktur monorepo. Dibaca pada setiap percakapan.
---

# MyPresensi — Overview Proyek

Sistem absensi mahasiswa dengan **3 layer verifikasi** (OTP/QR + GPS + Face Recognition) untuk Prodi TRPL, Politeknik Pertanian Negeri Samarinda. Proyek PBL Semester 6.

## Struktur Monorepo

```
Projek-PBL-Semester-6/
├── mypresensi-web/          ← Next.js 14 (Admin & Dosen) + API mobile
├── mypresensi-mobile/       ← Flutter (Mahasiswa)
├── docs/plans/              ← implementation_plan.md (sumber kebenaran)
├── workflow_mypresensi.md   ← diagram alur Mermaid (referensi non-teknis)
├── dev-log.md               ← log teknis tiap sesi
├── CHANGELOG.md             ← daftar perubahan per sesi/tanggal
└── credentials-MUSTREAD.txt ← akun admin (jangan commit)
```

## Tech Stack

### Web (`mypresensi-web/`)
| Library | Versi | Pakai untuk |
|---------|-------|-------------|
| `next` | `14.2.35` | App Router framework |
| `react` + `react-dom` | `18.3.1` (BUKAN 19) | UI library — pakai `useFormState`/`useFormStatus`, BUKAN `useActionState` |
| `typescript` | `5.x` | Strict mode |
| `tailwindcss` | `3.4.17` | Utility class layout & spacing |
| `@supabase/ssr` + `@supabase/supabase-js` | `0.10.x` + `2.101.x` | Auth + DB cookie-based SSR |
| `zod` | `3.23.8` | Validasi server action / API |
| `sweetalert2` | `11.26.x` | Toast + konfirmasi destruktif |
| `lucide-react` | `1.7.x` | Ikon |
| `recharts` | `3.8.x` | Grafik & chart |
| `papaparse` | `5.5.x` | CSV parse/generate |
| `jspdf` + `jspdf-autotable` | `4.x` + `5.x` | PDF export |
| `qrcode.react` | `4.2.x` | QR display |
| `react-easy-crop` | `5.5.x` | Crop avatar |
| `clsx` + `tailwind-merge` | `2.x` + `3.x` | `cn()` utility |

### Mobile (`mypresensi-mobile/`)
| Library | Versi | Pakai untuk |
|---------|-------|-------------|
| Flutter SDK | `^3.11.4` | Framework |
| `flutter_riverpod` + `riverpod` | `3.3.x` + `3.2.x` | State management |
| `go_router` | `17.2.x` | Routing dengan `refreshListenable` |
| `dio` | `5.9.x` | HTTP client + interceptor |
| `flutter_secure_storage` | `10.0.x` | Token & secret (BUKAN `shared_preferences`) |
| `mobile_scanner` | `7.2.x` | Scan QR (minSdk 26) |
| `google_mlkit_face_detection` | `0.13.2` | Face detection (bbox + liveness) |
| `tflite_flutter` + `image` | `0.12.x` + `4.8.x` | MobileFaceNet inference (192-d embedding) |
| `camera` | `0.12.x` | Live camera (ResolutionPreset.high untuk face) |
| `geolocator` | `14.0.x` | GPS + `isMocked` anti fake-GPS |
| `permission_handler` | `12.0.x` | Runtime permission request |
| `device_info_plus` | `12.4.x` | Device model & OS untuk audit log |
| `flutter_native_splash` | `2.4.x` | Splash screen native |
| `google_fonts` | `8.0.x` | Plus Jakarta Sans + Inter |
| `image_picker` | `1.1.x` | Pilih foto bukti izin/sakit (gallery + camera) |

> **Deps yang DIHAPUS sesi 2026-05-14 cleanup** (boleh ditambah kembali saat fitur konkret dikerjakan): `cached_network_image` (belum ada avatar widget yang butuh cache), `shimmer` (belum ada skeleton loading di mobile screen), `connectivity_plus` (belum ada offline detection di mobile), `cupertino_icons` (tidak dipakai), `flutter_driver` + `integration_test` (tidak ada e2e test plan).

### Backend
| Service | Catatan |
|---------|---------|
| Supabase (Postgres + Auth + Storage) | Project ref di `mypresensi-web/.env.local` |
| Edge Functions | Tidak dipakai (semua via Next.js Route Handler) |
| MCP Supabase | Aktif sejak 2026-05-14 — pakai `mcp0_apply_migration` untuk DDL baru |

## Pembagian Role & Platform

| Role | Platform | Akses |
|------|----------|-------|
| **Admin** | Web only | Master data (mahasiswa, dosen, MK), settings, audit log, export, lokasi kampus |
| **Dosen** | Web only | Buat/mulai sesi, generate OTP, QR display, monitor presensi, approve izin, rekap |
| **Mahasiswa** | Mobile only | Login, scan QR, GPS, face register/verify, riwayat, notifikasi |

> Middleware web (`mypresensi-web/middleware.ts`) memblok mahasiswa masuk dashboard.
> Endpoint mobile (`/api/mobile/*`) memblok admin/dosen via `authenticateRequest()`.

## Alur Inti Presensi

1. Dosen klik **Mulai Sesi** → server generate **OTP 6 digit** (expired ~3 menit) + QR berisi `{session_id, code}`.
2. Mahasiswa scan QR di mobile → app ambil GPS + (opsional) face verify → POST `/api/mobile/attendance/submit`.
3. Server validasi **5 layer**: sesi aktif → kode cocok & belum expired → mahasiswa enrolled → belum pernah submit → GPS dalam radius (mode offline) atau skip (online).
4. **`is_mock_location = true` → langsung REJECT** (status 403 + audit log `mock_location_detected`).
5. Insert `attendances` + `logAudit('mobile_attendance_submit')` + kirim notifikasi.

## Database (Supabase)

Migrations sudah jalan di `mypresensi-web/supabase/migrations/`:

- `001_initial_schema.sql` — `profiles`, `face_embeddings`, `courses`, `enrollments`, `sessions`, `attendances`, `leave_requests`, `settings`, `audit_logs`, `rate_limit_log` + RLS lengkap
- `002_notifications.sql` — `notifications` + RLS per user
- `003_face_verification_mode.sql` — setting `face_verification_mode: optional|required`
- `004_campus_locations.sql` — `campus_locations` (preset GPS) + seed Politani `(-0.5378, 117.1242)`
- `005_mobilefacenet_threshold.sql` — update threshold default 0.65 (LFW MobileFaceNet 192-d) menggantikan 0.75 lama
- `006_security_hardening.sql` — REVOKE SELECT dari role `anon`, audit_logs/notifications insert hanya via service_role, function `search_path` eksplisit
- `007_disable_graphql.sql` — DROP `pg_graphql` extension (CASCADE); MyPresensi tidak pakai GraphQL
- `008_avatar_listing_hardening.sql` — DROP policy broad SELECT untuk bucket `avatars` (cegah LIST exposure)
- `009_rate_limit_log_explicit_policy.sql` — Explicit DENY policy `FOR ALL TO authenticated, anon USING (false)` untuk silence INFO advisor
- `010_fk_indexes.sql` — 6 FK index: `audit_logs.user_id`, `courses.dosen_id`, `leave_requests.{reviewed_by,session_id}`, `rate_limit_log.user_id`, `sessions.dosen_id`
- `011_rls_auth_initplan.sql` — Refactor 21 policy: `auth.uid()` → `(SELECT auth.uid())` (Postgres evaluate sekali per query, bukan per row)
- `012_consolidate_permissive_policies.sql` — Konsolidasi multi-permissive policies di `attendances`/`campus_locations`/`courses`/`enrollments`/`leave_requests`; split `FOR ALL` ke command-spesifik

**Konvensi penomoran migration**:
- File lokal di `supabase/migrations/`: tetap pakai `00X_<nama>.sql` (sequential, 1-indexed) untuk readability di repo.
- History Supabase via MCP (`mcp0_apply_migration`): otomatis pakai timestamp `YYYYMMDDhhmmss_<nama>` (mis. `20260514050201_security_hardening`).
- Sejak 2026-05-14: migration baru WAJIB lewat MCP agar ke-track di Supabase history. Manual via SQL Editor TIDAK tracked.

**Trigger penting**: `handle_new_user()` AFTER INSERT pada `auth.users` auto-membuat row di `profiles`. Function ini punya `SET search_path = public, pg_temp` (sejak migration 006) — saat tulis SECURITY DEFINER function baru, WAJIB ikuti pola ini.

**Akses role (sejak migration 006)**:
- `anon` — TIDAK punya SELECT ke tabel public manapun. Mobile pakai `service_role` via `/api/mobile/*`. Web SSR pakai `authenticated` (cookie).
- `authenticated` — punya SELECT ke tabel public, gating per-row via RLS. Web SSR butuh ini.
- `service_role` — bypass RLS via `createAdminClient()`. HANYA di Server Action / Route Handler **setelah** auth check.

**RLS pattern WAJIB** (sejak migration 011): pakai `(SELECT auth.uid())` BUKAN `auth.uid()` direct di policy USING/WITH CHECK. Postgres evaluate (SELECT ...) sekali per query, jauh lebih cepat di skala besar. Ref: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

## Settings Default (tabel `settings`)

```
geofence_radius_meters       = 150
face_confidence_threshold    = 0.65   ← MobileFaceNet 192-d (LFW benchmark), updated migration 005
session_code_expiry_minutes  = 3
max_login_attempts           = 5
lockout_minutes              = 30
face_verification_mode       = optional
```

> **Catatan**: Threshold 0.65 untuk MobileFaceNet (TFLite) — JANGAN balik ke 0.75 (nilai lama untuk landmark heuristic embedding yang sudah ditinggalkan). Lihat `mypresensi-mobile/lib/features/face/services/face_embedding_service.dart` `defaultThreshold`.

## Status Kehadiran

`hadir` · `izin` · `sakit` · `alpa` (CHECK constraint di `attendances.status`).
Catatan: "terlambat" sebagai konsep ada di workflow tapi BELUM diimplementasi sebagai enum DB — saat ini hanya `hadir` + flag `distance_meters`/waktu.

## Bahasa

- **Semua pesan user-facing**: Bahasa Indonesia (login error, validasi Zod, snackbar, dialog).
- **Komentar header file**: Bahasa Indonesia singkat menjelaskan tujuan + catatan keamanan jika relevan.
- **Nama variabel/fungsi**: Inggris (`getCurrentUserProfile`, `submitFromQr`, dll).

## File Sensitif (JANGAN commit / JANGAN expose)

- `mypresensi-web/.env.local` — Supabase URL + anon + service_role key
- `mypresensi-web/.dev-accounts.md` — kredensial test
- `credentials-MUSTREAD.txt` — akun admin
- `mypresensi-mobile/android/app/google-services.json` (jika ada)

## Referensi Cepat

- Diagram alur Mermaid lengkap → `workflow_mypresensi.md`
- Plan teknis & threat analysis → `docs/plans/implementation_plan.md`
- Rekap perubahan kronologis → `CHANGELOG.md` & `dev-log.md`
