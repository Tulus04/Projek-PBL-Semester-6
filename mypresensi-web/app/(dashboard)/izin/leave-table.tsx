'use client'
// app/(dashboard)/izin/leave-table.tsx
// Tabel persetujuan izin/sakit mahasiswa dengan aksi approve/reject.

import { useState } from 'react'
import { Check, X, Eye, MessageSquare, FileText } from 'lucide-react'
import { approveLeaveRequest, rejectLeaveRequest } from '@/lib/actions/leave-requests'
import { swal, toast } from '@/lib/swal'
import EmptyState from '@/components/ui/empty-state'

interface LeaveRequest {
  id: string
  type: string
  reason: string
  evidence_url: string | null
  status: string
  review_note: string | null
  created_at: string
  reviewed_at: string | null
  student: { id: string; full_name: string; nim_nip: string; kelas: string | null } | null
  reviewer: { full_name: string } | null
  session: {
    session_number: number
    topic: string | null
    course: { code: string; name: string } | null
  } | null
}

const statusBadge: Record<string, { label: string; className: string }> = {
  pending: { label: 'Menunggu', className: 'badge badge-warning' },
  approved: { label: 'Disetujui', className: 'badge badge-success' },
  rejected: { label: 'Ditolak', className: 'badge badge-danger' },
}

const typeBadge: Record<string, { label: string; className: string }> = {
  izin: { label: 'Izin', className: 'badge badge-neutral' },
  sakit: { label: 'Sakit', className: 'badge badge-warning' },
}

