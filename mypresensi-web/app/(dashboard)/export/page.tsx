// app/(dashboard)/export/page.tsx
// Halaman export data ke CSV dan PDF.
// Server Component — fetch daftar MK di server untuk dropdown PDF.

import { Metadata } from 'next'
import { FileDown } from 'lucide-react'
import { getAvailableCourses } from '@/lib/actions/export'
import ExportPanel from './export-panel'

export const metadata: Metadata = {
  title: 'Export Data',
}

export default async function ExportPage() {
  const courses = await getAvailableCourses()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <FileDown size={20} className="text-primary" />
        </div>
        <div>
          <h2 className="page-title">Export Data</h2>
          <p className="page-subtitle">Download data dalam format CSV dan PDF untuk laporan</p>
        </div>
      </div>

      <div className="card p-4 bg-primary/10 border-primary/20">
        <p className="text-xs text-primary">
          File CSV dapat dibuka di Microsoft Excel atau Google Sheets.
          File PDF berisi laporan resmi rekap kehadiran per mata kuliah, siap cetak.
        </p>
      </div>

      <ExportPanel courses={courses} />
    </div>
  )
}
