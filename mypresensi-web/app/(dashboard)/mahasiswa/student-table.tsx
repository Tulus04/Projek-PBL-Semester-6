'use client'
// app/(dashboard)/mahasiswa/student-table.tsx
// Tabel daftar mahasiswa dengan aksi per baris.
// Menggunakan SweetAlert2 untuk konfirmasi dan feedback.

import { useState } from 'react'
import Image from 'next/image'
import { MoreHorizontal, RotateCcw, UserCheck, UserX, Edit, Trash2, GraduationCap } from 'lucide-react'
import { toggleStudentStatusAction, resetStudentPasswordAction, deleteStudentAction } from '@/lib/actions/students'
import EditStudentModal from './edit-student-modal'
import { swal, toast, Swal } from '@/lib/swal'
import EmptyState from '@/components/ui/empty-state'

interface Student {
  id: string
  full_name: string
  nim_nip: string
  email: string | null
  semester: number | null
  kelas: string | null
  phone: string | null
  avatar_url: string | null
  is_active: boolean
  is_face_registered: boolean
  created_at: string
}

export default function StudentTable({ students }: { students: Student[] }) {
  const [openMenuId, setOpenMenuId] = useState<string | null>(null)
  const [menuPos, setMenuPos] = useState({ top: 0, left: 0 })
  const [editStudent, setEditStudent] = useState<Student | null>(null)
  const [loading, setLoading] = useState<string | null>(null)

  const handleToggleStatus = async (id: string, isActive: boolean, name: string) => {
    setOpenMenuId(null)
    setLoading(id)
    await toggleStudentStatusAction(id, isActive)
    setLoading(null)
    toast.fire({
      icon: 'success',
      title: isActive ? `${name} diaktifkan` : `${name} dinonaktifkan`,
    })
  }

  const handleResetPassword = async (s: Student) => {
    setOpenMenuId(null)
    const result = await swal.fire({
      title: 'Reset Password',
      html: `Password <b>${s.full_name}</b> akan direset menjadi:<br/><br/>
             <code style="background:#f3f4f6;padding:4px 12px;border-radius:6px;font-size:13px;">${s.nim_nip}@politani</code>`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Reset Password',
      cancelButtonText: 'Batal',
    })

    if (result.isConfirmed) {
      swal.fire({
        title: 'Mereset password...',
        allowOutsideClick: false,
        didOpen: () => Swal.showLoading(),
      })
      const res = await resetStudentPasswordAction(s.id, s.nim_nip)
      if (res.error) {
        swal.fire({ icon: 'error', title: 'Gagal', text: res.error })
      } else {
        swal.fire({
          icon: 'success',
          title: 'Berhasil!',
          html: `Password <b>${s.full_name}</b> berhasil direset menjadi:<br/><br/>
                 <code style="background:#f3f4f6;padding:4px 12px;border-radius:6px;font-size:13px;">${s.nim_nip}@politani</code>`,
        })
      }
    }
  }

  const handleDeleteStudent = async (s: Student) => {
    setOpenMenuId(null)
    const result = await swal.fire({
      title: 'Hapus Mahasiswa',
      html: `<div style="text-align:left;background:#fef2f2;border:1px solid #fecaca;border-radius:12px;padding:12px 16px;margin-bottom:12px;">
               <p style="color:#991b1b;font-weight:600;font-size:13px;margin-bottom:4px;">⚠️ Tindakan ini tidak dapat dibatalkan!</p>
               <p style="color:#b91c1c;font-size:13px;">Semua data mahasiswa berikut akan dihapus permanen.</p>
             </div>
             <div style="text-align:left;background:#f9fafb;border-radius:12px;padding:12px 16px;">
               <p style="font-weight:600;color:#1c2024;">${s.full_name}</p>
               <p style="color:#636c76;font-size:13px;margin-top:2px;">NIM: ${s.nim_nip}</p>
             </div>`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Hapus Permanen',
      cancelButtonText: 'Batal',
    })

    if (result.isConfirmed) {
      swal.fire({
        title: 'Menghapus mahasiswa...',
        allowOutsideClick: false,
        didOpen: () => Swal.showLoading(),
      })
      const res = await deleteStudentAction(s.id)
      if (res.error) {
        swal.fire({ icon: 'error', title: 'Gagal', text: res.error })
      } else {
        swal.fire({ icon: 'success', title: 'Terhapus!', text: 'Mahasiswa berhasil dihapus dari sistem.' })
      }
    }
  }

  const activeStudent = students.find((s) => s.id === openMenuId)

  if (students.length === 0) {
    return (
      <EmptyState
        icon={GraduationCap}
        title="Belum ada data mahasiswa"
        description='Tambahkan mahasiswa pertama dengan klik tombol "Tambah Mahasiswa" di pojok kanan atas, atau import dari CSV untuk batch entry.'
      />
    )
  }

  return (
    <>
      <div className="overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th>Mahasiswa</th>
              <th>NIM</th>
              <th>Semester</th>
              <th>Kelas</th>
              <th>No. HP</th>
              <th>Face</th>
              <th>Status</th>
              <th className="w-12"></th>
            </tr>
          </thead>
          <tbody>
            {students.map((s) => (
              <tr key={s.id} className={!s.is_active ? 'opacity-50' : ''}>
                <td>
                  <div className="flex items-center gap-3">
                    {s.avatar_url ? (
                      <Image
                        src={s.avatar_url}
                        alt={s.full_name}
                        width={32}
                        height={32}
                        className="w-8 h-8 rounded-full object-cover flex-shrink-0"
                        unoptimized
                      />
                    ) : (
                      <div
                        className={`w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0 ${s.is_active ? 'bg-primary' : 'bg-gray-400'}`}
                      >
                        {s.full_name.charAt(0).toUpperCase()}
                      </div>
                    )}
                    <span className="font-medium text-text-primary text-sm">
                      {s.full_name}
                    </span>
                  </div>
                </td>
                <td className="text-sm font-mono">{s.nim_nip}</td>
                <td className="text-sm text-center">{s.semester ?? '-'}</td>
                <td className="text-sm text-center">{s.kelas ? `${s.semester ?? ''}${s.kelas}` : '-'}</td>
                <td className="text-sm text-text-secondary">{s.phone ?? '-'}</td>
                <td>
                  <span className={s.is_face_registered ? 'badge badge-success' : 'badge badge-neutral'}>
                    {s.is_face_registered ? 'Terdaftar' : 'Belum'}
                  </span>
                </td>
                <td>
                  <span className={s.is_active ? 'badge badge-success' : 'badge badge-danger'}>
                    {s.is_active ? 'Aktif' : 'Nonaktif'}
                  </span>
                </td>
                <td>
                  {loading === s.id ? (
                    <div className="w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto" />
                  ) : (
                    <button
                      onClick={(e) => {
                        if (openMenuId === s.id) {
                          setOpenMenuId(null)
                        } else {
                          const rect = e.currentTarget.getBoundingClientRect()
                          setMenuPos({ top: rect.bottom + 4, left: rect.right - 192 })
                          setOpenMenuId(s.id)
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
      {openMenuId && activeStudent && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpenMenuId(null)} />
          <div
            className="fixed w-48 bg-white rounded-xl shadow-lg border border-border py-1 z-50"
            style={{ top: menuPos.top, left: menuPos.left }}
          >
            <button
              onClick={() => { setOpenMenuId(null); setEditStudent(activeStudent) }}
              className="w-full px-4 py-2.5 text-left text-sm text-text-primary hover:bg-gray-50 flex items-center gap-2.5"
            >
              <Edit size={14} /> Edit Data
            </button>
            <button
              onClick={() => handleResetPassword(activeStudent)}
              className="w-full px-4 py-2.5 text-left text-sm text-text-primary hover:bg-gray-50 flex items-center gap-2.5"
            >
              <RotateCcw size={14} /> Reset Password
            </button>
            <button
              onClick={() => handleToggleStatus(activeStudent.id, !activeStudent.is_active, activeStudent.full_name)}
              className={`w-full px-4 py-2.5 text-left text-sm hover:bg-gray-50 flex items-center gap-2.5 ${activeStudent.is_active ? 'text-danger' : 'text-success'}`}
            >
              {activeStudent.is_active ? <><UserX size={14} /> Nonaktifkan</> : <><UserCheck size={14} /> Aktifkan</>}
            </button>
            <div className="border-t border-border my-1" />
            <button
              onClick={() => handleDeleteStudent(activeStudent)}
              className="w-full px-4 py-2.5 text-left text-sm text-danger hover:bg-danger/10 flex items-center gap-2.5"
            >
              <Trash2 size={14} /> Hapus Data
            </button>
          </div>
        </>
      )}

      {/* Edit Modal */}
      {editStudent && (
        <EditStudentModal
          student={editStudent}
          onClose={() => setEditStudent(null)}
        />
      )}
    </>
  )
}
