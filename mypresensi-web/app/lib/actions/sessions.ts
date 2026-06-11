'use server'
// app/lib/actions/sessions.ts
// Server Actions untuk manajemen sesi perkuliahan.
// Termasuk generate session code (OTP), refresh, detail presensi, dan konfigurasi geolokasi.
// SECURITY: Semua mutasi di-guard oleh ownership check (dosen hanya bisa kelola sesi MK-nya).

import { revalidatePath } from 'next/cache'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import { createBulkNotifications } from '@/lib/actions/notifications'
import { sendPushToMany } from '@/lib/fcm-admin'
import { getCurrentUserProfile, canAccessCourse } from '@/lib/auth-guard'
import { generateCode, getCurrentWindow } from '@/lib/utils/totp'
import crypto from 'crypto'

// ===========================
// Schema Validasi
// ===========================
const sessionSchema = z.object({
  session_number: z.coerce.number().min(1, 'Nomor pertemuan minimal 1').max(16, 'Nomor pertemuan maksimal 16'),
  topic: z.string().min(1, 'Topik wajib diisi').max(200, 'Topik maksimal 200 karakter'),
  mode: z.enum(['offline', 'online']),
  target_kelas: z.string().optional().or(z.literal('')),
  campus_location_id: z.string().uuid().optional().or(z.literal('')),
  radius_meters: z.preprocess(
    (val) => (val === '' || val === null || val === undefined) ? undefined : Number(val),
    z.number().int().min(50).max(500).optional()
  ),
})

export type SessionFormState = {
  error: string | null
  success: boolean
}

// ===========================
// Get ALL sessions (untuk halaman /sesi — grouped by course)
// Mendukung filter: dosenId (data isolation), courseId, status
// ===========================
export async function getAllSessions({
  dosenId,
  courseId,
  status,
  kelas,
}: {
  dosenId?: string
  courseId?: string
  status?: string
  kelas?: string
} = {}) {
  const supabase = createAdminClient()

  let query = supabase
    .from('sessions')
    .select(`
      *,
      attendance_count:attendances(count),
      course:courses!inner(id, name, code, dosen_id, semester, is_active)
    `)
    .order('created_at', { ascending: false })

  // Data isolation: filter berdasarkan dosen
  if (dosenId) {
    query = query.eq('courses.dosen_id', dosenId)
  }

  // Filter per MK
  if (courseId) {
    query = query.eq('course_id', courseId)
  }

  // Filter status sesi
  if (status === 'active') {
    query = query.eq('is_active', true)
  } else if (status === 'ended') {
    query = query.eq('is_active', false).not('started_at', 'is', null)
  } else if (status === 'pending') {
    query = query.eq('is_active', false).is('started_at', null)
  }

  // Filter kelas
  if (kelas) {
    if (kelas === 'Semua') {
      query = query.is('target_kelas', null)
    } else {
      query = query.ilike('target_kelas', `%${kelas}`)
    }
  }

  const { data, error } = await query

  return { sessions: data ?? [], error: error?.message ?? null }
}

// ===========================
// Get sessions for a course
// ===========================
export async function getSessionsByCourse(courseId: string) {
  const supabase = createAdminClient()

  const { data, error } = await supabase
    .from('sessions')
    .select('*, attendance_count:attendances(count)')
    .eq('course_id', courseId)
    .order('session_number')

  return { sessions: data ?? [], error: error?.message ?? null }
}

