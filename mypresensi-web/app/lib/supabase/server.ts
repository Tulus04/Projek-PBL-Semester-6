// src/lib/supabase/server.ts
// Supabase client untuk Server Components dan Server Actions.
// API key service role TIDAK pernah dikirim ke browser.

import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

// Client untuk operasi yang membutuhkan auth user (baca data dengan RLS)
export function createClient() {
  const cookieStore = cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // Diabaikan jika dipanggil dari Server Component (read-only)
          }
        },
      },
    }
  )
}

// Client untuk operasi admin yang bypass RLS (gunakan dengan SANGAT hati-hati)
// Hanya boleh dipakai di Server Actions dan API Routes
export function createAdminClient() {
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    {
      cookies: {
        getAll() { return [] },
        setAll() {},
      },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    }
  )
}
