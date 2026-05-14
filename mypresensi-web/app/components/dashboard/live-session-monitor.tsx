'use client'
// app/components/dashboard/live-session-monitor.tsx
// Widget realtime monitor sesi aktif untuk dashboard dosen.
// Subscribe Supabase Realtime channel `attendances:session_id=eq.<id>` untuk
// menerima INSERT saat mahasiswa submit presensi → update progress + grid peserta.
// Catatan: RLS attendances apply ke realtime broadcast — dosen otomatis hanya menerima
// row yang ia berhak akses.

import { useEffect, useMemo, useState } from 'react'
import { Activity, Clock, Wifi, WifiOff } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import type { ActiveSessionInfo, EnrolledStudent } from '@/lib/actions/live-session'

interface LiveSessionMonitorProps {
  data: ActiveSessionInfo
}

// Avatar fallback dengan inisial nama
function getInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map(part => part[0]?.toUpperCase() ?? '')
    .join('')
}

// Format relatif "5 menit yang lalu"
function formatRelativeTime(iso: string): string {
  const date = new Date(iso)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMin = Math.floor(diffMs / 60000)
  if (diffMin < 1) return 'Baru saja'
  if (diffMin < 60) return `${diffMin} menit lalu`
  const diffHour = Math.floor(diffMin / 60)
  return `${diffHour} jam ${diffMin % 60} menit lalu`
}

// Status -> warna badge avatar
const statusColorMap: Record<string, { ring: string; label: string }> = {
  hadir: { ring: 'ring-success', label: 'Hadir' },
  terlambat: { ring: 'ring-warning', label: 'Telat' },
  izin: { ring: 'ring-warning', label: 'Izin' },
  sakit: { ring: 'ring-warning', label: 'Sakit' },
  alpa: { ring: 'ring-danger', label: 'Alpa' },
}

// Avatar single mahasiswa — present atau absent
function StudentAvatar({
  student,
  status,
}: {
  student: EnrolledStudent
  status: string | null
}) {
  const isPresent = status !== null
  const config = status ? statusColorMap[status] : null

  return (
    <div className="flex flex-col items-center gap-1 group" title={`${student.fullName} · ${student.nimNip}${status ? ` · ${config?.label ?? status}` : ' · Belum hadir'}`}>
      <div className="relative">
        {student.avatarUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={student.avatarUrl}
            alt={student.fullName}
            className={`w-12 h-12 rounded-full object-cover transition-all ${
              isPresent
                ? `ring-2 ring-offset-2 ring-offset-surface ${config?.ring ?? 'ring-success'}`
                : 'opacity-40 grayscale'
            }`}
          />
        ) : (
          <div
            className={`w-12 h-12 rounded-full flex items-center justify-center font-semibold text-sm transition-all ${
              isPresent
                ? `bg-primary/10 text-primary ring-2 ring-offset-2 ring-offset-surface ${config?.ring ?? 'ring-success'}`
                : 'bg-gray-100 text-gray-400'
            }`}
          >
            {getInitials(student.fullName)}
          </div>
        )}
        {/* Indicator dot */}
        {isPresent && (
          <span className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full bg-success border-2 border-surface flex items-center justify-center">
            <span className="w-1 h-1 rounded-full bg-white" />
          </span>
        )}
      </div>
      <p
        className={`text-[10px] text-center leading-tight max-w-[70px] truncate ${
          isPresent ? 'text-text-primary font-medium' : 'text-text-secondary'
        }`}
      >
        {student.fullName.split(' ')[0]}
      </p>
    </div>
  )
}

