'use client'
// app/(dashboard)/matakuliah/session-detail-modal.tsx
// Modal detail presensi per sesi — menampilkan daftar mahasiswa yang enrolled
// beserta status kehadirannya (hadir/izin/sakit/alpa/belum absen).

import { useEffect, useState, useCallback } from 'react'
import { X, ClipboardList, CheckCircle, AlertTriangle, XCircle, Clock, MapPin, Scan } from 'lucide-react'
import { getSessionDetail } from '@/lib/actions/sessions'
import type { SessionDetailData } from '@/lib/actions/sessions'

interface Props {
  sessionId: string
  courseName: string
  onClose: () => void
}

const statusConfig = {
  hadir: { label: 'Hadir', className: 'badge badge-success', icon: CheckCircle },
  terlambat: { label: 'Terlambat', className: 'badge badge-warning', icon: Clock },
  izin: { label: 'Izin', className: 'badge badge-warning', icon: AlertTriangle },
  sakit: { label: 'Sakit', className: 'badge badge-warning', icon: AlertTriangle },
  alpa: { label: 'Alpa', className: 'badge badge-danger', icon: XCircle },
  belum: { label: 'Belum Absen', className: 'badge', icon: Clock },
} as const

export default function SessionDetailModal({ sessionId, courseName, onClose }: Props) {
  const [data, setData] = useState<SessionDetailData | null>(null)
  const [loading, setLoading] = useState(true)

  const loadData = useCallback(async () => {
    setLoading(true)
    const result = await getSessionDetail(sessionId)
    if (result.data) setData(result.data)
    setLoading(false)
  }, [sessionId])

  useEffect(() => { loadData() }, [loadData])

  // Auto-refresh setiap 10 detik saat sesi aktif
  useEffect(() => {
    if (!data?.session.is_active) return
    const interval = setInterval(loadData, 10000)
    return () => clearInterval(interval)
  }, [data?.session.is_active, loadData])

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onClick={onClose}>
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="px-6 py-4 border-b border-border flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center">
              <ClipboardList size={18} className="text-primary" />
            </div>
            <div>
              <h3 className="text-base font-bold text-text-primary">Detail Presensi</h3>
              <p className="text-xs text-text-secondary">{courseName}</p>
            </div>
          </div>
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors">
            <X size={18} className="text-text-secondary" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {loading ? (
            <div className="flex items-center justify-center py-16">
              <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
            </div>
          ) : !data ? (
            <p className="text-center text-text-secondary py-8">Data tidak tersedia.</p>
          ) : (
            <>
              {/* Session Info Bar */}
              <div className="bg-gray-50 border border-border rounded-lg p-4 mb-4">
                <div className="flex items-center justify-between flex-wrap gap-2">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-white border border-border flex items-center justify-center">
                      <span className="text-sm font-bold text-text-primary">{data.session.session_number}</span>
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-text-primary">
                        Pertemuan {data.session.session_number}
                      </p>
                      <p className="text-xs text-text-secondary">
                        {data.session.topic || 'Tidak ada topik'}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={data.session.mode === 'offline' ? 'badge badge-success' : 'badge badge-warning'}>
                      {data.session.mode === 'offline' ? 'Tatap Muka' : 'Daring'}
                    </span>
                    {data.session.is_active && (
                      <span className="badge badge-success" style={{ animation: 'pulse 2s infinite' }}>
                        Sedang Berlangsung
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {/* Summary Cards — 7 kolom (Total/Hadir/Terlambat/Izin/Sakit/Alpa/Belum) */}
              <div className="grid grid-cols-3 md:grid-cols-7 gap-2 mb-4">
                <div className="text-center p-3 bg-gray-50 rounded-lg border border-border">
                  <p className="text-lg font-bold text-text-primary">{data.summary.total}</p>
                  <p className="text-[10px] text-text-secondary uppercase font-medium">Total</p>
                </div>
                <div className="text-center p-3 rounded-lg bg-success/10 border border-success/20">
                  <p className="text-lg font-bold text-success">{data.summary.hadir}</p>
                  <p className="text-[10px] uppercase font-medium text-success">Hadir</p>
                </div>
                <div className="text-center p-3 rounded-lg" style={{ backgroundColor: 'rgba(217,119,6,0.1)', borderColor: 'rgba(217,119,6,0.2)', borderWidth: '1px' }}>
                  <p className="text-lg font-bold" style={{ color: '#D97706' }}>{data.summary.terlambat}</p>
                  <p className="text-[10px] uppercase font-medium" style={{ color: '#D97706' }}>Terlambat</p>
                </div>
                <div className="text-center p-3 rounded-lg bg-warning/10 border border-warning/20">
                  <p className="text-lg font-bold text-warning">{data.summary.izin}</p>
                  <p className="text-[10px] uppercase font-medium text-warning">Izin</p>
                </div>
                <div className="text-center p-3 rounded-lg bg-warning/10 border border-warning/20">
                  <p className="text-lg font-bold text-warning">{data.summary.sakit}</p>
                  <p className="text-[10px] uppercase font-medium text-warning">Sakit</p>
                </div>
                <div className="text-center p-3 rounded-lg bg-danger/10 border border-danger/20">
                  <p className="text-lg font-bold text-danger">{data.summary.alpa}</p>
                  <p className="text-[10px] uppercase font-medium text-danger">Alpa</p>
                </div>
                <div className="text-center p-3 bg-gray-50 rounded-lg border border-border">
                  <p className="text-lg font-bold text-text-secondary">{data.summary.belumAbsen}</p>
                  <p className="text-[10px] text-text-secondary uppercase font-medium">Belum</p>
                </div>
              </div>

              {/* Attendance Table */}
              <div className="border border-border rounded-lg overflow-hidden">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th className="w-8">#</th>
                      <th>Mahasiswa</th>
                      <th>Status</th>
                      <th>Waktu</th>
                      <th>
                        <span className="flex items-center gap-1"><MapPin size={12} /> Jarak</span>
                      </th>
                      <th>
                        <span className="flex items-center gap-1"><Scan size={12} /> Face</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {/* Daftar yang sudah scan */}
                    {data.attendances.map((att, i) => {
                      const config = statusConfig[att.status as keyof typeof statusConfig] ?? statusConfig.belum
                      return (
                        <tr key={att.id}>
                          <td className="text-xs text-text-secondary">{i + 1}</td>
                          <td>
                            <div>
                              <p className="text-sm font-medium text-text-primary">{att.student_name}</p>
                              <p className="text-xs text-text-secondary">{att.student_nim}</p>
                            </div>
                          </td>
                          <td>
                            <span className={config.className}>{config.label}</span>
                          </td>
                          <td className="text-sm text-text-secondary tabular-nums">
                            {att.scanned_at
                              ? new Date(att.scanned_at).toLocaleTimeString('id-ID', {
                                  hour: '2-digit',
                                  minute: '2-digit',
                                  second: '2-digit',
                                })
                              : '-'}
                          </td>
                          <td className="text-sm tabular-nums">
                            {att.distance_meters != null ? (
                              <span className={att.is_location_valid ? 'text-success' : 'text-danger'}>
                                {Math.round(att.distance_meters)}m
                              </span>
                            ) : '-'}
                          </td>
                          <td className="text-sm tabular-nums">
                            {att.face_confidence != null ? (
                              <span className={att.face_confidence >= 0.75 ? 'text-success' : 'text-warning'}>
                                {(att.face_confidence * 100).toFixed(0)}%
                              </span>
                            ) : '-'}
                          </td>
                        </tr>
                      )
                    })}

                    {/* Mahasiswa enrolled yang belum scan */}
                    {data.enrolledStudents
                      .filter((s) => !data.attendances.some((a) => a.student_id === s.id))
                      .map((student, i) => (
                        <tr key={student.id} className="opacity-50">
                          <td className="text-xs text-text-secondary">
                            {data.attendances.length + i + 1}
                          </td>
                          <td>
                            <div>
                              <p className="text-sm font-medium text-text-primary">{student.full_name}</p>
                              <p className="text-xs text-text-secondary">{student.nim_nip}</p>
                            </div>
                          </td>
                          <td>
                            <span className="badge">Belum Absen</span>
                          </td>
                          <td className="text-sm text-text-secondary">-</td>
                          <td className="text-sm text-text-secondary">-</td>
                          <td className="text-sm text-text-secondary">-</td>
                        </tr>
                      ))}

                    {data.enrolledStudents.length === 0 && data.attendances.length === 0 && (
                      <tr>
                        <td colSpan={6} className="text-center py-8 text-text-secondary text-sm">
                          Belum ada mahasiswa yang terdaftar di kelas ini.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
