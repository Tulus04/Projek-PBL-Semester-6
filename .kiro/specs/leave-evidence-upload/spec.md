# Spec: Upload Bukti Izin/Sakit (P3-#1)

> **Status**: In Progress
> **Created**: 2026-05-16
> **Priority**: P3 (Backend feature)
> **Estimated effort**: 2-3 jam

## Konteks

Schema kolom `leave_requests.evidence_url TEXT` sudah ada sejak migration 001. Endpoint submit (`POST /api/mobile/leave-requests/submit`) sudah accept field `evidence_url` (Zod optional URL). Web admin/dosen approval table sudah render link "Lihat Bukti" via `evidence_url`.

**Yang masih missing**:
1. Storage bucket untuk simpan file
2. Endpoint upload server-side (validasi + place file di bucket)
3. UI mobile: tombol pilih foto + preview + integrasi ke flow submit
4. Endpoint signed URL untuk web admin/dosen view
5. RLS policy yang gate akses (mahasiswa upload ke folder sendiri, dosen MK terkait + admin baca)

## Keputusan Arsitektur (sudah dikonfirmasi user)

| Aspek | Pilihan | Alasan |
|-------|---------|--------|
| Bucket type | **Private + signed URL on-demand** | Surat dokter/KTM = data sensitif, mahasiswa berhak privasi |
| Mobile package | **`image_picker ^1.1.0`** | Standar Flutter, 150KB, cocok untuk image-only |
| Path convention | `<student_id>/<request_id>.<ext>` | Auth boundary jelas via prefix |
| File limit | 5 MB | Cukup untuk foto HD; sama dengan bucket avatars |
| Mime types | `image/jpeg, image/png, image/webp` | Image-only, no PDF (out of scope) |
| Signed URL TTL | 5 menit | Cukup untuk dosen klik dan lihat, expired otomatis |

## Threat Model

### Attack vectors
1. **Anon download**: bucket private + RLS deny SELECT untuk anon → ✓ blocked
2. **Mahasiswa A baca evidence mahasiswa B**: RLS gate via path prefix `auth.uid()::text` → ✓ blocked
3. **Spoofed evidence_url di submit**: server validate URL pattern (must match bucket prefix) atau lebih baik: simpan path saja di DB, server yang generate signed URL on-demand → pakai pendekatan ini
4. **Upload file selain image**: validate mime + magic bytes server-side, plus bucket-level `allowed_mime_types`
5. **Upload massive file (DoS)**: bucket-level `file_size_limit` 5MB + Zod check di endpoint
6. **Race upload tanpa request_id**: upload sebelum submit → orphan file. Strategi: upload dulu dapat path, lalu submit pakai path. Cleanup orphan via cron (out of scope sekarang, accept residue).

### Yang TIDAK akan dilakukan (out of scope)
- Image compression server-side (mobile yang resize sebelum upload via image_picker `imageQuality`)
- Virus scan (cost prohibitif untuk PBL)
- OCR atau auto-extract isi surat dokter
- Edit/replace evidence setelah submit (immutable per request)
- Cron cleanup orphan upload (manual purge cukup untuk demo)

## Requirements

### R1 — DB & Storage Migration
- R1.1. Migration baru `019_leave_evidence_bucket.sql`:
  - Create bucket `leave-evidence` (`public=false`, `file_size_limit=5242880`, `allowed_mime_types=['image/jpeg','image/png','image/webp']`)
  - Storage policies di `storage.objects`:
    - **INSERT**: authenticated mahasiswa, path harus mulai `auth.uid()::text || '/'`
    - **SELECT**: 3 path — (a) owner mahasiswa lihat punya sendiri, (b) dosen MK terkait lihat evidence student di MK-nya, (c) admin lihat semua. Implementasi via JOIN ke `leave_requests` dan `enrollments`.
    - **UPDATE/DELETE**: deny untuk semua kecuali service_role (immutable evidence)
  - Backward compat: kolom `leave_requests.evidence_url` tetap pakai TEXT (path saja, bukan full URL)

### R2 — Endpoint Upload Server (Mobile)
- R2.1. `POST /api/mobile/leave-requests/upload-evidence`:
  - Auth: Bearer JWT, role mahasiswa, is_active
  - Rate limit: 10 upload per 15 menit per (user+device) — sliding window
  - Body: multipart/form-data dengan `file` field (image)
  - Validate: mime type + size (server-side double-check meski bucket limit)
  - Generate path: `<user.id>/<crypto-random-id>.<ext>`
  - Upload via service_role (bypass RLS, sudah aman karena auth check)
  - Return `{ path: string }` — bukan full URL
  - Audit `mobile_leave_evidence_upload` dengan `path`, `size`, `mime`

