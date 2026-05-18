---
inclusion: always
description: Strategi testing, commit hygiene, dan disiplin release untuk MyPresensi. Pre-commit checklist, manual QA, branch & commit convention.
---

# Testing, Commit, & Release Discipline — MyPresensi

Proyek ini punya 2 surface (web + mobile) + DB Supabase. Tanpa disiplin testing & release, regresi gampang lolos.

## A. Strategi Testing

### Prinsip
1. **Tidak setiap kode butuh unit test** — fokus testing ke logika non-trivial yang sulit di-verify manual.
2. **Manual QA dulu, automation kemudian** — proyek PBL waktunya terbatas. Tulis automated test untuk *high-value path*, manual checklist untuk yang lain.
3. **Test desain mendukung hak hapus / rollback** — jangan tulis test yang ngotot ada data tertentu di DB tanpa setup teardown.

### Tier Testing per Tipe Kode

| Tipe Kode | Wajib Test? | Cara |
|-----------|-------------|------|
| Server Action mutasi (CRUD) | **Manual** + lihat `audit_logs` setelah trigger | Login → trigger form → cek DB + audit |
| Endpoint mobile (`/api/mobile/*`) | **Manual via Postman/Thunder Client** atau dari UI mobile | Header `Authorization: Bearer <jwt>` + body Zod-valid + body invalid |
| Logic murni (utility function, formatter, validator) | **Boleh** unit test pakai Jest/Vitest (web) atau `flutter_test` (mobile) | High-value: GPS Haversine, cosine similarity, OTP generator, format date Indonesia |
| Pure UI component | **Visual** — buka di browser/emulator, cek 3-state (loading/empty/error) | Skeleton muncul? Empty pesan jelas? Error retry jalan? |
| Migration SQL | **Apply ke dev project** + cek tabel ada | `mcp0_apply_migration` lalu `mcp0_list_tables` |
| RLS policy | **Test sebagai 3 role** (anon, authenticated user A, authenticated user B) | Cek "user A bisa baca data user B?" → harus tidak |
| Face recognition pipeline | **Field test** dengan kondisi cahaya berbeda | Indoor terang, indoor remang, outdoor siang, outdoor malam |
| Mock GPS rejection | **Release build** + Fake GPS app di HP fisik | Submit harus ditolak 403 + audit `mock_location_detected` |

### Manual QA Checklist (sebelum merge fitur baru)

#### Web
- [ ] Login admin / dosen / mahasiswa → role-based redirect benar
- [ ] Halaman baru: 3-state (loading skeleton, empty Indonesia, error retry) muncul semua?
- [ ] Form: validasi Zod menampilkan error di bawah field, tidak crash
- [ ] CRUD: setelah submit → `revalidatePath` jalan, UI refresh tanpa F5
- [ ] Audit log: `audit_logs` row baru muncul dengan `action` & `details` yang benar
- [ ] Browser console: 0 error, 0 warning baru
- [ ] Network: tidak ada request `service_role` key bocor

#### Mobile
- [ ] Login → home page muncul, identitas user benar
- [ ] Hot restart (bukan hot reload) → state direstore via SecureStorage
- [ ] Logout → clear storage + reset Dio + kembali ke /login
- [ ] Submit presensi: GPS in-radius → success; GPS jauh → tolak; mock GPS → tolak
- [ ] Face register: 7 frame averaging jalan? embedding tersimpan? UI feedback jelas?
- [ ] Face verify: similarity di-compute server-side? tampil hasil + threshold?
- [ ] Permission denied (camera/location) → dialog Indonesia + tombol "Buka Pengaturan"
- [ ] Tidak ada koneksi → error message ramah, tombol retry

#### Database
- [ ] Migration baru → `mcp0_get_advisors({ type: 'security' })` 0 issue baru
- [ ] RLS aktif di semua tabel: `SELECT tablename FROM pg_tables WHERE schemaname='public' AND rowsecurity=false` → 0 rows
- [ ] FK punya index: cek via `mcp0_get_advisors({ type: 'performance' })`

## B. Pre-Commit Verification

WAJIB sebelum `git commit`:

### Web (`mypresensi-web/`)
```powershell
# 1. TypeScript strict
npm run type-check

# 2. ESLint
npm run lint

# 3. (opsional, untuk pre-merge ke main) Build penuh
npm run build
```

### Mobile (`mypresensi-mobile/`)
```powershell
# 1. Static analysis
flutter analyze

# 2. (kalau ubah pubspec.yaml)
flutter pub get

# 3. (untuk pre-release) Build APK debug
flutter build apk --debug
```

### Universal
```powershell
# Pastikan tidak ada secret yang ke-stage
git diff --cached | Select-String -Pattern "(SUPABASE_SERVICE_ROLE_KEY|password|secret|sk_|pk_)" -CaseSensitive:$false
```

Kalau muncul match → STOP, buang dari staging dengan `git reset HEAD <file>`.

## C. Commit Message Convention

Format yang dipakai di `CHANGELOG.md`:

```
| HH:MM | [TYPE] | <file/path> | <Penjelasan singkat Bahasa Indonesia> |
```

| Type | Untuk |
|------|-------|
| `[ADD]` | Tambah file/fitur baru |
| `[MOD]` | Modifikasi kode existing (refactor, tweak, perbaikan minor) |
| `[FIX]` | Bug fix dengan referensi gejala |
| `[DOC]` | Update dokumentasi/comment saja |
| `[STYLE]` | Formatting, indent, naming (no logic change) |
| `[CHORE]` | Build, deps, config |
| `[SEC]` | Security fix / hardening |

