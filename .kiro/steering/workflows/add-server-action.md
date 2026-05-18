---
inclusion: manual
description: Pola standar membuat Server Action baru di mypresensi-web (auth-guard + Zod + audit + revalidate). Pakai saat menambah CRUD baru di dashboard admin/dosen.
---

# Add Server Action

Workflow untuk menambah Server Action baru. Ikuti urutan ini agar konsisten dengan action yang sudah ada (`students.ts`, `dosen.ts`, `courses.ts`, `sessions.ts`).

## 1. Tentukan domain & nama file

File ditaruh di `mypresensi-web/app/lib/actions/<domain>.ts`. Domain = entitas utama (mahasiswa, dosen, mata kuliah, sesi, izin, dll). Kalau domain sudah ada, **tambahkan ke file existing**, jangan buat file baru.

## 2. Cek apakah perlu migration DB

- Jika action menyentuh kolom/tabel baru → buat dulu `mypresensi-web/supabase/migrations/00X_<nama>.sql` lalu jalankan di SQL Editor Supabase. Sertakan RLS policy + index jika perlu.
- Update `app/types/database.ts` jika ada interface baru.

## 3. Tulis schema Zod di atas file

```ts
const fooSchema = z.object({
  name: z.string().min(3, 'Nama minimal 3 karakter').max(100),
  // ... pesan error wajib Bahasa Indonesia
})

export type FooFormState = {
  error: string | null
  success: boolean
  fieldErrors?: Record<string, string[]>
}
```

## 4. Tulis action utama mengikuti template

```ts
'use server'

import { revalidatePath } from 'next/cache'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/server'
import { requireRole } from '@/lib/auth-guard'  // atau getCurrentUserProfile + canAccessCourse
import { logAudit } from '@/lib/audit-logger'

export async function addFooAction(
  _prevState: FooFormState,
  formData: FormData
): Promise<FooFormState> {
  // === 1. AUTH + ROLE ===
  let user
  try {
    user = await requireRole(['admin', 'dosen'])
  } catch (e) {
    return { error: (e as Error).message, success: false }
  }

  // === 2. PARSE & VALIDASI ===
  const raw = {
    name: formData.get('name') as string,
    // ...
  }
  const parsed = fooSchema.safeParse(raw)
  if (!parsed.success) {
    return {
      error: 'Data tidak valid',
      success: false,
      fieldErrors: parsed.error.flatten().fieldErrors,
    }
  }

  // === 3. (jika perlu) OWNERSHIP CHECK ===
  // const ok = await canAccessCourse(user.id, user.role, parsed.data.course_id)
  // if (!ok) return { error: 'Akses ditolak.', success: false }

  // === 4. PRE-CHECK DUPLICATE / KONDISI BISNIS ===
  const supabase = createAdminClient()
  const { data: dup } = await supabase
    .from('foos').select('id').eq('name', parsed.data.name).maybeSingle()
  if (dup) return { error: `'${parsed.data.name}' sudah terdaftar.`, success: false }

  // === 5. MUTASI ===
  const { error: insertError } = await supabase
    .from('foos')
    .insert({ name: parsed.data.name, created_by: user.id })

  if (insertError) {
    return { error: `Gagal menyimpan: ${insertError.message}`, success: false }
  }

  // === 6. AUDIT ===
  await logAudit({
    action: 'create_foo',
    details: { name: parsed.data.name },
  })

  // === 7. REVALIDATE ===
  revalidatePath('/foo')
  return { error: null, success: true }
}
```

## 5. Pola untuk variasi action

| Tipe | Patokan |
|------|---------|
| **Update** | Tambah `id` di formData, schema sama tanpa field unik. Jangan lupa `.neq('id', id)` saat cek duplikat. |
| **Toggle status** | Action sederhana terima `(id: string, isActive: boolean)`. Tetap `logAudit('toggle_<entity>_status')` + `revalidatePath`. |
| **Reset password** | Pakai `supabase.auth.admin.updateUserById(id, { password: defaultPwd })` + set `must_change_password=true`. |
| **Get list** | Bukan action, tapi function biasa exported yang dipanggil dari Server Component. Return `{ data, total, page, totalPages, error }`. |
| **Import CSV / batch** | Loop dengan counter `imported/skipped`, kembalikan ringkasan. Lihat `importStudentsCSVAction`. |
| **Delete** | Cek dependensi dulu (mis. cascade ke attendances) sebelum delete. Sertakan pesan error yang jelas jika ditolak. |

## 6. Pakai action dari komponen

```tsx
// File: app/(dashboard)/foo/foo-form.tsx
'use client'
import { useFormState, useFormStatus } from 'react-dom'
import { addFooAction, type FooFormState } from '@/lib/actions/foo'

const initial: FooFormState = { error: null, success: false }

export default function FooForm() {
  const [state, formAction] = useFormState(addFooAction, initial)
  // ... render form, baca state.fieldErrors?.name?.[0] untuk per-field error
}
```

`useFormStatus()` **harus** di komponen submit yang terpisah (lihat `(auth)/login/login-form.tsx`).

## 7. Verifikasi

// turbo
```powershell
npm run type-check
```

cwd: `mypresensi-web`.

Lalu coba dari browser (login → halaman terkait → trigger form). Cek juga `audit_logs` di Supabase Studio bahwa `action`-nya tercatat.

## 8. Update CHANGELOG (opsional tapi disarankan)

Tambah entri di `CHANGELOG.md` mengikuti format yang sudah ada (waktu, jenis `[ADD]`/`[MOD]`/`[FIX]`, file, deskripsi).
