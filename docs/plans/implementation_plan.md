# MyPresensi — Implementation Plan v6 (Final)

> Sistem Absensi Face Recognition + Geolokasi
> **Prodi TRPL, Politeknik Pertanian Negeri Samarinda**
> Proyek PBL Semester 6 | Deadline: 4 Bulan (16 Minggu)

---

## Status: Menunggu Review & Approval Akhir

> [!IMPORTANT]
> **Ini adalah plan final yang mengunci semua keputusan teknis dan desain.**
> Setelah disetujui, tidak ada perubahan arsitektur — hanya eksekusi.
> Perubahan dari v5:
> - **Identitas Visual:** Ganti dari Logo Kampus (Politani) → **Logo Prodi (TRPL)**
> - **Warna:** Ganti dari Hijau Politani (`#1B6B3A`) → **Biru Baja TRPL (`#5483AD`)**
> - **Panduan Desain:** Ganti referensi IBM Carbon → **Mekari Talenta (Card-based, Ultra-Minimalist)**
> - **Navigasi Mobile:** Standard Bottom Navigation Bar (bukan floating)
> - **Komponen UI:** Card sudut tumpul (16px radius) + drop-shadow halus, Pill Button

---

## Bagian 1: Identitas Aplikasi

| Atribut | Nilai |
|---------|-------|
| **Nama Aplikasi** | MyPresensi |
| **Institusi** | Politeknik Pertanian Negeri Samarinda |
| **Prodi** | Teknik Rekayasa Perangkat Lunak (TRPL) |
| **Logo** | `gambar/Prodi/TRPL.jpg` |
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

### Stack Utama

| Komponen | Teknologi | Alasan |
|----------|-----------|--------|
| **Mobile** | Flutter 3.x (Dart) | Satu codebase Android+iOS, performa ML native, akses hardware kamera langsung |
| **Web** | Next.js 14 (React) | Server Components: API key tidak pernah muncul di browser |
| **Backend** | Supabase (PostgreSQL) | Auth built-in, RLS, Edge Functions, Storage, Real-time — semua tanpa konfigurasi server |
| **Face Detection** | google_mlkit_face_detection | Deteksi cepat, berjalan on-device (offline) |
| **Face Encoding** | tflite_flutter + MobileFaceNet | Embedding 128D di perangkat mahasiswa, tidak perlu server ML |
| **Liveness** | Active Challenge (kedip + senyum, urutan random) | Menolak foto/video spoofing |
| **State Management** | Riverpod | Type-safe, testable, compile-time safe |
| **Navigasi** | GoRouter | Deep link support, declarative routing |

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

## Bagian 4: Arsitektur Keamanan (DevSecOps)

### 4.1 Anti-Fake GPS — 6 Layer

| Layer | Metode | Cara Kerja |
|-------|--------|------------|
| **1** | `isMockLocation()` | Deteksi developer mode / GPS palsu dari OS |
| **2** | WiFi SSID Matching | Wajib terkoneksi `Politani_Samarinda_University` |
| **3** | Teleportation Detection | Kecepatan perpindahan > 100 km/jam = reject |
| **4** | GPS vs Cell Tower | Cross-reference koordinat GPS dengan tower seluler |
| **5** | Server-side Revalidation | Edge Function memvalidasi ulang payload di server |
| **6** | Face Recognition | Wajah fisik mahasiswa harus hadir di depan kamera |

### 4.2 Threat Model

| Serangan | Mitigasi |
|----------|----------|
| Brute Force | Rate limit + lockout 30 menit setelah 5x gagal |
| Session Hijacking | `flutter_secure_storage` + refresh token rotation + 15-menit access token |
| Photo Spoofing | Liveness: kedip + senyum + gerak kepala, urutan acak |
| Video Replay | Challenge berbeda tiap sesi + texture analysis |
| Embedding Theft | AES-256 encrypted + RLS (hanya pemilik yang bisa akses) |
| MITM | HTTPS + certificate pinning (Dio) |
| Root / Emulator | freeRASP: deteksi root, emulator, hook, tampering |
| SQL Injection | Parameterized queries + Zod server validation |
| IDOR | RLS: `auth.uid() = student_id` per baris |
| Mass Assignment | Whitelist field di Edge Function |

