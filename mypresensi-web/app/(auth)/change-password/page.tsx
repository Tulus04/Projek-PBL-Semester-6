// app/(auth)/change-password/page.tsx
// Halaman paksa ganti password — ditampilkan TANPA sidebar/dashboard.
// User yang masih pakai password default wajib ganti sebelum bisa masuk.

import { Metadata } from 'next'
import { redirect } from 'next/navigation'
import { createClient, createAdminClient } from '@/lib/supabase/server'
import ChangePasswordForm from './change-password-form'
import Image from 'next/image'
import { KeyRound } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Ganti Password — MyPresensi TRPL',
  description: 'Anda harus mengganti password default sebelum melanjutkan.',
}

export default async function ChangePasswordPage() {
  // Pastikan user sudah login
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  // Cek apakah user memang harus ganti password
  const adminClient = createAdminClient()
  const { data: profile } = await adminClient
    .from('profiles')
    .select('must_change_password, full_name, role')
    .eq('id', user.id)
    .single()

  // Jika user TIDAK perlu ganti password, langsung ke dashboard
  if (!profile?.must_change_password) {
    redirect('/dashboard')
  }

  return (
    <main className="min-h-screen bg-background flex items-center justify-center p-4">
      <div className="w-full max-w-md">

        {/* Logo & Branding */}
        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 rounded-2xl flex items-center justify-center mb-4 overflow-hidden bg-white shadow-sm">
            <Image
              src="/trpl-logo.jpg"
              alt="Logo TRPL"
              width={56}
              height={56}
              className="object-contain"
            />
          </div>
          <h1 className="text-2xl font-bold font-heading text-text-primary">
            MyPresensi
          </h1>
          <p className="text-sm text-text-secondary mt-1">
            Prodi TRPL · Politeknik Pertanian Negeri Samarinda
          </p>
        </div>

        {/* Card Ganti Password */}
        <div className="card p-8">
          {/* Warning Banner */}
          <div className="bg-warning-subtle border border-warning/20 rounded-xl px-4 py-3 mb-6 flex items-start gap-3">
            <div className="w-9 h-9 rounded-lg bg-warning/15 flex items-center justify-center flex-shrink-0">
              <KeyRound size={16} className="text-warning" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-semibold text-warning leading-tight">
                Ganti Password Wajib
              </p>
              <p className="text-xs text-warning/80 mt-1 leading-relaxed">
                Anda masih menggunakan password default. Demi keamanan akun, silakan buat password baru.
              </p>
            </div>
          </div>

          <h2 className="text-lg font-bold font-heading text-text-primary mb-1">
            Buat Password Baru
          </h2>
          <p className="text-sm text-text-secondary mb-6">
            Halo, <span className="font-semibold text-text-primary">{profile.full_name}</span>. 
            Buat password yang kuat dan mudah Anda ingat.
          </p>

          <ChangePasswordForm />
        </div>

        {/* Footer */}
        <p className="text-center text-xs text-text-secondary mt-6">
          Butuh bantuan? Hubungi admin prodi.
        </p>
      </div>
    </main>
  )
}
