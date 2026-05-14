# Model File — `mobilefacenet.tflite`

File ini **WAJIB ada** di folder `assets/models/` agar fitur Face Recognition bekerja.

File model TIDAK di-commit ke Git (terlalu besar — ~5 MB) dan harus di-download manual sekali setelah clone repo.

## Spesifikasi Model

| Field | Nilai |
|-------|-------|
| **Arsitektur** | MobileFaceNet |
| **Input shape** | `[1, 112, 112, 3]` — RGB float32 |
| **Input range** | `[-1.0, 1.0]` (normalized: `(pixel - 127.5) / 128.0`) |
| **Output shape** | `[1, 192]` — float32 embedding vector |
| **Threshold reliable** | `~0.65` cosine similarity |
| **Ukuran file** | ~5 MB |

## Cara Download (3 cara, pilih salah satu)

### Opsi 1 — Direct download (paling cepat)

Buka URL ini di browser, klik **Download raw file**, simpan sebagai `mobilefacenet.tflite` di folder ini:

```
https://github.com/MCarlomagno/FaceRecognitionAuth/raw/master/assets/mobilefacenet.tflite
```

Atau pakai PowerShell:

```powershell
curl.exe -L -o "assets/models/mobilefacenet.tflite" "https://github.com/MCarlomagno/FaceRecognitionAuth/raw/master/assets/mobilefacenet.tflite"
```

(jalankan dari folder `mypresensi-mobile/`)

### Opsi 2 — Sirius-AI repo (model resmi, perlu konversi sendiri)

Source code training: <https://github.com/sirius-ai/MobileFaceNet_TF>

Konversi `.pb` → `.tflite` pakai `tflite_convert` CLI. Hanya gunakan jika Anda tahu apa yang dilakukan.

### Opsi 3 — Train sendiri

Pakai dataset CASIA-WebFace atau MS-Celeb-1M. Training butuh GPU + waktu hari-hari. **Tidak disarankan untuk PBL**.

## Verifikasi setelah download

File hash SHA-256 yang valid (untuk URL Opsi 1):

```
SHA-256: 4ef6e1e60f7de58d9a9bdb27b40a46a18cb88d9ebde4ec6bc04fb22e1d1b1fc1
```

(catatan: hash bisa berbeda jika maintainer repo update file. Yang penting model bisa di-load tanpa error & output 192 dimensi.)

## Setelah Download

1. Pastikan file ada di `mypresensi-mobile/assets/models/mobilefacenet.tflite`.
2. Jalankan `flutter pub get` (sekali, untuk register asset).
3. Hot **restart** (bukan hot reload) agar asset di-load ulang.
4. Test registrasi wajah → `[FACE EMBED] Model loaded: ...` muncul di log.

## Troubleshooting

- **`Unable to load asset`** → cek `pubspec.yaml` punya `- assets/models/` di section `flutter.assets`. Hot restart, bukan reload.
- **Output bukan 192-d** → file korup atau bukan MobileFaceNet. Re-download.
- **Inference lambat (>500ms)** → resolution kamera mungkin terlalu tinggi. Set `ResolutionPreset.medium` atau `high` (jangan `veryHigh`).

## Lisensi Model

Model dari MCarlomagno/FaceRecognitionAuth dirilis di bawah MIT License (cek README repo asli). Untuk produksi/komersial, periksa lisensi training dataset yang dipakai (CASIA-WebFace memiliki restriksi non-komersial).
