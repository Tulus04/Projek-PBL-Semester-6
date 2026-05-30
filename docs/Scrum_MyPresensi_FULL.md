# Dokumen Scrum â€” MyPresensi
## Sistem Absensi Mahasiswa 3-Layer Verifikasi

**Proyek PBL Semester 6 â€” Prodi TRPL, Politeknik Pertanian Negeri Samarinda**

| Informasi | Detail |
|-----------|--------|
| **Nama Proyek** | MyPresensi |
| **Mata Kuliah** | Project Based Learning (PBL) Semester 6 |
| **Program Studi** | Teknologi Rekayasa Perangkat Lunak (TRPL) |
| **Institusi** | Politeknik Pertanian Negeri Samarinda |
| **Periode** | April â€“ Juni 2026 |
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
| **Tujuan** | Satu klik buat sesi â†’ mahasiswa scan â†’ langsung tahu siapa hadir |

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
| **Must Have** | US-01 | Autentikasi Web (Login, Logout, Change Password) | 3 | âœ… Done |
| **Must Have** | US-02 | CRUD Mahasiswa + Import CSV | 5 | âœ… Done |
| **Must Have** | US-03 | CRUD Dosen | 5 | âœ… Done |
| **Must Have** | US-04 | Manajemen Mata Kuliah & Enrollment | 5 | âœ… Done |
| **Must Have** | US-05 | Sesi Presensi + QR Code Generation | 8 | âœ… Done |
| **Must Have** | US-06 | Scan QR Code Mobile | 8 | âœ… Done |
| **Must Have** | US-07 | Verifikasi GPS + Anti Mock Location | 8 | âœ… Done |
| **Must Have** | US-08 | Face Recognition (Register + Verify) | 13 | âœ… Done |
| **Must Have** | US-09 | Rekap Kehadiran Dosen | 5 | âœ… Done |
| **Must Have** | US-10 | Riwayat Kehadiran Mahasiswa | 5 | âœ… Done |
| **Must Have** | US-11 | Pengajuan Izin/Sakit Mahasiswa | 5 | âœ… Done |
| **Must Have** | US-12 | Approve/Reject Izin Dosen | 3 | âœ… Done |
| **Must Have** | US-13 | Settings Geofence & Toleransi | 3 | âœ… Done |
| **Should Have** | US-14 | Export CSV/PDF | 5 | âœ… Done |
| **Should Have** | US-15 | Audit Log | 3 | âœ… Done |
| **Should Have** | US-16 | Live Monitor Real-time | 8 | âœ… Done |
| **Should Have** | US-17 | QR Display Fullscreen | 5 | âœ… Done |
| **Should Have** | US-18 | Upload Bukti Izin/Sakit | 5 | âœ… Done |
| **Could Have** | US-19 | AI Chatbot Assistant | 8 | âœ… Done |
| **Could Have** | US-20 | Onboarding Mobile | 3 | âœ… Done |
| **Could Have** | US-21 | Upload Foto Profil | 3 | âœ… Done |
| **Could Have** | US-22 | Dashboard At-Risk Students | 5 | âœ… Done |
| **Could Have** | US-23 | Hapus Data Wajah (UU PDP) | 3 | âœ… Done |
| **Won't Have** | US-24 | Push Notification FCM | 8 | âŒ Backlog |
| **Won't Have** | US-25 | Monitoring & Alerting | 5 | âŒ Backlog |

**Ringkasan:**
- Must Have: 76 SP â†’ 100% selesai
- Should Have: 26 SP â†’ 100% selesai
- Could Have: 22 SP â†’ 100% selesai
- Won't Have: 13 SP â†’ deferred ke rilis berikutnya

---

# Bab 3: Sprint Planning â€” Sprint 1

## Sprint 1: Foundation & Web Core

| Atribut | Detail |
|---------|--------|
| **Sprint Goal** | Membangun fondasi sistem web (autentikasi, database, dashboard) agar Admin bisa login dan melihat dashboard |
| **Durasi** | 6 April â€“ 20 April 2026 (2 minggu) |
| **Kapasitas Tim** | 5 developer Ã— 10 hari kerja = 50 person-days |
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
| â€” | Database Schema & Migration | 8 | Eza, Tulus |
| â€” | Design System & UI Framework | 5 | Sachio, Abdul Latif |
| â€” | Dashboard Admin & Dosen | 8 | Sachio, Abdul Latif, Eza |

**Total Sprint 1: 42 SP**

---

# Bab 4: Sprint Backlog â€” Sprint 1

