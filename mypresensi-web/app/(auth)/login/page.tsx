// app/(auth)/login/page.tsx
// Halaman login — Server Component.
// 2-column split-screen: brand panel kiri (gradient + features) + form kanan.
// Mobile fallback: stacked single column.
// Jika user sudah login, middleware sudah redirect sebelum halaman ini dirender.

import { Metadata } from 'next'
import LoginForm from './login-form'
import Image from 'next/image'
import { Fingerprint, MapPin, ScanFace } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Masuk — MyPresensi TRPL',
  description: 'Masuk ke sistem presensi MyPresensi Prodi TRPL Politani Samarinda',
}

export default function LoginPage() {
  return (
    <main className="min-h-screen flex flex-col lg:flex-row bg-background">
      {/* LEFT PANEL — Brand showcase (hidden mobile, visible lg+) */}
      <aside className="relative hidden lg:flex lg:w-[45%] xl:w-[50%] flex-col justify-between p-10 xl:p-14 text-white overflow-hidden bg-gradient-to-br from-primary via-primary to-primary-dark animate-slide-in-left">
        {/* Decorative elements — dengan drift animation sub-perceptual */}
        <div className="absolute top-0 right-0 w-72 h-72 bg-amber-300/20 rounded-full blur-3xl translate-x-24 -translate-y-24 animate-drift-blur-1" />
        <div className="absolute bottom-0 left-0 w-96 h-96 bg-white/10 rounded-full blur-3xl -translate-x-32 translate-y-32 animate-drift-blur-2" />

        {/* Top: logo + brand */}
        <div className="relative z-10">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center bg-white shadow-lg overflow-hidden">
              <Image
                src="/trpl-logo.jpg"
                alt="Logo TRPL"
                width={48}
                height={48}
                className="object-contain"
              />
            </div>
            <div>
              <h1 className="text-2xl font-bold font-heading text-white leading-tight">
                MyPresensi
              </h1>
              <p className="text-xs text-white/80 leading-tight">
                Sistem Presensi Akademik
              </p>
            </div>
          </div>
        </div>

        {/* Middle: tagline + features */}
        <div className="relative z-10 my-auto">
          <h2 className="text-3xl xl:text-4xl font-bold font-heading text-white leading-tight mb-3">
            Presensi modern,
            <br />
            <span className="text-amber-300">aman</span> &amp;{' '}
            <span className="text-amber-300">akurat</span>.
          </h2>
          <p className="text-sm xl:text-base text-white/85 leading-relaxed mb-8 max-w-md">
            Sistem presensi mahasiswa Prodi TRPL Politani Samarinda dengan tiga lapisan verifikasi: QR Dinamis, geofence GPS, dan pengenalan wajah.
          </p>

          {/* Feature highlights — stagger fade-up untuk premium feel */}
          <ul className="space-y-3 max-w-md">
            <li className="flex items-start gap-3 animate-stagger-in" style={{ animationDelay: '280ms' }}>
              <div className="w-8 h-8 rounded-lg bg-white/15 backdrop-blur flex items-center justify-center flex-shrink-0">
                <Fingerprint size={16} className="text-amber-300" />
              </div>
              <div>
                <p className="text-sm font-semibold text-white">QR Dinamis</p>
                <p className="text-xs text-white/70">Refresh otomatis setiap 5 detik untuk keamanan dan cegah duplikasi.</p>
              </div>
            </li>
            <li className="flex items-start gap-3 animate-stagger-in" style={{ animationDelay: '360ms' }}>
              <div className="w-8 h-8 rounded-lg bg-white/15 backdrop-blur flex items-center justify-center flex-shrink-0">
                <MapPin size={16} className="text-amber-300" />
              </div>
              <div>
                <p className="text-sm font-semibold text-white">Geofence GPS</p>
                <p className="text-xs text-white/70">Validasi lokasi 150m dari kampus + deteksi mock GPS.</p>
              </div>
            </li>
            <li className="flex items-start gap-3 animate-stagger-in" style={{ animationDelay: '440ms' }}>
              <div className="w-8 h-8 rounded-lg bg-white/15 backdrop-blur flex items-center justify-center flex-shrink-0">
                <ScanFace size={16} className="text-amber-300" />
              </div>
              <div>
                <p className="text-sm font-semibold text-white">Pengenalan Wajah</p>
                <p className="text-xs text-white/70">MobileFaceNet on-device dengan liveness detection.</p>
              </div>
            </li>
          </ul>
        </div>

        {/* Bottom: copyright only — trust badge dihapus sesuai feedback user (terlalu noise di footer panel kiri). */}
        <div className="relative z-10">
          <p className="text-xs text-white/70">
            © {new Date().getFullYear()} TRPL Politani Samarinda · v1.0.0
          </p>
        </div>
      </aside>

      {/* RIGHT PANEL — Login form */}
      <section className="flex-1 flex items-center justify-center p-6 lg:p-10 animate-slide-in-right" style={{ animationDelay: '150ms' }}>
        <div className="w-full max-w-md">
          {/* Mobile-only branding (hidden lg+) */}
          <div className="flex flex-col items-center mb-8 lg:hidden">
            <div className="w-16 h-16 rounded-2xl flex items-center justify-center mb-4 overflow-hidden bg-white shadow-sm border border-border">
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
            <p className="text-sm text-text-secondary mt-1 text-center">
              Prodi TRPL · Politani Samarinda
            </p>
          </div>

          {/* Form heading */}
          <div className="mb-6">
            <h2 className="text-2xl font-bold font-heading text-text-primary mb-1.5">
              Portal Akses MyPresensi
            </h2>
            <p className="text-sm text-text-secondary">
              Silakan masuk menggunakan kredensial Admin atau Dosen.
            </p>
          </div>

          {/* Card Login */}
          <div className="card p-7">
            <LoginForm />
          </div>

          {/* Footer */}
          <p className="text-center text-xs text-text-secondary mt-6">
            Butuh bantuan? Hubungi admin prodi atau dosen pengajar Anda.
          </p>
        </div>
      </section>
    </main>
  )
}
