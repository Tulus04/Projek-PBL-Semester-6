// app/(dashboard)/matakuliah/page.tsx
// Halaman Manajemen Mata Kuliah — Server Component.
// SECURITY: Dosen hanya melihat MK yang dia ampu. Tombol admin-only disembunyikan.

import { Metadata } from 'next'
import { getCourses, getActiveDosen } from '@/lib/actions/courses'
import { getCurrentUserProfile } from '@/lib/auth-guard'
import { BookOpen } from 'lucide-react'
import CourseTable from './course-table'
import CourseFilters from './course-filters'
import AddCourseModal from './add-course-modal'
import Pagination from '@/components/ui/pagination'
import { redirect } from 'next/navigation'

export const metadata: Metadata = {
  title: 'Kelola Mata Kuliah',
}

export default async function MatakuliahPage({
  searchParams,
}: {
  searchParams: { q?: string; page?: string; semester?: string }
}) {
  // Ambil role user yang sedang login
  const currentUser = await getCurrentUserProfile()
  if (!currentUser) redirect('/login')

  const isAdmin = currentUser.role === 'admin'
  const isDosen = currentUser.role === 'dosen'
  const search = searchParams.q ?? ''
  const page = parseInt(searchParams.page ?? '1')
  const semester = searchParams.semester ? parseInt(searchParams.semester) : undefined

  // Data isolation: dosen hanya lihat MK miliknya
  const [coursesData, dosenData] = await Promise.all([
    getCourses({
      search,
      page,
      perPage: 20,
      semester,
      dosenId: isAdmin ? undefined : currentUser.id,
    }),
    // Admin butuh dosen list untuk dropdown. Dosen tidak perlu (auto-assign)
    isAdmin ? getActiveDosen() : Promise.resolve({ dosen: [], error: null }),
  ])

  const { courses, total, totalPages } = coursesData

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <BookOpen size={20} className="text-primary" />
          </div>
          <div>
            <h2 className="page-title">Kelola Mata Kuliah</h2>
            <p className="page-subtitle">{total} mata kuliah terdaftar</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {/* Tombol Tambah MK: Admin dan Dosen */}
          {(isAdmin || isDosen) && (
            <AddCourseModal
              dosenList={dosenData.dosen}
              userRole={currentUser.role}
            />
          )}
        </div>
      </div>

      {/* Search & Filter */}
      <div className="card">
        <CourseFilters />
      </div>

      {/* Tabel */}
      <div className="card">
        <CourseTable
          courses={courses}
          dosenList={dosenData.dosen}
          userRole={currentUser.role}
          userId={currentUser.id}
        />

        <Pagination
          page={page}
          totalPages={totalPages}
          total={total}
          baseHref="/matakuliah"
          searchParams={{ q: search, semester }}
        />
      </div>
    </div>
  )
}
