'use client'
// app/(dashboard)/settings/settings-form.tsx
// Form untuk mengedit pengaturan sistem.

import { useState, useEffect } from 'react'
import { Save, Shield, MapPin, Clock, KeyRound, Scan } from 'lucide-react'
import { updateSettingsAction, SettingsFormState } from '@/lib/actions/settings'
import { toast } from '@/lib/swal'
import { getFriendlyErrorMessage } from '@/lib/utils'

const initialState: SettingsFormState = { error: null, success: false }

interface Setting {
  id: string
  key: string
  value: string
  description: string | null
}

// Icon dan label mapping untuk setiap setting
const settingMeta: Record<string, { icon: typeof Shield; label: string; unit: string; type: 'number' | 'text'; min?: number; max?: number; step?: number }> = {
  face_confidence_threshold: {
    icon: Scan,
    label: 'Batas Face Confidence',
    unit: '(0 - 1)',
    type: 'number',
    min: 0,
    max: 1,
    step: 0.01,
  },
  geofence_radius_meters: {
    icon: MapPin,
    label: 'Radius Geofencing',
    unit: 'meter',
    type: 'number',
    min: 10,
    max: 1000,
  },
  lockout_minutes: {
    icon: Clock,
    label: 'Durasi Lockout',
    unit: 'menit',
    type: 'number',
    min: 1,
    max: 120,
  },
  max_login_attempts: {
    icon: KeyRound,
    label: 'Maksimum Login Gagal',
    unit: 'kali percobaan',
    type: 'number',
    min: 1,
    max: 20,
  },

  late_threshold_minutes: {
    icon: Clock,
    label: 'Batas Keterlambatan',
    unit: 'menit',
    type: 'number',
    min: 0,
    max: 120,
  },
}

export default function SettingsForm({ settings }: { settings: Setting[] }) {
  const [state, setState] = useState<SettingsFormState>(initialState)
  const [pending, setPending] = useState(false)

  // Toast saat success
  useEffect(() => {
    if (state.success) {
      toast.fire({ icon: 'success', title: 'Pengaturan berhasil disimpan' })
      setState(initialState)
    }
  }, [state.success])

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setPending(true)
    const formData = new FormData(e.currentTarget)
    try {
      const res = await updateSettingsAction(state, formData)
      setState(res)
    } catch (err) {
      setState({
        error: getFriendlyErrorMessage(err, 'Gagal menyimpan pengaturan.'),
        success: false,
      })
    } finally {
      setPending(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {state.error && (
        <div className="p-3 bg-danger/10 border border-danger/20 rounded-lg text-sm text-danger">
          {state.error}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {settings.map((s) => {
          const meta = settingMeta[s.key]
          if (!meta) return null
          const Icon = meta.icon

          return (
            <div key={s.id} className="card p-5">
              <div className="flex items-start gap-3 mb-3">
                <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                  <Icon size={18} className="text-primary" />
                </div>
                <div className="flex-1 min-w-0">
                  <label htmlFor={s.key} className="text-sm font-semibold text-text-primary block">
                    {meta.label}
                  </label>
                  <p className="text-xs text-text-secondary mt-0.5">
                    {s.description}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <input
                  id={s.key}
                  name={`setting_${s.key}`}
                  type={meta.type}
                  step={meta.step}
                  min={meta.min}
                  max={meta.max}
                  defaultValue={s.value}
                  className="input-field flex-1"
                />
                <span className="text-xs text-text-secondary whitespace-nowrap">
                  {meta.unit}
                </span>
              </div>
            </div>
          )
        })}
      </div>

      <div className="flex justify-end pt-2">
        <button type="submit" className="btn-primary flex items-center gap-2" disabled={pending}>
          <Save size={16} /> {pending ? 'Menyimpan...' : 'Simpan Pengaturan'}
        </button>
      </div>
    </form>
  )
}
