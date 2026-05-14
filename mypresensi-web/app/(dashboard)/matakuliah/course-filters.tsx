'use client'
// app/(dashboard)/matakuliah/course-filters.tsx
// Client component: search + filter semester.

import { useRouter, useSearchParams } from 'next/navigation'
import { useRef } from 'react'
import { Search } from 'lucide-react'

export default function CourseFilters() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const timerRef = useRef<NodeJS.Timeout | null>(null)

  const currentQ = searchParams.get('q') ?? ''
  const currentSemester = searchParams.get('semester') ?? ''

  const buildUrl = (params: Record<string, string>) => {
    const sp = new URLSearchParams()
    const q = params.q ?? currentQ
    const semester = params.semester ?? currentSemester

    if (q) sp.set('q', q)
    if (semester) sp.set('semester', semester)
    return `/matakuliah?${sp.toString()}`
  }

  const handleSearch = (value: string) => {
    if (timerRef.current) clearTimeout(timerRef.current)
    timerRef.current = setTimeout(() => {
      router.push(buildUrl({ q: value }))
    }, 400)
  }

  return (
    <div className="px-6 py-4 flex items-center gap-4">
      <div className="relative flex-1">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary" />
        <input
          type="text"
          placeholder="Cari kode atau nama mata kuliah..."
          defaultValue={currentQ}
          onChange={(e) => handleSearch(e.target.value)}
          className="input-field pl-9 w-full"
        />
      </div>
      <select
        defaultValue={currentSemester}
        onChange={(e) => router.push(buildUrl({ semester: e.target.value }))}
        className="input-field text-sm py-2 pr-8 w-auto min-w-[160px]"
      >
        <option value="">Semua Semester</option>
        {[1, 2, 3, 4, 5, 6, 7, 8].map((s) => (
          <option key={s} value={s}>
            Semester {s}
          </option>
        ))}
      </select>
    </div>
  )
}
