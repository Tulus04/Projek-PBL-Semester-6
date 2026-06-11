'use client'
// app/(dashboard)/mahasiswa/add-student-modal.tsx
// Modal form untuk menambah mahasiswa baru dengan upload foto profil.

import { useRef, useState } from 'react'
import { useFormState, useFormStatus } from 'react-dom'
import { Plus, X } from 'lucide-react'
import { addStudentAction, StudentFormState } from '@/lib/actions/students'
import AvatarUpload from '@/components/ui/avatar-upload'
import { toast } from '@/lib/swal'

const initialState: StudentFormState = { error: null, success: false }

function SubmitButton() {
  const { pending } = useFormStatus()
  return (
    <button type="submit" className="btn-primary text-sm py-2.5 px-6" disabled={pending}>
      {pending ? 'Menyimpan...' : 'Simpan'}
    </button>
  )
}

export default function AddStudentModal() {
  const [isOpen, setIsOpen] = useState(false)
  const [state, formAction] = useFormState(addStudentAction, initialState)
  const [avatarBlob, setAvatarBlob] = useState<Blob | null>(null)
  const [nameValue, setNameValue] = useState('')
  const formRef = useRef<HTMLFormElement>(null)

  // Auto-close on success
  if (state.success && isOpen) {
    toast.fire({ icon: 'success', title: 'Mahasiswa berhasil ditambahkan' })
    setIsOpen(false)
    state.success = false
  }

  // Custom submit handler to append avatar blob
  const handleSubmit = (formData: FormData) => {
    if (avatarBlob) {
      formData.append('avatar', avatarBlob, 'avatar.jpg')
    }
    formAction(formData)
  }

  return (
    <>
      <button onClick={() => setIsOpen(true)} className="btn-primary text-sm py-2.5 px-4 flex items-center gap-2">
        <Plus size={16} /> Tambah Mahasiswa
      </button>

      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          {/* Backdrop */}
          <div className="absolute inset-0 bg-black/40" onClick={() => setIsOpen(false)} />

          {/* Modal */}
          <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            {/* Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-border">
              <h3 className="text-base font-bold font-heading text-text-primary">
                Tambah Mahasiswa Baru
              </h3>
              <button
                onClick={() => setIsOpen(false)}
                className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-gray-100"
              >
                <X size={18} />
              </button>
            </div>

            {/* Form */}
            <form ref={formRef} action={handleSubmit} className="p-6 flex flex-col gap-4">
              {state.error && (
                <div className="p-3 rounded-lg bg-danger/5 border border-danger/20 text-sm text-danger">
                  {state.error}
                </div>
              )}

              {/* Avatar Upload */}
              <div className="flex justify-center pb-2">
                <AvatarUpload
                  name={nameValue}
                  size={80}
                  onCropped={(blob) => setAvatarBlob(blob)}
                />
              </div>

              <div>
                <label htmlFor="add-full_name" className="form-label">Nama Lengkap *</label>
                <input
                  id="add-full_name"
                  name="full_name"
                  type="text"
                  className="input-field w-full"
                  placeholder="contoh: Ahmad Rizki"
                  required
                  value={nameValue}
                  onChange={(e) => setNameValue(e.target.value)}
                />
                {state.fieldErrors?.full_name && <p className="text-xs text-danger mt-1">{state.fieldErrors.full_name[0]}</p>}
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label htmlFor="add-nim_nip" className="form-label">NIM *</label>
                  <input id="add-nim_nip" name="nim_nip" type="text" className="input-field w-full" placeholder="contoh: P2100001" required />
                  {state.fieldErrors?.nim_nip && <p className="text-xs text-danger mt-1">{state.fieldErrors.nim_nip[0]}</p>}
                </div>
                <div>
                  <label htmlFor="add-email" className="form-label">Email *</label>
                  <input id="add-email" name="email" type="email" className="input-field w-full" placeholder="contoh@email.com" required />
                  {state.fieldErrors?.email && <p className="text-xs text-danger mt-1">{state.fieldErrors.email[0]}</p>}
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label htmlFor="add-semester" className="form-label">Semester</label>
                  <select id="add-semester" name="semester" className="input-field w-full">
                    <option value="">-</option>
                    {[1, 2, 3, 4, 5, 6, 7, 8].map((s) => (
                      <option key={s} value={s}>{s}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label htmlFor="add-kelas" className="form-label">Kelas</label>
                  <select id="add-kelas" name="kelas" className="input-field w-full">
                    <option value="">-</option>
                    {['A', 'B', 'C'].map((k) => (
                      <option key={k} value={k}>{k}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label htmlFor="add-phone" className="form-label">No. HP</label>
                  <input id="add-phone" name="phone" type="tel" className="input-field w-full" placeholder="08xxx" />
                </div>
              </div>

              <div className="p-3 rounded-lg bg-primary/5 border border-primary/15 text-xs text-text-secondary">
                <strong>Password default:</strong> NIM@politani (contoh: P2100001@politani).
                <br />Mahasiswa wajib ganti password saat login pertama.
              </div>

              {/* Actions */}
              <div className="flex items-center justify-end gap-2 pt-2">
                <button type="button" onClick={() => setIsOpen(false)} className="btn-secondary text-sm py-2.5 px-4">
                  Batal
                </button>
                <SubmitButton />
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  )
}
