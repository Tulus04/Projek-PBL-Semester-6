# tool/run-with-lan-ip.ps1
# Auto-detect IP Wi-Fi laptop, inject ke flutter run via --dart-define.
# Hindari edit _lanIp di app_config.dart setiap kali DHCP renew.
#
# Pakai dari folder mypresensi-mobile/:
#   .\tool\run-with-lan-ip.ps1
#
# Optional: pilih device tertentu
#   .\tool\run-with-lan-ip.ps1 -Device RMX5000
#
# Optional: build saja (tanpa run)
#   .\tool\run-with-lan-ip.ps1 -BuildOnly
#
# Behavior:
# - Cari IPv4 dari interface "Wi-Fi*" yang aktif (PrefixOrigin=Dhcp atau Manual).
# - Tampilkan IP yang di-detect + URL backend.
# - Run flutter dengan --dart-define=API_BASE_URL=http://<ip>:3000.
#
# Catatan: backend Next.js (npm run dev di mypresensi-web/) HARUS sudah running
# sebelum script ini dijalankan. Script ini hanya inject IP ke mobile.

[CmdletBinding()]
param(
    [string]$Device = '',
    [int]$Port = 3000,
    [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'

# ============================================================
# 1. Detect IP Wi-Fi laptop
# ============================================================
Write-Host '=== MyPresensi Mobile — Run with LAN IP ===' -ForegroundColor Cyan

$wifi = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*' -ErrorAction SilentlyContinue |
    Where-Object { $_.PrefixOrigin -in @('Dhcp', 'Manual') -and $_.IPAddress -notlike '169.*' } |
    Select-Object -First 1

if (-not $wifi) {
    Write-Host '[ERROR] Wi-Fi adapter tidak aktif atau tidak punya IP valid.' -ForegroundColor Red
    Write-Host 'Connect ke Wi-Fi dulu, lalu jalankan ulang script ini.' -ForegroundColor Yellow
    exit 1
}

$ip = $wifi.IPAddress
$baseUrl = "http://${ip}:$Port"

Write-Host "[OK] Wi-Fi IP detected   : $ip" -ForegroundColor Green
Write-Host "[OK] Backend URL inject  : $baseUrl" -ForegroundColor Green

# ============================================================
# 2. Verify backend reachable (optional sanity check)
# ============================================================
Write-Host ''
Write-Host '=== Cek backend reachable ===' -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    Write-Host "[OK] Backend HTTP $($response.StatusCode) di $baseUrl" -ForegroundColor Green
}
catch {
    Write-Host "[WARNING] Backend tidak reachable di $baseUrl" -ForegroundColor Yellow
    Write-Host '         Pastikan npm run dev jalan di mypresensi-web/' -ForegroundColor Yellow
    Write-Host '         Lanjut tetap run app — connect timeout akan muncul saat login.' -ForegroundColor Yellow
}

# ============================================================
# 3. Build Flutter command
# ============================================================
Write-Host ''
Write-Host '=== Run Flutter ===' -ForegroundColor Cyan

$flutterArgs = @()
if ($BuildOnly) {
    $flutterArgs += 'build'
    $flutterArgs += 'apk'
    $flutterArgs += '--debug'
}
else {
    $flutterArgs += 'run'
}

$flutterArgs += "--dart-define=API_BASE_URL=$baseUrl"

if ($Device) {
    $flutterArgs += '-d'
    $flutterArgs += $Device
}

Write-Host "Command: flutter $($flutterArgs -join ' ')" -ForegroundColor Gray
Write-Host ''

& flutter @flutterArgs
