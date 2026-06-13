'use client'
// app/(dashboard)/dosen/edit-dosen-modal.tsx
// Modal untuk mengedit data dosen dengan upload foto profil.

import { useState } from 'react'
import { X, Edit } from 'lucide-react'
import { updateDosenAction, DosenFormState } from '@/lib/actions/dosen'
import AvatarUpload from '@/components/ui/avatar-upload'
import { toast } from '@/lib/swal'
import { getFriendlyErrorMessage } from '@/lib/utils'

const initialState: DosenFormState = { error: null, success: false }

interface Dosen {
  id: string
  full_name: string
  nim_nip: string
  email: string | null
  phone: string | null
  avatar_url?: string | null
}

export default function EditDosenModal({
  dosen,
  onClose,
}: {
  dosen: Dosen
  onClose: () => void
}) {
  const [state, setState] = useState<DosenFormState>(initialState)
  const [pending, setPending] = useState(false)
  const [avatarBlob, setAvatarBlob] = useState<Blob | null>(null)
  const [nameValue, setNameValue] = useState(dosen.full_name)

  // Auto close on success
  if (state.success) {
    toast.fire({ icon: 'success', title: 'Data dosen berhasil diperbarui' })
    setTimeout(() => {
      onClose()
      setState(initialState)
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
      const res = await updateDosenAction(state, formData)
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
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="fixed inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 p-6 z-[51]">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
              <Edit size={20} className="text-primary" />
            </div>
            <h3 className="text-lg font-semibold text-text-primary">Edit Dosen</h3>
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

        <form onSubmit={handleSubmit} className="space-y-4">
          <input type="hidden" name="dosen_id" value={dosen.id} />

          {/* Avatar Upload */}
          <div className="flex justify-center pb-2">
            <AvatarUpload
              defaultImage={dosen.avatar_url}
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
              value={nameValue}
              onChange={(e) => setNameValue(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="form-label">NIP *</label>
              <input name="nim_nip" className="input-field w-full" required defaultValue={dosen.nim_nip} />
            </div>
            <div>
              <label className="form-label">No. HP</label>
              <input name="phone" className="input-field w-full" defaultValue={dosen.phone ?? ''} />
            </div>
          </div>

          <div>
            <label className="form-label">Email *</label>
            <input name="email" type="email" className="input-field w-full" required defaultValue={dosen.email ?? ''} />
          </div>

          <div className="flex gap-3 justify-end pt-2">
            <button type="button" onClick={onClose} className="btn-secondary text-sm py-2.5 px-4" disabled={pending}>
              Batal
            </button>
            <button type="submit" className="btn-primary" disabled={pending}>
              {pending ? 'Menyimpan...' : 'Simpan Perubahan'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
