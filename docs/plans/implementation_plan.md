# MyPresensi — Implementation Plan v7 (Honest Reality Check)

> Sistem Absensi Face Recognition + Geolokasi
> **Prodi TRPL, Politeknik Pertanian Negeri Samarinda**
> Proyek PBL Semester 6 | Status: Eksekusi aktif (sebagian sudah implementasi)

---

## Status: Source of Truth

> [!IMPORTANT]
> **Plan v7 adalah hasil audit security 17 Mei 2026 (Riki × Kiro).**
> Replaces plan v6 yang over-promise klaim security yang tidak ter-implement.
> Source of truth keputusan: `docs/decisions/security-architecture-final.md`.
> Setiap klaim di file ini sudah cross-reference dengan kode aktual (`submit/route.ts`, `face_embedding_service.dart`, migrations 001-019).
>
> **Perubahan utama v6 → v7 (HONEST REDUCTION):**
> - **6-layer security → 3-layer realistic** (QR + GPS + Face). Hapus klaim: WiFi SSID matching, teleportation detection (>100 km/h), GPS vs cell tower cross-ref.
> - **Embedding 128-D → 192-D** (MobileFaceNet TFLite, sesuai `face_embedding_service.dart:23`).
> - **Liveness Active Challenge → Basic Presence Detection** (ML Kit face landmark detection, no kedip-senyum random order).
> - **Status kehadiran 4 → 5 enum** (+ `terlambat`, sudah ada sejak migration `013_late_status.sql`).
> - **Dosen platform: Mobile App → Web only** (endpoint `/api/mobile/*` memblok role≠`mahasiswa` di `auth.ts:67-69`).
> - **Bottom nav mobile: 4 tab → 5 tab** (Beranda, Riwayat, Asisten AI, Notifikasi, Profil — sesuai `app_shell.dart:35-41`).
> - **Hapus klaim**: AES-256 embedding encryption (Supabase encrypt-at-rest sudah default), certificate pinning, freeRASP, Edge Functions (semua via Next.js Route Handler).
> - **Threshold face confidence**: 0.75 → 0.65 (migration `005_mobilefacenet_threshold.sql`, sesuai LFW benchmark MobileFaceNet 192-d).
> - **Backend pattern**: Supabase Edge Functions → Next.js 14 Route Handler (`app/api/mobile/*`) + Server Actions.
>
> **Adjustment Phase 1.5 (sesi yang sama, 17 Mei 2026):**
> - **Face WAJIB di kedua mode** (offline + online) — sesuai feedback user: konsistensi rule, cover threat titip absen online. Mahasiswa absen via HP smartphone (punya kamera depan), bukan dari laptop. UX friction online minor (pose 2-3 detik ke kamera).
> - **Phase 4 Manual Override Dosen DIHAPUS** — edge case kamera rusak HP sangat rare; solusi informal via "pinjam HP teman sebelum sesi" cukup. Mahasiswa benar-benar tidak bisa hadir = ajukan izin/sakit via leave_request yang sudah ada.
> - **v7 final = 3 phase teknis** (Phase 2 face wajib + Phase 3 QR rolling 5s).
>
> **Identitas visual & desain (carry-over dari v6, masih berlaku):**
> - **Logo:** Prodi TRPL (`docs/assets/images/Prodi/TRPL.jpg`)
> - **Warna:** Biru Baja TRPL (`#5483AD`)
> - **Panduan Desain:** Mekari Talenta (Card-based, Ultra-Minimalist)
> - **Navigasi Mobile:** Standard Bottom Navigation Bar (bukan floating)

---

## Bagian 1: Identitas Aplikasi

| Atribut | Nilai |
|---------|-------|
| **Nama Aplikasi** | MyPresensi |
| **Institusi** | Politeknik Pertanian Negeri Samarinda |
| **Prodi** | Teknik Rekayasa Perangkat Lunak (TRPL) |
| **Logo** | `docs/assets/images/Prodi/TRPL.jpg` |
| **Target Pengguna** | Mahasiswa, Dosen, Admin Prodi |
| **Platform** | Mobile (Android/iOS) + Web Admin |

---

## Bagian 2: Keputusan Akun Mahasiswa

### Strategi: Standalone + CSV Import (Sekarang) → SIA API (Masa Depan)

```
Admin punya data Excel dari prodi
       |
Siapkan CSV: NIM, Nama, Email, Semester, Kelas
       |
Upload via Web Admin → "Import Mahasiswa"
       |
Sistem per baris:
  1. Buat Supabase Auth account (email + default password)
  2. Buat profile record (NIM, nama, semester, kelas)
  3. Default password = NIM@politani (contoh: H2336001@politani)
       |
Mahasiswa login pertama kali
       |
Force Change Password (WAJIB ganti) ← Tidak bisa skip
       |
Registrasi Wajah (1x, bisa diulang jika perlu)
       |
Siap Digunakan
```

> [!NOTE]
> **Arsitektur Siap SIA API:** Database schema dirancang agar `nim_nip`, `full_name`, `semester`, `kelas`
> bisa diisi dari CSV sekarang atau SIA API nanti tanpa perlu refactor apapun.

---

## Bagian 3: Tech Stack & Justifikasi

### Stack Utama (Aktual)

| Komponen | Teknologi | Alasan |
|----------|-----------|--------|
| **Mobile** | Flutter 3.11+ (Dart) | Satu codebase Android+iOS, performa ML native, akses hardware kamera langsung |
| **Web** | Next.js 14.2 App Router (React 18) | Server Components: service_role key tidak pernah muncul di browser |
| **Backend** | Supabase (PostgreSQL + Auth + Storage) | Auth built-in, RLS, Storage, Real-time — semua tanpa konfigurasi server |
| **API Mobile** | Next.js Route Handler (`/api/mobile/*`) | Bearer JWT auth, Zod validation, rate limit in-memory. **BUKAN Supabase Edge Functions** (di plan v6 disebut, tapi tidak dipakai). |
| **Face Detection** | google_mlkit_face_detection 0.13 | Deteksi landmark + bbox, berjalan on-device (offline) |
| **Face Encoding** | tflite_flutter 0.12 + MobileFaceNet | Embedding **192-D** di perangkat mahasiswa, inference on-device |
| **Liveness** | Basic Presence Detection (ML Kit) | Cek wajah real-time + landmark (bukan static photo). **TIDAK pakai active challenge** (kedip-senyum random) — mudah di-bypass video, butuh model ML khusus di luar PBL scope. |
| **State Management** | Riverpod 3.3 | Type-safe, testable, compile-time safe |
| **Navigasi** | GoRouter 17.2 | Deep link support, `refreshListenable` untuk auth state |
| **HTTP Client** | Dio 5.9 | Interceptor auth (Bearer JWT) + 401 auto-logout |
| **Secure Storage** | flutter_secure_storage 10 | Token & secret (BUKAN `shared_preferences`) |

