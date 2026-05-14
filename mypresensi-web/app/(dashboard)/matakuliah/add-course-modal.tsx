'use client'
// app/(dashboard)/matakuliah/add-course-modal.tsx
// Modal untuk menambahkan mata kuliah baru dengan dropdown dosen.

import { useState } from 'react'
import { useFormState } from 'react-dom'
import { Plus, X, BookOpen } from 'lucide-react'
import { addCourseAction, CourseFormState } from '@/lib/actions/courses'
import { toast } from '@/lib/swal'

const initialState: CourseFormState = { error: null, success: false }

interface DosenInfo {
  id: string
  full_name: string
  nim_nip: string
}

export default function AddCourseModal({ dosenList, userRole = 'admin' }: { dosenList: DosenInfo[]; userRole?: string }) {
  const isAdmin = userRole === 'admin'
  const [open, setOpen] = useState(false)
  const [state, formAction] = useFormState(addCourseAction, initialState)

  if (state.success && open) {
    toast.fire({ icon: 'success', title: 'Mata kuliah berhasil ditambahkan' })
    setTimeout(() => {
      setOpen(false)
      state.success = false
    }, 300)
  }

  return (
    <>
      <button onClick={() => setOpen(true)} className="btn-primary flex items-center gap-2">
        <Plus size={16} /> Tambah Mata Kuliah
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div className="fixed inset-0 bg-black/40" onClick={() => setOpen(false)} />
          <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 p-6 z-[51]">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                  <BookOpen size={20} className="text-primary" />
                </div>
                <h3 className="text-lg font-semibold text-text-primary">Tambah Mata Kuliah</h3>
              </div>
              <button onClick={() => setOpen(false)} className="p-1 hover:bg-gray-100 rounded-lg">
                <X size={18} className="text-text-secondary" />
              </button>
            </div>

            {state.error && (
              <div className="mb-4 p-3 bg-danger/10 border border-danger/20 rounded-lg text-sm text-danger">
                {state.error}
              </div>
            )}

            <form action={formAction} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="form-label">Kode MK *</label>
                  <input name="code" className="input-field w-full" required placeholder="MK001" />
                  {state.fieldErrors?.code && <p className="text-xs text-red-500 mt-1">{state.fieldErrors.code[0]}</p>}
                </div>
                <div>
                  <label className="form-label">SKS *</label>
                  <input name="sks" type="number" min={1} max={6} defaultValue={3} className="input-field w-full" required />
                  {state.fieldErrors?.sks && <p className="text-xs text-red-500 mt-1">{state.fieldErrors.sks[0]}</p>}
                </div>
              </div>

              <div>
                <label className="form-label">Nama Mata Kuliah *</label>
                <input name="name" className="input-field w-full" required placeholder="Pemrograman Web Lanjut" />
                {state.fieldErrors?.name && <p className="text-xs text-red-500 mt-1">{state.fieldErrors.name[0]}</p>}
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="form-label">Semester *</label>
                  <select name="semester" className="input-field w-full" required>
                    {[1, 2, 3, 4, 5, 6, 7, 8].map((s) => (
                      <option key={s} value={s}>Semester {s}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="form-label">Tahun Akademik</label>
                  <input name="academic_year" className="input-field w-full" defaultValue="2025/2026" />
                </div>
              </div>

              {/* Dropdown Dosen Pengampu — hanya tampil untuk Admin */}
              {isAdmin && (
                <div>
                  <label className="form-label">Dosen Pengampu</label>
                  <select name="dosen_id" className="input-field w-full">
                    <option value="">— Belum ditentukan —</option>
                    {dosenList.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.full_name} ({d.nim_nip})
                      </option>
                    ))}
                  </select>
                </div>
              )}
              {/* Dosen: dosen_id otomatis di-set di server-side */}
              {!isAdmin && (
                <div className="p-3 bg-primary/10 border border-primary/20 rounded-lg text-sm text-primary">
                  Mata kuliah ini akan otomatis terdaftar sebagai MK yang Anda ampu.
                </div>
              )}

              <div className="flex gap-3 justify-end pt-2">
                <button type="button" onClick={() => setOpen(false)} className="px-4 py-2 text-sm border border-border rounded-lg hover:bg-gray-50 transition-colors">
                  Batal
                </button>
                <button type="submit" className="btn-primary">
                  Simpan
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  )
}
