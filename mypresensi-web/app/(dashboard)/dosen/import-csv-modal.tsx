'use client'
// app/(dashboard)/dosen/import-csv-modal.tsx
// Modal untuk import dosen via CSV.

import { useState } from 'react'
import { useFormState, useFormStatus } from 'react-dom'
import { Upload, X, FileSpreadsheet } from 'lucide-react'
import { importDosenCSVAction, DosenFormState } from '@/lib/actions/dosen'
import { swal } from '@/lib/swal'

const initialState: DosenFormState & { imported?: number; skipped?: number } = {
  error: null,
  success: false,
}

function SubmitButton() {
  const { pending } = useFormStatus()
  return (
    <button type="submit" className="btn-primary text-sm py-2.5 px-6" disabled={pending}>
      {pending ? 'Mengimpor...' : 'Import'}
    </button>
  )
}

export default function ImportCSVModal() {
  const [isOpen, setIsOpen] = useState(false)
  const [csvText, setCsvText] = useState('')
  const [state, formAction] = useFormState(importDosenCSVAction, initialState)

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (event) => {
      setCsvText((event.target?.result as string) || '')
    }
    reader.readAsText(file)
  }

  return (
    <>
      <button
        onClick={() => setIsOpen(true)}
        className="btn-secondary text-sm py-2.5 px-4 flex items-center gap-2"
      >
        <Upload size={16} /> Import CSV
      </button>

      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/40" onClick={() => setIsOpen(false)} />

          <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between px-6 py-4 border-b border-border">
              <h3 className="text-base font-bold font-heading text-text-primary flex items-center gap-2">
                <FileSpreadsheet size={18} /> Import Dosen dari CSV
              </h3>
              <button onClick={() => setIsOpen(false)} className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-gray-100">
                <X size={18} />
              </button>
            </div>

            <form action={formAction} className="p-6 flex flex-col gap-4">
              {state.error && (
                <div className="p-3 rounded-lg bg-danger/5 border border-danger/20 text-sm text-danger">
                  {state.error}
                </div>
              )}

              {state.success && (
                (() => {
                  swal.fire({
                    icon: 'success',
                    title: 'Import Berhasil!',
                    text: `${state.imported ?? 0} dosen berhasil diimport.${state.skipped ? ` ${state.skipped} dilewati.` : ''}`,
                  })
                  state.success = false
                  return null
                })()
              )}

              {/* Format info */}
              <div className="p-3 rounded-lg bg-primary/5 border border-primary/15 text-xs text-text-secondary">
                <strong>Format CSV:</strong>
                <code className="block mt-1 font-mono text-text-primary">
                  Nama,NIP,Email,NoHP
                </code>
                <p className="mt-1">
                  Kolom NoHP bersifat opsional. Password default: NIP@Politani
                </p>
              </div>

              {/* Upload file */}
              <div>
                <label className="form-label">Upload File CSV</label>
                <input
                  type="file"
                  accept=".csv,.txt"
                  onChange={handleFileUpload}
                  className="block w-full text-sm text-text-secondary
                    file:mr-4 file:py-2 file:px-4
                    file:rounded-lg file:border-0
                    file:text-sm file:font-semibold
                    file:bg-primary/10 file:text-primary
                    hover:file:bg-primary/20 file:cursor-pointer
                    file:transition-colors"
                />
              </div>

              {/* Atau paste manual */}
              <div>
                <label htmlFor="csv-textarea" className="form-label">
                  Atau paste data CSV di sini
                </label>
                <textarea
                  id="csv-textarea"
                  name="csv_data"
                  rows={8}
                  value={csvText}
                  onChange={(e) => setCsvText(e.target.value)}
                  className="input-field w-full font-mono text-xs"
                  placeholder={`Nama,NIP,Email,NoHP\nAhmad Rizki,198001012005011001,ahmad.r@politani.ac.id,081234567890\nSiti Nurhaliza,198502022010012002,siti.n@politani.ac.id,`}
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button type="button" onClick={() => setIsOpen(false)} className="btn-secondary text-sm py-2.5 px-4">
                  Tutup
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
