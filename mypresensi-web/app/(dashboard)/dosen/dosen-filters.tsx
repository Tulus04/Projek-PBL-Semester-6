'use client'
// app/(dashboard)/dosen/dosen-filters.tsx
// Client component: search by nama/NIP.

import { useRouter, useSearchParams } from 'next/navigation'
import { useRef } from 'react'
import { Search } from 'lucide-react'

export default function DosenFilters() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const timerRef = useRef<NodeJS.Timeout | null>(null)

  const handleSearch = (value: string) => {
    if (timerRef.current) clearTimeout(timerRef.current)
    timerRef.current = setTimeout(() => {
      const params = new URLSearchParams()
      if (value) params.set('q', value)
      router.push(`/dosen?${params.toString()}`)
    }, 400)
  }

  return (
    <div className="px-6 py-4 flex items-center gap-4">
      <div className="relative flex-1">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary" />
        <input
          type="text"
          placeholder="Cari nama atau NIP..."
          defaultValue={searchParams.get('q') ?? ''}
          onChange={(e) => handleSearch(e.target.value)}
          className="input-field pl-9 w-full"
        />
      </div>
    </div>
  )
}
