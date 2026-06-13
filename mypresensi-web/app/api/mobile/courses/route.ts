// app/api/mobile/courses/route.ts
// Endpoint daftar mata kuliah yang di-enroll oleh mahasiswa.
// Menyertakan info sesi aktif per MK agar Flutter bisa langsung tahu mana yang perlu di-attend.

import { NextRequest } from 'next/server'
import { authenticateRequest, errorResponse, successResponse } from '../_lib/auth'
import { createAdminClient } from '@/lib/supabase/server'

export async function GET(req: NextRequest) {
  const auth = await authenticateRequest(req)
  if (auth.error) return errorResponse(auth.error, auth.status)

  const user = auth.user!
  const adminClient = createAdminClient()

  // 1. Ambil semua enrollment mahasiswa + data course + dosen
  const { data: enrollments, error } = await adminClient
    .from('enrollments')
    .select(`
      course_id,
      academic_year,
      course:courses!enrollments_course_id_fkey(
        id, code, name, sks, semester, academic_year, is_active,
        dosen:profiles!courses_dosen_id_fkey(full_name)
      )
    `)
    .eq('student_id', user.id)

  if (error) {
    return errorResponse('Gagal mengambil data mata kuliah', 500)
  }

  // 2. Ambil semua sesi aktif untuk course yang di-enroll
  const courseIds = (enrollments ?? [])
    .map((e) => {
      const courseObj = e.course as unknown as { id: string } | null
      return courseObj?.id
    })
    .filter(Boolean) as string[]

  const activeSessions: Record<string, { id: string; session_number: number; topic: string | null }> = {}

  if (courseIds.length > 0) {
    const { data: sessions } = await adminClient
      .from('sessions')
      .select('id, course_id, session_number, topic')
      .in('course_id', courseIds)
      .eq('is_active', true)

    if (sessions) {
      for (const s of sessions) {
        activeSessions[s.course_id] = {
          id: s.id,
          session_number: s.session_number,
          topic: s.topic,
        }
      }
    }
  }

  // 3. Map ke response format
  const courses = (enrollments ?? []).map((e) => {
    const course = e.course as unknown as {
      id: string; code: string; name: string; sks: number;
      semester: number; academic_year: string; is_active: boolean;
      dosen: { full_name: string } | Array<{ full_name: string }> | null
    } | null

    if (!course) return null

    const dosenData = course.dosen
    const dosenName = Array.isArray(dosenData)
      ? dosenData[0]?.full_name ?? null
      : dosenData?.full_name ?? null

    return {
      id: course.id,
      code: course.code,
      name: course.name,
      sks: course.sks,
      semester: course.semester,
      dosen_name: dosenName,
      academic_year: course.academic_year,
      is_active: course.is_active,
      active_session: activeSessions[course.id] ?? null,
    }
  }).filter(Boolean)

  return successResponse({ courses })
}
