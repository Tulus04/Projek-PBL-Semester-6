// app/(dashboard)/sesi/[id]/live/page.tsx
// Live Monitor Dosen — Server Component (auth + initial fetch).
// Render dashboard real-time dengan geofence ring, KPI bar, activity feed,
// dan student grid. Listen Postgres Changes via Realtime channel attendances.
//
// Auth flow (defense in depth):
//   1. requireRole(['admin', 'dosen']) — gate role
//   2. canAccessCourse(user.id, role, session.course_id) — gate ownership
//   3. createAdminClient() dipanggil setelah kedua check di atas.

import { notFound, redirect } from 'next/navigation'
import type { Metadata } from 'next'

import { requireRole, canAccessCourse } from '@/lib/auth-guard'
import { createAdminClient } from '@/lib/supabase/server'

import { LiveMonitorClient } from './live-monitor-client'

interface PageProps {
  params: Promise<{ id: string }>
}

interface SessionDetail {
  id: string
  course_id: string
  session_number: number
  topic: string | null
  mode: string
  session_code: string | null
  session_code_expires_at: string | null
  is_active: boolean
  started_at: string | null
  location_lat: number | null
  location_lng: number | null
  radius_meters: number | null
  course: {
    code: string
    name: string
    dosen_name: string | null
  }
}

interface StudentLiveRow {
  student_id: string
  full_name: string
  nim: string | null
  avatar_url: string | null
  status: string
  scanned_at: string | null
  student_lat: number | null
  student_lng: number | null
  distance_meters: number | null
  is_mock_location: boolean | null
  face_confidence: number | null
}

interface LiveStats {
  hadir: number
  terlambat: number
  belum: number
  total: number
  ditolak: number
}

// ============================================================================
// Helpers
// ============================================================================

async function fetchSessionDetail(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  client: any,
  sessionId: string,
): Promise<SessionDetail | null> {
  const { data, error } = await client
    .from('sessions')
    .select(`
      id, course_id, session_number, topic, mode,
      session_code, session_code_expires_at,
      is_active, started_at,
      location_lat, location_lng, radius_meters,
      course:courses!sessions_course_id_fkey(
        code, name,
        dosen:profiles!courses_dosen_id_fkey(full_name)
      )
    `)
    .eq('id', sessionId)
    .maybeSingle()

  if (error || !data) return null

  const courseRaw = data.course as unknown as {
    code: string
    name: string
    dosen: { full_name: string }[] | null
  } | null

  const dosenName =
    Array.isArray(courseRaw?.dosen) && courseRaw.dosen.length > 0
      ? courseRaw.dosen[0].full_name
      : null

  return {
    id: data.id,
    course_id: data.course_id,
    session_number: data.session_number,
    topic: data.topic,
    mode: data.mode,
    session_code: data.session_code,
    session_code_expires_at: data.session_code_expires_at,
    is_active: data.is_active,
    started_at: data.started_at,
    location_lat: data.location_lat,
    location_lng: data.location_lng,
    radius_meters: data.radius_meters,
    course: {
      code: courseRaw?.code ?? '-',
      name: courseRaw?.name ?? '-',
      dosen_name: dosenName,
    },
  }
}

async function fetchInitialLiveState(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  client: any,
  sessionId: string,
  courseId: string,
): Promise<{ students: StudentLiveRow[]; stats: LiveStats }> {
  const [enrollmentsRes, attendancesRes] = await Promise.all([
    client
      .from('enrollments')
      .select(`
        student_id,
        profile:profiles!enrollments_student_id_fkey(id, full_name, nim_nip, avatar_url)
      `)
      .eq('course_id', courseId),
    client
      .from('attendances')
      .select(`
        student_id, status, scanned_at,
        student_lat, student_lng, distance_meters,
        is_mock_location, face_confidence
      `)
      .eq('session_id', sessionId),
  ])

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const enrollments = (enrollmentsRes.data ?? []) as any[]
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const attendances = (attendancesRes.data ?? []) as any[]

  const attendanceMap = new Map<string, (typeof attendances)[number]>()
  for (const a of attendances) {
    attendanceMap.set(a.student_id, a)
  }

  const students: StudentLiveRow[] = enrollments.map((e) => {
    const a = attendanceMap.get(e.student_id)
    const profile = e.profile?.[0]
    const status = a
      ? a.is_mock_location
        ? 'ditolak'
        : (a.status as string)
      : 'belum'
    return {
      student_id: e.student_id,
      full_name: profile?.full_name ?? '-',
      nim: profile?.nim_nip ?? null,
      avatar_url: profile?.avatar_url ?? null,
      status,
      scanned_at: a?.scanned_at ?? null,
      student_lat: a?.student_lat ?? null,
      student_lng: a?.student_lng ?? null,
      distance_meters: a?.distance_meters ?? null,
      is_mock_location: a?.is_mock_location ?? null,
      face_confidence: a?.face_confidence ?? null,
    }
  })

  let hadir = 0
  let terlambat = 0
  let belum = 0
  let ditolak = 0
  for (const s of students) {
    switch (s.status) {
      case 'hadir':
        hadir++
        break
      case 'terlambat':
        terlambat++
        break
      case 'ditolak':
        ditolak++
        break
      case 'belum':
        belum++
        break
    }
  }

  return {
    students,
    stats: {
      hadir,
      terlambat,
      belum,
      ditolak,
      total: students.length,
    },
  }
}

// ============================================================================
// Metadata
// ============================================================================

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params
  try {
    const adminClient = createAdminClient()
    const session = await fetchSessionDetail(adminClient, id)
    if (!session) {
      return { title: 'Live Monitor — MyPresensi' }
    }
    return {
      title: `${session.course.name} · Pertemuan ${session.session_number} — Live Monitor`,
    }
  } catch {
    return { title: 'Live Monitor — MyPresensi' }
  }
}

// ============================================================================
// Page Component
// ============================================================================

export default async function LiveMonitorPage({ params }: PageProps) {
  const { id } = await params

  // 1. Auth gate
  let user
  try {
    user = await requireRole(['admin', 'dosen'])
  } catch {
    redirect('/login?next=/sesi')
  }

  const adminClient = createAdminClient()

  // 2. Fetch session detail
  const session = await fetchSessionDetail(adminClient, id)
  if (!session) {
    notFound()
  }

  // 3. Ownership gate
  const allowed = await canAccessCourse(user.id, user.role, session.course_id)
  if (!allowed) {
    redirect('/sesi?error=no-access')
  }

  // 4. Fetch initial live state
  const { students, stats } = await fetchInitialLiveState(
    adminClient,
    session.id,
    session.course_id,
  )

  // 5. Render client component
  return (
    <LiveMonitorClient
      sessionId={session.id}
      sessionCode={session.session_code}
      sessionCodeExpiresAt={session.session_code_expires_at}
      sessionNumber={session.session_number}
      topic={session.topic}
      mode={session.mode}
      isActive={session.is_active}
      startedAt={session.started_at}
      courseCode={session.course.code}
      courseName={session.course.name}
      dosenName={session.course.dosen_name}
      geofenceCenter={
        session.location_lat !== null && session.location_lng !== null
          ? { lat: session.location_lat, lng: session.location_lng }
          : null
      }
      geofenceRadius={session.radius_meters ?? 150}
      initialStudents={students}
      initialStats={stats}
    />
  )
}
