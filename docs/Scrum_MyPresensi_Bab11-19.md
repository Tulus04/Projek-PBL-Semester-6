# Bab 11: Sprint Planning — Sprint 3

## Sprint 3: Security Hardening & Advanced Features

| Atribut | Detail |
|---------|--------|
| **Sprint Goal** | Mengimplementasikan face recognition (layer keamanan ke-3), fitur advanced (live monitor, AI chatbot, QR fullscreen), dan hardening keamanan sistem |
| **Durasi** | 5 Mei – 18 Mei 2026 (2 minggu) |
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

# Bab 12: Sprint Backlog — Sprint 3

| Task ID | User Story | Task | PIC | Status |
|---------|-----------|------|-----|:------:|
| T3-01 | US-08 | Integrasi MobileFaceNet TFLite (192-D embedding) | Tulus | ✅ Done |
| T3-02 | US-08 | Face registration screen (capture + extract + upload) | Tulus | ✅ Done |
| T3-03 | US-08 | API: POST /face/register (simpan embedding ke DB) | Eza | ✅ Done |
| T3-04 | US-08 | Face verification screen (capture + compare) | Tulus | ✅ Done |
| T3-05 | US-08 | API: POST /face/verify (server-side cosine similarity, threshold 0.65) | Eza | ✅ Done |
| T3-06 | US-08 | SQL Migration: face_embeddings table + RLS | Eza | ✅ Done |
| T3-07 | US-08 | Integrasi face verify ke attendance flow (wajib sebelum submit) | Tulus | ✅ Done |
| T3-08 | US-16 | Web: Live monitor component (SVG geofence ring) | Sachio | ✅ Done |
| T3-09 | US-16 | Supabase Realtime subscription (attendance channel) | Eza | ✅ Done |
| T3-10 | US-16 | Live attendance stats (hadir/belum/terlambat counter) | Abdul Latif | ✅ Done |
| T3-11 | US-17 | QR Display fullscreen (projector mode, auto-scale) | Abdul Latif | ✅ Done |
| T3-12 | US-18 | Supabase Storage: bucket izin + signed URL | Eza | ✅ Done |
| T3-13 | US-18 | Mobile: upload file picker + compress | Tulus | ✅ Done |
| T3-14 | US-18 | Web: preview bukti izin (signed URL, image viewer) | Abdul Latif | ✅ Done |
| T3-15 | US-19 | API: POST /ai/chat (Gemini 2.5 Flash, streaming) | Eza | ✅ Done |
| T3-16 | US-19 | Web: AI chatbot panel (context-aware, markdown render) | Sachio | ✅ Done |
| T3-17 | US-19 | Mobile: AI chatbot screen | Tulus | ✅ Done |
| T3-18 | US-20 | Mobile: Onboarding 3-step (info carousel + permission) | Sachio | ✅ Done |
| T3-19 | US-21 | Mobile: Avatar upload + crop | Sachio | ✅ Done |
| T3-20 | US-22 | Web: Dashboard widget at-risk students (RPC + card) | Abdul Latif | ✅ Done |
| T3-21 | US-22 | Supabase RPC: get_at_risk_students + security (revoke public) | Eza | ✅ Done |
| T3-22 | US-23 | Mobile: Hapus data wajah (2-step UU PDP: edukasi + konfirmasi) | Tulus | ✅ Done |
| T3-23 | — | RLS consolidation (10 tabel, drop-recreate) | Eza | ✅ Done |
| T3-24 | — | Rate limiting per-device (composite key userId:deviceId) | Eza | ✅ Done |
| T3-25 | — | Security audit: function grants, revoke public | Eza, Tulus | ✅ Done |
| T3-26 | — | DB Recovery Runbook documentation | Tulus | ✅ Done |
| T3-27 | — | Testing integrasi face recognition flow E2E | Mukhlis | ✅ Done |
| T3-28 | — | Bug fixing (session code 404, face migration, RLS conflict) | Tulus | ✅ Done |

**Realisasi Sprint 3: 53/53 SP selesai (100%)**

---

# Bab 13: Sprint Review — Sprint 3

## 13.1 Hasil Demo Sprint 3

