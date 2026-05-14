---
trigger: glob
globs: mypresensi-web/**
description: Pola Next.js 14 App Router yang wajib diikuti — Server vs Client Component, data fetching, Route Handler, error boundary, performance.
---

# Next.js Patterns — `mypresensi-web/`

Komplemen `10-web-conventions.md`. Fokus di pola arsitektur Next.js, bukan struktur folder.

## A. Server vs Client Component

### Iron Rule
**DEFAULT = Server Component.** Hanya tambahkan `'use client'` jika butuh:
- Interaksi browser (`onClick`, `onChange`, `useState`, `useEffect`, `useRef`, `useFormState`).
- Browser-only API (`window`, `document`, `localStorage`, `navigator`).
- React Context yang konsumsi state.
- Library yang import browser API (mis. chart library yang render canvas).

### Pembagian Tanggung Jawab
| Server Component | Client Component |
|------------------|------------------|
| Fetch data dari Supabase / DB | Form state, modal, toggle, dropdown |
| Akses `cookies()`, `headers()` | `useFormState` + `useFormStatus` |
| Render HTML statis | Animasi yang react ke state |
| Auth guard di `layout.tsx` | Real-time subscription (jika ada) |

### Pola yang Wajib Diikuti
```tsx
// page.tsx — SERVER component (no 'use client')
import { createClient } from '@/lib/supabase/server'
import { ClientFormView } from './client-form-view'

export default async function FooPage() {
  // 1. Fetch data di server
  const supabase = await createClient()
  const { data } = await supabase.from('foos').select('*')

  // 2. Pass sebagai props ke Client Component
  return <ClientFormView initialData={data ?? []} />
}
```

```tsx
// client-form-view.tsx — CLIENT component
'use client'
import { useState } from 'react'

interface Props { initialData: Foo[] }
export function ClientFormView({ initialData }: Props) {
  const [foos, setFoos] = useState(initialData)
  // ... interaksi
}
```

### Yang TIDAK Boleh
- ❌ Fetch data di Client Component pakai `useEffect` + `fetch` kalau bisa di server.
- ❌ Import Server Component di dalam Client Component (tapi pass via children/props OK).
- ❌ Pakai `'use client'` di file yang tidak butuh interaksi.
- ❌ Pass function dari Server ke Client (kecuali Server Action).

### Pengecualian
- **Real-time** (mis. polling notifikasi): Client Component pakai `useEffect` + `setInterval` atau Supabase Realtime.
- **Form**: Client Component dengan `useFormState`. Server Action di-import dan dipass sebagai prop ke `useFormState`.

## B. Data Fetching

1. **Fetch data di Server Component**, BUKAN Client Component (kecuali real-time/polling).
2. **Hindari data waterfalls** — pakai `Promise.all()` untuk parallel fetch:
   ```tsx
   const [profile, courses, sessions] = await Promise.all([
     getProfile(userId),
     getCourses(userId),
     getActiveSessions(),
   ])
   ```
3. **`loading.tsx`** untuk auto-Suspense streaming. Atau pakai `<Suspense fallback={<Skeleton />}>` manual untuk granular control.
4. **Server Actions** (`'use server'`) untuk **mutasi** data (create/update/delete). Lihat workflow `/add-server-action`.
5. **Route Handlers** (`/api/*/route.ts`) HANYA untuk:
   - Endpoint mobile (`/api/mobile/*`).
   - Webhook eksternal.
   - Special case yang butuh response non-HTML.
   **JANGAN** pakai Route Handler untuk internal data fetching dari komponen — pakai Server Component langsung.

## C. File Conventions

| File | Tujuan | Catatan |
|------|--------|---------|
| `page.tsx` | Halaman route | 1 page per folder |
| `layout.tsx` | Wrapper persistent across navigation | Auth guard di `(dashboard)/layout.tsx` |
| `loading.tsx` | Loading UI (auto-Suspense) | Pakai `.skeleton` |
| `error.tsx` | Error boundary | **WAJIB** Client Component (`'use client'`) |
| `not-found.tsx` | 404 page | Per route group |
| `route.ts` | API endpoint | JANGAN bareng `page.tsx` di folder sama |
| `*-form.tsx` / `*-table.tsx` | Komponen client per halaman | Pisah dari `page.tsx` agar `useFormState` bisa dipakai |

### Error Boundary — WAJIB
**Setiap route group** wajib punya `error.tsx` agar error tidak crash seluruh app. Pakai pola:
```tsx
'use client'
export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div className="card">
      <h2>Terjadi kesalahan</h2>
      <p>{error.message || 'Coba beberapa saat lagi.'}</p>
      <button onClick={reset} className="btn-primary">Coba Lagi</button>
    </div>
  )
}
```

## D. Navigation

- **Server Component** → pakai `redirect()` dari `next/navigation`. JANGAN `router.push()`.
- **Client Component** → `router.push()` dari `useRouter()`.
- **404** → pakai `notFound()` dari `next/navigation`.
- Di catch block, kalau lempar redirect/notFound → pakai `unstable_rethrow()` sebelum catch generic agar redirect tidak ketelan.

## E. Route Handlers (untuk `/api/mobile/*`)

1. `route.ts` TIDAK punya akses React DOM — pure server logic.
2. Response: `return new NextResponse(JSON.stringify(data), { status, headers })` atau pakai helper `successResponse()` / `errorResponse()` dari `app/api/mobile/_lib/auth.ts`.
3. JANGAN buat `route.ts` dan `page.tsx` di folder yang sama.
4. Pakai **Zod** untuk validasi request body. Pesan error Bahasa Indonesia.
5. Pakai helper `authenticateRequest()` — Bearer JWT + role mahasiswa + `is_active=true`.
6. Untuk endpoint kritis (submit, face register) tambah **rate limit** in-memory (lihat `attendance/submit/route.ts`).
7. Lihat workflow `/add-mobile-api-endpoint` untuk template lengkap.

## F. Performance

1. **Image**: pakai `next/image`, BUKAN `<img>` — auto optimize + lazy load.
2. **Font**: pakai `next/font` (bukan `<link>` manual) — auto-optimize, tidak ada FOUT.
3. **LCP image**: set `priority={true}` pada gambar above-the-fold (mis. logo login).
4. **Lazy load komponen berat**:
   ```tsx
   import dynamic from 'next/dynamic'
   const Chart = dynamic(() => import('./chart'), { ssr: false, loading: () => <Skeleton /> })
   ```
5. **Avoid client bundle bloat** — chart library, PDF generator, CSV parser → lazy load atau hanya di Server Component / Server Action.

## G. Directives

- `'use client'` di **baris pertama** file Client Component (boleh setelah komentar header).
- `'use server'` di **baris pertama** file Server Action.
- JANGAN pass function biasa dari Server ke Client (kecuali Server Action yang sudah `'use server'`).

## H. Pola Cache & Revalidation

| Operasi | Yang dilakukan |
|---------|----------------|
| Login / Logout | `revalidatePath('/', 'layout')` |
| Mutasi 1 halaman | `revalidatePath('/halaman-terkait')` |
| Mutasi yang affect banyak halaman | `revalidatePath('/dashboard')` + `revalidatePath('/sesi')` (eksplisit) |
| Tag-based (advanced) | `revalidateTag('foo')` setelah `fetch(..., { next: { tags: ['foo'] } })` |

## I. Common Pitfalls MyPresensi

1. **`useFormState` HANYA di Client Component** — kalau page-nya server, pisah form ke `*-form.tsx` client.
2. **`cookies()` HANYA di Server Component / Server Action / Route Handler**. `createAdminClient()` aman karena tidak akses cookies.
3. **Email Supabase Auth tidak otomatis sync ke `profiles`** — saat update email, panggil juga `supabase.auth.admin.updateUserById()`.
4. **Path alias `@/*` → `./app/*`** (BUKAN `./src/*`). Folder `mypresensi-web/src/` adalah peninggalan scaffold — abaikan (BUG-002).
5. **React 18, BUKAN 19** — pakai `useFormState` + `useFormStatus` dari `react-dom`. JANGAN `useActionState` dari `react` (BUG-004).
6. **Submit button yang butuh `useFormStatus`** harus komponen terpisah (lihat `(auth)/login/login-form.tsx`).

## J. Referensi

Pola lengkap: `https://github.com/vercel-labs/next-skills/tree/main/skills/next-best-practices`. Sesuaikan dengan konvensi MyPresensi yang sudah ada di `10-web-conventions.md`.
