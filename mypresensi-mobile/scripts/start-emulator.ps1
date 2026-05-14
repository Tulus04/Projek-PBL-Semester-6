# mypresensi-mobile/scripts/start-emulator.ps1
# Helper untuk boot Android emulator Pixel_9a dengan webcam laptop sebagai kamera virtual.
# Usage: .\scripts\start-emulator.ps1

$ErrorActionPreference = "Stop"

$EmulatorPath = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"
$AvdName = "Pixel_9a"

if (-not (Test-Path $EmulatorPath)) {
    Write-Host "❌ Emulator binary tidak ditemukan di: $EmulatorPath" -ForegroundColor Red
    Write-Host "   Pastikan Android SDK terinstall di lokasi default." -ForegroundColor Yellow
    exit 1
}

# Cek AVD ada
$avdList = & $EmulatorPath -list-avds
if ($avdList -notcontains $AvdName) {
    Write-Host "❌ AVD '$AvdName' tidak ditemukan." -ForegroundColor Red
    Write-Host "   AVD yang tersedia:" -ForegroundColor Yellow
    $avdList | ForEach-Object { Write-Host "     - $_" -ForegroundColor Cyan }
    Write-Host ""
    Write-Host "   Buat AVD Pixel_9a via Android Studio → Device Manager → Create Device" -ForegroundColor Yellow
    exit 1
}

# Cek apakah emulator sudah jalan
$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (Test-Path $adbPath) {
    $running = & $adbPath devices | Select-String -Pattern "emulator-\d+\s+device"
    if ($running) {
        Write-Host "ℹ️  Emulator sudah jalan: $running" -ForegroundColor Green
        Write-Host "   Skip boot. Lanjut ke 'flutter run -d emulator-XXXX'" -ForegroundColor Cyan
        exit 0
    }
}

Write-Host "🚀 Booting emulator $AvdName..." -ForegroundColor Cyan
Write-Host "   Webcam laptop akan dipakai sebagai virtual camera (front + back)" -ForegroundColor Gray
Write-Host "   Ini memungkinkan test face recognition tanpa HP fisik" -ForegroundColor Gray
Write-Host ""

Start-Process -FilePath $EmulatorPath `
    -ArgumentList "-avd", $AvdName, `
                  "-no-snapshot-load", `
                  "-camera-back", "webcam0", `
                  "-camera-front", "webcam0" `
    -WindowStyle Normal

Write-Host "✅ Emulator dilaunch (window terpisah)" -ForegroundColor Green
Write-Host ""
Write-Host "Tunggu hingga emulator boot complete (~1-2 menit), lalu jalankan:" -ForegroundColor Yellow
Write-Host "  flutter devices                  # cek device ID" -ForegroundColor White
Write-Host "  flutter run -d emulator-5554     # jalankan app" -ForegroundColor White
Write-Host ""
Write-Host "Set GPS ke Politani via Extended Controls (...) → Location:" -ForegroundColor Yellow
Write-Host "  Latitude:  -0.5378" -ForegroundColor White
Write-Host "  Longitude: 117.1242" -ForegroundColor White
