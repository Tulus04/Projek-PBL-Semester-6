---
description: Menyalakan dev environment MyPresensi (web Next.js + mobile Flutter) dan memastikan koneksi mobile↔web bekerja.
---

# Start Dev Environment

Workflow untuk menyalakan stack lengkap dan memverifikasi mahasiswa di HP fisik bisa request ke API web yang berjalan di laptop.

## 1. Pastikan `.env.local` web sudah terisi

Cek `mypresensi-web/.env.local`. Harus ada 3 nilai non-placeholder:

```
NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

Jika masih `your_..._here` → middleware akan bypass auth (mode dev) dan login tidak akan jalan.

## 2. Start dev server Next.js

```powershell
npm run dev
```

cwd: `mypresensi-web`. Tunggu hingga muncul `Ready in ...ms` dan listen di `http://localhost:3000`.

// turbo
```powershell
npm run type-check
```

cwd: `mypresensi-web` — opsional, untuk memastikan build hijau sebelum mulai ngoding.

## 3. (Hanya jika pakai HP fisik) Update LAN IP

Cek IP laptop:

// turbo
```powershell
ipconfig | Select-String "IPv4"
```

Jika berbeda dari `_lanIp` di `mypresensi-mobile/lib/core/config/app_config.dart`, ganti konstanta tersebut. Pastikan firewall Windows mengizinkan port 3000 untuk **Private network**.

## 4. Start app Flutter

```powershell
flutter pub get
```

cwd: `mypresensi-mobile`.

```powershell
flutter run
```

cwd: `mypresensi-mobile`. Pilih device (emulator atau HP fisik). Saat startup, console akan print:

```
═══════════════════════════════════════
📱 Device: ...
🤖 Physical device: true/false
🌐 Base URL: http://...:3000
═══════════════════════════════════════
```

Pastikan `Base URL` benar:
- Emulator → `http://10.0.2.2:3000`
- HP fisik → `http://192.168.x.x:3000` (IP laptop)

## 5. Smoke test

1. Buka `http://localhost:3000` di browser laptop → halaman login muncul.
2. Login dengan akun admin dari `mypresensi-web/.dev-accounts.md` (file lokal, gitignored). Kalau belum ada, ikuti `credentials-MUSTREAD.txt` atau buat manual via Supabase Dashboard → Authentication → Users.
3. Di mobile, login dengan akun mahasiswa (default password: `<NIM>@politani`).
4. Kalau muncul "Tidak dapat terhubung ke server" di mobile → cek langkah 3 + firewall.

## 6. Override baseUrl tanpa edit kode (opsional)

Untuk testing cepat dengan IP berbeda:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.5.10:3000
```

cwd: `mypresensi-mobile`.

## 7. Stop

- Web: `Ctrl+C` di terminal `npm run dev`.
- Mobile: `q` di terminal `flutter run`, atau tutup emulator.
