// middleware.ts
// Proteksi route — auth check + role-based access control.
// Layer pertama pertahanan: route admin-only di-block untuk role selain admin.
// CATATAN: Ini BUKAN satu-satunya layer keamanan — server actions juga validasi role.

import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

const PUBLIC_ROUTES = ['/login', '/api/mobile']

// Route yang HANYA boleh diakses oleh admin
const ADMIN_ONLY_ROUTES = ['/mahasiswa', '/dosen', '/audit', '/settings', '/export']

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Selalu izinkan akses ke route publik tanpa cek auth
  if (PUBLIC_ROUTES.some((route) => pathname.startsWith(route))) {
    return NextResponse.next()
  }

  // Jika env belum diisi, izinkan semua request (mode dev)
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  const isEnvConfigured =
    supabaseUrl &&
    supabaseKey &&
    supabaseUrl !== 'your_supabase_project_url_here' &&
    supabaseKey !== 'your_supabase_anon_key_here'

  if (!isEnvConfigured) {
    return NextResponse.next()
  }

  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(supabaseUrl!, supabaseKey!, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value)
        )
        supabaseResponse = NextResponse.next({ request })
        cookiesToSet.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(name, value, options)
        )
      },
    },
  })

  const {
    data: { user },
  } = await supabase.auth.getUser()

  // User belum login → redirect ke login
  if (!user) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  // =========================================
  // ROLE-BASED ACCESS CONTROL
  // =========================================
  // Cek apakah route ini admin-only
  const isAdminRoute = ADMIN_ONLY_ROUTES.some((route) => pathname.startsWith(route))

  if (isAdminRoute) {
    // Fetch role menggunakan service_role key (bypass RLS) karena
    // anon key + RLS tidak reliable di middleware untuk baca profiles orang lain
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
    if (serviceRoleKey) {
      const { createClient } = await import('@supabase/supabase-js')
      const adminClient = createClient(supabaseUrl!, serviceRoleKey)

      const { data: profile } = await adminClient
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single()

      const role = profile?.role

      // Jika bukan admin, redirect ke dashboard (bukan 403 — UX lebih halus)
      if (role !== 'admin') {
        const url = request.nextUrl.clone()
        url.pathname = '/dashboard'
        return NextResponse.redirect(url)
      }
    }
  }

  return supabaseResponse
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
