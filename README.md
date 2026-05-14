# MyPresensi — Sistem Absensi Mahasiswa 3-Layer Verifikasi

Sistem absensi digital untuk **Prodi TRPL, Politeknik Pertanian Negeri Samarinda**. Proyek PBL Semester 6.

3 layer verifikasi presensi:
1. **OTP/QR** (sesi dosen → kode 6 digit, expired 3 menit)
2. **GPS** (radius dari koordinat kelas, anti-mock GPS via `Position.isMocked`)
3. **Face Recognition** (MobileFaceNet 192-d embedding, cosine similarity threshold 0.65)

---

## Struktur Repository

```
Projek-PBL-Semester-6/
├── mypresensi-web/          ← Next.js 14 — Admin & Dosen dashboard + API mobile
├── mypresensi-mobile/       ← Flutter 3.11 — App mahasiswa
├── docs/plans/              ← Plan teknis & threat analysis
├── .windsurf/               ← Workflow & rules Cascade AI
├── workflow_mypresensi.md   ← Diagram alur Mermaid
├── dev-log.md               ← Log teknis tiap sesi
├── CHANGELOG.md             ← Riwayat perubahan
└── credentials-MUSTREAD.txt ← Akun admin (TIDAK di-commit)
```

---

## Tech Stack Singkat

| Layer | Tech |
|-------|------|
| **Web** | Next.js 14.2 · React 18.3 · TypeScript · Tailwind CSS 3.4 · Supabase SSR |
| **Mobile** | Flutter 3.11 · Riverpod 3 · GoRouter · Dio · TFLite (MobileFaceNet) |
| **Backend** | Supabase (Postgres + Auth + Storage) · Row-Level Security · Edge cases via Next.js Route Handler |
| **Tools** | Supabase MCP · Android Emulator (Pixel_9a) · Windsurf AI workflows |

Detail lengkap di `.windsurf/rules/00-mypresensi-overview.md`.

---

## Prerequisites

| Tool | Versi Minimal | Catatan |
|------|---------------|---------|
| **Node.js** | 18.x | LTS recommended (20.x) |
| **npm** | 9+ | Bundled dengan Node |
| **Flutter SDK** | 3.11.4 | `flutter doctor` harus pass semua |
| **Android Studio** | Hedgehog+ | Untuk emulator + SDK |
| **PostgreSQL client** | Optional | Untuk akses Supabase manual (psql) |
| **Git** | 2.30+ | |

Supabase project sudah di-provision di organisasi maintainer. Project ref tersimpan di `mypresensi-web/.env.local` (gitignored). Token Personal Access untuk MCP di-set di `~/.codeium/windsurf/mcp_config.json` lokal masing-masing dev.

---

## Setup dari Nol (Developer Baru)

### 1. Clone Repository

```powershell
git clone <repo-url> Projek-PBL-Semester-6
cd Projek-PBL-Semester-6
```

### 2. Setup Web App (`mypresensi-web/`)

```powershell
cd mypresensi-web
npm install
```

**Buat `.env.local`** dari template:
```powershell
Copy-Item .env.local.example .env.local
```

Isi dengan kredensial Supabase (minta ke maintainer atau ambil dari Supabase Dashboard → Settings → API):
```env
NEXT_PUBLIC_SUPABASE_URL=https://<your-project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<ambil dari dashboard>
SUPABASE_SERVICE_ROLE_KEY=<ambil dari dashboard — RAHASIA>
```

> ⚠️ **`SUPABASE_SERVICE_ROLE_KEY` TIDAK PERNAH commit ke git** — sudah ada di `.gitignore`.

**Verify**:
```powershell
npm run type-check    # Harus exit 0
npm run lint          # Harus "No ESLint warnings or errors"
```

**Jalankan dev server**:
```powershell
npm run dev           # http://localhost:3000
```

### 3. Setup Mobile App (`mypresensi-mobile/`)

```powershell
cd ../mypresensi-mobile
flutter pub get
```

**Download model MobileFaceNet** (5 MB, gitignored):
- Lihat instruksi di `assets/models/README.md`
- Letakkan file `mobilefacenet.tflite` di `assets/models/`

**Verify**:
```powershell
flutter analyze       # Harus "No issues found"
```

**Jalankan**:

Pakai workflow shortcut `/run-emulator` (atau manual):
```powershell
# Cek perangkat tersedia
flutter devices

# Run di emulator (auto-detect baseUrl http://10.0.2.2:3000 untuk web local)
flutter run -d emulator-5554
```

### 4. Setup Database (Supabase Migrations)

⚠️ **PENTING**: Migration history di Supabase MCP terpisah jadi 2 fase:

#### Fase A — Manual (pre-MCP, untuk fresh project)

Migration 001-005 di-apply manual sebelum MCP token tersedia. Untuk **fresh setup** dari nol:

1. Buka Supabase Dashboard → SQL Editor
2. Jalankan secara berurutan file SQL di `mypresensi-web/supabase/migrations/`:
   - `001_initial_schema.sql` — tabel inti + RLS
   - `002_notifications.sql` — notifikasi in-app
   - `003_face_verification_mode.sql` — setting optional/required
   - `004_campus_locations.sql` — preset GPS Politani
   - `005_mobilefacenet_threshold.sql` — threshold 0.65