export default function LiveSessionMonitor({ data }: LiveSessionMonitorProps) {
  const [attendances, setAttendances] = useState<Record<string, string>>(data.initialAttendances)
  const [connected, setConnected] = useState(false)
  // Track timestamp toast/highlight terakhir (animation pulse di entry baru)
  const [latestArrival, setLatestArrival] = useState<string | null>(null)

  // Subscribe Supabase Realtime channel
  useEffect(() => {
    const supabase = createClient()
    const channel = supabase
      .channel(`live-session-${data.sessionId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'attendances',
          filter: `session_id=eq.${data.sessionId}`,
        },
        (payload) => {
          const row = payload.new as { student_id: string; status: string } | null
          if (!row?.student_id) return
          setAttendances((prev) => ({ ...prev, [row.student_id]: row.status ?? 'hadir' }))
          setLatestArrival(row.student_id)
          // Reset highlight setelah 3 detik
          setTimeout(() => setLatestArrival(null), 3000)
        },
      )
      .subscribe((status) => {
        setConnected(status === 'SUBSCRIBED')
      })

    return () => {
      supabase.removeChannel(channel)
    }
  }, [data.sessionId])

  const totalAttended = Object.keys(attendances).length
  const totalEnrolled = data.totalEnrolled
  const progressPct = totalEnrolled > 0 ? Math.round((totalAttended / totalEnrolled) * 100) : 0

  // Split: yang sudah hadir vs belum, sorted hadir first
  const sortedStudents = useMemo(() => {
    return [...data.enrolledStudents].sort((a, b) => {
      const aPresent = attendances[a.id] !== undefined
      const bPresent = attendances[b.id] !== undefined
      if (aPresent && !bPresent) return -1
      if (!aPresent && bPresent) return 1
      return a.fullName.localeCompare(b.fullName, 'id')
    })
  }, [data.enrolledStudents, attendances])

  return (
    <div className="card p-5 border-l-4 border-l-primary">
      {/* Header */}
      <div className="flex items-start justify-between gap-3 flex-wrap mb-4">
        <div className="flex items-start gap-3 flex-1 min-w-0">
          <div className="kpi-icon-box primary flex-shrink-0">
            <Activity size={18} />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 flex-wrap mb-1">
              <span className="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest text-primary bg-primary/10 px-2 py-0.5 rounded-full">
                <span className="relative flex h-1.5 w-1.5">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75" />
                  <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-primary" />
                </span>
                Sesi Aktif
              </span>
              <span className="text-[10px] uppercase tracking-widest font-bold text-text-secondary">
                {data.mode === 'offline' ? 'Offline (GPS)' : 'Online'}
              </span>
              {/* Connection indicator */}
              <span
                className={`inline-flex items-center gap-1 text-[10px] font-bold ${
                  connected ? 'text-success' : 'text-text-secondary'
                }`}
                title={connected ? 'Realtime tersambung' : 'Menyambung ke realtime…'}
              >
                {connected ? <Wifi size={10} /> : <WifiOff size={10} />}
                {connected ? 'Live' : 'Connecting…'}
              </span>
            </div>
            <h3 className="text-base font-bold font-heading text-text-primary leading-tight truncate">
              {data.courseCode} · {data.courseName}
            </h3>
            <p className="text-xs text-text-secondary mt-0.5 truncate">
              Sesi #{data.sessionNumber}
              {data.topic && ` · ${data.topic}`}
              <span className="inline-flex items-center gap-1 ml-2">
                <Clock size={10} />
                {formatRelativeTime(data.startedAt)}
              </span>
            </p>
          </div>
        </div>

        {/* Progress count */}
        <div className="text-right flex-shrink-0">
          <p className="text-2xl font-bold font-heading text-primary leading-tight">
            {totalAttended}
            <span className="text-base text-text-secondary font-normal"> / {totalEnrolled}</span>
          </p>
          <p className="text-[10px] text-text-secondary uppercase tracking-wide">sudah absen</p>
        </div>
      </div>

      {/* Progress bar */}
      <div className="mb-4">
        <div className="flex items-center justify-between mb-1.5">
          <span className="text-xs font-semibold text-text-primary">Progres Kehadiran</span>
          <span className="text-xs font-bold text-primary">{progressPct}%</span>
        </div>
        <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-primary to-primary-hover transition-all duration-700 ease-out"
            style={{ width: `${Math.max(progressPct, 2)}%` }}
          />
        </div>
      </div>

      {/* Grid mahasiswa */}
      {sortedStudents.length === 0 ? (
        <div className="text-center py-6 text-sm text-text-secondary">
          Belum ada mahasiswa yang terdaftar di mata kuliah ini.
        </div>
      ) : (
        <>
          <div className="flex items-center justify-between mb-2">
            <p className="text-[10px] uppercase tracking-widest font-bold text-text-secondary">
              Peserta Mata Kuliah
            </p>
            <p className="text-[10px] text-text-secondary">
              <span className="text-success font-semibold">{totalAttended} hadir</span>
              {' · '}
              <span>{totalEnrolled - totalAttended} belum</span>
            </p>
          </div>
          <div className="grid grid-cols-5 sm:grid-cols-7 md:grid-cols-9 lg:grid-cols-11 gap-3">
            {sortedStudents.map((student) => (
              <div
                key={student.id}
                className={
                  latestArrival === student.id
                    ? 'animate-pulse-once'
                    : ''
                }
              >
                <StudentAvatar
                  student={student}
                  status={attendances[student.id] ?? null}
                />
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  )
}
