---
inclusion: always
description: Prinsip desain UI MyPresensi (formal Corporate/SaaS, 3-state wajib, Bahasa Indonesia) + library yang dikunci dan tidak boleh diganti tanpa persetujuan user.
---

# Design Principles & Library Lock — MyPresensi

## A. Prinsip Desain UI

### Filosofi
1. **Formal, bersih, profesional — gaya Corporate/SaaS.** UI TIDAK BOLEH terlihat AI-generated:
   - Tanpa emoji acak di dalam UI (boleh di chat/log, tidak di komponen).
   - Tanpa gradient warna tidak jelas.
   - Tanpa tombol warna-warni mencolok yang tidak konsisten.
2. **Konsisten** — reuse komponen yang sudah ada (`.card`, `.btn-primary`, `.summary-card`, `.data-table`, `.badge-success/warning/danger`, `.input-field`, `.skeleton`, `.sidebar-nav-item`). REUSE dulu sebelum bikin baru.

### Bahasa
- **Semua label, placeholder, judul halaman, pesan error di UI** → Bahasa Indonesia.
- **Nama variabel, function, komentar teknis** → Inggris.
- Pesan ramah, bukan teknis: `"Sesi berakhir, silakan login ulang"` BUKAN `"401 Unauthorized"`.

### UX Copy Guidelines (Pesan User-Facing)

Pesan validasi & error harus **ringkas dan match dengan UI capability**. Pelajaran dari sesi 2026-05-23 — banyak pesan validasi terlalu verbose dan menyebut konsep teknis yang user tidak kenal.

#### Iron Laws

1. **Ringkas — 2-5 kata** untuk inline error / snackbar. Real apps Indonesia (Tokopedia, GoJek, BCA Mobile) pakai pola ini. JANGAN tulis kalimat panjang dengan "silakan...", "pastikan...", "mohon...".

   ```
   ❌ 'QR tidak valid. Pastikan Anda memindai QR presensi yang ditampilkan dosen.'
   ✅ 'QR tidak valid'

   ❌ 'Verifikasi wajah dibatalkan. Coba lagi dengan pencahayaan yang lebih baik.'
   ✅ 'Wajah tidak terdeteksi'  (atau hapus kalau user yang cancel)

   ❌ 'Kode sesi sudah kedaluwarsa. Minta dosen untuk refresh kode.'
   ✅ 'QR sudah kedaluwarsa'
   ```

2. **JANGAN sebut konsep internal** yang user tidak kenal. Mahasiswa MyPresensi cuma tahu **scan QR** + **verify wajah** + **submit presensi** — itu saja yang boleh disebut di pesan UI.

   | JANGAN sebut (internal) | Pakai ini (user-facing) |
   |-------------------------|------------------------|
   | "OTP", "kode 6 digit", "kode sesi" | **"QR"** |
   | "session_id", "session_code", "UUID" | **"QR"** atau **"sesi"** |
   | "embedding", "cosine similarity", "192-d" | **"wajah"** |
   | "Bearer token", "JWT", "401 Unauthorized" | **"Sesi login berakhir"** |
   | "RLS", "mock GPS detected", "is_mock_location" | **"Lokasi tidak valid"** |
   | "format embedding tidak valid" | **"Wajah tidak terdeteksi"** |

   Alasan: di MyPresensi mobile, user **TIDAK PERNAH** input kode 6 digit secara manual (tidak ada UI input). Mereka hanya scan QR. Maka pesan tidak boleh sebut "kode" — itu menyesatkan dan bikin bingung.

3. **Pesan harus match dengan recovery action yang TERSEDIA di UI**. Jangan sarankan user lakukan sesuatu yang UI tidak support.

   ```
   ❌ 'Kode tidak valid, silakan minta kode baru ke dosen'
      → User tidak bisa "memasukkan kode" karena tidak ada input field
   ✅ 'QR tidak valid'  (user tinggal scan ulang)
   ```

4. **Cancel ≠ Error**. Kalau user yang cancel/batal sendiri (mis. tap "Tutup" di face-verify), JANGAN tampilkan snackbar merah — itu bikin user merasa "salah" padahal niat mereka memang cancel. Silent recovery saja.

5. **Pattern Subject + State** untuk validation field:
   - `'Email salah'` ✅
   - `'Password tidak cocok'` ✅
   - `'NIM minimal 5 karakter'` ✅
   - `'QR tidak valid'` ✅

6. **Kalau perlu CTA**, taruh di **tombol terpisah**, bukan dalam pesan teks.
   ```
   ❌ Snackbar: 'Sesi habis, silakan login ulang dengan menekan tombol di bawah'
   ✅ Snackbar: 'Sesi berakhir' + tombol "Login Ulang" terpisah
   ```

#### Sources of Truth — Konsep User-Facing MyPresensi

Saat menulis pesan baru, gunakan kosa kata berikut sebagai **kamus user**. Konsep di luar daftar ini = internal, jangan masuk pesan UI.

