'use client'

import { useEffect } from 'react'

interface PhantomLoaderProps {
  loading: boolean
  children: React.ReactNode
  animation?: "shimmer" | "pulse" | "breathe" | "solid"
  count?: number
  countGap?: number
  stagger?: number
  reveal?: number
}

export default function PhantomLoader({
  loading,
  children,
  animation = "shimmer",
  count = 1,
  countGap = 0,
  stagger = 0,
  reveal = 0.3
}: PhantomLoaderProps) {
  useEffect(() => {
    // Dynamic import to avoid SSR errors since Web Components require document/customElements APIs
    import("@aejkatappaja/phantom-ui")
  }, [])

  return (
    <phantom-ui
      loading={loading ? true : undefined}
      animation={animation}
      count={count}
      count-gap={countGap}
      stagger={stagger}
      reveal={reveal}
    >
      {children}
    </phantom-ui>
  )
}