export default function LeaveTable({ requests, isReadOnly = false }: { requests: LeaveRequest[]; isReadOnly?: boolean }) {
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  const handleApprove = async (req: LeaveRequest) => {
    const { value: note } = await swal.fire({
      title: 'Setujui Pengajuan',
      html: `
        <div style="text-align:left;font-size:13px;line-height:1.6">
          <p><b>${req.student?.full_name}</b> (${req.student?.nim_nip})</p>
          <p>Tipe: <b>${req.type === 'izin' ? 'Izin' : 'Sakit'}</b></p>
          <p>Alasan: ${req.reason}</p>
        </div>
      `,
      input: 'textarea',
      inputPlaceholder: 'Catatan review (opsional)',
      inputAttributes: { rows: '3' },
      showCancelButton: true,
      confirmButtonText: 'Setujui',
      cancelButtonText: 'Batal',
    })

    if (note === undefined) return // cancelled

    setActionLoading(req.id)
    const result = await approveLeaveRequest(req.id, note || undefined)
    if (result.error) {
      swal.fire({ icon: 'error', title: 'Gagal', text: result.error })
    } else {
      toast.fire({ icon: 'success', title: 'Pengajuan disetujui' })
    }
    setActionLoading(null)
  }

  const handleReject = async (req: LeaveRequest) => {
    const { value: note } = await swal.fire({
      title: 'Tolak Pengajuan',
      html: `
        <div style="text-align:left;font-size:13px;line-height:1.6">
          <p><b>${req.student?.full_name}</b> (${req.student?.nim_nip})</p>
          <p>Tipe: <b>${req.type === 'izin' ? 'Izin' : 'Sakit'}</b></p>
          <p>Alasan: ${req.reason}</p>
        </div>
      `,
      input: 'textarea',
      inputPlaceholder: 'Alasan penolakan (opsional)',
      inputAttributes: { rows: '3' },
      showCancelButton: true,
      confirmButtonText: 'Tolak',
      cancelButtonText: 'Batal',
    })

    if (note === undefined) return

    setActionLoading(req.id)
    const result = await rejectLeaveRequest(req.id, note || undefined)
    if (result.error) {
      swal.fire({ icon: 'error', title: 'Gagal', text: result.error })
    } else {
      toast.fire({ icon: 'success', title: 'Pengajuan ditolak' })
    }
    setActionLoading(null)
  }

  if (requests.length === 0) {
    return (
      <EmptyState
        icon={FileText}
        title="Belum ada pengajuan izin/sakit"
        description={
          isReadOnly
            ? 'Pengajuan izin atau sakit dari mahasiswa akan muncul di sini setelah mereka submit lewat aplikasi mobile.'
            : 'Pengajuan dari mahasiswa pada mata kuliah Anda akan tampil di sini untuk direview.'
        }
      />
    )
  }

  return (
    <div className="overflow-x-auto">
      <table className="data-table">
        <thead>
          <tr>
            <th>Tanggal</th>
            <th>Mahasiswa</th>
            <th>Mata Kuliah</th>
            <th>Tipe</th>
            <th>Alasan</th>
            <th>Status</th>
            <th>Aksi</th>
          </tr>
        </thead>
        <tbody>
          {requests.map((req) => {
            const sBadge = statusBadge[req.status] ?? statusBadge.pending
            const tBadge = typeBadge[req.type] ?? typeBadge.izin

            return (
              <tr key={req.id}>
                <td className="text-sm tabular-nums whitespace-nowrap">
                  {new Date(req.created_at).toLocaleDateString('id-ID', {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric',
                  })}
                </td>
                <td>
                  <div>
                    <p className="text-sm font-medium text-text-primary">{req.student?.full_name ?? '-'}</p>
                    <p className="text-xs text-text-secondary">{req.student?.nim_nip ?? ''}</p>
                  </div>
                </td>
                <td className="text-sm text-text-secondary">
                  {req.session?.course ? (
                    <div>
                      <p className="font-mono text-primary font-semibold text-xs">{req.session.course.code}</p>
                      <p className="text-xs">Pertemuan {req.session.session_number}</p>
                    </div>
                  ) : '-'}
                </td>
                <td><span className={tBadge.className}>{tBadge.label}</span></td>
                <td className="text-sm text-text-secondary max-w-[200px] truncate" title={req.reason}>
                  {req.reason}
                </td>
                <td>
                  <span className={sBadge.className}>{sBadge.label}</span>
                  {req.reviewer && (
                    <p className="text-xs text-text-secondary mt-0.5">
                      oleh {req.reviewer.full_name}
                    </p>
                  )}
                </td>
                <td>
                  {actionLoading === req.id ? (
                    <div className="w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                  ) : req.status === 'pending' ? (
                    <div className="flex items-center gap-1">
                      {!isReadOnly && (
                        <>
                          <button
                            onClick={() => handleApprove(req)}
                            className="p-1.5 hover:bg-success/10 rounded-lg transition-colors"
                            title="Setujui"
                            aria-label="Setujui pengajuan"
                          >
                            <Check size={16} className="text-success" />
                          </button>
                          <button
                            onClick={() => handleReject(req)}
                            className="p-1.5 hover:bg-danger/10 rounded-lg transition-colors"
                            title="Tolak"
                            aria-label="Tolak pengajuan"
                          >
                            <X size={16} className="text-danger" />
                          </button>
                        </>
                      )}
                      {isReadOnly && (
                        <span className="text-[11px] text-text-secondary italic">
                          Menunggu review dosen
                        </span>
                      )}
                      {req.evidence_url && (
                        <a
                          href={req.evidence_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="p-1.5 hover:bg-primary/10 rounded-lg transition-colors"
                          title="Lihat bukti"
                          aria-label="Lihat bukti pendukung"
                        >
                          <Eye size={16} className="text-primary" />
                        </a>
                      )}
                    </div>
                  ) : (
                    <div className="flex items-center gap-1">
                      {req.review_note && (
                        <button
                          onClick={() => swal.fire({ title: 'Catatan Review', text: req.review_note!, icon: 'info' })}
                          className="p-1.5 hover:bg-primary/10 rounded-lg transition-colors"
                          title="Lihat catatan"
                          aria-label="Lihat catatan review"
                        >
                          <MessageSquare size={14} className="text-primary" />
                        </button>
                      )}
                      {req.evidence_url && (
                        <a
                          href={req.evidence_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="p-1.5 hover:bg-primary/10 rounded-lg transition-colors"
                          title="Lihat bukti"
                          aria-label="Lihat bukti pendukung"
                        >
                          <Eye size={14} className="text-primary" />
                        </a>
                      )}
                    </div>
                  )}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
