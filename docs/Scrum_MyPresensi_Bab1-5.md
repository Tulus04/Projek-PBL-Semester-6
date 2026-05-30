# Dokumen Scrum — MyPresensi
## Sistem Absensi Mahasiswa 3-Layer Verifikasi

**Proyek PBL Semester 6 — Prodi TRPL, Politeknik Pertanian Negeri Samarinda**

| Informasi | Detail |
|-----------|--------|
| **Nama Proyek** | MyPresensi |
| **Mata Kuliah** | Project Based Learning (PBL) Semester 6 |
| **Program Studi** | Teknologi Rekayasa Perangkat Lunak (TRPL) |
| **Institusi** | Politeknik Pertanian Negeri Samarinda |
| **Periode** | April – Juni 2026 |
| **Tanggal Dokumen** | 20 Mei 2026 |

### Tim Pengembang

| Nama | Peran Scrum | Peran Teknis |
|------|-------------|-------------|
| Tulus Arya Danendra | Scrum Master | Full-Stack Developer |
| I Made Sachio Dharmayasa | Development Team | Front-End Developer |
| Abdul Latif | Development Team | Front-End Developer |
| Eza Aditya Dewangga | Development Team | Back-End Developer |
| Muhammad Mukhlis Adim | Development Team | Testing / QA |
| Annafi' Franz, S.Kom., M.Kom | Product Owner | Dosen Pembimbing |

---

# Bab 1: User Stories & Persona

## 1.1 Persona Pengguna

### Persona 1: Admin Prodi

| Atribut | Deskripsi |
|---------|-----------|
| **Nama** | Ibu Sari (representasi admin) |
| **Role** | Admin Prodi TRPL |
| **Usia** | 35-45 tahun |
| **Latar Belakang** | Staff administrasi prodi yang mengelola data akademik |
| **Kebutuhan** | Mengelola data mahasiswa, dosen, mata kuliah; memantau kehadiran secara keseluruhan; menghasilkan laporan untuk pimpinan |
| **Pain Points** | Rekap absensi manual rentan kesalahan, sulit memantau kehadiran real-time, proses export data lambat |
| **Tujuan** | Sistem otomatis yang bisa mengelola seluruh data presensi dan menghasilkan laporan akurat |

### Persona 2: Dosen Pengampu

| Atribut | Deskripsi |
|---------|-----------|
| **Nama** | Pak Andi (representasi dosen) |
| **Role** | Dosen Pengampu Mata Kuliah |
| **Usia** | 30-50 tahun |
| **Latar Belakang** | Dosen yang mengajar beberapa mata kuliah dan perlu memantau kehadiran |
| **Kebutuhan** | Membuat sesi presensi mudah, memantau siapa yang hadir real-time, approve izin/sakit |
| **Pain Points** | Proses absensi manual memakan waktu, tidak tahu siapa yang titip absen, susah rekap di akhir semester |
| **Tujuan** | Satu klik buat sesi → mahasiswa scan → langsung tahu siapa hadir |

### Persona 3: Mahasiswa

| Atribut | Deskripsi |
|---------|-----------|
| **Nama** | Budi (representasi mahasiswa) |
| **Role** | Mahasiswa Aktif Semester 6 TRPL |
| **Usia** | 20-23 tahun |
| **Latar Belakang** | Mahasiswa yang mengikuti perkuliahan harian dan perlu presensi setiap pertemuan |
| **Kebutuhan** | Presensi cepat dan mudah lewat HP, lihat riwayat kehadiran, ajukan izin jika tidak bisa hadir |
| **Pain Points** | Absensi kertas mudah dititipkan teman, tidak tahu persentase kehadiran sendiri |
| **Tujuan** | Presensi yang cepat (<30 detik), aman (tidak bisa dititip), dan bisa dipantau mandiri |

## 1.2 User Stories

