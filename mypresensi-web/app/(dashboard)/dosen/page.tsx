// app/(dashboard)/dosen/page.tsx
// Halaman Manajemen Dosen — Server Component.
// Data di-fetch di server, search & pagination via searchParams.

import { Metadata } from 'next'
import { getDosen } from '@/lib/actions/dosen'
import { Users } from 'lucide-react'
import DosenTable from './dosen-table'
import DosenFilters from './dosen-filters'
import AddDosenModal from './add-dosen-modal'
import ImportCSVModal from './import-csv-modal'
import Pagination from '@/components/ui/pagination'

export const metadata: Metadata = {
  title: 'Kelola Dosen',
}

export default async function DosenPage({
  searchParams,
}: {
  searchParams: { q?: string; page?: string }
}) {
  const search = searchParams.q ?? ''
  const page = parseInt(searchParams.page ?? '1')

  const { dosen, total, totalPages } = await getDosen({
    search,
    page,
    perPage: 20,
  })

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <Users size={20} className="text-primary" />
          </div>
          <div>
            <h2 className="page-title">Kelola Dosen</h2>
            <p className="page-subtitle">{total} dosen terdaftar</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <ImportCSVModal />
          <AddDosenModal />
        </div>
      </div>

      {/* Search Bar */}
      <div className="card">
        <DosenFilters />
      </div>

      {/* Tabel Dosen */}
      <div className="card">
        <DosenTable dosen={dosen} />

        <Pagination
          page={page}
          totalPages={totalPages}
          total={total}
          baseHref="/dosen"
          searchParams={{ q: search }}
        />
      </div>
    </div>
  )
}
