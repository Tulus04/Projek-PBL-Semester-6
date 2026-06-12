'use client'
// app/(dashboard)/rekap/rekap-filters.tsx
// Filter untuk rekap presensi — pilih MK / dosen.

import { useRouter } from 'next/navigation'
import { useState } from 'react'
import { Search, RotateCcw } from 'lucide-react'

interface CourseOption {
  id: string
  code: string
  name: string
}

interface Props {
  courses: CourseOption[]
  dosenList: { id: string; full_name: string }[]
  currentCourseId?: string
  currentDosenId?: string
  showDosenFilter?: boolean
}

export default function RekapFilters({ courses, dosenList, currentCourseId, currentDosenId, showDosenFilter = true }: Props) {
  const router = useRouter()
  const [courseId, setCourseId] = useState(currentCourseId || '')
  const [dosenId, setDosenId] = useState(currentDosenId || '')

  const handleFilter = () => {
    const params = new URLSearchParams()
    if (courseId) params.set('course_id', courseId)
    if (dosenId) params.set('dosen_id', dosenId)
    router.push(`/rekap?${params.toString()}`)
  }

  const handleReset = () => {
    setCourseId('')
    setDosenId('')
    router.push('/rekap')
  }

  return (
    <div className="card p-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-1 min-w-[200px]">
          <label className="form-label">Mata Kuliah</label>
          <select
            value={courseId}
            onChange={(e) => setCourseId(e.target.value)}
            className="input-field w-full"
          >
            <option value="">Semua Mata Kuliah</option>
            {courses.map((c) => (
              <option key={c.id} value={c.id}>
                {c.code} — {c.name}
              </option>
            ))}
          </select>
        </div>
        {/* Dropdown Dosen — hanya tampil untuk Admin */}
        {showDosenFilter && (
          <div className="flex-1 min-w-[200px]">
            <label className="form-label">Dosen Pengampu</label>
            <select
              value={dosenId}
              onChange={(e) => setDosenId(e.target.value)}
              className="input-field w-full"
            >
              <option value="">Semua Dosen</option>
              {dosenList.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.full_name}
                </option>
              ))}
            </select>
          </div>
        )}
        <button onClick={handleFilter} className="btn-primary flex items-center gap-2">
          <Search size={14} /> Filter
        </button>
        {(courseId || dosenId) && (
          <button
            onClick={handleReset}
            className="px-3 py-2.5 text-sm border border-border rounded-lg hover:bg-gray-50 transition-colors flex items-center gap-1.5"
          >
            <RotateCcw size={14} /> Reset
          </button>
        )}
      </div>
    </div>
  )
}