### 4.3 Mode Absen: Offline vs Online

| Aspek | Offline (Tatap Muka) | Online (Daring) |
|-------|----------------------|-----------------|
| GPS | Wajib (6 layer aktif) | Dinonaktifkan |
| WiFi | Wajib (Politani SSID) | Dinonaktifkan |
| Mock Detection | Aktif | Dinonaktifkan |
| Face Recognition | Wajib + liveness | Wajib + liveness |
| Kode Sesi | Tidak perlu | Wajib (6 digit, expired 3 menit) |
| Audit | GPS + WiFi + device ID | IP + device ID + timestamp |

> Dosen memilih mode saat membuat sesi. Face recognition **selalu aktif** di kedua mode.

---

## Bagian 5: Fitur Lengkap Per Role

### Mahasiswa (Mobile App)

| Fitur | Deskripsi |
|-------|-----------|
| Login + Force Change Password | Login pertama wajib ganti password |
| Registrasi Wajah | Capture + liveness 1x. Re-register jika perlu. |
| Absen Offline | Face recognition + GPS 6-layer + WiFi |
| Absen Online | Kode sesi 6 digit + face recognition |
| **Ajukan Izin/Sakit** | Submit request + lampiran bukti, dosen approve/reject |
| Dashboard | Jadwal hari ini, sesi aktif, persentase kehadiran, request pending |
| Riwayat Absensi | Per mata kuliah, filter status, calendar view |
| Statistik Pribadi | Chart kehadiran per mata kuliah |
| Profil | Edit info, re-register wajah, ganti password |
| Notifikasi | Sesi aktif, kehadiran di bawah 80%, status izin |

### Dosen (Mobile App)

| Fitur | Deskripsi |
|-------|-----------|
| Buat Sesi | Pilih MK, topik, mode (offline/online), durasi |
| Monitor Real-time | Daftar hadir live saat sesi berlangsung |
| Tutup Sesi | Close manual + auto-alpa untuk yang belum absen |
| **Review Izin/Sakit** | Approve/reject request + lihat bukti foto mahasiswa |
| Rekap Kehadiran | Tabel per MK, download rekap |
| Statistik Kelas | Visualisasi tren kehadiran |

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
- Logo yang digunakan: **Logo Prodi TRPL** (`gambar/Prodi/TRPL.jpg`)

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
| Bottom Nav Bar | Standard (tidak floating), 4 item: Home, Absen, Riwayat, Profil |
| Status Badge | Bulat, warna solid: Hijau=Hadir, Kuning=Izin/Sakit, Merah=Alpa |
| Tabel Web | Tanpa garis vertical, row hover highlight, status badge |
| Input Field | `border-radius: 8px`, placeholder abu-abu, focus color: primary |

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
-- FACE EMBEDDINGS (enkripsi)
-- ===========================
CREATE TABLE face_embeddings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  embedding BYTEA NOT NULL,         -- AES-256 encrypted 128D vector
  embedding_hash TEXT NOT NULL,     -- untuk deteksi duplikat
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
CREATE TABLE attendances (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('hadir', 'izin', 'sakit', 'alpa')) DEFAULT 'hadir',
  scanned_at TIMESTAMPTZ DEFAULT NOW(),
  -- Geolocation audit
  student_lat DOUBLE PRECISION,
  student_lng DOUBLE PRECISION,
  distance_meters DOUBLE PRECISION,
  is_location_valid BOOLEAN,
  is_mock_location BOOLEAN DEFAULT FALSE,
  wifi_ssid TEXT,
  -- Face Recognition audit
  face_confidence DOUBLE PRECISION,
  is_face_matched BOOLEAN,
  is_liveness_passed BOOLEAN,
  -- Device audit
  device_model TEXT,
  device_os TEXT,
  ip_address TEXT,
  session_mode TEXT,
  UNIQUE(session_id, student_id)
);

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