Contoh entri di `CHANGELOG.md`:
```markdown
## 2026-05-14
| 14:30 | [ADD] | `app/api/mobile/face/verify/route.ts` | Endpoint face verify cosine similarity server-side |
| 14:45 | [SEC] | `supabase/migrations/006_security_hardening.sql` | REVOKE SELECT dari anon, audit_logs admin-only insert |
| 15:10 | [FIX] | `mypresensi-mobile/lib/features/face/.../face_registration_notifier.dart` | Capture embedding di pose lookStraight (BUG-010 root cause) |
```

Untuk Git commit message: pakai conventional commit-ish style:
```
[SEC] Hardening anon role + audit_logs insert policy

- REVOKE SELECT FROM anon di semua tabel public
- Insert audit_logs hanya via service_role
- SET search_path eksplisit di SECURITY DEFINER functions

Refs: migration 006_security_hardening
```

## D. Branch & Workflow

Untuk PBL solo dev, rekomendasi minimal:

| Branch | Tujuan |
|--------|--------|
| `main` | Stable, sudah-tested-manual. Deploy-ready. |
| `dev` (opsional) | Integrasi fitur sebelum merge ke main |
| `feature/<nama>` | Per fitur besar (mis. `feature/face-recognition-mobilefacenet`) |
| `fix/<bug-id>` | Bug fix (mis. `fix/bug-010-face-pose`) |

**Aturan**:
- Commit ke `main` HARUS pass type-check + flutter analyze.
- Tidak ada `--force push` ke `main` kecuali emergency.
- Tag versi rilis: `v1.0.0`, `v1.1.0`, dll. Match dengan `pubspec.yaml` version dan `package.json` version.

## E. Files yang Wajib `.gitignore`

Periksa berkala — kalau bocor, rotate kredensial:

| File | Folder | Alasan |
|------|--------|--------|
| `.env.local` | `mypresensi-web/` | Supabase URL + anon + service_role key |
| `.env*.local` | semua | Override lokal |
| `.dev-accounts.md` | `mypresensi-web/` | Credential test |
| `credentials-MUSTREAD.txt` | root | Akun admin |
| `key.properties` | `mypresensi-mobile/android/` | Keystore password |
| `*.jks`, `*.keystore` | semua | Upload/release keystore |
| `assets/models/*.tflite` | `mypresensi-mobile/` | Model 5MB, di-download manual |
| `build/`, `.dart_tool/`, `node_modules/` | semua | Generated |
| `google-services.json` | `mypresensi-mobile/android/app/` | Firebase config (jika ada) |
| `GoogleService-Info.plist` | `mypresensi-mobile/ios/` | Firebase iOS (jika ada) |

Cek isinya `.gitignore` masing-masing repo. Kalau ragu, audit:
```powershell
git ls-files | Select-String -Pattern "(\.env|credentials|\.jks|key\.properties|google-services)"
```
Output harus kosong. Kalau ada → STOP, hapus dari Git history (pakai `git filter-repo` atau BFG).

## F. Release Build (Mobile)

Lihat workflow `/release-build` (akan dibuat) untuk langkah lengkap. Ringkasan:

```powershell
# 1. Test analyze pass dulu
flutter analyze

# 2. Build APK release dengan obfuscate
flutter build apk --release --obfuscate --split-debug-info=build/symbols

# 3. Cek size APK
Get-ChildItem build/app/outputs/flutter-apk/app-release.apk | Select-Object Length

# 4. Install ke HP fisik untuk smoke test
adb install -r build/app/outputs/flutter-apk/app-release.apk

# 5. Smoke test:
#    - Login → home muncul
#    - Submit presensi (GPS valid) → berhasil
#    - Submit dengan Fake GPS → tolak 403
#    - Face register + verify → berhasil
```

**Sebelum** kirim APK ke dosen pembimbing / production:
- [ ] `usesCleartextTraffic` di `AndroidManifest.xml` sudah `false` atau di-restrict via `network_security_config.xml`
- [ ] Backend production sudah HTTPS
- [ ] `applicationId` final (jangan ganti setelah ada user terinstall)
- [ ] Signing dengan **upload keystore** (bukan debug key)
- [ ] ProGuard/R8 enabled (`isMinifyEnabled = true`, `isShrinkResources = true`)
- [ ] Smoke test full flow di HP fisik (bukan emulator)
- [ ] Symbol file `build/symbols/` di-backup untuk decode crash report

## G. Common Mistakes saat Release

1. **APK debug dipakai sebagai release** — file size besar (~50MB+), tidak obfuscated, debug log aktif.
2. **Mock GPS lolos di test** karena pakai debug build (otomatis bypass `isMocked`). Test rejection wajib release build.
3. **Lupa update `versionCode`** di `pubspec.yaml` `version: 1.0.0+1` — Play Store reject upload dengan versionCode duplicate.
4. **Backend masih `localhost:3000`** di config production — mobile gagal connect.
5. **Database migration belum di-apply ke production** — fitur baru error di runtime karena tabel/kolom belum ada.
6. **Service role key bocor** karena di-include di repo public — segera rotate via Supabase Dashboard.
