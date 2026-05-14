// app/(dashboard)/at-risk/page.tsx
// Halaman Mahasiswa Berisiko — full list mhs dengan kehadiran rendah.
// Server Component, akses admin only (server action getAtRiskStudents punya requireRole).
// Drill-down dari widget at-risk di /dashboard.

import type { Metadata } from 'next'
import { AlertTriangle } from 'lucide-react'
import { getAtRiskStudents, type AtRiskStudent } from '@/lib/actions/at-risk'
import EmptyState from '@/components/ui/empty-state'
import { formatDateId } from '@/lib/utils'

export const metadata: Metadata = {
  title: 'Mahasiswa Berisiko',
}

// Avatar fallback dengan inisial 2 huruf
function getInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map(part => part[0]?.toUpperCase() ?? '')
    .join('')
}

// Bar progress visual untuk persentase kehadiran
function AttendanceBar({ pct, tier }: { pct: number; tier: 'critical' | 'warning' }) {
  const barColor = tier === 'critical' ? 'bg-danger' : 'bg-warning'
  return (
    <div className="w-full h-1.5 bg-gray-100 rounded-full overflow-hidden">
      <div
        className={`h-full ${barColor} transition-all duration-500`}
        style={{ width: `${Math.max(pct, 4)}%` }}
      />
    </div>
  )
}

// Format "berapa hari lalu" dari last_attended_at
function formatLastAttended(iso: string | null): string {
  if (!iso) return 'Belum pernah'
  const date = new Date(iso)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))
  if (diffDays === 0) return 'Hari ini'
  if (diffDays === 1) return 'Kemarin'
  if (diffDays < 7) return `${diffDays} hari lalu`
  if (diffDays < 30) return `${Math.floor(diffDays / 7)} minggu lalu`
  return formatDateId(iso)
}

function StudentRow({ student }: { student: AtRiskStudent }) {
  const tierLabel = student.tier === 'critical' ? 'Kritis' : 'Perhatian'
  const tierBadgeClass = student.tier === 'critical'
    ? 'bg-danger/10 text-danger border-danger/20'
    : 'bg-warning/10 text-warning border-warning/20'

  return (
    <tr className="border-b border-border last:border-0 hover:bg-background-tertiary transition-colors">
      {/* Mahasiswa */}
      <td className="py-3 px-4">
        <div className="flex items-center gap-3">
          {student.avatarUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={student.avatarUrl}
              alt={student.fullName}
              className="w-10 h-10 rounded-full object-cover flex-shrink-0"
            />
          ) : (
            <div className="w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center font-semibold text-sm flex-shrink-0">
              {getInitials(student.fullName)}
            </div>
          )}
          <div className="min-w-0">
            <p className="text-sm font-semibold text-text-primary truncate">{student.fullName}</p>
            <p className="text-xs text-text-secondary">{student.nimNip}</p>
          </div>
        </div>
      </td>

      {/* Kelas / Semester */}
      <td className="py-3 px-4 text-sm text-text-secondary">
        {student.kelas ?? '—'}
        {student.semester && (
          <span className="text-text-secondary/70"> · Smt {student.semester}</span>
        )}
      </td>

      {/* Tier badge */}
      <td className="py-3 px-4">
        <span className={`inline-block text-[10px] font-bold px-2 py-1 rounded-full uppercase tracking-wide border ${tierBadgeClass}`}>
          {tierLabel}
        </span>
      </td>

      {/* Kehadiran (persen + bar) */}
      <td className="py-3 px-4 min-w-[180px]">
        <div className="flex items-center gap-3">
          <span className={`text-base font-bold font-heading ${student.tier === 'critical' ? 'text-danger' : 'text-warning'}`}>
            {student.attendancePct}%
          </span>
          <div className="flex-1">
            <AttendanceBar pct={student.attendancePct} tier={student.tier} />
          </div>
        </div>
      </td>

      {/* Sesi (attended/expected) */}
      <td className="py-3 px-4 text-sm text-text-secondary text-center">
        <span className="font-semibold text-text-primary">{student.attendedSessions}</span>
        <span className="text-text-secondary/70"> / {student.expectedSessions}</span>
      </td>

      {/* Last attended */}
      <td className="py-3 px-4 text-sm text-text-secondary">
        {formatLastAttended(student.lastAttendedAt)}
      </td>
    </tr>
  )
}

