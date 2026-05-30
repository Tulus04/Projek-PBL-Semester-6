'use client'
// app/components/ui/avatar-upload.tsx
// Komponen reusable untuk upload & crop foto profil.
// Mendukung: klik, drag & drop, dan paste gambar.
// Menggunakan react-easy-crop untuk cropping lingkaran interaktif.

import { useState, useCallback, useRef } from 'react'
import Cropper from 'react-easy-crop'
import type { Area } from 'react-easy-crop'
import { Camera, X, ZoomIn, ZoomOut, Upload } from 'lucide-react'
import { getCroppedImg } from '@/lib/utils/crop-image'
import { swal } from '@/lib/swal'

interface AvatarUploadProps {
  /** URL avatar saat ini (untuk edit mode) */
  defaultImage?: string | null
  /** Nama user untuk fallback inisial */
  name?: string
  /** Ukuran avatar dalam px */
  size?: number
  /** Callback ketika avatar berubah, null = dihapus */
  onCropped: (blob: Blob | null) => void
}

export default function AvatarUpload({
  defaultImage,
  name = '',
  size = 96,
  onCropped,
}: AvatarUploadProps) {
  const [preview, setPreview] = useState<string | null>(defaultImage ?? null)
  const [rawImage, setRawImage] = useState<string | null>(null)
  const [crop, setCrop] = useState({ x: 0, y: 0 })
  const [zoom, setZoom] = useState(1)
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null)
  const [showCropper, setShowCropper] = useState(false)
  const [isDragging, setIsDragging] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const dropZoneRef = useRef<HTMLDivElement>(null)

  const initial = name.charAt(0).toUpperCase() || 'U'

  // ============================================
  // SHARED: Process a file (used by click, drag, paste)
  // ============================================
  const processFile = useCallback((file: File) => {
    // Validate file size (5MB)
    if (file.size > 5 * 1024 * 1024) {
      swal.fire({ icon: 'warning', title: 'File Terlalu Besar', text: 'Ukuran file maksimal 5MB' })
      return
    }

    // Validate file type
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      swal.fire({ icon: 'warning', title: 'Format Tidak Didukung', text: 'Gunakan format JPG, PNG, atau WebP' })
      return
    }

    const reader = new FileReader()
    reader.onload = () => {
      setRawImage(reader.result as string)
      setCrop({ x: 0, y: 0 })
      setZoom(1)
      setShowCropper(true)
    }
    reader.readAsDataURL(file)
  }, [])

  // ============================================
  // Handle file input selection
  // ============================================
  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    processFile(file)
    e.target.value = ''
  }

  // ============================================
  // DRAG & DROP handlers
  // ============================================
  const handleDragEnter = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(true)
  }, [])

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    // Only set false when leaving the drop zone entirely
    const relatedTarget = e.relatedTarget as Node | null
    if (!dropZoneRef.current?.contains(relatedTarget)) {
      setIsDragging(false)
    }
  }, [])

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
  }, [])

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)

    const files = e.dataTransfer?.files
    if (files && files.length > 0) {
      const file = files[0]
      if (file.type.startsWith('image/')) {
        processFile(file)
      } else {
        swal.fire({ icon: 'warning', title: 'Bukan File Gambar', text: 'Gunakan format JPG, PNG, atau WebP.' })
      }
    }
  }, [processFile])

  // ============================================
  // Handle crop complete
  // ============================================
  const onCropComplete = useCallback((_: Area, croppedPixels: Area) => {
    setCroppedAreaPixels(croppedPixels)
  }, [])

  // Simpan hasil crop
  const handleSaveCrop = async () => {
    if (!rawImage || !croppedAreaPixels) return

    try {
      const croppedBlob = await getCroppedImg(rawImage, croppedAreaPixels)
      const previewUrl = URL.createObjectURL(croppedBlob)
      setPreview(previewUrl)
      onCropped(croppedBlob)
      setShowCropper(false)
      setRawImage(null)
    } catch (err) {
      console.error('Gagal crop gambar:', err)
      swal.fire({ icon: 'error', title: 'Gagal Memproses', text: 'Gagal memproses gambar. Coba gambar lain.' })
    }
  }

  // Batal crop
  const handleCancelCrop = () => {
    setShowCropper(false)
    setRawImage(null)
  }

  // Hapus avatar
  const handleRemove = () => {
    setPreview(null)
    onCropped(null)
  }

  return (
    <>
      {/* Avatar Display — Drop Zone */}
      <div className="flex flex-col items-center gap-2">
        <div
          ref={dropZoneRef}
          className={`relative group cursor-pointer transition-all duration-200 ${
            isDragging
              ? 'scale-110'
              : ''
          }`}
          onClick={() => fileInputRef.current?.click()}
          onDragEnter={handleDragEnter}
          onDragLeave={handleDragLeave}
          onDragOver={handleDragOver}
          onDrop={handleDrop}
          style={{ width: size, height: size }}
        >
          {/* Avatar image or initial */}
          {preview ? (
            // eslint-disable-next-line @next/next/no-img-element -- preview adalah blob URL/base64 dari upload user, next/image tidak support
            <img
              src={preview}
              alt="Foto profil"
              className={`w-full h-full rounded-full object-cover border-2 transition-colors ${
                isDragging ? 'border-primary border-dashed' : 'border-gray-200'
              }`}
            />
          ) : (
            <div
              className={`w-full h-full rounded-full flex items-center justify-center text-white font-bold border-2 border-dashed transition-all ${
                isDragging
                  ? 'border-primary bg-primary/20 text-primary'
                  : 'border-gray-300 bg-primary'
              }`}
              style={{ fontSize: size * 0.35 }}
            >
              {isDragging ? (
                <Upload size={size * 0.3} className="text-primary animate-bounce" />
              ) : (
                initial
              )}
            </div>
          )}

          {/* Hover overlay (hidden during drag) */}
          {!isDragging && (
            <div className="absolute inset-0 rounded-full bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
              <Camera size={size * 0.25} className="text-white" />
            </div>
          )}

          {/* Drag overlay */}
          {isDragging && (
            <div className="absolute inset-0 rounded-full bg-primary/20 border-2 border-dashed border-primary flex items-center justify-center animate-pulse">
              <Upload size={size * 0.25} className="text-primary" />
            </div>
          )}

          {/* Remove button */}
          {preview && preview !== defaultImage && !isDragging && (
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation()
                handleRemove()
              }}
              className="absolute -top-1 -right-1 w-6 h-6 bg-danger text-white rounded-full flex items-center justify-center hover:opacity-90 transition-opacity shadow-md"
            >
              <X size={12} />
            </button>
          )}
        </div>

        <p className="text-xs text-text-secondary text-center">
          {isDragging ? (
            <span className="text-primary font-medium">Lepaskan untuk upload</span>
          ) : (
            'Klik atau drag & drop foto'
          )}
        </p>

        {/* Hidden file input */}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          className="hidden"
          onChange={handleFileSelect}
        />
      </div>

      {/* Crop Modal */}
      {showCropper && rawImage && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center">
          <div className="fixed inset-0 bg-black/60" onClick={handleCancelCrop} />
          <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 z-[71] overflow-hidden">
            {/* Header */}
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100">
              <h3 className="text-base font-semibold text-text-primary">
                Crop Foto Profil
              </h3>
              <button
                type="button"
                onClick={handleCancelCrop}
                className="p-1 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <X size={18} className="text-text-secondary" />
              </button>
            </div>

            {/* Crop Canvas */}
            <div className="relative w-full" style={{ height: 320 }}>
              <Cropper
                image={rawImage}
                crop={crop}
                zoom={zoom}
                aspect={1}
                cropShape="round"
                showGrid={false}
                onCropChange={setCrop}
                onCropComplete={onCropComplete}
                onZoomChange={setZoom}
              />
            </div>

            {/* Zoom Slider */}
            <div className="px-5 py-3 flex items-center gap-3 bg-gray-50">
              <ZoomOut size={16} className="text-text-secondary flex-shrink-0" />
              <input
                type="range"
                min={1}
                max={3}
                step={0.05}
                value={zoom}
                onChange={(e) => setZoom(Number(e.target.value))}
                className="flex-1 h-1.5 bg-gray-200 rounded-full appearance-none cursor-pointer
                  [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:h-4
                  [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-primary [&::-webkit-slider-thumb]:cursor-pointer
                  [&::-webkit-slider-thumb]:shadow-md"
              />
              <ZoomIn size={16} className="text-text-secondary flex-shrink-0" />
            </div>

            {/* Actions */}
            <div className="flex gap-3 justify-end px-5 py-4 border-t border-gray-100">
              <button
                type="button"
                onClick={handleCancelCrop}
                className="btn-secondary text-sm py-2.5 px-4"
              >
                Batal
              </button>
              <button
                type="button"
                onClick={handleSaveCrop}
                className="btn-primary"
              >
                Simpan Crop
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
