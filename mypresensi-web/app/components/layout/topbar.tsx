'use client'
// app/components/layout/topbar.tsx
// Top bar di atas konten dashboard.
// Menampilkan: hamburger (mobile) + judul halaman + notifikasi + info user.

import { usePathname } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { Menu } from 'lucide-react'
import NotificationDropdown from './notification-dropdown'
import { useSidebar } from './sidebar-provider'

type TopBarProfile = {
  full_name: string
  role: string
  avatar_url: string | null
}

interface TopBarProps {
  profile: TopBarProfile | null
}

// Map pathname ke judul halaman
const pageTitles: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/mahasiswa': 'Kelola Mahasiswa',
  '/dosen': 'Kelola Dosen',
  '/matakuliah': 'Mata Kuliah',
  '/sesi': 'Sesi Absensi',
  '/rekap': 'Rekap Absensi',
  '/izin': 'Izin / Sakit',
  '/export': 'Export Data',
  '/audit': 'Audit Log',
  '/settings': 'Pengaturan Sistem',
  '/profil': 'Profil Saya',
}

export default function TopBar({ profile }: TopBarProps) {
  const pathname = usePathname()
  const { toggle } = useSidebar()

  // Cari judul yang cocok (termasuk sub-route)
  const title =
    Object.entries(pageTitles).find(([key]) =>
      pathname === key || pathname.startsWith(key + '/')
    )?.[1] ?? 'Dashboard'

  return (
    <header className="h-16 bg-white border-b border-border flex items-center justify-between px-4 md:px-6 flex-shrink-0 gap-3">
      {/* Hamburger + Judul halaman */}
      <div className="flex items-center gap-3 min-w-0">
        <button
          type="button"
          onClick={toggle}
          className="md:hidden p-2 -ml-1 rounded-lg hover:bg-gray-100 transition-colors flex-shrink-0"
          aria-label="Buka menu navigasi"
        >
          <Menu size={20} className="text-text-primary" />
        </button>
        <h1 className="text-base md:text-lg font-bold font-heading text-text-primary truncate">
          {title}
        </h1>
      </div>

      {/* Kanan: Notifikasi + User info */}
      <div className="flex items-center gap-3">
        {/* Dropdown notifikasi */}
        <NotificationDropdown />

        {/* Avatar + nama — klik ke profil */}
        <Link
          href="/profil"
          className="flex items-center gap-2.5 hover:opacity-80 transition-opacity"
        >
          {profile?.avatar_url ? (
            <Image
              src={profile.avatar_url}
              alt={profile.full_name}
              width={32}
              height={32}
              className="w-8 h-8 rounded-full object-cover"
              unoptimized
            />
          ) : (
            <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold bg-primary">
              {profile?.full_name?.charAt(0).toUpperCase() ?? 'U'}
            </div>
          )}
          <div className="hidden sm:block">
            <p className="text-sm font-semibold text-text-primary leading-tight">
              {profile?.full_name ?? 'Pengguna'}
            </p>
            <p className="text-xs text-text-secondary capitalize leading-tight">
              {profile?.role ?? ''}
            </p>
          </div>
        </Link>
      </div>
    </header>
  )
}
