'use client'
// app/(dashboard)/sesi/session-filters.tsx
// Filter bar untuk halaman Sesi Absensi.
// Auto-apply on change — tidak perlu klik tombol "Filter".

import { useRouter } from 'next/navigation'
import { useState, useCallback, useEffect } from 'react'
import { RotateCcw, Filter } from 'lucide-react'

interface CourseOption {
  id: string
  code: string
  name: string
}

interface Props {
  courses: CourseOption[]
  currentCourseId?: string
  currentStatus?: string
  currentKelas?: string
}

export default function SessionFilters({
  courses,
  currentCourseId,
  currentStatus,
  currentKelas,
}: Props) {
  const router = useRouter()
  const [courseId, setCourseId] = useState(currentCourseId || '')
  const [status, setStatus] = useState(currentStatus || '')
  const [kelas, setKelas] = useState(currentKelas || '')

  // Debounced auto-apply
  const applyFilter = useCallback(
    (newCourseId: string, newStatus: string, newKelas: string) => {
      const params = new URLSearchParams()
      if (newCourseId) params.set('course_id', newCourseId)
      if (newStatus) params.set('status', newStatus)
      if (newKelas) params.set('kelas', newKelas)
      const qs = params.toString()
      router.push(qs ? `/sesi?${qs}` : '/sesi')
    },
    [router]
  )

  const handleCourseChange = (value: string) => {
    setCourseId(value)
    applyFilter(value, status, kelas)
  }

  const handleStatusChange = (value: string) => {
    setStatus(value)
    applyFilter(courseId, value, kelas)
  }

  const handleKelasChange = (value: string) => {
    setKelas(value)
    applyFilter(courseId, status, value)
  }

  const handleReset = () => {
    setCourseId('')
    setStatus('')
    setKelas('')
    router.push('/sesi')
  }

  // Sync state from URL params (jika user navigate langsung via URL)
  useEffect(() => {
    setCourseId(currentCourseId || '')
    setStatus(currentStatus || '')
    setKelas(currentKelas || '')
  }, [currentCourseId, currentStatus, currentKelas])

  const hasFilter = courseId || status || kelas

  return (
    <div className="card p-4">
      <div className="flex flex-wrap items-end gap-3">
        {/* Label */}
        <div className="flex items-center gap-2 mr-1 self-center">
          <Filter size={14} className="text-text-secondary" />
          <span className="text-xs font-medium text-text-secondary uppercase tracking-wide">Filter</span>
        </div>

        {/* Filter MK */}
        <div className="flex-1 min-w-[200px]">
          <label className="form-label">Mata Kuliah</label>
          <select
            value={courseId}
            onChange={(e) => handleCourseChange(e.target.value)}
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

        {/* Filter Status */}
        <div className="flex-1 min-w-[180px]">
          <label className="form-label">Status Sesi</label>
          <select
            value={status}
            onChange={(e) => handleStatusChange(e.target.value)}
            className="input-field w-full"
          >
            <option value="">Semua Status</option>
            <option value="active">Sedang Berlangsung</option>
            <option value="ended">Sudah Selesai</option>
            <option value="pending">Belum Dimulai</option>
          </select>
        </div>

        {/* Filter Kelas */}
        <div className="flex-1 min-w-[120px]">
          <label className="form-label">Target Kelas</label>
          <select
            value={kelas}
            onChange={(e) => handleKelasChange(e.target.value)}
            className="input-field w-full"
          >
            <option value="">Semua Filter</option>
            <option value="Semua">Khusus "Semua Kelas"</option>
            <option value="A">Kelas A</option>
            <option value="B">Kelas B</option>
            <option value="C">Kelas C</option>
          </select>
        </div>

        {/* Reset Button */}
        {hasFilter && (
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
