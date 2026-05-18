'use client'

// app/(dashboard)/sesi/[id]/live/live-monitor-client.tsx
// Client Component Live Monitor Dosen.
// Subscribe Realtime channel attendances → update geofence ring + KPI bar +
// activity feed + student grid secara real-time.
//
// Reference visual: docs/ui-research/mockups/live-monitor.html
// Spec: .kiro/specs/live-monitor-dosen/

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  Activity,
  AlertCircle,
  CheckCircle2,
  Clock,
  MapPin,
  RefreshCw,
  StopCircle,
  Users,
  WifiOff,
  XCircle,
} from 'lucide-react'

import { useRealtimeAttendances } from '@/lib/realtime/use-realtime-attendances'
import type {
  RealtimeAttendanceRow,
  RealtimeChannelStatus,
} from '@/types/realtime'
import { refreshSessionCode, toggleSessionAction } from '@/lib/actions/sessions'
import { swal, toast } from '@/lib/swal'
import { cn } from '@/lib/utils'

// ============================================================================
// Types
// ============================================================================

export interface StudentLiveRow {
  student_id: string
  full_name: string
  nim: string | null
  avatar_url: string | null
  status: string // 'belum' | 'hadir' | 'terlambat' | 'izin' | 'sakit' | 'alpa' | 'ditolak'
  scanned_at: string | null
  student_lat: number | null
  student_lng: number | null
  distance_meters: number | null
  is_mock_location: boolean | null
  face_confidence: number | null
}

export interface LiveStats {
  hadir: number
  terlambat: number
  belum: number
  total: number
  ditolak: number
}

interface LiveMonitorClientProps {
  sessionId: string
  sessionCode: string | null
  sessionCodeExpiresAt: string | null
  sessionNumber: number
  topic: string | null
  mode: string
  isActive: boolean
  startedAt: string | null
  courseCode: string
  courseName: string
  dosenName: string | null
  geofenceCenter: { lat: number; lng: number } | null
  geofenceRadius: number
  initialStudents: StudentLiveRow[]
  initialStats: LiveStats
}

type FilterChip = 'semua' | 'hadir' | 'telat' | 'belum' | 'ditolak'

interface ActivityEvent {
  id: string
  studentName: string
  status: string
  timestamp: string
  isMock: boolean
}

// ============================================================================
// Pure helpers
// ============================================================================

const RING_SIZE_PX = 380
const RING_OUTER_RADIUS_PX = RING_SIZE_PX / 2 - 16

/** Compute Haversine distance in meters between two coords (degrees). */
function haversineDistanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371000
  const φ1 = (lat1 * Math.PI) / 180
  const φ2 = (lat2 * Math.PI) / 180
  const Δφ = ((lat2 - lat1) * Math.PI) / 180
  const Δλ = ((lng2 - lng1) * Math.PI) / 180
  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

/** Compute polar position (x, y) for student dot in geofence SVG. */
export function computeDotPosition(
  centerLat: number | null,
  centerLng: number | null,
  studentLat: number | null,
  studentLng: number | null,
  ringSizePx: number,
  ringRadiusMeters: number,
): { x: number; y: number; withinRange: boolean; distance: number } {
  const cx = ringSizePx / 2
  if (
    centerLat === null ||
    centerLng === null ||
    studentLat === null ||
    studentLng === null
  ) {
    return { x: cx, y: cx, withinRange: false, distance: 0 }
  }

  const distance = haversineDistanceMeters(
    centerLat,
    centerLng,
    studentLat,
    studentLng,
  )

  const dLng = ((studentLng - centerLng) * Math.PI) / 180
  const φ1 = (centerLat * Math.PI) / 180
  const φ2 = (studentLat * Math.PI) / 180
  const y1 = Math.sin(dLng) * Math.cos(φ2)
  const x1 =
    Math.cos(φ1) * Math.sin(φ2) -
    Math.sin(φ1) * Math.cos(φ2) * Math.cos(dLng)
  const bearing = Math.atan2(y1, x1)

  const scale = Math.min(distance / ringRadiusMeters, 1.0)
  const pixelDist = scale * RING_OUTER_RADIUS_PX

  const x = cx + pixelDist * Math.sin(bearing)
  const y = cx - pixelDist * Math.cos(bearing)

  return { x, y, withinRange: distance <= ringRadiusMeters, distance }
}

