'use client'
// app/(dashboard)/export/export-pdf-modal.tsx
// Modal untuk memilih mata kuliah dan generate PDF rekap kehadiran.
// Menggunakan jsPDF + AutoTable untuk generate PDF di client-side.

import { useState } from 'react'
import { X, FileText, Download, BookOpen } from 'lucide-react'
import { getRekapPDFData } from '@/lib/actions/export'
import type { RekapPDFCourse, RekapPDFData } from '@/lib/actions/export'
import { swal, Swal } from '@/lib/swal'
import { getFriendlyErrorMessage } from '@/lib/utils'
import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'

interface ExportPDFModalProps {
  isOpen: boolean
  onClose: () => void
  courses: RekapPDFCourse[]
}

/**
 * Generate PDF rekap kehadiran dari RekapPDFData.
 * Format: kop header + info MK + tabel per pertemuan + tabel detail mahasiswa + ringkasan.
 */
function generatePDF(data: RekapPDFData, printedBy: string) {
  const doc = new jsPDF({
    orientation: data.sessions.length > 8 ? 'landscape' : 'portrait',
    unit: 'mm',
    format: 'a4',
  })

  const pageWidth = doc.internal.pageSize.getWidth()
  const margin = 14
  let yPos = margin

  // === 1. KOP HEADER ===
  doc.setFontSize(14)
  doc.setFont('helvetica', 'bold')
  doc.text('LAPORAN REKAP KEHADIRAN', pageWidth / 2, yPos, { align: 'center' })
  yPos += 6

  doc.setFontSize(10)
  doc.setFont('helvetica', 'normal')
  doc.text('Politeknik Pertanian Negeri Samarinda', pageWidth / 2, yPos, { align: 'center' })
  yPos += 4
  doc.text('Program Studi Teknologi Rekayasa Perangkat Lunak', pageWidth / 2, yPos, { align: 'center' })
  yPos += 6

  // Garis pemisah
  doc.setDrawColor(84, 131, 173) // --color-primary
  doc.setLineWidth(0.8)
  doc.line(margin, yPos, pageWidth - margin, yPos)
  yPos += 8

  // === 2. INFO MATA KULIAH ===
  doc.setFontSize(9)
  doc.setFont('helvetica', 'normal')

  const infoLabels = [
    ['Mata Kuliah', `${data.course.name} (${data.course.code})`],
    ['SKS', `${data.course.sks}`],
    ['Semester', `${data.course.semester}`],
    ['Dosen Pengampu', data.course.dosenName],
    ['Tahun Akademik', data.course.academicYear],
    ['Tanggal Cetak', new Date().toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })],
  ]

  infoLabels.forEach(([label, value]) => {
    doc.setFont('helvetica', 'bold')
    doc.text(`${label}`, margin, yPos)
    doc.setFont('helvetica', 'normal')
    doc.text(`: ${value}`, margin + 35, yPos)
    yPos += 5
  })

  yPos += 4

  // === 3. TABEL REKAP PER PERTEMUAN ===
  if (data.sessions.length > 0) {
    doc.setFontSize(10)
    doc.setFont('helvetica', 'bold')
    doc.text('A. Rekap Per Pertemuan', margin, yPos)
    yPos += 2

    autoTable(doc, {
      startY: yPos,
      head: [['No', 'Pertemuan', 'Topik', 'Tanggal', 'Hadir', 'Telat', 'Izin', 'Sakit', 'Alpa', 'Total']],
      body: data.sessions.map((s, i) => [
        `${i + 1}`,
        `P${s.sessionNumber}`,
        s.topic.length > 30 ? s.topic.substring(0, 30) + '...' : s.topic,
        s.date,
        `${s.hadir}`,
        `${s.terlambat}`,
        `${s.izin}`,
        `${s.sakit}`,
        `${s.alpa}`,
        `${s.total}`,
      ]),
      theme: 'grid',
      styles: {
        fontSize: 7.5,
        cellPadding: 2,
        halign: 'center',
        lineColor: [200, 200, 200],
        lineWidth: 0.3,
      },
      headStyles: {
        fillColor: [84, 131, 173], // --color-primary
        textColor: [255, 255, 255],
        fontStyle: 'bold',
        fontSize: 8,
      },
      columnStyles: {
        0: { cellWidth: 10, halign: 'center' },
        1: { cellWidth: 18, halign: 'center' },
        2: { halign: 'left', cellWidth: 'auto' },
        3: { cellWidth: 25, halign: 'center' },
      },
      alternateRowStyles: {
        fillColor: [245, 248, 252],
      },
      margin: { left: margin, right: margin },
    })

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    yPos = (doc as any).lastAutoTable.finalY + 8
  }

  // === 4. TABEL DETAIL MAHASISWA ===
  if (data.students.length > 0) {
    // Cek apakah perlu halaman baru
    if (yPos > doc.internal.pageSize.getHeight() - 40) {
      doc.addPage()
      yPos = margin
    }

    doc.setFontSize(10)
    doc.setFont('helvetica', 'bold')
    doc.text('B. Detail Kehadiran Per Mahasiswa', margin, yPos)
    yPos += 2

    // Header dinamis berdasarkan jumlah pertemuan
    const sessionHeaders = data.sessions.map(s => `P${s.sessionNumber}`)
    const headers = ['No', 'NIM', 'Nama', ...sessionHeaders, 'H', 'T', 'I', 'S', 'A', '%']

    const body = data.students.map((student, i) => {
      const sessionValues = data.sessions.map(s => student.attendances[s.sessionNumber] ?? '-')
      return [
        `${i + 1}`,
        student.nim,
        student.name.length > 20 ? student.name.substring(0, 20) + '...' : student.name,
        ...sessionValues,
        `${student.totalHadir}`,
        `${student.totalTerlambat}`,
        `${student.totalIzin}`,
        `${student.totalSakit}`,
        `${student.totalAlpa}`,
        `${student.percentage}%`,
      ]
    })

    autoTable(doc, {
      startY: yPos,
      head: [headers],
      body,
      theme: 'grid',
      styles: {
        fontSize: 6.5,
        cellPadding: 1.5,
        halign: 'center',
        lineColor: [200, 200, 200],
        lineWidth: 0.3,
      },
      headStyles: {
        fillColor: [84, 131, 173],
        textColor: [255, 255, 255],
        fontStyle: 'bold',
        fontSize: 7,
      },
      columnStyles: {
        0: { cellWidth: 8 },
        1: { cellWidth: 22, halign: 'left', fontSize: 6 },
        2: { cellWidth: 28, halign: 'left' },
      },
      alternateRowStyles: {
        fillColor: [245, 248, 252],
      },
      // Warnai sel berdasarkan status
      didParseCell: (hookData) => {
        const cellText = hookData.cell.text[0]
        if (hookData.section === 'body' && hookData.column.index >= 3) {
          if (cellText === 'H') {
            hookData.cell.styles.textColor = [26, 127, 55] // success
            hookData.cell.styles.fontStyle = 'bold'
          } else if (cellText === 'A') {
            hookData.cell.styles.textColor = [207, 34, 46] // danger
            hookData.cell.styles.fontStyle = 'bold'
          } else if (cellText === 'I' || cellText === 'S') {
            hookData.cell.styles.textColor = [154, 103, 0] // warning
          }
        }
      },
      margin: { left: margin, right: margin },
    })

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    yPos = (doc as any).lastAutoTable.finalY + 8
  }

  // === 5. RINGKASAN ===
  if (yPos > doc.internal.pageSize.getHeight() - 30) {
    doc.addPage()
    yPos = margin
  }

  doc.setFontSize(10)
  doc.setFont('helvetica', 'bold')
  doc.text('C. Ringkasan', margin, yPos)
  yPos += 6

  doc.setFontSize(9)
  doc.setFont('helvetica', 'normal')

  // Tingkat Kehadiran inklusif: (hadir + terlambat) / total — sesuai migration 013
  const summaryItems = [
    ['Total Pertemuan', `${data.summary.totalSesi} sesi`],
    ['Total Hadir (on-time)', `${data.summary.totalHadir}`],
    ['Total Terlambat', `${data.summary.totalTerlambat}`],
    ['Total Izin', `${data.summary.totalIzin}`],
    ['Total Sakit', `${data.summary.totalSakit}`],
    ['Total Alpa', `${data.summary.totalAlpa}`],
    ['Tingkat Kehadiran', `${data.summary.rateHadir}% (hadir + terlambat / total)`],
  ]

  summaryItems.forEach(([label, value]) => {
    doc.setFont('helvetica', 'bold')
    doc.text(`${label}`, margin, yPos)
    doc.setFont('helvetica', 'normal')
    doc.text(`: ${value}`, margin + 35, yPos)
    yPos += 5
  })

  // === 6. FOOTER ===
  yPos += 6
  doc.setFontSize(8)
  doc.setTextColor(120, 120, 120)
  doc.text(`Dicetak oleh: ${printedBy}`, margin, yPos)
  doc.text(
    `Tanggal: ${new Date().toLocaleDateString('id-ID')} ${new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}`,
    margin,
    yPos + 4
  )
  doc.text('Dokumen ini digenerate otomatis oleh sistem MyPresensi.', margin, yPos + 8)

  // Page numbers
  const pageCount = doc.getNumberOfPages()
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i)
    doc.setFontSize(8)
    doc.setTextColor(150, 150, 150)
    doc.text(
      `Halaman ${i} dari ${pageCount}`,
      pageWidth / 2,
      doc.internal.pageSize.getHeight() - 8,
      { align: 'center' }
    )
  }

  // Save PDF
  const filename = `Rekap_${data.course.code}_${new Date().toISOString().split('T')[0]}.pdf`
  doc.save(filename)
  return filename
}

