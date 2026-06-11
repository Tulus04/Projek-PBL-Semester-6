// app/components/dashboard/quick-actions.tsx
// Quick Actions Panel — 4 tombol cepat di dashboard admin untuk reduce clicks.
// Server Component (data already di-pass via props dari parent).
// Tombol: Tambah Mahasiswa, Tambah Dosen, Approve Izin (with counter), Export Rekap.

import Link from 'next/link'
import { UserPlus, Users, FileText, Download, ArrowRight } from 'lucide-react'

interface QuickActionsProps {
  /** Jumlah pengajuan izin yang masih pending — untuk badge counter. */
  pendingLeaveCount: number
}

interface QuickAction {
  icon: typeof UserPlus
  title: string
  description: string
  href: string
  variant: 'primary' | 'success' | 'warning' | 'danger'
  /** Optional badge counter (shown in top-right). */
  badge?: number
}

export default function QuickActions({ pendingLeaveCount }: QuickActionsProps) {
  const actions: QuickAction[] = [
    {
      icon: UserPlus,
      title: 'Tambah Mahasiswa',
      description: 'Daftarkan mahasiswa baru',
      href: '/mahasiswa',
      variant: 'primary',
    },
    {
      icon: Users,
      title: 'Tambah Dosen',
      description: 'Daftarkan pengajar',
      href: '/dosen',
      variant: 'primary',
    },
    {
      icon: FileText,
      title: 'Persetujuan Izin',
      description: 'Pengajuan menunggu',
      href: '/izin?status=pending',
      variant: 'warning',
      badge: pendingLeaveCount > 0 ? pendingLeaveCount : undefined,
    },
    {
      icon: Download,
      title: 'Unduh Rekap',
      description: 'Unduh laporan PDF/CSV',
      href: '/export',
      variant: 'success',
    },
  ]

  // Variant → CSS class mapping (icon box duotone consistent dengan kpi-icon-box)
  const variantStyle: Record<QuickAction['variant'], string> = {
    primary: 'bg-primary/10 text-primary group-hover:bg-primary group-hover:text-white',
    success: 'bg-success/10 text-success group-hover:bg-success group-hover:text-white',
    warning: 'bg-warning/10 text-warning group-hover:bg-warning group-hover:text-white',
    danger: 'bg-danger/10 text-danger group-hover:bg-danger group-hover:text-white',
  }

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
      {actions.map(({ icon: Icon, title, description, href, variant, badge }) => (
        <Link
          key={title}
          href={href}
          className="card p-4 group hover:border-primary/30 transition-all relative overflow-hidden"
        >
          {/* Counter badge */}
          {badge !== undefined && badge > 0 && (
            <span className="absolute top-3 right-3 inline-flex items-center justify-center min-w-[20px] h-5 px-1.5 rounded-full bg-danger text-white text-[10px] font-bold">
              {badge}
            </span>
          )}

          <div className="flex items-start gap-3">
            {/* Icon box */}
            <div
              className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all flex-shrink-0 ${variantStyle[variant]}`}
            >
              <Icon size={18} />
            </div>

            {/* Text */}
            <div className="flex-1 min-w-0">
              <p className="text-sm font-bold font-heading text-text-primary leading-tight mb-0.5">
                {title}
              </p>
              <p className="text-xs text-text-secondary leading-tight">{description}</p>
            </div>
          </div>

          {/* Arrow indicator on hover */}
          <ArrowRight
            size={14}
            className="absolute bottom-3 right-3 text-text-secondary opacity-0 group-hover:opacity-100 group-hover:translate-x-0.5 transition-all"
          />
        </Link>
      ))}
    </div>
  )
}
