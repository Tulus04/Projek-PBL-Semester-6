// app/(dashboard)/audit/page.tsx
// Halaman audit log — riwayat aktivitas sistem.
// Server Component — data diambil di server dengan pagination.

import { Metadata } from 'next'
import { createAdminClient } from '@/lib/supabase/server'
import { ScrollText } from 'lucide-react'
import AuditTable from './audit-table'
import AuditFilters from './audit-filters'
import Pagination from '@/components/ui/pagination'

export const metadata: Metadata = {
  title: 'Audit Log',
}

interface PageProps {
  searchParams: {
    page?: string
    action?: string
    from?: string
    to?: string
  }
}

export default async function AuditLogPage({ searchParams }: PageProps) {
  const supabase = createAdminClient()
  const page = parseInt(searchParams.page || '1', 10)
  const perPage = 15
  const offset = (page - 1) * perPage

  // Build query with filters
  let query = supabase
    .from('audit_logs')
    .select(
      'id, action, details, ip_address, created_at, user:profiles!user_id(full_name, nim_nip, role)',
      { count: 'exact' }
    )
    .order('created_at', { ascending: false })
    .range(offset, offset + perPage - 1)

  if (searchParams.action) {
    query = query.ilike('action', `%${searchParams.action}%`)
  }
  if (searchParams.from) {
    query = query.gte('created_at', searchParams.from)
  }
  if (searchParams.to) {
    query = query.lte('created_at', `${searchParams.to}T23:59:59`)
  }

  const { data: logs, count } = await query
  const totalPages = Math.ceil((count ?? 0) / perPage)

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <ScrollText size={20} className="text-primary" />
        </div>
        <div>
          <h2 className="page-title">Audit Log</h2>
          <p className="page-subtitle">{count ?? 0} aktivitas tercatat</p>
        </div>
      </div>

      <AuditFilters
        currentAction={searchParams.action}
        currentFrom={searchParams.from}
        currentTo={searchParams.to}
      />

      <div className="card overflow-hidden">
        <AuditTable logs={(logs ?? []).map((log: Record<string, unknown>) => {
          const userRaw = log.user as unknown
          const user = Array.isArray(userRaw) ? userRaw[0] ?? null : userRaw
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          return { ...log, user } as any
        })} />

        <Pagination
          page={page}
          totalPages={totalPages}
          total={count ?? 0}
          baseHref="/audit"
          searchParams={{
            action: searchParams.action,
            from: searchParams.from,
            to: searchParams.to,
          }}
          size="compact"
        />
      </div>
    </div>
  )
}
