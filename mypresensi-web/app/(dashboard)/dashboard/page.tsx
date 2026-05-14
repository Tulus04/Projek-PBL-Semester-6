// app/(dashboard)/dashboard/page.tsx
// Halaman utama dashboard — render konten berbeda berdasarkan role user.
// Admin: statistik global + grafik Recharts. Dosen: statistik MK yang diampu + grafik.
// Server Component — deteksi role di server, zero client-side auth check.

import { Metadata } from 'next'
import { createClient, createAdminClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AdminDashboard from './admin-dashboard'
import DosenDashboard from './dosen-dashboard'
import { getDosenDashboardData, getAdminDashboardData } from '@/lib/actions/dashboard'
import { getAtRiskSummary } from '@/lib/actions/at-risk'
import { getActiveSessionStatus } from '@/lib/actions/live-session'
import { getRecentActivity } from '@/lib/actions/recent-activity'

export const metadata: Metadata = {
  title: 'Dashboard',
}

export default async function DashboardPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  // Ambil role user yang sedang login
  const adminClient = createAdminClient()
  const { data: profile } = await adminClient
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  const role = profile?.role ?? 'admin'

  // Render dashboard berdasarkan role
  if (role === 'dosen') {
    // Fetch dashboard data + active session paralel (1 round-trip)
    const [dashboardData, activeSession] = await Promise.all([
      getDosenDashboardData(),
      getActiveSessionStatus(),
    ])

    return (
      <DosenDashboard
        dosenName={dashboardData.dosenName}
        summary={dashboardData.summary}
        courses={dashboardData.courses}
        weeklyTrend={dashboardData.weeklyTrend}
        attendanceRatio={dashboardData.attendanceRatio}
        recentAttendances={dashboardData.recentAttendances}
        activeSession={activeSession}
      />
    )
  }

  // Admin dashboard — fetch chart data + at-risk summary + recent activity paralel
  const [adminData, atRiskSummary, recentActivities] = await Promise.all([
    getAdminDashboardData(),
    getAtRiskSummary(),
    getRecentActivity(15),
  ])
  return (
    <AdminDashboard
      data={adminData}
      atRiskSummary={atRiskSummary}
      recentActivities={recentActivities}
    />
  )
}