| Konsep | Istilah Mobile (mahasiswa) | Istilah Web (admin/dosen) |
|--------|---------------------------|---------------------------|
| QR untuk presensi | "QR" | "QR" |
| Verifikasi wajah | "wajah", "verifikasi wajah" | "verifikasi wajah" |
| Sesi presensi yang sedang berjalan | "sesi", "kelas" | "sesi" |
| GPS / lokasi | "lokasi" | "lokasi" |
| Akun login | "akun" | "akun" |
| Submit presensi | "presensi" | "presensi" / "absensi" |
| Permintaan izin/sakit | "izin", "sakit" | "izin", "sakit" |

### Warna — Pakai Design Token
Pakai variabel CSS dari `app/globals.css`. JANGAN warna hardcode acak.

| Token | Nilai | Pakai untuk |
|-------|-------|-------------|
| `--color-primary` | `#5483AD` (Biru Baja TRPL) | Tombol primary, link aktif, brand |
| `--color-success` | `#1A7F37` | Badge "Hadir", "Aktif" |
| `--color-warning` | `#9A6700` | Badge "Izin/Sakit", "Pending" |
| `--color-danger` | `#CF222E` | Badge "Alpa", "Nonaktif", error |

Mobile pakai `AppColors` & design token dari `lib/core/theme/`. JANGAN hardcode warna di widget.

### Struktur Halaman
1. **Setiap halaman WAJIB punya header**: icon (Lucide) + page-title + page-subtitle.
2. **Setiap tabel** pakai class `.data-table` dengan kolom konsisten + badge status berwarna.
3. **Responsive** — grid layout menyesuaikan mobile & desktop.
4. **Mobile (Flutter)** ikut Material Design 3 dengan custom theme. Setiap screen WAJIB ada AppBar atau identitas halaman jelas.

### 3-State UI — WAJIB di Setiap Screen
Tidak ada halaman boleh "kosong tanpa konteks". Wajib handle 3 state:

| State | Web | Mobile |
|-------|-----|--------|
| **Loading** | `.skeleton` shimmer | `Shimmer` dari package `shimmer` atau `CircularProgressIndicator` dengan styling — BUKAN halaman kosong |
| **Empty** | Pesan informatif Indonesia + CTA (tombol/link). Jelaskan **kenapa kosong** & **apa langkah berikutnya**. Contoh: `"Belum ada sesi hari ini. Buat sesi baru →"` | Sama, pakai `EmptyState` widget custom |
| **Error** | Pesan user-friendly + tombol retry. JANGAN tampilkan stack trace ke user | Sama, pakai `ErrorState` widget |

### Micro-Interaction
- Animasi halus 200-400ms untuk transisi antar halaman, loading state, feedback interaksi.
- Hindari transisi abrupt atau halaman yang langsung muncul tanpa animasi.
- Web: pakai CSS transition / Framer Motion (jika dipakai konsisten).
- Mobile: pakai `AnimatedSwitcher`, `FadeTransition`, `SlideTransition`. GoRouter pakai transition helper yang sudah ada (`_fadeTransition`, `_slideTransition`, `_fadeScaleTransition`).

### Navigasi — Tidak Boleh Dead-End
1. User selalu tahu di mana mereka berada (breadcrumb / page header / aktif state sidebar).
2. User selalu bisa kembali ke halaman sebelumnya.
3. User tidak pernah ketemu halaman tanpa aksi/kelanjutan.
4. Jika halaman kosong → WAJIB ada tombol/link mengarahkan ke langkah produktif berikutnya.

### Pola UI yang Sudah Disepakati MyPresensi
- **Konfirmasi destruktif**: SweetAlert2 (`@/lib/swal`) atau custom modal — **JANGAN** `window.confirm()` (BUG-008: blocking React lifecycle, bisa bikin server action `net::ERR_ABORTED`).
- **Dropdown 3-titik di tabel**: pakai *fixed positioning* di luar container scroll/overflow (BUG-007: `overflow-hidden` parent meng-clip).
- **Loading state**: skeleton atau Lucide spinner — JANGAN teks "Loading...".
- **Empty state**: kalimat ramah Indonesia, contoh "Belum ada absensi hari ini."
- **Toast**: `toast.fire({ icon, title })` dari `@/lib/swal`.
- **State machine async**: enum `idle → loading → success/error` (web actions return `{ error, success }`, mobile pakai state class immutable + `copyWith`).

## B. Library yang Dikunci

Library berikut WAJIB dipakai dan **TIDAK BOLEH diganti tanpa persetujuan user**. Kalau ada kebutuhan yang library lock-nya tidak cover, **diskusikan dulu** sebelum tambah dependency.

### Web (`mypresensi-web/`)

