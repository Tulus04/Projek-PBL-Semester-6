'use client'
// app/(dashboard)/mahasiswa/edit-student-modal.tsx
// Modal form edit data mahasiswa dengan upload foto profil.

import { useState } from 'react'
import { X, Edit } from 'lucide-react'
import { updateStudentAction, StudentFormState } from '@/lib/actions/students'
import AvatarUpload from '@/components/ui/avatar-upload'
import { toast } from '@/lib/swal'
import { getFriendlyErrorMessage } from '@/lib/utils'

const initialState: StudentFormState = { error: null, success: false }

interface Props {
  student: {
    id: string
    full_name: string
    nim_nip: string
    email: string | null
    semester: number | null
    kelas: string | null
    phone: string | null
    avatar_url?: string | null
  }
  onClose: () => void
}

export default function EditStudentModal({ student, onClose }: Props) {
  const [state, setState] = useState<StudentFormState>(initialState)
  const [pending, setPending] = useState(false)
  const [avatarBlob, setAvatarBlob] = useState<Blob | null>(null)
  const [nameValue, setNameValue] = useState(student.full_name)

  if (state.success) {
    toast.fire({ icon: 'success', title: 'Data mahasiswa berhasil diperbarui' })
    setTimeout(() => {
      onClose()
      state.success = false
    }, 300)
  }

  // Custom submit handler to append avatar blob and handle network errors
  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setPending(true)
    const formData = new FormData(e.currentTarget)
    if (avatarBlob) {
      formData.append('avatar', avatarBlob, 'avatar.jpg')
    }
    try {
      const res = await updateStudentAction(state, formData)
      setState(res)
    } catch (err) {
      setState({
        error: getFriendlyErrorMessage(err, 'Gagal menghubungkan ke server.'),
        success: false,
      })
    } finally {
      setPending(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />

      <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-4 border-b border-border">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
              <Edit size={20} className="text-primary" />
            </div>
            <h3 className="text-base font-bold font-heading text-text-primary">
              Edit Mahasiswa
            </h3>
          </div>
          <button onClick={onClose} className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-gray-100">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 flex flex-col gap-4">
          <input type="hidden" name="student_id" value={student.id} />

          {state.error && (
            <div className="p-3 rounded-lg bg-danger/5 border border-danger/20 text-sm text-danger">
              {state.error}
            </div>
          )}

          {/* Avatar Upload */}
          <div className="flex justify-center pb-2">
            <AvatarUpload
              defaultImage={student.avatar_url}
              name={nameValue}
              size={80}
              onCropped={(blob) => setAvatarBlob(blob)}
            />
          </div>

          <div>
            <label htmlFor="edit-full_name" className="form-label">Nama Lengkap *</label>
            <input
              id="edit-full_name"
              name="full_name"
              type="text"
              className="input-field w-full"
              required
              value={nameValue}
              onChange={(e) => setNameValue(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label htmlFor="edit-nim_nip" className="form-label">NIM *</label>
              <input id="edit-nim_nip" name="nim_nip" type="text" defaultValue={student.nim_nip} className="input-field w-full" required />
            </div>
            <div>
              <label htmlFor="edit-email" className="form-label">Email *</label>
              <input id="edit-email" name="email" type="email" defaultValue={student.email ?? ''} className="input-field w-full" required />
            </div>
          </div>

          <div className="grid grid-cols-3 gap-4">
            <div>
              <label htmlFor="edit-semester" className="form-label">Semester</label>
              <select id="edit-semester" name="semester" defaultValue={student.semester ?? ''} className="input-field w-full">
                <option value="">-</option>
                {[1, 2, 3, 4, 5, 6, 7, 8].map((s) => (
                  <option key={s} value={s}>{s}</option>
                ))}
              </select>
            </div>
            <div>
              <label htmlFor="edit-kelas" className="form-label">Kelas</label>
              <select id="edit-kelas" name="kelas" defaultValue={student.kelas ?? ''} className="input-field w-full">
                <option value="">-</option>
                {['A', 'B', 'C'].map((k) => (
                  <option key={k} value={k}>{k}</option>
                ))}
              </select>
            </div>
            <div>
              <label htmlFor="edit-phone" className="form-label">No. HP</label>
              <input id="edit-phone" name="phone" type="tel" defaultValue={student.phone ?? ''} className="input-field w-full" />
            </div>
          </div>

          <div className="flex items-center justify-end gap-2 pt-2">
            <button type="button" onClick={onClose} className="btn-secondary text-sm py-2.5 px-4">
              Batal
            </button>
            <button type="submit" className="btn-primary text-sm py-2.5 px-6" disabled={pending}>
              {pending ? 'Menyimpan...' : 'Simpan Perubahan'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