| Task ID | User Story | Task | PIC | Estimasi | Status |
|---------|-----------|------|-----|:--------:|:------:|
| T1-01 | US-01 | Scaffold Next.js 14 + konfigurasi TypeScript | Tulus | 2 jam | âœ… Done |
| T1-02 | US-01 | Setup Supabase project + .env.local | Tulus, Eza | 1 jam | âœ… Done |
| T1-03 | US-01 | Buat Supabase client (server + browser) | Eza | 2 jam | âœ… Done |
| T1-04 | US-01 | Halaman Login (Server + Client Component) | Sachio | 4 jam | âœ… Done |
| T1-05 | US-01 | Server Action: login, logout, changePassword | Eza | 3 jam | âœ… Done |
| T1-06 | US-01 | Middleware route guard | Eza | 2 jam | âœ… Done |
| T1-07 | â€” | Design System (globals.css, Tailwind config, color tokens TRPL) | Sachio | 4 jam | âœ… Done |
| T1-08 | â€” | Type definitions (10 interface + 5 union types) | Eza | 2 jam | âœ… Done |
| T1-09 | â€” | Utility functions (11 helper) | Tulus | 2 jam | âœ… Done |
| T1-10 | â€” | SQL Migration 001: initial schema (10 tabel + RLS + triggers) | Eza | 6 jam | âœ… Done |
| T1-11 | â€” | SQL Migration 002-005 (notifications, face mode, campus locations, threshold) | Eza | 3 jam | âœ… Done |
| T1-12 | â€” | Dashboard Layout (Sidebar + Topbar) | Sachio, Abdul Latif | 4 jam | âœ… Done |
| T1-13 | â€” | Dashboard Admin (summary cards + tabel absensi) | Sachio | 4 jam | âœ… Done |
| T1-14 | US-02 | Halaman Mahasiswa (tabel + add modal + edit modal) | Abdul Latif | 8 jam | âœ… Done |
| T1-15 | US-02 | Import CSV mahasiswa + bulk create akun | Sachio | 6 jam | âœ… Done |
| T1-16 | US-03 | Halaman Dosen (tabel + CRUD) | Abdul Latif | 6 jam | âœ… Done |
| T1-17 | US-04 | Halaman Mata Kuliah (card grid + CRUD + enrollment) | Sachio | 8 jam | âœ… Done |
| T1-18 | US-13 | Halaman Settings (geofence radius, toleransi, face mode) | Abdul Latif | 4 jam | âœ… Done |
| T1-19 | â€” | Testing integrasi login â†’ dashboard â†’ CRUD | Mukhlis | 4 jam | âœ… Done |
| T1-20 | â€” | Bug fixing (5 bug ditemukan dan diperbaiki) | Tulus | 4 jam | âœ… Done |

**Realisasi Sprint 1: 42/42 SP selesai (100%)**

---

# Bab 5: Sprint Review â€” Sprint 1

## 5.1 Hasil Demo Sprint 1

