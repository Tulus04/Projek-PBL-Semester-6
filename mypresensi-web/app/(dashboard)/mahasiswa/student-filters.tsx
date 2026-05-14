'use client'
// app/(dashboard)/mahasiswa/student-filters.tsx
// Filter semester & kelas — auto-submit saat berubah.

import { useRouter, useSearchParams } from 'next/navigation'
import { Search } from 'lucide-react'

export default function StudentFilters() {
  const router = useRouter()
  const searchParams = useSearchParams()

  const currentSearch = searchParams.get('q') ?? ''
  const currentSemester = searchParams.get('semester') ?? ''
  const currentKelas = searchParams.get('kelas') ?? ''

  const updateFilter = (key: string, value: string) => {
    const params = new URLSearchParams(searchParams.toString())
    if (value) {
      params.set(key, value)
    } else {
      params.delete(key)
    }
    params.delete('page') // Reset ke halaman 1
    router.push(`/mahasiswa?${params.toString()}`)
  }

  const handleSearch = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const formData = new FormData(e.currentTarget)
    const q = formData.get('q') as string
    updateFilter('q', q)
  }

  return (
    <div className="px-6 py-4 flex items-center gap-4 flex-wrap">
      {/* Search */}
      <form className="flex-1 min-w-[240px]" onSubmit={handleSearch}>
        <div className="relative">
          <Search
            size={16}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary"
          />
          <input
            type="text"
            name="q"
            defaultValue={currentSearch}
            placeholder="Cari nama atau NIM..."
            className="input-field pl-9 w-full"
          />
        </div>
      </form>

      {/* Filter Semester */}
      <select
        className="input-field text-sm py-2 pr-8 w-auto min-w-[160px]"
        value={currentSemester}
        onChange={(e) => updateFilter('semester', e.target.value)}
      >
        <option value="">Semua Semester</option>
        {[1, 2, 3, 4, 5, 6, 7, 8].map((s) => (
          <option key={s} value={s}>
            Semester {s}
          </option>
        ))}
      </select>

      {/* Filter Kelas */}
      <select
        className="input-field text-sm py-2 pr-8 w-auto min-w-[140px]"
        value={currentKelas}
        onChange={(e) => updateFilter('kelas', e.target.value)}
      >
        <option value="">Semua Kelas</option>
        {['A', 'B', 'C', 'D'].map((k) => (
          <option key={k} value={k}>
            Kelas {k}
          </option>
        ))}
      </select>
    </div>
  )
}
