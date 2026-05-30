// app/(dashboard)/profil/page.tsx
// Halaman profil user — Server Component.
// Fetch data profil di server, render form edit di client.

import { UserCircle } from 'lucide-react'
import { getMyProfile } from '@/lib/actions/profile'
import ProfileForm from './profile-form'
import BackButton from '@/components/ui/back-button'

export default async function ProfilPage() {
  const { profile, email } = await getMyProfile()

  return (
    <div className="max-w-3xl mx-auto">
      {/* Back navigation — profil diakses dari topbar avatar (halaman manapun) */}
      <div className="mb-4">
        <BackButton label="Kembali" />
      </div>

      {/* Page Header */}
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <UserCircle size={22} className="text-primary" />
        </div>
        <div>
          <h2 className="page-title">Profil Saya</h2>
          <p className="page-subtitle">Kelola informasi profil dan keamanan akun Anda</p>
        </div>
      </div>

      <ProfileForm
        profile={profile}
        email={email}
      />
    </div>
  )
}
