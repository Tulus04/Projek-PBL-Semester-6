// app/(dashboard)/izin/page.tsx
// Halaman Persetujuan Izin/Sakit — Server Component.
// SECURITY: Dosen hanya melihat pengajuan izin dari MK yang dia ampu.

import { Metadata } from 'next'
import { FileText } from 'lucide-react'
import { getLeaveRequests } from '@/lib/actions/leave-requests'
import { getCurrentUserProfile } from '@/lib/auth-guard'
import LeaveTable from './leave-table'
import LeaveFilters from './leave-filters'
import Pagination from '@/components/ui/pagination'
import { redirect } from 'next/navigation'

export const metadata: Metadata = {
  title: 'Izin & Sakit',
}

export default async function IzinPage({
  searchParams,
}: {
  searchParams: { status?: string; page?: string }
}) {
  // Cek role user yang login
  const currentUser = await getCurrentUserProfile()
  if (!currentUser) redirect('/login')

  const isAdmin = currentUser.role === 'admin'
  const status = searchParams.status ?? undefined
  const page = parseInt(searchParams.page ?? '1')

  // Data isolation: dosen hanya lihat izin dari MK miliknya
  const { requests, total, totalPages } = await getLeaveRequests({
    status,
    page,
    dosenId: isAdmin ? undefined : currentUser.id,
  })

  // Count pending
  const pendingCount = requests.filter((r) => r.status === 'pending').length

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <FileText size={20} className="text-primary" />
        </div>
        <div>
          <h2 className="page-title">Izin &amp; Sakit</h2>
          <p className="page-subtitle">
            {total} pengajuan
            {pendingCount > 0 && (
              <> · <span className="text-warning font-semibold">{pendingCount} menunggu persetujuan</span></>
            )}
          </p>
        </div>
      </div>

      {/* Filters */}
      <div className="card">
        <LeaveFilters />
      </div>

      {/* Table */}
      <div className="card">
        {/* Cast karena tipe dari Supabase nested join (Supabase mengembalikan
            array ber-nested untuk setiap relasi) tidak match persis dengan
            interface LeaveRequest yang dipakai komponen client. Runtime data
            tetap aman karena komponen sudah handle null dengan optional chaining. */}
        <LeaveTable requests={requests as unknown as Parameters<typeof LeaveTable>[0]['requests']} isReadOnly={isAdmin} />

        <Pagination
          page={page}
          totalPages={totalPages}
          total={total}
          baseHref="/izin"
          searchParams={{ status }}
        />
      </div>
    </div>
  )
}
