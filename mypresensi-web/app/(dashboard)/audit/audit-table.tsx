'use client'
// app/(dashboard)/audit/audit-table.tsx
// Tabel interaktif untuk audit log — expand JSON detail.

import { useState } from 'react'
import { ChevronDown, ChevronRight, User, Shield, GraduationCap } from 'lucide-react'

interface AuditLog {
  id: string
  action: string
  details: Record<string, unknown> | null
  ip_address: string | null
  created_at: string
  user: {
    full_name: string
    nim_nip: string
    role: string
  } | null
}

const actionBadge: Record<string, { label: string; className: string }> = {
  login: { label: 'Login', className: 'badge badge-success' },
  logout: { label: 'Logout', className: 'badge badge-neutral' },
  create: { label: 'Create', className: 'badge badge-success' },
  update: { label: 'Update', className: 'badge badge-warning' },
  delete: { label: 'Delete', className: 'badge badge-danger' },
}

function getActionBadge(action: string) {
  // Match partial action strings like "login", "create_dosen", etc.
  const key = Object.keys(actionBadge).find((k) => action.toLowerCase().includes(k))
  return key ? actionBadge[key] : { label: action, className: 'badge badge-neutral' }
}

const roleIcon: Record<string, typeof User> = {
  admin: Shield,
  dosen: User,
  mahasiswa: GraduationCap,
}

export default function AuditTable({ logs }: { logs: AuditLog[] }) {
  const [expandedId, setExpandedId] = useState<string | null>(null)

  if (logs.length === 0) {
    return (
      <div className="py-16 text-center">
        <p className="text-text-secondary text-sm">
          Belum ada log aktivitas tercatat.
        </p>
      </div>
    )
  }

  return (
    <div className="overflow-x-auto">
      <table className="data-table">
        <thead>
          <tr>
            <th className="w-8"></th>
            <th>Waktu</th>
            <th>User</th>
            <th>Aksi</th>
            <th>IP Address</th>
          </tr>
        </thead>
        <tbody>
          {logs.map((log) => {
            const badge = getActionBadge(log.action)
            const isExpanded = expandedId === log.id
            const RoleIcon = log.user?.role ? roleIcon[log.user.role] || User : User

            return (
              <>
                <tr
                  key={log.id}
                  className="cursor-pointer hover:bg-gray-50"
                  onClick={() => setExpandedId(isExpanded ? null : log.id)}
                >
                  <td className="w-8">
                    {isExpanded ? (
                      <ChevronDown size={14} className="text-text-secondary" />
                    ) : (
                      <ChevronRight size={14} className="text-text-secondary" />
                    )}
                  </td>
                  <td className="text-sm tabular-nums whitespace-nowrap">
                    <div>
                      <p className="text-text-primary">
                        {new Date(log.created_at).toLocaleDateString('id-ID', {
                          day: '2-digit',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </p>
                      <p className="text-xs text-text-secondary">
                        {new Date(log.created_at).toLocaleTimeString('id-ID', {
                          hour: '2-digit',
                          minute: '2-digit',
                          second: '2-digit',
                        })}
                      </p>
                    </div>
                  </td>
                  <td>
                    {log.user ? (
                      <div className="flex items-center gap-2">
                        <div className="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                          <RoleIcon size={12} className="text-primary" />
                        </div>
                        <div>
                          <p className="text-sm font-medium text-text-primary">
                            {log.user.full_name}
                          </p>
                          <p className="text-xs text-text-secondary capitalize">
                            {log.user.role}
                          </p>
                        </div>
                      </div>
                    ) : (
                      <span className="text-sm text-text-secondary italic">System</span>
                    )}
                  </td>
                  <td>
                    <span className={badge.className}>{badge.label}</span>
                    <span className="text-xs text-text-secondary ml-2">{log.action}</span>
                  </td>
                  <td className="text-sm text-text-secondary font-mono">
                    {log.ip_address ?? '-'}
                  </td>
                </tr>

                {/* Expanded Detail Row */}
                {isExpanded && log.details && (
                  <tr key={`${log.id}-detail`}>
                    <td colSpan={5} className="!p-0">
                      <div className="bg-gray-50 border-t border-border px-6 py-4">
                        <p className="text-xs font-semibold text-text-secondary mb-2 uppercase tracking-wide">
                          Detail
                        </p>
                        <pre className="text-xs bg-white border border-border rounded-lg p-4 overflow-x-auto max-h-60 text-text-primary font-mono">
                          {JSON.stringify(log.details, null, 2)}
                        </pre>
                      </div>
                    </td>
                  </tr>
                )}
              </>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
