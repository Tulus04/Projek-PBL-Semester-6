---
inclusion: manual
description: Bundling pre-commit verification untuk MyPresensi — type-check + lint + flutter analyze + secret leak audit. Pakai sebelum git commit.
---

# /pre-commit-check — Verifikasi Sebelum Commit

Workflow untuk pastikan kode yang akan di-commit clean: type-safe, lint pass, tidak ada secret bocor.

## Kapan pakai?

- **Selalu** sebelum `git commit` untuk perubahan multi-file.
- Untuk single-file commit (mis. fix typo) tetap baik dijalankan, tapi tidak strict wajib.

## Step 1 — Cek Apa yang Stage

```powershell
git status
git diff --cached --stat
```

Pastikan file yang di-stage memang yang dimaksud. Kalau ada file accidental (mis. `.env.local`, `node_modules/...`) → unstage dulu:
```powershell
git reset HEAD <file>
```

## Step 2 — Audit Secret Leak

// turbo
```powershell
git diff --cached | Select-String -Pattern "(SUPABASE_SERVICE_ROLE_KEY|SUPABASE_ANON_KEY|password\s*=|secret\s*=|sk_live|pk_live|Bearer\s+ey)" -CaseSensitive:$false
```

**Kalau muncul match** → STOP. Bisa jadi:
- Hardcode credential di kode → ganti pakai `.env.local` reference.
- File `.env.local` ke-stage → unstage + cek `.gitignore`.
- Token JWT di test fixture → pakai placeholder.

```powershell
# Audit ekstra: file sensitif tipikal
git ls-files --cached | Select-String -Pattern "(\.env(\.[a-z]+)?$|credentials|\.jks$|\.keystore$|key\.properties$|google-services\.json$)"
```

Output harus kosong. Kalau ada → CRITICAL: rotate kredensial setelah commit jika sudah pernah ke-push.

## Step 3 — Verifikasi Web (`mypresensi-web/`)

Hanya jalankan jika ada perubahan di `mypresensi-web/`:

// turbo
```powershell
npm run type-check
```
cwd: `mypresensi-web`. Output harus: `0 errors`.

```powershell
npm run lint
```
cwd: `mypresensi-web`. Output harus: tidak ada error baru. Warning OK kalau memang sudah ada sebelumnya, tapi jangan tambah warning baru.

### (Opsional, untuk pre-merge ke main) Build Penuh
```powershell
npm run build
```
cwd: `mypresensi-web`. Tunggu sampai selesai (~30-60 detik). Pastikan exit code 0 dan tidak ada error/warning baru.

## Step 4 — Verifikasi Mobile (`mypresensi-mobile/`)

Hanya jalankan jika ada perubahan di `mypresensi-mobile/`:

// turbo
```powershell
flutter analyze
```
cwd: `mypresensi-mobile`. Output harus: `No issues found!`.

```powershell
flutter pub get
```
cwd: `mypresensi-mobile`. Hanya jika `pubspec.yaml` ke-edit. Jangan commit `pubspec.lock` yang stale.

### (Opsional, untuk pre-merge) Build Debug
```powershell
flutter build apk --debug
```
cwd: `mypresensi-mobile`. Tunggu ~2 menit. Verify build berhasil.

## Step 5 — Verifikasi Migration (jika ada)

Hanya jika ada file baru di `mypresensi-web/supabase/migrations/`:

```
mcp0_list_migrations({ project_id: '<ref>' })
```

Pastikan migration yang baru ditambahkan SUDAH di-apply ke project (kalau pakai MCP) atau didokumentasikan di CHANGELOG (kalau apply manual).

```
mcp0_get_advisors({ project_id: '<ref>', type: 'security' })
mcp0_get_advisors({ project_id: '<ref>', type: 'performance' })
```

Kalau ada issue baru → fix dulu sebelum commit.

## Step 6 — Cek Komentar Header File

Setiap file baru WAJIB punya komentar header Bahasa Indonesia singkat:

```powershell
# Cek file yang baru ditambah, pastikan ada header komentar
git diff --cached --name-only --diff-filter=A | ForEach-Object {
  if ($_ -match '\.(ts|tsx|dart|sql)$') {
    Write-Host "Cek header: $_"
    Get-Content $_ -Head 3
    Write-Host "---"
  }
}
```

Format yang diharapkan:
```ts
// app/api/mobile/foo/bar/route.ts
// Endpoint <fungsi singkat> — <catatan keamanan jika relevan>
```

## Step 7 — Update CHANGELOG (jika perubahan signifikan)

Untuk fitur baru, bug fix, security fix, perubahan migration — tambah entri di `CHANGELOG.md`:

```markdown
## YYYY-MM-DD
| HH:MM | [TYPE] | <file/path> | <Penjelasan singkat Bahasa Indonesia> |
```

Type: `[ADD]` / `[MOD]` / `[FIX]` / `[SEC]` / `[DOC]` / `[CHORE]` / `[STYLE]`.

Untuk tweak kecil (typo, formatting saja) — tidak perlu update CHANGELOG.

## Step 8 — Format Commit Message

Format yang dipakai (conventional commit-ish, dalam Bahasa Indonesia atau Inggris):

```
[TYPE] Judul singkat <72 char

Deskripsi panjang opsional. Jelaskan WHY, bukan WHAT (yang mana sudah jelas dari diff).

Refs: <BUG-XXX, migration NNN, atau issue ID>
```

Contoh:
```
[SEC] Hardening anon role + audit_logs insert policy

REVOKE SELECT FROM anon di semua tabel public agar mobile/web
yang lupa Bearer token tidak dapat data apapun. Insert audit_logs
hanya via service_role agar pemalsuan log tidak bisa.

Refs: migration 006_security_hardening
```

## Step 9 — Final Confirm

```powershell
git status
```

- File yang di-stage = file yang dimaksud
- Tidak ada file accidental
- Branch sesuai (`feature/...` atau `fix/...` atau `main` kalau memang langsung commit)

```powershell
git commit -m "[TYPE] <judul>"
```

Atau pakai editor (`git commit`) untuk multi-line message.

## Anti-Pattern (JANGAN dilakukan)

- ❌ Skip type-check karena "cepetan dulu" — bug TS akan muncul nanti di runtime, lebih lama debug.
- ❌ `git commit -a -m "fix"` tanpa lihat diff dulu — bisa commit file accidental.
- ❌ Commit sambil ada `console.log()` debug yang lupa dihapus.
- ❌ Commit dengan TODO baru tanpa issue tracker / catatan.
- ❌ Commit migration yang BELUM di-apply ke Supabase — orang lain pull, type-check error.

## Quick One-Liner (untuk daily dev)

Kalau yakin scope kecil dan rapi:

```powershell
# Web
cd mypresensi-web
npm run type-check && npm run lint
cd ..

# Mobile
cd mypresensi-mobile
flutter analyze
cd ..

# Stage + commit
git status
git add <file-yang-relevan>
git commit -m "[TYPE] <judul>"
```

## Output

Kalau semua step pass → siap `git push`. Kalau ada yang gagal → fix dulu, jangan commit yang setengah.
