'use client'
// app/(dashboard)/matakuliah/edit-course-modal.tsx
// Modal untuk mengedit data mata kuliah.

import { useFormState } from 'react-dom'
import { X, Edit } from 'lucide-react'
import { updateCourseAction, CourseFormState } from '@/lib/actions/courses'
import { toast } from '@/lib/swal'

const initialState: CourseFormState = { error: null, success: false }

interface DosenInfo {
  id: string
  full_name: string
  nim_nip: string
}

interface Course {
  id: string
  code: string
  name: string
  sks: number
  semester: number
  dosen_id: string | null
  academic_year: string
}

export default function EditCourseModal({
  course,
  dosenList,
  userRole = 'admin',
  onClose,
}: {
  course: Course
  dosenList: DosenInfo[]
  userRole?: string
  onClose: () => void
}) {
  const isAdmin = userRole === 'admin'
  const [state, formAction] = useFormState(updateCourseAction, initialState)

  if (state.success) {
    toast.fire({ icon: 'success', title: 'Mata kuliah berhasil diperbarui' })
    setTimeout(() => {
      onClose()
      state.success = false
    }, 300)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="fixed inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 p-6 z-[51]">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
              <Edit size={20} className="text-primary" />
            </div>
            <h3 className="text-lg font-semibold text-text-primary">Edit Mata Kuliah</h3>
          </div>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-lg">
            <X size={18} className="text-text-secondary" />
          </button>
        </div>

        {state.error && (
          <div className="mb-4 p-3 bg-danger/10 border border-danger/20 rounded-lg text-sm text-danger">
            {state.error}
          </div>
        )}

        <form action={formAction} className="space-y-4">
          <input type="hidden" name="course_id" value={course.id} />

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="form-label">Kode MK *</label>
              <input name="code" className="input-field w-full" required defaultValue={course.code} />
            </div>
            <div>
              <label className="form-label">SKS *</label>
              <input name="sks" type="number" min={1} max={6} className="input-field w-full" required defaultValue={course.sks} />
            </div>
          </div>

          <div>
            <label className="form-label">Nama Mata Kuliah *</label>
            <input name="name" className="input-field w-full" required defaultValue={course.name} />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="form-label">Semester *</label>
              <select name="semester" className="input-field w-full" required defaultValue={course.semester}>
                {[1, 2, 3, 4, 5, 6, 7, 8].map((s) => (
                  <option key={s} value={s}>Semester {s}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="form-label">Tahun Akademik</label>
              <input name="academic_year" className="input-field w-full" defaultValue={course.academic_year} />
            </div>
          </div>

          {/* Dropdown Dosen — hanya tampil untuk Admin */}
          {isAdmin && (
            <div>
              <label className="form-label">Dosen Pengampu</label>
              <select name="dosen_id" className="input-field w-full" defaultValue={course.dosen_id ?? ''}>
                <option value="">— Belum ditentukan —</option>
                {dosenList.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.full_name} ({d.nim_nip})
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="flex gap-3 justify-end pt-2">
            <button type="button" onClick={onClose} className="px-4 py-2 text-sm border border-border rounded-lg hover:bg-gray-50 transition-colors">
              Batal
            </button>
            <button type="submit" className="btn-primary">
              Simpan Perubahan
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
