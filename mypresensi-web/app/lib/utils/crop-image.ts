// app/lib/utils/crop-image.ts
// Utility untuk mengcrop gambar menggunakan Canvas API.
// Mengambil output croppedAreaPixels dari react-easy-crop
// dan menghasilkan Blob JPEG yang siap upload.

interface PixelCrop {
  x: number
  y: number
  width: number
  height: number
}

/**
 * Membuat Image element dari URL.
 */
function createImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image()
    image.addEventListener('load', () => resolve(image))
    image.addEventListener('error', (error) => reject(error))
    image.setAttribute('crossOrigin', 'anonymous')
    image.src = url
  })
}

/**
 * Mengcrop gambar menggunakan Canvas API.
 * Output: Blob JPEG dengan ukuran max 400x400px.
 */
export async function getCroppedImg(
  imageSrc: string,
  pixelCrop: PixelCrop,
  maxSize = 400
): Promise<Blob> {
  const image = await createImage(imageSrc)
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')

  if (!ctx) throw new Error('Canvas 2D context tidak tersedia')

  // Tentukan ukuran output (max 400x400, keep aspect ratio)
  const outputSize = Math.min(pixelCrop.width, pixelCrop.height, maxSize)
  canvas.width = outputSize
  canvas.height = outputSize

  // Gambar bagian yang dicrop ke canvas
  ctx.drawImage(
    image,
    pixelCrop.x,
    pixelCrop.y,
    pixelCrop.width,
    pixelCrop.height,
    0,
    0,
    outputSize,
    outputSize
  )

  // Export ke Blob JPEG
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (blob) resolve(blob)
        else reject(new Error('Gagal membuat blob dari canvas'))
      },
      'image/jpeg',
      0.85
    )
  })
}
