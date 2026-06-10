<#
    PERF_CHECK.ps1  -  Diagnostik performa laptop (READ-ONLY, AMAN)
    Tidak mengubah APAPUN. Hanya membaca & menampilkan kondisi laptop
    supaya keputusan optimasi berdasar DATA, bukan tebakan.

    Target: Lenovo 82SB / Ryzen 5 7535HS / 16GB / dual NVMe SSD.
    Kompatibel PowerShell 5.1 (murni ASCII). Tidak butuh admin.
#>

Write-Host ""
Write-Host "=== DIAGNOSTIK PERFORMA (read-only) ===" -ForegroundColor Cyan
Write-Host ""

# --- 1. RAM ---
$os   = Get-CimInstance Win32_OperatingSystem
$totGB  = [math]::Round($os.TotalVisibleMemorySize/1MB,1)
$freeGB = [math]::Round($os.FreePhysicalMemory/1MB,1)
$usedPct = [math]::Round((($totGB-$freeGB)/$totGB)*100)
Write-Host "[RAM]" -ForegroundColor Yellow
Write-Host ("  Total: {0} GB | Bebas: {1} GB | Terpakai: {2}%" -f $totGB,$freeGB,$usedPct)
if ($usedPct -ge 80) {
    Write-Host "  -> RAM ketat. Tutup app yang tidak dipakai (lihat daftar di bawah)." -ForegroundColor Red
} else {
    Write-Host "  -> RAM sehat." -ForegroundColor Green
}

# Memory Compression = indikator tekanan RAM
$mc = Get-Process -Name "Memory Compression" -EA SilentlyContinue
if ($mc) {
    $mcMB = [math]::Round($mc.WorkingSet64/1MB)
    Write-Host ("  Memory Compression: {0} MB" -f $mcMB)
    if ($mcMB -gt 500) {
        Write-Host "  -> Tinggi. Windows mengompres RAM karena penuh = sinyal kurang RAM bebas." -ForegroundColor Red
    }
}
Write-Host ""

# --- 2. Top proses pemakan RAM ---
Write-Host "[10 PROSES PALING RAKUS RAM]" -ForegroundColor Yellow
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 `
    @{N='Aplikasi';E={$_.Name}}, @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB)}} |
    Format-Table -AutoSize
Write-Host ""

# --- 3. Disk ---
Write-Host "[DISK]" -ForegroundColor Yellow
Get-PhysicalDisk | ForEach-Object {
    Write-Host ("  {0} - {1} ({2})" -f $_.FriendlyName, $_.MediaType, $_.BusType)
}
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object {
    $freeG = [math]::Round($_.Free/1GB,1); $usedG = [math]::Round($_.Used/1GB,1); $tot = $freeG+$usedG
    if ($tot -gt 0) {
        $pctFree = [math]::Round(($freeG/$tot)*100)
        $flag = if ($pctFree -lt 10) { " <- HAMPIR PENUH, bisa lambatkan sistem" } else { "" }
        Write-Host ("  Drive {0}: bebas {1} GB dari {2} GB ({3}% bebas){4}" -f $_.Name,$freeG,$tot,$pctFree,$flag)
    }
}
Write-Host ""

# --- 4. Power plan ---
Write-Host "[POWER PLAN]" -ForegroundColor Yellow
$act = (powercfg /getactivescheme)
Write-Host ("  " + $act)
Write-Host "  Tips: saat ngoding & dicolok charger, set Windows ke 'Best performance'"
Write-Host "  via Settings > System > Power, atau Lenovo Vantage (Fn+Q)."
Write-Host ""

# --- 5. Startup apps ---
Write-Host "[STARTUP APPS - yang auto-buka saat boot]" -ForegroundColor Yellow
Get-CimInstance Win32_StartupCommand | Select-Object @{N='Aplikasi';E={$_.Name}}, @{N='Lokasi';E={$_.Location}} | Format-Table -AutoSize
Write-Host "  Tips: matikan app berat (Steam/Discord/Spotify) via Task Manager > Startup apps."
Write-Host ""

Write-Host "=== SELESAI - tidak ada yang diubah ===" -ForegroundColor Cyan
Read-Host "Tekan Enter untuk keluar"
