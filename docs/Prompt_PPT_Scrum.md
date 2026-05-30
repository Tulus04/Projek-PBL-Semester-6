# Prompt untuk Membuat PPT Scrum MyPresensi
## (Copy-paste prompt di bawah ke Notebook LLM / ChatGPT / Gemini)

---

## PROMPT:

```
Buatkan presentasi PowerPoint (PPT) untuk dokumen Scrum proyek "MyPresensi" dengan ketentuan berikut:

## Konteks Proyek
- **Nama Proyek**: MyPresensi — Sistem Absensi Mahasiswa 3-Layer Verifikasi (QR Code + GPS + Face Recognition)
- **Institusi**: Prodi TRPL, Politeknik Pertanian Negeri Samarinda
- **Mata Kuliah**: Project Based Learning (PBL) Semester 6
- **Tech Stack**: Next.js 14 (Web Dashboard), Flutter 3.11 (Mobile App), Supabase (Backend + Auth + Storage + Realtime)
- **Deadline Demo**: 8 Juni 2026

## Tim
| Nama | Peran Scrum | Peran Teknis |
|------|-------------|-------------|
| Tulus Arya Danendra | Scrum Master | Full-Stack Developer |
| I Made Sachio Dharmayasa | Development Team | Front-End Developer |
| Abdul Latif | Development Team | Front-End Developer |
| Eza Aditya Dewangga | Development Team | Back-End Developer |
| Muhammad Mukhlis Adim | Development Team | Testing / QA |
| Annafi' Franz, S.Kom., M.Kom | Product Owner | Dosen Pembimbing |

## Struktur Slide yang Dibutuhkan (±20-25 slide)

### Slide 1: Cover
- Judul: "Dokumen Scrum — MyPresensi"
- Subtitle: Sistem Absensi Mahasiswa 3-Layer Verifikasi
- Nama tim + logo prodi (placeholder)
- Tanggal

### Slide 2: Daftar Isi
- Overview semua bab

### Slide 3-4: Persona & User Stories
- 3 persona: Admin Prodi, Dosen, Mahasiswa
- Tabel 25 User Stories (ID, story, prioritas MoSCoW, SP)
- Total: 139 SP

### Slide 5: Product Backlog
- Tabel Product Backlog dengan MoSCoW priority
- Must Have: 76 SP (100% done)
- Should Have: 26 SP (100% done)
- Could Have: 22 SP (100% done)
- Won't Have: 13 SP (deferred)

### Slide 6-8: Sprint 1 (6-20 April 2026) — Foundation & Web Core
- Sprint Planning: Goal, 42 SP, PIC assignment
- Sprint Backlog: 20 tasks, semua Done
- Sprint Review: 7 fitur di-demo, feedback PO
- Sprint Retrospective: What went well (scaffold cepat, design system solid), What didn't (setup lambat, 5 bugs)

### Slide 9-11: Sprint 2 (21 Apr - 4 Mei 2026) — Mobile Core & Presensi Flow
- Sprint Planning: Goal, 47 SP
- Sprint Backlog: 24 tasks, semua Done
- Sprint Review: 8 fitur demo (scan QR, GPS, izin), PO minta face recognition
- Retrospective: Well (mobile fungsional, velocity naik), Didn't (face belum, UI basic)

### Slide 12-14: Sprint 3 (5-18 Mei 2026) — Security & Advanced Features
- Sprint Planning: Goal, 53 SP (stretch target)
- Sprint Backlog: 28 tasks, semua Done
- Sprint Review: 10 fitur demo termasuk FACE RECOGNITION (fitur unggulan), AI chatbot, live monitor
- Retrospective: Well (face berhasil, 53 SP tertinggi), Didn't (tech debt, manual testing)

### Slide 15: Sprint 4 (19 Mei - 8 Juni 2026) — In Progress
- Status: Production Readiness, 21 SP target
- Focus: Smoke test E2E, UI bug fixes, demo preparation
- Progress: 6 SP done, 8 SP in progress, 7 SP to do

### Slide 16: Product Backlog Refinement
- Perubahan prioritas selama proyek
- Story baru yang muncul (onboarding, at-risk, UU PDP)
- Re-estimation SP (US-08: 8→13, US-05: 5→8)
- Definition of Done (7 kriteria)

### Slide 17: Velocity Chart
- Bar chart: Sprint 1=42, Sprint 2=47, Sprint 3=53, Sprint 4=21 (in progress)
- Rata-rata: 47.3 SP/sprint
- Tren naik +12% → +13% → controlled decrease (quality focus)

### Slide 18: Burndown Chart
- 3 burndown charts (Sprint 1, 2, 3)
- Ideal line vs Actual line
- Highlight: Sprint 3 paling menantang (face recognition di awal)

### Slide 19: Ringkasan Progres
- 142/160 SP selesai (88.75%)
- 23/25 User Stories done
- Must+Should+Could: 100% complete
- Fitur unggulan: 3-Layer Verification

### Slide 20: Pencapaian Utama
- 3-Layer Security (QR + GPS + Face)
- Full-stack dalam 6 minggu
- Enterprise-grade security (RLS, rate limiting, audit log)
- AI-powered chatbot
- UU PDP compliance

### Slide 21: Tantangan & Pembelajaran
- Face Recognition complexity → re-estimate SP
- RLS policy conflicts → consolidation approach
- API contract mismatch → standardize naming
- Tim improvement: setup environment lebih baik

### Slide 22: Kesimpulan
- Release candidate tercapai dalam 3 sprint
- Velocity positif konsisten
- 3-layer verifikasi sebagai diferensiasi utama
- Sprint 4 fokus quality + demo 8 Juni

### Slide 23: Q&A / Penutup
- Terima kasih
- Contact info tim

## Instruksi Desain
- Gunakan tema profesional (biru tua + putih + aksen emas/hijau)
- Font: Poppins atau Montserrat
- Setiap slide maksimal 6-8 bullet point
- Gunakan ikon/grafik untuk visualisasi
- Tabel harus rapi dan readable
- Chart velocity & burndown harus visual (bukan teks)
- Slide tidak boleh terlalu padat — prioritaskan readability

## Data Pendukung
Semua data berasal dari dokumen Scrum proyek yang sudah disusun berdasarkan data aktual development log, bukan simulasi.
```

---

> **Cara Pakai:**
> 1. Copy seluruh teks di dalam blok ``` di atas
> 2. Paste ke Notebook LLM (Google AI Studio / ChatGPT / Gemini)
> 3. Minta generate slide content atau langsung minta format PPTX
> 4. Untuk membuat file PPTX langsung, tambahkan: "Buatkan dalam format file PPTX yang bisa didownload"
