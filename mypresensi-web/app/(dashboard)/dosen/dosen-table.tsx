'use client'
// app/(dashboard)/dosen/dosen-table.tsx
// Tabel daftar dosen dengan aksi per baris.
// Menggunakan SweetAlert2 untuk konfirmasi dan feedback.

import { useState } from 'react'
import Image from 'next/image'
import { MoreHorizontal, RotateCcw, UserCheck, UserX, Edit, Trash2, UserCog } from 'lucide-react'
import { toggleDosenStatusAction, resetDosenPasswordAction, deleteDosenAction } from '@/lib/actions/dosen'
import EditDosenModal from './edit-dosen-modal'
import { swal, toast, Swal } from '@/lib/swal'
import EmptyState from '@/components/ui/empty-state'

interface Dosen {
  id: string
  full_name: string
  nim_nip: string
  email: string | null
  phone: string | null
  avatar_url: string | null
  is_active: boolean
  created_at: string
}

export default function DosenTable({ dosen }: { dosen: Dosen[] }) {
  const [openMenuId, setOpenMenuId] = useState<string | null>(null)
  const [menuPos, setMenuPos] = useState({ top: 0, left: 0 })
  const [editDosen, setEditDosen] = useState<Dosen | null>(null)
  const [loading, setLoading] = useState<string | null>(null)

  const handleToggleStatus = async (id: string, isActive: boolean, name: string) => {
    setOpenMenuId(null)
    setLoading(id)
    await toggleDosenStatusAction(id, isActive)
    setLoading(null)
    toast.fire({
      icon: 'success',
      title: isActive ? `${name} diaktifkan` : `${name} dinonaktifkan`,
    })
  }

  const handleResetPassword = async (d: Dosen) => {
    setOpenMenuId(null)
    const result = await swal.fire({
      title: 'Reset Password',
      html: `Password <b>${d.full_name}</b> akan direset menjadi:<br/><br/>
             <code style="background:#f3f4f6;padding:4px 12px;border-radius:6px;font-size:13px;">${d.nim_nip}@politani</code>`,
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
      const res = await resetDosenPasswordAction(d.id, d.nim_nip)
      if (res.error) {
        swal.fire({ icon: 'error', title: 'Gagal', text: res.error })
      } else {
        swal.fire({
          icon: 'success',
          title: 'Berhasil!',
          html: `Password <b>${d.full_name}</b> berhasil direset menjadi:<br/><br/>
                 <code style="background:#f3f4f6;padding:4px 12px;border-radius:6px;font-size:13px;">${d.nim_nip}@politani</code>`,
        })
      }
    }
  }

  const handleDeleteDosen = async (d: Dosen) => {
    setOpenMenuId(null)
    const result = await swal.fire({
      title: 'Hapus Dosen',
      html: `<div style="text-align:left;background:#fef2f2;border:1px solid #fecaca;border-radius:12px;padding:12px 16px;margin-bottom:12px;">
               <p style="color:#991b1b;font-weight:600;font-size:13px;margin-bottom:4px;">⚠️ Tindakan ini tidak dapat dibatalkan!</p>
               <p style="color:#b91c1c;font-size:13px;">Semua data dosen berikut akan dihapus permanen.</p>
             </div>
             <div style="text-align:left;background:#f9fafb;border-radius:12px;padding:12px 16px;">
               <p style="font-weight:600;color:#1c2024;">${d.full_name}</p>
               <p style="color:#636c76;font-size:13px;margin-top:2px;">NIP: ${d.nim_nip}</p>
             </div>`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Hapus Permanen',
      cancelButtonText: 'Batal',
      customClass: {
        confirmButton: 'swal-btn-confirm',
        cancelButton: 'swal-btn-cancel',
        popup: 'swal-popup-custom',
      },
    })

    if (result.isConfirmed) {
      swal.fire({
        title: 'Menghapus dosen...',
        allowOutsideClick: false,
        didOpen: () => Swal.showLoading(),
      })
      const res = await deleteDosenAction(d.id)
      if (res.error) {
        swal.fire({ icon: 'error', title: 'Gagal', text: res.error })
      } else {
        swal.fire({ icon: 'success', title: 'Terhapus!', text: 'Dosen berhasil dihapus dari sistem.' })
      }
    }
  }

  const activeDosen = dosen.find((d) => d.id === openMenuId)

  if (dosen.length === 0) {
    return (
      <EmptyState
        icon={UserCog}
        title="Belum ada data dosen"
        description='Tambahkan dosen pengampu pertama dengan klik tombol "Tambah Dosen" di pojok kanan atas.'
      />
    )
  }

  return (
    <>
      <div className="overflow-x-auto">
        <table className="data-table">
          <thead>
            <tr>
              <th>Dosen</th>
              <th>NIP</th>
              <th>No. HP</th>
              <th>Status</th>
              <th className="w-12"></th>
            </tr>
          </thead>
          <tbody>
            {dosen.map((d) => (
              <tr key={d.id} className={!d.is_active ? 'opacity-50' : ''}>
                <td>
                  <div className="flex items-center gap-3">
                    {d.avatar_url ? (
                      <Image
                        src={d.avatar_url}
                        alt={d.full_name}
                        width={32}
                        height={32}
                        className="w-8 h-8 rounded-full object-cover flex-shrink-0"
                        unoptimized
                      />
                    ) : (
                      <div
                        className={`w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0 ${d.is_active ? 'bg-primary' : 'bg-gray-400'}`}
                      >
                        {d.full_name.charAt(0).toUpperCase()}
                      </div>
                    )}
                    <span className="font-medium text-text-primary text-sm">
                      {d.full_name}
                    </span>
                  </div>
                </td>
                <td className="text-sm font-mono">{d.nim_nip}</td>
                <td className="text-sm text-text-secondary">{d.phone ?? '-'}</td>
                <td>
                  <span
                    className={
                      d.is_active
                        ? 'badge badge-success'
                        : 'badge badge-danger'
                    }
                  >
                    {d.is_active ? 'Aktif' : 'Nonaktif'}
                  </span>
                </td>
                <td>
                  {loading === d.id ? (
                    <div className="w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto" />
                  ) : (
                    <button
                      onClick={(e) => {
                        if (openMenuId === d.id) {
                          setOpenMenuId(null)
                        } else {
                          const rect = e.currentTarget.getBoundingClientRect()
                          setMenuPos({ top: rect.bottom + 4, left: rect.right - 192 })
                          setOpenMenuId(d.id)
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
      {openMenuId && activeDosen && (
        <>
          <div
            className="fixed inset-0 z-40"
            onClick={() => setOpenMenuId(null)}
          />
          <div
            className="fixed w-48 bg-white rounded-xl shadow-lg border border-border py-1 z-50"
            style={{ top: menuPos.top, left: menuPos.left }}
          >
            <button
              onClick={() => {
                setOpenMenuId(null)
                setEditDosen(activeDosen)
              }}
              className="w-full px-4 py-2.5 text-left text-sm text-text-primary hover:bg-gray-50 flex items-center gap-2.5"
            >
              <Edit size={14} /> Edit Data
            </button>
            <button
              onClick={() => handleResetPassword(activeDosen)}
              className="w-full px-4 py-2.5 text-left text-sm text-text-primary hover:bg-gray-50 flex items-center gap-2.5"
            >
              <RotateCcw size={14} /> Reset Password
            </button>
            <button
              onClick={() => handleToggleStatus(activeDosen.id, !activeDosen.is_active, activeDosen.full_name)}
              className={`w-full px-4 py-2.5 text-left text-sm hover:bg-gray-50 flex items-center gap-2.5 ${activeDosen.is_active ? 'text-danger' : 'text-success'}`}
            >
              {activeDosen.is_active ? (
                <>
                  <UserX size={14} /> Nonaktifkan
                </>
              ) : (
                <>
                  <UserCheck size={14} /> Aktifkan
                </>
              )}
            </button>
            <div className="border-t border-border my-1" />
            <button
              onClick={() => handleDeleteDosen(activeDosen)}
              className="w-full px-4 py-2.5 text-left text-sm text-danger hover:bg-danger/10 flex items-center gap-2.5"
            >
              <Trash2 size={14} /> Hapus Data
            </button>
          </div>
        </>
      )}

      {/* Edit Modal */}
      {editDosen && (
        <EditDosenModal
          dosen={editDosen}
          onClose={() => setEditDosen(null)}
        />
      )}
    </>
  )
}