| Kebutuhan | Library WAJIB | Alasan kenapa di-lock |
|-----------|---------------|----------------------|
| Toast, konfirmasi, input dialog | **SweetAlert2** via `@/lib/swal` | UX konsisten, sudah di-style sesuai design token, hindari `window.confirm()` bug |
| Validasi input server action / API | **Zod** (`zod ^3.23.8`) | Schema declarative, error message Indonesia mudah, type inference otomatis |
| Ikon | **Lucide React** (`lucide-react`) | Ringan, tree-shakeable, style konsisten. JANGAN emoji atau icon library lain |
| Grafik & chart | **Recharts** (`recharts ^3.8.1`) | React-native, design konsisten. JANGAN Chart.js / ApexCharts |
| CSV parse/generate | **PapaParse** (`papaparse ^5.5.3`) | Battle-tested, handle edge case CSV |
| PDF generate | **jsPDF + jspdf-autotable** | Sudah dipakai di export rekap |
| Crop avatar | **react-easy-crop** | Sudah dipakai di profil |
| QR display | **qrcode.react** | React-native, ringan |
| Class name merge | **clsx + tailwind-merge** | Standar `cn()` utility |
| Auth & DB | **@supabase/ssr + @supabase/supabase-js** | Cookie-based SSR session |
| State form | **`useFormState` + `useFormStatus` dari `react-dom`** | React 18 compatible (BUKAN React 19 `useActionState`) |

### Mobile (`mypresensi-mobile/`)

**Yang SUDAH dipakai & di-lock** (jangan ganti tanpa diskusi):

| Kebutuhan | Library WAJIB | Catatan |
|-----------|---------------|---------|
| State management | **flutter_riverpod ^3.3.1** + **riverpod ^3.2.1** | Konsisten di seluruh app |
| HTTP | **dio ^5.9.2** | Interceptor untuk auth + 401 auto-logout |
| Routing | **go_router ^17.2.0** | Pakai `refreshListenable`, JANGAN MaterialPageRoute mendadak |
| Secure storage | **flutter_secure_storage ^10.0.0** | JANGAN `shared_preferences` untuk token/secret |
| QR scan | **mobile_scanner ^7.2.0** | minSdk 26 |
| Face detection | **google_mlkit_face_detection ^0.13.2** | ML Kit landmark + bbox + liveness |
| Face embedding | **tflite_flutter ^0.12.1** + **image ^4.8.0** | MobileFaceNet inference. JANGAN `tflite_flutter_helper` (deprecated) |
| Kamera | **camera ^0.12.0+1** | `ResolutionPreset.high` untuk face, NV21 format Android |
| GPS | **geolocator ^14.0.2** | `Position.isMocked` untuk anti fake-GPS |
| Permission runtime | **permission_handler ^12.0.1** | JANGAN assume permission granted |
| Device info | **device_info_plus ^12.4.0** | Untuk audit log (model + OS) |
| Splash native | **flutter_native_splash ^2.4.7** | Generated, jangan edit manual |
| Font | **google_fonts ^8.0.2** | Plus Jakarta Sans (heading) + Inter (body) |

**Rekomendasi untuk fitur YANG BELUM diimplementasi** (boleh tambah saat fitur dikerjakan, jangan tambah sekarang biar APK tidak bloat):

| Fitur masa depan | Library yang direkomendasikan | Kapan tambah |
|-----------|---------------|---------|
| Skeleton loading state | `shimmer` (latest dari pub.dev) | Saat implement loading 3-state mobile pertama kali |
| Cache avatar network image | `cached_network_image` (latest) | Saat fitur edit avatar mobile diimplementasi |
| Offline detection / banner | `connectivity_plus` (latest) | Saat implement offline-first mode atau retry indicator |

**Yang DIHAPUS dari pubspec (audit 2026-05-14)** karena belum dipakai:
- `cached_network_image`, `shimmer`, `connectivity_plus` — over-locked di rules sebelum implementasi
- `cupertino_icons` — proyek Android-only Material 3
- `flutter_driver` + `integration_test` — tidak ada e2e test plan

### Yang Dilarang Tanpa Diskusi
- ❌ Ganti SweetAlert2 dengan `react-hot-toast`, `sonner`, `react-toastify`.
- ❌ Ganti Recharts dengan Chart.js / ApexCharts / Victory.
- ❌ Pakai emoji untuk ikon (pakai Lucide).
- ❌ Validasi manual `if-else` (pakai Zod).
- ❌ Ganti `useFormState` dengan `useActionState` (BUG-004 — React 19).
- ❌ Pakai `window.alert()` / `window.confirm()` (BUG-008).
- ❌ Pakai `shared_preferences` untuk simpan token (pakai `flutter_secure_storage`).
- ❌ Ganti Riverpod dengan Provider/BLoC/GetX di mobile.
- ❌ Hardcode HTTP client baru di samping Dio singleton.
- ❌ Ganti GoRouter dengan auto_route / Navigator 1.0.

### Cara Tambah Dependency Baru
1. Cari dulu apakah library yang sudah ada bisa cover kebutuhan.
2. Jika benar-benar perlu library baru → **diskusikan dulu dengan user**:
   - Apa kebutuhan konkretnya?
   - Apakah ada alternatif via library yang sudah ada?
   - Bagaimana maintenance status library tersebut?
   - Lisensi (MIT/Apache/BSD OK; GPL hindari).
3. Setelah disetujui → tambah ke `package.json` / `pubspec.yaml` dengan **versi terkunci** (caret OK, tapi lebih baik exact untuk production).
4. Update `00-mypresensi-overview.md` (tech stack table) atau dokumentasi yang relevan.
