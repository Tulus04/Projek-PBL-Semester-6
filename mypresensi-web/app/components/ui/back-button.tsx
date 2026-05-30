'use client'
// app/components/ui/back-button.tsx
// Tombol kembali reusable untuk halaman detail/nested route.
// Mengikuti rule 01-agent-persona.md (UX Advocate): navigasi tidak boleh
// dead-end — user selalu bisa kembali ke halaman sebelumnya.
//
// Dua mode:
//   • href diisi  → Link ke route spesifik (preferred, navigasi prediktif)
//   • href kosong → router.back() (fallback ke history browser)

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { ArrowLeft } from 'lucide-react'

interface BackButtonProps {
  /** Route tujuan. Jika kosong, pakai router.back(). */
  href?: string
  /** Label teks di samping ikon. Default "Kembali". */
  label?: string
}

export default function BackButton({ href, label = 'Kembali' }: BackButtonProps) {
  const router = useRouter()

  const className =
    'inline-flex items-center gap-1.5 text-sm font-medium text-text-secondary ' +
    'hover:text-primary transition-colors rounded-lg -ml-1 px-1 py-0.5 ' +
    'focus:outline-none focus:ring-2 focus:ring-primary/25'

  if (href) {
    return (
      <Link href={href} className={className}>
        <ArrowLeft size={16} />
        {label}
      </Link>
    )
  }

  return (
    <button type="button" onClick={() => router.back()} className={className}>
      <ArrowLeft size={16} />
      {label}
    </button>
  )
}