| ID | User Story | Prioritas | Story Points |
|----|-----------|-----------|:------------:|
| US-01 | Sebagai **Admin**, saya ingin **login ke dashboard web** agar saya dapat mengelola sistem presensi. | Must | 3 |
| US-02 | Sebagai **Admin**, saya ingin **mengelola data mahasiswa** (tambah, edit, hapus, import CSV) agar data selalu akurat. | Must | 5 |
| US-03 | Sebagai **Admin**, saya ingin **mengelola data dosen** agar dosen dapat menggunakan sistem. | Must | 5 |
| US-04 | Sebagai **Admin**, saya ingin **mengelola mata kuliah dan enrollment** agar jadwal perkuliahan terstruktur. | Must | 5 |
| US-05 | Sebagai **Dosen**, saya ingin **membuat sesi presensi dan menampilkan QR Code** agar mahasiswa dapat melakukan absensi. | Must | 8 |
| US-06 | Sebagai **Mahasiswa**, saya ingin **scan QR Code** dari layar dosen agar saya dapat memulai proses presensi. | Must | 8 |
| US-07 | Sebagai **Mahasiswa**, saya ingin **lokasi GPS saya diverifikasi** agar sistem memastikan saya berada di kelas. | Must | 8 |
| US-08 | Sebagai **Mahasiswa**, saya ingin **wajah saya diverifikasi** agar identitas saya tidak bisa dipalsukan. | Must | 13 |
| US-09 | Sebagai **Dosen**, saya ingin **melihat rekap kehadiran per MK** agar saya dapat mengevaluasi partisipasi mahasiswa. | Must | 5 |
| US-10 | Sebagai **Mahasiswa**, saya ingin **melihat riwayat kehadiran saya** agar saya mengetahui persentase kehadiran. | Must | 5 |
| US-11 | Sebagai **Mahasiswa**, saya ingin **mengajukan izin/sakit** agar ketidakhadiran saya tercatat dengan alasan valid. | Must | 5 |
| US-12 | Sebagai **Dosen**, saya ingin **approve/reject pengajuan izin** agar kontrol kehadiran tetap di tangan dosen. | Must | 3 |
| US-13 | Sebagai **Admin**, saya ingin **mengkonfigurasi radius geofencing dan toleransi terlambat** agar parameter sesuai kondisi kampus. | Must | 3 |
| US-14 | Sebagai **Admin**, saya ingin **export data kehadiran ke CSV/PDF** agar bisa digunakan untuk pelaporan. | Should | 5 |
| US-15 | Sebagai **Admin**, saya ingin **melihat audit log** agar semua aksi tercatat untuk keamanan. | Should | 3 |
| US-16 | Sebagai **Dosen**, saya ingin **memonitor kehadiran real-time** saat sesi berlangsung dengan visualisasi geofence. | Should | 8 |
| US-17 | Sebagai **Dosen**, saya ingin **menampilkan QR fullscreen di proyektor** agar semua mahasiswa bisa scan. | Should | 5 |
| US-18 | Sebagai **Mahasiswa**, saya ingin **upload bukti surat sakit/izin** agar pengajuan saya lebih valid. | Should | 5 |
| US-19 | Sebagai **Pengguna**, saya ingin **bertanya ke AI assistant** tentang data presensi agar mendapat insight cepat. | Could | 8 |
| US-20 | Sebagai **Mahasiswa**, saya ingin **onboarding saat pertama install** agar saya tahu cara menggunakan aplikasi. | Could | 3 |
| US-21 | Sebagai **Mahasiswa**, saya ingin **upload foto profil** agar profil saya lebih personal. | Could | 3 |
| US-22 | Sebagai **Admin**, saya ingin **melihat mahasiswa berisiko alpa** agar bisa dilakukan intervensi dini. | Could | 5 |
| US-23 | Sebagai **Mahasiswa**, saya ingin **menghapus data wajah saya** agar sesuai hak UU PDP. | Could | 3 |
| US-24 | Sebagai **Dosen**, saya ingin **mengirim push notification** ke mahasiswa saat sesi dibuat. | Won't | 8 |
| US-25 | Sebagai **Admin**, saya ingin **monitoring & alerting otomatis** untuk deteksi anomali. | Won't | 5 |

**Total Story Points: 139 SP**

---

# Bab 2: Product Backlog

## 2.1 Product Backlog dengan Prioritas MoSCoW