function formatRelativeTime(iso: string | null): string {
  if (!iso) return ''
  try {
    const dt = new Date(iso)
    const diff = Math.floor((Date.now() - dt.getTime()) / 1000)
    if (diff < 60) return 'Baru saja'
    if (diff < 3600) return `${Math.floor(diff / 60)} menit lalu`
    if (diff < 86400) return `${Math.floor(diff / 3600)} jam lalu`
    return `${dt.getHours().toString().padStart(2, '0')}:${dt.getMinutes().toString().padStart(2, '0')}`
  } catch {
    return ''
  }
}

function computeCountdown(expiresAt: string | null): number {
  if (!expiresAt) return 0
  try {
    const expireMs = new Date(expiresAt).getTime()
    if (Number.isNaN(expireMs)) return 0
    const diffMs = expireMs - Date.now()
    return Math.max(0, Math.floor(diffMs / 1000))
  } catch {
    return 0
  }
}

function formatCountdown(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
}

function getStatusColor(status: string): {
  fill: string
  bg: string
  border: string
  text: string
} {
  switch (status) {
    case 'hadir':
      return {
        fill: '#22c55e',
        bg: 'bg-green-50',
        border: 'border-green-300',
        text: 'text-green-700',
      }
    case 'terlambat':
      return {
        fill: '#3b82f6',
        bg: 'bg-blue-50',
        border: 'border-blue-300',
        text: 'text-blue-700',
      }
    case 'izin':
    case 'sakit':
      return {
        fill: '#f59e0b',
        bg: 'bg-amber-50',
        border: 'border-amber-300',
        text: 'text-amber-700',
      }
    case 'ditolak':
    case 'alpa':
      return {
        fill: '#ef4444',
        bg: 'bg-red-50',
        border: 'border-red-300',
        text: 'text-red-700',
      }
    default:
      return {
        fill: '#9ca3af',
        bg: 'bg-gray-50',
        border: 'border-gray-300',
        text: 'text-gray-600',
      }
  }
}

function getStatusLabel(status: string): string {
  switch (status) {
    case 'hadir':
      return 'Hadir'
    case 'terlambat':
      return 'Telat'
    case 'izin':
      return 'Izin'
    case 'sakit':
      return 'Sakit'
    case 'alpa':
      return 'Alpa'
    case 'ditolak':
      return 'Ditolak'
    default:
      return 'Belum'
  }
}

// ============================================================================
// Animated counter — count up from previous value to current
// ============================================================================

function useAnimatedCounter(target: number, durationMs: number = 800): number {
  const [display, setDisplay] = useState(target)
  const prevRef = useRef(target)

  useEffect(() => {
    if (target === prevRef.current) return
    const from = prevRef.current
    const to = target
    const startTime = performance.now()
    let raf: number

    const step = (now: number) => {
      const elapsed = now - startTime
      const progress = Math.min(elapsed / durationMs, 1)
      const eased = 1 - Math.pow(1 - progress, 3) // easeOutCubic
      const value = Math.round(from + (to - from) * eased)
      setDisplay(value)
      if (progress < 1) {
        raf = requestAnimationFrame(step)
      } else {
        prevRef.current = to
      }
    }

    raf = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf)
  }, [target, durationMs])

  return display
}

// ============================================================================
// Main Component
// ============================================================================

