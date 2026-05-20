# Tool — MyPresensi Mobile

Helper script untuk dev workflow. Tidak masuk APK production.

## `run-with-lan-ip.ps1`

Auto-detect IP Wi-Fi laptop, inject ke `flutter run` via `--dart-define=API_BASE_URL=...`. Solve masalah DHCP renew IP berubah — tidak perlu edit `lib/core/config/app_config.dart` manual setiap kali Wi-Fi reconnect.

### Pakai

Dari folder `mypresensi-mobile/`:

```powershell
.\tool\run-with-lan-ip.ps1
```

Output contoh:

```
=== MyPresensi Mobile — Run with LAN IP ===
[OK] Wi-Fi IP detected   : 10.10.0.76
[OK] Backend URL inject  : http://10.10.0.76:3000

=== Cek backend reachable ===
[OK] Backend HTTP 200 di http://10.10.0.76:3000

=== Run Flutter ===
Command: flutter run --dart-define=API_BASE_URL=http://10.10.0.76:3000

Launching lib\main.dart on RMX5000 in debug mode...
...
```

### Parameter

| Flag | Default | Fungsi |
|------|---------|--------|
| `-Device <id>` | (auto) | Pilih device specific kalau ada multiple |
| `-Port <n>` | `3000` | Port backend Next.js |
| `-BuildOnly` | (off) | Build APK debug saja, tidak run |

### Contoh

Run di emulator RMX5000:

```powershell
.\tool\run-with-lan-ip.ps1 -Device RMX5000
```

Build APK debug dengan IP injected (untuk install manual via adb):

```powershell
.\tool\run-with-lan-ip.ps1 -BuildOnly
```

### Prerequisites

1. Backend Next.js jalan: `cd mypresensi-web && npm run dev`
2. HP & laptop di Wi-Fi yang sama
3. Wi-Fi adapter laptop aktif

### Kapan TIDAK Perlu Pakai Script Ini

- Test di emulator Android Studio → URL fix `10.0.2.2:3000`, tidak perlu inject.
- Develop di iOS simulator / desktop → URL fix `localhost:3000`.

Auto-detect di `AppConfig.baseUrl` cover kasus emulator + desktop. Script ini hanya untuk **HP fisik di LAN dev**.

### Production / Release Build

JANGAN pakai script ini untuk release build production. Production URL harus pakai HTTPS public domain via `--dart-define` saat build:

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.mypresensi.example.com `
  --obfuscate `
  --split-debug-info=build/symbols
```
