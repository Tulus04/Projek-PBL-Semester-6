'use client'
// app/components/layout/sidebar-provider.tsx
// Context provider untuk koordinasi state buka/tutup sidebar mobile.
// Auto-close saat path berubah agar UX smooth setelah navigasi.

import { createContext, useContext, useState, useEffect, type ReactNode } from 'react'
import { usePathname } from 'next/navigation'

type SidebarContextValue = {
  isOpen: boolean
  toggle: () => void
  open: () => void
  close: () => void
}

const SidebarContext = createContext<SidebarContextValue | null>(null)

export function SidebarProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false)
  const pathname = usePathname()

  // Tutup sidebar saat user pindah halaman
  useEffect(() => {
    setIsOpen(false)
  }, [pathname])

  // Tutup juga saat resize ke desktop (≥ md), agar state tidak nyangkut
  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth >= 768) setIsOpen(false)
    }
    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  // Cegah scroll body saat drawer terbuka
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [isOpen])

  return (
    <SidebarContext.Provider
      value={{
        isOpen,
        toggle: () => setIsOpen((o) => !o),
        open: () => setIsOpen(true),
        close: () => setIsOpen(false),
      }}
    >
      {children}
    </SidebarContext.Provider>
  )
}

export function useSidebar() {
  const ctx = useContext(SidebarContext)
  if (!ctx) {
    throw new Error('useSidebar must be used within SidebarProvider')
  }
  return ctx
}
