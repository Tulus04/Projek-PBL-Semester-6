'use client'
// app/(dashboard)/matakuliah/sessions-modal.tsx
// Modal untuk mengelola sesi perkuliahan per mata kuliah.
// Termasuk tampilan QR rolling + countdown timer saat sesi aktif.

import { useEffect, useState, useCallback, useRef } from 'react'
import {
  X, Plus, Trash2, PlayCircle, StopCircle, Calendar,
  ClipboardList, QrCode, Maximize2, Activity
} from 'lucide-react'
import { QRCodeSVG } from 'qrcode.react'
import {
  getSessionsByCourse,
  addSessionAction,
  toggleSessionAction,
  deleteSessionAction,
  refreshSessionCode,
} from '@/lib/actions/sessions'
import { swal, toast } from '@/lib/swal'
import SessionDetailModal from './session-detail-modal'
import { getFriendlyErrorMessage } from '@/lib/utils'

interface Props {
  courseId: string
  courseName: string
  dosenId: string | null
  onClose: () => void
}

interface Session {
  id: string
  session_number: number
  topic: string | null
  mode: string
  session_code: string | null
  session_code_expires_at: string | null
  is_active: boolean
  started_at: string | null
  ended_at: string | null
  attendance_count: { count: number }[]
}

export default function SessionsModal({ courseId, courseName, dosenId, onClose }: Props) {
  const [sessions, setSessions] = useState<Session[]>([])
  const [loading, setLoading] = useState(true)
  const [showAddForm, setShowAddForm] = useState(false)
  const [adding, setAdding] = useState(false)
  const [actionLoading, setActionLoading] = useState<string | null>(null)
  const [detailSessionId, setDetailSessionId] = useState<string | null>(null)

  // Countdown state
  const [countdown, setCountdown] = useState<number>(0)
  const countdownRef = useRef<NodeJS.Timeout | null>(null)

  const loadData = useCallback(async () => {
    setLoading(true)
    try {
      const { sessions: data } = await getSessionsByCourse(courseId)
      setSessions(data as Session[])
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal Memuat',
        text: getFriendlyErrorMessage(err, 'Gagal memuat data sesi perkuliahan.'),
      })
    } finally {
      setLoading(false)
    }
  }, [courseId])

  useEffect(() => { loadData() }, [loadData])

  // Cari sesi yang sedang aktif
  const activeSession = sessions.find((s) => s.is_active)

  // Countdown timer effect
  useEffect(() => {
    if (countdownRef.current) clearInterval(countdownRef.current)

    if (!activeSession?.session_code_expires_at) {
      setCountdown(0)
      return
    }

    const tick = () => {
      const diff = Math.max(
        0,
        Math.floor((new Date(activeSession.session_code_expires_at!).getTime() - Date.now()) / 1000)
      )
      setCountdown(diff)

      // Auto-refresh QR jika expired
      if (diff === 0 && activeSession.is_active) {
        handleRefreshCode(activeSession.id)
      }
    }

    tick()
    countdownRef.current = setInterval(tick, 1000)
    return () => { if (countdownRef.current) clearInterval(countdownRef.current) }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeSession?.session_code_expires_at, activeSession?.is_active])

  const handleAddSession = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setAdding(true)
    const formData = new FormData(e.currentTarget)
    try {
      const result = await addSessionAction(courseId, dosenId, formData)
      if (result.success) {
        toast.fire({ icon: 'success', title: 'Sesi berhasil ditambahkan' })
        setShowAddForm(false)
        loadData()
      } else {
        swal.fire({ icon: 'error', title: 'Gagal', text: result.error ?? '' })
      }
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal',
        text: getFriendlyErrorMessage(err, 'Gagal menambahkan sesi.'),
      })
    } finally {
      setAdding(false)
    }
  }

  const handleToggle = async (session: Session) => {
    if (session.is_active) {
      // Konfirmasi akhiri sesi
      const confirm = await swal.fire({
        title: 'Akhiri Sesi?',
        html: `Pertemuan <b>${session.session_number}</b> akan diakhiri. Kode sesi akan dihapus.`,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Akhiri',
        cancelButtonText: 'Batal',
      })
      if (!confirm.isConfirmed) return
    }

    setActionLoading(session.id)
    try {
      const result = await toggleSessionAction(session.id, !session.is_active)
      if (result.error) {
        swal.fire({ icon: 'error', title: 'Gagal', text: result.error })
      } else {
        toast.fire({
          icon: 'success',
          title: session.is_active ? 'Sesi diakhiri' : 'Sesi dimulai — kode presensi aktif',
        })
        loadData()
      }
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal',
        text: getFriendlyErrorMessage(err, 'Gagal mengubah status sesi.'),
      })
    } finally {
      setActionLoading(null)
    }
  }

  const handleRefreshCode = async (sessionId: string) => {
    try {
      const result = await refreshSessionCode(sessionId)
      if (result.error) {
        toast.fire({ icon: 'error', title: result.error })
      } else {
        loadData()
      }
    } catch (err) {
      toast.fire({
        icon: 'error',
        title: getFriendlyErrorMessage(err, 'Koneksi terputus'),
      })
    }
  }

  const handleDelete = async (session: Session) => {
    const result = await swal.fire({
      title: 'Hapus Sesi',
      html: `Pertemuan <b>${session.session_number}</b> akan dihapus permanen.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Hapus',
      cancelButtonText: 'Batal',
    })
    if (!result.isConfirmed) return

    setActionLoading(session.id)
    try {
      const res = await deleteSessionAction(session.id)
      if (res.error) {
        swal.fire({ icon: 'error', title: 'Gagal', text: res.error })
      } else {
        toast.fire({ icon: 'success', title: 'Sesi dihapus' })
        loadData()
      }
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal',
        text: getFriendlyErrorMessage(err, 'Gagal menghapus sesi.'),
      })
    } finally {
      setActionLoading(null)
    }
  }

  // Format countdown mm:ss
  const formatCountdown = (seconds: number) => {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
  }

  // Next session number suggestion
  const nextNumber = sessions.length > 0 ? Math.max(...sessions.map((s) => s.session_number)) + 1 : 1

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onClick={onClose}>
        <div
          className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[85vh] flex flex-col"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="px-6 py-4 border-b border-border flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center">
                <Calendar size={18} className="text-primary" />
              </div>
              <div>
                <h3 className="text-base font-bold text-text-primary">Kelola Sesi</h3>
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
              <div className="flex items-center justify-center py-12">
                <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
              </div>
            ) : (
              <>
                {/* ======================== */}
                {/* ACTIVE SESSION CODE CARD */}
                {/* ======================== */}
                {activeSession && activeSession.session_code && (
                  <div
                    className="rounded-xl p-5 mb-5 border-2"
                    style={{
                      background: 'linear-gradient(135deg, rgba(26,127,55,0.04) 0%, rgba(84,131,173,0.04) 100%)',
                      borderColor: 'rgba(26,127,55,0.25)',
                    }}
                  >
                    {/* Header */}
                    <div className="flex items-center justify-between mb-4">
                      <div className="flex items-center gap-2">
                        <div
                          className="w-2 h-2 rounded-full bg-success"
                          style={{ animation: 'pulse 2s infinite' }}
                        />
                        <span className="text-xs font-semibold uppercase tracking-wider text-success">
                          Sesi {activeSession.session_number} — Sedang Berlangsung
                        </span>
                      </div>
                      <span className="text-xs text-text-secondary">
                        {activeSession.topic}
                      </span>
                    </div>

                    {/* QR Code Display */}
                    <div className="flex flex-col items-center mb-4">
                      <div className="bg-white p-3 rounded-xl border border-border shadow-sm mb-2">
                        <QRCodeSVG
                          value={JSON.stringify({
                            sid: activeSession.id,
                            code: activeSession.session_code,
                            exp: activeSession.session_code_expires_at,
                          })}
                          size={180}
                          level="H"
                          includeMargin={false}
                          bgColor="#FFFFFF"
                          fgColor="#1a1a2e"
                        />
                      </div>
                      <div className="flex items-center gap-1.5 text-xs text-text-secondary">
                        <QrCode size={12} />
                        <span>Arahkan kamera HP ke QR Code</span>
                      </div>
                    </div>

                    {/* OTP Display dihilangkan (Phase 3 v7) — code di payload QR
                        TIDAK dipakai user input, mahasiswa scan QR otomatis.
                        Dosen tidak perlu lihat angka 6-digit. Kode rolling tetap
                        ada di payload QR untuk server verify (TOTP). */}

                    {/* Countdown */}
                    <div className="text-center mb-3">
                      <span
                        className={`text-sm font-medium ${countdown <= 30 ? 'text-danger' : 'text-text-secondary'}`}
                      >
                        QR berganti dalam: {formatCountdown(countdown)}
                      </span>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex items-center justify-center gap-2 flex-wrap">
                      {/* Primary — pemantauan real-time */}
                      <a
                        href={`/sesi/${activeSession.id}/live`}
                        className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg text-white transition-colors bg-primary hover:bg-primary-hover"
                      >
                        <Activity size={13} /> Live Monitor
                      </a>
                      {/* Secondary — outline */}
                      <a
                        href={`/sesi/${activeSession.id}/qr`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg border border-primary/30 bg-primary/5 text-primary hover:bg-primary/10 transition-colors"
                      >
                        <Maximize2 size={13} /> Tampilkan Fullscreen
                      </a>
                      <button
                        onClick={() => setDetailSessionId(activeSession.id)}
                        className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg border border-primary/30 bg-primary/5 text-primary hover:bg-primary/10 transition-colors"
                      >
                        <ClipboardList size={13} /> Lihat Detail
                      </button>
                      {/* Destructive — danger outline */}
                      <button
                        onClick={() => handleToggle(activeSession)}
                        className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg border border-danger/30 bg-danger/5 text-danger hover:bg-danger/10 transition-colors"
                      >
                        <StopCircle size={13} /> Akhiri
                      </button>
                    </div>
                  </div>
                )}

                <div className="flex items-center justify-between mb-3">
                  <h4 className="text-sm font-semibold text-text-primary">
                    {sessions.length} Sesi Perkuliahan
                  </h4>
                  <button
                    onClick={() => setShowAddForm(!showAddForm)}
                    className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5"
                  >
                    <Plus size={14} /> Tambah Sesi
                  </button>
                </div>

                {/* Add Form */}
                {showAddForm && (
                  <form onSubmit={handleAddSession} className="border border-primary/20 bg-primary/5 rounded-lg p-4 mb-4">
                    <h4 className="text-sm font-semibold text-text-primary mb-3">Sesi Baru</h4>
                    <div className="grid grid-cols-2 gap-3 mb-3">
                      <div>
                        <label className="form-label">Pertemuan Ke</label>
                        <input
                          name="session_number"
                          type="number"
                          defaultValue={nextNumber}
                          min={1}
                          max={16}
                          className="input-field w-full"
                          required
                        />
                      </div>
                      <div>
                        <label className="form-label">Mode</label>
                        <select name="mode" className="input-field w-full" defaultValue="offline">
                          <option value="offline">Tatap Muka (Offline)</option>
                          <option value="online">Daring (Online)</option>
                        </select>
                      </div>
                    </div>
                    <div className="mb-3">
                      <label className="form-label">Topik / Materi</label>
                      <input
                        name="topic"
                        type="text"
                        placeholder="Contoh: Pengenalan HTML & CSS"
                        className="input-field w-full"
                        required
                      />
                    </div>
                    <div className="flex justify-end gap-2">
                      <button type="button" onClick={() => setShowAddForm(false)} className="px-3 py-2 text-sm border border-border rounded-lg hover:bg-gray-50">
                        Batal
                      </button>
                      <button type="submit" disabled={adding} className="btn-primary text-sm flex items-center gap-2">
                        {adding ? (
                          <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                        ) : (
                          <Plus size={14} />
                        )}
                        Simpan
                      </button>
                    </div>
                  </form>
                )}

                {/* Sessions List */}
                {sessions.length === 0 ? (
                  <p className="text-sm text-text-secondary italic py-4 text-center">
                    Belum ada sesi perkuliahan.
                  </p>
                ) : (
                  <div className="space-y-2">
                    {sessions.map((s) => {
                      const attCount = s.attendance_count?.[0]?.count ?? 0
                      return (
                        <div
                          key={s.id}
                          className="border rounded-lg p-3 hover:bg-gray-50 transition-colors"
                          style={{
                            borderColor: s.is_active ? 'rgba(26,127,55,0.3)' : 'var(--color-border)',
                            backgroundColor: s.is_active ? 'rgba(26,127,55,0.02)' : undefined,
                          }}
                        >
                          <div className="flex items-center justify-between">
                            <div className="flex items-center gap-3 flex-1 min-w-0">
                              <div
                                className="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0"
                                style={{
                                  backgroundColor: s.is_active ? 'rgba(26,127,55,0.1)' : '#f3f4f6',
                                }}
                              >
                                <span
                                  className={`text-sm font-bold ${s.is_active ? 'text-success' : 'text-text-primary'}`}
                                >
                                  {s.session_number}
                                </span>
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="text-sm font-medium text-text-primary truncate">
                                  {s.topic || 'Tidak ada topik'}
                                </p>
                                <div className="flex items-center gap-2 mt-0.5">
                                  <span className={s.mode === 'offline' ? 'badge badge-success' : 'badge badge-warning'}>
                                    {s.mode === 'offline' ? 'Tatap Muka' : 'Daring'}
                                  </span>
                                  <span className="text-xs text-text-secondary">
                                    {attCount} presensi
                                  </span>
                                  {s.started_at && (
                                    <span className="text-xs text-text-secondary">
                                      · {new Date(s.started_at).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' })}
                                    </span>
                                  )}
                                  {s.is_active && (
                                    <span
                                      className="inline-block w-1.5 h-1.5 rounded-full bg-success"
                                      style={{ animation: 'pulse 2s infinite' }}
                                    />
                                  )}
                                </div>
                              </div>
                            </div>

                            <div className="flex items-center gap-1">
                              {actionLoading === s.id ? (
                                <div className="w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                              ) : (
                                <>
                                  {/* Detail button */}
                                  <button
                                    onClick={() => setDetailSessionId(s.id)}
                                    className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors"
                                    title="Lihat detail presensi"
                                    aria-label="Lihat detail presensi"
                                  >
                                    <ClipboardList size={15} className="text-primary" />
                                  </button>
                                  {/* Start/Stop */}
                                  <button
                                    onClick={() => handleToggle(s)}
                                    className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors"
                                    title={s.is_active ? 'Akhiri sesi' : 'Mulai sesi'}
                                  >
                                    {s.is_active ? (
                                      <StopCircle size={16} className="text-danger" />
                                    ) : (
                                      <PlayCircle size={16} className="text-success" />
                                    )}
                                  </button>
                                  {/* Delete — hanya jika sesi TIDAK aktif */}
                                  {!s.is_active && (
                                    <button
                                      onClick={() => handleDelete(s)}
                                      className="p-1.5 hover:bg-danger/10 rounded-lg transition-colors"
                                      title="Hapus sesi"
                                      aria-label="Hapus sesi"
                                    >
                                      <Trash2 size={14} className="text-danger" />
                                    </button>
                                  )}
                                </>
                              )}
                            </div>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      </div>

      {/* Detail Presensi Modal */}
      {detailSessionId && (
        <SessionDetailModal
          sessionId={detailSessionId}
          courseName={courseName}
          onClose={() => setDetailSessionId(null)}
        />
      )}
    </>
  )
}
