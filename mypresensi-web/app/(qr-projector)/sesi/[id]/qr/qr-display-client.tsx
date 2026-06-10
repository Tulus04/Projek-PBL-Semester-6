'use client'

// app/(qr-projector)/sesi/[id]/qr/qr-display-client.tsx
// Client Component untuk mode presentasi fullscreen QR.
// Handle: countdown timer, polling stats 5s, expired overlay, refresh code,
// abort cleanup, exponential backoff on consecutive errors.
//
// Phase 3 v7 (Rolling QR TOTP-like) — tambah polling kedua paralel ke
// `/api/admin/sessions/:id/current-code` setiap 5 detik untuk dapat code current.
// QR `value` + countdown derive dari STATE polling (bukan prop SSR static).
// Sessions legacy (seed=null) tetap kompatibel via fallback ke prop expires_at.
//
// Diakses dari Server Component page.tsx — semua initial data via props.

import { useEffect, useRef, useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { QRCodeSVG } from 'qrcode.react'
import {
  Maximize2,
  RefreshCw,
  X,
  Clock,
  Users,
  GraduationCap,
  MapPin,
  Wifi,
  WifiOff,
  AlertCircle,
} from 'lucide-react'
import { refreshSessionCode } from '@/lib/actions/sessions'
import { toast } from '@/lib/swal'

// ============================================================================
// Types
// ============================================================================

interface QrDisplayClientProps {
  sessionId: string
  sessionCode: string | null
  sessionCodeExpiresAt: string | null
  sessionNumber: number
  topic: string | null
  mode: string // 'offline' | 'online'
  isActive: boolean
  startedAt: string | null
  courseCode: string
  courseName: string
  dosenName: string | null
  initialStats: { hadir: number; total: number }
}

interface LiveStats {
  hadir: number
  total: number
}

type PollState = 'idle' | 'fetching' | 'success' | 'error' | 'backoff'

// ============================================================================
// Helpers
// ============================================================================

const SESSION_CODE_EXPIRY_TOTAL_SEC = 180 // 3 menit default — match settings table

/**
 * Algorithm 1: Compute countdown seconds remaining from ISO expiresAt.
 * Returns 0 if expired or null. Pure function — easy to test.
 */
export function computeCountdown(expiresAt: string | null): number {
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

// Format jam HH:mm dari ISO string ke timezone Asia/Jakarta (WIB UTC+7).
// Pakai Intl.DateTimeFormat dengan timeZone explicit untuk konsistensi SSR
// vs client (Node.js server timezone vs browser timezone bisa beda — fix
// hydration mismatch). Fallback ke '--:--' kalau iso invalid.
function formatStartTime(iso: string | null): string {
  if (!iso) return '--:--'
  try {
    const d = new Date(iso)
    if (Number.isNaN(d.getTime())) return '--:--'
    return new Intl.DateTimeFormat('en-GB', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
      timeZone: 'Asia/Jakarta',
    }).format(d)
  } catch {
    return '--:--'
  }
}

// ============================================================================
// Main Component
// ============================================================================

export function QrDisplayClient(props: QrDisplayClientProps) {
  const router = useRouter()

  // Countdown state — init 0 deterministic untuk SSR safety (fix React hydration
  // mismatch). Akan di-overwrite di useEffect setelah mount via computeCountdown.
  // Note: formatStartTime() pakai Intl.DateTimeFormat timeZone='Asia/Jakarta'
  // supaya SSR (UTC) dan client (WIB) menghasilkan output identik.
  const [countdownSec, setCountdownSec] = useState<number>(0)

  // Stats + polling state
  const [stats, setStats] = useState<LiveStats>(props.initialStats)
  const [pollState, setPollState] = useState<PollState>('idle')

  // Refresh code state
  const [isRefreshing, setIsRefreshing] = useState(false)

  // Banner state (untuk 403/404 → auto-close)
  const [banner, setBanner] = useState<string | null>(null)

  // ===========================================================================
  // Phase 3 v7 — Rolling QR state (current-code polling)
  // ===========================================================================
  // Initialize dari prop SSR supaya first render tidak flicker. Polling kedua
  // (paralel dengan live-stats) akan refresh setiap 5 detik.
  const [currentCode, setCurrentCode] = useState<string | null>(
    props.sessionCode,
  )
  const [windowTtlMs, setWindowTtlMs] = useState<number>(0)
  const [isRolling, setIsRolling] = useState<boolean>(false)

  // Refs untuk cleanup
  const errorCountRef = useRef(0)
  const pollTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const abortRef = useRef<AbortController | null>(null)
  const isMountedRef = useRef(true)

  // ===========================================================================
  // Countdown setInterval — Algorithm 1
  // ===========================================================================
  useEffect(() => {
    setCountdownSec(computeCountdown(props.sessionCodeExpiresAt))

    const interval = setInterval(() => {
      setCountdownSec(computeCountdown(props.sessionCodeExpiresAt))
    }, 1000)

    return () => clearInterval(interval)
  }, [props.sessionCodeExpiresAt])

  // ===========================================================================
  // Polling lifecycle — Algorithm 2
  // ===========================================================================
  const executePoll = useCallback(async () => {
    if (!isMountedRef.current) return

    abortRef.current = new AbortController()
    setPollState('fetching')

    try {
      const response = await fetch(
        `/api/admin/sessions/${props.sessionId}/live-stats`,
        { signal: abortRef.current.signal, cache: 'no-store' },
      )

      if (!isMountedRef.current) return

      if (response.status === 401) {
        window.location.href = '/login?next=/sesi'
        return
      }

      if (response.status === 403) {
        setBanner('Tidak ada akses ke sesi ini. Window akan tertutup otomatis.')
        setPollState('error')
        setTimeout(() => {
          if (typeof window !== 'undefined') window.close()
        }, 3000)
        return
      }

      if (response.status === 404) {
        setBanner('Sesi sudah dihapus. Window akan tertutup otomatis.')
        setPollState('error')
        setTimeout(() => {
          if (typeof window !== 'undefined') window.close()
        }, 3000)
        return
      }

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = (await response.json()) as LiveStats
      if (!isMountedRef.current) return

      setStats(data)
      setPollState('success')
      errorCountRef.current = 0
      schedulePoll(5000)
    } catch (err) {
      if (!isMountedRef.current) return
      // AbortError = expected on unmount, silent
      if (err instanceof DOMException && err.name === 'AbortError') return

      errorCountRef.current += 1
      if (errorCountRef.current >= 3) {
        setPollState('backoff')
        schedulePoll(30_000)
      } else {
        setPollState('error')
        schedulePoll(5_000)
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [props.sessionId])

  const schedulePoll = useCallback(
    (delayMs: number) => {
      if (!isMountedRef.current) return
      if (pollTimeoutRef.current) clearTimeout(pollTimeoutRef.current)
      pollTimeoutRef.current = setTimeout(executePoll, delayMs)
    },
    [executePoll],
  )

  useEffect(() => {
    isMountedRef.current = true
    schedulePoll(5000) // first poll setelah 5 detik (initial sudah dari SSR)

    return () => {
      isMountedRef.current = false
      if (pollTimeoutRef.current) clearTimeout(pollTimeoutRef.current)
      if (abortRef.current) abortRef.current.abort()
    }
  }, [schedulePoll])

  // ===========================================================================
  // Phase 3 v7 — Polling current-code (paralel dengan live-stats)
  // ===========================================================================
  // Polling independen ke /api/admin/sessions/:id/current-code setiap 5 detik.
  // Dapat current_code (rolling/legacy), window TTL, is_rolling, is_active.
  // Pattern: AbortController + 3x consecutive error → backoff 30s, 410 → banner
  // + auto-close (sama dengan live-stats handler 403/404).
  useEffect(() => {
    let cancelled = false
    const controller = new AbortController()
    let consecutiveErrors = 0
    let timeoutId: ReturnType<typeof setTimeout> | null = null

    async function pollCurrentCode() {
      if (cancelled) return
      try {
        const res = await fetch(
          `/api/admin/sessions/${props.sessionId}/current-code`,
          { signal: controller.signal, cache: 'no-store' },
        )

        if (cancelled) return

        // 401 → tidak terautentikasi, redirect login (samakan dengan live-stats)
        if (res.status === 401) {
          window.location.href = '/login?next=/sesi'
          return
        }

        // 410 Gone → sesi sudah berakhir, banner + auto-close window
        if (res.status === 410) {
          if (!cancelled) {
            setBanner('Sesi sudah berakhir. Window akan tertutup otomatis.')
            setTimeout(() => {
              if (typeof window !== 'undefined') window.close()
            }, 3000)
          }
          return
        }

        if (!res.ok) {
          consecutiveErrors += 1
          const interval = consecutiveErrors >= 3 ? 30_000 : 5000
          if (!cancelled) {
            timeoutId = setTimeout(pollCurrentCode, interval)
          }
          return
        }

        consecutiveErrors = 0
        const data = (await res.json()) as {
          current_code: string | null
          window: number | null
          ttl_ms_until_next: number
          is_rolling: boolean
          is_active: boolean
          expires_at: string | null
        }

        if (!cancelled) {
          setCurrentCode(data.current_code)
          setWindowTtlMs(data.ttl_ms_until_next ?? 0)
          setIsRolling(data.is_rolling === true)
        }

        if (!cancelled) {
          // Sinkronisasi polling dengan sisa TTL window dari server!
          // Jika rolling, tunggu sesuai sisa TTL + 50ms padding agar request
          // persis jatuh di window berikutnya. Jika tidak, fallback 5 detik.
          const nextPollDelay = data.is_rolling && data.ttl_ms_until_next > 0
            ? data.ttl_ms_until_next + 50
            : 5000
          timeoutId = setTimeout(pollCurrentCode, nextPollDelay)
        }
      } catch (err) {
        if (cancelled) return
        // AbortError = expected on unmount, silent
        if (err instanceof DOMException && err.name === 'AbortError') return

        consecutiveErrors += 1
        const interval = consecutiveErrors >= 3 ? 30_000 : 5000
        timeoutId = setTimeout(pollCurrentCode, interval)
      }
    }

    // Kick off pertama segera (initial state dari prop SSR sudah siap).
    pollCurrentCode()

    return () => {
      cancelled = true
      controller.abort()
      if (timeoutId) clearTimeout(timeoutId)
    }
  }, [props.sessionId])

  // ===========================================================================
  // Phase 3 v7 — Local TTL ticker untuk OtpBlock countdown (rolling mode)
  // ===========================================================================
  // Saat isRolling=true, decrement windowTtlMs lokal setiap 1 detik supaya
  // bar countdown turun smooth. Polling next tick reset ke fresh value (~30s).
  useEffect(() => {
    if (!isRolling) return
    const interval = setInterval(() => {
      setWindowTtlMs((prev) => Math.max(0, prev - 1000))
    }, 1000)
    return () => clearInterval(interval)
  }, [isRolling])

  // ===========================================================================
  // Refresh code handler
  // ===========================================================================
  const handleRefreshCode = useCallback(async () => {
    setIsRefreshing(true)
    try {
      const result = await refreshSessionCode(props.sessionId)
      if (result.error) {
        toast.fire({ icon: 'error', title: result.error })
        setIsRefreshing(false)
        return
      }
      // Re-fetch session via Next.js router refresh
      router.refresh()
      // Reset isRefreshing after a small delay agar countdown timer nge-update lewat props baru
      setTimeout(() => setIsRefreshing(false), 800)
    } catch {
      toast.fire({ icon: 'error', title: 'Gagal memuat QR baru' })
      setIsRefreshing(false)
    }
  }, [props.sessionId, router])

  // ===========================================================================
  // Derived state
  // ===========================================================================
  // Phase 3 v7 — Logic countdown:
  //   - Rolling mode: countdownSec dari windowTtlMs (max 30s, turun ke 0 lalu
  //     reset polling next tick). NEVER expired.
  //   - Legacy mode: existing logic — countdownSec dari expires_at, isExpired
  //     saat 0, ExpiredOverlay tampil saat expired + isActive.
  const rollingCountdownSec = Math.ceil(windowTtlMs / 1000)
  const displayCountdownSec = isRolling ? rollingCountdownSec : countdownSec

  // ExpiredOverlay HANYA untuk legacy mode — rolling code tidak pernah expired.
  const isLegacyExpired = !isRolling && countdownSec === 0

  // Fill percentage bar countdown.
  //   - Rolling: relatif ke window 5s (Phase 3 v7 A1 config)
  //   - Legacy: relatif ke 3-menit total
  const ROLLING_WINDOW_SEC = 5
  const fillPct = isRolling
    ? Math.max(
        0,
        Math.min(100, (rollingCountdownSec / ROLLING_WINDOW_SEC) * 100),
      )
    : SESSION_CODE_EXPIRY_TOTAL_SEC > 0
      ? Math.max(
          0,
          Math.min(100, (countdownSec / SESSION_CODE_EXPIRY_TOTAL_SEC) * 100),
        )
      : 0
  const hadirPct =
    stats.total > 0 ? Math.min(100, (stats.hadir / stats.total) * 100) : 0

  // Phase 3 v7 — QR derive dari currentCode STATE (bukan prop SSR static).
  // `exp` field dipertahankan untuk backward compat parser mobile, tapi
  // tidak relevan di rolling mode (server verify pakai TOTP window).
  const qrPayload = currentCode
    ? JSON.stringify({
        sid: props.sessionId,
        code: currentCode,
        exp: props.sessionCodeExpiresAt,
      })
    : ''

  // ===========================================================================
  // Render
  // ===========================================================================
  return (
    <div className="relative flex min-h-screen flex-col overflow-hidden px-12 py-8">
      {/* Background gradient + radial glows */}
      <div
        className="pointer-events-none absolute inset-0 -z-10"
        style={{
          background:
            'radial-gradient(ellipse at top left, #0D2C5E 0%, #050d1c 60%)',
        }}
      />
      <div
        className="pointer-events-none absolute -right-[10%] -top-[20%] h-[600px] w-[600px] -z-10"
        style={{
          background:
            'radial-gradient(circle, rgba(244,180,0,0.18) 0%, transparent 60%)',
        }}
      />
      <div
        className="pointer-events-none absolute -bottom-[30%] -left-[10%] h-[600px] w-[600px] -z-10"
        style={{
          background:
            'radial-gradient(circle, rgba(45,134,255,0.20) 0%, transparent 60%)',
        }}
      />

      {/* Banner (403/404 alert) */}
      {banner && (
        <div className="mb-4 rounded-2xl border border-red-400/40 bg-red-900/30 px-6 py-4 text-center text-base text-red-200 backdrop-blur-md">
          <AlertCircle className="mr-2 inline h-5 w-5" />
          {banner}
        </div>
      )}

      {/* Topbar */}
      <PresTopbar
        courseName={props.courseName}
        courseCode={props.courseCode}
        isActive={props.isActive}
        pollState={pollState}
      />

      {/* Main content split */}
      <div className="grid flex-1 grid-cols-[380px_1fr] items-center gap-14 py-6">
        {/* Left: QR Card */}
        <QrCard qrPayload={qrPayload} startedAt={props.startedAt} mode={props.mode} />

        {/* Right: Info area */}
        <div className="flex flex-col gap-8">
          <MkHeader
            courseName={props.courseName}
            courseCode={props.courseCode}
            dosenName={props.dosenName}
            sessionNumber={props.sessionNumber}
            topic={props.topic}
            startedAt={props.startedAt}
            mode={props.mode}
          />

          <OtpCountdown
            countdownSec={displayCountdownSec}
            fillPct={fillPct}
            isRolling={isRolling}
          />

          <InstructionList />
        </div>
      </div>

      {/* Bottom progress strip */}
      <PresProgress stats={stats} hadirPct={hadirPct} pollState={pollState} />

      {/* Expired overlay — HANYA legacy mode (rolling code tidak pernah expired, R8.12) */}
      {isLegacyExpired && props.isActive && (
        <ExpiredOverlay
          isRefreshing={isRefreshing}
          onRefresh={handleRefreshCode}
        />
      )}
    </div>
  )
}

// ============================================================================
// Sub-component: PresTopbar
// ============================================================================

function PresTopbar({
  courseName,
  courseCode,
  isActive,
  pollState,
}: {
  courseName: string
  courseCode: string
  isActive: boolean
  pollState: PollState
}) {
  return (
    <div className="mb-6 flex items-center justify-between gap-4">
      <div className="flex items-center gap-3">
        <div
          className="flex h-12 w-12 items-center justify-center rounded-2xl text-lg font-extrabold text-white"
          style={{
            background: 'linear-gradient(135deg, #2D86FF 0%, #F4B400 100%)',
            boxShadow: '0 8px 20px rgba(244, 180, 0, 0.3)',
            fontFamily: 'Plus Jakarta Sans, sans-serif',
          }}
        >
          MP
        </div>
        <div>
          <div className="text-lg font-bold leading-tight text-white">
            MyPresensi
          </div>
          <div className="text-xs text-white/60">
            {courseCode} · {courseName}
          </div>
        </div>
      </div>

      <div className="flex items-center gap-3">
        {pollState === 'backoff' && (
          <span className="inline-flex items-center gap-2 rounded-full border border-amber-400/40 bg-amber-900/20 px-3 py-1 text-xs font-semibold text-amber-200">
            <WifiOff className="h-3.5 w-3.5" />
            Sync terganggu
          </span>
        )}
        {isActive ? (
          <span className="inline-flex items-center gap-2 rounded-full border border-green-400/40 bg-green-900/20 px-4 py-2 text-xs font-semibold uppercase tracking-wider text-green-300">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-400 opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-green-400" />
            </span>
            Sesi Aktif
          </span>
        ) : (
          <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-wider text-white/70">
            Sesi Tidak Aktif
          </span>
        )}
        <button
          onClick={() => {
            if (typeof window !== 'undefined') window.close()
          }}
          className="inline-flex items-center gap-2 rounded-xl border border-white/15 bg-white/10 px-4 py-2 text-sm font-semibold text-white backdrop-blur-md transition-colors hover:bg-white/20"
          aria-label="Tutup window"
        >
          <X className="h-4 w-4" />
          Tutup
        </button>
      </div>
    </div>
  )
}

// ============================================================================
// Sub-component: QrCard
// ============================================================================

function QrCard({
  qrPayload,
  startedAt,
  mode,
}: {
  qrPayload: string
  startedAt: string | null
  mode: string
}) {
  return (
    <div
      className="relative rounded-3xl bg-white p-6"
      style={{
        boxShadow:
          '0 0 0 6px rgba(255, 255, 255, 0.08), 0 30px 80px rgba(0, 0, 0, 0.5), 0 0 60px rgba(244, 180, 0, 0.20)',
      }}
    >
      {/* Gradient blur halo */}
      <div
        className="pointer-events-none absolute -inset-0.5 -z-10 rounded-[26px] opacity-50"
        style={{
          background: 'linear-gradient(135deg, #F4B400 0%, #2D86FF 100%)',
          filter: 'blur(20px)',
        }}
      />

      {qrPayload ? (
        <QRCodeSVG
          value={qrPayload}
          size={332}
          level="M"
          marginSize={0}
          className="block aspect-square w-full"
        />
      ) : (
        <div className="flex aspect-square w-full items-center justify-center text-center text-sm text-slate-400">
          Sesi belum aktif
          <br />
          atau kode tidak tersedia
        </div>
      )}

      {/* Bottom info row dashed border */}
      <div className="mt-3.5 flex justify-between border-t border-dashed border-slate-300 pt-3.5">
        <div className="flex items-center gap-1.5 font-mono text-xs text-slate-500">
          <Clock className="h-3.5 w-3.5 text-[#2D86FF]" />
          {formatStartTime(startedAt)}
        </div>
        <div className="flex items-center gap-1.5 font-mono text-xs text-slate-500">
          {mode === 'online' ? (
            <Wifi className="h-3.5 w-3.5 text-[#2D86FF]" />
          ) : (
            <MapPin className="h-3.5 w-3.5 text-[#2D86FF]" />
          )}
          {mode === 'online' ? 'Online' : 'Offline'}
        </div>
      </div>
    </div>
  )
}

// ============================================================================
// Sub-component: MkHeader
// ============================================================================

function MkHeader({
  courseName,
  courseCode,
  dosenName,
  sessionNumber,
  topic,
  startedAt,
  mode,
}: {
  courseName: string
  courseCode: string
  dosenName: string | null
  sessionNumber: number
  topic: string | null
  startedAt: string | null
  mode: string
}) {
  return (
    <div className="flex flex-col gap-3">
      <span
        className="inline-flex w-fit items-center gap-2 rounded-full border border-amber-400/40 bg-amber-400/15 px-3.5 py-1.5 text-xs font-semibold uppercase tracking-wider text-amber-200"
        style={{ fontFamily: 'Plus Jakarta Sans, sans-serif' }}
      >
        <GraduationCap className="h-3.5 w-3.5" />
        {courseCode} · Pertemuan {sessionNumber}
      </span>

      <h1
        className="m-0 text-[42px] font-extrabold leading-[1.05] tracking-tight text-white"
        style={{ fontFamily: 'Plus Jakarta Sans, sans-serif' }}
      >
        {courseName}
      </h1>

      {topic && <div className="text-base text-white/70">{topic}</div>}

      <div className="flex flex-wrap gap-6 text-base text-white/75">
        {dosenName && (
          <span className="inline-flex items-center gap-1.5">
            <Users className="h-4 w-4 text-amber-400/80" />
            {dosenName}
          </span>
        )}
        <span className="inline-flex items-center gap-1.5">
          <Clock className="h-4 w-4 text-amber-400/80" />
          Mulai {formatStartTime(startedAt)}
        </span>
        <span className="inline-flex items-center gap-1.5">
          {mode === 'online' ? (
            <Wifi className="h-4 w-4 text-amber-400/80" />
          ) : (
            <MapPin className="h-4 w-4 text-amber-400/80" />
          )}
          {mode === 'online' ? 'Mode Online' : 'Mode Offline'}
        </span>
      </div>
    </div>
  )
}

// ============================================================================
// Sub-component: OtpCountdown — countdown bar tanpa display angka 6-digit
// ============================================================================
// Phase 3 v7: code di payload QR TIDAK dipakai user input. Dosen + audience
// kelas tidak perlu lihat angka 6-digit (cuma bocor + bisa di-screenshot oleh
// audience). Yang ditampilkan: progress bar countdown + label informatif
// "Kode berganti dalam: 00:18" — cukup buat dosen tahu kapan QR refresh.

function OtpCountdown({
  countdownSec,
  fillPct,
  isRolling,
}: {
  countdownSec: number
  fillPct: number
  isRolling: boolean
}) {
  return (
    <div
      className="rounded-3xl border border-white/10 bg-white/5 px-8 py-6 backdrop-blur-md"
    >
      <div
        className="mb-3 text-xs font-bold uppercase tracking-[2px] text-amber-300/85"
        style={{ fontFamily: 'Plus Jakarta Sans, sans-serif' }}
      >
        Status QR
      </div>

      <div className="flex items-center gap-3.5">
        <div
          className="relative h-2.5 flex-1 overflow-hidden rounded-full bg-white/10"
          aria-label="Sisa waktu QR aktif"
        >
          <div
            className="h-full rounded-full transition-[width] duration-1000 ease-linear"
            style={{
              width: `${fillPct}%`,
              background: 'linear-gradient(90deg, #F4B400, #f59e0b)',
              boxShadow: '0 0 12px rgba(244, 180, 0, 0.5)',
            }}
          />
        </div>
        <div
          className="flex items-center gap-1.5 text-2xl font-bold text-white"
          style={{ fontFamily: 'JetBrains Mono, monospace' }}
        >
          <Clock className="h-5 w-5 text-amber-400" />
          {formatCountdown(countdownSec)}
        </div>
      </div>

      <div className="mt-3 text-sm font-medium text-white/65">
        {isRolling
          ? 'QR otomatis berganti — pastikan mahasiswa scan QR yang sedang ditampilkan.'
          : 'QR tetap berlaku selama countdown belum habis. Klik "Putar Ulang QR" untuk membuat yang baru.'}
      </div>
    </div>
  )
}

// ============================================================================
// Sub-component: InstructionList (1-2-3)
// ============================================================================

function InstructionList() {
  const items = [
    'Buka aplikasi MyPresensi di HP-mu',
    'Tap menu Scan QR di bottom navigation',
    'Arahkan kamera ke QR code di layar ini',
  ]
  return (
    <div className="flex flex-col gap-3">
      {items.map((text, i) => (
        <div
          key={i}
          className="flex items-center gap-3.5 text-base text-white/85"
        >
          <span
            className="inline-flex h-[30px] w-[30px] flex-shrink-0 items-center justify-center rounded-full border border-blue-400/50 bg-blue-400/20 text-sm font-bold text-blue-300"
            style={{ fontFamily: 'Plus Jakarta Sans, sans-serif' }}
          >
            {i + 1}
          </span>
          {text}
        </div>
      ))}
    </div>
  )
}

// ============================================================================
// Sub-component: PresProgress (bottom strip)
// ============================================================================

function PresProgress({
  stats,
  hadirPct,
  pollState,
}: {
  stats: LiveStats
  hadirPct: number
  pollState: PollState
}) {
  return (
    <div
      className="mt-6 grid grid-cols-[1fr_2fr_1fr] items-center gap-8 rounded-3xl border border-white/10 bg-white/5 px-7 py-5 backdrop-blur-md"
    >
      {/* Hadir count */}
      <div className="flex items-center gap-3.5">
        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-green-400/15 text-green-400">
          <Users className="h-6 w-6" />
        </div>
        <div className="leading-tight">
          <div
            className="text-3xl font-extrabold tracking-tight text-white"
            style={{ fontFamily: 'Plus Jakarta Sans, sans-serif' }}
          >
            {stats.hadir}
            <span className="text-white/40"> / {stats.total}</span>
          </div>
          <div className="mt-1 text-xs font-medium text-white/60">
            Mahasiswa Hadir
          </div>
        </div>
      </div>

      {/* Progress bar */}
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between text-sm text-white/70">
          <span>Tingkat Kehadiran</span>
          <strong
            className="text-base font-bold text-white"
            style={{ fontFamily: 'Plus Jakarta Sans, sans-serif' }}
          >
            {Math.round(hadirPct)}%
          </strong>
        </div>
        {stats.total > 0 ? (
          <div className="relative h-3.5 overflow-hidden rounded-full bg-white/10">
            <div
              className="relative h-full overflow-hidden rounded-full"
              style={{
                width: `${hadirPct}%`,
                background: 'linear-gradient(90deg, #2D86FF, #4ade80)',
                boxShadow: '0 0 20px rgba(45, 134, 255, 0.4)',
                transition: 'width 0.6s ease',
              }}
            >
              <div className="qr-shimmer absolute inset-0" />
            </div>
          </div>
        ) : (
          <div className="text-sm italic text-white/50">
            Belum ada mahasiswa terdaftar
          </div>
        )}
      </div>

      {/* Poll state indicator */}
      <div className="flex items-center justify-end gap-2">
        {pollState === 'backoff' ? (
          <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-amber-300">
            <WifiOff className="h-3.5 w-3.5" />
            Retry 30 detik
          </span>
        ) : pollState === 'success' || pollState === 'idle' ? (
          <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-green-300">
            <Wifi className="h-3.5 w-3.5" />
            Sync aktif
          </span>
        ) : pollState === 'fetching' ? (
          <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-blue-300">
            <RefreshCw className="h-3.5 w-3.5 animate-spin" />
            Sync...
          </span>
        ) : (
          <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-white/60">
            <Wifi className="h-3.5 w-3.5" />
            Sync...
          </span>
        )}
      </div>

      <style jsx>{`
        @keyframes qrShimmer {
          0% {
            transform: translateX(-100%);
          }
          100% {
            transform: translateX(100%);
          }
        }
        .qr-shimmer {
          background: linear-gradient(
            90deg,
            transparent,
            rgba(255, 255, 255, 0.3),
            transparent
          );
          animation: qrShimmer 2s linear infinite;
        }
      `}</style>
    </div>
  )
}

// ============================================================================
// Sub-component: ExpiredOverlay
// ============================================================================

function ExpiredOverlay({
  isRefreshing,
  onRefresh,
}: {
  isRefreshing: boolean
  onRefresh: () => void
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center backdrop-blur-md"
      style={{ background: 'rgba(5, 13, 28, 0.85)' }}
    >
      <div className="mx-6 max-w-xl rounded-3xl border border-white/15 bg-white/5 px-12 py-10 text-center shadow-2xl">
        <div className="mx-auto mb-5 flex h-20 w-20 items-center justify-center rounded-full bg-amber-400/20">
          <Clock className="h-10 w-10 text-amber-400" />
        </div>
        <h2
          className="mb-2 text-3xl font-extrabold text-white"
          style={{ fontFamily: 'Plus Jakarta Sans, sans-serif' }}
        >
          QR Sudah Kedaluwarsa
        </h2>
        <p className="mb-8 text-base text-white/70">
          QR presensi sudah lewat masa aktifnya. Putar ulang QR untuk
          lanjut menerima presensi mahasiswa.
        </p>
        <button
          onClick={onRefresh}
          disabled={isRefreshing}
          className="inline-flex items-center justify-center gap-2 rounded-full bg-[#2D86FF] px-6 py-3 text-sm font-bold text-white shadow-lg transition-colors hover:bg-[#1E70E0] disabled:cursor-not-allowed disabled:opacity-60"
          style={{ fontFamily: 'Plus Jakarta Sans, sans-serif' }}
        >
          <RefreshCw
            className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`}
          />
          {isRefreshing ? 'Memuat QR baru...' : 'Putar Ulang QR'}
        </button>
      </div>
    </div>
  )
}

// Tipe-tipe internal supaya tidak unused (helper Maximize2 export untuk session-list)
export { Maximize2 }