// ===========================
// Add a session
// ===========================
export async function addSessionAction(
  courseId: string,
  dosenId: string | null,
  formData: FormData
): Promise<SessionFormState> {
  // SECURITY: Cek bahwa user boleh menambahkan sesi ke course ini
  const currentUser = await getCurrentUserProfile()
  if (!currentUser) return { error: 'Unauthorized: silakan login ulang.', success: false }

  const hasAccess = await canAccessCourse(currentUser.id, currentUser.role, courseId)
  if (!hasAccess) return { error: 'Akses ditolak: Anda tidak mengampu mata kuliah ini.', success: false }
  const raw = {
    session_number: formData.get('session_number'),
    topic: formData.get('topic'),
    mode: formData.get('mode'),
    target_kelas: formData.get('target_kelas') || '',
    campus_location_id: formData.get('campus_location_id') || '',
    radius_meters: formData.get('radius_meters') || undefined,
  }

  const parsed = sessionSchema.safeParse(raw)
  if (!parsed.success) {
    const msgs = Object.values(parsed.error.flatten().fieldErrors).flat()
    return { error: msgs[0] || 'Data tidak valid', success: false }
  }

  const supabase = createAdminClient()

  const targetKelas = parsed.data.target_kelas || null

  // Check duplicate session number for the same class
  const checkQuery = supabase
    .from('sessions')
    .select('id, target_kelas')
    .eq('course_id', courseId)
    .eq('session_number', parsed.data.session_number)

  const { data: existingSessions } = await checkQuery

  if (existingSessions && existingSessions.length > 0) {
    if (targetKelas === null) {
      return { error: `Pertemuan ${parsed.data.session_number} sudah ada (Semua Kelas/Kelas Lain). Tidak dapat menimpa dengan 'Semua Kelas'.`, success: false }
    } else {
      const conflict = existingSessions.find(s => s.target_kelas === targetKelas || s.target_kelas === null)
      if (conflict) {
        return { error: `Pertemuan ${parsed.data.session_number} sudah dibuat untuk kelas ${conflict.target_kelas || 'Semua Kelas'}.`, success: false }
      }
    }
  }

  // Resolve lokasi berdasarkan mode
  let locationLat: number | null = null
  let locationLng: number | null = null
  let radiusMeters: number | null = null

  if (parsed.data.mode === 'offline') {
    // Mode tatap muka — perlu GPS config
    const locationId = parsed.data.campus_location_id

    if (locationId) {
      // Dosen memilih lokasi dari preset
      const { data: loc } = await supabase
        .from('campus_locations')
        .select('latitude, longitude, radius_meters')
        .eq('id', locationId)
        .single()

      if (loc) {
        locationLat = loc.latitude
        locationLng = loc.longitude
        radiusMeters = parsed.data.radius_meters ?? loc.radius_meters
      }
    }

    // Fallback ke lokasi default jika tidak dipilih
    if (locationLat === null) {
      const { data: defaultLoc } = await supabase
        .from('campus_locations')
        .select('latitude, longitude, radius_meters')
        .eq('is_default', true)
        .single()

      if (defaultLoc) {
        locationLat = defaultLoc.latitude
        locationLng = defaultLoc.longitude
        radiusMeters = parsed.data.radius_meters ?? defaultLoc.radius_meters
      }
    }
  }
  // Mode online → locationLat/Lng/radius tetap null → GPS dilewat

  const { error: insertError } = await supabase.from('sessions').insert({
    course_id: courseId,
    dosen_id: dosenId,
    session_number: parsed.data.session_number,
    topic: parsed.data.topic,
    mode: parsed.data.mode,
    target_kelas: targetKelas,
    location_lat: locationLat,
    location_lng: locationLng,
    radius_meters: radiusMeters,
    // Sesi baru = pending (belum dimulai). Dosen harus eksplisit klik "Mulai".
    is_active: false,
    started_at: null,
  })

  if (insertError) {
    return { error: `Gagal menambahkan sesi: ${insertError.message}`, success: false }
  }

  await logAudit({
    action: 'create_session',
    details: { course_id: courseId, session_number: parsed.data.session_number, topic: parsed.data.topic },
  })

  revalidatePath('/matakuliah')
  revalidatePath('/sesi')
  return { error: null, success: true }
}

