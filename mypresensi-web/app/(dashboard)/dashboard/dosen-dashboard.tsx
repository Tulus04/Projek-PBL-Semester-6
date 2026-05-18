'use client'
// app/(dashboard)/dashboard/dosen-dashboard.tsx
// Komponen dashboard untuk role Dosen.
// Menampilkan statistik MK yang diampu, grafik Recharts (trend & donut),
// daftar card MK, dan log presensi terkini.

import { BookOpen, CalendarDays, CheckCircle, Clock, ArrowRight, Users, LayoutDashboard } from 'lucide-react'
import { formatDateId } from '@/lib/utils'
import EmptyState from '@/components/ui/empty-state'
import LiveSessionMonitor from '@/components/dashboard/live-session-monitor'
import AnimatedNumber from '@/components/dashboard/animated-number'
import type {
  DashboardSummary,
  CourseCardData,
  WeeklyTrendItem,
  AttendanceRatio,
  RecentAttendance,
} from '@/lib/actions/dashboard'
import type { ActiveSessionInfo } from '@/lib/actions/live-session'
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend,
} from 'recharts'
import Link from 'next/link'
import { BRAND_COLORS, STATUS_COLORS } from '@/lib/utils'

interface DosenDashboardProps {
  dosenName: string
  summary: DashboardSummary
  courses: CourseCardData[]
  weeklyTrend: WeeklyTrendItem[]
  attendanceRatio: AttendanceRatio[]
  recentAttendances: RecentAttendance[]
  activeSession: ActiveSessionInfo | null
}

const statusConfig = {
  hadir: { label: 'Hadir', className: 'badge badge-success' },
  terlambat: { label: 'Terlambat', className: 'badge badge-warning' },
  izin: { label: 'Izin', className: 'badge badge-warning' },
  sakit: { label: 'Sakit', className: 'badge badge-warning' },
  alpa: { label: 'Alpa', className: 'badge badge-danger' },
} as const

// Custom tooltip untuk AreaChart
function TrendTooltip({ active, payload, label }: { active?: boolean; payload?: Array<{ value: number; name: string; color: string }>; label?: string }) {
  if (!active || !payload) return null
  return (
    <div className="card" style={{ padding: '12px 16px', fontSize: '13px', minWidth: '140px' }}>
      <p className="font-semibold text-text-primary mb-1">{label}</p>
      {payload.map((entry) => (
        <div key={entry.name} className="flex items-center justify-between gap-4">
          <span className="flex items-center gap-1.5">
            <span style={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: entry.color, display: 'inline-block' }} />
            <span className="text-text-secondary">{entry.name}</span>
          </span>
          <span className="font-medium text-text-primary">{entry.value}</span>
        </div>
      ))}
    </div>
  )
}