export function LiveMonitorClient(props: LiveMonitorClientProps) {
  const router = useRouter()

  // State: students Map (O(1) update by student_id)
  const [studentsMap, setStudentsMap] = useState<Map<string, StudentLiveRow>>(() => {
    const m = new Map<string, StudentLiveRow>()
    for (const s of props.initialStudents) m.set(s.student_id, s)
    return m
  })
  const [stats, setStats] = useState<LiveStats>(props.initialStats)
  const [activity, setActivity] = useState<ActivityEvent[]>([])
  const [filterChip, setFilterChip] = useState<FilterChip>('semua')
  const [syncStatus, setSyncStatus] = useState<RealtimeChannelStatus>('CONNECTING')
  const [pulseStudentId, setPulseStudentId] = useState<string | null>(null)
  const [countdownSec, setCountdownSec] = useState<number>(() =>
    computeCountdown(props.sessionCodeExpiresAt),
  )
  const [isEnding, setIsEnding] = useState(false)
  const [isRefreshingCode, setIsRefreshingCode] = useState(false)

  // Countdown timer
  useEffect(() => {
    setCountdownSec(computeCountdown(props.sessionCodeExpiresAt))
    const interval = setInterval(() => {
      setCountdownSec(computeCountdown(props.sessionCodeExpiresAt))
    }, 1000)
    return () => clearInterval(interval)
  }, [props.sessionCodeExpiresAt])

  // Realtime callback — Algorithm 2 design.md
  const handleRealtimeInsert = useCallback((row: RealtimeAttendanceRow) => {
    setStudentsMap((prev) => {
      const newMap = new Map(prev)
      const existing = newMap.get(row.student_id)
      const newStatus = row.is_mock_location ? 'ditolak' : row.status
      newMap.set(row.student_id, {
        student_id: row.student_id,
        full_name: existing?.full_name ?? '-',
        nim: existing?.nim ?? null,
        avatar_url: existing?.avatar_url ?? null,
        status: newStatus,
        scanned_at: row.scanned_at,
        student_lat: row.student_lat,
        student_lng: row.student_lng,
        distance_meters: row.distance_meters,
        is_mock_location: row.is_mock_location,
        face_confidence: row.face_confidence,
      })
      return newMap
    })

    // Stats delta (compute from student status change)
    setStats((prev) => {
      const oldStatus = studentsMap.get(row.student_id)?.status ?? 'belum'
      const newStatus = row.is_mock_location ? 'ditolak' : row.status
      const newStats = { ...prev }
      if (oldStatus === 'belum') newStats.belum = Math.max(0, newStats.belum - 1)
      if (newStatus === 'hadir') newStats.hadir += 1
      if (newStatus === 'terlambat') newStats.terlambat += 1
      if (newStatus === 'ditolak') newStats.ditolak += 1
      return newStats
    })

    // Prepend activity feed (cap 20)
    const studentName =
      studentsMap.get(row.student_id)?.full_name ?? 'Mahasiswa'
    setActivity((prev) =>
      [
        {
          id: row.id,
          studentName,
          status: row.is_mock_location ? 'ditolak' : row.status,
          timestamp: row.scanned_at,
          isMock: row.is_mock_location ?? false,
        },
        ...prev,
      ].slice(0, 20),
    )

    // Pulse highlight 1 detik
    setPulseStudentId(row.student_id)
    setTimeout(() => setPulseStudentId(null), 1000)
  }, [studentsMap])

  // Realtime subscription
  useRealtimeAttendances({
    sessionId: props.sessionId,
    enabled: props.isActive,
    onInsert: handleRealtimeInsert,
    onStatusChange: (status) => setSyncStatus(status),
  })

  // Filter students
  const filteredStudents = useMemo(() => {
    const all = Array.from(studentsMap.values())
    switch (filterChip) {
      case 'semua':
        return all
      case 'hadir':
        return all.filter((s) => s.status === 'hadir')
      case 'telat':
        return all.filter((s) => s.status === 'terlambat')
      case 'belum':
        return all.filter((s) => s.status === 'belum')
      case 'ditolak':
        return all.filter((s) => s.status === 'ditolak')
    }
  }, [studentsMap, filterChip])

  // Handlers
  const handleEndSession = useCallback(async () => {
    const result = await swal.fire({
      title: 'Akhiri sesi sekarang?',
      text: 'Mahasiswa tidak akan bisa scan QR lagi setelah sesi diakhiri.',
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Ya, Akhiri',
      cancelButtonText: 'Batal',
      reverseButtons: true,
    })
    if (!result.isConfirmed) return

    setIsEnding(true)
    try {
      const res = await toggleSessionAction(props.sessionId, false)
      if (res.error) {
        toast.fire({ icon: 'error', title: res.error })
        setIsEnding(false)
        return
      }
      toast.fire({ icon: 'success', title: 'Sesi berhasil diakhiri' })
      setTimeout(() => router.replace('/sesi'), 500)
    } catch {
      toast.fire({ icon: 'error', title: 'Gagal mengakhiri sesi' })
      setIsEnding(false)
    }
  }, [props.sessionId, router])

  const handleRefreshCode = useCallback(async () => {
    setIsRefreshingCode(true)
    try {
      const res = await refreshSessionCode(props.sessionId)
      if (res.error) {
        toast.fire({ icon: 'error', title: res.error })
      } else {
        toast.fire({ icon: 'success', title: 'Kode sesi berhasil di-refresh' })
        router.refresh()
      }
    } catch {
      toast.fire({ icon: 'error', title: 'Gagal refresh kode' })
    }
    setTimeout(() => setIsRefreshingCode(false), 800)
  }, [props.sessionId, router])

  // Derived
  const tooFarStudents = useMemo(() => {
    let count = 0
    for (const s of Array.from(studentsMap.values())) {
      if (s.distance_meters !== null && s.distance_meters > 300) count++
    }
    return count
  }, [studentsMap])

  return (
    <div className="space-y-6 pb-12">
      {/* Topbar */}
      <MonitorTopbar
        courseCode={props.courseCode}
        courseName={props.courseName}
        dosenName={props.dosenName}
        sessionNumber={props.sessionNumber}
        topic={props.topic}
        isActive={props.isActive}
        sessionCode={props.sessionCode}
        countdownSec={countdownSec}
        syncStatus={syncStatus}
        isEnding={isEnding}
        isRefreshingCode={isRefreshingCode}
        onEndSession={handleEndSession}
        onRefreshCode={handleRefreshCode}
      />

      {/* KPI Bar */}
      <MonitorKpiBar stats={stats} />

      {/* Sync error banner */}
      {(syncStatus === 'CHANNEL_ERROR' || syncStatus === 'TIMED_OUT') && (
        <div className="flex items-center gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          <WifiOff className="h-4 w-4 shrink-0" />
          <span>
            Sync terganggu, mencoba reconnect... Update real-time pause sebentar.
          </span>
        </div>
      )}

      {/* Too far students banner */}
      {tooFarStudents > 0 && (
        <div className="flex items-center gap-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          <AlertCircle className="h-4 w-4 shrink-0" />
          <span>
            {tooFarStudents} mahasiswa terlalu jauh (&gt;300m), tidak ditampilkan
            di peta.
          </span>
        </div>
      )}

      {/* Main grid: geofence + activity feed */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[480px_1fr]">
        {/* Geofence ring + activity feed sidebar */}
        <div className="space-y-6">
          <GeofenceRing
            centerLat={props.geofenceCenter?.lat ?? null}
            centerLng={props.geofenceCenter?.lng ?? null}
            radius={props.geofenceRadius}
            students={Array.from(studentsMap.values())}
          />
          <ActivityFeed events={activity} />
        </div>

        {/* Student grid */}
        <StudentGrid
          allStudents={Array.from(studentsMap.values())}
          filteredStudents={filteredStudents}
          stats={stats}
          filterChip={filterChip}
          onFilterChange={setFilterChip}
          pulseStudentId={pulseStudentId}
        />
      </div>

      {props.sessionCode && (
        <p className="sr-only">Kode sesi: {props.sessionCode}</p>
      )}
    </div>
  )
}

// ============================================================================
// Sub-component: MonitorTopbar
// ============================================================================

function MonitorTopbar({
  courseCode,
  courseName,
  dosenName,
  sessionNumber,
  topic,
  isActive,
  sessionCode,
  countdownSec,
  syncStatus,
  isEnding,
  isRefreshingCode,
  onEndSession,
  onRefreshCode,
}: {
  courseCode: string
  courseName: string
  dosenName: string | null
  sessionNumber: number
  topic: string | null
  isActive: boolean
  sessionCode: string | null
  countdownSec: number
  syncStatus: RealtimeChannelStatus
  isEnding: boolean
  isRefreshingCode: boolean
  onEndSession: () => void
  onRefreshCode: () => void
}) {
  return (
    <div className="rounded-2xl border border-border bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0 flex-1">
          <div className="mb-2 flex flex-wrap items-center gap-2">
            <span className="inline-flex items-center gap-1.5 rounded-full bg-primary/10 px-3 py-1 text-xs font-semibold text-primary">
              <Activity className="h-3 w-3" />
              {courseCode} · Pertemuan {sessionNumber}
            </span>
            {isActive ? (
              <span className="inline-flex items-center gap-1.5 rounded-full border border-green-300 bg-green-50 px-3 py-1 text-xs font-semibold uppercase tracking-wider text-green-700">
                <span className="relative flex h-2 w-2">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-500 opacity-75" />
                  <span className="relative inline-flex h-2 w-2 rounded-full bg-green-500" />
                </span>
                Live · Sesi Aktif
              </span>
            ) : (
              <span className="inline-flex items-center gap-1.5 rounded-full border border-gray-300 bg-gray-50 px-3 py-1 text-xs font-semibold uppercase text-gray-600">
                Sesi Berakhir
              </span>
            )}
            {syncStatus === 'SUBSCRIBED' && isActive && (
              <span className="inline-flex items-center gap-1.5 text-xs font-medium text-green-600">
                <CheckCircle2 className="h-3 w-3" />
                Sync aktif
              </span>
            )}
          </div>
          <h1 className="text-2xl font-bold leading-tight text-text-primary">
            {courseName}
          </h1>
          <div className="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-text-secondary">
            {dosenName && <span>Dosen: {dosenName}</span>}
            {topic && <span>· {topic}</span>}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {sessionCode && isActive && (
            <div className="flex items-center gap-2 rounded-xl border border-border bg-gray-50 px-4 py-2">
              <div className="text-xs font-medium text-text-secondary">
                Kode Sesi
              </div>
              <div className="font-mono text-lg font-bold tracking-wider text-text-primary">
                {sessionCode.slice(0, 3)}
                <span className="mx-0.5 text-amber-500">·</span>
                {sessionCode.slice(3, 6)}
              </div>
              <div className="flex items-center gap-1 text-xs font-medium text-text-secondary">
                <Clock className="h-3 w-3" />
                <span className="font-mono">{formatCountdown(countdownSec)}</span>
              </div>
              <button
                onClick={onRefreshCode}
                disabled={isRefreshingCode}
                className="rounded-md p-1 text-text-tertiary transition-colors hover:bg-white hover:text-primary disabled:opacity-50"
                title="Refresh Kode"
              >
                <RefreshCw
                  className={cn('h-4 w-4', isRefreshingCode && 'animate-spin')}
                />
              </button>
            </div>
          )}
          {isActive && (
            <button
              onClick={onEndSession}
              disabled={isEnding}
              className="inline-flex items-center gap-2 rounded-xl border border-red-300 bg-red-50 px-4 py-2 text-sm font-semibold text-red-700 transition-colors hover:bg-red-100 disabled:opacity-50"
            >
              <StopCircle className={cn('h-4 w-4', isEnding && 'animate-pulse')} />
              {isEnding ? 'Mengakhiri...' : 'Akhiri Sesi'}
            </button>
          )}
        </div>
      </div>
    </div>
  )
}

// ============================================================================
// Sub-component: MonitorKpiBar — 4 cards with animated counter
// ============================================================================

function MonitorKpiBar({ stats }: { stats: LiveStats }) {
  const cards: Array<{
    label: string
    value: number
    icon: React.ComponentType<{ className?: string }>
    color: string
    bgColor: string
  }> = [
    {
      label: 'Hadir',
      value: stats.hadir,
      icon: CheckCircle2,
      color: 'text-green-600',
      bgColor: 'bg-green-50',
    },
    {
      label: 'Telat',
      value: stats.terlambat,
      icon: Clock,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
    },
    {
      label: 'Belum',
      value: stats.belum,
      icon: Users,
      color: 'text-gray-600',
      bgColor: 'bg-gray-50',
    },
    {
      label: 'Total Terdaftar',
      value: stats.total,
      icon: Users,
      color: 'text-primary',
      bgColor: 'bg-primary/5',
    },
  ]

  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
      {cards.map((card) => (
        <KpiCard key={card.label} {...card} />
      ))}
    </div>
  )
}

