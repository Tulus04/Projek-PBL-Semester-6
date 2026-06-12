'use client'
// app/(dashboard)/rekap/rekap-table.tsx
// Tabel rekap presensi per MK — expand untuk lihat sesi.

import { useState } from 'react'
import { ChevronDown, ChevronRight, BarChart3, PlayCircle } from 'lucide-react'
import Link from 'next/link'
import EmptyState from '@/components/ui/empty-state'

interface SessionItem {
  id: string
  session_number: number
  is_active: boolean
  topic: string | null
  started_at: string | null
}

interface RekapItem {
  id: string
  code: string
  name: string
  semester: number
  academic_year: string
  // Supabase mengembalikan join sebagai object atau array (tergantung relasi),
  // hanya field yang dipakai di tabel ini.
  dosen: { id: string; full_name: string } | { id: string; full_name: string }[] | null
  totalSesi: number
  sessions: SessionItem[]
  stats: {
    hadir: number
    terlambat: number
    izin: number
    sakit: number
    alpa: number
    total: number
  }
}

function AttendanceBar({ stats }: { stats: RekapItem['stats'] }) {
  if (stats.total === 0) {
    return <span className="text-xs text-text-secondary italic">Belum ada data</span>
  }

  // Persentase inklusif: hadir + terlambat dianggap hadir untuk perhitungan tingkat kehadiran
  // (sesuai migration 013 — terlambat = sub-variant hadir, tetap dianggap hadir)
  const pctHadir = (stats.hadir / stats.total) * 100
  const pctTerlambat = (stats.terlambat / stats.total) * 100
  const pctIzin = ((stats.izin + stats.sakit) / stats.total) * 100
  const pctAlpa = (stats.alpa / stats.total) * 100
  const pctHadirInclusive = pctHadir + pctTerlambat

  return (
    <div className="flex items-center gap-2 min-w-[200px]">
      <div className="flex-1 h-2.5 bg-gray-100 rounded-full overflow-hidden flex">
        {pctHadir > 0 && (
          <div
            className="h-full rounded-l-full bg-success"
            style={{ width: `${pctHadir}%` }}
            title={`Hadir: ${stats.hadir}`}
          />
        )}
        {pctTerlambat > 0 && (
          <div
            className="h-full"
            style={{ width: `${pctTerlambat}%`, backgroundColor: '#D97706' }}
            title={`Terlambat: ${stats.terlambat}`}
          />
        )}
        {pctIzin > 0 && (
          <div
            className="h-full bg-warning"
            style={{ width: `${pctIzin}%` }}
            title={`Izin/Sakit: ${stats.izin + stats.sakit}`}
          />
        )}
        {pctAlpa > 0 && (
          <div
            className="h-full rounded-r-full bg-danger"
            style={{ width: `${pctAlpa}%` }}
            title={`Alpa: ${stats.alpa}`}
          />
        )}
      </div>
      <span
        className={`text-xs font-semibold tabular-nums ${pctHadirInclusive >= 80 ? 'text-success' : 'text-danger'}`}
        title="Tingkat kehadiran inklusif (hadir + terlambat) / total"
      >
        {Math.round(pctHadirInclusive)}%
      </span>
    </div>
  )
}

export default function RekapTable({ data }: { data: RekapItem[] }) {
  const [expandedId, setExpandedId] = useState<string | null>(null)

  if (data.length === 0) {
    return (
      <EmptyState
        icon={BarChart3}
        title="Belum ada data rekap presensi"
        description="Rekap akan muncul setelah mahasiswa melakukan presensi pada sesi perkuliahan. Filter di atas bisa membantu mempersempit pencarian."
        action={
          <Link href="/sesi" className="btn-primary inline-flex">
            <PlayCircle size={14} /> Kelola Sesi Presensi
          </Link>
        }
      />
    )
  }

  return (
    <div className="overflow-x-auto">
      <table className="data-table">
        <thead>
          <tr>
            <th className="w-8"></th>
            <th>Kode</th>
            <th>Mata Kuliah</th>
            <th>Dosen</th>
            <th className="text-center">Sesi</th>
            <th>Hadir</th>
            <th>Alpa</th>
            <th>Izin</th>
            <th>Kehadiran</th>
          </tr>
        </thead>
        <tbody>
          {data.map((item) => {
            const isExpanded = expandedId === item.id
            return (
              <>
                <tr
                  key={item.id}
                  className="cursor-pointer hover:bg-gray-50"
                  onClick={() => setExpandedId(isExpanded ? null : item.id)}
                >
                  <td className="w-8">
                    {isExpanded ? (
                      <ChevronDown size={14} className="text-text-secondary" />
                    ) : (
                      <ChevronRight size={14} className="text-text-secondary" />
                    )}
                  </td>
                  <td className="font-mono text-sm font-semibold text-primary">{item.code}</td>
                  <td className="text-sm font-medium text-text-primary">{item.name}</td>
                  <td className="text-sm text-text-secondary">
                    {(() => {
                      const dosen = Array.isArray(item.dosen) ? item.dosen[0] : item.dosen
                      return dosen?.full_name ?? <span className="italic">Belum ditentukan</span>
                    })()}
                  </td>
                  <td className="text-center text-sm font-semibold">{item.totalSesi}</td>
                  <td className="text-sm font-semibold text-success">
                    {item.stats.hadir + item.stats.terlambat}
                    {item.stats.terlambat > 0 && (
                      <span className="text-xs font-normal block" style={{ color: '#D97706' }}>
                        ({item.stats.terlambat} terlambat)
                      </span>
                    )}
                  </td>
                  <td className="text-sm font-semibold text-danger">{item.stats.alpa}</td>
                  <td className="text-sm font-semibold text-warning">{item.stats.izin + item.stats.sakit}</td>
                  <td>
                    <AttendanceBar stats={item.stats} />
                  </td>
                </tr>

                {/* Expanded: Session Details */}
                {isExpanded && (
                  <tr key={`${item.id}-sessions`}>
                    <td colSpan={9} className="!p-0">
                      <div className="bg-gray-50 border-t border-border px-6 py-4">
                        <p className="text-xs font-semibold text-text-secondary mb-3 uppercase tracking-wide">
                          Detail Sesi Perkuliahan
                        </p>
                        {item.sessions.length === 0 ? (
                          <p className="text-xs text-text-secondary italic">Belum ada sesi terlaksana.</p>
                        ) : (
                          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
                            {item.sessions.map((session) => (
                              <div
                                key={session.id}
                                className="bg-white rounded-lg border border-border p-3 text-sm"
                              >
                                <div className="flex items-center justify-between mb-1">
                                  <span className="font-semibold text-text-primary">
                                    Pertemuan {session.session_number}
                                  </span>
                                  <span className={session.is_active ? 'badge badge-success' : 'badge badge-neutral'}>
                                    {session.is_active ? 'Aktif' : 'Selesai'}
                                  </span>
                                </div>
                                <p className="text-xs text-text-secondary">
                                  {session.topic ?? 'Tidak ada topik'}
                                </p>
                                <p className="text-xs text-text-secondary mt-1">
                                  {session.started_at
                                    ? new Date(session.started_at).toLocaleDateString('id-ID', {
                                        day: '2-digit',
                                        month: 'short',
                                        year: 'numeric',
                                        hour: '2-digit',
                                        minute: '2-digit',
                                      })
                                    : '-'}
                                </p>
                              </div>
                            ))}
                          </div>
                        )}
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
