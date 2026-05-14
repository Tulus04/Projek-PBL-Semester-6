// app/page.tsx
// Root page — redirect ke /dashboard jika sudah login, /login jika belum.
// Middleware sudah menangani ini, tapi ini sebagai fallback.

import { redirect } from 'next/navigation'

export default function RootPage() {
  redirect('/login')
}