| Tanggal Demo | 18 Mei 2026 |
|---|---|
| **Peserta** | Tim Development + Product Owner (Pak Annafi' Franz) |
| **Lokasi** | Kampus Politeknik Pertanian Negeri Samarinda |

### Fitur yang Di-demo-kan

| # | Fitur | Hasil | Feedback PO |
|---|-------|-------|-------------|
| 1 | Face Registration → Face Verify → Submit Presensi | ✅ Berhasil | **Fitur unggulan!** 3-layer verifikasi sangat kuat |
| 2 | Server-side face comparison (cosine similarity) | ✅ Berhasil | Bagus karena embedding tidak di-compare di client |
| 3 | Live Monitor + Geofence Ring SVG | ✅ Berhasil | Visualisasi sangat membantu dosen |
| 4 | QR Fullscreen (projector mode) | ✅ Berhasil | Praktis untuk kelas besar |
| 5 | AI Chatbot (Web + Mobile) | ✅ Berhasil | Value-add yang bagus, respons cepat |
| 6 | Upload bukti izin + preview signed URL | ✅ Berhasil | Dosen bisa langsung lihat bukti |
| 7 | Onboarding 3-step | ✅ Berhasil | UX friendly untuk mahasiswa baru |
| 8 | Hapus data wajah (UU PDP) | ✅ Berhasil | Compliance hukum penting |
| 9 | Dashboard at-risk students | ✅ Berhasil | Early warning system untuk admin |
| 10 | Security hardening (RLS, rate limit) | ✅ Berhasil | Keamanan sudah enterprise-grade |

### 13.2 Feedback Product Owner

- ✅ **Sangat puas** dengan 3-layer verifikasi (QR + GPS + Face)
- ✅ **Fitur melebihi ekspektasi** — AI chatbot dan live monitor tidak diminta awalnya
- 📝 **Sprint 4 fokus:** Polish, testing akhir, persiapan demo PBL 8 Juni

### 13.3 Burndown Chart Data — Sprint 3

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

# Bab 14: Sprint Retrospective — Sprint 3

## 14.1 What Went Well ✅

1. **Face Recognition berhasil** — MobileFaceNet 192-D terintegrasi sempurna, threshold 0.65 optimal
2. **Server-side verification** — Keputusan memindahkan face comparison ke server terbukti tepat (anti-bypass)
3. **Velocity tertinggi** — 53 SP, naik dari 47 (Sprint 2), menunjukkan produktivitas tim optimal
4. **3-layer security** — Menjadi USP (Unique Selling Point) proyek vs kompetitor
5. **AI Chatbot** — Implementasi streaming Gemini 2.5 Flash berjalan lancar
6. **UU PDP compliance** — Fitur hapus data wajah menunjukkan awareness hukum

## 14.2 What Didn't Go Well ❌

1. **Debt teknis menumpuk** — RLS perlu di-consolidate (drop-recreate) karena terlalu banyak incremental policy
2. **Bug face migration** — Database migration untuk face embeddings sempat konflik
3. **Testing masih manual** — Automated E2E test belum tersedia
4. **QR Rolling 5s** (Phase 3 security) belum sempat diimplementasi

## 14.3 Action Items

| # | Action Item | PIC | Target |
|---|------------|-----|--------|
| 1 | Smoke test E2E di HP fisik (bukan emulator) | Mukhlis, Tulus | Sprint 4 |
| 2 | Fix remaining UI bugs (padding, overflow) | Sachio, Abdul Latif | Sprint 4 |
| 3 | Persiapan materi demo PBL (slide + skenario) | Seluruh tim | Sprint 4 |
| 4 | Dokumentasi final (README, API docs) | Tulus | Sprint 4 |
| 5 | QR Rolling 5s di-deferred ke post-release | — | Backlog |

---

# Bab 15: Sprint 4 — Production Readiness (In Progress)

## Sprint 4: Final Polish & Demo Preparation

| Atribut | Detail |
|---------|--------|
| **Sprint Goal** | Memastikan sistem production-ready untuk demo PBL dan memperbaiki sisa bug |
| **Durasi** | 19 Mei – 8 Juni 2026 (3 minggu — extended karena termasuk persiapan demo) |
| **Status** | 🟡 **In Progress** |

### Sprint Backlog — Sprint 4

| Task ID | Task | PIC | SP | Status |
|---------|------|-----|:--:|:------:|
| T4-01 | Smoke test E2E pada HP fisik (Android) | Mukhlis | 5 | ⏳ In Progress |
| T4-02 | Fix UI bugs (overflow, padding, responsive) | Sachio, Abdul Latif | 3 | ⏳ In Progress |
| T4-03 | Performance optimization (lazy load, caching) | Eza | 3 | 📋 To Do |
| T4-04 | Persiapan materi demo PBL (skenario + slide) | Seluruh tim | 3 | 📋 To Do |
| T4-05 | Dokumentasi final (update README + API docs) | Tulus | 2 | ⏳ In Progress |
| T4-06 | Penyusunan dokumen Scrum (dokumen ini) | Tulus | 2 | ⏳ In Progress |
| T4-07 | Regression testing fitur inti | Mukhlis | 3 | 📋 To Do |

**Total Sprint 4: 21 SP** (fokus quality, bukan feature baru)

**Progress saat ini: 6/21 SP selesai, 8 SP in progress, 7 SP to do**

---

# Bab 16: Product Backlog Refinement

## 16.1 Refinement yang Dilakukan

Refinement dilakukan secara informal di antara sprint, biasanya saat daily standup atau diskusi teknis di kampus. Berikut perubahan yang terjadi selama proyek berjalan:

### Perubahan Prioritas

| Item | Perubahan | Alasan |
|------|----------|--------|
| US-08 (Face Recognition) | Naik dari Sprint 2 → Sprint 3 | Sprint 2 terlalu padat dengan presensi core flow |
| US-16 (Live Monitor) | Naik dari Could Have → Should Have | Feedback PO: fitur penting untuk dosen |
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

1. ✅ Kode berjalan tanpa error di environment development
2. ✅ Fitur sesuai acceptance criteria dari User Story
3. ✅ RLS policy diterapkan untuk tabel terkait
4. ✅ UI responsive (web) / adaptive (mobile)
5. ✅ Diuji manual oleh QA (Mukhlis)
6. ✅ Tidak ada regression pada fitur yang sudah ada
7. ✅ Kode sudah di-commit dan di-push ke repository

---

# Bab 17: Velocity Chart

## 17.1 Data Velocity per Sprint

| Sprint | SP Planned | SP Completed | Velocity |
|:------:|:----------:|:------------:|:--------:|
| Sprint 1 | 42 | 42 | 42 |
| Sprint 2 | 47 | 47 | 47 |
| Sprint 3 | 53 | 53 | 53 |
| Sprint 4 | 21 | 6 (in progress) | — |

### Rata-rata Velocity (Sprint 1-3): **47.3 SP/Sprint**

## 17.2 Visualisasi Velocity Chart

```
SP
55 │                         ┌───┐
50 │              ┌───┐      │53 │
45 │   ┌───┐     │47 │      │   │
40 │   │42 │     │   │      │   │
35 │   │   │     │   │      │   │
30 │   │   │     │   │      │   │
25 │   │   │     │   │      │   │      ┌───┐
20 │   │   │     │   │      │   │      │21 │ ← target
15 │   │   │     │   │      │   │      │   │
10 │   │   │     │   │      │   │      │▓▓▓│ 6 done
 5 │   │   │     │   │      │   │      │▓▓▓│
 0 └───┴───┴─────┴───┴──────┴───┴──────┴───┘
     Sprint 1   Sprint 2   Sprint 3   Sprint 4
                                     (In Progress)
```

### Tren Velocity

- **Sprint 1 → 2**: +5 SP (+12%) — Tim semakin familiar dengan stack
- **Sprint 2 → 3**: +6 SP (+13%) — Paralelisasi web+mobile optimal
- **Sprint 4**: Sengaja dikurangi (21 SP) karena fokus quality & demo preparation

---

# Bab 18: Burndown Chart

## 18.1 Burndown Chart — Sprint 1 (42 SP)

```
SP
42 │●
38 │ ╲  ●
34 │  ╲   ●
30 │   ╲    ●
26 │    ╲     ●
22 │     ╲      ●
18 │      ╲       ●
14 │       ╲        ●
10 │        ╲         ●
 6 │         ╲
 0 │──────────╲─────────●
   └──────────────────────
    1  2  3  4  5  6  7  8  9  10
   ── Ideal    ● Aktual
```

**Catatan:** Awal sprint lebih lambat (setup environment), akhir sprint percepatan.

## 18.2 Burndown Chart — Sprint 2 (47 SP)

```
SP
47 │●
42 │ ╲  ●
38 │  ╲
33 │   ╲  ●
28 │    ╲    ●
24 │     ╲     ●
19 │      ╲      ●
14 │       ╲       ●
 9 │        ╲        ●
 5 │         ╲     ●
 0 │──────────╲───●
   └──────────────────────
    1  2  3  4  5  6  7  8  9  10
   ── Ideal    ● Aktual
```

**Catatan:** Sprint 2 lebih smooth, pola ideal mendekati aktual. Hari 8-10 percepatan integrasi.

## 18.3 Burndown Chart — Sprint 3 (53 SP)

```
SP
53 │●
48 │ ╲●
42 │  ╲  ●
37 │   ╲    ●
32 │    ╲     ●
27 │     ╲      ●
21 │      ╲       ●
16 │       ╲        ●
11 │        ╲
 5 │         ╲   ●
 0 │──────────╲●
   └──────────────────────
    1  2  3  4  5  6  7  8  9  10
   ── Ideal    ● Aktual
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
| **Status Proyek** | 🟢 On Track — Release Candidate |

## 19.2 Pencapaian Utama

1. **3-Layer Verification System** — QR Code + GPS (Haversine + anti-mock) + Face Recognition (MobileFaceNet 192-D). Ketiganya wajib dilewati untuk presensi berhasil.
2. **Full-Stack Implementation** — Web dashboard (Next.js 14) + Mobile app (Flutter 3.11) + Backend (Supabase) dalam 6 minggu.
3. **Enterprise-Grade Security** — RLS policies 10 tabel, server-side face verification, rate limiting per-device, audit log.
4. **AI-Powered** — Chatbot terintegrasi (Gemini 2.5 Flash) untuk insight data presensi.
5. **UU PDP Compliance** — Fitur hapus data biometrik wajah dengan edukasi 2-step.

## 19.3 Tantangan & Pembelajaran

| Tantangan | Solusi | Pembelajaran |
|-----------|--------|-------------|
| Face Recognition integration kompleks | Gunakan TFLite pre-trained model, pindahkan comparison ke server | Estimasi SP untuk fitur AI/ML harus lebih besar |
| RLS policy konfliks setelah banyak migration | Consolidation: drop-recreate semua policy | Desain RLS harus mature di awal, bukan incremental |
| QR code field mismatch (web vs mobile) | Standardisasi naming convention | Perlu API contract document sebelum parallel development |
| Environment setup untuk member baru lambat | Buat checklist dan `.env.example` | Developer onboarding harus di-prioritaskan |

## 19.4 Rencana Sprint 4 dan Selanjutnya

### Sprint 4 (In Progress — deadline 8 Juni 2026)
- Smoke test E2E pada device fisik
- Fix remaining UI bugs
- Persiapan demo PBL
- Dokumentasi final

### Post-Release Backlog (setelah demo PBL)
- US-24: Push Notification FCM (8 SP)
- US-25: Monitoring & Alerting (5 SP)
- QR Rolling 5 detik (TOTP-like) — Phase 3 Security

## 19.5 Kesimpulan

Proyek MyPresensi berhasil mencapai target **release candidate** dalam 3 sprint (6 minggu), dengan seluruh fitur Must Have, Should Have, dan Could Have terselesaikan. Velocity tim menunjukkan tren positif yang konsisten (42 → 47 → 53 SP), mencerminkan peningkatan produktivitas seiring familiaritas dengan tech stack.

Sistem 3-layer verifikasi (QR + GPS + Face) menjadi diferensiasi utama dibandingkan sistem presensi konvensional, dan kepatuhan terhadap UU PDP menunjukkan kesadaran tim terhadap aspek legal teknologi biometrik.

Sprint 4 saat ini berjalan dengan fokus pada quality assurance dan persiapan demo PBL yang dijadwalkan tanggal **8 Juni 2026**.

---

**Disusun oleh:**
Tulus Arya Danendra (Scrum Master)

**Disetujui oleh:**
Annafi' Franz, S.Kom., M.Kom (Product Owner)

**Tanggal:** 20 Mei 2026
