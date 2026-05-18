'use client'
// app/components/dashboard/animated-number.tsx
// Tween angka dari 0 (atau previous value) ke target — 600ms ease-out.
// CSS-only tidak bisa karena perlu update text content per frame.
// Respects prefers-reduced-motion: langsung set final value tanpa tween.

import { useEffect, useRef, useState } from 'react'

type Props = {
  /** Target angka final */
  value: number
  /** Durasi animasi (ms). Default 600 — Tier 1 spec. */
  durationMs?: number
  /** Format Intl.NumberFormat locale. Default 'id-ID'. */
  locale?: string
  /** Decimal places. Default 0 (integer). */
  decimals?: number
}

export default function AnimatedNumber({
  value,
  durationMs = 600,
  locale = 'id-ID',
  decimals = 0,
}: Props) {
  const [display, setDisplay] = useState(value)
  const startRef = useRef(value)
  const rafRef = useRef<number | null>(null)

  useEffect(() => {
    // Hormati reduced-motion — set instan tanpa tween.
    if (typeof window !== 'undefined') {
      const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
      if (reduce) {
        setDisplay(value)
        return
      }
    }

    const from = startRef.current
    const to = value
    if (from === to) {
      setDisplay(to)
      return
    }

    const startTime = performance.now()

    const tick = (now: number) => {
      const elapsed = now - startTime
      const t = Math.min(elapsed / durationMs, 1)
      // ease-out cubic: 1 - (1 - t)^3 — kuat di awal, halus di akhir
      const eased = 1 - Math.pow(1 - t, 3)
      const current = from + (to - from) * eased
      setDisplay(current)

      if (t < 1) {
        rafRef.current = requestAnimationFrame(tick)
      } else {
        startRef.current = to
      }
    }

    rafRef.current = requestAnimationFrame(tick)
    return () => {
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current)
    }
  }, [value, durationMs])

  const formatted = new Intl.NumberFormat(locale, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(display)

  return <span aria-live="polite">{formatted}</span>
}
