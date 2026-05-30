# Bab 6: Sprint Retrospective — Sprint 1

## 6.1 Retrospective Meeting

| Atribut | Detail |
|---------|--------|
| **Tanggal** | 20 April 2026 |
| **Fasilitator** | Tulus Arya Danendra (Scrum Master) |
| **Peserta** | Seluruh Development Team |
| **Format** | What Went Well / What Didn't / Action Items |

## 6.2 What Went Well ✅

1. **Scaffold cepat** — Next.js 14 + Supabase berhasil di-setup dalam 1 sesi pertama
2. **Design system solid** — Color token TRPL, CSS utility class, dan component pattern terbentuk di awal sehingga konsisten
3. **Database schema komprehensif** — 10 tabel + 11 index + RLS policies selesai dalam 1 migration
4. **Import CSV mahasiswa** berfungsi baik, menghemat waktu admin vs input manual
5. **Kolaborasi front-end** — Sachio dan Abdul Latif bisa paralel mengerjakan halaman berbeda tanpa konflik

## 6.3 What Didn't Go Well ❌

1. **Setup environment lambat** — Hari 1-2 banyak waktu terbuang untuk konfigurasi (path alias, env variable, Supabase project)
2. **5 bug ditemukan** saat integrasi (package.json kosong, 404 route, middleware crash, useActionState React 19 vs 18, import path)
3. **Belum ada automated testing** — QA belum bisa mulai karena test framework belum di-setup
4. **Mobile app belum dimulai** — Flutter SDK masih dalam proses instalasi

## 6.4 Action Items

| # | Action Item | PIC | Target |
|---|------------|-----|--------|
| 1 | Buat checklist setup environment untuk developer baru | Tulus | Sprint 2 |
| 2 | Setup Flutter project dan pastikan `flutter doctor` pass | Tulus | Sprint 2 awal |
| 3 | Buat halaman force change password | Eza | Sprint 2 |
| 4 | Mulai test plan untuk fitur inti (login, CRUD) | Mukhlis | Sprint 2 |
| 5 | Dokumentasi API endpoint untuk tim mobile | Eza | Sprint 2 |

---

# Bab 7: Sprint Planning — Sprint 2

## Sprint 2: Mobile Core & Presensi Flow

| Atribut | Detail |
|---------|--------|
| **Sprint Goal** | Mengembangkan mobile app mahasiswa dan flow presensi inti (scan QR → GPS → submit) agar mahasiswa bisa melakukan presensi |
| **Durasi** | 21 April – 4 Mei 2026 (2 minggu) |
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
| — | Mobile App Foundation (auth, routing, theme) | 5 | Tulus |

**Total Sprint 2: 47 SP**

---

# Bab 8: Sprint Backlog — Sprint 2

| Task ID | User Story | Task | PIC | Status |
|---------|-----------|------|-----|:------:|
| T2-01 | — | Scaffold Flutter project + konfigurasi | Tulus | ✅ Done |
| T2-02 | — | Setup Riverpod 3 + GoRouter + Dio client | Tulus | ✅ Done |
| T2-03 | — | Mobile design system (AppColors, AppTheme, AppShadows) | Sachio | ✅ Done |
| T2-04 | — | Mobile login screen + auth provider | Tulus | ✅ Done |
| T2-05 | — | Mobile splash screen + routing guard | Tulus | ✅ Done |
| T2-06 | — | Bottom navigation (AppShell) + 5 tab | Sachio | ✅ Done |
| T2-07 | US-05 | Web: Halaman sesi presensi (buat/tutup sesi) | Eza | ✅ Done |
| T2-08 | US-05 | Web: QR Code generation + OTP 6-digit | Eza | ✅ Done |
| T2-09 | US-05 | API Route: POST/GET sesi + session_code | Eza | ✅ Done |
| T2-10 | US-06 | Mobile: Scan QR screen (camera + decode) | Tulus | ✅ Done |
| T2-11 | US-07 | Mobile: Location service (Haversine + mock detection) | Tulus | ✅ Done |
| T2-12 | US-07 | API: Attendance submit (6-layer validation) | Eza | ✅ Done |
| T2-13 | US-06+07 | Mobile: Attendance result screen (success/fail UI) | Sachio | ✅ Done |
| T2-14 | US-09 | Web: Halaman rekap kehadiran (filter + tabel) | Abdul Latif | ✅ Done |
| T2-15 | US-14 | Web: Export CSV/PDF | Abdul Latif | ✅ Done |
| T2-16 | US-10 | Mobile: History screen + provider | Sachio | ✅ Done |
| T2-17 | US-11 | Mobile: Submit leave request screen | Tulus | ✅ Done |
| T2-18 | US-11 | API: POST leave request + file logic | Eza | ✅ Done |
| T2-19 | US-12 | Web: Halaman izin dosen (approve/reject) | Abdul Latif | ✅ Done |
| T2-20 | US-15 | Web: Halaman audit log | Abdul Latif | ✅ Done |
| T2-21 | — | Mobile: Notification screen | Sachio | ✅ Done |
| T2-22 | — | Mobile: Profile screen + change password | Tulus | ✅ Done |
| T2-23 | — | Testing integrasi mobile ↔ web API | Mukhlis | ✅ Done |
| T2-24 | — | Bug fixing QR field mismatch + face migration | Tulus | ✅ Done |

