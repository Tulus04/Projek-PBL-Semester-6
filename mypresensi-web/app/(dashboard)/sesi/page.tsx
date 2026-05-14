// app/(dashboard)/sesi/page.tsx
// Halaman Sesi Absensi — Server Component.
// Menampilkan semua sesi perkuliahan dengan akses langsung dari sidebar.
// SECURITY: Dosen hanya melihat sesi dari MK yang dia ampu (data isolation).

import { Metadata } from 'next'
import { PlayCircle } from 'lucide-react'
import { getAllSessions } from '@/lib/actions/sessions'
import { getCourses } from '@/lib/actions/courses'
import { getCampusLocations } from '@/lib/actions/campus-locations'
import { getCurrentUserProfile } from '@/lib/auth-guard'
import { redirect } from 'next/navigation'
import SessionList from './session-list'
import SessionFilters from './session-filters'

interface CourseInfo {
  id: string
  name: string
  code: string
  dosen_id: string
  semester: string
  is_active: boolean
}

interface SessionWithCourse {
  id: string
  course_id: string
  session_number: number
  topic: string | null
  mode: string
  session_code: string | null
  session_code_expires_at: string | null
  is_active: boolean
  started_at: string | null
  ended_at: string | null
  attendance_count: { count: number }[]
  course: CourseInfo
}

export const metadata: Metadata = {
  title: 'Sesi Absensi',
}

export default async function SesiPage({
  searchParams,
}: {
  searchParams: { course_id?: string; status?: string }
}) {
  const currentUser = await getCurrentUserProfile()
  if (!currentUser) redirect('/login')

  const isAdmin = currentUser.role === 'admin'
  const dosenId = isAdmin ? undefined : currentUser.id

  // Fetch sesi berdasarkan filter
  const { sessions } = await getAllSessions({
    dosenId,
    courseId: searchParams.course_id,
    status: searchParams.status,
  })

  // Fetch daftar MK untuk filter dropdown
  const { courses } = await getCourses({ dosenId })

  // Fetch preset lokasi kampus untuk form tambah sesi
  const campusLocations = await getCampusLocations()

  // Group sessions by course
  const groupedSessions = new Map<string, { course: CourseInfo; sessions: SessionWithCourse[] }>()
  for (const session of sessions as SessionWithCourse[]) {
    const courseId = session.course_id
    if (!groupedSessions.has(courseId)) {
      groupedSessions.set(courseId, {
        course: session.course,
        sessions: [],
      })
    }
    groupedSessions.get(courseId)!.sessions.push(session)
  }

  // Tambahkan courses yang belum punya sesi (agar dosen bisa buat sesi pertama)
  // Hanya jika tidak ada filter status aktif (karena course tanpa sesi tidak match filter apapun)
  if (!searchParams.status) {
    for (const course of courses as CourseInfo[]) {
      // Jika ada filter course_id, hanya tampilkan course yang sesuai
      if (searchParams.course_id && course.id !== searchParams.course_id) continue
      if (!groupedSessions.has(course.id)) {
        groupedSessions.set(course.id, {
          course,
          sessions: [],
        })
      }
    }
  }


  // Sort: courses with active sessions first, then pending, then by name
  const grouped = Array.from(groupedSessions.values()).sort((a, b) => {
    const aHasActive = a.sessions.some((s) => s.is_active)
    const bHasActive = b.sessions.some((s) => s.is_active)
    if (aHasActive && !bHasActive) return -1
    if (!aHasActive && bHasActive) return 1
    const aHasPending = a.sessions.some((s) => !s.is_active && !s.started_at)
    const bHasPending = b.sessions.some((s) => !s.is_active && !s.started_at)
    if (aHasPending && !bHasPending) return -1
    if (!aHasPending && bHasPending) return 1
    return 0
  })

  // Hitung statistik
  const totalSessions = sessions.length
  const activeSessions = (sessions as SessionWithCourse[]).filter((s) => s.is_active).length
  const pendingSessions = (sessions as SessionWithCourse[]).filter(
    (s) => !s.is_active && !s.started_at
  ).length

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <PlayCircle size={20} className="text-primary" />
        </div>
        <div>
          <h2 className="page-title">Sesi Absensi</h2>
          <p className="page-subtitle">
            {totalSessions} sesi
            {activeSessions > 0 && (
              <> · <span className="text-success font-semibold">{activeSessions} sedang berlangsung</span></>
            )}
            {pendingSessions > 0 && (
              <> · <span className="text-amber-600 font-medium">{pendingSessions} siap dimulai</span></>
            )}
          </p>
        </div>
      </div>

      {/* Filters */}
      <SessionFilters
        courses={courses}
        currentCourseId={searchParams.course_id}
        currentStatus={searchParams.status}
      />

      {/* Session List — grouped by course */}
      <SessionList
        groupedSessions={grouped}
        userRole={currentUser.role}
        userId={currentUser.id}
        campusLocations={campusLocations}
      />
    </div>
  )
}
