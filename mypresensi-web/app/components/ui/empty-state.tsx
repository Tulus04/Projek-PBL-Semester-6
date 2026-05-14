// app/components/ui/empty-state.tsx
// Komponen reusable untuk empty state di seluruh dashboard.
// Pattern: icon (Lucide) + title + description + optional hint/CTA.
// Mengikuti rule 03-design-and-libraries.md — empty state WAJIB jelaskan kenapa kosong + next action.

import type { LucideIcon } from 'lucide-react'
import type { ReactNode } from 'react'

interface EmptyStateProps {
  icon: LucideIcon
  title: string
  description?: string
  hint?: ReactNode // optional secondary text atau JSX (mis. instruksi navigasi)
  action?: ReactNode // optional CTA button/link
  /** Variant size — `default` untuk halaman utama, `compact` untuk dalam modal/dropdown */
  size?: 'default' | 'compact'
}

export default function EmptyState({
  icon: Icon,
  title,
  description,
  hint,
  action,
  size = 'default',
}: EmptyStateProps) {
  const isCompact = size === 'compact'

  return (
    <div className={`${isCompact ? 'py-6' : 'py-12'} text-center`}>
      <div
        className={`mx-auto ${isCompact ? 'w-10 h-10' : 'w-14 h-14'} rounded-2xl bg-primary/5 flex items-center justify-center mb-3`}
      >
        <Icon size={isCompact ? 20 : 28} className="text-text-secondary opacity-60" />
      </div>
      <p
        className={`${isCompact ? 'text-xs' : 'text-sm'} font-medium text-text-primary mb-1`}
      >
        {title}
      </p>
      {description && (
        <p
          className={`${isCompact ? 'text-[11px]' : 'text-xs'} text-text-secondary ${isCompact ? '' : 'max-w-md mx-auto'}`}
        >
          {description}
        </p>
      )}
      {hint && (
        <div className={`${isCompact ? 'text-[11px]' : 'text-xs'} text-text-secondary mt-2`}>
          {hint}
        </div>
      )}
      {action && <div className="mt-4">{action}</div>}
    </div>
  )
}
