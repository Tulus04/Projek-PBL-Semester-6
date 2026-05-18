# Spec: Upload Avatar Mobile (P3-#3)

> **Status**: Done (pending user smoke test)
> **Created**: 2026-05-16
> **Priority**: P3 (Backend feature, low impact polish)
> **Estimated effort**: 1-2 jam (actual ~1 jam)

## Konteks

Sebelumnya avatar mahasiswa hanya bisa diset via web admin (Server Action `updateProfileAction`). Mobile profile screen render avatar tapi mahasiswa tidak punya cara untuk update sendiri. Setelah P3-#1 (leave evidence upload) selesai, infra image picker + storage utils sudah ada — reuse untuk fitur ini.

## Keputusan Arsitektur

| Aspek | Pilihan | Alasan |
|-------|---------|--------|
| Bucket | **Reuse `avatars` existing (public)** | Sudah ada sejak migration awal, RLS authenticated insert sudah aktif. Tidak perlu migration baru. |
| Path convention | `<user.id>.jpg` | Sama dengan pola web Server Action (`uploadAvatar` di profile.ts). Upsert true → replace foto lama otomatis. |
| File limit | 5 MB | Sama dengan leave-evidence (konsisten via `MAX_IMAGE_SIZE_BYTES`). |
| Mime types | jpeg/png/webp | Reuse `ALLOWED_IMAGE_MIME` dari storage-utils. |
| Validation | Magic bytes + size + mime | Reuse `validateMagicBytes` + `isAllowedImageMime`. |
| Mobile package | `image_picker ^1.1.0` | **Sudah ditambahkan di P3-#1** — reuse, tidak perlu nambah deps. |
| Cache busting | URL ditambah `?t=<timestamp>` | Mobile yang sudah cache URL lama auto-fetch versi baru. |

## Threat Model

### Attack vectors yang ditutup
1. **Mahasiswa A replace foto B**: server lock path ke `<user.id>.jpg` (bukan dari client) → mahasiswa A tidak bisa upload ke `<B>.jpg`
2. **Upload non-image**: magic bytes + mime check
3. **Upload massive file (DoS)**: limit 5 MB di endpoint + bucket-level
4. **Spam upload**: rate limit 5 upload / 10 menit per (user + device)
5. **CSRF/replay**: Bearer JWT + audit log per upload

### Yang tidak relevan
- Public visibility avatar URL: by design — bucket avatars sudah public sejak awal proyek, foto profil memang umum dilihat publik internal kampus
- Multiple file: spec hanya 1 avatar per user (upsert replace lama)

## Implementasi

### Server (Web)
- `app/api/mobile/profile/avatar/route.ts` — POST endpoint
  - Auth + rate limit + multipart parse + magic bytes
  - Upload ke bucket avatars dengan path `<user.id>.jpg` upsert
  - Get public URL + cache buster `?t=<timestamp>`
  - Update `profiles.avatar_url` (non-fatal kalau gagal — file sudah upload)
  - Audit `mobile_avatar_upload`
  - Return `{ avatar_url, message }`

### Mobile
- `lib/features/profile/data/profile_repository.dart` — `uploadAvatar(File)` multipart
- `lib/features/profile/providers/profile_provider.dart` — `AvatarUploadNotifier` state machine (idle/uploading/success/error)
- `lib/features/auth/providers/auth_provider.dart` — method baru `markAvatarUpdated(newUrl)` untuk update local user state tanpa flash loading
- `lib/features/profile/screens/profile_screen.dart`:
  - Convert dari `ConsumerWidget` → `ConsumerStatefulWidget` (butuh state untuk image picker)
  - Avatar GestureDetector tap → bottom sheet pilihan source
  - Render `Image.network(user.avatarUrl)` dengan fallback ke initials avatar
  - Camera badge overlay di pojok bawah avatar (icon kamera atau spinner saat uploading)
  - Tombol "Ganti Foto Profil" sebagai entry alternatif

### API endpoint constant
- `lib/core/network/api_endpoints.dart` — tambah `profileAvatar = '/api/mobile/profile/avatar'`

## Verifikasi

| Item | Hasil |
|------|-------|
| `npm run type-check` (web) | exit 0 ✓ |
| `flutter analyze` (mobile) | No issues found ✓ |
| Tidak butuh migration baru (reuse bucket existing) | ✓ |

## User Smoke Test (pending)

- A1: Mahasiswa login → tab Profil → tap avatar → bottom sheet muncul
- A2: Pilih galeri → pilih foto JPG → upload progress (spinner di camera badge) → success snackbar → avatar refresh
- A3: Hot restart app → avatar tetap muncul (load dari URL yang baru)
- A4: Upload non-image (rename `.txt` jadi `.jpg`) → reject 400 dengan pesan magic bytes
- A5: Upload 6 kali dalam 10 menit → kena rate limit 429

## Compliance Rules

- ✅ `04-security-and-privacy.md` Section A: Tier 2 PII (foto profil) — RLS authenticated only insert, audit log lengkap
- ✅ `14-web-supabase-patterns.md` Section B: defense-in-depth (auth → endpoint role check → RLS → magic bytes)
- ✅ `03-design-and-libraries.md`: image_picker sudah lock dari P3-#1, reuse di sini tidak perlu diskusi baru
- ✅ `02-quality-debugging-verification.md`: gate verifikasi run sebelum claim selesai