function KpiCard({
  label,
  value,
  icon: Icon,
  color,
  bgColor,
}: {
  label: string
  value: number
  icon: React.ComponentType<{ className?: string }>
  color: string
  bgColor: string
}) {
  const animated = useAnimatedCounter(value)
  return (
    <div className="rounded-2xl border border-border bg-white p-4 shadow-sm">
      <div className="flex items-center gap-3">
        <div className={cn('flex h-10 w-10 items-center justify-center rounded-xl', bgColor)}>
          <Icon className={cn('h-5 w-5', color)} />
        </div>
        <div className="min-w-0">
          <div className={cn('text-2xl font-bold tabular-nums', color)}>
            {animated}
          </div>
          <div className="truncate text-xs font-medium text-text-secondary">
            {label}
          </div>
        </div>
      </div>
    </div>
  )
}

// ============================================================================
// Sub-component: GeofenceRing
// ============================================================================

function GeofenceRing({
  centerLat,
  centerLng,
  radius,
  students,
}: {
  centerLat: number | null
  centerLng: number | null
  radius: number
  students: StudentLiveRow[]
}) {
  const cx = RING_SIZE_PX / 2
  const r150 = RING_OUTER_RADIUS_PX
  const r100 = RING_OUTER_RADIUS_PX * (100 / radius)
  const r50 = RING_OUTER_RADIUS_PX * (50 / radius)

  // Compute positions for students with GPS
  const dots = students
    .filter((s) => s.student_lat !== null && s.student_lng !== null)
    .map((s) => ({
      ...s,
      ...computeDotPosition(centerLat, centerLng, s.student_lat, s.student_lng, RING_SIZE_PX, radius),
    }))

  return (
    <div className="rounded-2xl border border-border bg-white p-5 shadow-sm">
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h3 className="flex items-center gap-2 text-sm font-bold text-text-primary">
            <MapPin className="h-4 w-4 text-primary" />
            Peta Geofence
          </h3>
          <p className="mt-0.5 text-xs text-text-tertiary">
            Radius {radius}m dari pusat kampus
          </p>
        </div>
      </div>

      <div className="relative mx-auto" style={{ width: RING_SIZE_PX, height: RING_SIZE_PX }}>
        <svg
          width={RING_SIZE_PX}
          height={RING_SIZE_PX}
          viewBox={`0 0 ${RING_SIZE_PX} ${RING_SIZE_PX}`}
          className="absolute inset-0"
        >
          {/* Subtle background grid */}
          <defs>
            <pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
              <path d="M 20 0 L 0 0 0 20" fill="none" stroke="rgba(0,0,0,0.04)" strokeWidth="0.5" />
            </pattern>
          </defs>
          <rect width={RING_SIZE_PX} height={RING_SIZE_PX} fill="url(#grid)" />

          {/* Concentric rings */}
          <circle cx={cx} cy={cx} r={r150} fill="none" stroke="rgba(45,134,255,0.4)" strokeWidth="2" strokeDasharray="6 4" />
          <circle cx={cx} cy={cx} r={r100} fill="none" stroke="rgba(45,134,255,0.3)" strokeWidth="1.5" strokeDasharray="6 4" />
          <circle cx={cx} cy={cx} r={r50} fill="none" stroke="rgba(45,134,255,0.25)" strokeWidth="1.5" strokeDasharray="4 4" />

          {/* Ring labels */}
          <text x={cx} y={cx - r150 - 4} textAnchor="middle" className="fill-text-tertiary text-[10px] font-mono">{radius}m</text>
          <text x={cx} y={cx - r100 - 4} textAnchor="middle" className="fill-text-tertiary text-[10px] font-mono">100m</text>
          <text x={cx} y={cx - r50 - 4} textAnchor="middle" className="fill-text-tertiary text-[10px] font-mono">50m</text>

          {/* Center marker */}
          <circle cx={cx} cy={cx} r="6" fill="rgb(var(--color-primary))" />
          <circle cx={cx} cy={cx} r="10" fill="none" stroke="rgb(var(--color-primary))" strokeOpacity="0.3" strokeWidth="2" />

          {/* Student dots */}
          {dots.map((dot) => {
            const colors = getStatusColor(dot.status)
            const isOutOfRange = !dot.withinRange && dot.distance <= 300
            return (
              <g key={dot.student_id} style={{ transition: 'transform 0.3s ease' }}>
                <circle
                  cx={dot.x}
                  cy={dot.y}
                  r="6"
                  fill={colors.fill}
                  stroke={isOutOfRange ? '#dc2626' : '#ffffff'}
                  strokeWidth={isOutOfRange ? '2' : '1.5'}
                >
                  <title>
                    {dot.full_name} · {getStatusLabel(dot.status)}
                    {dot.distance_meters !== null && ` · ${Math.round(dot.distance_meters)}m`}
                  </title>
                </circle>
              </g>
            )
          })}
        </svg>

        {/* Center label */}
        <div
          className="absolute text-center text-[10px] font-semibold text-primary"
          style={{ left: 0, right: 0, top: cx + 12 }}
        >
          Pusat Kampus
        </div>
      </div>

      {/* Legend */}
      <div className="mt-4 flex flex-wrap gap-3 text-xs text-text-secondary">
        <LegendDot color="bg-green-500" label="Hadir" />
        <LegendDot color="bg-blue-500" label="Telat" />
        <LegendDot color="bg-amber-500" label="Izin/Sakit" />
        <LegendDot color="bg-red-500" label="Ditolak" />
      </div>

      {centerLat === null && (
        <div className="mt-4 flex items-center gap-2 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
          <AlertCircle className="h-3 w-3 shrink-0" />
          Lokasi pusat kampus belum di-set untuk sesi ini.
        </div>
      )}
    </div>
  )
}

