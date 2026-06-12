'use server'
// app/lib/actions/export.ts
// Server actions untuk export data ke CSV dan PDF.

import { createAdminClient } from '@/lib/supabase/server'
import { logAudit } from '@/lib/audit-logger'
import Papa from 'papaparse'

export async function exportDosenCSV(): Promise<string> {
  const supabase = createAdminClient()
  const { data } = await supabase
    .from('profiles')
    .select('full_name, nim_nip, phone, is_active, created_at')
    .eq('role', 'dosen')
    .order('full_name')

  type DosenRow = {
    full_name: string
    nim_nip: string | null
    phone: string | null
    is_active: boolean
    created_at: string
  }

  const rows = (data ?? []).map((d: DosenRow) => ({
    Nama: d.full_name,
    NIP: d.nim_nip,
    'No. HP': d.phone ?? '-',
    Status: d.is_active ? 'Aktif' : 'Nonaktif',
    'Terdaftar Sejak': new Date(d.created_at).toLocaleDateString('id-ID'),
  }))

  return Papa.unparse(rows)
}

export async function exportMahasiswaCSV(): Promise<string> {
  const supabase = createAdminClient()
  const { data } = await supabase
    .from('profiles')
    .select('full_name, nim_nip, semester, kelas, phone, is_active, is_face_registered, created_at')
    .eq('role', 'mahasiswa')
    .order('full_name')

  type MahasiswaRow = {
    full_name: string
    nim_nip: string | null
    semester: number | null
    kelas: string | null
    phone: string | null
    is_active: boolean
    is_face_registered: boolean
    created_at: string
  }

  const rows = (data ?? []).map((d: MahasiswaRow) => ({
    Nama: d.full_name,
    NIM: d.nim_nip,
    Semester: d.semester ?? '-',
    Kelas: d.kelas ?? '-',
    'No. HP': d.phone ?? '-',
    Status: d.is_active ? 'Aktif' : 'Nonaktif',
    'Face Registered': d.is_face_registered ? 'Ya' : 'Belum',
    'Terdaftar Sejak': new Date(d.created_at).toLocaleDateString('id-ID'),
  }))

  return Papa.unparse(rows)
}

export async function exportCoursesCSV(): Promise<string> {
  const supabase = createAdminClient()
  const { data } = await supabase
    .from('courses')
    .select('code, name, sks, semester, academic_year, is_active, dosen:profiles!dosen_id(full_name)')
    .order('code')

  type CourseRow = {
    code: string
    name: string
    sks: number
    semester: number
    academic_year: string
    is_active: boolean
    dosen: { full_name: string } | { full_name: string }[] | null
  }

  const rows = (data ?? []).map((d: CourseRow) => {
    const dosen = Array.isArray(d.dosen) ? d.dosen[0] : d.dosen
    return {
      'Kode MK': d.code,
      'Nama Mata Kuliah': d.name,
      SKS: d.sks,
      Semester: d.semester,
      'Tahun Akademik': d.academic_year,
      'Dosen Pengampu': dosen?.full_name ?? '-',
      Status: d.is_active ? 'Aktif' : 'Nonaktif',
    }
  })

  return Papa.unparse(rows)
}

export async function exportPresensiCSV(): Promise<string> {
  const supabase = createAdminClient()
  const { data } = await supabase
    .from('attendances')
    .select(`
      status, scanned_at, distance_meters, is_location_valid, face_confidence, is_face_matched, device_model,
      student:profiles!student_id(full_name, nim_nip),
      session:sessions!session_id(session_number, topic, course:courses!course_id(code, name))
    `)
    .order('scanned_at', { ascending: false })
    .limit(5000)

  type StudentJoin = { full_name: string; nim_nip: string | null }
  type CourseJoin = { code: string; name: string }
  type SessionJoin = {
    session_number: number
    topic: string | null
    course: CourseJoin | CourseJoin[] | null
  }
  type PresensiRow = {
    status: string
    scanned_at: string | null
    distance_meters: number | null
    is_location_valid: boolean
    face_confidence: number | null
    is_face_matched: boolean
    device_model: string | null
    student: StudentJoin | StudentJoin[] | null
    session: SessionJoin | SessionJoin[] | null
  }

  const rows = (data ?? []).map((d: PresensiRow) => {
    const student = Array.isArray(d.student) ? d.student[0] : d.student
    const session = Array.isArray(d.session) ? d.session[0] : d.session
    const course = session ? (Array.isArray(session.course) ? session.course[0] : session.course) : null

    return {
      Mahasiswa: student?.full_name ?? '-',
      NIM: student?.nim_nip ?? '-',
      'Kode MK': course?.code ?? '-',
      'Mata Kuliah': course?.name ?? '-',
      Pertemuan: session?.session_number ?? '-',
      Topik: session?.topic ?? '-',
      Status: d.status,
      Waktu: d.scanned_at ? new Date(d.scanned_at).toLocaleString('id-ID') : '-',
      'Jarak (m)': d.distance_meters ? Math.round(d.distance_meters) : '-',
      'Lokasi Valid': d.is_location_valid ? 'Ya' : 'Tidak',
      'Face Confidence': d.face_confidence ? `${(d.face_confidence * 100).toFixed(1)}%` : '-',
      'Face Match': d.is_face_matched ? 'Ya' : 'Tidak',
      'Device': d.device_model ?? '-',
    }
  })

  return Papa.unparse(rows)
}

