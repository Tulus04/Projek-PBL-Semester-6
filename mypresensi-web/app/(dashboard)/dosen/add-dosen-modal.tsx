'use client'
// app/(dashboard)/dosen/add-dosen-modal.tsx
// Modal untuk menambah dosen baru dengan upload foto profil.

import { useState, useRef } from 'react'
import { Plus, X, UserPlus } from 'lucide-react'
import { addDosenAction, DosenFormState } from '@/lib/actions/dosen'
import AvatarUpload from '@/components/ui/avatar-upload'
import { toast } from '@/lib/swal'
import { getFriendlyErrorMessage } from '@/lib/utils'

const initialState: DosenFormState = { error: null, success: false }

export default function AddDosenModal() {
  const [open, setOpen] = useState(false)
  const [state, setState] = useState<DosenFormState>(initialState)
  const [pending, setPending] = useState(false)
  const [avatarBlob, setAvatarBlob] = useState<Blob | null>(null)
  const [nameValue, setNameValue] = useState('')
  const formRef = useRef<HTMLFormElement>(null)

  // Auto close on success
  if (state.success && open) {
    toast.fire({ icon: 'success', title: 'Dosen berhasil ditambahkan' })
    setTimeout(() => {
      setOpen(false)
      setState(initialState)
      setAvatarBlob(null)
      setNameValue('')
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
      const res = await addDosenAction(state, formData)
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
    <>
      <button onClick={() => setOpen(true)} className="btn-primary flex items-center gap-2">
        <Plus size={16} /> Tambah Dosen
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div className="fixed inset-0 bg-black/40" onClick={() => setOpen(false)} />
          <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 p-6 z-[51]">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                  <UserPlus size={20} className="text-primary" />
                </div>
                <h3 className="text-lg font-semibold text-text-primary">Tambah Dosen</h3>
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

            <form ref={formRef} onSubmit={handleSubmit} className="space-y-4">
              {/* Avatar Upload */}
              <div className="flex justify-center pb-2">
                <AvatarUpload
                  name={nameValue}
                  size={80}
                  onCropped={(blob) => setAvatarBlob(blob)}
                />
              </div>

              <div>
                <label className="form-label">Nama Lengkap *</label>
                <input
                  name="full_name"
                  className="input-field w-full"
                  required
                  placeholder="Dr. Ahmad Rizki, M.Kom"
                  value={nameValue}
                  onChange={(e) => setNameValue(e.target.value)}
                />
                {state.fieldErrors?.full_name && <p className="text-xs text-red-500 mt-1">{state.fieldErrors.full_name[0]}</p>}
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="form-label">NIP *</label>
                  <input name="nim_nip" className="input-field w-full" required placeholder="198501012010011001" />
                  {state.fieldErrors?.nim_nip && <p className="text-xs text-red-500 mt-1">{state.fieldErrors.nim_nip[0]}</p>}
                </div>
                <div>
                  <label className="form-label">No. HP</label>
                  <input name="phone" className="input-field w-full" placeholder="081234567890" />
                </div>
              </div>

              <div>
                <label className="form-label">Email *</label>
                <input name="email" type="email" className="input-field w-full" required placeholder="ahmad.rizki@Politani.ac.id" />
                {state.fieldErrors?.email && <p className="text-xs text-red-500 mt-1">{state.fieldErrors.email[0]}</p>}
              </div>

              <div className="bg-primary/10 rounded-lg p-3">
                <p className="text-xs text-gray-500 mt-2">
                  Password default: <strong>NIP@Politani</strong> — Dosen akan diminta ganti password saat login pertama.
                </p>
              </div>

              <div className="flex gap-3 justify-end pt-2">
                <button type="button" onClick={() => setOpen(false)} className="btn-secondary text-sm py-2.5 px-4" disabled={pending}>
                  Batal
                </button>
                <button type="submit" className="btn-primary" disabled={pending}>
                  {pending ? 'Menyimpan...' : 'Simpan'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  )
}
