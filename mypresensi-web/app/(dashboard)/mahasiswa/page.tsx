// app/(dashboard)/mahasiswa/page.tsx
// Halaman Manajemen Mahasiswa — Server Component.
// Data di-fetch di server, search & pagination via searchParams.

import { Metadata } from 'next'
import { getStudents } from '@/lib/actions/students'
import { GraduationCap } from 'lucide-react'
import StudentTable from './student-table'
import StudentFilters from './student-filters'
import AddStudentModal from './add-student-modal'
import ImportCSVModal from './import-csv-modal'
import Pagination from '@/components/ui/pagination'

export const metadata: Metadata = {
  title: 'Kelola Mahasiswa',
}

export default async function MahasiswaPage({
  searchParams,
}: {
  searchParams: { q?: string; page?: string; semester?: string; kelas?: string }
}) {
  const search = searchParams.q ?? ''
  const page = parseInt(searchParams.page ?? '1')
  const semester = searchParams.semester ? parseInt(searchParams.semester) : undefined
  const kelas = searchParams.kelas ?? undefined

  const { students, total, totalPages } = await getStudents({
    search,
    page,
    perPage: 20,
    semester,
    kelas,
  })

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <GraduationCap size={20} className="text-primary" />
          </div>
          <div>
            <h2 className="page-title">Kelola Mahasiswa</h2>
            <p className="page-subtitle">{total} mahasiswa terdaftar</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <ImportCSVModal />
          <AddStudentModal />
        </div>
      </div>

      {/* Search & Filter Bar */}
      <div className="card">
        <StudentFilters />
      </div>

      {/* Tabel Mahasiswa */}
      <div className="card">
        <StudentTable students={students} />

        <Pagination
          page={page}
          totalPages={totalPages}
          total={total}
          baseHref="/mahasiswa"
          searchParams={{ q: search, semester, kelas }}
        />
      </div>
    </div>
  )
}