| Prioritas | ID | Product Backlog Item | Story Points | Status |
|-----------|-----|---------------------|:------------:|--------|
| **Must Have** | US-01 | Autentikasi Web (Login, Logout, Change Password) | 3 | ✅ Done |
| **Must Have** | US-02 | CRUD Mahasiswa + Import CSV | 5 | ✅ Done |
| **Must Have** | US-03 | CRUD Dosen | 5 | ✅ Done |
| **Must Have** | US-04 | Manajemen Mata Kuliah & Enrollment | 5 | ✅ Done |
| **Must Have** | US-05 | Sesi Presensi + QR Code Generation | 8 | ✅ Done |
| **Must Have** | US-06 | Scan QR Code Mobile | 8 | ✅ Done |
| **Must Have** | US-07 | Verifikasi GPS + Anti Mock Location | 8 | ✅ Done |
| **Must Have** | US-08 | Face Recognition (Register + Verify) | 13 | ✅ Done |
| **Must Have** | US-09 | Rekap Kehadiran Dosen | 5 | ✅ Done |
| **Must Have** | US-10 | Riwayat Kehadiran Mahasiswa | 5 | ✅ Done |
| **Must Have** | US-11 | Pengajuan Izin/Sakit Mahasiswa | 5 | ✅ Done |
| **Must Have** | US-12 | Approve/Reject Izin Dosen | 3 | ✅ Done |
| **Must Have** | US-13 | Settings Geofence & Toleransi | 3 | ✅ Done |
| **Should Have** | US-14 | Export CSV/PDF | 5 | ✅ Done |
| **Should Have** | US-15 | Audit Log | 3 | ✅ Done |
| **Should Have** | US-16 | Live Monitor Real-time | 8 | ✅ Done |
| **Should Have** | US-17 | QR Display Fullscreen | 5 | ✅ Done |
| **Should Have** | US-18 | Upload Bukti Izin/Sakit | 5 | ✅ Done |
| **Could Have** | US-19 | AI Chatbot Assistant | 8 | ✅ Done |
| **Could Have** | US-20 | Onboarding Mobile | 3 | ✅ Done |
| **Could Have** | US-21 | Upload Foto Profil | 3 | ✅ Done |
| **Could Have** | US-22 | Dashboard At-Risk Students | 5 | ✅ Done |
| **Could Have** | US-23 | Hapus Data Wajah (UU PDP) | 3 | ✅ Done |
| **Won't Have** | US-24 | Push Notification FCM | 8 | ❌ Backlog |
| **Won't Have** | US-25 | Monitoring & Alerting | 5 | ❌ Backlog |

**Ringkasan:**
- Must Have: 76 SP → 100% selesai
- Should Have: 26 SP → 100% selesai
- Could Have: 22 SP → 100% selesai
- Won't Have: 13 SP → deferred ke rilis berikutnya

---

# Bab 3: Sprint Planning — Sprint 1

## Sprint 1: Foundation & Web Core

| Atribut | Detail |
|---------|--------|
| **Sprint Goal** | Membangun fondasi sistem web (autentikasi, database, dashboard) agar Admin bisa login dan melihat dashboard |
| **Durasi** | 6 April – 20 April 2026 (2 minggu) |
| **Kapasitas Tim** | 5 developer × 10 hari kerja = 50 person-days |
| **Velocity Target** | 40 SP (sprint pertama, konservatif) |
| **Sprint Backlog** | US-01, US-02, US-03, US-04, US-13 |

### User Stories yang Diambil ke Sprint 1

| ID | User Story | SP | PIC |
|----|-----------|:--:|-----|
| US-01 | Autentikasi Web | 3 | Tulus, Eza |
| US-02 | CRUD Mahasiswa + Import CSV | 5 | Sachio, Abdul Latif |
| US-03 | CRUD Dosen | 5 | Sachio, Abdul Latif |
| US-04 | Manajemen Mata Kuliah | 5 | Sachio, Abdul Latif |
| US-13 | Settings Geofence & Toleransi | 3 | Eza |
| — | Database Schema & Migration | 8 | Eza, Tulus |
| — | Design System & UI Framework | 5 | Sachio, Abdul Latif |
| — | Dashboard Admin & Dosen | 8 | Sachio, Abdul Latif, Eza |

**Total Sprint 1: 42 SP**

---

# Bab 4: Sprint Backlog — Sprint 1