### Supabase vs PHP/Laravel

| Aspek | Laravel | Supabase |
|-------|---------|----------|
| Setup backend | 2-3 minggu | 1-2 hari |
| Auth + JWT | Manual (Sanctum) | Built-in |
| Real-time | Echo + Pusher (biaya) | Built-in (zero config) |
| SQL Injection | Eloquent aman, raw query berisiko | Parameterized default + RLS |
| Hosting | VPS ($5-10/bulan) | Free tier |
| **Total waktu backend** | **4-6 minggu** | **1 minggu** |

> 5 minggu yang dihemat dialokasikan ke Face Recognition dan lapisan keamanan.

---

## Bagian 4: Arsitektur Keamanan (Honest 3-Layer)

### 4.1 Defense in Depth — 3 Layer

3 layer dipilih karena masing-masing meng-cover threat **berbeda**, bukan belt-and-suspenders untuk threat yang sama.

| Layer | Komponen | Threat yang Di-cover | Status |
|-------|----------|----------------------|--------|
| **1** | **QR Code Session-Specific** (rolling 5s, TOTP-like, tolerance ±2 window = 15s effective) | Anti screenshot-share statis, session-binding | ⏳ Phase 3 (A1) |
| **2** | **GPS + Mock Detection** (Haversine server-side + `Position.isMocked` reject 403) | Absen dari kos di mode offline, fake GPS app | ✅ Sudah implementasi (GPS wajib offline, skip online) |
| **3** | **Face Recognition WAJIB di KEDUA MODE** (MobileFaceNet 192-D + cosine similarity 0.65 + presence detection) | Titip absen ke teman (offline + online), share QR + GPS palsu | ⏳ Phase 2 (gate di backend untuk SEMUA submit) |

**Filosofi**: Threat model = 95% serangan mahasiswa malas dengan trik basic (titip absen, fake GPS app, screenshot QR). BUKAN APT/state-sponsored. Skala = ~50 mahasiswa per kelas Politani TRPL.

### 4.2 Klaim yang DIHAPUS dari Plan v6 (Tidak Ter-implement)

| Klaim Plan v6 | Status Aktual | Alasan Skip |
|---------------|---------------|-------------|
| Layer WiFi SSID matching `Politani_Samarinda_University` | ❌ Tidak ada `network_info_plus` di `pubspec.yaml` | False positive tinggi (mhs data seluler) + bypass mudah (50m WiFi range) + operational nightmare (WiFi sering down) |
| Layer Teleportation Detection (>100 km/h reject) | ❌ Tidak ada code di submit | Edge case bias (motor 80 km/h), GPS jitter indoor 50-100m |
| Layer GPS vs Cell Tower cross-ref | ❌ Tidak implementasi | Privacy concern UU PDP, iOS unsupported, akurasi 5-10 km tidak cukup untuk radius 150m |
| Liveness Active Challenge (kedip + senyum random urutan) | ❌ Hanya basic ML Kit landmark check | Mudah di-bypass video real-time, butuh ML model spesialis (Onfido/Jumio level) |
| Texture analysis anti-replay | ❌ Tidak implementasi | Same — butuh model deep learning di luar PBL scope |
| AES-256 embedding encryption (BYTEA encrypted) | ❌ `face_embeddings.embedding BYTEA` raw, di-encrypt at-rest by Supabase storage | Supabase encrypt-at-rest + RLS strict sudah cukup proteksi |
| Certificate pinning (Dio) | ❌ Tidak dikonfigurasi | HTTPS default sudah cukup di kampus (tidak ada MITM threat realistic) |
| freeRASP (root/emulator/tampering detection) | ❌ Tidak di pubspec | Low ROI PBL, audit log + dosen review sudah cover |
| Refresh token rotation 15-menit | ❌ Pakai default Supabase JWT (1 jam) | Default Supabase Auth sudah aman untuk skala kampus |
| Edge Function server-side revalidation | ❌ Semua via Next.js Route Handler | Functional setara, lebih simpel untuk skala kampus |

### 4.3 Threat Model — TER-COVER (Honest)

| Serangan | Mitigasi | Severity |
|----------|----------|----------|
| Mahasiswa absen dari kos | GPS Haversine + radius 150m server-side (Layer 2) | HIGH |
| Fake GPS app (Lockito, Fake GPS Joystick) | `Position.isMocked = true` → reject 403 + audit `mock_location_detected` (Layer 2) | HIGH |
| Screenshot QR + share via WA | Rolling QR 5s (Layer 1, Phase 3) + Face wajib di kedua mode (Layer 3, Phase 2) — **dua-duanya gagal independent** | MEDIUM |
| Titip absen dengan HP teman (offline) | Face match wajib (Layer 3) | HIGH |
| **Titip absen online** (A kasih akun ke B, B submit dari rumah) | Face match wajib di mode online juga (Layer 3, Phase 2) — B harus pasang wajah B → mismatch → reject | HIGH (covered) |
| Replay attack (intercept HTTPS payload) | UNIQUE(session_id, student_id) duplicate check + Rolling QR 15s window | LOW |
| Submit kode sesi expired | `session_code_expires_at` check server-side | HIGH |
| Submit ke sesi yang sudah closed | `is_active = true` check server-side | HIGH |
| Mahasiswa kamera HP rusak permanen | **Prosedur informal**: pinjam HP teman sebelum sesi mulai → login akun sendiri → pose wajah sendiri → logout + ganti password. Frekuensi sangat rendah (HP modern). | LOW (acceptable risk) |
| Mahasiswa benar-benar tidak bisa hadir + tidak bisa pinjam HP | Ajukan **izin/sakit** via fitur `leave_request` yang sudah ada (mobile submit + bukti foto, dosen approve via web) | LOW |
| Brute force login | Rate limit endpoint + `max_login_attempts=5` + `lockout_minutes=30` (settings) | MEDIUM |
| Session hijacking | `flutter_secure_storage` token + Supabase JWT default expiry | MEDIUM |
| SQL Injection | Supabase parameterized queries + Zod server-side validation | HIGH |
| IDOR (akses data user lain) | RLS Postgres `(SELECT auth.uid()) = student_id` per row | HIGH |
| Mass assignment | Zod schema whitelist field di Route Handler | MEDIUM |

