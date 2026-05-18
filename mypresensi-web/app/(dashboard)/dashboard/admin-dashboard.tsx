'use client'
// app/(dashboard)/dashboard/admin-dashboard.tsx
// Komponen dashboard untuk role Admin.
// Menampilkan statistik global + grafik Recharts (trend + donut + bar chart MK).

import {
  Users, GraduationCap, CheckCircle, XCircle,
  Clock, FileText, LayoutDashboard
} from 'lucide-react'
import { formatDateId } from '@/lib/utils'
import EmptyState from '@/components/ui/empty-state'
import AtRiskWidget from '@/components/dashboard/at-risk-widget'
import TrendPill from '@/components/dashboard/trend-pill'
import RecentActivityFeed from '@/components/dashboard/recent-activity-feed'
import QuickActions from '@/components/dashboard/quick-actions'
import AnimatedNumber from '@/components/dashboard/animated-number'
import type { AdminDashboardData } from '@/lib/actions/dashboard'
import type { AtRiskSummary } from '@/lib/actions/at-risk'
import type { ActivityItem } from '@/lib/actions/recent-activity'
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, PieChart, Pie, Cell, Legend,
  BarChart, Bar,
} from 'recharts'
import { BRAND_COLORS, STATUS_COLORS } from '@/lib/utils'

