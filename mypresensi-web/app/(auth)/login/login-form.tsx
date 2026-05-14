'use client'
// app/(auth)/login/login-form.tsx
// Client Component — hanya untuk interaktivitas form.
// Logika auth ada di Server Action (auth.ts), bukan di sini.
// Menggunakan useFormState/useFormStatus (React 18 + Next.js 14 compatible)

import { useFormState, useFormStatus } from 'react-dom'
import { Eye, EyeOff } from 'lucide-react'
import { useState } from 'react'
import { loginAction, type LoginState } from '@/lib/actions/auth'

const initialState: LoginState = { error: null }

// Submit button terpisah supaya bisa pakai useFormStatus
function SubmitButton() {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      className="btn-primary w-full mt-2"
      disabled={pending}
    >
      {pending ? 'Memproses...' : 'Masuk'}
    </button>
  )
}

export default function LoginForm() {
  const [state, formAction] = useFormState(loginAction, initialState)
  const [showPassword, setShowPassword] = useState(false)

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
          placeholder="contoh@email.com"
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
            aria-describedby={state.fieldErrors?.password ? 'password-error' : undefined}
          />
          <button
            type="button"
            onClick={() => setShowPassword(!showPassword)}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary transition-colors"
            aria-label={showPassword ? 'Sembunyikan password' : 'Tampilkan password'}
          >
            {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
          </button>
        </div>
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