// ===========================
// Toggle session active status + Generate OTP
// ===========================
export async function toggleSessionAction(sessionId: string, isActive: boolean) {
  const supabase = createAdminClient()

  // SECURITY: Cek ownership — ambil course_id dari session, lalu validasi akses
  const currentUser = await getCurrentUserProfile()
  if (!currentUser) return { error: 'Unauthorized', sessionCode: null }

  const { data: sessionCheck } = await supabase
    .from('sessions')
    .select('course_id')
    .eq('id', sessionId)
    .single()

  if (sessionCheck) {
    const hasAccess = await canAccessCourse(currentUser.id, currentUser.role, sessionCheck.course_id)
    if (!hasAccess) return { error: 'Akses ditolak: Anda tidak mengampu mata kuliah ini.', sessionCode: null }
  }

  if (isActive) {
    // MULAI SESI → Generate seed + initial TOTP code (Phase 3 v7 rolling QR)
    // - seed: 32-byte random hex (64 char) — Tier 1 secret, server-only
    // - initialCode: TOTP-derived dari (seed, current 30s window) — boleh tampil ke dosen
    // - expiresAt: NOW() + 24h sebagai placeholder kompatibilitas UI/legacy.
    //   Rolling mode TIDAK pakai expiry sebenarnya — code di-rotate per window via TOTP.
    const seed = crypto.randomBytes(32).toString('hex')
    const initialCode = generateCode(seed, getCurrentWindow())
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()

    const { error } = await supabase
      .from('sessions')
      .update({
        is_active: true,
        session_code: initialCode,
        session_code_seed: seed,
        session_code_expires_at: expiresAt,
        started_at: new Date().toISOString(),
        ended_at: null,
      })
      .eq('id', sessionId)

    if (error) return { error: error.message, sessionCode: null }

    // SECURITY (R6.4, R16.2): JANGAN log seed atau initialCode mentah ke audit_logs.
    // Hanya metadata aman: length, boolean, mode.
    await logAudit({
      action: 'start_session',
      details: {
        session_id: sessionId,
        code_length: initialCode.length,
        has_seed: true,
        qr_mode: 'rolling',
      },
    })

    // 1. Ambil course_id dan target_kelas untuk sesi ini jika belum punya (defense)
    const sessionIdTarget = sessionId
    const { data: sessionData } = await supabase
      .from('sessions')
      .select('course_id, topic, session_number, target_kelas, course:courses!course_id(name)')
      .eq('id', sessionIdTarget)
      .single()

    if (sessionData && sessionData.course_id) {
      // 2. Ambil semua pendaftar di MK tersebut
      const { data: enrolled } = await supabase
        .from('enrollments')
        .select('student_id, profiles!inner(semester, kelas)')
        .eq('course_id', sessionData.course_id)

      let targetStudents = enrolled || []
      if (sessionData.target_kelas) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        targetStudents = targetStudents.filter((e: any) => {
          const p = e.profiles as { kelas?: string | null; semester?: number | string | null }
          const combined = `${p.semester ?? ''}${p.kelas ?? ''}`.toLowerCase()
          return combined === sessionData.target_kelas?.toLowerCase()
        })
      }

      if (targetStudents.length > 0) {
        const courseArr = sessionData.course as unknown as Array<{ name?: string }> | null
        const courseName = courseArr?.[0]?.name ?? 'Mata Kuliah'
        const topic = sessionData.topic ?? `Pertemuan ${sessionData.session_number}`

        await createBulkNotifications(
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          targetStudents.map((e: any) => ({
            userId: e.student_id,
            title: 'Sesi Presensi Dimulai',
            message: `${courseName}: ${topic} — segera lakukan absensi.`,
            type: 'warning' as const,
            href: '/dashboard',
          }))
        )

        try {
          await sendPushToMany(
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            targetStudents.map((e: any) => e.student_id),
            {
              title: 'Sesi Presensi Dimulai',
              body: `${courseName}: ${topic} — segera lakukan absensi.`,
              route: '/scan',
              type: 'session_start',
              relatedId: sessionId,
            },
          )
        } catch (e) {
          const errMsg = (e as Error).message
          console.error('[FCM] Failed to send push on session start:', errMsg)
          await logAudit({
            action: 'fcm_push_fatal_error',
            details: { error: errMsg }
          })
        }
      }
    }

    revalidatePath('/matakuliah')
    revalidatePath('/sesi')
    return { error: null, sessionCode: initialCode, expiresAt }
  } else {
    // AKHIRI SESI → Hapus kode, set ended_at, & GENERATE ALPA otomatis

    const sessionIdTarget = sessionId
    const courseIdTarget = sessionCheck?.course_id

    // 1. Ambil info sesi untuk menentukan target mahasiswa
    const { data: sessionData } = await supabase
      .from('sessions')
      .select('target_kelas')
      .eq('id', sessionIdTarget)
      .single()

    const { error } = await supabase
      .from('sessions')
      .update({
        is_active: false,
        session_code: null,
        session_code_expires_at: null,
        ended_at: new Date().toISOString(),
      })
      .eq('id', sessionIdTarget)

    if (error) return { error: error.message, sessionCode: null }

    // 3. Generate Alpa untuk mahasiswa yang belum absen
    if (courseIdTarget) {
      const { data: enrollments } = await supabase
        .from('enrollments')
        .select('student_id, profiles!inner(kelas)')
        .eq('course_id', courseIdTarget)

      // Filter pendaftar berdasarkan target_kelas sesi
      let targetStudents = enrollments || []
      if (sessionData?.target_kelas) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        targetStudents = targetStudents.filter((e: any) => {
          const p = e.profiles as { kelas?: string | null; semester?: number | string | null }
          const combined = `${p.semester ?? ''}${p.kelas ?? ''}`
          return combined === sessionData?.target_kelas
        })
      }

      const { data: attendances } = await supabase
        .from('attendances')
        .select('student_id')
        .eq('session_id', sessionIdTarget)

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const targetIds = targetStudents.map((e: any) => e.student_id)
      const attendedIds = new Set((attendances ?? []).map(a => a.student_id))
      const alpaIds = targetIds.filter((id: string) => !attendedIds.has(id))

      if (alpaIds.length > 0) {
        const alpaRecords = alpaIds.map((studentId: string) => ({
          session_id: sessionIdTarget,
          student_id: studentId,
          status: 'alpa',
          scanned_at: new Date().toISOString(),
          is_location_valid: null,
          distance_meters: null,
          face_confidence: null,
        }))

        // Insert semua record alpa
        await supabase.from('attendances').insert(alpaRecords)

        await logAudit({
          action: 'auto_generate_alpa',
          details: { session_id: sessionIdTarget, count: alpaIds.length },
        })
      }
    }

    await logAudit({
      action: 'end_session',
      details: { session_id: sessionIdTarget },
    })

    revalidatePath('/matakuliah')
    revalidatePath('/sesi')
    return { error: null, sessionCode: null }
  }
}