Atau pakai script helper:
```powershell
cd mypresensi-web
node scripts/apply-migration-005.mjs    # contoh, untuk 005 saja
```

#### Fase B — Via MCP (006+)

Migration 006 ke atas sudah ter-track di Supabase MCP history. Untuk apply manual via dashboard SQL Editor, atau via Cascade AI dengan workflow `/add-supabase-migration`.

Migration yang sudah applied via MCP (tertrack di `supabase_migrations.schema_migrations`):

| Version | Nama | Tujuan |
|---------|------|--------|
| `20260407103749` | create_avatars_bucket | Storage bucket untuk avatar |
| `20260411041042` | campus_locations | Preset GPS Politani |
| `20260514050201` | security_hardening | Function search_path + drop permissive RLS |
| `20260514055243` | 007_disable_graphql | Drop pg_graphql extension |
| `20260514055416` | 008_avatar_listing_hardening | Drop broad SELECT policy avatar |
| `20260514055450` | 009_rate_limit_log_explicit_policy | Explicit deny untuk rate_limit_log |
| `20260514...` | 010_fk_indexes | 6 FK index untuk perf |
| `20260514...` | 011_rls_auth_initplan | RLS auth.uid() → (SELECT auth.uid()) |
| `20260514...` | 012_consolidate_permissive_policies | Konsolidasi 2+ policy per role/cmd |

---

## Common Commands

### Web
```powershell
cd mypresensi-web
npm run dev          # Dev server (port 3000)
npm run build        # Production build
npm run type-check   # TypeScript strict check
npm run lint         # ESLint
```

### Mobile
```powershell
cd mypresensi-mobile
flutter pub get                                         # Install deps
flutter analyze                                         # Static analysis
flutter run -d emulator-5554                            # Run di emulator
flutter build apk --release --obfuscate `
  --split-debug-info=build/symbols                      # Build APK release (workflow /release-build)
```

### Database (via Supabase MCP — Cascade AI)
```
mcp0_list_migrations        # List migration history
mcp0_get_advisors            # Cek security/performance advisor
mcp0_apply_migration         # Apply DDL baru
```

---

## Troubleshooting

### Web: "Module not found: @/lib/..."
Pastikan menggunakan path alias `@/` dari `tsconfig.json` (root: `app/`). Bukan `@/src/`.

### Mobile: Build gagal "tflite_flutter not found"
```powershell
flutter clean
flutter pub get
```
Pastikan model `assets/models/mobilefacenet.tflite` ada (5 MB).

### Mobile: GPS "Mock location detected"
Di debug build, mock location otomatis di-bypass (lihat `location_service.dart`). Di **release build**, mock location akan reject submit presensi. Untuk test rejection, butuh HP fisik + aplikasi Fake GPS.

### Emulator tidak detect web dev server
Web dev server di `localhost:3000` di host laptop. Dari emulator Android, akses pakai `http://10.0.2.2:3000` (sudah auto-detect di mobile config).

### Type-check error "Cannot find module '@supabase/ssr'"
Pastikan `npm install` sudah jalan setelah pull. Lock file ada di `package-lock.json`.

---

## File Sensitif (TIDAK Pernah Commit)

Sudah di-cover oleh `.gitignore` di 3 level (root + web + mobile), tapi double-check sebelum push:

| File | Lokasi | Isi |
|------|--------|-----|
| `.env.local` | `mypresensi-web/` | Supabase URL + anon + service_role key |
| `.dev-accounts.md` | `mypresensi-web/` | Credential dev test |
| `credentials-MUSTREAD.txt` | root | Akun admin |
| `update-mcp-token.ps1` | root | Script update token MCP |
| `key.properties` | `mypresensi-mobile/android/` | Keystore password |
| `*.jks`, `*.keystore` | `mypresensi-mobile/android/app/` | Upload/release keystore |
| `assets/models/*.tflite` | `mypresensi-mobile/` | Model 5MB, download manual |
| `google-services.json` | `mypresensi-mobile/android/app/` | Firebase config (jika ada) |

**Audit cepat sebelum commit**:
```powershell
git diff --cached | Select-String -Pattern "(SUPABASE_SERVICE_ROLE_KEY|sbp_|sk_|secret_key)" -CaseSensitive:$false
```
Output harus kosong.

---

## Dokumentasi Lain

| File | Fungsi |
|------|--------|
| `dev-log.md` | Log teknis tiap sesi developer (rekap kronologis) |
| `CHANGELOG.md` | Riwayat perubahan per tanggal & file |
| `workflow_mypresensi.md` | Diagram Mermaid alur sistem |
| `docs/plans/implementation_plan.md` | Plan teknis lengkap + threat analysis |
| `.windsurf/rules/00-mypresensi-overview.md` | Overview untuk Cascade AI |
| `.windsurf/workflows/*.md` | Slash commands (`/start-dev`, `/run-emulator`, dll) |

---

## Lisensi & Credits

Proyek PBL Semester 6 — **Prodi TRPL, Politeknik Pertanian Negeri Samarinda**.

Tidak untuk distribusi komersial. Data biometrik (face embeddings) & GPS dianggap **data spesifik** menurut UU PDP Indonesia (UU 27/2022) — treat dengan proteksi ekstra. Lihat `.windsurf/rules/04-security-and-privacy.md` untuk panduan lengkap.