interface AdminDashboardProps {
  data: AdminDashboardData
  atRiskSummary: AtRiskSummary
  recentActivities: ActivityItem[]
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

// Custom tooltip untuk BarChart
function BarTooltip({ active, payload, label }: { active?: boolean; payload?: Array<{ value: number; name: string; color: string; fill: string }>; label?: string }) {
  if (!active || !payload) return null
  return (
    <div className="card" style={{ padding: '12px 16px', fontSize: '13px', minWidth: '140px' }}>
      <p className="font-semibold text-text-primary mb-1">{label}</p>
      {payload.map((entry) => (
        <div key={entry.name} className="flex items-center justify-between gap-4">
          <span className="flex items-center gap-1.5">
            <span style={{ width: 8, height: 8, borderRadius: '4px', backgroundColor: entry.fill || entry.color, display: 'inline-block' }} />
            <span className="text-text-secondary">{entry.name}</span>
          </span>
          <span className="font-medium text-text-primary">{entry.value}</span>
        </div>
      ))}
    </div>
  )
}

export default function AdminDashboard({ data, atRiskSummary, recentActivities }: AdminDashboardProps) {
  const todayLabel = formatDateId(new Date().toISOString())
  const totalRatio = data.attendanceRatio.reduce((sum, item) => sum + item.value, 0)

  return (
    <div className="flex flex-col gap-6">
      {/* 1. Hero Card — welcome banner gradient primary→dark + amber glow + live indicator */}
      <div className="hero-card">
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-white/15 backdrop-blur flex items-center justify-center flex-shrink-0">
              <LayoutDashboard size={24} className="text-white" />
            </div>
            <div>
              <p className="text-xs uppercase tracking-widest font-semibold text-white/70">Dashboard Admin</p>
              <h2 className="text-2xl font-bold font-heading text-white">Selamat Datang, Administrator</h2>
              <p className="text-sm text-white/80 mt-0.5">{todayLabel}</p>
            </div>
          </div>

          {/* Live indicator pulse */}
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/10 backdrop-blur border border-white/20">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-amber-300"></span>
            </span>
            <span className="text-xs font-semibold text-white">Real-time</span>
          </div>
        </div>
      </div>

      {/* 1c. Quick Actions Panel — 4 tombol cepat untuk action paling sering */}
      <QuickActions pendingLeaveCount={data.pendingLeaveRequests} />

      {/* 2. KPI Cards — 6 cards dengan icon box duotone + lift hover + stagger entrance */}
      <div className="grid grid-cols-2 lg:grid-cols-6 gap-4">
        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '0ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Total Mahasiswa</span>
            <span className="kpi-icon-box">
              <GraduationCap size={18} />
            </span>
          </div>
          <span className="summary-card-value">
            <AnimatedNumber value={data.totalMahasiswa} />
          </span>
          <div className="flex items-center justify-between gap-2 mt-1">
            <span className="summary-card-sublabel">Aktif terdaftar</span>
            <TrendPill trend={data.trends.totalMahasiswa} hidePeriod />
          </div>
        </div>

        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '60ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Total Dosen</span>
            <span className="kpi-icon-box">
              <Users size={18} />
            </span>
          </div>
          <span className="summary-card-value">
            <AnimatedNumber value={data.totalDosen} />
          </span>
          <div className="flex items-center justify-between gap-2 mt-1">
            <span className="summary-card-sublabel">Pengajar aktif</span>
            <TrendPill trend={data.trends.totalDosen} hidePeriod />
          </div>
        </div>

        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '120ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Hadir Hari Ini</span>
            <span className="kpi-icon-box success">
              <CheckCircle size={18} />
            </span>
          </div>
          <span className="summary-card-value text-success">
            <AnimatedNumber value={data.totalHadir} />
          </span>
          <div className="flex items-center justify-between gap-2 mt-1">
            <span className="summary-card-sublabel">Absensi tercatat</span>
            <TrendPill trend={data.trends.totalHadir} hidePeriod />
          </div>
        </div>

        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '180ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Alpa Hari Ini</span>
            <span className="kpi-icon-box danger">
              <XCircle size={18} />
            </span>
          </div>
          <span className="summary-card-value text-danger">
            <AnimatedNumber value={data.totalAlpa} />
          </span>
          <div className="flex items-center justify-between gap-2 mt-1">
            <span className="summary-card-sublabel">Tidak hadir</span>
            <TrendPill trend={data.trends.totalAlpa} inverse hidePeriod />
          </div>
        </div>

        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '240ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Izin / Sakit</span>
            <span className="kpi-icon-box warning">
              <Clock size={18} />
            </span>
          </div>
          <span className="summary-card-value text-warning">
            <AnimatedNumber value={data.totalIzin} />
          </span>
          <div className="flex items-center justify-between gap-2 mt-1">
            <span className="summary-card-sublabel">Hari ini</span>
            <TrendPill trend={data.trends.totalIzin} inverse hidePeriod />
          </div>
        </div>

        <div className="kpi-card animate-stagger-in" style={{ animationDelay: '300ms' }}>
          <div className="flex items-center justify-between mb-2">
            <span className="summary-card-label">Menunggu Review</span>
            <span className="kpi-icon-box accent">
              <FileText size={18} />
            </span>
          </div>
          <span className="summary-card-value text-warning">
            <AnimatedNumber value={data.pendingLeaveRequests} />
          </span>
          <div className="flex items-center justify-between gap-2 mt-1">
            <span className="summary-card-sublabel">Pengajuan izin</span>
            <TrendPill trend={data.trends.pendingLeaveRequests} inverse hidePeriod />
          </div>
        </div>
      </div>

      {/* 3. Insight Row — At-Risk Widget (2/3) + Recent Activity Feed (1/3) */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2">
          <AtRiskWidget summary={atRiskSummary} />
        </div>
        <div className="lg:col-span-1">
          <RecentActivityFeed activities={recentActivities} />
        </div>
      </div>

      {/* 4. Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Area Chart — Trend 7 Hari */}
        <div className="card p-6 lg:col-span-2">
          <div className="mb-4">
            <h3 className="text-base font-bold font-heading text-text-primary">
              Tren Kehadiran 7 Hari Terakhir
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Pergerakan presensi seluruh kelas secara global
            </p>
          </div>
          {data.weeklyTrend.every(d => d.hadir === 0 && d.izin === 0 && d.alpa === 0) ? (
            <div className="flex items-center justify-center h-[240px]">
              <p className="text-text-secondary text-sm">Belum ada data presensi minggu ini.</p>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <AreaChart data={data.weeklyTrend} margin={{ top: 5, right: 5, bottom: 0, left: -20 }}>
                <defs>
                  <linearGradient id="adminGradHadir" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={STATUS_COLORS.hadir} stopOpacity={0.15} />
                    <stop offset="95%" stopColor={STATUS_COLORS.hadir} stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="adminGradIzin" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={STATUS_COLORS.izin} stopOpacity={0.15} />
                    <stop offset="95%" stopColor={STATUS_COLORS.izin} stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="adminGradAlpa" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={STATUS_COLORS.alpa} stopOpacity={0.15} />
                    <stop offset="95%" stopColor={STATUS_COLORS.alpa} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(226,230,234,0.6)" />
                <XAxis dataKey="day" tick={{ fontSize: 12, fill: BRAND_COLORS.textSecondary }} axisLine={{ stroke: BRAND_COLORS.border }} tickLine={false} />
                <YAxis tick={{ fontSize: 12, fill: BRAND_COLORS.textSecondary }} axisLine={false} tickLine={false} allowDecimals={false} />
                <Tooltip content={<TrendTooltip />} />
                <Area type="monotone" dataKey="hadir" name="Hadir" stroke={STATUS_COLORS.hadir} strokeWidth={2} fill="url(#adminGradHadir)" />
                <Area type="monotone" dataKey="izin" name="Izin/Sakit" stroke={STATUS_COLORS.izin} strokeWidth={2} fill="url(#adminGradIzin)" />
                <Area type="monotone" dataKey="alpa" name="Alpa" stroke={STATUS_COLORS.alpa} strokeWidth={2} fill="url(#adminGradAlpa)" />
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
              Distribusi status 30 hari terakhir
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
                  data={data.attendanceRatio}
                  cx="50%"
                  cy="50%"
                  innerRadius={55}
                  outerRadius={85}
                  paddingAngle={3}
                  dataKey="value"
                  strokeWidth={0}
                >
                  {data.attendanceRatio.map((entry, index) => (
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

      {/* 4. Bar Chart — Kehadiran per Mata Kuliah */}
      {data.courseOverview.length > 0 && (
        <div className="card p-6">
          <div className="mb-4">
            <h3 className="text-base font-bold font-heading text-text-primary">
              Kehadiran per Mata Kuliah
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Distribusi status presensi berdasarkan mata kuliah
            </p>
          </div>
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={data.courseOverview} margin={{ top: 5, right: 5, bottom: 5, left: -10 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(226,230,234,0.6)" />
              <XAxis
                dataKey="code"
                tick={{ fontSize: 11, fill: BRAND_COLORS.textSecondary }}
                axisLine={{ stroke: BRAND_COLORS.border }}
                tickLine={false}
              />
              <YAxis
                tick={{ fontSize: 12, fill: BRAND_COLORS.textSecondary }}
                axisLine={false}
                tickLine={false}
                allowDecimals={false}
              />
              <Tooltip content={<BarTooltip />} />
              <Legend
                verticalAlign="top"
                align="right"
                iconType="square"
                iconSize={10}
                formatter={(value: string) => (
                  <span style={{ fontSize: '12px', color: BRAND_COLORS.textSecondary }}>{value}</span>
                )}
              />
              <Bar dataKey="totalHadir" name="Hadir" fill={STATUS_COLORS.hadir} radius={[4, 4, 0, 0]} />
              <Bar dataKey="totalIzin" name="Izin/Sakit" fill={STATUS_COLORS.izin} radius={[4, 4, 0, 0]} />
              <Bar dataKey="totalAlpa" name="Alpa" fill={STATUS_COLORS.alpa} radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* 5. Tabel Absensi Terkini */}
      <div className="card overflow-hidden">
        <div className="px-6 py-4 border-b border-border flex items-center justify-between">
          <div>
            <h3 className="text-base font-bold font-heading text-text-primary">
              Absensi Terkini
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Riwayat absensi hari ini secara real-time
            </p>
          </div>
        </div>

        <div className="overflow-x-auto">
          {data.recentAttendances.length === 0 ? (
            <EmptyState
              icon={Clock}
              title="Belum ada absensi hari ini"
              description="Riwayat presensi terbaru akan muncul saat mahasiswa melakukan absensi pada sesi aktif."
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
                {data.recentAttendances.map((att: Record<string, unknown>) => {
                  const student = att.student as Record<string, string> | null
                  const session = att.session as Record<string, unknown> | null
                  const course = session?.course as Record<string, string> | null
                  const config = statusConfig[att.status as keyof typeof statusConfig]
                  return (
                    <tr key={att.id as string}>
                      <td>
                        <div>
                          <p className="font-medium text-text-primary text-sm">
                            {student?.full_name ?? '-'}
                          </p>
                          <p className="text-xs text-text-secondary">
                            {student?.nim_nip ?? ''}
                          </p>
                        </div>
                      </td>
                      <td className="text-text-primary text-sm">
                        {course?.name ?? '-'}
                      </td>
                      <td className="text-text-secondary text-sm">
                        {(session?.topic as string) ?? '-'}
                      </td>
                      <td className="text-text-secondary text-sm tabular-nums">
                        {new Date(att.scanned_at as string).toLocaleTimeString('id-ID', {
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
