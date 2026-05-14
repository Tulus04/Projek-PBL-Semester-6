'use client'
// app/(dashboard)/matakuliah/course-table.tsx
// Tabel mata kuliah dengan dropdown aksi: Edit, Kelola Peserta, Kelola Sesi, Toggle Status.

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { MoreHorizontal, Edit, Eye, EyeOff, Users, Calendar, BookOpen } from 'lucide-react'
import { toggleCourseStatusAction } from '@/lib/actions/courses'
import { toast } from '@/lib/swal'
import EditCourseModal from './edit-course-modal'
import EnrollmentsModal from './enrollments-modal'
import EmptyState from '@/components/ui/empty-state'

interface DosenInfo {
  id: string
  full_name: string
  nim_nip: string
}

interface Course {
  id: string
  code: string
  name: string
  sks: number
  semester: number
  dosen_id: string | null
  dosen: DosenInfo | null
  academic_year: string
  is_active: boolean
  created_at: string
}

export default function CourseTable({
  courses,
  dosenList,
  userRole = 'admin',
  userId,
}: {
  courses: Course[]
  dosenList: DosenInfo[]
  userRole?: string
  userId?: string
}) {
  const isAdmin = userRole === 'admin'
  const router = useRouter()
  const [openMenuId, setOpenMenuId] = useState<string | null>(null)
  const [menuPos, setMenuPos] = useState({ top: 0, left: 0 })
  const [editCourse, setEditCourse] = useState<Course | null>(null)
  const [enrollmentsCourse, setEnrollmentsCourse] = useState<Course | null>(null)
  const [loading, setLoading] = useState<string | null>(null)

  const handleToggleStatus = async (id: string, isActive: boolean, name: string) => {
    setLoading(id)
    setOpenMenuId(null)
    await toggleCourseStatusAction(id, isActive)
    setLoading(null)
    toast.fire({
      icon: 'success',
      title: isActive ? `${name} diaktifkan` : `${name} dinonaktifkan`,
    })
  }

  const activeCourse = courses.find((c) => c.id === openMenuId)

  if (courses.length === 0) {
    return (
      <EmptyState
        icon={BookOpen}
        title={isAdmin ? 'Belum ada mata kuliah' : 'Anda belum mengampu mata kuliah'}
        description={
          isAdmin
            ? 'Tambahkan mata kuliah pertama dengan klik tombol "Tambah Mata Kuliah" di pojok kanan atas. Anda bisa menetapkan dosen pengampu setelah mata kuliah dibuat.'
            : 'Daftarkan mata kuliah yang Anda ampu agar bisa membuat sesi presensi dan mengelola kehadiran mahasiswa.'
        }
      />
    )
  }

  return (
    <>
      <div className="overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th>Kode MK</th>
              <th>Nama Mata Kuliah</th>
              <th className="text-center">SKS</th>
              <th className="text-center">Semester</th>
              <th>Dosen Pengampu</th>
              <th>Tahun Akademik</th>
              <th>Status</th>
              <th className="w-12"></th>
            </tr>
          </thead>
          <tbody>
            {courses.map((c) => (
              <tr key={c.id} className={!c.is_active ? 'opacity-50' : ''}>
                <td className="font-mono text-sm font-semibold text-primary">{c.code}</td>
                <td className="text-sm font-medium text-text-primary">{c.name}</td>
                <td className="text-center text-sm">{c.sks}</td>
                <td className="text-center text-sm">{c.semester}</td>
                <td className="text-sm text-text-secondary">
                  {c.dosen ? (
                    <div className="flex items-center gap-2">
                      <div className="w-6 h-6 rounded-full flex items-center justify-center text-white text-[10px] font-bold flex-shrink-0 bg-primary">
                        {c.dosen.full_name.charAt(0).toUpperCase()}
                      </div>
                      <span>{c.dosen.full_name}</span>
                    </div>
                  ) : (
                    <span className="text-text-secondary italic">Belum ditentukan</span>
                  )}
                </td>
                <td className="text-sm text-text-secondary">{c.academic_year}</td>
                <td>
                  <span className={c.is_active ? 'badge badge-success' : 'badge badge-danger'}>
                    {c.is_active ? 'Aktif' : 'Nonaktif'}
                  </span>
                </td>
                <td>
                  {loading === c.id ? (
                    <div className="w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto" />
                  ) : (
                    <button
                      onClick={(e) => {
                        if (openMenuId === c.id) {
                          setOpenMenuId(null)
                        } else {
                          const rect = e.currentTarget.getBoundingClientRect()
                          setMenuPos({ top: rect.bottom + 4, left: rect.right - 192 })
                          setOpenMenuId(c.id)
                        }
                      }}
                      className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-gray-100 transition-colors"
                    >
                      <MoreHorizontal size={16} className="text-text-secondary" />
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Fixed Dropdown Menu */}
      {openMenuId && activeCourse && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpenMenuId(null)} />
          <div
            className="fixed w-48 bg-white rounded-xl shadow-lg border border-border py-1 z-50"
            style={{ top: menuPos.top, left: menuPos.left }}
          >
            {/* Edit Data — admin atau dosen pemilik MK */}
            {(isAdmin || (userId && activeCourse.dosen_id === userId)) && (
              <button
                onClick={() => {
                  setOpenMenuId(null)
                  setEditCourse(activeCourse)
                }}
                className="w-full px-4 py-2.5 text-left text-sm text-text-primary hover:bg-gray-50 flex items-center gap-2.5"
              >
                <Edit size={14} /> Edit Data
              </button>
            )}
            {/* Kelola Peserta — admin atau dosen pemilik MK */}
            {(isAdmin || (userId && activeCourse.dosen_id === userId)) && (
              <button
                onClick={() => {
                  setOpenMenuId(null)
                  setEnrollmentsCourse(activeCourse)
                }}
                className="w-full px-4 py-2.5 text-left text-sm text-text-primary hover:bg-gray-50 flex items-center gap-2.5"
              >
                <Users size={14} /> Kelola Peserta
              </button>
            )}
            {/* Kelola Sesi — redirect ke /sesi?course_id=xxx (single entry point) */}
            <button
              onClick={() => {
                setOpenMenuId(null)
                router.push(`/sesi?course_id=${activeCourse.id}`)
              }}
              className="w-full px-4 py-2.5 text-left text-sm text-text-primary hover:bg-gray-50 flex items-center gap-2.5"
            >
              <Calendar size={14} /> Kelola Sesi
            </button>
            {/* Toggle Status — admin atau dosen pemilik MK */}
            {(isAdmin || (userId && activeCourse.dosen_id === userId)) && (
              <>
                <div className="border-t border-border my-1" />
                <button
                  onClick={() => handleToggleStatus(activeCourse.id, !activeCourse.is_active, activeCourse.name)}
                  className={`w-full px-4 py-2.5 text-left text-sm hover:bg-gray-50 flex items-center gap-2.5 ${activeCourse.is_active ? 'text-danger' : 'text-success'}`}
                >
                  {activeCourse.is_active ? (
                    <>
                      <EyeOff size={14} /> Nonaktifkan
                    </>
                  ) : (
                    <>
                      <Eye size={14} /> Aktifkan
                    </>
                  )}
                </button>
              </>
            )}
          </div>
        </>
      )}

      {/* Edit Modal */}
      {editCourse && (
        <EditCourseModal
          course={editCourse}
          dosenList={dosenList}
          userRole={userRole}
          onClose={() => setEditCourse(null)}
        />
      )}

      {/* Enrollments Modal */}
      {enrollmentsCourse && (
        <EnrollmentsModal
          courseId={enrollmentsCourse.id}
          courseName={`${enrollmentsCourse.code} — ${enrollmentsCourse.name}`}
          onClose={() => setEnrollmentsCourse(null)}
        />
      )}
    </>
  )
}
