---
inclusion: manual
description: Index folder steering MyPresensi — pemetaan rules + workflows hasil migrasi dari .windsurf.
---

# `.kiro/steering/` — Index

Folder ini berisi rules + workflows MyPresensi hasil migrasi dari `.windsurf/` (Windsurf IDE) ke format Kiro. Konten identik dengan sumber aslinya, hanya frontmatter yang disesuaikan ke konvensi Kiro.

## Cara Kerja Steering di Kiro

Setiap file `.md` di folder ini diatur via frontmatter:

| Mode | Frontmatter | Kapan aktif |
|------|-------------|-------------|
| **Always** | `inclusion: always` | Otomatis ikut di setiap percakapan |
| **File match** | `inclusion: fileMatch` + `fileMatchPattern: 'glob/**'` | Otomatis aktif saat file yang cocok di-baca/edit |
| **Manual** | `inclusion: manual` | Hanya aktif kalau user panggil pakai `#nama-file` di chat |

## Rules (workspace `.kiro/steering/`)

### Always-on (selalu di konteks)

| File | Tujuan |
|------|--------|
| `00-mypresensi-overview.md` | Overview proyek, tech stack, struktur monorepo, role, alur presensi, daftar migration |
| `01-agent-persona.md` | Persona Kiro: Senior Architect + Security Expert + Mobile Dev — anti-yes-man, security-first, UX-advocate |
| `02-quality-debugging-verification.md` | Standar kualitas kode, debugging 4-fase, gate verifikasi sebelum klaim selesai |
| `03-design-and-libraries.md` | Prinsip desain UI (3-state wajib, Bahasa Indonesia, design token) + library lock |
| `04-security-and-privacy.md` | Data classification, biometric handling, threat model checklist, anti-pattern |
| `05-testing-and-release.md` | Strategi testing, manual QA checklist, commit convention, branch workflow |

### Web-scoped (`mypresensi-web/**`)

| File | Tujuan |
|------|--------|
| `10-web-conventions.md` | Struktur App Router, dua Supabase client, server action template, sidebar grouping, React 18 |
| `13-web-nextjs-patterns.md` | Server vs Client Component, data fetching, route handler, error boundary, performance |
| `14-web-supabase-patterns.md` | RLS security, query performance + index, schema design, monitoring |

### Mobile-scoped (`mypresensi-mobile/**`)

| File | Tujuan |
|------|--------|
| `20-mobile-conventions.md` | Struktur `lib/`, Riverpod 3, GoRouter, AppShell, Dio singleton, face recognition pipeline |
| `21-mobile-android-platform.md` | minSdk 26, permissions, ProGuard, signing, cleartext traffic |
| `22-mobile-design-system.md` | Color tokens, layered shadows, Iconsax Bulk + Semantic System, component patterns |

## Workflows (`.kiro/steering/workflows/`) — Manual Inclusion

Workflow di-trigger dengan konteks `#nama-file` di chat. Misal: ketik `#add-server-action` saat ingin Kiro mengikuti template Server Action.

| File | Untuk apa |
|------|-----------|
| `start-dev.md` | Nyalain stack web + mobile + verifikasi koneksi LAN |
| `add-server-action.md` | Template tambah Server Action baru di `mypresensi-web` |
| `add-mobile-api-endpoint.md` | Template tambah endpoint `/api/mobile/*` + Flutter repository |
| `add-supabase-migration.md` | Template migration baru: SQL + RLS + index + types |
| `debug-rca.md` | Root Cause Analysis sistematis 4 fase |
| `pre-commit-check.md` | Verifikasi pra-commit: type-check + lint + flutter analyze + secret audit |
| `security-review.md` | Pre-merge checklist 10 checkpoint untuk fitur sensitif |
| `release-build.md` | Build APK release: keystore, ProGuard, obfuscate, smoke test |
| `run-emulator.md` | Boot Pixel_9a + webcam + GPS Politani + run Flutter |

## Catatan Migrasi

- Sumber asli: `.windsurf/rules/` dan `.windsurf/workflows/`. Kedua folder lama masih dipertahankan agar Windsurf tetap bisa dipakai paralel kalau perlu.
- Format frontmatter Windsurf (`trigger: always_on` / `trigger: glob`) sudah dikonversi ke Kiro (`inclusion: always` / `inclusion: fileMatch`).
- Konten body tidak diubah — semua referensi `Cascade` sudah disesuaikan ke `Kiro` di file `01-agent-persona.md`.
- Tanggal migrasi: 2026-05-16.
