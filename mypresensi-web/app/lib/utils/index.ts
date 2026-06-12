// src/lib/utils/index.ts
// Pure helper functions. Tidak ada side effects, tidak ada external calls.

import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { AttendanceStatus } from '@/types/database'

// Gabungkan class Tailwind dengan aman (menghindari konflik)
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Konstanta warna hex untuk library yang butuh hex string (mis. Recharts).
// Untuk JSX/CSS, SELALU pakai utility class Tailwind (text-primary, text-success, dll).
// Single source of truth — kalau rebrand, edit di sini saja.
// Palette: Politani Web (extracted dari politanisamarinda.ac.id).
export const BRAND_COLORS = {
  primary: '#2D86FF',         // Politani Web Blue (CTA & link)
  primaryHover: '#1E70E0',    // Hover state
  primaryDark: '#0D2C5E',     // Navy deep — hero gradient end
  accent: '#F4B400',          // Gold pita logo Politani
  success: '#1A7F37',
  warning: '#9A6700',
  danger: '#CF222E',
  textPrimary: '#1C2024',
  textSecondary: '#636C76',
  border: '#E2E6EA',
} as const

// Mapping status presensi ke warna (untuk chart/donut/bar)
// Terlambat pakai amber distinct dari izin/sakit (warning yellow gelap)
// agar di donut chart 4 slice bisa dibedakan secara visual.
export const STATUS_COLORS: Record<'hadir' | 'terlambat' | 'izin' | 'alpa', string> = {
  hadir: BRAND_COLORS.success,
  terlambat: '#D97706', // amber-600 — sub-variant hadir tapi distinct dari izin
  izin: BRAND_COLORS.warning,
  alpa: BRAND_COLORS.danger,
}

// Format tanggal ke format Indonesia: "Senin, 06 April 2026"
export function formatDateId(dateString: string): string {
  return new Date(dateString).toLocaleDateString('id-ID', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
}

// Format tanggal pendek: "06 Apr 2026"
export function formatDateShort(dateString: string): string {
  return new Date(dateString).toLocaleDateString('id-ID', {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
  })
}

// Format waktu: "14:30"
export function formatTime(dateString: string): string {
  return new Date(dateString).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

// Hitung persentase kehadiran
export function calculateAttendanceRate(hadir: number, total: number): number {
  if (total === 0) return 0
  return Math.round((hadir / total) * 100)
}

// Tentukan apakah persentase kehadiran tergolong bahaya (< 80%)
export function isAttendanceDanger(rate: number): boolean {
  return rate < 80
}

// Dapatkan label status presensi dalam bahasa Indonesia
export function getStatusLabel(status: AttendanceStatus): string {
  const labels: Record<AttendanceStatus, string> = {
    hadir: 'Hadir',
    terlambat: 'Terlambat',
    izin: 'Izin',
    sakit: 'Sakit',
    alpa: 'Alpa',
  }
  return labels[status]
}

// Dapatkan warna Tailwind untuk badge status
// 'terlambat' = warning tone (sama dengan izin/sakit) — distinguish via label + icon Clock
export function getStatusColor(status: AttendanceStatus): string {
  const colors: Record<AttendanceStatus, string> = {
    hadir: 'bg-success-subtle text-success border-success/20',
    terlambat: 'bg-warning-subtle text-warning border-warning/20',
    izin: 'bg-warning-subtle text-warning border-warning/20',
    sakit: 'bg-warning-subtle text-warning border-warning/20',
    alpa: 'bg-danger-subtle text-danger border-danger/20',
  }
  return colors[status]
}

// Truncate teks panjang dengan ellipsis
export function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text
  return `${text.slice(0, maxLength)}...`
}

// Validasi NIM format (contoh: H2336001)
export function isValidNim(nim: string): boolean {
  return /^[A-Z]\d{7}$/.test(nim)
}

// Generate default password dari NIM
export function generateDefaultPassword(nim: string): string {
  return `${nim}@Politani`
}