// ============================================
// PDF EXPORT — DATA HELPERS
// ============================================

export interface RekapPDFCourse {
  id: string
  code: string
  name: string
  sks: number
  semester: number
  academicYear: string
  dosenName: string
}

export interface RekapPDFSessionRow {
  sessionNumber: number
  topic: string
  date: string
  hadir: number
  terlambat: number
  izin: number
  sakit: number
  alpa: number
  total: number
}

export interface RekapPDFStudentRow {
  nim: string
  name: string
  attendances: Record<number, string> // sessionNumber -> status initial (H/T/I/S/A)
  totalHadir: number
  totalTerlambat: number
  totalIzin: number
  totalSakit: number
  totalAlpa: number
  percentage: number
}

export interface RekapPDFData {
  course: RekapPDFCourse
  sessions: RekapPDFSessionRow[]
  students: RekapPDFStudentRow[]
  summary: {
    totalSesi: number
    totalHadir: number
    totalTerlambat: number
    totalIzin: number
    totalSakit: number
    totalAlpa: number
    rateHadir: number // (hadir + terlambat) / total × 100 (inklusif sesuai migration 013)
  }
}

/**
 * Mengambil daftar mata kuliah aktif untuk dropdown pilihan di modal PDF.
 */
export async function getAvailableCourses(): Promise<RekapPDFCourse[]> {
  const supabase = createAdminClient()

  const { data } = await supabase
    .from('courses')
    .select('id, code, name, sks, semester, academic_year, dosen:profiles!dosen_id(full_name)')
    .eq('is_active', true)
    .order('code')

  return (data ?? []).map((c: Record<string, unknown>) => {
    const dosenRaw = c.dosen as unknown
    const dosen = Array.isArray(dosenRaw) ? dosenRaw[0] as Record<string, string> | undefined : dosenRaw as Record<string, string> | null
    return {
      id: c.id as string,
      code: c.code as string,
      name: c.name as string,
      sks: c.sks as number,
      semester: c.semester as number,
      academicYear: c.academic_year as string,
      dosenName: dosen?.full_name ?? '-',
    }
  })
}

/**
 * Mengambil data rekap kehadiran per MK untuk generate PDF di client.
 * Termasuk: info kelas, rekap per pertemuan, detail per mahasiswa.
 */
