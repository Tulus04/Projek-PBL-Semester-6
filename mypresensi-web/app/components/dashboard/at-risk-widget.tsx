// app/components/dashboard/at-risk-widget.tsx
// Widget at-risk students untuk dashboard admin (dan nanti dosen).
// Menampilkan ringkasan: total count, critical/warning split, top 3 mhs terburuk.
// Tombol CTA "Lihat Semua" → /dashboard/at-risk untuk drill-down.

import Link from 'next/link'
import { AlertTriangle, ChevronRight, GraduationCap } from 'lucide-react'
import type { AtRiskSummary, AtRiskStudent } from '@/lib/actions/at-risk'

interface AtRiskWidgetProps {
  summary: AtRiskSummary
}

// Avatar fallback dengan inisial nama (JP / SS / DA)
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

// Row mahasiswa di list top
function StudentRow({ student }: { student: AtRiskStudent }) {
  const tierLabel = student.tier === 'critical' ? 'Tindakan Lanjut' : 'Peringatan Dini'
  const tierBadgeClass = student.tier === 'critical'
    ? 'bg-danger/10 text-danger'
    : 'bg-warning/10 text-warning'

  return (
    <div className="flex items-center gap-3 py-2.5 border-b border-border last:border-0">
      {/* Avatar */}
      <div className="flex-shrink-0">
        {student.avatarUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={student.avatarUrl}
            alt={student.fullName}
            className="w-10 h-10 rounded-full object-cover"
          />
        ) : (
          <div className="w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center font-semibold text-sm">
            {getInitials(student.fullName)}
          </div>
        )}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 mb-0.5">
          <p className="text-sm font-semibold text-text-primary truncate">{student.fullName}</p>
          <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded-full uppercase tracking-wide ${tierBadgeClass}`}>
            {tierLabel}
          </span>
        </div>
        <p className="text-xs text-text-secondary mb-1">
          {student.nimNip}
          {student.kelas && ` · Kelas ${student.kelas}`}
          {' · '}
          Hadir {student.attendedSessions} dari {student.expectedSessions} sesi
        </p>
        <AttendanceBar pct={student.attendancePct} tier={student.tier} />
      </div>

      {/* Persentase */}
      <div className="flex-shrink-0 text-right">
        <p className={`text-lg font-bold font-heading ${student.tier === 'critical' ? 'text-danger' : 'text-warning'}`}>
          {student.attendancePct}%
        </p>
        <p className="text-[10px] text-text-secondary uppercase tracking-wide">kehadiran</p>
      </div>
    </div>
  )
}

export default function AtRiskWidget({ summary }: AtRiskWidgetProps) {
  const { totalCount, criticalCount, warningCount, topStudents, settings } = summary

  // Empty state — tidak ada mhs at-risk
  if (totalCount === 0) {
    return (
      <div className="card p-5 h-full flex flex-col justify-center">
        <div className="flex items-center gap-3 mb-3">
          <div className="kpi-icon-box success">
            <GraduationCap size={18} />
          </div>
          <div>
            <h3 className="text-base font-bold font-heading text-text-primary">Status Kehadiran Mahasiswa</h3>
            <p className="text-xs text-text-secondary">
              Window {settings.windowDays} hari · threshold {settings.thresholdPct}%
            </p>
          </div>
        </div>
        <div className="text-center py-4">
          <p className="text-sm text-text-secondary">
            Tidak ada evaluasi kehadiran saat ini. Seluruh mahasiswa memenuhi threshold kehadiran. 🎉
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="card p-5 h-full flex flex-col">
      {/* Header */}
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="flex items-center gap-3">
          <div className="kpi-icon-box danger">
            <AlertTriangle size={18} />
          </div>
          <div>
            <h3 className="text-base font-bold font-heading text-text-primary">
              Evaluasi Kehadiran
            </h3>
            <p className="text-xs text-text-secondary">
              Tingkat kehadiran di bawah {settings.thresholdPct}% dalam {settings.windowDays} hari terakhir
            </p>
          </div>
        </div>

        {/* Summary count */}
        <div className="text-right flex-shrink-0">
          <p className="text-2xl font-bold font-heading text-danger leading-tight">{totalCount}</p>
          <p className="text-[10px] text-text-secondary uppercase tracking-wide">mahasiswa</p>
        </div>
      </div>

      {/* Tier breakdown */}
      <div className="grid grid-cols-2 gap-3 mb-4">
        <div className="rounded-xl bg-danger/5 border border-danger/15 p-3">
          <p className="text-[10px] uppercase tracking-widest font-bold text-danger mb-1">Tindakan Lanjut</p>
          <p className="text-xl font-bold font-heading text-danger leading-tight">{criticalCount}</p>
          <p className="text-[10px] text-text-secondary">Tingkat kehadiran &lt; {settings.criticalPct}%</p>
        </div>
        <div className="rounded-xl bg-warning/5 border border-warning/15 p-3">
          <p className="text-[10px] uppercase tracking-widest font-bold text-warning mb-1">Peringatan Dini</p>
          <p className="text-xl font-bold font-heading text-warning leading-tight">{warningCount}</p>
          <p className="text-[10px] text-text-secondary">Tingkat kehadiran {settings.criticalPct}% – {settings.thresholdPct - 0.1}%</p>
        </div>
      </div>

      {/* Top 3 list */}
      {topStudents.length > 0 && (
        <>
          <p className="text-[10px] uppercase tracking-widest font-bold text-text-secondary mb-2">
            3 Prioritas Utama
          </p>
          <div className="mb-3">
            {topStudents.map(s => (
              <StudentRow key={s.studentId} student={s} />
            ))}
          </div>
        </>
      )}

      {/* CTA Lihat Semua */}
      <Link
        href="/at-risk"
        className="mt-auto flex items-center justify-between rounded-xl bg-primary/5 hover:bg-primary/10 transition-colors px-4 py-2.5 text-sm font-semibold text-primary group"
      >
        <span>Lihat semua riwayat evaluasi ({totalCount} mahasiswa)</span>
        <ChevronRight size={16} className="group-hover:translate-x-0.5 transition-transform" />
      </Link>
    </div>
  )
}