function LegendDot({ color, label }: { color: string; label: string }) {
  return (
    <div className="flex items-center gap-1.5">
      <div className={cn('h-2.5 w-2.5 rounded-full', color)} />
      <span>{label}</span>
    </div>
  )
}

// ============================================================================
// Sub-component: ActivityFeed
// ============================================================================

function ActivityFeed({ events }: { events: ActivityEvent[] }) {
  return (
    <div className="rounded-2xl border border-border bg-white p-5 shadow-sm">
      <h3 className="mb-4 flex items-center gap-2 text-sm font-bold text-text-primary">
        <Activity className="h-4 w-4 text-primary" />
        Aktivitas Terkini
      </h3>

      {events.length === 0 ? (
        <div className="py-8 text-center">
          <Clock className="mx-auto mb-2 h-8 w-8 text-text-tertiary" />
          <p className="text-sm text-text-tertiary">
            Menunggu mahasiswa scan QR...
          </p>
        </div>
      ) : (
        <div className="max-h-80 space-y-2 overflow-y-auto">
          {events.map((event) => {
            const colors = getStatusColor(event.status)
            return (
              <div
                key={event.id}
                className={cn(
                  'flex items-center gap-3 rounded-xl px-3 py-2.5 transition-all',
                  colors.bg,
                  colors.border,
                  'border',
                )}
              >
                <div
                  className={cn(
                    'flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white',
                  )}
                  style={{ backgroundColor: colors.fill }}
                >
                  {event.studentName.charAt(0).toUpperCase()}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-medium text-text-primary">
                    {event.studentName}
                  </div>
                  <div className={cn('text-xs font-semibold uppercase', colors.text)}>
                    {getStatusLabel(event.status)}
                    {event.isMock && ' · Mock GPS'}
                  </div>
                </div>
                <div className="shrink-0 text-xs font-medium text-text-tertiary">
                  {formatRelativeTime(event.timestamp)}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

// ============================================================================
// Sub-component: StudentGrid + FilterChips + StudentCard
// ============================================================================

function StudentGrid({
  allStudents,
  filteredStudents,
  stats,
  filterChip,
  onFilterChange,
  pulseStudentId,
}: {
  allStudents: StudentLiveRow[]
  filteredStudents: StudentLiveRow[]
  stats: LiveStats
  filterChip: FilterChip
  onFilterChange: (chip: FilterChip) => void
  pulseStudentId: string | null
}) {
  const chips: Array<{ id: FilterChip; label: string; count: number }> = [
    { id: 'semua', label: 'Semua', count: allStudents.length },
    { id: 'hadir', label: 'Hadir', count: stats.hadir },
    { id: 'telat', label: 'Telat', count: stats.terlambat },
    { id: 'belum', label: 'Belum', count: stats.belum },
    { id: 'ditolak', label: 'Ditolak', count: stats.ditolak },
  ]

  return (
    <div className="rounded-2xl border border-border bg-white p-5 shadow-sm">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h3 className="flex items-center gap-2 text-sm font-bold text-text-primary">
          <Users className="h-4 w-4 text-primary" />
          Daftar Mahasiswa
        </h3>
      </div>

      {/* Filter chips */}
      <div className="mb-4 flex flex-wrap gap-2">
        {chips.map((chip) => (
          <button
            key={chip.id}
            onClick={() => onFilterChange(chip.id)}
            className={cn(
              'inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors',
              filterChip === chip.id
                ? 'border-primary bg-primary text-white'
                : 'border-border bg-white text-text-secondary hover:bg-gray-50',
            )}
          >
            {chip.label}
            <span
              className={cn(
                'rounded-full px-1.5 py-0.5 text-[10px] font-bold',
                filterChip === chip.id
                  ? 'bg-white/25 text-white'
                  : 'bg-gray-100 text-text-secondary',
              )}
            >
              {chip.count}
            </span>
          </button>
        ))}
      </div>

      {/* Grid */}
      {filteredStudents.length === 0 ? (
        <div className="py-12 text-center">
          <Users className="mx-auto mb-3 h-10 w-10 text-text-tertiary" />
          <p className="text-sm text-text-tertiary">
            Tidak ada mahasiswa di kategori ini.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {filteredStudents.map((student) => (
            <StudentCard
              key={student.student_id}
              student={student}
              isPulsing={pulseStudentId === student.student_id}
            />
          ))}
        </div>
      )}
    </div>
  )
}

function StudentCard({
  student,
  isPulsing,
}: {
  student: StudentLiveRow
  isPulsing: boolean
}) {
  const colors = getStatusColor(student.status)
  const isBelum = student.status === 'belum'

  return (
    <div
      className={cn(
        'flex items-center gap-3 rounded-xl border px-3 py-2.5 transition-all',
        colors.bg,
        colors.border,
        isBelum && 'opacity-60',
        isPulsing && 'ring-2 ring-primary ring-offset-2',
      )}
    >
      <div
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white"
        style={{ backgroundColor: colors.fill }}
      >
        {student.full_name.charAt(0).toUpperCase()}
      </div>
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-semibold text-text-primary">
          {student.full_name}
        </div>
        <div className="flex items-center gap-1.5 text-xs">
          {student.nim && (
            <span className="text-text-tertiary">{student.nim}</span>
          )}
          <span className={cn('font-semibold uppercase', colors.text)}>
            · {getStatusLabel(student.status)}
          </span>
        </div>
      </div>
      {student.is_mock_location && (
        <XCircle className="h-4 w-4 shrink-0 text-red-500" />
      )}
    </div>
  )
}