export default function ExportPDFModal({ isOpen, onClose, courses }: ExportPDFModalProps) {
  const [selectedCourseId, setSelectedCourseId] = useState('')
  const [isLoading, setIsLoading] = useState(false)

  if (!isOpen) return null

  const handleGenerate = async () => {
    if (!selectedCourseId) {
      swal.fire({ icon: 'warning', title: 'Pilih Mata Kuliah', text: 'Silakan pilih mata kuliah terlebih dahulu.' })
      return
    }

    setIsLoading(true)

    try {
      swal.fire({
        title: 'Membuat Dokumen PDF...',
        text: 'Mengambil data rekap kehadiran',
        allowOutsideClick: false,
        didOpen: () => Swal.showLoading(),
      })

      const { data, error } = await getRekapPDFData(selectedCourseId)

      if (error || !data) {
        swal.fire({ icon: 'error', title: 'Gagal', text: error ?? 'Terjadi kesalahan saat mengambil data.' })
        return
      }

      if (data.sessions.length === 0) {
        swal.fire({
          icon: 'info',
          title: 'Data Kosong',
          text: 'Belum ada sesi pertemuan untuk mata kuliah ini. Tidak ada data yang bisa diekspor.',
        })
        return
      }

      // Generate PDF di client
      const filename = generatePDF(data, 'Administrator MyPresensi')

      swal.fire({
        icon: 'success',
        title: 'PDF Berhasil Dibuat!',
        text: `File ${filename} telah diunduh.`,
      })

      onClose()
    } catch (err: unknown) {
      swal.fire({ icon: 'error', title: 'Gagal', text: getFriendlyErrorMessage(err, 'Terjadi kesalahan.') })
    } finally {
      setIsLoading(false)
    }
  }

  const selectedCourse = courses.find(c => c.id === selectedCourseId)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />

      {/* Modal */}
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg border border-border">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-border">
          <div className="flex items-center gap-3">
            <div
              className="w-9 h-9 rounded-lg flex items-center justify-center bg-danger/10"
            >
              <FileText size={18} className="text-danger" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-text-primary">Export Rekap PDF</h3>
              <p className="text-xs text-text-secondary">Laporan kehadiran per mata kuliah</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <X size={18} className="text-text-secondary" />
          </button>
        </div>

        {/* Body */}
        <div className="px-6 py-5 flex flex-col gap-4">
          {/* Dropdown Mata Kuliah */}
          <div>
            <label className="form-label">Pilih Mata Kuliah</label>
            <select
              value={selectedCourseId}
              onChange={(e) => setSelectedCourseId(e.target.value)}
              className="input-field"
            >
              <option value="">— Pilih Mata Kuliah —</option>
              {courses.map((course) => (
                <option key={course.id} value={course.id}>
                  {course.code} — {course.name} (Sem. {course.semester})
                </option>
              ))}
            </select>
          </div>

          {/* Preview info jika sudah pilih */}
          {selectedCourse && (
            <div className="card p-4" style={{ backgroundColor: '#F8FAFC' }}>
              <div className="flex items-start gap-3">
                <BookOpen size={16} className="text-primary mt-0.5 flex-shrink-0" />
                <div className="text-xs space-y-1">
                  <p className="font-semibold text-text-primary">{selectedCourse.name}</p>
                  <p className="text-text-secondary">
                    {selectedCourse.code} · Semester {selectedCourse.semester} · {selectedCourse.sks} SKS
                  </p>
                  <p className="text-text-secondary">Dosen: {selectedCourse.dosenName}</p>
                  <p className="text-text-secondary">Tahun Akademik: {selectedCourse.academicYear}</p>
                </div>
              </div>
            </div>
          )}

          {/* Info format */}
          <div className="card p-3 bg-primary/10 border-primary/20">
            <p className="text-xs text-primary">
              PDF akan berisi: kop resmi, info mata kuliah, tabel rekap per pertemuan,
              tabel detail kehadiran per mahasiswa (H/T/I/S/A), dan ringkasan statistik.
              Tingkat kehadiran inklusif: hadir + terlambat dianggap hadir.
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-border">
          <button
            onClick={onClose}
            className="btn-secondary text-sm"
            disabled={isLoading}
          >
            Batal
          </button>
          <button
            onClick={handleGenerate}
            disabled={isLoading || !selectedCourseId}
            className="btn-primary flex items-center gap-2 text-sm"
          >
            {isLoading ? (
              <>
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                Memproses...
              </>
            ) : (
              <>
                <Download size={14} />
                Download PDF
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
