'use client'
// app/(dashboard)/settings/campus-locations-section.tsx
// Section untuk mengelola preset lokasi kampus di halaman Settings.
// Admin bisa tambah, edit default, dan hapus lokasi.
// Fitur "Gunakan Lokasi Saya" menggunakan navigator.geolocation (zero dependency).
// Dosen menggunakan lokasi ini saat membuat sesi presensi mode offline.

import { useState, useRef } from 'react'
import { MapPin, Plus, Star, Trash2, X, Crosshair, ExternalLink, Loader2 } from 'lucide-react'
import {
  addCampusLocationAction,
  deleteCampusLocationAction,
  setDefaultLocationAction,
} from '@/lib/actions/campus-locations'
import { swal, toast } from '@/lib/swal'
import { getFriendlyErrorMessage } from '@/lib/utils'

interface CampusLocation {
  id: string
  name: string
  latitude: number
  longitude: number
  radius_meters: number
  is_default: boolean
  is_active: boolean
}

type GeoStatus = 'idle' | 'loading' | 'success' | 'error'

export default function CampusLocationsSection({
  locations,
}: {
  locations: CampusLocation[]
}) {
  const [showAddForm, setShowAddForm] = useState(false)
  const [adding, setAdding] = useState(false)
  const [actionLoading, setActionLoading] = useState<string | null>(null)
  const [geoStatus, setGeoStatus] = useState<GeoStatus>('idle')
  const [geoCoords, setGeoCoords] = useState<{ lat: number; lng: number } | null>(null)

  // Refs untuk auto-fill field lat/lng
  const latRef = useRef<HTMLInputElement>(null)
  const lngRef = useRef<HTMLInputElement>(null)

  const handleUseMyLocation = () => {
    if (!navigator.geolocation) {
      swal.fire({
        icon: 'error',
        title: 'Tidak Didukung',
        text: 'Browser Anda tidak mendukung fitur geolokasi. Gunakan Chrome atau Firefox versi terbaru.',
      })
      return
    }

    setGeoStatus('loading')
    setGeoCoords(null)

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const lat = parseFloat(position.coords.latitude.toFixed(6))
        const lng = parseFloat(position.coords.longitude.toFixed(6))

        // Auto-fill input fields
        if (latRef.current) latRef.current.value = lat.toString()
        if (lngRef.current) lngRef.current.value = lng.toString()

        setGeoCoords({ lat, lng })
        setGeoStatus('success')
        toast.fire({ icon: 'success', title: 'Koordinat berhasil diambil!' })
      },
      (error) => {
        setGeoStatus('error')
        let message = 'Gagal mendapatkan lokasi.'
        if (error.code === error.PERMISSION_DENIED) {
          message = 'Izin lokasi ditolak. Aktifkan izin lokasi di pengaturan browser Anda.'
        } else if (error.code === error.POSITION_UNAVAILABLE) {
          message = 'Lokasi tidak tersedia. Pastikan GPS perangkat Anda aktif.'
        } else if (error.code === error.TIMEOUT) {
          message = 'Waktu pencarian lokasi habis. Coba lagi.'
        }
        swal.fire({ icon: 'error', title: 'Gagal', text: message })
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
    )
  }

  const handleAdd = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setAdding(true)
    const formData = new FormData(e.currentTarget)
    try {
      const result = await addCampusLocationAction(formData)
      if (result.success) {
        toast.fire({ icon: 'success', title: 'Lokasi berhasil ditambahkan' })
        setShowAddForm(false)
        setGeoStatus('idle')
        setGeoCoords(null)
      } else {
        swal.fire({ icon: 'error', title: 'Gagal', text: result.error ?? '' })
      }
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal',
        text: getFriendlyErrorMessage(err, 'Gagal menambahkan lokasi.'),
      })
    } finally {
      setAdding(false)
    }
  }

  const handleSetDefault = async (locationId: string, locationName: string) => {
    const confirm = await swal.fire({
      title: 'Ubah Lokasi Default?',
      html: `<b>${locationName}</b> akan dijadikan lokasi default untuk sesi baru.`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonText: 'Ya, Ubah',
      cancelButtonText: 'Batal',
    })
    if (!confirm.isConfirmed) return

    setActionLoading(locationId)
    try {
      const result = await setDefaultLocationAction(locationId)
      if (result.error) {
        swal.fire({ icon: 'error', title: 'Gagal', text: result.error })
      } else {
        toast.fire({ icon: 'success', title: `${locationName} dijadikan default` })
      }
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal',
        text: getFriendlyErrorMessage(err, 'Gagal mengubah lokasi default.'),
      })
    } finally {
      setActionLoading(null)
    }
  }

  const handleDelete = async (locationId: string, locationName: string) => {
    const confirm = await swal.fire({
      title: 'Hapus Lokasi?',
      html: `Lokasi <b>${locationName}</b> akan dihapus permanen.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Hapus',
      cancelButtonText: 'Batal',
    })
    if (!confirm.isConfirmed) return

    setActionLoading(locationId)
    try {
      const result = await deleteCampusLocationAction(locationId)
      if (result.error) {
        swal.fire({ icon: 'error', title: 'Gagal', text: result.error })
      } else {
        toast.fire({ icon: 'success', title: 'Lokasi dihapus' })
      }
    } catch (err) {
      swal.fire({
        icon: 'error',
        title: 'Gagal',
        text: getFriendlyErrorMessage(err, 'Gagal menghapus lokasi.'),
      })
    } finally {
      setActionLoading(null)
    }
  }

  // Google Maps verification link
  const mapsVerifyUrl = geoCoords
    ? `https://maps.google.com/?q=${geoCoords.lat},${geoCoords.lng}`
    : null

  return (
    <div className="card">
      {/* Header */}
      <div className="flex items-center justify-between p-5 border-b border-border">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
            <MapPin size={18} className="text-primary" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-text-primary">Lokasi Kampus</h3>
            <p className="text-xs text-text-secondary">
              Preset lokasi untuk verifikasi GPS saat presensi tatap muka
            </p>
          </div>
        </div>
        <button
          onClick={() => {
            setShowAddForm(!showAddForm)
            if (showAddForm) {
              setGeoStatus('idle')
              setGeoCoords(null)
            }
          }}
          className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5"
        >
          {showAddForm ? <X size={14} /> : <Plus size={14} />}
          {showAddForm ? 'Tutup' : 'Tambah Lokasi'}
        </button>
      </div>

      {/* Add Form */}
      {showAddForm && (
        <div className="p-5 border-b border-border bg-primary/5">
          <form onSubmit={handleAdd} className="space-y-3">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label className="form-label">Nama Lokasi</label>
                <input
                  name="name"
                  type="text"
                  placeholder="Contoh: Lab Komputer"
                  className="input-field w-full"
                  required
                />
              </div>
              <div>
                <label className="form-label">Radius (meter)</label>
                <input
                  name="radius_meters"
                  type="number"
                  defaultValue={150}
                  min={50}
                  max={500}
                  className="input-field w-full"
                  required
                />
              </div>
            </div>

            {/* Tombol Gunakan Lokasi Saya */}
            <div>
              <button
                type="button"
                onClick={handleUseMyLocation}
                disabled={geoStatus === 'loading'}
                className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-lg border-2 border-dashed transition-all text-sm font-medium"
                style={{
                  borderColor: geoStatus === 'success' ? 'var(--color-success)' : geoStatus === 'error' ? 'var(--color-danger)' : 'var(--color-border)',
                  backgroundColor: geoStatus === 'success' ? 'rgba(26, 127, 55, 0.04)' : geoStatus === 'error' ? 'rgba(207, 34, 46, 0.04)' : 'transparent',
                  color: geoStatus === 'success' ? 'var(--color-success)' : geoStatus === 'error' ? 'var(--color-danger)' : 'var(--color-primary)',
                }}
              >
                {geoStatus === 'loading' ? (
                  <>
                    <Loader2 size={16} className="animate-spin" />
                    Mencari lokasi Anda...
                  </>
                ) : geoStatus === 'success' ? (
                  <>
                    <Crosshair size={16} />
                    Lokasi berhasil diambil — klik untuk ambil ulang
                  </>
                ) : (
                  <>
                    <Crosshair size={16} />
                    Gunakan Lokasi Saya Saat Ini
                  </>
                )}
              </button>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="form-label">Latitude</label>
                <input
                  ref={latRef}
                  name="latitude"
                  type="number"
                  step="any"
                  placeholder="-0.5378"
                  className="input-field w-full"
                  required
                />
              </div>
              <div>
                <label className="form-label">Longitude</label>
                <input
                  ref={lngRef}
                  name="longitude"
                  type="number"
                  step="any"
                  placeholder="117.1242"
                  className="input-field w-full"
                  required
                />
              </div>
            </div>

            {/* Info & verification link */}
            <div className="flex items-center justify-between">
              <p className="text-[11px] text-text-secondary">
                Tip: Klik &quot;Gunakan Lokasi Saya&quot; atau salin koordinat dari Google Maps.
              </p>
              {mapsVerifyUrl && (
                <a
                  href={mapsVerifyUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-[11px] text-primary hover:underline flex items-center gap-1 flex-shrink-0"
                >
                  <ExternalLink size={11} />
                  Verifikasi di Google Maps
                </a>
              )}
            </div>

            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => {
                  setShowAddForm(false)
                  setGeoStatus('idle')
                  setGeoCoords(null)
                }}
                className="px-3 py-1.5 text-xs border border-border rounded-lg hover:bg-gray-50"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={adding}
                className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5"
              >
                {adding ? (
                  <div className="w-3 h-3 border-2 border-white border-t-transparent rounded-full animate-spin" />
                ) : (
                  <Plus size={13} />
                )}
                Simpan
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Table */}
      <div className="overflow-x-auto">
        {locations.length === 0 ? (
          <div className="p-8 text-center">
            <MapPin size={32} className="mx-auto text-text-secondary mb-2 opacity-40" />
            <p className="text-sm text-text-secondary">
              Belum ada lokasi kampus. Tambahkan lokasi pertama agar dosen bisa mengatur GPS sesi.
            </p>
          </div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>Nama Lokasi</th>
                <th>Koordinat</th>
                <th>Radius</th>
                <th>Status</th>
                <th className="text-right">Aksi</th>
              </tr>
            </thead>
            <tbody>
              {locations.map((loc) => (
                <tr key={loc.id}>
                  <td>
                    <div className="flex items-center gap-2">
                      <MapPin size={14} className="text-text-secondary" />
                      <span className="font-medium text-text-primary">{loc.name}</span>
                    </div>
                  </td>
                  <td>
                    <a
                      href={`https://maps.google.com/?q=${loc.latitude},${loc.longitude}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xs font-mono text-primary hover:underline flex items-center gap-1"
                      title="Lihat di Google Maps"
                    >
                      {loc.latitude.toFixed(4)}, {loc.longitude.toFixed(4)}
                      <ExternalLink size={10} />
                    </a>
                  </td>
                  <td>
                    <span className="text-sm text-text-primary">{loc.radius_meters}m</span>
                  </td>
                  <td>
                    {loc.is_default ? (
                      <span className="badge badge-success flex items-center gap-1 w-fit">
                        <Star size={10} /> Default
                      </span>
                    ) : (
                      <span className="badge badge-neutral">—</span>
                    )}
                  </td>
                  <td className="text-right">
                    <div className="flex items-center justify-end gap-1">
                      {!loc.is_default && (
                        <>
                          <button
                            onClick={() => handleSetDefault(loc.id, loc.name)}
                            disabled={actionLoading === loc.id}
                            className="p-1.5 rounded-lg hover:bg-primary/10 text-text-secondary hover:text-primary transition-colors"
                            title="Set sebagai default"
                            aria-label="Jadikan lokasi default"
                          >
                            <Star size={14} />
                          </button>
                          <button
                            onClick={() => handleDelete(loc.id, loc.name)}
                            disabled={actionLoading === loc.id}
                            className="p-1.5 rounded-lg hover:bg-danger/10 text-text-secondary hover:text-danger transition-colors"
                            title="Hapus lokasi"
                            aria-label="Hapus lokasi kampus"
                          >
                            <Trash2 size={14} />
                          </button>
                        </>
                      )}
                      {loc.is_default && (
                        <span className="text-[10px] text-text-secondary px-2">
                          Lokasi default tidak bisa dihapus
                        </span>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