| Task ID | User Story | Task | PIC | Estimasi | Status |
|---------|-----------|------|-----|:--------:|:------:|
| T1-01 | US-01 | Scaffold Next.js 14 + konfigurasi TypeScript | Tulus | 2 jam | ✅ Done |
| T1-02 | US-01 | Setup Supabase project + .env.local | Tulus, Eza | 1 jam | ✅ Done |
| T1-03 | US-01 | Buat Supabase client (server + browser) | Eza | 2 jam | ✅ Done |
| T1-04 | US-01 | Halaman Login (Server + Client Component) | Sachio | 4 jam | ✅ Done |
| T1-05 | US-01 | Server Action: login, logout, changePassword | Eza | 3 jam | ✅ Done |
| T1-06 | US-01 | Middleware route guard | Eza | 2 jam | ✅ Done |
| T1-07 | — | Design System (globals.css, Tailwind config, color tokens TRPL) | Sachio | 4 jam | ✅ Done |
| T1-08 | — | Type definitions (10 interface + 5 union types) | Eza | 2 jam | ✅ Done |
| T1-09 | — | Utility functions (11 helper) | Tulus | 2 jam | ✅ Done |
| T1-10 | — | SQL Migration 001: initial schema (10 tabel + RLS + triggers) | Eza | 6 jam | ✅ Done |
| T1-11 | — | SQL Migration 002-005 (notifications, face mode, campus locations, threshold) | Eza | 3 jam | ✅ Done |
| T1-12 | — | Dashboard Layout (Sidebar + Topbar) | Sachio, Abdul Latif | 4 jam | ✅ Done |
| T1-13 | — | Dashboard Admin (summary cards + tabel absensi) | Sachio | 4 jam | ✅ Done |
| T1-14 | US-02 | Halaman Mahasiswa (tabel + add modal + edit modal) | Abdul Latif | 8 jam | ✅ Done |
| T1-15 | US-02 | Import CSV mahasiswa + bulk create akun | Sachio | 6 jam | ✅ Done |
| T1-16 | US-03 | Halaman Dosen (tabel + CRUD) | Abdul Latif | 6 jam | ✅ Done |
| T1-17 | US-04 | Halaman Mata Kuliah (card grid + CRUD + enrollment) | Sachio | 8 jam | ✅ Done |
| T1-18 | US-13 | Halaman Settings (geofence radius, toleransi, face mode) | Abdul Latif | 4 jam | ✅ Done |
| T1-19 | — | Testing integrasi login → dashboard → CRUD | Mukhlis | 4 jam | ✅ Done |
| T1-20 | — | Bug fixing (5 bug ditemukan dan diperbaiki) | Tulus | 4 jam | ✅ Done |

**Realisasi Sprint 1: 42/42 SP selesai (100%)**

---

# Bab 5: Sprint Review — Sprint 1

## 5.1 Hasil Demo Sprint 1

| Tanggal Demo | 20 April 2026 |
|---|---|
| **Peserta** | Tim Development + Product Owner (Pak Annafi' Franz) |
| **Lokasi** | Kampus Politeknik Pertanian Negeri Samarinda |

### Fitur yang Di-demo-kan

| # | Fitur | Hasil | Feedback PO |
|---|-------|-------|-------------|
| 1 | Login web dengan email + password | ✅ Berhasil | Perlu force change password untuk keamanan |
| 2 | Dashboard admin (5 KPI cards + tabel absensi) | ✅ Berhasil | Tampilan sudah bagus, perlu chart di kemudian hari |
| 3 | CRUD Mahasiswa + Import CSV | ✅ Berhasil | Import CSV sangat membantu, perlu validasi NIM |
| 4 | CRUD Dosen | ✅ Berhasil | OK |
| 5 | Manajemen Mata Kuliah + Enrollment | ✅ Berhasil | Perlu assignment otomatis dari data CSV |
| 6 | Database schema (10 tabel + RLS) | ✅ Berhasil | Keamanan RLS sudah baik |
| 7 | Settings page | ✅ Berhasil | Default radius 100m sesuai kondisi kampus |

### 5.2 Product Backlog Update Pasca Sprint 1

- ✅ Semua US Sprint 1 diterima Product Owner
- 📝 Tambahan feedback: perlu halaman force change password
- 📝 Prioritas Sprint 2: mulai kerjakan mobile app + sesi presensi

### 5.3 Burndown Chart Data — Sprint 1

| Hari | SP Sisa (Ideal) | SP Sisa (Aktual) |
|:----:|:---------------:|:----------------:|
| 1 | 38 | 42 |
| 2 | 34 | 39 |
| 3 | 30 | 35 |
| 4 | 26 | 30 |
| 5 | 22 | 25 |
| 6 | 18 | 20 |
| 7 | 14 | 16 |
| 8 | 10 | 12 |
| 9 | 6 | 7 |
| 10 | 0 | 0 |

**Catatan:** Hari 1-4 aktual lebih lambat karena setup environment dan learning curve Supabase. Hari 5-10 percepatan karena tim sudah familiar.