// ===========================
// Refresh Session Code — Rotate seed total + compute kode baru (Phase 3 v7)
// ===========================
// Dipanggil saat dosen klik "Refresh Kode" karena curiga seed/code bocor.
// Strategy: full seed rotation (BUKAN reuse seed lama dengan window pointer geser),
// sehingga semua attempt dengan seed lama langsung di-reject di submit endpoint.
export async function refreshSessionCode(sessionId: string) {
  const supabase = createAdminClient()

  // SECURITY: Auth check — user harus login
  const currentUser = await getCurrentUserProfile()
  if (!currentUser) return { error: 'Unauthorized', sessionCode: null }

  // Ambil session untuk ownership + status check
  const { data: session } = await supabase
    .from('sessions')
    .select('course_id, is_active')
    .eq('id', sessionId)
    .single()

  if (!session) {
    return { error: 'Sesi tidak ditemukan.', sessionCode: null }
  }

  // SECURITY: Ownership check — dosen hanya boleh refresh sesi MK-nya
  const hasAccess = await canAccessCourse(currentUser.id, currentUser.role, session.course_id)
  if (!hasAccess) {
    return { error: 'Akses ditolak: Anda tidak mengampu mata kuliah ini.', sessionCode: null }
  }

  // R7.4: Sesi non-aktif TIDAK boleh refresh
  if (!session.is_active) {
    return { error: 'Sesi sudah berakhir, tidak dapat refresh kode.', sessionCode: null }
  }

  // R7.1-7.3: Rotate seed total + compute kode baru dari seed baru + current window
  // expiresAt = NOW() + 24h sebagai placeholder (rolling mode tidak pakai expiry sebenarnya).
  const newSeed = crypto.randomBytes(32).toString('hex')
  const newCode = generateCode(newSeed, getCurrentWindow())
  const newExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()

  const { error } = await supabase
    .from('sessions')
    .update({
      session_code: newCode,
      session_code_seed: newSeed,
      session_code_expires_at: newExpiresAt,
    })
    .eq('id', sessionId)

  if (error) return { error: error.message, sessionCode: null }

  // SECURITY (R7.6, R16.2): JANGAN log seed atau code mentah ke audit_logs (Tier 1).
  // Hanya metadata aman: length, boolean, flag rotated.
  await logAudit({
    action: 'refresh_session_code',
    details: {
      session_id: sessionId,
      code_length: newCode.length,
      has_seed: true,
      rotated: true,
    },
  })

  revalidatePath('/matakuliah')
  revalidatePath('/sesi')
  return { error: null, sessionCode: newCode, expiresAt: newExpiresAt }
}

// ===========================
// Get Active Session Detail — Untuk modal detail presensi
// ===========================
export interface SessionDetailData {
  session: {
    id: string
    session_number: number
    topic: string | null
    mode: string
    session_code: string | null
    session_code_expires_at: string | null
    is_active: boolean
    started_at: string | null
    ended_at: string | null
  }
  attendances: {
    id: string
    student_id: string
    student_name: string
    student_nim: string
    status: string
    scanned_at: string | null
    distance_meters: number | null
    is_location_valid: boolean | null
    face_confidence: number | null
  }[]
  enrolledStudents: {
    id: string
    full_name: string
    nim_nip: string
  }[]
  summary: {
    total: number
    hadir: number
    terlambat: number
    izin: number
    sakit: number
    alpa: number
    belumAbsen: number
  }
}

