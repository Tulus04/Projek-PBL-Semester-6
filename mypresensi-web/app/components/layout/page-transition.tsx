'use client'
// app/components/layout/page-transition.tsx
// Wrapper untuk animate-in setiap halaman dashboard saat path berubah.
// key={pathname} membuat React remount → animasi replay (~220ms fade+up).

import { usePathname } from 'next/navigation'
import { type ReactNode } from 'react'

export default function PageTransition({ children }: { children: ReactNode }) {
  const pathname = usePathname()
  return (
    <div key={pathname} className="animate-page-in">
      {children}
    </div>
  )
}
