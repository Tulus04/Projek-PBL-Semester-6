// app/(dashboard)/sesi/[id]/page.tsx
// Redirect route — /sesi/[id] (bare) tidak punya tampilan sendiri.
// Detail presensi per sesi ditampilkan via SessionDetailModal di halaman
// daftar sesi, sedangkan pemantauan real-time ada di /sesi/[id]/live.
// Route ini mencegah 404 saat user akses /sesi/[id] manual (bookmark/ketik
// URL) dengan mengarahkan ke Live Monitor.

import { redirect } from 'next/navigation'

interface PageProps {
  params: Promise<{ id: string }>
}

export default async function SessionDetailRedirect({ params }: PageProps) {
  const { id } = await params
  redirect(`/sesi/${id}/live`)
}
