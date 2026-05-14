// app/(dashboard)/rekap/page.tsx
// Halaman rekap absensi — statistik kehadiran per mata kuliah.
// Server Component — data diambil di server.
// SECURITY: Dosen hanya melihat rekap MK miliknya sendiri.

import { Metadata } from 'next'
import { createAdminClient } from '@/lib/supabase/server'
import { getCurrentUserProfile } from '@/lib/auth-guard'
import { BarChart3, CalendarDays, CheckCircle, XCircle, Clock } from 'lucide-react'
import RekapTable from './rekap-table'
import RekapFilters from './rekap-filters'
import { redirect } from 'next/navigation'

export const metadata: Metadata = {
  title: 'Rekap Absensi',
}

interface PageProps {
  searchParams: {
    course_id?: string
    dosen_id?: string
  }
}

async function getRekapData(courseId?: string, dosenId?: string) {
  const supabase = createAdminClient()

  // 1. Fetch courses with dosen info
  let courseQuery = supabase
    .from('courses')
    .select('id, code, name, semester, academic_year, is_active, dosen:profiles!dosen_id(id, full_name)')
    .eq('is_active', true)
    .order('code')

  if (courseId) courseQuery = courseQuery.eq('id', courseId)
  if (dosenId) courseQuery = courseQuery.eq('dosen_id', dosenId)

  const { data: courses } = await courseQuery

  // 2. For each course, get session + attendance stats
  type CourseRow = {
    id: string
    code: string
    name: string
    semester: number
    academic_year: string
    is_active: boolean
    dosen: { id: string; full_name: string } | { id: string; full_name: string }[] | null
  }

  const rekapData = await Promise.all(
    ((courses ?? []) as CourseRow[]).map(async (course) => {
      const { data: sessions } = await supabase
        .from('sessions')
        .select('id, session_number, topic, started_at, is_active')
        .eq('course_id', course.id)
        .order('session_number')

      const sessionIds = (sessions ?? []).map((s) => s.id)

      // Counter: terlambat = sub-variant "hadir" (mahasiswa tetap hadir, hanya telat).
      // - stats.hadir HANYA mahasiswa yang on-time
      // - stats.terlambat: counter terpisah untuk display
      // - Persentase kehadiran = (hadir + terlambat) / total
      const stats = { hadir: 0, terlambat: 0, izin: 0, sakit: 0, alpa: 0, total: 0 }

      if (sessionIds.length > 0) {
        const { data: attendances } = await supabase
          .from('attendances')
          .select('status')
          .in('session_id', sessionIds)

        if (attendances) {
          stats.total = attendances.length
          attendances.forEach((a) => {
            if (a.status === 'hadir') stats.hadir++
            else if (a.status === 'terlambat') stats.terlambat++
            else if (a.status === 'izin') stats.izin++
            else if (a.status === 'sakit') stats.sakit++
            else if (a.status === 'alpa') stats.alpa++
          })
        }
      }

      return {
        ...course,
        totalSesi: sessions?.length ?? 0,
        sessions: sessions ?? [],
        stats,
      }
    })
  )

  // 3. Fetch dosen list for filter
  const { data: dosenList } = await supabase
    .from('profiles')
    .select('id, full_name')
    .eq('role', 'dosen')
    .eq('is_active', true)
    .order('full_name')

  return { rekapData, dosenList: dosenList ?? [], courses: courses ?? [] }
}

export default async function RekapAbsensiPage({ searchParams }: PageProps) {
  // Cek role user yang login
  const currentUser = await getCurrentUserProfile()
  if (!currentUser) redirect('/login')

  const isAdmin = currentUser.role === 'admin'

  // Data isolation: dosen hanya lihat rekap MK miliknya
  const effectiveDosenId = isAdmin ? searchParams.dosen_id : currentUser.id

  const { rekapData, dosenList, courses } = await getRekapData(
    searchParams.course_id,
    effectiveDosenId
  )

  // Global stats — totalHadir inklusif terlambat (semantik: dia tetap hadir)
  const totalSesi = rekapData.reduce((sum, r) => sum + r.totalSesi, 0)
  const totalHadir = rekapData.reduce((sum, r) => sum + r.stats.hadir + r.stats.terlambat, 0)
  const totalAlpa = rekapData.reduce((sum, r) => sum + r.stats.alpa, 0)
  const totalIzin = rekapData.reduce((sum, r) => sum + r.stats.izin + r.stats.sakit, 0)

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <BarChart3 size={20} className="text-primary" />
        </div>
        <div>
          <h2 className="page-title">Rekap Absensi</h2>
          <p className="page-subtitle">Statistik kehadiran per mata kuliah</p>
        </div>
      </div>

      {/* KPI cards — duotone icon box + lift hover */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="kpi-card">
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Total Sesi</span>
            <span className="kpi-icon-box">
              <CalendarDays size={18} />
            </span>
          </div>
          <span className="summary-card-value">{totalSesi}</span>
          <span className="summary-card-sublabel">Pertemuan terlaksana</span>
        </div>
        <div className="kpi-card">
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Total Hadir</span>
            <span className="kpi-icon-box success">
              <CheckCircle size={18} />
            </span>
          </div>
          <span className="summary-card-value text-success">{totalHadir}</span>
          <span className="summary-card-sublabel">Kehadiran tercatat</span>
        </div>
        <div className="kpi-card">
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Total Alpa</span>
            <span className="kpi-icon-box danger">
              <XCircle size={18} />
            </span>
          </div>
          <span className="summary-card-value text-danger">{totalAlpa}</span>
          <span className="summary-card-sublabel">Tidak hadir</span>
        </div>
        <div className="kpi-card">
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Izin / Sakit</span>
            <span className="kpi-icon-box warning">
              <Clock size={18} />
            </span>
          </div>
          <span className="summary-card-value text-warning">{totalIzin}</span>
          <span className="summary-card-sublabel">Dispensasi</span>
        </div>
      </div>

      <RekapFilters
        courses={courses}
        dosenList={isAdmin ? dosenList : []}
        currentCourseId={searchParams.course_id}
        currentDosenId={effectiveDosenId}
        showDosenFilter={isAdmin}
      />

      <div className="card overflow-hidden">
        <RekapTable data={rekapData} />
      </div>
    </div>
  )
}