export async function getRekapPDFData(courseId: string): Promise<{ data: RekapPDFData | null; error: string | null }> {
  const supabase = createAdminClient()

  // 1. Fetch course info
  const { data: course, error: courseError } = await supabase
    .from('courses')
    .select('id, code, name, sks, semester, academic_year, dosen:profiles!dosen_id(full_name)')
    .eq('id', courseId)
    .single()

  if (courseError || !course) {
    return { data: null, error: 'Mata kuliah tidak ditemukan' }
  }

  const dosenRaw = course.dosen as unknown
  const dosen = Array.isArray(dosenRaw) ? dosenRaw[0] as Record<string, string> | undefined : dosenRaw as Record<string, string> | null
  const courseInfo: RekapPDFCourse = {
    id: course.id,
    code: course.code,
    name: course.name,
    sks: course.sks,
    semester: course.semester,
    academicYear: course.academic_year,
    dosenName: dosen?.full_name ?? '-',
  }

  // 2. Fetch all sessions
  const { data: sessions } = await supabase
    .from('sessions')
    .select('id, session_number, topic, started_at')
    .eq('course_id', courseId)
    .order('session_number')

  const sessionList = sessions ?? []

  if (sessionList.length === 0) {
    return {
      data: {
        course: courseInfo,
        sessions: [],
        students: [],
        summary: { totalSesi: 0, totalHadir: 0, totalTerlambat: 0, totalIzin: 0, totalSakit: 0, totalAlpa: 0, rateHadir: 0 },
      },
      error: null,
    }
  }

  const sessionIds = sessionList.map(s => s.id)

  // 3. Fetch all attendances for these sessions
  const { data: attendances } = await supabase
    .from('attendances')
    .select('session_id, student_id, status')
    .in('session_id', sessionIds)

  const attList = attendances ?? []

  // 4. Fetch enrolled students
  const { data: enrollments } = await supabase
    .from('enrollments')
    .select('student_id, student:profiles!student_id(full_name, nim_nip)')
    .eq('course_id', courseId)
    .order('student_id')

  const enrolledStudents = (enrollments ?? []).map((e: Record<string, unknown>) => {
    const student = e.student as Record<string, string> | null
    return {
      id: e.student_id as string,
      name: student?.full_name ?? '-',
      nim: student?.nim_nip ?? '-',
    }
  }).sort((a, b) => a.name.localeCompare(b.name))

  // 5. Build session rows
  const sessionRows: RekapPDFSessionRow[] = sessionList.map(session => {
    const sessionAtt = attList.filter(a => a.session_id === session.id)
    return {
      sessionNumber: session.session_number,
      topic: session.topic ?? '-',
      date: session.started_at
        ? new Date(session.started_at).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
        : '-',
      hadir: sessionAtt.filter(a => a.status === 'hadir').length,
      terlambat: sessionAtt.filter(a => a.status === 'terlambat').length,
      izin: sessionAtt.filter(a => a.status === 'izin').length,
      sakit: sessionAtt.filter(a => a.status === 'sakit').length,
      alpa: sessionAtt.filter(a => a.status === 'alpa').length,
      total: sessionAtt.length,
    }
  })

  // 6. Build student rows with per-session attendance
  // Status initial untuk PDF tabel: H=Hadir, T=Terlambat, I=Izin, S=Sakit, A=Alpa
  const statusInitial: Record<string, string> = { hadir: 'H', terlambat: 'T', izin: 'I', sakit: 'S', alpa: 'A' }

  const studentRows: RekapPDFStudentRow[] = enrolledStudents.map(student => {
    const studentAtt = attList.filter(a => a.student_id === student.id)
    const attendanceMap: Record<number, string> = {}

    sessionList.forEach(session => {
      const att = studentAtt.find(a => a.session_id === session.id)
      attendanceMap[session.session_number] = att ? (statusInitial[att.status] ?? '-') : '-'
    })

    const totalHadir = studentAtt.filter(a => a.status === 'hadir').length
    const totalTerlambat = studentAtt.filter(a => a.status === 'terlambat').length
    const totalIzin = studentAtt.filter(a => a.status === 'izin').length
    const totalSakit = studentAtt.filter(a => a.status === 'sakit').length
    const totalAlpa = studentAtt.filter(a => a.status === 'alpa').length
    const totalRecords = totalHadir + totalTerlambat + totalIzin + totalSakit + totalAlpa

    return {
      nim: student.nim,
      name: student.name,
      attendances: attendanceMap,
      totalHadir,
      totalTerlambat,
      totalIzin,
      totalSakit,
      totalAlpa,
      // Persentase inklusif: (hadir + terlambat) / total — terlambat tetap dianggap hadir
      percentage: totalRecords > 0 ? Math.round(((totalHadir + totalTerlambat) / totalRecords) * 100) : 0,
    }
  })

  // 7. Summary
  const totalHadir = attList.filter(a => a.status === 'hadir').length
  const totalTerlambat = attList.filter(a => a.status === 'terlambat').length
  const totalIzin = attList.filter(a => a.status === 'izin').length
  const totalSakit = attList.filter(a => a.status === 'sakit').length
  const totalAlpa = attList.filter(a => a.status === 'alpa').length
  const totalAll = totalHadir + totalTerlambat + totalIzin + totalSakit + totalAlpa

  // 8. Audit log
  await logAudit({
    action: 'export_rekap_pdf',
    details: { course_id: courseId, course_code: courseInfo.code, course_name: courseInfo.name },
  })

  return {
    data: {
      course: courseInfo,
      sessions: sessionRows,
      students: studentRows,
      summary: {
        totalSesi: sessionList.length,
        totalHadir,
        totalTerlambat,
        totalIzin,
        totalSakit,
        totalAlpa,
        // rateHadir inklusif: (hadir + terlambat) / total — sesuai migration 013
        rateHadir: totalAll > 0 ? Math.round(((totalHadir + totalTerlambat) / totalAll) * 100) : 0,
      },
    },
    error: null,
  }
}