**Realisasi Sprint 2: 47/47 SP selesai (100%)**

---

# Bab 9: Sprint Review — Sprint 2

## 9.1 Hasil Demo Sprint 2

| Tanggal Demo | 4 Mei 2026 |
|---|---|
| **Peserta** | Tim Development + Product Owner |
| **Lokasi** | Kampus Politeknik Pertanian Negeri Samarinda |

### Fitur yang Di-demo-kan

| # | Fitur | Hasil | Feedback PO |
|---|-------|-------|-------------|
| 1 | Mobile login + splash screen | ✅ Berhasil | Tampilan sudah baik |
| 2 | Dosen buat sesi → QR Code + OTP muncul | ✅ Berhasil | Perlu QR fullscreen untuk proyektor |
| 3 | Mahasiswa scan QR → GPS check → submit | ✅ Berhasil | Core flow berjalan, face verification belum |
| 4 | Anti mock GPS (isMocked reject) | ✅ Berhasil | Fitur anti-kecurangan kritis, harus dipertahankan |
| 5 | Rekap kehadiran + export CSV | ✅ Berhasil | Sangat membantu untuk evaluasi |
| 6 | Submit izin/sakit + approve dosen | ✅ Berhasil | Perlu upload bukti surat sakit |
| 7 | Riwayat kehadiran mahasiswa | ✅ Berhasil | Perlu tampilan persentase kehadiran |
| 8 | Audit log | ✅ Berhasil | Bagus untuk tracking aksi |

### 9.2 Feedback & Backlog Update

- 📝 **Prioritas tinggi:** Face Recognition harus segera diimplementasi (layer keamanan ke-3)
- 📝 **Tambahan:** QR display fullscreen untuk proyektor
- 📝 **Tambahan:** Upload bukti izin/sakit
- 📝 **Perbaikan:** UI mobile perlu di-polish agar lebih premium

### 9.3 Burndown Chart Data — Sprint 2

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

# Bab 10: Sprint Retrospective — Sprint 2

## 10.1 What Went Well ✅

1. **Mobile app fungsional** — Dalam 2 minggu, app sudah bisa login → scan QR → submit presensi
2. **GPS Haversine + mock detection bekerja sempurna** — Anti-kecurangan layer 2 berhasil
3. **API design konsisten** — Pola autentikasi Bearer + rate limit terstandardisasi
4. **Paralelisasi efektif** — Tim web dan mobile bisa bekerja bersamaan tanpa blocking
5. **Velocity naik dari 42 → 47 SP** — Tim semakin familiar dengan tech stack

## 10.2 What Didn't Go Well ❌

1. **Face Recognition belum masuk Sprint 2** — Terlalu banyak task sesi presensi yang harus diselesaikan dulu
2. **Bug QR field mismatch** (sid vs session_id) memakan waktu debug
3. **UI mobile masih basic** — Menggunakan Material Icons default, belum premium
4. **Test coverage masih minim** — QA baru bisa test secara manual

## 10.3 Action Items

| # | Action Item | PIC | Target |
|---|------------|-----|--------|
| 1 | Implementasi Face Recognition (MobileFaceNet) sebagai prioritas #1 | Tulus, Eza | Sprint 3 |
| 2 | Pindahkan face comparison ke server-side (security) | Eza | Sprint 3 |
| 3 | Upgrade icon system ke Iconsax (premium look) | Sachio | Sprint 3 |
| 4 | Polish UI mobile sesuai mockup yang sudah dibuat | Sachio, Abdul Latif | Sprint 3 |
| 5 | Setup smoke test checklist | Mukhlis | Sprint 3 |
