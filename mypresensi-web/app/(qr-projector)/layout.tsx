// app/(qr-projector)/layout.tsx
// Layout terisolasi untuk mode presentasi fullscreen QR Display.
// TIDAK render sidebar/topbar dashboard — projector mode butuh viewport penuh.
// Dark theme base styling agar QR card putih kontras kuat di kelas dengan
// lampu redup/proyektor.
//
// Catatan keamanan: layout TIDAK panggil auth guard — tanggung jawab
// di-page.tsx agar layout reusable kalau ke depan ada route lain di group ini.

import type { Metadata } from 'next'

export const metadata: Metadata = {
  // Halaman admin-only — jangan ke-index search engine.
  robots: {
    index: false,
    follow: false,
  },
}

export default function QrProjectorLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="qr-projector-root min-h-screen bg-[#050d1c] text-white antialiased">
      {children}
    </div>
  )
}