### 4.4 Threat Model — TIDAK TER-COVER (Acceptable Risk)

| Threat | Why NOT Covered | Mitigation Tersisa |
|--------|-----------------|--------------------|
| Attack via rooted device | freeRASP skipped (low ROI PBL) | Audit log device anomaly (`device_id_audit` migration 014), dosen review |
| MITM attack public WiFi | Cert pinning skipped (no realistic threat di kampus) | HTTPS default + Supabase HSTS |
| Mahasiswa fake video face real-time | Active liveness skipped (mudah di-bypass anyway) | Manual review dosen kalau ada anomaly + audit log |
| Mahasiswa bolos online lecture sambil tetap absen | Face wajib di mode online cover sebagian (mahasiswa harus pose wajah ke kamera saat absen) tapi tidak cover "submit lalu tutup laptop" | Trust dosen kelas online untuk monitor presensi via Zoom + check sesi rekaman |
| Database breach exfil embedding | Dianggap covered: Supabase encrypt-at-rest + RLS strict | RLS deny non-owner + audit log akses |
| Credential sharing saat "pinjam HP teman" | Inherent risk dari prosedur informal | Wajib ganti password setelah pinjam (manual), audit log device anomaly |

### 4.5 Mode Absen: Offline vs Online

| Aspek | Offline (Tatap Muka) | Online (Daring) |
|-------|----------------------|-----------------|
| GPS Haversine | Wajib (radius 150m dari `sessions.location_lat/lng`) | Skip (`distance_meters=0`, `is_location_valid=true`) |
| Mock GPS Detection | Aktif (`isMocked=true` → reject 403) | Aktif (tetap reject mock GPS) |
| Face Recognition | **WAJIB** (Phase 2 gate — `is_face_registered=true` + match) | **WAJIB** (Phase 2 gate — sama seperti offline) |
| Kode Sesi (QR) | Wajib (rolling 5s, Phase 3) | Wajib (rolling 5s, Phase 3) |
| Audit | GPS coords + device ID + IP + face confidence | IP + device ID + timestamp + face confidence |

> Dosen memilih mode saat membuat sesi. **Face WAJIB di KEDUA mode** sesuai adjustment Phase 1.5 (17 Mei 2026). Setting `face_verification_mode` (migration 003) di-set ke `required` (face wajib di semua mode). Mahasiswa absen via HP smartphone yang punya kamera depan — friction online minor (pose 2-3 detik). Edge case kamera HP rusak: pinjam HP teman sebelum sesi mulai (prosedur informal).

---

## Bagian 5: Fitur Lengkap Per Role

### Mahasiswa (Mobile App)

