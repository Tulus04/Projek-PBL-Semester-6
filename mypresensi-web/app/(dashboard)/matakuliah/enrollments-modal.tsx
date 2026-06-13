'use client'
// app/(dashboard)/matakuliah/enrollments-modal.tsx
// Modal untuk mengelola peserta (mahasiswa) per mata kuliah.

import { useEffect, useState, useCallback } from 'react'
import { X, UserPlus, Trash2, Search, Users } from 'lucide-react'
import { getEnrollmentsByCourse, getAvailableStudents, addEnrollmentAction, removeEnrollmentAction } from '@/lib/actions/enrollments'
import { swal, toast } from '@/lib/swal'
import { getFriendlyErrorMessage } from '@/lib/utils'

interface Props {
  courseId: string
  courseName: string
  onClose: () => void
}

interface Enrollment {
  id: string
  academic_year: string
  student: { id: string; full_name: string; nim_nip: string; kelas: string | null; semester: number | null } | null
}

interface Student {
  id: string
  full_name: string
  nim_nip: string
  kelas: string | null
  semester: number | null
}

export default function EnrollmentsModal({ courseId, courseName, onClose }: Props) {
  const [enrollments, setEnrollments] = useState<Enrollment[]>([])
  const [available, setAvailable] = useState<Student[]>([])
  const [loading, setLoading] = useState(true)
  const [adding, setAdding] = useState(false)
  const [showAddPanel, setShowAddPanel] = useState(false)
  const [selectedIds, setSelectedIds] = useState<string[]>([])
  const [searchAdd, setSearchAdd] = useState('')
  const [selectedKelasFilter, setSelectedKelasFilter] = useState('')

  const loadData = useCallback(async () => {
    setLoading(true)
    try {
      const [enrollData, availData] = await Promise.all([
        getEnrollmentsByCourse(courseId),
        getAvailableStudents(courseId),
      ])
      const mapped = (enrollData.enrollments ?? []).map((e: { id: string; academic_year: string; student: unknown }) => ({
        ...e,
        student: Array.isArray(e.student) ? e.student[0] ?? null : e.student,
      }))
      setEnrollments(mapped as Enrollment[])
      setAvailable(availData.students as Student[])
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal Memuat',
        text: getFriendlyErrorMessage(err, 'Gagal memuat data peserta.'),
      })
    } finally {
      setLoading(false)
    }
  }, [courseId])

  useEffect(() => { loadData() }, [loadData])

  const handleAdd = async () => {
    if (selectedIds.length === 0) return
    setAdding(true)
    try {
      const result = await addEnrollmentAction(courseId, selectedIds)
      if (result.success) {
        toast.fire({ icon: 'success', title: `${selectedIds.length} mahasiswa ditambahkan` })
        setSelectedIds([])
        setShowAddPanel(false)
        loadData()
      } else {
        swal.fire({ icon: 'error', title: 'Gagal', text: result.error ?? '' })
      }
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal',
        text: getFriendlyErrorMessage(err, 'Gagal menambahkan peserta.'),
      })
    } finally {
      setAdding(false)
    }
  }

  const handleRemove = async (enrollment: Enrollment) => {
    const result = await swal.fire({
      title: 'Hapus Peserta',
      html: `<b>${enrollment.student?.full_name}</b> akan dihapus dari mata kuliah ini.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Hapus',
      cancelButtonText: 'Batal',
    })
    if (!result.isConfirmed) return

    try {
      const res = await removeEnrollmentAction(enrollment.id, courseId)
      if (res.success) {
        toast.fire({ icon: 'success', title: 'Peserta dihapus' })
        loadData()
      } else {
        swal.fire({ icon: 'error', title: 'Gagal', text: res.error ?? '' })
      }
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal',
        text: getFriendlyErrorMessage(err, 'Gagal menghapus peserta.'),
      })
    }
  }

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => prev.includes(id) ? prev.filter((i) => i !== id) : [...prev, id])
  }

  const selectAll = () => {
    const filtered = filteredAvailable.map(s => s.id)
    setSelectedIds((prev) => {
      const allSelected = filtered.every(id => prev.includes(id))
      if (allSelected) return prev.filter(id => !filtered.includes(id))
      const merged = [...prev]
      filtered.forEach(id => { if (!merged.includes(id)) merged.push(id) })
      return merged
    })
  }

  const uniqueAvailableClasses = Array.from(new Set(available.map(s => s.kelas).filter(Boolean))).sort() as string[]

  const filteredAvailable = available.filter(
    (s) => {
      const matchSearch = !searchAdd || s.full_name.toLowerCase().includes(searchAdd.toLowerCase()) || s.nim_nip.toLowerCase().includes(searchAdd.toLowerCase())
      const matchKelas = !selectedKelasFilter || s.kelas === selectedKelasFilter
      return matchSearch && matchKelas
    }
  )

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[85vh] flex flex-col" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="px-6 py-4 border-b border-border flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center">
              <Users size={18} className="text-primary" />
            </div>
            <div>
              <h3 className="text-base font-bold text-text-primary">Kelola Peserta</h3>
              <p className="text-xs text-text-secondary">{courseName}</p>
            </div>
          </div>
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors">
            <X size={18} className="text-text-secondary" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
            </div>
          ) : (
            <>
              {/* Current Enrollments */}
              <div className="flex items-center justify-between mb-3">
                <h4 className="text-sm font-semibold text-text-primary">
                  Mahasiswa Terdaftar ({enrollments.length})
                </h4>
                <button
                  onClick={() => setShowAddPanel(!showAddPanel)}
                  className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5"
                >
                  <UserPlus size={14} /> Tambah Peserta
                </button>
              </div>

              {enrollments.length === 0 ? (
                <p className="text-sm text-text-secondary italic py-4 text-center">
                  Belum ada mahasiswa terdaftar.
                </p>
              ) : (
                <div className="border border-border rounded-lg overflow-hidden mb-4">
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50 border-b border-border">
                      <tr>
                        <th className="text-left px-4 py-2.5 text-xs font-semibold text-text-secondary uppercase">NIM</th>
                        <th className="text-left px-4 py-2.5 text-xs font-semibold text-text-secondary uppercase">Nama</th>
                        <th className="text-left px-4 py-2.5 text-xs font-semibold text-text-secondary uppercase">Kelas</th>
                        <th className="w-10"></th>
                      </tr>
                    </thead>
                    <tbody>
                      {enrollments.map((e) => (
                        <tr key={e.id} className="border-b border-border last:border-0 hover:bg-gray-50">
                          <td className="px-4 py-2.5 font-mono text-primary font-semibold">{e.student?.nim_nip}</td>
                          <td className="px-4 py-2.5 text-text-primary">{e.student?.full_name}</td>
                          <td className="px-4 py-2.5 text-text-secondary">{e.student?.kelas ? `${e.student?.semester ?? ''}${e.student.kelas}` : '-'}</td>
                          <td className="px-2">
                            <button
                              onClick={() => handleRemove(e)}
                              className="p-1.5 hover:bg-danger/10 rounded-lg transition-colors"
                              title="Hapus peserta"
                              aria-label="Hapus peserta dari mata kuliah"
                            >
                              <Trash2 size={14} className="text-danger" />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              {/* Add Panel */}
              {showAddPanel && (
                <div className="border border-primary/20 bg-primary/5 rounded-lg p-4 mt-4">
                  <h4 className="text-sm font-semibold text-text-primary mb-3">Tambah Mahasiswa</h4>

                  <div className="flex gap-3 mb-3">
                    <div className="relative flex-1">
                      <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary" />
                      <input
                        type="text"
                        placeholder="Cari NIM atau nama..."
                        value={searchAdd}
                        onChange={(e) => setSearchAdd(e.target.value)}
                        className="input-field w-full pl-9 text-sm"
                      />
                    </div>
                    <select
                      value={selectedKelasFilter}
                      onChange={(e) => setSelectedKelasFilter(e.target.value)}
                      className="input-field text-sm w-[140px] shrink-0"
                    >
                      <option value="">Semua Kelas</option>
                      {uniqueAvailableClasses.map(k => (
                        <option key={k} value={k}>Kelas {k}</option>
                      ))}
                    </select>
                  </div>

                  {filteredAvailable.length === 0 ? (
                    <p className="text-xs text-text-secondary italic py-2">Semua mahasiswa sudah terdaftar.</p>
                  ) : (
                    <>
                      <div className="flex items-center justify-between mb-2">
                        <button onClick={selectAll} className="text-xs text-primary font-medium hover:underline">
                          {filteredAvailable.every(s => selectedIds.includes(s.id)) ? 'Batal Pilih Semua' : 'Pilih Semua'}
                        </button>
                        <span className="text-xs text-text-secondary">{selectedIds.length} dipilih</span>
                      </div>
                      <div className="max-h-48 overflow-y-auto border border-border rounded-lg bg-white">
                        {filteredAvailable.map((s) => (
                          <label
                            key={s.id}
                            className="flex items-center gap-3 px-3 py-2 hover:bg-gray-50 cursor-pointer border-b border-border last:border-0"
                          >
                            <input
                              type="checkbox"
                              checked={selectedIds.includes(s.id)}
                              onChange={() => toggleSelect(s.id)}
                              className="w-4 h-4 rounded border-gray-300 text-primary accent-primary"
                            />
                            <span className="font-mono text-xs text-primary font-semibold">{s.nim_nip}</span>
                            <span className="text-sm text-text-primary flex-1">{s.full_name}</span>
                            <span className="text-xs text-text-secondary">{s.kelas ? `${s.semester ?? ''}${s.kelas}` : ''}</span>
                          </label>
                        ))}
                      </div>
                    </>
                  )}

                  {selectedIds.length > 0 && (
                    <button
                      onClick={handleAdd}
                      disabled={adding}
                      className="btn-primary w-full mt-3 text-sm flex items-center justify-center gap-2"
                    >
                      {adding ? (
                        <>
                          <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                          Menambahkan...
                        </>
                      ) : (
                        <>
                          <UserPlus size={14} /> Tambahkan {selectedIds.length} Mahasiswa
                        </>
                      )}
                    </button>
                  )}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  )
}
