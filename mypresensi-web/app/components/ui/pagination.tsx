// app/components/ui/pagination.tsx
// Komponen reusable untuk pagination di tabel-tabel dashboard.
// Pattern: "Halaman X dari Y (N data)" + Prev/Next button dengan preserve query string.
// Server-Component compatible (pakai Link, bukan useRouter).

import Link from 'next/link'
import { ChevronLeft, ChevronRight } from 'lucide-react'

interface PaginationProps {
  /** Halaman aktif (1-indexed) */
  page: number
  /** Total halaman */
  totalPages: number
  /** Total record (untuk ditampilkan di label) */
  total: number
  /** Base href tanpa query string (mis. `/matakuliah`, `/izin`) */
  baseHref: string
  /** Query params yang HARUS dipertahankan saat ganti halaman (mis. `{ q: 'admin', status: 'pending' }`) */
  searchParams?: Record<string, string | number | undefined | null>
  /** Variant size — `default` untuk halaman utama, `compact` untuk dalam modal */
  size?: 'default' | 'compact'
}

function buildHref(
  baseHref: string,
  searchParams: Record<string, string | number | undefined | null> = {},
  page: number
): string {
  const params = new URLSearchParams()
  params.set('page', String(page))
  for (const [k, v] of Object.entries(searchParams)) {
    if (v !== undefined && v !== null && v !== '') {
      params.set(k, String(v))
    }
  }
  return `${baseHref}?${params.toString()}`
}

export default function Pagination({
  page,
  totalPages,
  total,
  baseHref,
  searchParams = {},
  size = 'default',
}: PaginationProps) {
  if (totalPages <= 1) return null

  const isCompact = size === 'compact'
  const labelClass = isCompact ? 'text-xs' : 'text-sm'
  const btnClass = `btn-secondary ${isCompact ? 'text-xs py-1 px-2' : 'text-sm py-1.5 px-3'} flex items-center gap-1`

  return (
    <div
      className={`flex items-center justify-between px-6 ${isCompact ? 'py-3' : 'py-4'} border-t border-border`}
    >
      <p className={`${labelClass} text-text-secondary`}>
        Halaman {page} dari {totalPages}
        {!isCompact && ` (${total} data)`}
      </p>
      <div className="flex items-center gap-1">
        {page > 1 && (
          <Link href={buildHref(baseHref, searchParams, page - 1)} className={btnClass}>
            <ChevronLeft size={14} /> Prev
          </Link>
        )}
        {page < totalPages && (
          <Link href={buildHref(baseHref, searchParams, page + 1)} className={btnClass}>
            Next <ChevronRight size={14} />
          </Link>
        )}
      </div>
    </div>
  )
}
