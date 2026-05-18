---
inclusion: manual
description: Boot Android emulator (Pixel_9a) + run mobile app dengan kamera laptop & GPS Politani
---

# /run-emulator — Live Preview MyPresensi Mobile di Laptop

Workflow untuk daily dev tanpa perlu colok HP fisik. Emulator pakai webcam laptop sebagai kamera + GPS bisa di-mock ke koordinat Politani via Extended Controls.

## Prasyarat (sekali setup)

- Android Studio + AVD `Pixel_9a` (API 36, Google Play Store) — sudah ada di laptop
- Webcam laptop berfungsi (cek via Settings → Privacy → Camera)
- File model `mypresensi-mobile/assets/models/mobilefacenet.tflite` sudah di-download (lihat `assets/models/README.md`)
- Dev server web sudah jalan di `http://192.168.x.x:3000` (lihat workflow `/start-dev`)

## Langkah

### 1. Boot emulator dengan webcam attached

```powershell
Start-Process -FilePath "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" `
  -ArgumentList "-avd", "Pixel_9a", `
                "-no-snapshot-load", `
                "-camera-back", "webcam0", `
                "-camera-front", "webcam0" `
  -WindowStyle Normal
```

Tunggu hingga emulator boot complete (~1–2 menit).

// turbo

### 2. Verify emulator detected oleh Flutter

```powershell
flutter devices
```

Harus muncul `sdk gphone64 x86 64` atau similar dengan ID seperti `emulator-5554`.

### 3. Set GPS ke koordinat Politani via Extended Controls

Di emulator window:
1. Klik tombol `...` (Extended Controls) di toolbar kanan emulator
2. Pilih **Location** di sidebar
3. Set:
   - **Latitude**: `-0.5378`
   - **Longitude**: `117.1242`
4. Klik **Send** (atau `Set Location`)

Verify dengan buka Google Maps di emulator → harus zoom ke Politani Samarinda.

### 4. Run mobile app

Dari folder `mypresensi-mobile/`:

```powershell
flutter run -d emulator-5554
```

(Ganti `emulator-5554` dengan device ID dari step 2 jika berbeda.)

Tunggu hingga muncul `Flutter run key commands.` — itu artinya app sudah jalan.

### 5. Hot reload / Hot restart (saat coding)

Di terminal `flutter run`:
- **`r`** = hot reload (apply UI changes, preserve state)
- **`R`** = hot restart (apply non-UI changes, reset state) — wajib setelah ubah `main()`, register interceptor, atau tambah asset
- **`q`** = quit
- **`o`** = toggle platform brightness (test light/dark mode)

### 6. Buka DevTools untuk debug detail

Di terminal yang menjalankan `flutter run`, tekan **`v`**. Browser akan auto-buka ke DevTools dengan:
- **Inspector** — pohon widget
- **Performance** — frame rendering
- **Network** — semua HTTP request (Dio)
- **Logging** — `debugPrint` dengan filter
- **Memory** — heap usage

### 7. Logcat untuk error native (ML Kit, TFLite, GPS)

Di terminal terpisah:

```powershell
adb logcat -s flutter:I MlKitFaceDetection:V tflite:V Geolocator:I
```

Filter ini hanya tampilkan log dari Flutter app + ML Kit + TFLite + Geolocator (tidak banjir log Android system).

## Catatan Penting

- ⚠️ **Mock location di emulator** otomatis di-bypass saat **debug build** (lihat `LocationService.getCurrentPosition()`). Untuk test mock-rejection sebenarnya, harus pakai release build / HP fisik.
- ⚠️ **Emulator first-boot** lebih lama (~3-5 menit) karena init system. Setelahnya cukup ~30-60 detik dari snapshot.
- ⚠️ **Google Play Services** sudah include di Pixel_9a — ML Kit Face Detection akan jalan. Kalau muncul error "Module unavailable", buka **Play Store di emulator** → biarkan auto-update services.
- ⚠️ **Webcam dipakai 2 aplikasi sekaligus** kadang konflik (mis. Zoom + emulator). Tutup app lain yang pakai kamera.
- ⚠️ **Performa lebih lambat dari HP fisik** untuk TFLite inference (~200-500ms vs 50-100ms di HP). Ini normal.

## Troubleshooting

### "No connected devices"
```powershell
adb kill-server
adb start-server
flutter devices
```

### Emulator stuck di boot screen
- Tutup emulator window
- Hapus snapshot: `Get-ChildItem "$env:USERPROFILE\.android\avd\Pixel_9a.avd\snapshots" -Recurse | Remove-Item -Force`
- Boot ulang dengan `-wipe-data` flag (sekali saja, akan reset semua app data)

### App crash saat startup `Unable to load asset: assets/models/mobilefacenet.tflite`
File model belum di-download. Lihat `assets/models/README.md`.

### "Permission denied" untuk kamera/GPS
Di emulator: **Settings → Apps → MyPresensi → Permissions** → enable Camera & Location.
