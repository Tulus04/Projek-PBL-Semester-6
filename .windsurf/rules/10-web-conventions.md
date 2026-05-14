---
trigger: glob
globs: mypresensi-web/**
description: Konvensi koding mypresensi-web (Next.js 14 App Router + Supabase). Wajib diikuti untuk semua perubahan di folder ini.
---

# Konvensi `mypresensi-web/`

## Struktur App Router

```
app/
├── (auth)/login/                   ← Route group (tidak muncul di URL)
├── (dashboard)/                    ← Wajib login + bukan must_change_password
│   ├── layout.tsx                  ← Auth guard di sini
│   ├── dashboard/  dosen/  mahasiswa/  matakuliah/
│   ├── sesi/  rekap/  izin/  export/  audit/  settings/  profil/
├── api/mobile/                     ← Endpoint mobile (Bearer JWT, role mahasiswa)
│   ├── _lib/auth.ts                ← `authenticateRequest()` — pakai ini selalu
│   ├── auth/  attendance/  sessions/  face/  courses/  notifications/  profile/
├── components/{layout,ui,dashboard}/
├── lib/
│   ├── supabase/{client,server}.ts ← createClient() & createAdminClient()
│   ├── auth-guard.ts               ← getCurrentUserProfile, requireRole, canAccessCourse
│   ├── audit-logger.ts             ← logAudit({ action, details })
│   ├── actions/                    ← Server Actions per domain
│   ├── utils/                      ← cn, formatDateId, getStatusColor, dll
│   └── swal.ts                     ← SweetAlert2 styled
├── types/database.ts               ← Profile, Course, Session, Attendance, dll
└── globals.css                     ← Design tokens TRPL
```

## Path Alias — KRITIS

```jsonc
// tsconfig.json
"paths": { "@/*": ["./app/*"] }
```

- ✅ `import { createClient } from '@/lib/supabase/server'`
- ❌ `import ... from '@/src/lib/...'` — folder `src/` LAMA, jangan dipakai (BUG-002 dulu).

Folder `mypresensi-web/src/` adalah peninggalan scaffold Next.js — **abaikan, jangan import dari sana**.

## Dua Supabase Clients — Wajib Dibedakan

```ts
// app/lib/supabase/server.ts

createClient()        // anon key + cookies SSR. Pakai untuk auth.getUser() & query SSR yg patuh RLS user (role: authenticated).
createAdminClient()   // service_role key. BYPASS RLS. HANYA di Server Action / Route Handler setelah auth check.
```

**Aturan emas**: Sebelum panggil `createAdminClient()` untuk operasi sensitif, **selalu** validasi user dulu dengan `createClient().auth.getUser()` atau lewat `getCurrentUserProfile()` / `requireRole()`.

### Akses Role (sejak migration 006_security_hardening)

| Role | SELECT publik | Pakai dari mana | Catatan |
|------|---------------|-----------------|---------|
| `anon` | ❌ TIDAK ADA | (hampir tidak terpakai) | Sebelum login, hanya `auth.signIn()` yg jalan |
| `authenticated` | ✅ ADA, gating via RLS per-row | Web SSR (`createClient()` + cookies) | Default mode untuk dosen/admin yang sudah login |
| `service_role` | ✅ SEMUA, bypass RLS | Server Action / Route Handler (`createAdminClient()`) | **WAJIB** auth check sebelum dipakai |

**JANGAN** tambah `GRANT SELECT ... TO anon` di migration baru kecuali ada alasan public read sangat eksplisit (mis. landing page anonim). Diskusikan dulu.

### Insert ke `audit_logs` & `notifications` — WAJIB Pakai Admin Client

Sejak migration 006, kedua tabel ini **tidak punya insert policy permissive**. Berarti:
- `createClient()` (anon/authenticated) **tidak bisa insert** → RLS reject.
- `createAdminClient()` (service_role) **bypass RLS** → insert berhasil.

Server action / route handler yang panggil `logAudit()` atau kirim notifikasi WAJIB pakai `createAdminClient()`. Lihat `app/lib/audit-logger.ts` — sudah implementasi pola ini, jangan ditiru dengan `createServerClient()` di tempat lain.

## Server Actions

Setiap file di `app/lib/actions/*.ts` diawali `'use server'`. Pola wajib:

```ts
'use server'
import { revalidatePath } from 'next/cache'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/server'
import { requireRole, canAccessCourse } from '@/lib/auth-guard'
import { logAudit } from '@/lib/audit-logger'

const schema = z.object({ /* ... */ })

