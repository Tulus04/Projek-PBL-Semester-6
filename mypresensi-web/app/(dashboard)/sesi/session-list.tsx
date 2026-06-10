'use client'
// app/(dashboard)/sesi/session-list.tsx
// Client Component — daftar sesi dikelompokkan per mata kuliah.
// Mendukung: tambah sesi, mulai/akhiri sesi, tampil QR, hapus sesi, lihat detail.
// Lifecycle: Pending (belum dimulai) → Active (berlangsung) → Ended (selesai)

import { useState, useEffect, useRef } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import {
  Plus, PlayCircle, StopCircle, Trash2,
  QrCode, ClipboardList, BookOpen,
  ChevronDown, ChevronUp, Zap, MapPin, Info,
  Maximize2, Activity,
} from 'lucide-react'
import { QRCodeSVG } from 'qrcode.react'
import {
  addSessionAction,
  toggleSessionAction,
  deleteSessionAction,
} from '@/lib/actions/sessions'
import { swal, toast } from '@/lib/swal'
import SessionDetailModal from '../matakuliah/session-detail-modal'

interface CourseGroup {
  course: {
    id: string
    name: string
    code: string
    dosen_id: string
    semester: string
    is_active: boolean
  }
  sessions: Session[]
}

interface Session {
  id: string
  course_id: string
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

interface CampusLocation {
  id: string
  name: string
  latitude: number
  longitude: number
  radius_meters: number
  is_default: boolean
}

interface Props {
  groupedSessions: CourseGroup[]
  userRole: string
  userId: string
  campusLocations: CampusLocation[]
}

// Helper: status lifecycle sesi
function getSessionStatus(s: Session): 'active' | 'ended' | 'pending' {
  if (s.is_active) return 'active'
  if (s.started_at && s.ended_at) return 'ended'
  return 'pending'
}

export default function SessionList({ groupedSessions, userRole, userId, campusLocations }: Props) {
  const router = useRouter()
  const isAdmin = userRole === 'admin'

  const [expandedCourses, setExpandedCourses] = useState<Set<string>>(() => {
    // Auto-expand courses with active sessions or pending sessions
    const expanded = new Set<string>()
    groupedSessions.forEach((g) => {
      if (g.sessions.some((s) => s.is_active || !s.started_at)) {
        expanded.add(g.course.id)
      }
    })
    // Jika tidak ada yang aktif/pending, expand semua
    if (expanded.size === 0) {
      groupedSessions.forEach((g) => expanded.add(g.course.id))
    }
    return expanded
  })

  const [showAddForm, setShowAddForm] = useState<string | null>(null)
  const [adding, setAdding] = useState(false)
  const [actionLoading, setActionLoading] = useState<string | null>(null)
  const [detailSessionId, setDetailSessionId] = useState<string | null>(null)

  // Form state: mode-aware location fields
  const [formMode, setFormMode] = useState<'offline' | 'online'>('offline')
  const defaultLocation = campusLocations.find((l) => l.is_default) ?? campusLocations[0]
  const [radiusValue, setRadiusValue] = useState(defaultLocation?.radius_meters ?? 150)

  // Countdown untuk sesi aktif (legacy mode — pakai expires_at static)
  const [countdowns, setCountdowns] = useState<Record<string, number>>({})
  const countdownRef = useRef<NodeJS.Timeout | null>(null)

  // Phase 3 v7 — Rolling QR polling state per session.
  // Map sessionId → {code 6-digit current, ttl_ms sampai window berikutnya, isRolling}.
  // Polling /api/admin/sessions/:id/current-code setiap 5 detik untuk active+expanded.
  // Fallback ke session.session_code prop saat polling belum sukses pertama.
  const [modalCurrentCodes, setModalCurrentCodes] = useState<
    Record<string, { code: string; ttl: number; isRolling: boolean }>
  >({})

  // Track active sessions for countdown
  const activeSessions = groupedSessions.flatMap((g) =>
    g.sessions.filter((s) => s.is_active && s.session_code_expires_at)
  )

  useEffect(() => {
    if (countdownRef.current) clearInterval(countdownRef.current)

    if (activeSessions.length === 0) {
      setCountdowns({})
      return
    }

    const tick = () => {
      const newCountdowns: Record<string, number> = {}
      activeSessions.forEach((s) => {
        const diff = Math.max(
          0,
          Math.floor((new Date(s.session_code_expires_at!).getTime() - Date.now()) / 1000)
        )
        newCountdowns[s.id] = diff
      })
      setCountdowns(newCountdowns)
    }

    tick()
    countdownRef.current = setInterval(tick, 1000)
    return () => { if (countdownRef.current) clearInterval(countdownRef.current) }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeSessions.map(s => s.id + s.session_code_expires_at).join(',')])

  // Phase 3 v7 — Polling current-code per active+expanded session
  // (R9.1-9.9, R14.3). Pattern:
  //   - Hanya sessions yang course_id-nya di expandedCourses (modal QR visible)
  //   - Setiap 5 detik per session, AbortController per session
  //   - 3x error consecutive → backoff 30s per session (independen)
  //   - 410 Gone (sesi berakhir) → stop polling, jangan retry
  //   - is_rolling=false → auto-stop polling (legacy session pakai static)
  //   - Cleanup saat collapse/unmount → abort semua controllers + clear timeouts
  const activeExpandedKey = groupedSessions
    .flatMap((g) =>
      g.sessions
        .filter((s) => s.is_active && expandedCourses.has(s.course_id))
        .map((s) => s.id),
    )
    .sort()
    .join(',')

  useEffect(() => {
    const activeExpandedIds = groupedSessions
      .flatMap((g) => g.sessions)
      .filter((s) => s.is_active && expandedCourses.has(s.course_id))
      .map((s) => s.id)

    if (activeExpandedIds.length === 0) return

    const controllers = new Map<string, AbortController>()
    const timeouts = new Map<string, ReturnType<typeof setTimeout>>()
    const errorCounts = new Map<string, number>()
    const stoppedIds = new Set<string>()

    activeExpandedIds.forEach((sessionId) => {
      const controller = new AbortController()
      controllers.set(sessionId, controller)

      const pollSession = async () => {
        if (stoppedIds.has(sessionId)) return
        try {
          const res = await fetch(
            `/api/admin/sessions/${sessionId}/current-code`,
            { signal: controller.signal, cache: 'no-store' },
          )
          if (controller.signal.aborted) return

          if (!res.ok) {
            // 410 Gone → sesi sudah berakhir, stop polling
            if (res.status === 410) {
              stoppedIds.add(sessionId)
              return
            }
            const errCount = (errorCounts.get(sessionId) ?? 0) + 1
            errorCounts.set(sessionId, errCount)
            const interval = errCount >= 3 ? 30_000 : 5000
            timeouts.set(sessionId, setTimeout(pollSession, interval))
            return
          }

          errorCounts.set(sessionId, 0)
          const data = (await res.json()) as {
            current_code: string | null
            ttl_ms_until_next: number
            is_rolling: boolean
            is_active: boolean
          }

          if (data.current_code) {
            const codeValue = data.current_code
            setModalCurrentCodes((prev) => ({
              ...prev,
              [sessionId]: {
                code: codeValue,
                ttl: data.ttl_ms_until_next ?? 0,
                isRolling: data.is_rolling === true,
              },
            }))
          }

          // Legacy session (seed=null) — auto-stop polling, fallback ke static prop.
          // R9.7: SKIP polling untuk legacy session.
          if (data.is_rolling === false) {
            stoppedIds.add(sessionId)
            return
          }

          timeouts.set(sessionId, setTimeout(pollSession, 5000))
        } catch (err) {
          if (controller.signal.aborted) return
          if (err instanceof DOMException && err.name === 'AbortError') return
          const errCount = (errorCounts.get(sessionId) ?? 0) + 1
          errorCounts.set(sessionId, errCount)
          const interval = errCount >= 3 ? 30_000 : 5000
          timeouts.set(sessionId, setTimeout(pollSession, interval))
        }
      }

      pollSession()
    })

    return () => {
      controllers.forEach((c) => c.abort())
      timeouts.forEach((t) => clearTimeout(t))
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeExpandedKey])

  // Phase 3 v7 — Local TTL ticker (R9.4). Decrement ttl per session rolling
  // setiap 1 detik supaya countdown turun smooth. Polling next tick reset ke
  // fresh value (~30000ms) saat window berganti.
  useEffect(() => {
    const interval = setInterval(() => {
      setModalCurrentCodes((prev) => {
        let changed = false
        const next: typeof prev = {}
        for (const [id, entry] of Object.entries(prev)) {
          if (entry.isRolling && entry.ttl > 0) {
            next[id] = { ...entry, ttl: Math.max(0, entry.ttl - 1000) }
            changed = true
          } else {
            next[id] = entry
          }
        }
        return changed ? next : prev
      })
    }, 1000)
    return () => clearInterval(interval)
  }, [])

  const formatCountdown = (seconds: number) => {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
  }

  const toggleExpand = (courseId: string) => {
    setExpandedCourses((prev) => {
      const next = new Set(prev)
      if (next.has(courseId)) next.delete(courseId)
      else next.add(courseId)
      return next
    })
  }

  const handleAddSession = async (e: React.FormEvent<HTMLFormElement>, courseId: string, dosenId: string) => {
    e.preventDefault()
    setAdding(true)
    const formData = new FormData(e.currentTarget)
    const result = await addSessionAction(courseId, dosenId, formData)
    if (result.success) {
      toast.fire({ icon: 'success', title: 'Sesi berhasil ditambahkan' })
      setShowAddForm(null)
      router.refresh()
    } else {
      swal.fire({ icon: 'error', title: 'Gagal', text: result.error ?? '' })
    }
    setAdding(false)
  }

  const handleToggle = async (session: Session) => {
    if (session.is_active) {
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
        router.refresh()
      }
    } catch (err) {
      swal.fire({ icon: 'error', title: 'Terjadi Kesalahan', text: (err as Error).message || 'Gagal menghubungi server.' })
    } finally {
      setActionLoading(null)
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
    const res = await deleteSessionAction(session.id)
    if (res.error) {
      swal.fire({ icon: 'error', title: 'Gagal', text: res.error })
    } else {
      toast.fire({ icon: 'success', title: 'Sesi dihapus' })
      router.refresh()
    }
    setActionLoading(session.id)
  }

  // Collect pending sessions across all courses for "Quick Start" section
  const pendingSessions = groupedSessions.flatMap((g) =>
    g.sessions
      .filter((s) => getSessionStatus(s) === 'pending')
      .map((s) => ({ ...s, courseName: `${g.course.code} — ${g.course.name}`, courseDosenId: g.course.dosen_id }))
  )

  if (groupedSessions.length === 0) {
    return (
      <div className="card p-12 text-center">
        <BookOpen size={40} className="mx-auto text-text-secondary mb-3 opacity-40" />
        <p className="text-sm font-medium text-text-primary mb-1">
          Belum ada sesi perkuliahan
        </p>
        <p className="text-xs text-text-secondary mb-4">
          {isAdmin
            ? 'Sesi akan muncul setelah dosen membuat sesi pada mata kuliah yang mereka ampu.'
            : 'Buat sesi baru pada mata kuliah Anda untuk mulai mengelola presensi mahasiswa.'}
        </p>
        {!isAdmin && (
          <p className="text-xs text-text-secondary">
            Buka tab <strong>Mata Kuliah</strong> → pilih MK → <strong>Kelola Sesi</strong> untuk memulai.
          </p>
        )}
      </div>
    )
  }

  return (
    <>
      {/* =============================== */}
      {/* QUICK START: Pending Sessions    */}
      {/* =============================== */}
      {pendingSessions.length > 0 && (
        <div className="card overflow-hidden mb-4">
          <div className="px-5 py-3 border-b border-border bg-amber-50/50">
            <div className="flex items-center gap-2">
              <Zap size={16} className="text-amber-600" />
              <h3 className="text-sm font-semibold text-text-primary">
                Siap Dimulai ({pendingSessions.length} sesi)
              </h3>
            </div>
          </div>
          <div className="px-5 py-3 space-y-2">
            {pendingSessions.slice(0, 5).map((s) => (
              <div
                key={s.id}
                className="flex items-center justify-between p-3 rounded-lg border border-amber-200 bg-amber-50/30 hover:bg-amber-50/60 transition-colors"
              >
                <div className="flex items-center gap-3 flex-1 min-w-0">
                  <div className="w-9 h-9 rounded-lg bg-amber-100 flex items-center justify-center flex-shrink-0">
                    <span className="text-sm font-bold text-amber-700">{s.session_number}</span>
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-text-primary truncate">
                      {s.topic || 'Tidak ada topik'}
                    </p>
                    <p className="text-xs text-text-secondary truncate">{s.courseName}</p>
                  </div>
                </div>
                <button
                  onClick={() => handleToggle(s)}
                  disabled={actionLoading === s.id}
                  className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5 flex-shrink-0"
                >
                  {actionLoading === s.id ? (
                    <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  ) : (
                    <PlayCircle size={14} />
                  )}
                  Mulai Sesi
                </button>
              </div>
            ))}
            {pendingSessions.length > 5 && (
              <p className="text-xs text-text-secondary text-center py-1">
                +{pendingSessions.length - 5} sesi lainnya
              </p>
            )}
          </div>
        </div>
      )}

      {/* =============================== */}
      {/* GROUPED SESSIONS BY COURSE       */}
      {/* =============================== */}
      <div className="flex flex-col gap-4">
        {groupedSessions.map(({ course, sessions }) => {
          const isExpanded = expandedCourses.has(course.id)
          const activeSession = sessions.find((s) => s.is_active)
          const pendingCount = sessions.filter((s) => getSessionStatus(s) === 'pending').length
          const totalAtt = sessions.reduce(
            (sum, s) => sum + (s.attendance_count?.[0]?.count ?? 0), 0
          )
          const nextNumber = sessions.length > 0
            ? Math.max(...sessions.map((s) => s.session_number)) + 1
            : 1
          const isOwner = isAdmin || course.dosen_id === userId

          return (
            <div key={course.id} className="card overflow-hidden">
              {/* Course Header — clickable to expand/collapse */}
              <button
                onClick={() => toggleExpand(course.id)}
                className="w-full px-5 py-4 flex items-center justify-between hover:bg-gray-50/50 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${activeSession ? 'bg-success/10' : 'bg-primary/10'}`}>
                    <BookOpen
                      size={18}
                      className={activeSession ? 'text-success' : 'text-primary'}
                    />
                  </div>
                  <div className="text-left">
                    <div className="flex items-center gap-2">
                      <p className="text-sm font-bold text-text-primary">
                        {course.code} — {course.name}
                      </p>
                      {activeSession && (
                        <span className="badge badge-success text-[10px] py-0.5">
                          <span
                            className="inline-block w-1.5 h-1.5 rounded-full mr-1 bg-success"
                            style={{ animation: 'pulse 2s infinite' }}
                          />
                          Aktif
                        </span>
                      )}
                      {pendingCount > 0 && !activeSession && (
                        <span className="badge badge-warning text-[10px] py-0.5">
                          {pendingCount} siap mulai
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-text-secondary mt-0.5">
                      {sessions.length} sesi · {totalAtt} presensi · Semester {course.semester}
                    </p>
                  </div>
                </div>
                {isExpanded ? (
                  <ChevronUp size={18} className="text-text-secondary" />
                ) : (
                  <ChevronDown size={18} className="text-text-secondary" />
                )}
              </button>

              {/* Expanded Content */}
              {isExpanded && (
                <div className="border-t border-border px-5 py-4">
                  {/* Active Session QR Card */}
                  {activeSession && activeSession.session_code && (() => {
                    const polled = modalCurrentCodes[activeSession.id]
                    // Fallback ke prop static saat polling belum sukses pertama kali (R9.5).
                    // Untuk legacy session (seed=null), polling auto-stop & isRolling=false →
                    // tetap pakai prop static + countdowns legacy (R9.7, R14.3).
                    const displayCode = polled?.code ?? activeSession.session_code!
                    const isRollingMode = polled?.isRolling === true
                    const rollingCountdownSec = isRollingMode
                      ? Math.ceil((polled?.ttl ?? 0) / 1000)
                      : 0
                    const legacyCountdownSec = countdowns[activeSession.id] ?? 0
                    const displayCountdownSec = isRollingMode
                      ? rollingCountdownSec
                      : legacyCountdownSec
                    return (
                    <div
                      className="rounded-xl p-5 mb-4 border-2 border-success/25"
                      style={{
                        background: 'linear-gradient(135deg, rgba(26,127,55,0.04) 0%, rgba(84,131,173,0.04) 100%)',
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
                        <span className="text-xs text-text-secondary">{activeSession.topic}</span>
                      </div>

                      {/* QR Code */}
                      <div className="flex flex-col items-center mb-4">
                        <div className="bg-white p-3 rounded-xl border border-border shadow-sm mb-2">
                          <QRCodeSVG
                            value={JSON.stringify({
                              sid: activeSession.id,
                              code: displayCode,
                              exp: activeSession.session_code_expires_at,
                            })}
                            size={160}
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

                      {/* OTP Display dihilangkan (Phase 3 v7) — code di payload
                          QR TIDAK dipakai user input. Mahasiswa scan QR otomatis,
                          code rolling tetap ada di payload untuk server verify. */}

                      {/* Countdown */}
                      <div className="text-center mb-3">
                        <span
                          className={`text-sm font-medium ${displayCountdownSec <= 30 ? 'text-danger' : 'text-text-secondary'}`}
                        >
                          QR berganti dalam: {formatCountdown(displayCountdownSec)}
                        </span>
                      </div>

                      {/* Action Buttons */}
                      <div className="flex items-center justify-center gap-2 flex-wrap">
                        {/* Primary action — pemantauan real-time sesi aktif */}
                        <Link
                          href={`/sesi/${activeSession.id}/live`}
                          className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg text-white transition-colors bg-primary hover:bg-primary-hover"
                        >
                          <Activity size={13} /> Live Monitor
                        </Link>
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
                        {/* Destructive — danger outline (bukan solid, cegah salah klik) */}
                        <button
                          onClick={() => handleToggle(activeSession)}
                          className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg border border-danger/30 bg-danger/5 text-danger hover:bg-danger/10 transition-colors"
                        >
                          <StopCircle size={13} /> Akhiri
                        </button>
                      </div>
                    </div>
                    )
                  })()}

                  {/* Add Session Button + Form */}
                  {isOwner && (
                    <div className="flex items-center justify-between mb-3">
                      <h4 className="text-sm font-semibold text-text-primary">
                        {sessions.length} Sesi Terdaftar
                      </h4>
                      <button
                        onClick={() => setShowAddForm(showAddForm === course.id ? null : course.id)}
                        className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5"
                      >
                        <Plus size={14} /> Tambah Sesi
                      </button>
                    </div>
                  )}
                  {!isOwner && (
                    <h4 className="text-sm font-semibold text-text-primary mb-3">
                      {sessions.length} Sesi Terdaftar
                    </h4>
                  )}

                  {/* Add Form */}
                  {showAddForm === course.id && (
                    <form
                      onSubmit={(e) => handleAddSession(e, course.id, course.dosen_id)}
                      className="border border-primary/20 bg-primary/5 rounded-lg p-4 mb-4"
                    >
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
                          <select
                            name="mode"
                            className="input-field w-full"
                            defaultValue="offline"
                            onChange={(e) => {
                              setFormMode(e.target.value as 'offline' | 'online')
                              // Reset radius ke default lokasi saat ganti mode
                              if (e.target.value === 'offline') {
                                setRadiusValue(defaultLocation?.radius_meters ?? 150)
                              }
                            }}
                          >
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

                      {/* Mode-Aware Location Section */}
                      {formMode === 'offline' ? (
                        <div
                          className="border border-border rounded-lg p-3 mb-3 transition-all duration-300"
                          style={{ backgroundColor: 'rgba(84,131,173,0.03)' }}
                        >
                          <div className="flex items-center gap-2 mb-2.5">
                            <MapPin size={14} className="text-primary" />
                            <span className="text-xs font-semibold text-text-primary">Lokasi Kelas</span>
                          </div>

                          {/* Dropdown Lokasi Preset */}
                          <div className="mb-3">
                            <label className="form-label text-xs">Pilih Lokasi</label>
                            <select
                              name="campus_location_id"
                              className="input-field w-full text-sm"
                              defaultValue={defaultLocation?.id ?? ''}
                              onChange={(e) => {
                                const loc = campusLocations.find((l) => l.id === e.target.value)
                                if (loc) setRadiusValue(loc.radius_meters)
                              }}
                            >
                              {campusLocations.map((loc) => (
                                <option key={loc.id} value={loc.id}>
                                  {loc.name}{loc.is_default ? ' (default)' : ''}
                                </option>
                              ))}
                            </select>
                          </div>

                          {/* Slider Radius */}
                          <div>
                            <div className="flex items-center justify-between mb-1">
                              <label className="form-label text-xs mb-0">Radius GPS</label>
                              <span className="text-xs font-medium text-primary">{radiusValue} meter</span>
                            </div>
                            <input
                              name="radius_meters"
                              type="range"
                              min={50}
                              max={500}
                              step={10}
                              value={radiusValue}
                              onChange={(e) => setRadiusValue(parseInt(e.target.value))}
                              className="w-full accent-[var(--color-primary)]"
                              style={{ height: '6px' }}
                            />
                            <div className="flex justify-between text-[10px] text-text-secondary mt-0.5">
                              <span>50m</span>
                              <span>500m</span>
                            </div>
                          </div>
                        </div>
                      ) : (
                        <div className="flex items-start gap-2 border border-primary/20 bg-primary/5 rounded-lg p-3 mb-3 transition-all duration-300">
                          <Info size={14} className="text-primary mt-0.5 flex-shrink-0" />
                          <div>
                            <p className="text-xs font-medium text-text-primary">
                              Sesi daring — verifikasi lokasi GPS dinonaktifkan
                            </p>
                            <p className="text-[11px] text-text-secondary mt-0.5">
                              Mahasiswa bisa melakukan presensi dari mana saja tanpa validasi lokasi.
                            </p>
                          </div>
                        </div>
                      )}

                      <div className="flex justify-end gap-2">
                        <button
                          type="button"
                          onClick={() => {
                            setShowAddForm(null)
                            setFormMode('offline')
                            setRadiusValue(defaultLocation?.radius_meters ?? 150)
                          }}
                          className="px-3 py-2 text-sm border border-border rounded-lg hover:bg-gray-50"
                        >
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

                  {/* Session Rows */}
                  {sessions.length === 0 ? (
                    <div className="py-6 text-center">
                      <p className="text-sm text-text-secondary mb-1">
                        Belum ada sesi untuk mata kuliah ini.
                      </p>
                      <p className="text-xs text-text-secondary">
                        Klik &quot;Tambah Sesi&quot; untuk membuat pertemuan baru.
                      </p>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {sessions
                        .sort((a, b) => a.session_number - b.session_number)
                        .map((s) => {
                        const attCount = s.attendance_count?.[0]?.count ?? 0
                        const status = getSessionStatus(s)
                        return (
                          <div
                            key={s.id}
                            className="border rounded-lg p-3 hover:bg-gray-50 transition-colors"
                            style={{
                              borderColor: status === 'active'
                                ? 'rgba(26,127,55,0.3)'
                                : status === 'pending'
                                  ? 'rgba(234,179,8,0.3)'
                                  : 'var(--color-border)',
                              backgroundColor: status === 'active'
                                ? 'rgba(26,127,55,0.02)'
                                : status === 'pending'
                                  ? 'rgba(234,179,8,0.02)'
                                  : undefined,
                            }}
                          >
                            <div className="flex items-center justify-between">
                              <div className="flex items-center gap-3 flex-1 min-w-0">
                                <div
                                  className={`w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 ${
                                    status === 'active'
                                      ? 'bg-success/10'
                                      : status === 'pending'
                                        ? 'bg-amber-100'
                                        : 'bg-gray-100'
                                  }`}
                                >
                                  <span
                                    className={`text-sm font-bold ${
                                      status === 'active'
                                        ? 'text-success'
                                        : status === 'pending'
                                          ? 'text-amber-700'
                                          : 'text-text-primary'
                                    }`}
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
                                    {/* Status badge */}
                                    {status === 'pending' && (
                                      <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-amber-100 text-amber-700">
                                        Belum dimulai
                                      </span>
                                    )}
                                    {status === 'active' && (
                                      <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-success/10 text-success flex items-center gap-1">
                                        <span
                                          className="inline-block w-1.5 h-1.5 rounded-full bg-success"
                                          style={{ animation: 'pulse 2s infinite' }}
                                        />
                                        Berlangsung
                                      </span>
                                    )}
                                    {status === 'ended' && (
                                      <span className="text-xs text-text-secondary">{attCount} presensi</span>
                                    )}
                                    {s.started_at && (
                                      <span className="text-xs text-text-secondary" suppressHydrationWarning>
                                        · {new Date(s.started_at).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' })}
                                      </span>
                                    )}
                                  </div>
                                </div>
                              </div>

                              {/* Action Buttons */}
                              <div className="flex items-center gap-1">
                                {actionLoading === s.id ? (
                                  <div className="w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                                ) : (
                                  <>
                                    {/* Prominent "Mulai" for pending */}
                                    {status === 'pending' && isOwner && (
                                      <button
                                        onClick={() => handleToggle(s)}
                                        className="flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium rounded-lg text-white transition-opacity mr-1 bg-success hover:opacity-90"
                                        title="Mulai sesi"
                                        aria-label="Mulai sesi"
                                      >
                                        <PlayCircle size={13} /> Mulai
                                      </button>
                                    )}
                                    {/* Detail button */}
                                    {status !== 'pending' && (
                                      <button
                                        onClick={() => setDetailSessionId(s.id)}
                                        className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors"
                                        title="Lihat detail presensi"
                                        aria-label="Lihat detail presensi"
                                      >
                                        <ClipboardList size={15} className="text-primary" />
                                      </button>
                                    )}
                                    {/* Stop for active */}
                                    {status === 'active' && isOwner && (
                                      <button
                                        onClick={() => handleToggle(s)}
                                        className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors"
                                        title="Akhiri sesi"
                                        aria-label="Akhiri sesi"
                                      >
                                        <StopCircle size={16} className="text-danger" />
                                      </button>
                                    )}
                                    {/* Delete — hanya jika sesi pending (belum dimulai) */}
                                    {status === 'pending' && isOwner && (
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
                </div>
              )}
            </div>
          )
        })}
      </div>

      {/* Detail Modal — reuse dari matakuliah */}
      {detailSessionId && (
        <SessionDetailModal
          sessionId={detailSessionId}
          courseName=""
          onClose={() => setDetailSessionId(null)}
        />
      )}
    </>
  )
}
