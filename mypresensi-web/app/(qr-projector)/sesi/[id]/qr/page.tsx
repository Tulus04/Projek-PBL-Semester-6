// app/(qr-projector)/sesi/[id]/qr/page.tsx
// Mode presentasi fullscreen QR sesi presensi — Server Component.
// Render: dark gradient background + QR 360px + OTP 88pt + countdown + stats live.
//
// Auth flow (defense in depth):
//   1. requireRole(['admin','dosen']) — gate role
//   2. canAccessCourse(user.id, role, session.course_id) — gate ownership
//      Dosen hanya bisa lihat sesi MK miliknya. Admin bypass.
//   3. createAdminClient() dipanggil setelah kedua check di atas.
//
// Initial data (SSR) di-pass ke <QrDisplayClient/> agar first paint tidak flash.

import { notFound, redirect } from 'next/navigation'
import type { Metadata } from 'next'

import { requireRole, canAccessCourse } from '@/lib/auth-guard'
import { createAdminClient } from '@/lib/supabase/server'

import { QrDisplayClient } from './qr-display-client'

interface PageProps {
  params: Promise<{ id: string }>
}

// ============================================================================
// Helpers — fetch session detail + initial stats (parallel via Promise.all)
// ============================================================================

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
  course: {
    code: string
    name: string
    dosen_name: string | null
  }
}

/**
 * Fetch session + course + dosen info via single JOIN query.
 * Return null kalau session tidak ditemukan.
 */
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
      course:courses!sessions_course_id_fkey(
        code, name,
        dosen:profiles!courses_dosen_id_fkey(full_name)
      )
    `)
    .eq('id', sessionId)
    .maybeSingle()

  if (error || !data) return null

  // Supabase return relasi sebagai array — narrow ke single object
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
    course: {
      code: courseRaw?.code ?? '-',
      name: courseRaw?.name ?? '-',
      dosen_name: dosenName,
    },
  }
}

/**
 * Fetch initial hadir count + total enrolled secara parallel.
 */
async function fetchInitialStats(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  client: any,
  sessionId: string,
  courseId: string,
): Promise<{ hadir: number; total: number }> {
  const [hadirRes, totalRes] = await Promise.all([
    client
      .from('attendances')
      .select('id', { count: 'exact', head: true })
      .eq('session_id', sessionId)
      .in('status', ['hadir', 'terlambat']),
    client
      .from('enrollments')
      .select('id', { count: 'exact', head: true })
      .eq('course_id', courseId),
  ])

  return {
    hadir: hadirRes.count ?? 0,
    total: totalRes.count ?? 0,
  }
}

// ============================================================================
// generateMetadata — title window per MK + Pertemuan
// ============================================================================

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params
  try {
    const adminClient = createAdminClient()
    const session = await fetchSessionDetail(adminClient, id)
    if (!session) {
      return { title: 'QR Presensi — MyPresensi' }
    }
    return {
      title: `${session.course.name} · Pertemuan ${session.session_number} — QR Presensi`,
      robots: { index: false, follow: false },
    }
  } catch {
    return { title: 'QR Presensi — MyPresensi' }
  }
}

// ============================================================================
// Page Component
// ============================================================================

export default async function QrDisplayPage({ params }: PageProps) {
  const { id } = await params

  // 1. Auth gate — admin atau dosen
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

  // 3. Ownership gate — dosen hanya bisa lihat sesi MK miliknya
  const allowed = await canAccessCourse(user.id, user.role, session.course_id)
  if (!allowed) {
    redirect('/sesi?error=no-access')
  }

  // 4. Initial stats — pass ke client untuk avoid loading flash
  const initialStats = await fetchInitialStats(
    adminClient,
    session.id,
    session.course_id,
  )

  // 5. Render client component
  return (
    <QrDisplayClient
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
      initialStats={initialStats}
    />
  )
}