export async function fooAction(_prevState: State, formData: FormData): Promise<State> {
  // 1. Auth + role check
  const user = await requireRole(['admin', 'dosen']) // throws jika tidak authorized

  // 2. (jika perlu) ownership check
  // const ok = await canAccessCourse(user.id, user.role, courseId)

  // 3. Validasi Zod
  const parsed = schema.safeParse({ /* dari formData */ })
  if (!parsed.success) return { error: 'Data tidak valid', success: false, fieldErrors: parsed.error.flatten().fieldErrors }

  // 4. Mutasi DB pakai adminClient (bypass RLS, sudah aman karena step 1-2)
  const supabase = createAdminClient()
  const { error } = await supabase.from('...').insert({ /* ... */ })
  if (error) return { error: 'Gagal: ' + error.message, success: false }

  // 5. Audit + revalidate
  await logAudit({ action: 'create_foo', details: { /* ... */ } })
  revalidatePath('/halaman-terkait')
  return { error: null, success: true }
}
```

**Yang TIDAK boleh**:
- Memanggil `createAdminClient()` tanpa role/auth check sebelumnya.
- Lupa `revalidatePath()` setelah mutasi (UI tidak refresh).
- Mengembalikan pesan error mentah dari Supabase ke user (sanitasi seperti `loginAction`).

## Endpoint Mobile (`app/api/mobile/*`)

Setiap `route.ts` wajib pakai helper di `_lib/auth.ts`:

```ts
import { authenticateRequest, errorResponse, successResponse } from '../_lib/auth'

export async function POST(req: NextRequest) {
  const auth = await authenticateRequest(req) // Bearer + role mahasiswa + is_active
  if (auth.error) return errorResponse(auth.error, auth.status)
  const user = auth.user!
  // ... lanjut Zod, business logic, logAudit
}
```

Untuk endpoint kritis (submit, face register), tambahkan **rate limit** in-memory (lihat `attendance/submit/route.ts` & `face/register/route.ts` sebagai referensi).

**Pola DB di Route Handler**: Pakai `createAdminClient()` setelah `authenticateRequest()` selesai (mahasiswa role + is_active sudah dicek). Aman karena:
1. JWT sudah verified.
2. Role + status user sudah match.
3. RLS bypass diperlukan karena query lintas-row (mis. cek enrollment, cek session ownership) tidak feasible dengan RLS user-mode.

## Middleware

`middleware.ts` di root sudah handle:
- Public routes: `/login`, `/api/mobile`
- Admin-only routes: `/mahasiswa`, `/dosen`, `/audit`, `/settings`, `/export`
- Bypass dev mode jika env masih placeholder

**Jangan ubah** kecuali menambah route baru — update array `PUBLIC_ROUTES` atau `ADMIN_ONLY_ROUTES`.

## Sidebar — Grouped Navigation

Sidebar (`app/components/layout/sidebar.tsx`) terbagi menjadi 4 grup. Tambahkan menu baru ke grup yang relevan, **jangan bikin grup baru tanpa alasan**:

| Grup | Item | Roles |
|------|------|-------|
| (tanpa label) | Dashboard | admin, dosen |
| **Data Master** | Mahasiswa, Dosen, Mata Kuliah | admin (semua), dosen (Mata Kuliah saja) |
| **Operasional** | Sesi Absensi, Rekap Absensi, Izin / Sakit | admin, dosen |
| **Sistem** | Export Data, Audit Log, Pengaturan | Export: admin+dosen · Audit & Settings: admin |

Halaman `/profil` **tidak ada di sidebar** — diakses lewat klik avatar di topbar (`app/components/layout/topbar.tsx`). Kalau menambah halaman user-personal serupa, ikuti pola ini.

## Dashboard — Role Split (Bukan Unified Component)

`app/(dashboard)/dashboard/page.tsx` mendeteksi role di server lalu render salah satu:
- `admin-dashboard.tsx` — statistik global (semua MK, semua dosen, trend mingguan).
- `dosen-dashboard.tsx` — statistik MK yang diampu saja.

Data fetching: `getAdminDashboardData()` & `getDosenDashboardData()` di `app/lib/actions/dashboard.ts`. **Pola yang dianut**: kalau dashboard makin kompleks dan perlu komponen berbeda per role, **split file**, jangan if-else di dalam satu komponen besar.

## React 18 — Bukan 19

```tsx
// ✅ React 18 (yang kita pakai)
import { useFormState, useFormStatus } from 'react-dom'
const [state, formAction] = useFormState(loginAction, initialState)

// ❌ React 19 (jangan pakai — BUG-004 dulu)
import { useActionState } from 'react'
```

Submit button yang butuh `useFormStatus` **harus** dipisah jadi komponen sendiri (lihat `(auth)/login/login-form.tsx`).

## Design Tokens TRPL — `app/globals.css`

| Token | Nilai | Pakai untuk |
|-------|-------|-------------|
| `--color-primary` | `#5483AD` (Biru Baja TRPL) | Tombol primary, link aktif, brand |
| `--color-success` | `#1A7F37` | Badge "Hadir", "Aktif" |
| `--color-warning` | `#9A6700` | Badge "Izin/Sakit", "Pending" |
| `--color-danger` | `#CF222E` | Badge "Alpa", "Nonaktif", error |
| `--radius-card` | `16px` | `.card` |
| `--radius-button` | `999px` | `.btn-primary`, `.btn-secondary` (pill) |
| Font heading | Plus Jakarta Sans | h1–h6 |
| Font body | Inter | body |

Komponen CSS yang sudah ada: `.card`, `.btn-primary/secondary/danger`, `.badge-success/warning/danger`, `.input-field`, `.data-table`, `.summary-card`, `.sidebar-nav-item`, `.skeleton`. **Reuse dulu** sebelum bikin baru.

## UI Patterns yang Sudah Disepakati

- **Konfirmasi destruktif**: SweetAlert2 (`@/lib/swal`) atau custom modal — **JANGAN** `window.confirm()` (BUG-008: blocking React lifecycle).
- **Dropdown 3-titik di tabel**: pakai *fixed positioning* di luar container scroll/overflow (BUG-007: `overflow-hidden` parent meng-clip dropdown).
- **Loading state**: skeleton (`.skeleton`) atau Lucide spinner, jangan teks "Loading...".
- **Empty state**: kalimat ramah Indonesia, contoh "Belum ada absensi hari ini."
- **Toast**: `toast.fire({ icon, title })` dari `@/lib/swal`.

## TypeScript

- Hindari `any`. Untuk join Supabase yang sulit di-type, pakai `as unknown as Array<...>` lalu narrow.
- Untuk komponen yang hanya butuh sebagian field dari `Profile`, definisikan tipe lokal: `type SidebarProfile = Pick<Profile, 'id'|'full_name'|'role'|...>`.
- `tsconfig` strict — jaga build tetap hijau (`npm run type-check`).

## Audit Log — Action Names

Konvensi snake_case: `create_session`, `start_session`, `refresh_session_code`, `mobile_attendance_submit`, `mock_location_detected`, `reset_student_password`, `import_students_csv`, dll. Cari nama yang serupa di `app/lib/actions/*.ts` sebelum bikin baru — konsistensi penting untuk filter audit log.

## Gotchas

1. **`useFormState` hanya bisa dipakai dari Client Component** (`'use client'`). Kalau page-nya server, pisahkan form ke `*-form.tsx` client.
2. **`cookies()` hanya boleh dari Server Component / Server Action / Route Handler**. `createAdminClient()` aman karena tidak akses cookies.
3. **`revalidatePath('/', 'layout')`** untuk perubahan auth (login/logout), `revalidatePath('/halaman')` untuk mutasi spesifik.
4. **Email Supabase Auth tidak otomatis sync** ke `profiles` — kalau update email user, panggil juga `supabase.auth.admin.updateUserById()`.
