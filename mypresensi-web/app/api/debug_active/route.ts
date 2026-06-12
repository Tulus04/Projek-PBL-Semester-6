import { NextResponse } from 'next/server'
import { createAdminClient } from '@/lib/supabase/server'

export async function GET() {
  const adminClient = createAdminClient()
  
  // Ambil user tulus
  const { data: tulusArr } = await adminClient.from('profiles').select('*').ilike('full_name', '%tulus%').limit(1)
  const user = tulusArr?.[0]
  if (!user) return NextResponse.json({ error: 'tulus not found' })

  // 1. Ambil course_ids
  const { data: enrollments } = await adminClient
    .from('enrollments')
    .select('course_id')
    .eq('student_id', user.id)

  const courseIds = enrollments?.map((e) => e.course_id) || []

  // 2. Ambil sesi
  const { data: sessions } = await adminClient
    .from('sessions')
    .select(`
      id, course_id, session_number, topic, mode,
      location_lat, location_lng, radius_meters,
      started_at, target_kelas, is_active,
      course:courses!sessions_course_id_fkey(code, name),
      dosen:profiles!sessions_dosen_id_fkey(full_name)
    `)
    .in('course_id', courseIds)

  const combinedKelas = `${user.semester ?? ''}${user.kelas ?? ''}`.toLowerCase()
  const filteredSessions = sessions?.filter((s) => {
    if (!s.target_kelas) return true
    return s.target_kelas.toLowerCase() === combinedKelas
  }) || []

  return NextResponse.json({ 
    user_kelas_info: { semester: user.semester, kelas: user.kelas, combinedKelas },
    courseIds,
    all_sessions: sessions,
    filteredSessions 
  })
}
