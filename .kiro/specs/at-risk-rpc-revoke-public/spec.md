# Spec: Revoke `get_at_risk_students` Exposure to anon + authenticated

> **Status**: In Progress
> **Created**: 2026-05-16
> **Priority**: T0 (Security — flagged by Supabase advisors `auth_security_definer_function_executable`)
> **Estimated effort**: 30 menit

## Konteks

Function `public.get_at_risk_students` saat ini SECURITY DEFINER dengan grants:
- `anon=EXECUTE` ❌ harus dicabut
- `authenticated=EXECUTE` ❌ harus dicabut
- `service_role=EXECUTE` ✅ keep
- `postgres=EXECUTE` ✅ default owner, keep

Advisor Supabase flag 2 issue:
1. `anon_security_definer_function_executable` (WARN) — anon role bisa eksekusi → list mahasiswa at-risk bocor publik via `/rest/v1/rpc/get_at_risk_students`
2. `authenticated_security_definer_function_executable` (WARN) — authenticated role bisa eksekusi → mahasiswa biasa bisa dapat data mahasiswa lain

Migration 015 sudah ada `REVOKE ALL FROM PUBLIC` + `GRANT TO authenticated, service_role`, tapi **grant `authenticated` itu sendiri yang jadi masalah**, plus `anon` masih dapat akses (kemungkinan ada migration lain atau Supabase default behavior yang re-grant).

## Konflik dengan Rules MyPresensi

- **`04-security-and-privacy.md` Section A**: full_name, NIM = Tier 2 PII, "RLS strict per-row, audit log saat akses massal"
- **`14-web-supabase-patterns.md` Section B**: "RLS policy WAJIB pakai `auth.uid()` — JANGAN parameter dari client"
  - Function ini terima `p_dosen_id` dari client → trust client-supplied parameter, melanggar pola
- **Rule defense-in-depth**: function bypass RLS (SECURITY DEFINER) harus di-gate ketat di layer akses

## Verifikasi Caller di Kode

Semua caller pakai `createAdminClient()` (service_role) setelah `requireRole`:

| File | Line | Caller | Auth check |
|------|------|--------|------------|
| `app/lib/actions/at-risk.ts` | 118 | `getAtRiskSummary` | `requireRole(['admin'])` ✓ |
| `app/lib/actions/at-risk.ts` | 155 | `getAtRiskStudents` | `requireRole(['admin'])` ✓ |
| `app/lib/ai/tools.ts` | 84 | `listAtRiskStudents` (web AI) | parent route handler `requireRole` ✓ |
| `app/lib/ai/tools.ts` | 284 | `checkMyAtRiskStatus` (mobile AI) | parent route handler authenticate ✓ |

**Semua via `service_role` → revoke `authenticated` + `anon` TIDAK akan break apapun.** Aman dilakukan.

## Requirements

### R1 — Migration baru `016_revoke_at_risk_function_public.sql`
1.1. `REVOKE ALL ON FUNCTION public.get_at_risk_students(numeric, int, int, uuid) FROM PUBLIC, anon, authenticated;`
1.2. `GRANT EXECUTE ON FUNCTION ... TO service_role;` (re-affirm, idempotent)
1.3. Apply via MCP `apply_migration` agar ke-track di Supabase migration history.

### R2 — Verifikasi via MCP
2.1. Re-query `pg_proc` untuk confirm grants akhirnya hanya `service_role` + `postgres`.
2.2. Run `get_advisors({ type: 'security' })` lagi — 2 advisor `*_security_definer_function_executable` untuk function ini harus hilang.

### R3 — Verifikasi caller masih jalan
3.1. Type-check `npm run type-check` — pastikan tidak ada regresi.
3.2. (Manual user) Smoke test: buka `/dashboard/at-risk` sebagai admin → list muncul. Buka homepage dashboard → widget at-risk muncul.

### R4 — Audit dokumentasi
4.1. Update header migration 015 dengan komentar pointer ke 016.
4.2. CHANGELOG `[SEC]` entry.
4.3. TODO update.

## Out of Scope
- Tidak refactor function jadi `SECURITY INVOKER` — ada alasan SECURITY DEFINER dipertahankan: butuh akses lintas tabel (`profiles`, `enrollments`, `sessions`, `attendances`, `courses`) dengan RLS policy yang granular per role. Refactor ke INVOKER butuh redesign RLS policies lebih luas.
- Tidak hapus parameter `p_dosen_id` — masih dipakai di AI tool dosen (filter MK miliknya). Trust boundary ditegakkan oleh `service_role` only access (bukan client trust).

## Tasks

- [x] **T1** Apply migration via `apply_migration` MCP
- [x] **T2** Verify pg_proc grants → hanya service_role + postgres
- [x] **T3** Re-run get_advisors security → 2 issue terkait gone
- [x] **T4** Sync ke local `supabase/migrations/016_revoke_at_risk_function_public.sql` (manual write file)
- [x] **T5** `npm run type-check` di mypresensi-web
- [x] **T6** Update CHANGELOG.md `[SEC]` entry
- [x] **T7** Update docs/TODO.md
- [ ] **T8** (User) Smoke test halaman /dashboard/at-risk + widget dashboard