-- Default settings
INSERT INTO settings (key, value, description) VALUES
  ('geofence_radius_meters', '150', 'Radius default geofencing kampus'),
  ('face_confidence_threshold', '0.75', 'Batas minimum confidence face recognition'),
  ('session_code_expiry_minutes', '3', 'Durasi kode sesi online'),
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
-- ROW LEVEL SECURITY (RLS)
-- ===========================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE face_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendances ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;

-- Mahasiswa hanya bisa akses data milik sendiri
CREATE POLICY "Student own data" ON attendances
  FOR ALL USING (auth.uid() = student_id);

CREATE POLICY "Student own leave" ON leave_requests
  FOR ALL USING (auth.uid() = student_id);

-- Dosen bisa akses sesi & absensi yang dibuatnya
CREATE POLICY "Dosen own sessions" ON sessions
  FOR ALL USING (auth.uid() = dosen_id);

-- Embedding hanya bisa diakses pemiliknya
CREATE POLICY "User own embedding" ON face_embeddings
  FOR ALL USING (auth.uid() = user_id);

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
├── gambar/
│   ├── Logo-Kampus/Politani.png
│   └── Prodi/TRPL.jpg             ← Logo yang digunakan di aplikasi
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
├── mypresensi-web/                ← Next.js 14
│   ├── src/
│   │   ├── app/
│   │   │   ├── (auth)/login/
│   │   │   ├── (dashboard)/
│   │   │   │   ├── dashboard/
│   │   │   │   ├── dosen/
│   │   │   │   ├── mahasiswa/
│   │   │   │   ├── matakuliah/
│   │   │   │   ├── rekap/
│   │   │   │   ├── export/
│   │   │   │   ├── settings/
│   │   │   │   └── audit/
│   │   │   └── globals.css
│   │   ├── components/
│   │   ├── lib/supabase/
│   │   └── middleware.js          ← Auth guard server-side
│   └── package.json
│
└── supabase/
    ├── migrations/
    ├── functions/
    │   ├── validate-attendance/   ← Server-side geofence revalidation
    │   ├── generate-session-code/
    │   └── process-csv-import/    ← Bulk create accounts dari CSV
    └── seed.sql
```

---

## Bagian 11: Dependencies Flutter

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Backend
  supabase_flutter: ^2.5.0

  # Face Recognition
  google_mlkit_face_detection: ^0.11.0
  tflite_flutter: ^0.10.0
  image: ^4.1.0
  camera: ^0.11.0

  # Location
  geolocator: ^12.0.0
  network_info_plus: ^5.0.0        # WiFi SSID detection

  # Security
  flutter_secure_storage: ^9.0.0
  freeraspp: ^6.0.0                # Anti-tampering / root detection
  crypto: ^3.0.0                   # AES-256 encryption
  dio: ^5.4.0                      # SSL pinning

  # Navigation
  go_router: ^14.0.0

  # UI
  flutter_animate: ^4.5.0          # Micro-animations
  shimmer: ^3.0.0                  # Loading skeleton
  fl_chart: ^0.68.0               # Charts statistik
  google_fonts: ^6.2.0            # Plus Jakarta Sans + Inter
  phosphor_flutter: ^2.1.0        # Icons
  image_picker: ^1.0.0            # Upload bukti izin

  # Utils
  intl: ^0.19.0
  connectivity_plus: ^6.0.0
  permission_handler: ^11.3.0
  uuid: ^4.3.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  envied: ^0.5.0                  # Env variable encryption

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.7.0
  riverpod_generator: ^2.3.0
  envied_generator: ^0.5.0
```

---

## Bagian 12: Timeline Pengembangan (16 Minggu)

### Fase 1: Foundation (Minggu 1–3)

| Minggu | Target |
|--------|--------|
| **1** | Setup proyek Flutter + Next.js + Supabase. DB migration + RLS. Konfigurasi auth. |
| **2** | Mobile: Splash, onboarding, login, force change password, role routing, theme TRPL. |
| **3** | Web: Login, sidebar, dashboard shell, middleware. CSV import (dosen + mahasiswa). |

