'use client'
// app/(dashboard)/izin/leave-filters.tsx
// Filter untuk halaman izin/sakit: status.

import { useRouter, useSearchParams } from 'next/navigation'
import { Search } from 'lucide-react'

export default function LeaveFilters() {
  const router = useRouter()
  const searchParams = useSearchParams()

  const handleFilter = (status: string) => {
    const params = new URLSearchParams()
    if (status && status !== 'all') params.set('status', status)
    router.push(`/izin?${params.toString()}`)
  }

  return (
    <div className="flex items-center gap-4">
      <div className="flex-1">
        <label className="text-xs font-semibold text-text-secondary uppercase mb-1 block">Status</label>
        <select
          defaultValue={searchParams.get('status') ?? 'all'}
          onChange={(e) => handleFilter(e.target.value)}
          className="input-field w-full"
        >
          <option value="all">Semua Status</option>
          <option value="pending">Menunggu</option>
          <option value="approved">Disetujui</option>
          <option value="rejected">Ditolak</option>
        </select>
      </div>
      <div className="flex items-end">
        <button
          onClick={() => handleFilter(searchParams.get('status') ?? 'all')}
          className="btn-primary flex items-center gap-2 px-5 py-2.5"
        >
          <Search size={14} /> Filter
        </button>
      </div>
    </div>
  )
}
