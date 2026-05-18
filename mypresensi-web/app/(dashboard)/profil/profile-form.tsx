'use client'
// app/(dashboard)/profil/profile-form.tsx
// Client Component — form edit profil + ganti password.
// Menggunakan SweetAlert2 untuk notifikasi, Lucide untuk ikon.

import { useState, useRef, useLayoutEffect } from 'react'
import Image from 'next/image'
import {
  Camera, Save, Lock, Eye, EyeOff,
  Mail, Phone, Shield, Calendar, IdCard, BookOpen
} from 'lucide-react'
import { updateProfileAction, changeOwnPasswordAction } from '@/lib/actions/profile'
import { swal, toast } from '@/lib/swal'

interface ProfileData {
  id: string
  full_name: string
  nim_nip: string
  role: string
  phone: string | null
  avatar_url: string | null
  semester: number | null
  kelas: string | null
  is_active: boolean
  created_at: string
}

interface Props {
  profile: ProfileData | null
  email: string | null
}

export default function ProfileForm({ profile, email }: Props) {
  const [activeTab, setActiveTab] = useState<'info' | 'password'>('info')
  const [saving, setSaving] = useState(false)
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null)
  const [showCurrentPw, setShowCurrentPw] = useState(false)
  const [showNewPw, setShowNewPw] = useState(false)
  const [showConfirmPw, setShowConfirmPw] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const formRef = useRef<HTMLFormElement>(null)
  const pwFormRef = useRef<HTMLFormElement>(null)

  // Animated tab indicator — ukur posisi tab aktif lalu animate underline glide.
  const tabRefs = useRef<Record<string, HTMLButtonElement | null>>({})
  const [indicator, setIndicator] = useState({ left: 0, width: 0 })
  // useLayoutEffect supaya pengukuran terjadi sebelum paint (no flicker).
  // Aman di Client Component — Next.js handle SSR fallback.
  useLayoutEffect(() => {
    const el = tabRefs.current[activeTab]
    if (el) setIndicator({ left: el.offsetLeft, width: el.offsetWidth })
  }, [activeTab])

  if (!profile) {
    return (
      <div className="card p-8 text-center">
        <p className="text-text-secondary">Profil tidak ditemukan.</p>
      </div>
    )
  }

  const handleAvatarChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (file.size > 2 * 1024 * 1024) {
      swal.fire({ icon: 'error', title: 'File terlalu besar', text: 'Ukuran foto maksimal 2MB.' })
      return
    }

    const reader = new FileReader()
    reader.onloadend = () => setAvatarPreview(reader.result as string)
    reader.readAsDataURL(file)
  }

  const handleProfileSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setSaving(true)

    const formData = new FormData(e.currentTarget)
    const result = await updateProfileAction(formData)

    if (result.success) {
      toast.fire({ icon: 'success', title: 'Profil berhasil diperbarui' })
      setAvatarPreview(null)
    } else {
      swal.fire({ icon: 'error', title: 'Gagal', text: result.error ?? 'Terjadi kesalahan' })
    }
    setSaving(false)
  }

  const handlePasswordSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setSaving(true)

    const formData = new FormData(e.currentTarget)
    const result = await changeOwnPasswordAction(formData)

    if (result.success) {
      toast.fire({ icon: 'success', title: 'Password berhasil diubah' })
      pwFormRef.current?.reset()
    } else {
      if (result.fieldErrors) {
        const firstError = Object.values(result.fieldErrors).flat()[0]
        swal.fire({ icon: 'error', title: 'Validasi Gagal', text: firstError })
      } else {
        swal.fire({ icon: 'error', title: 'Gagal', text: result.error ?? 'Terjadi kesalahan' })
      }
    }
    setSaving(false)
  }

  const roleLabel: Record<string, string> = {
    admin: 'Administrator',
    dosen: 'Dosen',
    mahasiswa: 'Mahasiswa',
  }

  const displayAvatar = avatarPreview || profile.avatar_url

  return (
    <div className="space-y-5">
      {/* ==================== */}
      {/* PROFILE HEADER CARD  */}
      {/* ==================== */}
      <div className="card p-6">
        <div className="flex items-center gap-5">
          {/* Avatar */}
          <div className="relative group">
            {displayAvatar ? (
              <Image
                src={displayAvatar}
                alt={profile.full_name}
                width={80}
                height={80}
                className="w-20 h-20 rounded-2xl object-cover border-2 border-border"
                unoptimized
              />
            ) : (
              <div className="w-20 h-20 rounded-2xl flex items-center justify-center text-white text-2xl font-bold border-2 border-transparent bg-primary">
                {profile.full_name.charAt(0).toUpperCase()}
              </div>
            )}
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              className="absolute inset-0 rounded-2xl bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity cursor-pointer"
            >
              <Camera size={20} className="text-white" />
            </button>
          </div>

          {/* Info */}
          <div className="flex-1 min-w-0">
            <h3 className="text-lg font-bold text-text-primary">{profile.full_name}</h3>
            <p className="text-sm text-text-secondary">{email}</p>
            <div className="flex items-center gap-2 mt-1.5">
              <span className="badge badge-success">{roleLabel[profile.role] ?? profile.role}</span>
              <span className={profile.is_active ? 'badge badge-success' : 'badge badge-danger'}>
                {profile.is_active ? 'Aktif' : 'Nonaktif'}
              </span>
            </div>
          </div>

          {/* Meta Info */}
          <div className="hidden md:flex flex-col gap-1 text-right">
            <span className="text-xs text-text-secondary flex items-center gap-1.5 justify-end">
              <IdCard size={12} /> {profile.nim_nip}
            </span>
            <span className="text-xs text-text-secondary flex items-center gap-1.5 justify-end">
              <Calendar size={12} /> Bergabung {new Date(profile.created_at).toLocaleDateString('id-ID', {
                day: 'numeric', month: 'long', year: 'numeric'
              })}
            </span>
          </div>
        </div>
      </div>

      {/* ==================== */}
      {/* TAB NAVIGATION — underline glide via absolute indicator (Tier 2 anim) */}
      {/* ==================== */}
      <div className="relative flex gap-1 border-b border-border">
        <button
          ref={(el) => { tabRefs.current['info'] = el }}
          onClick={() => setActiveTab('info')}
          className={`px-4 py-2.5 text-sm font-medium transition-colors ${
            activeTab === 'info' ? 'text-primary' : 'text-text-secondary hover:text-text-primary'
          }`}
        >
          Informasi Profil
        </button>
        <button
          ref={(el) => { tabRefs.current['password'] = el }}
          onClick={() => setActiveTab('password')}
          className={`px-4 py-2.5 text-sm font-medium transition-colors flex items-center gap-1.5 ${
            activeTab === 'password' ? 'text-primary' : 'text-text-secondary hover:text-text-primary'
          }`}
        >
          <Lock size={14} /> Ubah Password
        </button>

        {/* Sliding underline indicator */}
        <span
          aria-hidden="true"
          className="pointer-events-none absolute bottom-0 h-0.5 -mb-px bg-primary transition-all duration-300 ease-out"
          style={{ left: indicator.left, width: indicator.width }}
        />
      </div>

      {/* ==================== */}
      {/* TAB: INFORMASI PROFIL */}
      {/* ==================== */}
      {activeTab === 'info' && (
        <form ref={formRef} onSubmit={handleProfileSubmit} className="card p-6">
          <h4 className="text-sm font-semibold text-text-primary mb-4 flex items-center gap-2">
            <Shield size={16} className="text-primary" />
            Edit Informasi Profil
          </h4>

          {/* Hidden avatar file input */}
          <input
            ref={fileInputRef}
            type="file"
            name="avatar"
            accept="image/jpeg,image/png,image/webp"
            className="hidden"
            onChange={handleAvatarChange}
          />

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Nama Lengkap */}
            <div>
              <label className="form-label">Nama Lengkap</label>
              <input
                name="full_name"
                type="text"
                defaultValue={profile.full_name}
                className="input-field w-full"
                required
              />
            </div>

            {/* Email — read-only */}
            <div>
              <label className="form-label flex items-center gap-1.5">
                <Mail size={12} /> Email
              </label>
              <input
                type="email"
                value={email ?? ''}
                disabled
                className="input-field w-full bg-gray-50 text-text-secondary cursor-not-allowed"
              />
              <p className="text-[10px] text-text-secondary mt-1">Email tidak dapat diubah</p>
            </div>

            {/* NIM/NIP — read-only */}
            <div>
              <label className="form-label flex items-center gap-1.5">
                <IdCard size={12} /> NIM / NIP
              </label>
              <input
                type="text"
                value={profile.nim_nip}
                disabled
                className="input-field w-full bg-gray-50 text-text-secondary cursor-not-allowed"
              />
              <p className="text-[10px] text-text-secondary mt-1">NIM/NIP tidak dapat diubah</p>
            </div>

            {/* Nomor Telepon */}
            <div>
              <label className="form-label flex items-center gap-1.5">
                <Phone size={12} /> Nomor Telepon
              </label>
              <input
                name="phone"
                type="text"
                defaultValue={profile.phone ?? ''}
                placeholder="contoh: 08123456789"
                className="input-field w-full"
              />
            </div>

            {/* Role — read-only */}
            <div>
              <label className="form-label flex items-center gap-1.5">
                <Shield size={12} /> Role
              </label>
              <input
                type="text"
                value={roleLabel[profile.role] ?? profile.role}
                disabled
                className="input-field w-full bg-gray-50 text-text-secondary cursor-not-allowed capitalize"
              />
            </div>

            {/* Semester/Kelas — untuk mahasiswa */}
            {profile.role === 'mahasiswa' && (
              <>
                <div>
                  <label className="form-label flex items-center gap-1.5">
                    <BookOpen size={12} /> Semester
                  </label>
                  <input
                    type="text"
                    value={profile.semester ?? '-'}
                    disabled
                    className="input-field w-full bg-gray-50 text-text-secondary cursor-not-allowed"
                  />
                </div>
                <div>
                  <label className="form-label">Kelas</label>
                  <input
                    type="text"
                    value={profile.kelas ?? '-'}
                    disabled
                    className="input-field w-full bg-gray-50 text-text-secondary cursor-not-allowed"
                  />
                </div>
              </>
            )}
          </div>

          {/* Avatar preview info */}
          {avatarPreview && (
            <div className="mt-4 p-3 bg-primary/10 rounded-lg border border-primary/20">
              <p className="text-xs text-primary font-medium">
                Foto baru akan disimpan saat Anda klik &quot;Simpan Perubahan&quot;
              </p>
            </div>
          )}

          <div className="flex justify-end mt-5">
            <button
              type="submit"
              disabled={saving}
              className="btn-primary flex items-center gap-2"
            >
              {saving ? (
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <Save size={16} />
              )}
              Simpan Perubahan
            </button>
          </div>
        </form>
      )}

      {/* ==================== */}
      {/* TAB: UBAH PASSWORD    */}
      {/* ==================== */}
      {activeTab === 'password' && (
        <form ref={pwFormRef} onSubmit={handlePasswordSubmit} className="card p-6">
          <h4 className="text-sm font-semibold text-text-primary mb-1 flex items-center gap-2">
            <Lock size={16} className="text-primary" />
            Ubah Password
          </h4>
          <p className="text-xs text-text-secondary mb-4">
            Pastikan password baru memiliki minimal 8 karakter, 1 huruf kapital, dan 1 angka.
          </p>

          <div className="max-w-md space-y-4">
            {/* Password Lama */}
            <div>
              <label className="form-label">Password Lama</label>
              <div className="relative">
                <input
                  name="currentPassword"
                  type={showCurrentPw ? 'text' : 'password'}
                  placeholder="Masukkan password saat ini"
                  className="input-field w-full pr-10"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowCurrentPw(!showCurrentPw)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary"
                >
                  {showCurrentPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            {/* Password Baru */}
            <div>
              <label className="form-label">Password Baru</label>
              <div className="relative">
                <input
                  name="newPassword"
                  type={showNewPw ? 'text' : 'password'}
                  placeholder="Minimal 8 karakter, 1 kapital, 1 angka"
                  className="input-field w-full pr-10"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowNewPw(!showNewPw)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary"
                >
                  {showNewPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            {/* Konfirmasi Password */}
            <div>
              <label className="form-label">Konfirmasi Password Baru</label>
              <div className="relative">
                <input
                  name="confirmPassword"
                  type={showConfirmPw ? 'text' : 'password'}
                  placeholder="Ulangi password baru"
                  className="input-field w-full pr-10"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowConfirmPw(!showConfirmPw)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary"
                >
                  {showConfirmPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>
          </div>

          <div className="flex justify-end mt-5">
            <button
              type="submit"
              disabled={saving}
              className="btn-primary flex items-center gap-2"
            >
              {saving ? (
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <Lock size={16} />
              )}
              Ubah Password
            </button>
          </div>
        </form>
      )}
    </div>
  )
}