**Deliverable Fase 1:** Mahasiswa dan dosen bisa login dan diarahkan ke halaman masing-masing.

### Fase 2: Core Features (Minggu 4–8)

| Minggu | Target |
|--------|--------|
| **4** | Registrasi wajah: kamera + ML Kit + liveness challenge + TFLite embedding + simpan ke DB. |
| **5** | Absensi: face matching + confidence check + catat ke tabel attendances. |
| **6** | Geolokasi: GPS + 6-layer mock detection + WiFi SSID + Edge Function revalidation. |
| **7** | Manajemen sesi dosen: buat sesi (offline/online) + real-time monitor + tutup sesi. |
| **8** | Web admin: CRUD dosen/mahasiswa/MK/enrollment + DataTable. |

**Deliverable Fase 2:** Mahasiswa bisa absen lengkap (face + GPS). Dosen bisa kelola sesi.

### Fase 3: Dashboard & Fitur Tambahan (Minggu 9–12)

| Minggu | Target |
|--------|--------|
| **9** | Dashboard mahasiswa, riwayat absensi, calendar view kehadiran. |
| **10** | Fitur Izin/Sakit: submit + upload bukti + dosen approve/reject + notifikasi push. |
| **11** | Dashboard dosen (rekap + chart). Dashboard admin (overview + trend chart). |
| **12** | Export PDF + Excel (server-generated). Audit log lengkap. |

**Deliverable Fase 3:** Semua fitur fungsional dan terintegrasi.

### Fase 4: Hardening & Ship (Minggu 13–16)

| Minggu | Target |
|--------|--------|
| **13** | Security: cert pinning, freeRASP, code obfuscation, RLS audit, rate limiting. |
| **14** | UI Polish: loading states, skeleton screen, error handling, dark mode. |
| **15** | Testing: multi-device Android, akurasi face recognition, fake GPS, penetration test. |
| **16** | Deploy: APK release, Vercel deploy, seed data, README, demo video, persiapan presentasi. |

---

## Bagian 13: Rencana Verifikasi

### Security Testing
- [x] Fake GPS → Ditolak (semua 6 layer)
- [x] Root device / Emulator → Warning + block
- [x] MITM via proxy → Certificate pinning block
- [x] Akses data orang lain → RLS deny
- [x] Spam login → Lockout 30 menit
- [x] Foto di depan kamera → Liveness tolak

### Face Recognition Testing
- [x] Minimal 3 perangkat Android berbeda
- [x] Foto/video spoofing → Liveness tolak
- [x] Kondisi cahaya: terang, redup, lampu belakang
- [x] Target: < 3 detik per proses scan

### Functional Testing
- [x] Alur offline lengkap (face + GPS 6 layer)
- [x] Alur online lengkap (kode sesi + face)
- [x] Alur izin lengkap (submit → approve → status update)
- [x] CSV import 150+ baris
- [x] Export PDF + Excel
- [x] Edge case: kode sesi expired, double absen, mahasiswa di luar radius

### Code Quality Check
- [x] Tidak ada dead code (unused import, unused function)
- [x] Tidak ada logika duplikat
- [x] Semua network call punya try/catch dan user feedback
- [x] Semua function punya single responsibility

---

## Ringkasan Keputusan Final

| Keputusan | Pilihan |
|-----------|---------|
| Mobile Framework | Flutter |
| Web Framework | Next.js 14 |
| Backend | Supabase |
| Face Recognition | ML Kit + MobileFaceNet (on-device) |
| Anti-Fraud | 6-layer GPS + Liveness challenge |
| Akun Mahasiswa | Standalone CSV → SIA API ready |
| Logo | Prodi TRPL |
| Warna Utama | Biru TRPL `#5483AD` |
| Panduan Desain | Mekari Talenta (Card-based, Ultra-Minimalist) |
| Navigasi Mobile | Standard Bottom Nav Bar (4 item) |
| Fitur Izin/Sakit | Ada (mahasiswa submit, dosen approve) |
| State Management | Riverpod |
| Timeline | 16 Minggu (4 Fase) |
