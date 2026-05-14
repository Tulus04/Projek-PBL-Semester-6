# Alur Kerja MyPresensi — Workflow Lengkap

## Overview Arsitektur

```mermaid
graph LR
    A["👨‍💼 Admin<br/>(Web)"] --> API["☁️ Supabase<br/>Database + Auth"]
    B["👨‍🏫 Dosen<br/>(Web)"] --> API
    C["👨‍🎓 Mahasiswa<br/>(Mobile)"] --> NX["🖥️ Next.js API<br/>/api/mobile/*"]
    NX --> API
    B --> QR["📱 QR Code<br/>Display"]
    QR -.->|scan| C
```

---

## Fase 1: Setup Awal (Admin)

```mermaid
flowchart TD
    A1["Admin login ke Web Dashboard"] --> A2["Input data Dosen<br/>(nama, NIP, email)"]
    A2 --> A3["Import data Mahasiswa via CSV<br/>(nama, NIM, email, semester, kelas)"]
    A3 --> A4["Buat Mata Kuliah<br/>(nama MK, SKS, assign Dosen)"]
    A4 --> A5["Konfigurasi Settings<br/>(radius geofencing, toleransi terlambat)"]
    A5 --> A6["✅ Sistem siap digunakan"]

    style A6 fill:#1A7F37,color:#fff
```

### Detail:
| Langkah | Platform | Keterangan |
|---------|----------|------------|
| Input Dosen | Web | Admin menambahkan dosen, sistem auto-generate akun Supabase Auth |
| Import Mahasiswa | Web | Upload CSV → sistem buat akun massal, password default: `NIM@politani` |
| Buat Mata Kuliah | Web | Assign dosen pengampu ke setiap mata kuliah |
| Settings | Web | Set radius GPS (misal 100m dari kampus), toleransi terlambat (15 menit) |

---

## Fase 2: Mahasiswa Setup Pertama Kali

```mermaid
flowchart TD
    M1["Mahasiswa buka browser<br/>akses web MyPresensi"] --> M2["Login dengan email + password default<br/>(NIM@politani)"]
    M2 --> M3["Sistem redirect ke halaman<br/>Ubah Password"]
    M3 --> M4["Mahasiswa set password baru"]
    M4 --> M5["Install APK MyPresensi<br/>di HP Android"]
    M5 --> M6["Login di mobile app<br/>dengan password baru"]
    M6 --> M7["✅ Mahasiswa siap presensi"]

    style M7 fill:#1A7F37,color:#fff
```

> **Kenapa harus ganti password via web dulu?**
> Keamanan — password default (`NIM@politani`) terlalu mudah ditebak. Sistem memaksa ganti password sebelum bisa akses fitur mobile.

---

## Fase 3: Presensi Harian (Inti Sistem)

Ini adalah workflow utama yang terjadi **setiap pertemuan kuliah**:

```mermaid
sequenceDiagram
    participant D as 👨‍🏫 Dosen (Web)
    participant S as ☁️ Server
    participant M as 👨‍🎓 Mahasiswa (Mobile)

    Note over D: Di kelas, buka web dashboard
    D->>S: Buat Sesi Pertemuan Baru
    S-->>D: Generate QR Code + Session Code

    Note over D: Tampilkan QR di layar proyektor

    Note over M: Buka app MyPresensi
    M->>M: Scan QR Code dari layar

    Note over M: App otomatis jalankan verifikasi

    M->>M: 📍 Cek GPS (dalam radius kampus?)
    M->>M: 📸 Cek Wajah (face match?)
    M->>S: Submit: QR code + GPS + face data

    S->>S: Validasi server-side
    Note over S: 1. Session code valid?<br/>2. GPS dalam radius? (Haversine)<br/>3. Face match?<br/>4. Belum pernah absen?<br/>5. Masih dalam waktu sesi?

    alt Semua valid
        S-->>M: ✅ Presensi berhasil — Hadir
    else Terlambat
        S-->>M: ⚠️ Presensi dicatat — Terlambat
    else Gagal
        S-->>M: ❌ Presensi ditolak + alasan
    end

    Note over D: Monitoring real-time
    D->>S: Lihat siapa saja yang sudah hadir
    S-->>D: Daftar kehadiran real-time
```

### Detail Per Langkah:

| # | Aktor | Aksi | Platform | Validasi |
|---|-------|------|----------|----------|
| 1 | Dosen | Buat sesi pertemuan baru | Web | - |
| 2 | Dosen | Tampilkan QR Code di proyektor | Web | QR berisi session code unik |
| 3 | Mahasiswa | Buka app → tap "Scan QR" | Mobile | - |
| 4 | Mahasiswa | Arahkan kamera ke QR | Mobile | Decode session code |
| 5 | System | Cek GPS mahasiswa | Mobile + Server | Haversine distance ≤ radius setting |
| 6 | System | Verifikasi wajah | Mobile | Face match dengan data terdaftar |
| 7 | System | Submit ke server | Server | Cek duplikasi, waktu sesi, validitas |
| 8 | Dosen | Monitor kehadiran | Web | Lihat siapa hadir/terlambat/belum |
| 9 | Dosen | Tutup sesi | Web | Mahasiswa yang belum absen = Alpha |

---

## Fase 4: Penanganan Izin/Sakit

```mermaid
flowchart TD
    M1["Mahasiswa tidak bisa hadir"] --> M2{"Alasan?"}
    M2 -->|Sakit| M3["Upload surat sakit<br/>via mobile app"]
    M2 -->|Izin| M4["Input alasan izin<br/>via mobile app"]
    M3 --> M5["Dosen review di web"]
    M4 --> M5
    M5 --> M6{"Approve?"}
    M6 -->|Ya| M7["Status: Sakit/Izin ✅"]
    M6 -->|Tidak| M8["Status: Alpha ❌"]

    style M7 fill:#1A7F37,color:#fff
    style M8 fill:#CF222E,color:#fff
```

---

## Fase 5: Rekap & Reporting (Admin + Dosen)

```mermaid
flowchart LR
    R1["Dosen buka<br/>Rekap Kehadiran"] --> R2["Filter: MK, Kelas,<br/>Periode, Status"]
    R2 --> R3["Lihat tabel rekap<br/>per mahasiswa"]
    R3 --> R4["Export ke CSV/PDF"]

    A1["Admin buka<br/>Dashboard"] --> A2["Lihat statistik global<br/>% kehadiran, trend"]
    A2 --> A3["Audit Log<br/>tracking semua aksi"]
```

### Yang Bisa Dilihat:

| Role | Data | Format |
|------|------|--------|
| **Dosen** | Rekap per MK yang diampu, per kelas, per mahasiswa | Tabel + Export CSV |
| **Admin** | Rekap seluruh MK, semua dosen, statistik global | Dashboard + Export |
| **Mahasiswa** | Riwayat kehadiran pribadi | List di mobile app |

---

## Status Kehadiran

| Status | Kode Warna | Kondisi |
|--------|:---:|---------|
| **Hadir** | 🟢 | Scan QR + GPS valid + Face valid, dalam waktu |
| **Terlambat** | 🟡 | Sama seperti hadir, tapi melebihi batas toleransi |
| **Izin** | 🔵 | Diajukan mahasiswa, disetujui dosen |
| **Sakit** | 🟠 | Diajukan + surat sakit, disetujui dosen |
| **Alpha** | 🔴 | Tidak hadir, tidak ada keterangan |

---

## Security Flow

```mermaid
flowchart TD
    S1["3 Layer Verifikasi"] --> S2["🔐 QR Code<br/>Bukti ada di kelas<br/>(session-specific, rotating)"]
    S1 --> S3["📍 GPS Geofencing<br/>Bukti lokasi fisik<br/>(server-side Haversine)"]
    S1 --> S4["📸 Face Verification<br/>Bukti identitas<br/>(anti-titip absen)"]

    S2 --> V["Server Validasi"]
    S3 --> V
    S4 --> V
    V --> R["✅ Presensi Sah"]

    style S1 fill:#5483AD,color:#fff
    style V fill:#3A6B8F,color:#fff
    style R fill:#1A7F37,color:#fff
```

**Kenapa 3 layer?**
- **QR saja** → bisa dishare via foto/screenshot
- **QR + GPS** → bisa dipalsukan lokasi (fake GPS)
- **QR + GPS + Face** → hampir mustahil dipalsukan (harus fisik ada di lokasi + wajah cocok)

---

## Ringkasan: Siapa Pakai Apa

| Role | Platform | Fitur Utama |
|------|----------|-------------|
| **Admin** | 🌐 Web only | Master data, settings, audit, rekap global |
| **Dosen** | 🌐 Web only | Buat sesi, QR code, monitoring, approve izin, rekap |
| **Mahasiswa** | 📱 Mobile only | Login, scan QR, GPS, face, riwayat, notifikasi |