export async function getSessionDetail(sessionId: string): Promise<{
  error: string | null
  data: SessionDetailData | null
}> {
  const supabase = createAdminClient()

  // 1. Ambil data sesi
  const { data: session, error: sessionError } = await supabase
    .from('sessions')
    .select('id, session_number, topic, mode, session_code, session_code_expires_at, is_active, started_at, ended_at, course_id, target_kelas')
    .eq('id', sessionId)
    .single()

  if (sessionError || !session) {
    return { error: 'Sesi tidak ditemukan.', data: null }
  }

  // 2. Ambil daftar mahasiswa yang enrolled di course ini
  const { data: enrollments } = await supabase
    .from('enrollments')
    .select('student_id, student:profiles!enrollments_student_id_fkey(id, full_name, nim_nip, kelas, semester)')
    .eq('course_id', session.course_id)

  let filteredEnrollments = enrollments || []
  if (session.target_kelas) {
    filteredEnrollments = filteredEnrollments.filter((e) => {
      const p = e.student as { kelas?: string | null; semester?: number | string | null }
      const combined = `${p.semester ?? ''}${p.kelas ?? ''}`
      return combined === session.target_kelas
    })
  }

  const enrolledStudents = filteredEnrollments.map((e) => {
    const student = e.student as unknown as { id: string; full_name: string; nim_nip: string }
    return {
      id: student.id,
      full_name: student.full_name,
      nim_nip: student.nim_nip,
    }
  })

  // 3. Ambil data presensi yang sudah tercatat
  const { data: attendances } = await supabase
    .from('attendances')
    .select('id, student_id, status, scanned_at, distance_meters, is_location_valid, face_confidence')
    .eq('session_id', sessionId)

  const attendanceList = (attendances ?? []).map((a) => {
    const student = enrolledStudents.find((s) => s.id === a.student_id)
    return {
      id: a.id,
      student_id: a.student_id,
      student_name: student?.full_name ?? 'Unknown',
      student_nim: student?.nim_nip ?? '-',
      status: a.status,
      scanned_at: a.scanned_at,
      distance_meters: a.distance_meters,
      is_location_valid: a.is_location_valid,
      face_confidence: a.face_confidence,
    }
  })

  // 4. Hitung summary — terlambat counter terpisah (per migration 013: tampil terpisah di rekap detail)
  const hadir = attendanceList.filter((a) => a.status === 'hadir').length
  const terlambat = attendanceList.filter((a) => a.status === 'terlambat').length
  const izin = attendanceList.filter((a) => a.status === 'izin').length
  const sakit = attendanceList.filter((a) => a.status === 'sakit').length
  const alpa = attendanceList.filter((a) => a.status === 'alpa').length
  const attendedStudentIds = new Set(attendanceList.map((a) => a.student_id))
  const belumAbsen = enrolledStudents.filter((s) => !attendedStudentIds.has(s.id)).length

  return {
    error: null,
    data: {
      session: {
        id: session.id,
        session_number: session.session_number,
        topic: session.topic,
        mode: session.mode,
        session_code: session.session_code,
        session_code_expires_at: session.session_code_expires_at,
        is_active: session.is_active,
        started_at: session.started_at,
        ended_at: session.ended_at,
      },
      attendances: attendanceList,
      enrolledStudents,
      summary: {
        total: enrolledStudents.length,
        hadir,
        terlambat,
        izin,
        sakit,
        alpa,
        belumAbsen,
      },
    },
  }
}

// ===========================
// Delete session (only if no attendances)
// ===========================
export async function deleteSessionAction(sessionId: string) {
  const supabase = createAdminClient()

  // SECURITY: Cek ownership — ambil course_id dari session, lalu validasi akses
  const currentUser = await getCurrentUserProfile()
  if (!currentUser) return { error: 'Unauthorized' }

  const { data: sessionCheck } = await supabase
    .from('sessions')
    .select('course_id')
    .eq('id', sessionId)
    .single()

  if (sessionCheck) {
    const hasAccess = await canAccessCourse(currentUser.id, currentUser.role, sessionCheck.course_id)
    if (!hasAccess) return { error: 'Akses ditolak: Anda tidak mengampu mata kuliah ini.' }
  }

  // Check if session has attendances
  const { count } = await supabase
    .from('attendances')
    .select('*', { count: 'exact', head: true })
    .eq('session_id', sessionId)

  if (count && count > 0) {
    return { error: 'Tidak dapat menghapus sesi yang sudah memiliki data presensi.' }
  }

  const { error } = await supabase.from('sessions').delete().eq('id', sessionId)

  if (error) return { error: error.message }

  await logAudit({
    action: 'delete_session',
    details: { session_id: sessionId },
  })

  revalidatePath('/matakuliah')
  revalidatePath('/sesi')
  return { error: null }
}
