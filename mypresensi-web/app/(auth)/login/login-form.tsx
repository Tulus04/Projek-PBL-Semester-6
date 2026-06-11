'use client'
// app/(auth)/login/login-form.tsx
// Client Component — hanya untuk interaktivitas form.
// Logika auth ada di Server Action (auth.ts), bukan di sini.
// Menggunakan useFormState/useFormStatus (React 18 + Next.js 14 compatible)

import { useFormState, useFormStatus } from 'react-dom'
import { Eye, EyeOff, Loader2, AlertTriangle, Bug } from 'lucide-react'
import { useRef, useState } from 'react'
import { loginAction, type LoginState } from '@/lib/actions/auth'

const initialState: LoginState = { error: null }

// DEV ONLY — daftar akun test untuk quick login.
// Hilang dari bundle production via tree-shaking + flag NODE_ENV.
// Akun yang dipakai = sama dengan `mypresensi-web/.dev-accounts.md`.
type DevAccount = {
  label: string
  subtitle: string
  email: string
  password: string
  variant: 'admin' | 'dosen'
}

const DEV_ACCOUNTS: DevAccount[] = [
  {
    label: 'Admin TRPL',
    subtitle: 'aryadanendra23@gmail.com',
    email: 'aryadanendra23@gmail.com',
    password: '@Batuah26',
    variant: 'admin',
  },
  {
    label: 'Dr. Ahmad (Dosen)',
    subtitle: 'NIP 199001012015011002',
    email: 'dosen.test@Politani.ac.id',
    password: 'DosenTest123!',
    variant: 'dosen',
  },
]

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
  const formRef = useRef<HTMLFormElement>(null)
  const emailRef = useRef<HTMLInputElement>(null)
  const passwordRef = useRef<HTMLInputElement>(null)

  // DEV ONLY — auto-fill kredensial + trigger form submit.
  // process.env.NODE_ENV di-replace compile-time oleh Next.js, jadi kalau
  // production build dicompile, branch ini di-strip total via dead code elimination.
  const handleDevQuickLogin = (account: DevAccount) => {
    if (emailRef.current && passwordRef.current && formRef.current) {
      emailRef.current.value = account.email
      passwordRef.current.value = account.password
      formRef.current.requestSubmit()
    }
  }

  // CapsLock detector — bantu user yang lagi ketik password biar nggak salah berkali-kali.
  // Pattern Stripe/GitHub: warning kuning muncul di bawah field password saat aktif.
  const handleCapsLockCheck = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (typeof e.getModifierState === 'function') {
      setCapsLockOn(e.getModifierState('CapsLock'))
    }
  }

  return (
    <form ref={formRef} action={formAction} className="flex flex-col gap-4">

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
          ref={emailRef}
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
            ref={passwordRef}
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

      {/* DEV ONLY — Quick login panel.
          Section ini di-strip dari production build via process.env.NODE_ENV
          (Next.js compile-time substitution + dead code elimination). */}
      {process.env.NODE_ENV !== 'production' && (
        <div className="mt-3 rounded-lg border border-warning/20 bg-warning/[0.06] p-3">
          <div className="flex items-center gap-1.5 mb-1">
            <Bug size={14} className="text-warning" aria-hidden="true" />
            <span className="text-[11px] font-bold uppercase tracking-wider text-warning">
              Dev Only · Quick Login
            </span>
          </div>
          <p className="text-[11px] text-text-tertiary mb-2.5">
            Hilang otomatis di production build.
          </p>
          <div className="flex flex-wrap gap-2">
            {DEV_ACCOUNTS.map((acc) => (
              <button
                key={acc.email}
                type="button"
                onClick={() => handleDevQuickLogin(acc)}
                className="text-left rounded-md border border-border bg-surface px-3 py-2 text-xs hover:border-primary/40 hover:bg-primary/5 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <div className="font-bold text-text-primary">{acc.label}</div>
                <div className="text-[10px] text-text-tertiary font-mono mt-0.5">
                  {acc.subtitle}
                </div>
              </button>
            ))}
          </div>
        </div>
      )}
    </form>
  )
}
