'use client'
// app/(auth)/change-password/change-password-form.tsx
// Form ganti password — client component dengan useFormState.

import { useFormState, useFormStatus } from 'react-dom'
import { changePasswordAction, ChangePasswordState } from '@/lib/actions/auth'
import { useState } from 'react'
import { Eye, EyeOff, Lock, ShieldCheck } from 'lucide-react'

const initialState: ChangePasswordState = {
  error: null,
  success: false,
}

function SubmitButton() {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="btn-primary w-full py-3 flex items-center justify-center gap-2"
    >
      {pending ? (
        <>
          <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          Menyimpan...
        </>
      ) : (
        <>
          <ShieldCheck size={16} strokeWidth={2} />
          Simpan Password Baru
        </>
      )}
    </button>
  )
}

export default function ChangePasswordForm() {
  const [state, formAction] = useFormState(changePasswordAction, initialState)
  const [showNew, setShowNew] = useState(false)
  const [showConfirm, setShowConfirm] = useState(false)
  const [password, setPassword] = useState('')

  // Real-time password strength indicators
  const hasMinLength = password.length >= 8
  const hasUppercase = /[A-Z]/.test(password)
  const hasNumber = /[0-9]/.test(password)

  return (
    <form action={formAction} className="space-y-5">
      {/* Error Alert */}
      {state.error && (
        <div className="bg-danger-subtle border border-danger/20 rounded-xl px-4 py-3">
          <p className="text-sm text-danger font-medium">{state.error}</p>
        </div>
      )}

      {/* New Password */}
      <div>
        <label htmlFor="newPassword" className="form-label">
          Password Baru *
        </label>
        <div className="relative">
          <Lock
            size={16}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary"
          />
          <input
            id="newPassword"
            name="newPassword"
            type={showNew ? 'text' : 'password'}
            required
            placeholder="Masukkan password baru"
            className="input-field pl-9 pr-10 w-full"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <button
            type="button"
            onClick={() => setShowNew(!showNew)}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary transition-colors"
            tabIndex={-1}
          >
            {showNew ? <EyeOff size={16} /> : <Eye size={16} />}
          </button>
        </div>
        {state.fieldErrors?.newPassword && (
          <p className="text-xs text-danger mt-1">{state.fieldErrors.newPassword[0]}</p>
        )}

        {/* Password Strength Indicators */}
        {password.length > 0 && (
          <div className="mt-3 space-y-1.5">
            <StrengthItem valid={hasMinLength} label="Minimal 8 karakter" />
            <StrengthItem valid={hasUppercase} label="Mengandung huruf kapital (A-Z)" />
            <StrengthItem valid={hasNumber} label="Mengandung angka (0-9)" />
          </div>
        )}
      </div>

      {/* Confirm Password */}
      <div>
        <label htmlFor="confirmPassword" className="form-label">
          Konfirmasi Password *
        </label>
        <div className="relative">
          <Lock
            size={16}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-text-secondary"
          />
          <input
            id="confirmPassword"
            name="confirmPassword"
            type={showConfirm ? 'text' : 'password'}
            required
            placeholder="Ketik ulang password baru"
            className="input-field pl-9 pr-10 w-full"
          />
          <button
            type="button"
            onClick={() => setShowConfirm(!showConfirm)}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary transition-colors"
            tabIndex={-1}
          >
            {showConfirm ? <EyeOff size={16} /> : <Eye size={16} />}
          </button>
        </div>
        {state.fieldErrors?.confirmPassword && (
          <p className="text-xs text-danger mt-1">{state.fieldErrors.confirmPassword[0]}</p>
        )}
      </div>

      {/* Submit */}
      <SubmitButton />
    </form>
  )
}

// Sub-component: Password Strength Indicator
function StrengthItem({ valid, label }: { valid: boolean; label: string }) {
  return (
    <div className="flex items-center gap-2">
      <div
        className={`w-4 h-4 rounded-full flex items-center justify-center text-white text-[10px] transition-colors ${
          valid ? 'bg-success' : 'bg-text-disabled'
        }`}
      >
        {valid ? '✓' : ''}
      </div>
      <span
        className={`text-xs transition-colors ${
          valid ? 'text-success font-medium' : 'text-text-secondary'
        }`}
      >
        {label}
      </span>
    </div>
  )
}
