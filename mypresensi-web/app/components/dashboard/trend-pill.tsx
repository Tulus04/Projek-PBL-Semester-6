// app/components/dashboard/trend-pill.tsx
// Pill kecil untuk indikator perubahan KPI vs periode sebelumnya.
// Mendukung "inverse semantic" — naik untuk Alpa = merah (negatif), bukan hijau.
// Format display: ▲ +12% / ▼ -3% / = 0% / ✦ Baru
//
// Color logic:
//   non-inverse + up = success (hijau)    inverse + up = danger (merah)
//   non-inverse + down = danger (merah)   inverse + down = success (hijau)
//   delta = 0 = neutral gray
//   no baseline (previous=0, current>0) = primary "Baru"

import { TrendingUp, TrendingDown, Minus, Sparkles } from 'lucide-react'
import type { TrendData } from '@/lib/actions/dashboard'

interface TrendPillProps {
  trend: TrendData
  /** True kalau naik = buruk (Alpa, Izin/Sakit, Pending). Default false (naik = baik). */
  inverse?: boolean
  /** Sembunyikan label periode untuk versi compact. Default false. */
  hidePeriod?: boolean
}

export default function TrendPill({ trend, inverse = false, hidePeriod = false }: TrendPillProps) {
  const { deltaPct, periodLabel, previous, current } = trend

  // Case 1: tidak ada baseline — previous=0 dan current>0 → "Baru"
  if (deltaPct === null && previous === 0 && current > 0) {
    return (
      <span className="trend-pill" style={{
        background: 'rgba(var(--color-primary), 0.12)',
        color: 'rgb(var(--color-primary))',
      }}>
        <Sparkles size={11} />
        <span>Baru</span>
        {!hidePeriod && <span className="opacity-75 font-normal">{periodLabel}</span>}
      </span>
    )
  }

  // Case 2: previous=0 dan current=0 → tidak tampil pill (skip)
  if (deltaPct === null) return null

  // Case 3: zero change
  if (deltaPct === 0) {
    return (
      <span className="trend-pill neutral">
        <Minus size={11} />
        <span>0%</span>
        {!hidePeriod && <span className="opacity-75 font-normal">{periodLabel}</span>}
      </span>
    )
  }

  // Case 4: actual change
  const isUp = deltaPct > 0
  // Color rules: inverse XOR isUp → success
  const isPositive = inverse ? !isUp : isUp
  const colorClass = isPositive ? 'up' : 'down'
  const Icon = isUp ? TrendingUp : TrendingDown
  const sign = isUp ? '+' : ''

  return (
    <span
      className={`trend-pill ${colorClass}`}
      title={`Sekarang: ${current} · Sebelum: ${previous}`}
    >
      <Icon size={11} />
      <span>{sign}{deltaPct}%</span>
      {!hidePeriod && <span className="opacity-75 font-normal">{periodLabel}</span>}
    </span>
  )
}
