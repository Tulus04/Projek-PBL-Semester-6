'use client'
// app/(dashboard)/audit/audit-filters.tsx
// Filter untuk audit log — tanggal, tipe aksi.

import { useRouter } from 'next/navigation'
import { useState } from 'react'
import { Search, RotateCcw } from 'lucide-react'

interface Props {
  currentAction?: string
  currentFrom?: string
  currentTo?: string
}

export default function AuditFilters({ currentAction, currentFrom, currentTo }: Props) {
  const router = useRouter()
  const [action, setAction] = useState(currentAction || '')
  const [from, setFrom] = useState(currentFrom || '')
  const [to, setTo] = useState(currentTo || '')

  const handleFilter = () => {
    const params = new URLSearchParams()
    if (action) params.set('action', action)
    if (from) params.set('from', from)
    if (to) params.set('to', to)
    router.push(`/audit?${params.toString()}`)
  }

  const handleReset = () => {
    setAction('')
    setFrom('')
    setTo('')
    router.push('/audit')
  }

  return (
    <div className="card p-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-1 min-w-[180px]">
          <label className="form-label">Tipe Aksi</label>
          <select
            value={action}
            onChange={(e) => setAction(e.target.value)}
            className="input-field w-full"
          >
            <option value="">Semua Aksi</option>
            <option value="login">Login</option>
            <option value="create">Create</option>
            <option value="update">Update</option>
            <option value="delete">Delete</option>
          </select>
        </div>
        <div className="min-w-[160px]">
          <label className="form-label">Dari Tanggal</label>
          <input
            type="date"
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            className="input-field w-full"
          />
        </div>
        <div className="min-w-[160px]">
          <label className="form-label">Sampai Tanggal</label>
          <input
            type="date"
            value={to}
            onChange={(e) => setTo(e.target.value)}
            className="input-field w-full"
          />
        </div>
        <button onClick={handleFilter} className="btn-primary flex items-center gap-2">
          <Search size={14} /> Filter
        </button>
        {(action || from || to) && (
          <button
            onClick={handleReset}
            className="px-3 py-2.5 text-sm border border-border rounded-lg hover:bg-gray-50 transition-colors flex items-center gap-1.5"
          >
            <RotateCcw size={14} /> Reset
          </button>
        )}
      </div>
    </div>
  )
}
