'use client'
// app/(auth)/login/login-form.tsx
// Client Component — hanya untuk interaktivitas form.
// Logika auth ada di Server Action (auth.ts), bukan di sini.
// Menggunakan useFormState/useFormStatus (React 18 + Next.js 14 compatible)

import { useFormState, useFormStatus } from 'react-dom'
import { Eye, EyeOff, Loader2, AlertTriangle } from 'lucide-react'
import { useState } from 'react'
import { loginAction, type LoginState } from '@/lib/actions/auth'

const initialState: LoginState = { error: null }

// Submit button terpisah supaya bisa pakai useFormStatus.
// Variant A loading: spinner Lucide loader-2 di kiri teks "Masuk" — teks TIDAK berubah.
function SubmitButton() {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      className="btn-primary w-full mt-2 inline-flex items-center justify-center gap-2"
      disabled={pending}
      aria-busy={pending}
    >
      {pending && <Loader2 size={16} className="animate-spin" aria-hidden="true" />}
      <span>Masuk</span>
    </button>
  )
}

export default function LoginForm() {
  const [state, formAction] = useFormState(loginAction, initialState)
  const [showPassword, setShowPassword] = useState(false)
  const [capsLockOn, setCapsLockOn] = useState(false)

  // CapsLock detector — bantu user yang lagi ketik password biar nggak salah berkali-kali.
  // Pattern Stripe/GitHub: warning kuning muncul di bawah field password saat aktif.
  const handleCapsLockCheck = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (typeof e.getModifierState === 'function') {
      setCapsLockOn(e.getModifierState('CapsLock'))
    }
  }

  return (
    <form action={formAction} className="flex flex-col gap-4">

      {/* Error global */}
      {state.error && (
        <div
          className="bg-danger/10 border border-danger/20 text-danger rounded-lg p-3 text-sm"
          role="alert"
        >
          {state.error}
        </div>
      )}

      {/* Email */}
      <div>
        <label htmlFor="email" className="form-label">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          autoFocus
          placeholder="nama@politanisamarinda.ac.id"
          className="input-field"
          aria-describedby={state.fieldErrors?.email ? 'email-error' : undefined}
        />
        {state.fieldErrors?.email && (
          <p id="email-error" className="text-xs text-danger mt-1">
            {state.fieldErrors.email[0]}
          </p>
        )}
      </div>

      {/* Password */}
      <div>
        <label htmlFor="password" className="form-label">
          Password
        </label>
        <div className="relative">
          <input
            id="password"
            name="password"
            type={showPassword ? 'text' : 'password'}
            autoComplete="current-password"
            placeholder="Masukkan password"
            className="input-field pr-10"
            onKeyDown={handleCapsLockCheck}
            onKeyUp={handleCapsLockCheck}
            aria-describedby={
              state.fieldErrors?.password
                ? 'password-error'
                : capsLockOn
                  ? 'password-capslock'
                  : undefined
            }
          />
          <button
            type="button"
            onClick={() => setShowPassword(!showPassword)}
            tabIndex={-1}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary transition-colors"
            aria-label={showPassword ? 'Sembunyikan password' : 'Tampilkan password'}
          >
            {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
          </button>
        </div>
        {capsLockOn && !state.fieldErrors?.password && (
          <p
            id="password-capslock"
            className="flex items-center gap-1.5 text-xs text-warning mt-1.5 font-medium"
            role="status"
          >
            <AlertTriangle size={12} aria-hidden="true" />
            CapsLock aktif — pastikan password sudah benar.
          </p>
        )}
        {state.fieldErrors?.password && (
          <p id="password-error" className="text-xs text-danger mt-1">
            {state.fieldErrors.password[0]}
          </p>
        )}
      </div>

      <SubmitButton />
    </form>
  )
}
