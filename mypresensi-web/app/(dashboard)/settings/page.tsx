// app/(dashboard)/settings/page.tsx
// Halaman pengaturan sistem.
// Server Component — data settings dan lokasi kampus diambil di server.

import { Metadata } from 'next'
import { createAdminClient } from '@/lib/supabase/server'
import { Settings } from 'lucide-react'
import SettingsForm from './settings-form'
import CampusLocationsSection from './campus-locations-section'
import { getCampusLocations } from '@/lib/actions/campus-locations'

export const metadata: Metadata = {
  title: 'Pengaturan',
}

export default async function SettingsPage() {
  const supabase = createAdminClient()
  const { data: settings } = await supabase
    .from('settings')
    .select('*')
    .order('key')

  // Fetch semua lokasi kampus (termasuk non-aktif untuk admin)
  const campusLocations = await getCampusLocations()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Settings size={20} className="text-primary" />
        </div>
        <div>
          <h2 className="page-title">Pengaturan Sistem</h2>
          <p className="page-subtitle">Konfigurasi parameter sistem presensi</p>
        </div>
      </div>

      <SettingsForm settings={settings ?? []} />

      {/* Section: Lokasi Kampus */}
      <CampusLocationsSection locations={campusLocations} />
    </div>
  )
}