| Fitur | Deskripsi | Status |
|-------|-----------|--------|
| Login + Force Change Password | Login pertama wajib ganti password via web (mobile blok kalau `must_change_password=true`) | ✅ Sudah ada |
| Registrasi Wajah | 7-frame averaging di pose `lookStraight` (BUG-010 fix) + ML Kit presence detection + simpan embedding 192-D | ✅ Sudah ada |
| Absen Offline | Scan QR → GPS Haversine in-radius → **Face match WAJIB** (Phase 2) | ⏳ Phase 2 (face gate) |
| Absen Online | Scan QR → **Face match WAJIB** (Phase 2, sama seperti offline) | ⏳ Phase 2 (face gate) |
| Ajukan Izin/Sakit | Submit request + lampiran bukti foto (`image_picker`) ke bucket `leave-evidence` | ✅ Sudah ada |
| Dashboard | Jadwal hari ini, sesi aktif, persentase kehadiran, request pending | ✅ Sudah ada |
| Riwayat Absensi | Per mata kuliah, filter status (5 enum), card view | ✅ Sudah ada |
| Statistik Pribadi | Chart kehadiran per mata kuliah | ⏳ Belum diimplementasi |
| Profil | Edit info, **upload avatar** (P3-#3), re-register wajah, ganti password | ✅ Sudah ada |
| Notifikasi | Sesi aktif, status izin (notifikasi push BELUM diimplementasi — hanya inbox) | ✅ Inbox saja |
| Asisten AI (tab 3) | AI chat untuk tanya prosedur absen, bantuan navigasi | ✅ Sudah ada |

### Dosen (Web Dashboard — BUKAN Mobile)

> **Catatan v7**: Plan v6 menyebut Dosen pakai "Mobile App". AKTUAL: Dosen hanya di Web. Endpoint `/api/mobile/*` memblok role≠`mahasiswa` (`auth.ts:67-69`). Tidak ada layar dosen di `mypresensi-mobile/lib/`.

| Fitur | Deskripsi | Status |
|-------|-----------|--------|
| Buat Sesi | Pilih MK, topik, mode (offline/online), durasi, radius GPS | ✅ Sudah ada |
| QR Display + Refresh | Tampilkan QR rolling 30s di proyektor untuk mahasiswa scan | ✅ Sudah ada (Phase 3 22 Mei 2026) |
| Monitor Real-time | Daftar hadir live saat sesi berlangsung (Supabase Realtime) | ✅ Sudah ada (migration 016) |
| Tutup Sesi | Close manual + auto-alpa untuk yang belum absen | ✅ Sudah ada |
| Review Izin/Sakit | Approve/reject request + lihat bukti foto mahasiswa (juga handle case mahasiswa kamera rusak permanen + tidak bisa pinjam HP teman) | ✅ Sudah ada |
| Rekap Kehadiran | Tabel per MK, filter status, export CSV/PDF | ✅ Sudah ada |
| Statistik Kelas | Visualisasi tren kehadiran (Recharts) | ✅ Sudah ada |
| At-Risk Widget | Identifikasi mahasiswa kehadiran <70% (migration 015) | ✅ Sudah ada |

### Admin (Web Dashboard)

| Fitur | Deskripsi |
|-------|-----------|
| Dashboard Overview | Angka total hari ini: hadir, alpa, izin, trend chart |
| Kelola Dosen | CRUD + CSV import dosen |
| Kelola Mahasiswa | CRUD + CSV import (default pass: NIM@politani, force change) |
| Kelola Mata Kuliah | CRUD + assignment dosen ke MK |
| Enrollment | Relasi mahasiswa-MK per tahun ajaran + CSV import |
| Rekap Absensi | Filter per MK/dosen/kelas/tanggal, detail per sesi |
| Export Data | PDF + Excel (generated di server, bukan browser) |
| Pengaturan Sistem | Radius geofencing, threshold liveness, durasi token |
| Audit Log | Semua aktivitas sistem tercatat (siapa, apa, kapan) |

---

## Bagian 6: Fitur Izin / Sakit (Detail)

### Alur

```
Mahasiswa tidak bisa hadir
       |
Buka app → "Ajukan Izin"
       |
Pilih sesi / mata kuliah yang dimaksud
Pilih jenis: [Izin] atau [Sakit]
Isi alasan (wajib, min 20 karakter)
Upload bukti (opsional): foto surat dokter / surat izin orang tua
       |
Submit → Status: "Menunggu"
       |
Dosen dapat notifikasi push
       |
Dosen buka → lihat detail + preview bukti → [Setujui] / [Tolak]
       |                                           |
    Setujui:                                    Tolak:
    status = "izin"/"sakit"                     status tetap "alpa"
    notifikasi ke mahasiswa                     notifikasi + alasan penolakan
```

---

## Bagian 7: Desain UI/UX

### 7.1 Referensi & Panduan

**Referensi Utama:** Mekari Talenta (card-based, ultra-minimalist)
**Referensi Pendukung:** BambooHR, Rippling (tabel data)

### 7.2 Aturan Wajib

- Tidak ada emoji di dalam aplikasi
- Tidak ada gradient warna-warni
- Tidak ada dekorasi berlebihan (shadow ekstrem, animasi berputar, dll.)
- Gaya: Post-Flat, Card-based seperti Mekari Talenta
- Ikon: **Lucide** (web), **Phosphor** (mobile)
- Logo yang digunakan: **Logo Prodi TRPL** (`docs/assets/images/Prodi/TRPL.jpg`)

### 7.3 Color Tokens (Biru TRPL)

| Token | Light Mode | Dark Mode |
|-------|-----------|-----------|
| **primary** | `#5483AD` | `#628FB3` |
| **primary-hover** | `#43698A` | `#4D728F` |
| surface | `#FFFFFF` | `#1A1F2B` |
| background | `#F4F6F8` | `#0D1117` |
| border | `#E2E6EA` | `#2D333B` |
| text-primary | `#1C2024` | `#E6EDF3` |
| text-secondary | `#636C76` | `#8B949E` |
| **success (Hadir)** | `#1A7F37` | `#3FB950` |
| **warning (Izin)** | `#9A6700` | `#D29922` |
| **danger (Alpa)** | `#CF222E` | `#F85149` |

### 7.4 Tipografi

| Penggunaan | Font | Weight |
|------------|------|--------|
| Heading / Judul | Plus Jakarta Sans | 600, 700 |
| Body / Paragraf | Inter | 400, 500 |
| Kode / Monospace | JetBrains Mono | 400 |

### 7.5 Komponen UI Kunci (Ala Mekari Talenta)

| Komponen | Spesifikasi |
|----------|------------|
| Card | `border-radius: 16px`, `box-shadow: 0 2px 8px rgba(0,0,0,0.06)` |
| Tombol Utama (CTA) | Pill button / `border-radius: 999px`, lebar penuh di mobile |
| Bottom Nav Bar | Standard (tidak floating), **5 item AKTUAL** (`app_shell.dart:35-41`): Beranda, Riwayat, Asisten (AI Chat), Notifikasi, Profil |
| Status Badge | Bulat, warna solid: Hijau=Hadir, Kuning=Terlambat/Izin/Sakit, Merah=Alpa, Biru=Izin disetujui |
| Tabel Web | Tanpa garis vertical, row hover highlight, status badge |
| Input Field | `border-radius: 8px`, placeholder abu-abu, focus color: primary |

> **Catatan v7**: Tab "Izin" di `security-architecture-final.md` adalah placeholder rencana. AKTUAL aplikasi pakai tab "Asisten" (AI Chat) sebagai slot tab ke-3. Akses fitur izin via tab Riwayat → "Ajukan Izin" atau via Beranda. Bila ingin promote "Izin" jadi tab utama, perlu diskusi UX dulu (potential displacement Asisten ke menu lain).

### 7.6 Mockup Visual

File PDF mockup tersedia:
- `UI_Mockup_MyPresensi_v4_Talenta.pdf` — versi final (Gaya Mekari Talenta + Biru TRPL)

---

## Bagian 8: Code Quality Contract

> [!IMPORTANT]
> Aturan ini berlaku untuk **setiap baris kode** sepanjang proyek. Tidak ada kompromi.

| Prinsip | Implementasi |
|---------|-------------|
| **DRY** | Tidak ada logika yang ditulis dua kali. Jika dipakai >1 tempat, extract ke function/widget/service |
| **Single Responsibility** | 1 file = 1 tujuan. 1 class = 1 tanggung jawab. 1 function = 1 tugas |
| **No Dead Code** | Tidak ada kode di-comment "untuk jaga-jaga". Tidak ada function yang tidak dipanggil |
| **Separation of Concerns** | UI tidak boleh langsung panggil database. Selalu lewat service layer |
| **Naming** | Dart: `snake_case` file, `camelCase` var, `PascalCase` class. JS: `camelCase` var, `PascalCase` component |
| **Explicit** | Tidak ada magic string. Semua constant di `constants.dart` / `constants.js` |
| **Error Handling** | Semua network call di-wrap try/catch. User selalu dapat feedback jelas. Tidak ada silent failure |
| **Type Safety** | Dart: no `dynamic` kecuali terpaksa. TypeScript di Next.js |

### Pola Arsitektur Flutter

```
Screen / Widget  →  Provider (Riverpod)  →  Service  →  Supabase / TFLite / GPS
     (UI only)       (state bridge)        (business logic)   (external)
```

### Pola Arsitektur Next.js

```
Page (Server Component)  →  Server Action / API Route  →  Supabase (service_role)
     (render HTML)             (mutasi + validasi Zod)       (query aman)
```

---

## Bagian 9: Database Schema

```sql
-- ===========================
-- PROFILES (semua user)
-- ===========================
CREATE TABLE profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  full_name TEXT NOT NULL,
  nim_nip TEXT UNIQUE NOT NULL,
  role TEXT CHECK (role IN ('admin', 'dosen', 'mahasiswa')) NOT NULL,
  semester INTEGER,
  kelas TEXT,
  phone TEXT,
  avatar_url TEXT,
  is_face_registered BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  must_change_password BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- FACE EMBEDDINGS
-- ===========================
-- v7: embedding 192-D (MobileFaceNet, BUKAN 128D seperti klaim v6)
-- BYTEA raw float32 array; encryption at-rest oleh Supabase storage (default)
-- TIDAK ada AES-256 kolom-level (klaim v6 salah)
CREATE TABLE face_embeddings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  embedding BYTEA NOT NULL,         -- 192-D float32 vector (768 bytes)
  embedding_hash TEXT NOT NULL,     -- SHA-256 hash untuk dedup detection
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- COURSES (mata kuliah)
-- ===========================
CREATE TABLE courses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  sks INTEGER DEFAULT 3,
  semester INTEGER NOT NULL,
  dosen_id UUID REFERENCES profiles(id),
  academic_year TEXT DEFAULT '2025/2026',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- ENROLLMENTS (relasi mhs-MK)
-- ===========================
CREATE TABLE enrollments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  academic_year TEXT NOT NULL,
  UNIQUE(course_id, student_id, academic_year)
);

-- ===========================
-- SESSIONS (sesi perkuliahan)
-- ===========================
CREATE TABLE sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
  dosen_id UUID REFERENCES profiles(id),
  session_number INTEGER NOT NULL,
  topic TEXT,
  mode TEXT CHECK (mode IN ('offline', 'online')) DEFAULT 'offline',
  session_code TEXT,                              -- 6 digit, mode online
  session_code_expires_at TIMESTAMPTZ,
  location_lat DOUBLE PRECISION DEFAULT -0.5378, -- Koordinat Politani Samarinda
  location_lng DOUBLE PRECISION DEFAULT 117.1242,
  radius_meters INTEGER DEFAULT 150,
  is_active BOOLEAN DEFAULT TRUE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- ATTENDANCES (rekap absensi)
-- ===========================
-- v7: status enum 5 (+ terlambat), bukan 4 seperti klaim v6.
--     Migration 013_late_status.sql sudah extend enum + auto-classify by late_threshold_minutes.
-- v7: wifi_ssid column ada di schema tapi TIDAK dipakai aktual (klaim WiFi SSID matching v6 dihapus).
CREATE TABLE attendances (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('hadir', 'terlambat', 'izin', 'sakit', 'alpa')) DEFAULT 'hadir',
  scanned_at TIMESTAMPTZ DEFAULT NOW(),
  -- Geolocation audit (Layer 2)
  student_lat DOUBLE PRECISION,
  student_lng DOUBLE PRECISION,
  distance_meters DOUBLE PRECISION,
  is_location_valid BOOLEAN,
  is_mock_location BOOLEAN DEFAULT FALSE,
  wifi_ssid TEXT,                              -- LEGACY: tidak dipakai validasi v7
  -- Face Recognition audit (Layer 3)
  face_confidence DOUBLE PRECISION,            -- cosine similarity (0.0-1.0)
  is_face_matched BOOLEAN,                     -- threshold check by server
  is_liveness_passed BOOLEAN,                  -- presence detection only
  -- Device audit
  device_model TEXT,
  device_os TEXT,
  device_id TEXT,                              -- migration 014_device_id_audit
  ip_address TEXT,
  session_mode TEXT,
  UNIQUE(session_id, student_id)
);

-- v7 Phase 1.5: Manual Override (Phase 4 B1) DI-SKIP — edge case kamera rusak HP
--                pakai prosedur informal "pinjam HP teman sebelum sesi".
--                Migration 021 tidak akan dibuat.

-- ===========================
-- LEAVE REQUESTS (izin/sakit)
-- ===========================
CREATE TABLE leave_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  type TEXT CHECK (type IN ('izin', 'sakit')) NOT NULL,
  reason TEXT NOT NULL,
  evidence_url TEXT,                   -- foto bukti di Supabase Storage
  status TEXT CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
  reviewed_by UUID REFERENCES profiles(id),
  review_note TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- SETTINGS (konfigurasi sistem)
-- ===========================
CREATE TABLE settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default settings (v7 — sesuai aktual migration 001 + 003 + 005 + 013)
INSERT INTO settings (key, value, description) VALUES
  ('geofence_radius_meters', '150', 'Radius default geofencing kampus'),
  ('face_confidence_threshold', '0.65', 'Cosine similarity minimum (LFW MobileFaceNet 192-d). v7: 0.65 bukan 0.75'),
  ('face_verification_mode', 'required', 'required = WAJIB di kedua mode (Phase 1.5 adjustment 17 Mei 2026). Sebelumnya optional = ikut session.mode.'),
  ('session_code_expiry_minutes', '3', 'Durasi kode sesi (akan jadi rolling 5s di Phase 3)'),
  ('late_threshold_minutes', '15', 'Submit > nilai ini setelah started_at → status=terlambat (migration 013)'),
  ('max_login_attempts', '5', 'Maksimum percobaan login sebelum lockout'),
  ('lockout_minutes', '30', 'Durasi lockout setelah gagal login');

-- ===========================
-- AUDIT LOGS
-- ===========================
CREATE TABLE audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  action TEXT NOT NULL,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- RATE LIMIT LOG
-- ===========================
CREATE TABLE rate_limit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  endpoint TEXT NOT NULL,
  requested_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================
-- ROW LEVEL SECURITY (RLS) — v7 PATTERN
-- ===========================
-- v7: WAJIB pakai (SELECT auth.uid()) BUKAN auth.uid() langsung
-- (sejak migration 011_rls_auth_initplan — init-plan optimization, Postgres evaluate sekali per query)
-- Ref: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE face_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendances ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limit_log ENABLE ROW LEVEL SECURITY;

-- Mahasiswa hanya bisa akses data milik sendiri (v7 pattern)
CREATE POLICY "Student own attendance" ON attendances
  FOR SELECT USING ((SELECT auth.uid()) = student_id);

CREATE POLICY "Student own leave" ON leave_requests
  FOR ALL USING ((SELECT auth.uid()) = student_id);

-- Dosen bisa akses sesi & absensi yang dibuatnya
CREATE POLICY "Dosen own sessions" ON sessions
  FOR ALL USING ((SELECT auth.uid()) = dosen_id);

-- Embedding hanya bisa diakses pemiliknya
CREATE POLICY "User own embedding" ON face_embeddings
  FOR ALL USING ((SELECT auth.uid()) = user_id);

-- v7: anon role REVOKE SELECT dari semua tabel public (migration 006_security_hardening)
-- v7: audit_logs INSERT hanya via service_role (createAdminClient), bukan permissive policy
-- v7: notifications INSERT hanya via service_role

-- ===========================
-- INDEXES
-- ===========================
CREATE INDEX idx_attendances_session ON attendances(session_id);
CREATE INDEX idx_attendances_student ON attendances(student_id);
CREATE INDEX idx_leave_requests_student ON leave_requests(student_id);
CREATE INDEX idx_leave_requests_status ON leave_requests(status) WHERE status = 'pending';
CREATE INDEX idx_sessions_course ON sessions(course_id);
CREATE INDEX idx_enrollments_student ON enrollments(student_id);
```

---

## Bagian 10: Struktur Proyek

```
Projek-PBL-Semester-6/
├── docs/
│   └── assets/
│       └── images/
│           ├── Logo-Kampus/Politani.png
│           └── Prodi/TRPL.jpg             ← Logo yang digunakan di aplikasi
│
├── mypresensi-mobile/             ← Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/
│   │   │   ├── app.dart
│   │   │   ├── theme.dart         ← Color tokens + typography TRPL
│   │   │   └── constants.dart     ← Semua magic string di sini
│   │   ├── core/
│   │   │   ├── models/            ← freezed data classes
│   │   │   ├── services/          ← 1 file = 1 layanan
│   │   │   │   ├── auth_service.dart
│   │   │   │   ├── face_recognition_service.dart
│   │   │   │   ├── location_service.dart
│   │   │   │   └── attendance_service.dart
│   │   │   ├── providers/         ← Riverpod providers
│   │   │   ├── utils/             ← pure helper functions
│   │   │   └── exceptions/        ← typed errors
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── dashboard/
│   │   │   ├── attendance/
│   │   │   ├── face_registration/
│   │   │   ├── history/
│   │   │   ├── session/           ← dosen: kelola sesi
│   │   │   ├── leave_request/     ← izin/sakit flow
│   │   │   ├── statistics/
│   │   │   └── profile/
│   │   └── shared/
│   │       ├── widgets/           ← reusable components
│   │       └── layouts/
│   ├── assets/
│   │   └── images/trpl_logo.jpg
│   └── pubspec.yaml
│
├── mypresensi-web/                ← Next.js 14 App Router
│   ├── app/                       ← v7: path alias @/* → ./app/* (BUKAN src/, BUG-002)
│   │   ├── (auth)/login/
│   │   ├── (dashboard)/
│   │   │   ├── dashboard/
│   │   │   ├── dosen/
│   │   │   ├── mahasiswa/
│   │   │   ├── matakuliah/
│   │   │   ├── sesi/                ← dosen kelola sesi + QR display
│   │   │   ├── rekap/
│   │   │   ├── export/
│   │   │   ├── settings/
│   │   │   └── audit/
│   │   ├── api/
│   │   │   └── mobile/              ← v7: Route Handler untuk mobile (BUKAN Edge Functions)
│   │   │       ├── auth/login/
│   │   │       ├── attendance/submit/
│   │   │       ├── face/register/
│   │   │       ├── face/verify/
│   │   │       ├── profile/
│   │   │       └── _lib/auth.ts     ← authenticateRequest() helper
│   │   ├── lib/                     ← supabase clients, audit-logger, swal, dll
│   │   └── globals.css
│   ├── components/
│   ├── supabase/migrations/       ← 001..019 (v7 active range)
│   ├── middleware.ts              ← Auth guard server-side + role gate
│   └── package.json
│
└── supabase/                      ← v7: TIDAK pakai functions/ (semua via Next.js Route Handler)
```

> **Catatan v7**: Plan v6 menyebut Edge Functions (`validate-attendance`, `generate-session-code`, `process-csv-import`). AKTUAL: semua di-implement sebagai Next.js Route Handler di `mypresensi-web/app/api/mobile/*` dan Server Action di `mypresensi-web/app/lib/actions/*`. Tidak ada Edge Function di repo.

---

## Bagian 11: Dependencies Flutter (AKTUAL `pubspec.yaml`)

> **Catatan v7**: Plan v6 list banyak dependency yang TIDAK pernah masuk pubspec aktual. Lihat `pubspec.yaml` repo untuk source of truth. List di bawah = AKTUAL sesi 2026-05-16.

```yaml
name: mypresensi_mobile
environment:
  sdk: ^3.11.4

dependencies:
  flutter:
    sdk: flutter

  # === Core ===
  dio: ^5.9.2                       # HTTP client + interceptor auth (BUKAN supabase_flutter SDK)
  flutter_riverpod: ^3.3.1          # State management (v3 Notifier pattern)
  riverpod: ^3.2.1
  go_router: ^17.2.0                # Routing dengan refreshListenable
  flutter_secure_storage: ^10.0.0   # Token & secret (BUKAN shared_preferences)

  # === UI ===
  google_fonts: ^8.0.2              # Plus Jakarta Sans + Inter
  flutter_native_splash: ^2.4.7     # Splash screen native

  # === Device ===
  geolocator: ^14.0.2               # GPS + isMocked anti fake-GPS
  permission_handler: ^12.0.1       # Runtime permission request
  device_info_plus: ^12.4.0         # Device model & OS untuk audit log
  camera: ^0.12.0+1                 # Live camera (ResolutionPreset.high)
  mobile_scanner: ^7.2.0            # Scan QR (minSdk 26)

  # === Face Recognition ===
  google_mlkit_face_detection: ^0.13.2  # ML Kit landmark + bbox + presence detection
  tflite_flutter: ^0.12.1               # MobileFaceNet inference (192-D)
  image: ^4.8.0                         # YUV/NV21 → RGB + crop + resize

  # === File Picker ===
  image_picker: ^1.1.0                  # Pilih foto bukti izin/sakit + avatar

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.4
```

### Dependencies yang DIHAPUS dari Klaim v6 (Tidak Pernah Masuk Aktual)

| Klaim v6 | Status |
|----------|--------|
| `supabase_flutter` | ❌ Tidak dipakai. Mobile pakai Dio + Bearer JWT manual via `/api/mobile/*` |
| `riverpod_annotation`, `riverpod_generator`, `build_runner`, `freezed`, `json_serializable`, `freezed_annotation`, `json_annotation` | ❌ Tidak pakai code generation, state class manual `copyWith` |
| `network_info_plus` | ❌ WiFi SSID matching dihapus dari v7 |
| `freeraspp` | ❌ Anti-tampering skipped (low ROI PBL) |
| `crypto` (AES-256) | ❌ Embedding tidak AES-encrypt kolom-level (Supabase at-rest cukup) |
| `flutter_animate`, `shimmer`, `fl_chart`, `phosphor_flutter` | ❌ UI library tidak dipakai — pakai Material 3 default + Lucide-like Material Icons |
| `intl`, `uuid`, `connectivity_plus`, `envied`, `envied_generator` | ❌ Tidak ada use case, hindari bloat APK |

---

## Bagian 12: Timeline Pengembangan & Status

### Fase 1–3 — Sudah Selesai (per 2026-05-16)

| Fase | Deliverable | Status |
|------|-------------|--------|
| **Foundation** | Setup Flutter + Next.js + Supabase, DB migrations 001-019, auth + role routing, CSV import | ✅ Done |
| **Core Features (Mahasiswa)** | Registrasi wajah 192-D (BUG-010 fix), scan QR, GPS Haversine + mock reject, submit attendance dengan 5-layer validation, upload avatar (P3-#3) | ✅ Done |
| **Core Features (Dosen)** | Buat sesi (offline/online), QR display, real-time monitor (Supabase Realtime), close sesi auto-alpa, manage izin, rekap, export | ✅ Done |
| **Web Admin** | CRUD dosen/mahasiswa/MK/enrollment, settings, audit log, export PDF/CSV, at-risk widget (migration 015) | ✅ Done |
| **Izin/Sakit Flow** | Mobile submit + upload bukti foto (bucket `leave-evidence`, migration 019), web approve/reject, audit | ✅ Done |

### Fase 4 — Aktif (Security Architecture v7)

| Phase | Target | Effort | Status |
|-------|--------|--------|--------|
| **Phase 1** | Document Honest Update (plan v6 → v7, workflow update) | ~3 jam | ✅ Selesai |
| **Phase 1.5** | Adjustment: Face WAJIB di kedua mode + skip Phase 4 (sesi yang sama) | ~30 menit | ✅ Selesai |
| **Phase 2** | Face WAJIB di **kedua mode** (route.ts gate + mobile UX 403 handling + dialog redirect ke face_registration). Backend logic lebih simpel — tidak ada branch per session.mode | 3-4 jam | ⏳ Next |
| **Phase 3** | QR Rolling **30s + tolerance ±1 = 90s effective** (A3) — migration 022 `session_code_seed`, TOTP-like generation, web polling refresh, mobile no-change | 4-6 jam | ✅ Selesai (22 Mei 2026) — manual smoke pending USER |
| ~~**Phase 4**~~ | ~~Manual Override Dosen (B1)~~ — **DIHAPUS** sesuai adjustment Phase 1.5 | ~~3-4 jam~~ | ❌ Skip |

### Fase 5 — Hardening & Ship (Post-v7)

| Target | Catatan |
|--------|---------|
| Pre-release smoke test full flow di HP fisik | Login → face register → scan QR → submit → mock GPS reject → face mismatch reject |
| Release build (obfuscate + signing) | `flutter build apk --release --obfuscate --split-debug-info=build/symbols` (lihat workflow `/release-build`) |
| Deploy web ke Vercel + Supabase production | Update mobile config `apiBaseUrl` ke production URL |
| README + demo video + persiapan presentasi PBL | Audit `.gitignore` agar `.env.local`, `key.properties`, `*.jks` tidak ke-commit |

> **TIDAK ada** di Fase 5: cert pinning, freeRASP, AES-256 embedding encryption, manual override dosen — semuanya skipped dari v7 (lihat Bagian 4.2 + adjustment Phase 1.5).

---

## Bagian 13: Rencana Verifikasi (v7 — Honest)

### Security Testing (yang bisa dan AKAN di-test)
- [ ] Fake GPS app aktif (mode offline) → `Position.isMocked=true` → reject 403 + audit `mock_location_detected` (TEST DENGAN release build, debug build bypass `isMocked`)
- [ ] GPS di luar radius 150m (mode offline) → reject 403 + audit `gps_out_of_radius`
- [ ] Submit di mode online dengan GPS dimanapun → GPS skip, tetap accept (face tetap wajib)
- [ ] Tanpa register wajah submit (kedua mode) → reject 403 + dialog redirect ke face_registration_screen (Phase 2)
- [ ] Face mismatch (foto orang lain, kedua mode) → reject 403 dengan pesan ramah (Phase 2)
- [ ] Scan QR yang sudah expired → reject + pesan
- [ ] Double submit ke sesi yang sama → reject (UNIQUE constraint)
- [ ] Akses data mahasiswa lain via URL tweak → RLS deny
- [ ] Spam login 5x dengan password salah → lockout 30 menit

### Security Testing yang DI-SKIP (Lihat Bagian 4.4)
- ~~Root device detection~~ (freeRASP skipped)
- ~~MITM via proxy~~ (cert pinning skipped)
- ~~Photo/video spoof active liveness~~ (active liveness skipped — basic presence detection only)

### Face Recognition Testing
- [ ] Minimal 3 perangkat Android berbeda (mid-range + low-end + flagship)
- [ ] Kondisi cahaya: indoor terang, indoor remang, outdoor siang, outdoor malam (field test)
- [ ] Target: < 3 detik per proses scan-to-verify
- [ ] Threshold cosine similarity 0.65 — verify true accept rate >95%, false accept <5%
- [ ] 7-frame averaging untuk embedding (BUG-010 fix — capture di pose lookStraight, BUKAN turnRight)

### Functional Testing
- [ ] Alur offline lengkap (scan QR → GPS → face → submit) di release build di HP fisik
- [ ] Alur online lengkap (scan QR → face wajib → submit di mode online dari berbagai lokasi)
- [ ] Alur izin lengkap (submit + bukti foto → dosen approve → status update)
- [ ] CSV import 50+ baris mahasiswa
- [ ] Export PDF + Excel
- [ ] Edge case: kode sesi expired, double absen, mahasiswa di luar radius (mode offline)
- [ ] **Edge case kamera rusak HP**: simulasi prosedur "pinjam HP teman" — login akun A di HP B, face A capture, submit valid

### Code Quality Check
- [ ] `npm run type-check` (web) → 0 errors
- [ ] `npm run lint` (web) → 0 errors
- [ ] `flutter analyze` (mobile) → No issues found
- [ ] `mcp0_get_advisors({ type: 'security' })` → 0 new issues setelah migrations baru
- [ ] `mcp0_get_advisors({ type: 'performance' })` → 0 missing FK index

---

## Ringkasan Keputusan Final v7

| Keputusan | Pilihan v7 (Aktual) |
|-----------|---------------------|
| Mobile Framework | Flutter 3.11+ (Riverpod 3 + Dio + GoRouter) |
| Web Framework | Next.js 14.2 App Router (React 18, BUKAN 19) |
| Backend | Supabase (Postgres + Auth + Storage) |
| API Mobile | Next.js Route Handler (`/api/mobile/*`), BUKAN Edge Functions |
| Face Recognition | ML Kit (detection) + MobileFaceNet TFLite (embedding **192-D**) + cosine similarity threshold **0.65** |
| Liveness | Basic presence detection (ML Kit landmark check), TIDAK pakai active challenge |
| **Anti-Fraud** | **3-layer realistic** (QR rolling 5s + GPS offline-wajib/online-skip + **Face match WAJIB kedua mode**) |
| **QR Architecture** | A1 — Rolling 5s + tolerance ±2 (TOTP-like, Phase 3) |
| **Edge Case Kamera Rusak HP** | Prosedur informal: pinjam HP teman sebelum sesi mulai + ganti password setelahnya. **Tidak ada fitur dedicated** (Phase 4 di-skip). |
| Akun Mahasiswa | Standalone CSV → SIA API ready |
| Logo | Prodi TRPL (`docs/assets/images/Prodi/TRPL.jpg`) |
| Warna Utama | Biru TRPL `#5483AD` |
| Panduan Desain | Mekari Talenta (Card-based, Ultra-Minimalist) |
| Navigasi Mobile | Standard Bottom Nav Bar (**5 item**: Beranda, Riwayat, Asisten AI, Notifikasi, Profil) |
| Status Kehadiran | **5 enum**: hadir, terlambat, izin, sakit, alpa |
| Platform Dosen | **Web only** (BUKAN mobile) |
| Platform Mahasiswa | Mobile only (web mahasiswa hanya untuk ganti password awal) |
| Fitur Izin/Sakit | Ada (mobile submit + bukti foto, dosen approve via web) |
| State Management | Riverpod 3 (Notifier pattern) |
| Timeline | Fase 1-3 sudah selesai. Fase 4 v7 sedang eksekusi (Phase 1-4 sub-tasks). |

---

## Lampiran A — Cross-Reference dengan File Lain

| File | Tujuan |
|------|--------|
| `docs/decisions/security-architecture-final.md` | Source of truth keputusan security v7 (sudah final) |
| `workflow_mypresensi.md` | Diagram alur Mermaid — reference untuk non-teknis |
| `dev-log.md` | Log teknis tiap sesi |
| `CHANGELOG.md` | Daftar perubahan per sesi/tanggal |
| `.kiro/steering/00-mypresensi-overview.md` | Overview proyek, tech stack table, migration list |
| `.kiro/steering/04-security-and-privacy.md` | Aturan data classification, biometric handling |
| `.kiro/steering/13-web-nextjs-patterns.md` | Next.js patterns (Server vs Client, Route Handler) |
| `.kiro/steering/14-web-supabase-patterns.md` | RLS, query performance, schema design |

## Lampiran B — Migration History (v7 Active Range)

| Migration | Tujuan |
|-----------|--------|
| `001_initial_schema` | Profiles, face_embeddings, courses, enrollments, sessions, attendances, leave_requests, settings, audit_logs, rate_limit_log + RLS |
| `002_notifications` | Tabel notifications + RLS per user |
| `003_face_verification_mode` | Setting `face_verification_mode: optional\|required` (Phase 2 activate) |
| `004_campus_locations` | Tabel `campus_locations` + seed Politani (-0.5378, 117.1242) |
| `005_mobilefacenet_threshold` | Update threshold 0.75 → 0.65 (LFW MobileFaceNet 192-d) |
| `006_security_hardening` | REVOKE SELECT dari anon, audit_logs/notifications insert hanya service_role |
| `007_disable_graphql` | DROP `pg_graphql` extension (tidak dipakai) |
| `008_avatar_listing_hardening` | DROP broad SELECT bucket avatars |
| `009_rate_limit_log_explicit_policy` | Explicit DENY policy untuk silence advisor |
| `010_fk_indexes` | 6 FK index (audit_logs.user_id, courses.dosen_id, dll) |
| `011_rls_auth_initplan` | Refactor 21 policy: `auth.uid()` → `(SELECT auth.uid())` |
| `012_consolidate_permissive_policies` | Konsolidasi multi-permissive policies |
| `013_late_status` | Tambah enum `terlambat` + setting `late_threshold_minutes` |
| `014_device_id_audit` | Tambah `attendances.device_id` |
| `015_at_risk_function` | Function `get_at_risk_students` untuk widget at-risk |
| `016_attendances_realtime` | Aktifkan Supabase Realtime untuk monitor dosen |
| `017_seed_demo_data` | Seed 4 mahasiswa demo + 24 attendance rows untuk demo |
| `018_revoke_at_risk_function_public` | REVOKE public dari at_risk function |
| `019_leave_evidence_bucket` | Bucket `leave-evidence` untuk upload bukti izin/sakit |
| `020_realtime_attendances` | Enable Realtime publication untuk live monitor dosen |
| `021_session_started_at_index` | Index pada `sessions.started_at` untuk query historical |
| `022_rolling_qr_seed` (Phase 3) | Tambah `sessions.session_code_seed` untuk TOTP-like rolling QR ✅ Applied 22 Mei 2026 |
| ~~`021_manual_attendance_override`~~ | ~~Phase 4 manual override~~ — **DIHAPUS** (Phase 1.5 adjustment, lihat Bagian 4.4) |