export default async function AtRiskPage() {
  const { students, settings } = await getAtRiskStudents()

  const criticalCount = students.filter(s => s.tier === 'critical').length
  const warningCount = students.filter(s => s.tier === 'warning').length
  const totalCount = students.length

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-danger/10 flex items-center justify-center">
            <AlertTriangle size={20} className="text-danger" />
          </div>
          <div>
            <h2 className="page-title">Mahasiswa Berisiko</h2>
            <p className="page-subtitle">
              {totalCount} mahasiswa dengan kehadiran &lt; {settings.thresholdPct}% dalam {settings.windowDays} hari terakhir
            </p>
          </div>
        </div>
      </div>

      {/* Summary cards mini — 3 KPI */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="card p-4">
          <p className="text-[10px] uppercase tracking-widest font-bold text-text-secondary mb-1">Total Berisiko</p>
          <p className="text-3xl font-bold font-heading text-text-primary leading-tight">{totalCount}</p>
          <p className="text-xs text-text-secondary mt-1">Minimum {settings.minSessions} sesi expected</p>
        </div>
        <div className="card p-4 border-danger/20">
          <p className="text-[10px] uppercase tracking-widest font-bold text-danger mb-1">Tier Kritis</p>
          <p className="text-3xl font-bold font-heading text-danger leading-tight">{criticalCount}</p>
          <p className="text-xs text-text-secondary mt-1">&lt; {settings.criticalPct}% kehadiran</p>
        </div>
        <div className="card p-4 border-warning/20">
          <p className="text-[10px] uppercase tracking-widest font-bold text-warning mb-1">Tier Perhatian</p>
          <p className="text-3xl font-bold font-heading text-warning leading-tight">{warningCount}</p>
          <p className="text-xs text-text-secondary mt-1">{settings.criticalPct}% – {settings.thresholdPct - 0.1}%</p>
        </div>
      </div>

      {/* Tabel atau empty state */}
      <div className="card overflow-hidden">
        {students.length === 0 ? (
          <EmptyState
            icon={AlertTriangle}
            title="Tidak ada mahasiswa berisiko"
            description={`Seluruh mahasiswa memenuhi threshold kehadiran ≥ ${settings.thresholdPct}% dalam ${settings.windowDays} hari terakhir. Status presensi sehat — pertahankan!`}
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="data-table w-full">
              <thead>
                <tr>
                  <th>Mahasiswa</th>
                  <th>Kelas</th>
                  <th>Tier</th>
                  <th>Kehadiran</th>
                  <th className="text-center">Sesi</th>
                  <th>Terakhir Hadir</th>
                </tr>
              </thead>
              <tbody>
                {students.map(s => (
                  <StudentRow key={s.studentId} student={s} />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Penjelasan metodologi */}
      <div className="card p-4 bg-background-tertiary border-dashed">
        <p className="text-xs text-text-secondary leading-relaxed">
          <strong className="text-text-primary">Cara perhitungan:</strong>{' '}
          Persentase kehadiran = jumlah sesi hadir/terlambat dibagi dengan total sesi yang seharusnya diikuti
          (berdasarkan enrollment mahasiswa di mata kuliah yang sudah selesai dalam {settings.windowDays} hari terakhir).
          Mahasiswa dengan minimum {settings.minSessions} sesi expected dan persentase &lt; {settings.thresholdPct}% akan ditandai.
          Tier <strong className="text-danger">Kritis</strong> untuk yang &lt; {settings.criticalPct}%, sisanya tier{' '}
          <strong className="text-warning">Perhatian</strong>. Threshold dapat diubah lewat menu Pengaturan.
        </p>
      </div>
    </div>
  )
}