| Tanggal Demo | 20 April 2026 |
|---|---|
| **Peserta** | Tim Development + Product Owner (Pak Annafi' Franz) |
| **Lokasi** | Kampus Politeknik Pertanian Negeri Samarinda |

### Fitur yang Di-demo-kan

| # | Fitur | Hasil | Feedback PO |
|---|-------|-------|-------------|
| 1 | Login web dengan email + password | âœ… Berhasil | Perlu force change password untuk keamanan |
| 2 | Dashboard admin (5 KPI cards + tabel absensi) | âœ… Berhasil | Tampilan sudah bagus, perlu chart di kemudian hari |
| 3 | CRUD Mahasiswa + Import CSV | âœ… Berhasil | Import CSV sangat membantu, perlu validasi NIM |
| 4 | CRUD Dosen | âœ… Berhasil | OK |
| 5 | Manajemen Mata Kuliah + Enrollment | âœ… Berhasil | Perlu assignment otomatis dari data CSV |
| 6 | Database schema (10 tabel + RLS) | âœ… Berhasil | Keamanan RLS sudah baik |
| 7 | Settings page | âœ… Berhasil | Default radius 100m sesuai kondisi kampus |

### 5.2 Product Backlog Update Pasca Sprint 1

- âœ… Semua US Sprint 1 diterima Product Owner
- ðŸ“ Tambahan feedback: perlu halaman force change password
- ðŸ“ Prioritas Sprint 2: mulai kerjakan mobile app + sesi presensi

### 5.3 Burndown Chart Data â€” Sprint 1

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
# Bab 6: Sprint Retrospective â€” Sprint 1

## 6.1 Retrospective Meeting

| Atribut | Detail |
|---------|--------|
| **Tanggal** | 20 April 2026 |
| **Fasilitator** | Tulus Arya Danendra (Scrum Master) |
| **Peserta** | Seluruh Development Team |
| **Format** | What Went Well / What Didn't / Action Items |

## 6.2 What Went Well âœ…

1. **Scaffold cepat** â€” Next.js 14 + Supabase berhasil di-setup dalam 1 sesi pertama
2. **Design system solid** â€” Color token TRPL, CSS utility class, dan component pattern terbentuk di awal sehingga konsisten
3. **Database schema komprehensif** â€” 10 tabel + 11 index + RLS policies selesai dalam 1 migration
4. **Import CSV mahasiswa** berfungsi baik, menghemat waktu admin vs input manual
5. **Kolaborasi front-end** â€” Sachio dan Abdul Latif bisa paralel mengerjakan halaman berbeda tanpa konflik

## 6.3 What Didn't Go Well âŒ

1. **Setup environment lambat** â€” Hari 1-2 banyak waktu terbuang untuk konfigurasi (path alias, env variable, Supabase project)
2. **5 bug ditemukan** saat integrasi (package.json kosong, 404 route, middleware crash, useActionState React 19 vs 18, import path)
3. **Belum ada automated testing** â€” QA belum bisa mulai karena test framework belum di-setup
4. **Mobile app belum dimulai** â€” Flutter SDK masih dalam proses instalasi

## 6.4 Action Items

| # | Action Item | PIC | Target |
|---|------------|-----|--------|
| 1 | Buat checklist setup environment untuk developer baru | Tulus | Sprint 2 |
| 2 | Setup Flutter project dan pastikan `flutter doctor` pass | Tulus | Sprint 2 awal |
| 3 | Buat halaman force change password | Eza | Sprint 2 |
| 4 | Mulai test plan untuk fitur inti (login, CRUD) | Mukhlis | Sprint 2 |
| 5 | Dokumentasi API endpoint untuk tim mobile | Eza | Sprint 2 |

---

# Bab 7: Sprint Planning â€” Sprint 2

## Sprint 2: Mobile Core & Presensi Flow

| Atribut | Detail |
|---------|--------|
| **Sprint Goal** | Mengembangkan mobile app mahasiswa dan flow presensi inti (scan QR â†’ GPS â†’ submit) agar mahasiswa bisa melakukan presensi |
| **Durasi** | 21 April â€“ 4 Mei 2026 (2 minggu) |
| **Velocity Referensi** | 42 SP (Sprint 1) |
| **Velocity Target** | 47 SP |

### User Stories yang Diambil ke Sprint 2

| ID | User Story | SP | PIC |
|----|-----------|:--:|-----|
| US-05 | Sesi Presensi + QR Code + OTP | 8 | Eza, Sachio |
| US-06 | Scan QR Code Mobile | 8 | Tulus |
| US-07 | Verifikasi GPS + Anti Mock Location | 8 | Tulus, Eza |
| US-09 | Rekap Kehadiran Dosen | 5 | Abdul Latif |
| US-10 | Riwayat Kehadiran Mahasiswa (Mobile) | 5 | Sachio |
| US-11 | Pengajuan Izin/Sakit | 5 | Abdul Latif, Tulus |
| US-12 | Approve/Reject Izin Dosen | 3 | Abdul Latif |
| â€” | Mobile App Foundation (auth, routing, theme) | 5 | Tulus |

**Total Sprint 2: 47 SP**

---

# Bab 8: Sprint Backlog â€” Sprint 2

| Task ID | User Story | Task | PIC | Status |
|---------|-----------|------|-----|:------:|
| T2-01 | â€” | Scaffold Flutter project + konfigurasi | Tulus | âœ… Done |
| T2-02 | â€” | Setup Riverpod 3 + GoRouter + Dio client | Tulus | âœ… Done |
| T2-03 | â€” | Mobile design system (AppColors, AppTheme, AppShadows) | Sachio | âœ… Done |
| T2-04 | â€” | Mobile login screen + auth provider | Tulus | âœ… Done |
| T2-05 | â€” | Mobile splash screen + routing guard | Tulus | âœ… Done |
| T2-06 | â€” | Bottom navigation (AppShell) + 5 tab | Sachio | âœ… Done |
| T2-07 | US-05 | Web: Halaman sesi presensi (buat/tutup sesi) | Eza | âœ… Done |
| T2-08 | US-05 | Web: QR Code generation + OTP 6-digit | Eza | âœ… Done |
| T2-09 | US-05 | API Route: POST/GET sesi + session_code | Eza | âœ… Done |
| T2-10 | US-06 | Mobile: Scan QR screen (camera + decode) | Tulus | âœ… Done |
| T2-11 | US-07 | Mobile: Location service (Haversine + mock detection) | Tulus | âœ… Done |
| T2-12 | US-07 | API: Attendance submit (6-layer validation) | Eza | âœ… Done |
| T2-13 | US-06+07 | Mobile: Attendance result screen (success/fail UI) | Sachio | âœ… Done |
| T2-14 | US-09 | Web: Halaman rekap kehadiran (filter + tabel) | Abdul Latif | âœ… Done |
| T2-15 | US-14 | Web: Export CSV/PDF | Abdul Latif | âœ… Done |
| T2-16 | US-10 | Mobile: History screen + provider | Sachio | âœ… Done |
| T2-17 | US-11 | Mobile: Submit leave request screen | Tulus | âœ… Done |
| T2-18 | US-11 | API: POST leave request + file logic | Eza | âœ… Done |
| T2-19 | US-12 | Web: Halaman izin dosen (approve/reject) | Abdul Latif | âœ… Done |
| T2-20 | US-15 | Web: Halaman audit log | Abdul Latif | âœ… Done |
| T2-21 | â€” | Mobile: Notification screen | Sachio | âœ… Done |
| T2-22 | â€” | Mobile: Profile screen + change password | Tulus | âœ… Done |
| T2-23 | â€” | Testing integrasi mobile â†” web API | Mukhlis | âœ… Done |
| T2-24 | â€” | Bug fixing QR field mismatch + face migration | Tulus | âœ… Done |

**Realisasi Sprint 2: 47/47 SP selesai (100%)**

---

# Bab 9: Sprint Review â€” Sprint 2

## 9.1 Hasil Demo Sprint 2

| Tanggal Demo | 4 Mei 2026 |
|---|---|
| **Peserta** | Tim Development + Product Owner |
| **Lokasi** | Kampus Politeknik Pertanian Negeri Samarinda |

### Fitur yang Di-demo-kan

| # | Fitur | Hasil | Feedback PO |
|---|-------|-------|-------------|
| 1 | Mobile login + splash screen | âœ… Berhasil | Tampilan sudah baik |
| 2 | Dosen buat sesi â†’ QR Code + OTP muncul | âœ… Berhasil | Perlu QR fullscreen untuk proyektor |
| 3 | Mahasiswa scan QR â†’ GPS check â†’ submit | âœ… Berhasil | Core flow berjalan, face verification belum |
| 4 | Anti mock GPS (isMocked reject) | âœ… Berhasil | Fitur anti-kecurangan kritis, harus dipertahankan |
| 5 | Rekap kehadiran + export CSV | âœ… Berhasil | Sangat membantu untuk evaluasi |
| 6 | Submit izin/sakit + approve dosen | âœ… Berhasil | Perlu upload bukti surat sakit |
| 7 | Riwayat kehadiran mahasiswa | âœ… Berhasil | Perlu tampilan persentase kehadiran |
| 8 | Audit log | âœ… Berhasil | Bagus untuk tracking aksi |

### 9.2 Feedback & Backlog Update

- ðŸ“ **Prioritas tinggi:** Face Recognition harus segera diimplementasi (layer keamanan ke-3)
- ðŸ“ **Tambahan:** QR display fullscreen untuk proyektor
- ðŸ“ **Tambahan:** Upload bukti izin/sakit
- ðŸ“ **Perbaikan:** UI mobile perlu di-polish agar lebih premium

### 9.3 Burndown Chart Data â€” Sprint 2

| Hari | SP Sisa (Ideal) | SP Sisa (Aktual) |
|:----:|:---------------:|:----------------:|
| 1 | 42 | 47 |
| 2 | 38 | 44 |
| 3 | 33 | 39 |
| 4 | 28 | 33 |
| 5 | 24 | 28 |
| 6 | 19 | 22 |
| 7 | 14 | 17 |
| 8 | 9 | 12 |
| 9 | 5 | 5 |
| 10 | 0 | 0 |

---

# Bab 10: Sprint Retrospective â€” Sprint 2

## 10.1 What Went Well âœ…

1. **Mobile app fungsional** â€” Dalam 2 minggu, app sudah bisa login â†’ scan QR â†’ submit presensi
2. **GPS Haversine + mock detection bekerja sempurna** â€” Anti-kecurangan layer 2 berhasil
3. **API design konsisten** â€” Pola autentikasi Bearer + rate limit terstandardisasi
4. **Paralelisasi efektif** â€” Tim web dan mobile bisa bekerja bersamaan tanpa blocking
5. **Velocity naik dari 42 â†’ 47 SP** â€” Tim semakin familiar dengan tech stack

## 10.2 What Didn't Go Well âŒ

1. **Face Recognition belum masuk Sprint 2** â€” Terlalu banyak task sesi presensi yang harus diselesaikan dulu
2. **Bug QR field mismatch** (sid vs session_id) memakan waktu debug
3. **UI mobile masih basic** â€” Menggunakan Material Icons default, belum premium
4. **Test coverage masih minim** â€” QA baru bisa test secara manual

## 10.3 Action Items

| # | Action Item | PIC | Target |
|---|------------|-----|--------|
| 1 | Implementasi Face Recognition (MobileFaceNet) sebagai prioritas #1 | Tulus, Eza | Sprint 3 |
| 2 | Pindahkan face comparison ke server-side (security) | Eza | Sprint 3 |
| 3 | Upgrade icon system ke Iconsax (premium look) | Sachio | Sprint 3 |
| 4 | Polish UI mobile sesuai mockup yang sudah dibuat | Sachio, Abdul Latif | Sprint 3 |
| 5 | Setup smoke test checklist | Mukhlis | Sprint 3 |
# Bab 11: Sprint Planning â€” Sprint 3

## Sprint 3: Security Hardening & Advanced Features

| Atribut | Detail |
|---------|--------|
| **Sprint Goal** | Mengimplementasikan face recognition (layer keamanan ke-3), fitur advanced (live monitor, AI chatbot, QR fullscreen), dan hardening keamanan sistem |
| **Durasi** | 5 Mei â€“ 18 Mei 2026 (2 minggu) |
| **Velocity Referensi** | Rata-rata Sprint 1+2 = (42+47)/2 = 44.5 SP |
| **Velocity Target** | 50 SP |

### User Stories yang Diambil ke Sprint 3

| ID | User Story | SP | PIC |
|----|-----------|:--:|-----|
| US-08 | Face Recognition (Register + Verify) | 13 | Tulus, Eza |
| US-16 | Live Monitor Real-time + Geofence Ring | 8 | Sachio, Abdul Latif |
| US-17 | QR Display Fullscreen | 5 | Abdul Latif |
| US-18 | Upload Bukti Izin/Sakit (Signed URL) | 5 | Eza |
| US-19 | AI Chatbot (Gemini 2.5 Flash) | 8 | Tulus, Eza |
| US-20 | Onboarding Mobile 3-Step | 3 | Sachio |
| US-21 | Upload Foto Profil | 3 | Sachio |
| US-22 | Dashboard At-Risk Students | 5 | Abdul Latif |
| US-23 | Hapus Data Wajah (UU PDP) | 3 | Tulus |

**Total Sprint 3: 53 SP** (stretch target karena velocity naik)

---

# Bab 12: Sprint Backlog â€” Sprint 3

| Task ID | User Story | Task | PIC | Status |
|---------|-----------|------|-----|:------:|
| T3-01 | US-08 | Integrasi MobileFaceNet TFLite (192-D embedding) | Tulus | âœ… Done |
| T3-02 | US-08 | Face registration screen (capture + extract + upload) | Tulus | âœ… Done |
| T3-03 | US-08 | API: POST /face/register (simpan embedding ke DB) | Eza | âœ… Done |
| T3-04 | US-08 | Face verification screen (capture + compare) | Tulus | âœ… Done |
| T3-05 | US-08 | API: POST /face/verify (server-side cosine similarity, threshold 0.65) | Eza | âœ… Done |
| T3-06 | US-08 | SQL Migration: face_embeddings table + RLS | Eza | âœ… Done |
| T3-07 | US-08 | Integrasi face verify ke attendance flow (wajib sebelum submit) | Tulus | âœ… Done |
| T3-08 | US-16 | Web: Live monitor component (SVG geofence ring) | Sachio | âœ… Done |
| T3-09 | US-16 | Supabase Realtime subscription (attendance channel) | Eza | âœ… Done |
| T3-10 | US-16 | Live attendance stats (hadir/belum/terlambat counter) | Abdul Latif | âœ… Done |
| T3-11 | US-17 | QR Display fullscreen (projector mode, auto-scale) | Abdul Latif | âœ… Done |
| T3-12 | US-18 | Supabase Storage: bucket izin + signed URL | Eza | âœ… Done |
| T3-13 | US-18 | Mobile: upload file picker + compress | Tulus | âœ… Done |
| T3-14 | US-18 | Web: preview bukti izin (signed URL, image viewer) | Abdul Latif | âœ… Done |
| T3-15 | US-19 | API: POST /ai/chat (Gemini 2.5 Flash, streaming) | Eza | âœ… Done |
| T3-16 | US-19 | Web: AI chatbot panel (context-aware, markdown render) | Sachio | âœ… Done |
| T3-17 | US-19 | Mobile: AI chatbot screen | Tulus | âœ… Done |
| T3-18 | US-20 | Mobile: Onboarding 3-step (info carousel + permission) | Sachio | âœ… Done |
| T3-19 | US-21 | Mobile: Avatar upload + crop | Sachio | âœ… Done |
| T3-20 | US-22 | Web: Dashboard widget at-risk students (RPC + card) | Abdul Latif | âœ… Done |
| T3-21 | US-22 | Supabase RPC: get_at_risk_students + security (revoke public) | Eza | âœ… Done |
| T3-22 | US-23 | Mobile: Hapus data wajah (2-step UU PDP: edukasi + konfirmasi) | Tulus | âœ… Done |
| T3-23 | â€” | RLS consolidation (10 tabel, drop-recreate) | Eza | âœ… Done |
| T3-24 | â€” | Rate limiting per-device (composite key userId:deviceId) | Eza | âœ… Done |
| T3-25 | â€” | Security audit: function grants, revoke public | Eza, Tulus | âœ… Done |
| T3-26 | â€” | DB Recovery Runbook documentation | Tulus | âœ… Done |
| T3-27 | â€” | Testing integrasi face recognition flow E2E | Mukhlis | âœ… Done |
| T3-28 | â€” | Bug fixing (session code 404, face migration, RLS conflict) | Tulus | âœ… Done |

**Realisasi Sprint 3: 53/53 SP selesai (100%)**

---

# Bab 13: Sprint Review â€” Sprint 3

## 13.1 Hasil Demo Sprint 3

| Tanggal Demo | 18 Mei 2026 |
|---|---|
| **Peserta** | Tim Development + Product Owner (Pak Annafi' Franz) |
| **Lokasi** | Kampus Politeknik Pertanian Negeri Samarinda |

### Fitur yang Di-demo-kan

| # | Fitur | Hasil | Feedback PO |
|---|-------|-------|-------------|
| 1 | Face Registration â†’ Face Verify â†’ Submit Presensi | âœ… Berhasil | **Fitur unggulan!** 3-layer verifikasi sangat kuat |
| 2 | Server-side face comparison (cosine similarity) | âœ… Berhasil | Bagus karena embedding tidak di-compare di client |
| 3 | Live Monitor + Geofence Ring SVG | âœ… Berhasil | Visualisasi sangat membantu dosen |
| 4 | QR Fullscreen (projector mode) | âœ… Berhasil | Praktis untuk kelas besar |
| 5 | AI Chatbot (Web + Mobile) | âœ… Berhasil | Value-add yang bagus, respons cepat |
| 6 | Upload bukti izin + preview signed URL | âœ… Berhasil | Dosen bisa langsung lihat bukti |
| 7 | Onboarding 3-step | âœ… Berhasil | UX friendly untuk mahasiswa baru |
| 8 | Hapus data wajah (UU PDP) | âœ… Berhasil | Compliance hukum penting |
| 9 | Dashboard at-risk students | âœ… Berhasil | Early warning system untuk admin |
| 10 | Security hardening (RLS, rate limit) | âœ… Berhasil | Keamanan sudah enterprise-grade |

### 13.2 Feedback Product Owner

- âœ… **Sangat puas** dengan 3-layer verifikasi (QR + GPS + Face)
- âœ… **Fitur melebihi ekspektasi** â€” AI chatbot dan live monitor tidak diminta awalnya
- ðŸ“ **Sprint 4 fokus:** Polish, testing akhir, persiapan demo PBL 8 Juni

### 13.3 Burndown Chart Data â€” Sprint 3

| Hari | SP Sisa (Ideal) | SP Sisa (Aktual) |
|:----:|:---------------:|:----------------:|
| 1 | 48 | 53 |
| 2 | 42 | 50 |
| 3 | 37 | 45 |
| 4 | 32 | 38 |
| 5 | 27 | 32 |
| 6 | 21 | 26 |
| 7 | 16 | 20 |
| 8 | 11 | 13 |
| 9 | 5 | 6 |
| 10 | 0 | 0 |

**Catatan:** Hari 1-3 lebih lambat karena kompleksitas tinggi face recognition (TFLite integration). Setelah face berhasil, velocity meningkat drastis.

---

# Bab 14: Sprint Retrospective â€” Sprint 3

## 14.1 What Went Well âœ…

1. **Face Recognition berhasil** â€” MobileFaceNet 192-D terintegrasi sempurna, threshold 0.65 optimal
2. **Server-side verification** â€” Keputusan memindahkan face comparison ke server terbukti tepat (anti-bypass)
3. **Velocity tertinggi** â€” 53 SP, naik dari 47 (Sprint 2), menunjukkan produktivitas tim optimal
4. **3-layer security** â€” Menjadi USP (Unique Selling Point) proyek vs kompetitor
5. **AI Chatbot** â€” Implementasi streaming Gemini 2.5 Flash berjalan lancar
6. **UU PDP compliance** â€” Fitur hapus data wajah menunjukkan awareness hukum

## 14.2 What Didn't Go Well âŒ

1. **Debt teknis menumpuk** â€” RLS perlu di-consolidate (drop-recreate) karena terlalu banyak incremental policy
2. **Bug face migration** â€” Database migration untuk face embeddings sempat konflik
3. **Testing masih manual** â€” Automated E2E test belum tersedia
4. **QR Rolling 5s** (Phase 3 security) belum sempat diimplementasi

## 14.3 Action Items

| # | Action Item | PIC | Target |
|---|------------|-----|--------|
| 1 | Smoke test E2E di HP fisik (bukan emulator) | Mukhlis, Tulus | Sprint 4 |
| 2 | Fix remaining UI bugs (padding, overflow) | Sachio, Abdul Latif | Sprint 4 |
| 3 | Persiapan materi demo PBL (slide + skenario) | Seluruh tim | Sprint 4 |
| 4 | Dokumentasi final (README, API docs) | Tulus | Sprint 4 |
| 5 | QR Rolling 5s di-deferred ke post-release | â€” | Backlog |

---

# Bab 15: Sprint 4 â€” Production Readiness (In Progress)

## Sprint 4: Final Polish & Demo Preparation

| Atribut | Detail |
|---------|--------|
| **Sprint Goal** | Memastikan sistem production-ready untuk demo PBL dan memperbaiki sisa bug |
| **Durasi** | 19 Mei â€“ 8 Juni 2026 (3 minggu â€” extended karena termasuk persiapan demo) |
| **Status** | ðŸŸ¡ **In Progress** |

### Sprint Backlog â€” Sprint 4

| Task ID | Task | PIC | SP | Status |
|---------|------|-----|:--:|:------:|
| T4-01 | Smoke test E2E pada HP fisik (Android) | Mukhlis | 5 | â³ In Progress |
| T4-02 | Fix UI bugs (overflow, padding, responsive) | Sachio, Abdul Latif | 3 | â³ In Progress |
| T4-03 | Performance optimization (lazy load, caching) | Eza | 3 | ðŸ“‹ To Do |
| T4-04 | Persiapan materi demo PBL (skenario + slide) | Seluruh tim | 3 | ðŸ“‹ To Do |
| T4-05 | Dokumentasi final (update README + API docs) | Tulus | 2 | â³ In Progress |
| T4-06 | Penyusunan dokumen Scrum (dokumen ini) | Tulus | 2 | â³ In Progress |
| T4-07 | Regression testing fitur inti | Mukhlis | 3 | ðŸ“‹ To Do |

**Total Sprint 4: 21 SP** (fokus quality, bukan feature baru)

**Progress saat ini: 6/21 SP selesai, 8 SP in progress, 7 SP to do**

---

# Bab 16: Product Backlog Refinement

## 16.1 Refinement yang Dilakukan

Refinement dilakukan secara informal di antara sprint, biasanya saat daily standup atau diskusi teknis di kampus. Berikut perubahan yang terjadi selama proyek berjalan:

### Perubahan Prioritas

| Item | Perubahan | Alasan |
|------|----------|--------|
| US-08 (Face Recognition) | Naik dari Sprint 2 â†’ Sprint 3 | Sprint 2 terlalu padat dengan presensi core flow |
| US-16 (Live Monitor) | Naik dari Could Have â†’ Should Have | Feedback PO: fitur penting untuk dosen |
| US-19 (AI Chatbot) | Tetap Could Have, tapi dimasukkan Sprint 3 | Kapasitas tim masih ada |
| US-24 (Push Notif FCM) | Tetap Won't Have | Butuh konfigurasi Firebase yang belum prioritas |
| US-25 (Monitoring) | Tetap Won't Have | Butuh Supabase Pro Plan (budget) |

### Penambahan User Story Baru (muncul selama development)

| ID | User Story Baru | Asal | SP |
|----|----------------|------|:--:|
| US-20 | Onboarding 3-step | Feedback UX testing | 3 |
| US-22 | At-risk students dashboard | Feedback PO Sprint 2 review | 5 |
| US-23 | Hapus data wajah (UU PDP) | Analisis compliance hukum | 3 |

### Story Points Re-estimation

| ID | Estimasi Awal | Estimasi Akhir | Alasan |
|----|:------------:|:-------------:|--------|
| US-08 | 8 SP | 13 SP | Kompleksitas TFLite integration + server-side lebih tinggi dari perkiraan |
| US-05 | 5 SP | 8 SP | Perlu QR code generation + OTP + session management |
| US-16 | 5 SP | 8 SP | Supabase Realtime + SVG geofence ring lebih kompleks |

## 16.2 Definition of Done (DoD)

Berikut Definition of Done yang digunakan tim sepanjang proyek:

1. âœ… Kode berjalan tanpa error di environment development
2. âœ… Fitur sesuai acceptance criteria dari User Story
3. âœ… RLS policy diterapkan untuk tabel terkait
4. âœ… UI responsive (web) / adaptive (mobile)
5. âœ… Diuji manual oleh QA (Mukhlis)
6. âœ… Tidak ada regression pada fitur yang sudah ada
7. âœ… Kode sudah di-commit dan di-push ke repository

---

# Bab 17: Velocity Chart

## 17.1 Data Velocity per Sprint

| Sprint | SP Planned | SP Completed | Velocity |
|:------:|:----------:|:------------:|:--------:|
| Sprint 1 | 42 | 42 | 42 |
| Sprint 2 | 47 | 47 | 47 |
| Sprint 3 | 53 | 53 | 53 |
| Sprint 4 | 21 | 6 (in progress) | â€” |

### Rata-rata Velocity (Sprint 1-3): **47.3 SP/Sprint**

## 17.2 Visualisasi Velocity Chart

```
SP
55 â”‚                         â”Œâ”€â”€â”€â”
50 â”‚              â”Œâ”€â”€â”€â”      â”‚53 â”‚
45 â”‚   â”Œâ”€â”€â”€â”     â”‚47 â”‚      â”‚   â”‚
40 â”‚   â”‚42 â”‚     â”‚   â”‚      â”‚   â”‚
35 â”‚   â”‚   â”‚     â”‚   â”‚      â”‚   â”‚
30 â”‚   â”‚   â”‚     â”‚   â”‚      â”‚   â”‚
25 â”‚   â”‚   â”‚     â”‚   â”‚      â”‚   â”‚      â”Œâ”€â”€â”€â”
20 â”‚   â”‚   â”‚     â”‚   â”‚      â”‚   â”‚      â”‚21 â”‚ â† target
15 â”‚   â”‚   â”‚     â”‚   â”‚      â”‚   â”‚      â”‚   â”‚
10 â”‚   â”‚   â”‚     â”‚   â”‚      â”‚   â”‚      â”‚â–“â–“â–“â”‚ 6 done
 5 â”‚   â”‚   â”‚     â”‚   â”‚      â”‚   â”‚      â”‚â–“â–“â–“â”‚
 0 â””â”€â”€â”€â”´â”€â”€â”€â”´â”€â”€â”€â”€â”€â”´â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”˜
     Sprint 1   Sprint 2   Sprint 3   Sprint 4
                                     (In Progress)
```

### Tren Velocity

- **Sprint 1 â†’ 2**: +5 SP (+12%) â€” Tim semakin familiar dengan stack
- **Sprint 2 â†’ 3**: +6 SP (+13%) â€” Paralelisasi web+mobile optimal
- **Sprint 4**: Sengaja dikurangi (21 SP) karena fokus quality & demo preparation

---

# Bab 18: Burndown Chart

## 18.1 Burndown Chart â€” Sprint 1 (42 SP)

```
SP
42 â”‚â—
38 â”‚ â•²  â—
34 â”‚  â•²   â—
30 â”‚   â•²    â—
26 â”‚    â•²     â—
22 â”‚     â•²      â—
18 â”‚      â•²       â—
14 â”‚       â•²        â—
10 â”‚        â•²         â—
 6 â”‚         â•²
 0 â”‚â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â•²â”€â”€â”€â”€â”€â”€â”€â”€â”€â—
   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    1  2  3  4  5  6  7  8  9  10
   â”€â”€ Ideal    â— Aktual
```

**Catatan:** Awal sprint lebih lambat (setup environment), akhir sprint percepatan.

## 18.2 Burndown Chart â€” Sprint 2 (47 SP)

```
SP
47 â”‚â—
42 â”‚ â•²  â—
38 â”‚  â•²
33 â”‚   â•²  â—
28 â”‚    â•²    â—
24 â”‚     â•²     â—
19 â”‚      â•²      â—
14 â”‚       â•²       â—
 9 â”‚        â•²        â—
 5 â”‚         â•²     â—
 0 â”‚â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â•²â”€â”€â”€â—
   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    1  2  3  4  5  6  7  8  9  10
   â”€â”€ Ideal    â— Aktual
```

**Catatan:** Sprint 2 lebih smooth, pola ideal mendekati aktual. Hari 8-10 percepatan integrasi.

## 18.3 Burndown Chart â€” Sprint 3 (53 SP)

```
SP
53 â”‚â—
48 â”‚ â•²â—
42 â”‚  â•²  â—
37 â”‚   â•²    â—
32 â”‚    â•²     â—
27 â”‚     â•²      â—
21 â”‚      â•²       â—
16 â”‚       â•²        â—
11 â”‚        â•²
 5 â”‚         â•²   â—
 0 â”‚â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â•²â—
   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    1  2  3  4  5  6  7  8  9  10
   â”€â”€ Ideal    â— Aktual
```

**Catatan:** Sprint 3 paling menantang. Hari 1-3 lambat karena face recognition (kompleksitas tinggi). Setelah TFLite berhasil, velocity melonjak.

---

# Bab 19: Ringkasan & Kesimpulan

## 19.1 Ringkasan Progres Proyek

| Metrik | Nilai |
|--------|-------|
| **Total Sprint** | 4 (3 selesai, 1 in progress) |
| **Total SP Selesai** | 142 SP (dari 160 SP total backlog) |
| **Rata-rata Velocity** | 47.3 SP/sprint |
| **Must Have Completion** | 76/76 SP (100%) |
| **Should Have Completion** | 26/26 SP (100%) |
| **Could Have Completion** | 22/22 SP (100%) |
| **Won't Have (deferred)** | 13 SP |
| **Fitur Selesai** | 23 dari 25 user stories |
| **Status Proyek** | ðŸŸ¢ On Track â€” Release Candidate |

## 19.2 Pencapaian Utama

1. **3-Layer Verification System** â€” QR Code + GPS (Haversine + anti-mock) + Face Recognition (MobileFaceNet 192-D). Ketiganya wajib dilewati untuk presensi berhasil.
2. **Full-Stack Implementation** â€” Web dashboard (Next.js 14) + Mobile app (Flutter 3.11) + Backend (Supabase) dalam 6 minggu.
3. **Enterprise-Grade Security** â€” RLS policies 10 tabel, server-side face verification, rate limiting per-device, audit log.
4. **AI-Powered** â€” Chatbot terintegrasi (Gemini 2.5 Flash) untuk insight data presensi.
5. **UU PDP Compliance** â€” Fitur hapus data biometrik wajah dengan edukasi 2-step.

## 19.3 Tantangan & Pembelajaran

| Tantangan | Solusi | Pembelajaran |
|-----------|--------|-------------|
| Face Recognition integration kompleks | Gunakan TFLite pre-trained model, pindahkan comparison ke server | Estimasi SP untuk fitur AI/ML harus lebih besar |
| RLS policy konfliks setelah banyak migration | Consolidation: drop-recreate semua policy | Desain RLS harus mature di awal, bukan incremental |
| QR code field mismatch (web vs mobile) | Standardisasi naming convention | Perlu API contract document sebelum parallel development |
| Environment setup untuk member baru lambat | Buat checklist dan `.env.example` | Developer onboarding harus di-prioritaskan |

## 19.4 Rencana Sprint 4 dan Selanjutnya

### Sprint 4 (In Progress â€” deadline 8 Juni 2026)
- Smoke test E2E pada device fisik
- Fix remaining UI bugs
- Persiapan demo PBL
- Dokumentasi final

### Post-Release Backlog (setelah demo PBL)
- US-24: Push Notification FCM (8 SP)
- US-25: Monitoring & Alerting (5 SP)
- QR Rolling 5 detik (TOTP-like) â€” Phase 3 Security

## 19.5 Kesimpulan

Proyek MyPresensi berhasil mencapai target **release candidate** dalam 3 sprint (6 minggu), dengan seluruh fitur Must Have, Should Have, dan Could Have terselesaikan. Velocity tim menunjukkan tren positif yang konsisten (42 â†’ 47 â†’ 53 SP), mencerminkan peningkatan produktivitas seiring familiaritas dengan tech stack.

Sistem 3-layer verifikasi (QR + GPS + Face) menjadi diferensiasi utama dibandingkan sistem presensi konvensional, dan kepatuhan terhadap UU PDP menunjukkan kesadaran tim terhadap aspek legal teknologi biometrik.

Sprint 4 saat ini berjalan dengan fokus pada quality assurance dan persiapan demo PBL yang dijadwalkan tanggal **8 Juni 2026**.

---

**Disusun oleh:**
Tulus Arya Danendra (Scrum Master)

**Disetujui oleh:**
Annafi' Franz, S.Kom., M.Kom (Product Owner)

**Tanggal:** 20 Mei 2026
