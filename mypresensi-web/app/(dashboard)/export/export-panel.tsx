'use client'
// app/(dashboard)/export/export-panel.tsx
// Panel interaktif untuk export data ke CSV dan PDF.
// Client Component — mengelola state loading dan trigger download.

import { useState } from 'react'
import { Download, Users, GraduationCap, BookOpen, ClipboardList, FileText } from 'lucide-react'
import { exportDosenCSV, exportMahasiswaCSV, exportCoursesCSV, exportPresensiCSV } from '@/lib/actions/export'
import type { RekapPDFCourse } from '@/lib/actions/export'
import { swal, Swal } from '@/lib/swal'
import { getFriendlyErrorMessage } from '@/lib/utils'
import ExportPDFModal from './export-pdf-modal'

interface ExportPanelProps {
  courses: RekapPDFCourse[]
}

const csvModules = [
  {
    id: 'dosen',
    label: 'Data Dosen',
    description: 'Nama, NIP, No. HP, Status',
    icon: Users,
    color: '#5483AD',
    action: exportDosenCSV,
    filename: 'data_dosen',
  },
  {
    id: 'mahasiswa',
    label: 'Data Mahasiswa',
    description: 'Nama, NIM, Semester, Kelas, Face ID',
    icon: GraduationCap,
    color: '#1A7F37',
    action: exportMahasiswaCSV,
    filename: 'data_mahasiswa',
  },
  {
    id: 'courses',
    label: 'Mata Kuliah',
    description: 'Kode MK, Nama, SKS, Dosen Pengampu',
    icon: BookOpen,
    color: '#9A6700',
    action: exportCoursesCSV,
    filename: 'data_matakuliah',
  },
  {
    id: 'presensi',
    label: 'Rekap Presensi (CSV)',
    description: 'Data kehadiran lengkap (maks 5000 baris)',
    icon: ClipboardList,
    color: '#636C76',
    action: exportPresensiCSV,
    filename: 'rekap_presensi',
  },
]

export default function ExportPanel({ courses }: ExportPanelProps) {
  const [loadingId, setLoadingId] = useState<string | null>(null)
  const [showPDFModal, setShowPDFModal] = useState(false)

  const handleExport = async (moduleId: string) => {
    const mod = csvModules.find((m) => m.id === moduleId)
    if (!mod) return

    setLoadingId(moduleId)

    try {
      swal.fire({
        title: `Mengekspor ${mod.label}...`,
        text: 'Mohon tunggu sebentar',
        allowOutsideClick: false,
        didOpen: () => Swal.showLoading(),
      })

      const csvString = await mod.action()

      // Create & download file
      const blob = new Blob(['\uFEFF' + csvString], { type: 'text/csv;charset=utf-8;' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      const timestamp = new Date().toISOString().split('T')[0]
      link.href = url
      link.download = `${mod.filename}_${timestamp}.csv`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)

      swal.fire({
        icon: 'success',
        title: 'Export Berhasil!',
        text: `File ${mod.filename}_${timestamp}.csv telah diunduh.`,
      })
    } catch (err: unknown) {
      swal.fire({
        icon: 'error',
        title: 'Gagal Export',
        text: getFriendlyErrorMessage(err, 'Terjadi kesalahan saat mengekspor data.'),
      })
    } finally {
      setLoadingId(null)
    }
  }

  return (
    <>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Card PDF — Paling atas, full width */}
        <div className="card p-5 flex flex-col md:col-span-2 border-l-4 border-l-danger">
          <div className="flex items-start gap-3 mb-4">
            <div className="w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 bg-danger/10">
              <FileText size={22} className="text-danger" />
            </div>
            <div className="flex-1">
              <h3 className="text-sm font-bold text-text-primary">Rekap Presensi (PDF)</h3>
              <p className="text-xs text-text-secondary mt-0.5">
                Laporan kehadiran lengkap per mata kuliah — format PDF siap cetak dengan kop resmi,
                tabel detail per mahasiswa, dan ringkasan statistik.
              </p>
            </div>
          </div>

          <div className="mt-auto pt-2">
            <button
              onClick={() => setShowPDFModal(true)}
              className="btn-primary flex items-center justify-center gap-2 text-sm bg-danger hover:bg-danger"
              style={{ maxWidth: '220px' }}
            >
              <FileText size={14} />
              Generate PDF
            </button>
          </div>
        </div>

        {/* Card CSV — Grid 2 kolom */}
        {csvModules.map((mod) => {
          const Icon = mod.icon
          const isLoading = loadingId === mod.id

          return (
            <div key={mod.id} className="card p-5 flex flex-col">
              <div className="flex items-start gap-3 mb-4">
                <div
                  className="w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0"
                  style={{ backgroundColor: `${mod.color}15` }}
                >
                  <Icon size={22} style={{ color: mod.color }} />
                </div>
                <div className="flex-1">
                  <h3 className="text-sm font-bold text-text-primary">{mod.label}</h3>
                  <p className="text-xs text-text-secondary mt-0.5">{mod.description}</p>
                </div>
              </div>

              <div className="mt-auto pt-2">
                <button
                  onClick={() => handleExport(mod.id)}
                  disabled={isLoading}
                  className="w-full btn-primary flex items-center justify-center gap-2 text-sm"
                >
                  {isLoading ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      Mengunduh...
                    </>
                  ) : (
                    <>
                      <Download size={14} /> Download CSV
                    </>
                  )}
                </button>
              </div>
            </div>
          )
        })}
      </div>

      {/* Modal Export PDF */}
      <ExportPDFModal
        isOpen={showPDFModal}
        onClose={() => setShowPDFModal(false)}
        courses={courses}
      />
    </>
  )
}