### R3 — Endpoint Submit (existing, modify)
- R3.1. `POST /api/mobile/leave-requests/submit` saat ini accept `evidence_url` (full URL). **Refactor**: ganti jadi `evidence_path` (string path), validate format `^[0-9a-f-]{36}/[0-9a-f-]+\.(jpe?g|png|webp)$` (matches user's own UUID prefix).
- R3.2. Server validate `evidence_path` mulai dengan `user.id` — defense in depth (selain RLS).
- R3.3. Simpan ke `leave_requests.evidence_url` kolom (nama kolom legacy, isi sekarang path).

### R4 — Endpoint Get Signed URL (Web admin/dosen)
- R4.1. Web Server Action `getLeaveEvidenceSignedUrl(requestId)`:
  - Auth: `requireRole(['admin', 'dosen'])`
  - Cek dosen ownership: kalau role dosen, leave_requests.session.course.dosen_id harus = user.id
  - Generate signed URL via `supabase.storage.from('leave-evidence').createSignedUrl(path, 300)` (5 menit)
  - Return URL atau error
- R4.2. Web `leave-table.tsx` ganti link langsung ke `evidence_url` jadi panggil server action saat klik "Lihat Bukti"

### R5 — UI Mobile
- R5.1. Tambah `image_picker: ^1.1.0` di `pubspec.yaml`
- R5.2. Update `submit_leave_request_screen.dart`:
  - Section baru "Bukti Pendukung (Opsional)" dengan tombol "Pilih Foto"
  - Preview thumbnail kalau sudah pilih
  - Tombol X untuk hapus pilihan
  - Saat submit: kalau ada foto, upload dulu via `uploadEvidence()` → dapat path → masukkan ke submit body
- R5.3. Repository `LeaveRepository.uploadEvidence(File file)` — multipart POST
- R5.4. State management: tambah field `evidencePath` di `SubmitLeaveState`, `uploading`/`uploaded` substatus

### R6 — Verifikasi
- R6.1. Migration apply via MCP, advisor security 0 issue baru
- R6.2. `npm run type-check` (web): exit 0
- R6.3. `flutter analyze` (mobile): No issues
- R6.4. Manual smoke test (user): upload foto JPG → submit → web admin klik "Lihat Bukti" → URL signed valid muncul → expired setelah 5 menit

## Tasks

Status: `[ ]` not started · `[~]` in progress · `[x]` done

### A. Database & Storage
- [x] **A1** Migration 019 — bucket + 3 storage policies
- [x] **A2** Apply via MCP `apply_migration`
- [x] **A3** Verify advisor security: 0 issue baru
- [x] **A4** Sync ke `mypresensi-web/supabase/migrations/019_leave_evidence_bucket.sql`

### B. Server Endpoint
- [x] **B1** Buat helper `_lib/storage-utils.ts` (validate mime + ext, generate path)
- [x] **B2** Buat `POST /api/mobile/leave-requests/upload-evidence` route handler
- [x] **B3** Refactor existing `submit/route.ts`: rename `evidence_url` → `evidence_path` di Zod schema, validate prefix, simpan path
- [x] **B4** Tambah `ApiEndpoints.leaveRequestUpload` di mobile constants
- [x] **B5** `npm run type-check`: 0 errors

### C. Web Admin/Dosen — Signed URL
- [x] **C1** Server action `getLeaveEvidenceSignedUrl()` di `app/lib/actions/leave-requests.ts`
- [x] **C2** Refactor `leave-table.tsx` "Lihat Bukti" jadi async dengan loading state
- [x] **C3** `npm run type-check`: 0 errors

### D. Mobile UI
- [x] **D1** Tambah `image_picker: ^1.1.0` di `pubspec.yaml`
- [x] **D2** Tambah method `uploadEvidence(File)` di `LeaveRepository`
- [x] **D3** Update `SubmitLeaveState` dengan `pickedImage`, `evidencePath`, status `uploading`
- [x] **D4** Update `submit_leave_request_screen.dart`: section bukti + preview + handle pick/upload
- [x] **D5** `flutter analyze`: 0 issues

### E. Dokumentasi
- [x] **E1** Update CHANGELOG `[ADD]` + `[MOD]`
- [x] **E2** Update TODO.md — move P3-#1 ke completed
- [x] **E3** Update rule `00-mypresensi-overview.md` library mobile table (tambah image_picker)

### F. Manual smoke test (user)
- [ ] **F1** Mahasiswa pick foto → submit izin → success
- [ ] **F2** Web admin login → halaman izin → klik "Lihat Bukti" → image muncul di tab baru
- [ ] **F3** Mahasiswa A coba akses path mahasiswa B via direct URL → 403
- [ ] **F4** Upload non-image (TXT) → reject 400

## Out of Scope (defer ke future)
- PDF/document support (image-only sekarang)
- Image compression server-side
- Virus scan
- Cron cleanup orphan upload
- Edit/replace evidence
- Multiple files per request