export default function DosenDashboard({
  dosenName,
  summary,
  courses,
  weeklyTrend,
  attendanceRatio,
  recentAttendances,
  activeSession,
}: DosenDashboardProps) {
  const todayLabel = formatDateId(new Date().toISOString())
  const totalRatio = attendanceRatio.reduce((sum, item) => sum + item.value, 0)

  return (
    <div className="flex flex-col gap-6">
      {/* 1. Header Greeting */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <LayoutDashboard size={20} className="text-primary" />
        </div>
        <div>
          <h2 className="page-title">Selamat Datang, {dosenName}</h2>
          <p className="page-subtitle">{todayLabel}</p>
        </div>
      </div>

      {/* 1b. Live Session Monitor — hanya tampil saat ada sesi aktif */}
      {activeSession && <LiveSessionMonitor data={activeSession} />}

      {/* 2. KPI Cards — 4 cards dengan icon box duotone + lift hover + stagger entrance */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '0ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Mata Kuliah Aktif</span>
            <span className="kpi-icon-box">
              <BookOpen size={18} />
            </span>
          </div>
          <span className="summary-card-value">
            <AnimatedNumber value={summary.totalMataKuliah} />
          </span>
          <span className="summary-card-sublabel">Diampu semester ini</span>
        </div>

        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '60ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Total Pertemuan</span>
            <span className="kpi-icon-box">
              <CalendarDays size={18} />
            </span>
          </div>
          <span className="summary-card-value">
            <AnimatedNumber value={summary.totalSesi} />
          </span>
          <span className="summary-card-sublabel">Sesi terlaksana</span>
        </div>

        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '120ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Total Kehadiran</span>
            <span className="kpi-icon-box success">
              <CheckCircle size={18} />
            </span>
          </div>
          <span className="summary-card-value text-success">
            <AnimatedNumber value={summary.totalHadir} />
          </span>
          <span className="summary-card-sublabel">Mahasiswa hadir</span>
        </div>

        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '180ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Menunggu Persetujuan</span>
            <span className="kpi-icon-box warning">
              <Clock size={18} />
            </span>
          </div>
          <span className="summary-card-value text-warning">
            <AnimatedNumber value={summary.pendingLeaveRequests} />
          </span>
          <span className="summary-card-sublabel">Pengajuan izin/sakit</span>
        </div>
      </div>

      {/* 3. Grafik Statistik */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Area Chart — Trend 7 Hari */}
        <div className="card p-6 lg:col-span-2">
          <div className="mb-4">
            <h3 className="text-base font-bold font-heading text-text-primary">
              Tren Kehadiran 7 Hari Terakhir
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Pergerakan presensi di seluruh kelas Anda
            </p>
          </div>
          {weeklyTrend.every(d => d.hadir === 0 && d.izin === 0 && d.alpa === 0) ? (
            <div className="flex items-center justify-center h-[240px]">
              <p className="text-text-secondary text-sm">Belum ada data presensi minggu ini.</p>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <AreaChart data={weeklyTrend} margin={{ top: 5, right: 5, bottom: 0, left: -20 }}>
                <defs>
                  <linearGradient id="gradHadir" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={STATUS_COLORS.hadir} stopOpacity={0.15} />
                    <stop offset="95%" stopColor={STATUS_COLORS.hadir} stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="gradIzin" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={STATUS_COLORS.izin} stopOpacity={0.15} />
                    <stop offset="95%" stopColor={STATUS_COLORS.izin} stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="gradAlpa" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={STATUS_COLORS.alpa} stopOpacity={0.15} />
                    <stop offset="95%" stopColor={STATUS_COLORS.alpa} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(226,230,234,0.6)" />
                <XAxis
                  dataKey="day"
                  tick={{ fontSize: 12, fill: BRAND_COLORS.textSecondary }}
                  axisLine={{ stroke: BRAND_COLORS.border }}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fontSize: 12, fill: BRAND_COLORS.textSecondary }}
                  axisLine={false}
                  tickLine={false}
                  allowDecimals={false}
                />
                <Tooltip content={<TrendTooltip />} />
                <Area type="monotone" dataKey="hadir" name="Hadir" stroke={STATUS_COLORS.hadir} strokeWidth={2} fill="url(#gradHadir)" />
                <Area type="monotone" dataKey="izin" name="Izin/Sakit" stroke={STATUS_COLORS.izin} strokeWidth={2} fill="url(#gradIzin)" />
                <Area type="monotone" dataKey="alpa" name="Alpa" stroke={STATUS_COLORS.alpa} strokeWidth={2} fill="url(#gradAlpa)" />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Donut Chart — Rasio Kehadiran */}
        <div className="card p-6">
          <div className="mb-4">
            <h3 className="text-base font-bold font-heading text-text-primary">
              Rasio Kehadiran
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Distribusi status presensi keseluruhan
            </p>
          </div>
          {totalRatio === 0 ? (
            <div className="flex items-center justify-center h-[240px]">
              <p className="text-text-secondary text-sm">Belum ada data presensi.</p>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <PieChart>
                <Pie
                  data={attendanceRatio}
                  cx="50%"
                  cy="50%"
                  innerRadius={55}
                  outerRadius={85}
                  paddingAngle={3}
                  dataKey="value"
                  strokeWidth={0}
                >
                  {attendanceRatio.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip
                  formatter={(value, name) => [
                    `${value} (${totalRatio > 0 ? Math.round((Number(value) / totalRatio) * 100) : 0}%)`,
                    name,
                  ]}
                />
                <Legend
                  verticalAlign="bottom"
                  iconType="circle"
                  iconSize={8}
                  formatter={(value: string) => (
                    <span style={{ fontSize: '12px', color: BRAND_COLORS.textSecondary }}>{value}</span>
                  )}
                />
              </PieChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {/* 4. Daftar MK yang Diampu */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-base font-bold font-heading text-text-primary">
            Mata Kuliah yang Diampu
          </h3>
          <Link
            href="/matakuliah"
            className="text-sm font-medium flex items-center gap-1 hover:underline text-primary"
          >
            Lihat Semua <ArrowRight size={14} />
          </Link>
        </div>

        {courses.length === 0 ? (
          <div className="card">
            <EmptyState
              icon={BookOpen}
              title="Belum ada mata kuliah yang diampu"
              description="Daftarkan mata kuliah yang Anda ampu di halaman Mata Kuliah agar bisa membuat sesi presensi."
              action={
                <Link href="/matakuliah" className="btn-primary inline-flex">
                  <BookOpen size={14} /> Buka Mata Kuliah
                </Link>
              }
            />
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {courses.map((course) => {
              const percentage = course.totalPresensi > 0
                ? Math.round((course.totalHadir / course.totalPresensi) * 100)
                : 0

              return (
                <div key={course.id} className="card p-5 transition-all duration-200 hover:shadow-lg">
                  <div className="flex items-start justify-between mb-3">
                    <div>
                      <p className="text-xs font-medium text-text-secondary uppercase tracking-wide">
                        {course.code}
                      </p>
                      <h4 className="text-sm font-bold text-text-primary mt-0.5">
                        {course.name}
                      </h4>
                    </div>
                    <span className="badge" style={{ fontSize: '11px' }}>
                      Semester {course.semester}
                    </span>
                  </div>

                  <div className="flex items-center gap-4 text-xs text-text-secondary mb-3">
                    <span className="flex items-center gap-1">
                      <Users size={13} /> {course.totalPeserta} peserta
                    </span>
                    <span className="flex items-center gap-1">
                      <CalendarDays size={13} /> {course.totalSesi} sesi
                    </span>
                    {course.sesiAktif > 0 && (
                      <span className="badge badge-success" style={{ fontSize: '10px', padding: '1px 6px' }}>
                        {course.sesiAktif} aktif
                      </span>
                    )}
                  </div>

                  {/* Progress bar kehadiran */}
                  <div>
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs text-text-secondary">Tingkat kehadiran</span>
                      <span className="text-xs font-semibold text-text-primary">{percentage}%</span>
                    </div>
                    <div className="w-full h-2 rounded-full bg-border">
                      <div
                        className={`h-2 rounded-full transition-all duration-500 ${
                          percentage >= 75 ? 'bg-success' : percentage >= 50 ? 'bg-warning' : 'bg-danger'
                        }`}
                        style={{ width: `${percentage}%` }}
                      />
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* 5. Presensi Terkini */}
      <div className="card overflow-hidden">
        <div className="px-6 py-4 border-b border-border">
          <h3 className="text-base font-bold font-heading text-text-primary">
            Presensi Terkini di Kelas Anda
          </h3>
          <p className="text-xs text-text-secondary mt-0.5">
            Riwayat absensi mahasiswa terbaru
          </p>
        </div>

        <div className="overflow-x-auto">
          {recentAttendances.length === 0 ? (
            <EmptyState
              icon={Clock}
              title="Belum ada presensi tercatat"
              description="Riwayat presensi akan muncul setelah mahasiswa melakukan absensi pada sesi aktif Anda."
            />
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>Mahasiswa</th>
                  <th>Mata Kuliah</th>
                  <th>Topik</th>
                  <th>Waktu</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {recentAttendances.map((att) => {
                  const config = statusConfig[att.status as keyof typeof statusConfig]
                  return (
                    <tr key={att.id}>
                      <td>
                        <div>
                          <p className="font-medium text-text-primary text-sm">
                            {att.studentName}
                          </p>
                          <p className="text-xs text-text-secondary">
                            {att.studentNim}
                          </p>
                        </div>
                      </td>
                      <td className="text-text-primary text-sm">{att.courseName}</td>
                      <td className="text-text-secondary text-sm">{att.topic}</td>
                      <td className="text-text-secondary text-sm tabular-nums">
                        {new Date(att.scanned_at).toLocaleTimeString('id-ID', {
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </td>
                      <td>
                        <span className={config.className}>{config.label}</span>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  )
}
