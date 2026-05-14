'use client'
// app/components/layout/sidebar.tsx
// Sidebar navigasi kiri — grouped navigation dengan label kategori.
// Responsive: desktop static, mobile slide-in drawer dengan backdrop.
// Client Component karena butuh usePathname untuk active state + sidebar context.

import Link from 'next/link'
import Image from 'next/image'
import { usePathname } from 'next/navigation'
import {
  LayoutDashboard,
  Users,
  GraduationCap,
  BookOpen,
  PlayCircle,
  ClipboardList,
  FileText,
  Download,
  Settings,
  ScrollText,
  AlertTriangle,
  LogOut,
  X,
  type LucideIcon,
} from 'lucide-react'
import { logoutAction } from '@/lib/actions/auth'
import { cn } from '@/lib/utils'
import { useSidebar } from './sidebar-provider'

type SidebarProfile = {
  id: string
  full_name: string
  nim_nip: string
  role: string
  avatar_url: string | null
  must_change_password: boolean
}

interface SidebarProps {
  profile: SidebarProfile | null
}

// Definisi menu dalam grup dengan label kategori
interface NavItem {
  label: string
  href: string
  icon: LucideIcon
  roles: string[]
}

interface NavGroup {
  groupLabel: string | null // null = tanpa label (untuk Dashboard)
  items: NavItem[]
}

const navGroups: NavGroup[] = [
  {
    groupLabel: null,
    items: [
      {
        label: 'Dashboard',
        href: '/dashboard',
        icon: LayoutDashboard,
        roles: ['admin', 'dosen'],
      },
    ],
  },
  {
    groupLabel: 'Data Master',
    items: [
      {
        label: 'Mahasiswa',
        href: '/mahasiswa',
        icon: GraduationCap,
        roles: ['admin'],
      },
      {
        label: 'Dosen',
        href: '/dosen',
        icon: Users,
        roles: ['admin'],
      },
      {
        label: 'Mata Kuliah',
        href: '/matakuliah',
        icon: BookOpen,
        roles: ['admin', 'dosen'],
      },
    ],
  },
  {
    groupLabel: 'Operasional',
    items: [
      {
        label: 'Sesi Absensi',
        href: '/sesi',
        icon: PlayCircle,
        roles: ['admin', 'dosen'],
      },
      {
        label: 'Rekap Absensi',
        href: '/rekap',
        icon: ClipboardList,
        roles: ['admin', 'dosen'],
      },
      {
        label: 'Mahasiswa Berisiko',
        href: '/at-risk',
        icon: AlertTriangle,
        roles: ['admin'],
      },
      {
        label: 'Izin / Sakit',
        href: '/izin',
        icon: FileText,
        roles: ['admin', 'dosen'],
      },
    ],
  },
  {
    groupLabel: 'Sistem',
    items: [
      {
        label: 'Export Data',
        href: '/export',
        icon: Download,
        roles: ['admin', 'dosen'],
      },
      {
        label: 'Audit Log',
        href: '/audit',
        icon: ScrollText,
        roles: ['admin'],
      },
      {
        label: 'Pengaturan',
        href: '/settings',
        icon: Settings,
        roles: ['admin'],
      },
    ],
  },
]

export default function Sidebar({ profile }: SidebarProps) {
  const pathname = usePathname()
  const { isOpen, close } = useSidebar()
  const role = profile?.role ?? 'admin'

  // Filter grup: hanya tampilkan grup yang punya item sesuai role
  const filteredGroups = navGroups
    .map((group) => ({
      ...group,
      items: group.items.filter((item) => item.roles.includes(role)),
    }))
    .filter((group) => group.items.length > 0)

  return (
    <>
      {/* Backdrop — hanya tampil di mobile saat drawer terbuka */}
      {isOpen && (
        <div
          className="fixed inset-0 z-30 bg-black/40 md:hidden"
          onClick={close}
          aria-hidden="true"
        />
      )}

      <aside
        className={cn(
          'w-60 flex-shrink-0 bg-white border-r border-border flex flex-col',
          // Mobile: fixed slide-in drawer; Desktop (md+): static
          'fixed inset-y-0 left-0 z-40 transition-transform duration-300 ease-out',
          'md:static md:translate-x-0 md:transition-none',
          isOpen ? 'translate-x-0 shadow-2xl' : '-translate-x-full'
        )}
        aria-label="Navigasi utama"
      >
        {/* Logo area + close button mobile */}
        <div className="h-16 flex items-center px-5 border-b border-border gap-3">
          <div className="w-8 h-8 rounded-lg flex-shrink-0 overflow-hidden">
            <Image
              src="/trpl-logo.jpg"
              alt="Logo TRPL"
              width={32}
              height={32}
              className="object-contain"
            />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-bold font-heading text-text-primary leading-tight">
              MyPresensi
            </p>
            <p className="text-xs text-text-secondary leading-tight">TRPL · Politani</p>
          </div>
          {/* Close button — hanya tampil di mobile */}
          <button
            type="button"
            onClick={close}
            className="md:hidden p-1.5 rounded-lg hover:bg-gray-100 transition-colors"
            aria-label="Tutup menu navigasi"
          >
            <X size={18} className="text-text-secondary" />
          </button>
        </div>

        {/* Navigation — Grouped */}
        <nav className="flex-1 px-3 py-4 flex flex-col gap-0.5 overflow-y-auto">
        {filteredGroups.map((group, groupIndex) => (
          <div key={group.groupLabel ?? 'main'}>
            {/* Group label */}
            {group.groupLabel && (
              <div className="px-3 pt-4 pb-1.5">
                <p className="text-[10px] font-semibold uppercase tracking-widest text-text-secondary/60">
                  {group.groupLabel}
                </p>
              </div>
            )}

            {/* Divider sebelum grup (kecuali grup pertama) */}
            {groupIndex > 0 && !group.groupLabel && (
              <hr className="my-2 border-border" />
            )}

            {/* Menu items */}
            {group.items.map((item) => {
              const isActive = pathname === item.href || pathname.startsWith(item.href + '/')
              const Icon = item.icon

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn('sidebar-nav-item', isActive && 'active')}
                >
                  <Icon size={18} strokeWidth={1.75} />
                  {item.label}
                </Link>
              )
            })}
          </div>
        ))}
      </nav>

      {/* User + Logout */}
      <div className="border-t border-border p-3">
        <div className="flex items-center gap-3 px-2 py-2 mb-1">
          {/* Avatar */}
          {profile?.avatar_url ? (
            <Image
              src={profile.avatar_url}
              alt={profile.full_name}
              width={32}
              height={32}
              className="w-8 h-8 rounded-full object-cover flex-shrink-0"
              unoptimized
            />
          ) : (
            <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0 bg-primary">
              {profile?.full_name?.charAt(0).toUpperCase() ?? 'U'}
            </div>
          )}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-text-primary truncate">
              {profile?.full_name ?? 'Pengguna'}
            </p>
            <p className="text-xs text-text-secondary truncate capitalize">
              {profile?.role ?? ''}
            </p>
          </div>
        </div>

          <form action={logoutAction}>
            <button
              type="submit"
              className="sidebar-nav-item w-full text-danger hover:bg-danger/5 hover:text-danger"
            >
              <LogOut size={18} strokeWidth={1.75} />
              Keluar
            </button>
          </form>
        </div>
      </aside>
    </>
  )
}
