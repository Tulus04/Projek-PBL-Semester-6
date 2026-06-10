# Requirements Document

## Introduction

Redesign halaman **Beranda mobile** (`mypresensi-mobile/lib/features/home/screens/home_screen.dart`) supaya menampilkan **riwayat kehadiran dalam format kalender** (week strip + agenda per hari), menggantikan section "Aktivitas Terakhir" yang sekarang berupa daftar linear.

Tujuan: mahasiswa bisa melihat sekilas (glanceable) pola kehadiran minggu ini langsung dari Beranda — hari mana hadir, izin, atau alpa — tanpa harus buka tab Riwayat. Ini melengkapi kalender bulan-penuh yang sudah ada di tab Riwayat (`history_calendar_view.dart`) dengan pola "preview di Beranda, detail di tab".

**Sumber kebenaran desain visual**: `docs/ui-research/mockups/home-riwayat-kalender.html`.

**Scope**: Mobile-only (aplikasi mahasiswa). Tidak menyentuh web admin/dosen.

**Konteks teknis yang sudah ada (akan di-reuse, bukan dibangun dari nol)**:
- Model `AttendanceRecord` (`scannedAt`, `status`, `courseName`, `sessionNumber`).
- Logika status dominan + mapping warna/ikon/label di `history_calendar_view.dart` (`_dominantStatus`, `_statusFg`, `_statusTint`, `_statusIcon`, `_statusLabel`, `_groupByDate`).
- Package `table_calendar ^3.1.3` (sudah di-approve, dipakai tab Riwayat).
- Provider Riverpod: `recentActivitiesProvider`, `historyProvider`, `activeSessionsProvider`.
- Design system rule `22-mobile-design-system.md` (AppCard, AppShadows, Iconsax, token warna) + UX writing rule `09`.

---

## Glossary

- **Week strip**: baris 7 hari (Senin–Minggu) di Beranda, tiap hari menampilkan tanggal + indikator status dominan.
- **Status dominan**: 1 status yang mewakili hari itu kalau ada >1 kelas, dipilih berdasarkan prioritas terburuk (alpa > terlambat > izin/sakit > hadir). Sudah ada logikanya di `history_calendar_view.dart`.
- **Agenda hari terpilih**: daftar kelas/presensi pada hari yang dipilih user di week strip.
- **Hari ini**: tanggal lokal perangkat saat aplikasi dibuka.

---

## Requirements

### Requirement 1: Week strip riwayat kehadiran di Beranda

**User Story:** Sebagai mahasiswa, saya ingin melihat ringkasan kehadiran 7 hari minggu ini di Beranda, supaya saya langsung tahu pola hadir/izin/alpa saya tanpa membuka tab lain.

#### Acceptance Criteria

1. WHEN Beranda dibuka dan data riwayat tersedia THEN sistem SHALL menampilkan kartu "Riwayat Kehadiran" berisi week strip 7 hari untuk minggu yang sedang aktif (Senin–Minggu).
2. WHERE sebuah hari memiliki minimal satu record presensi THE sistem SHALL memberi tint background + indikator dot pada hari tersebut sesuai status dominan (hadir=hijau, izin/sakit=kuning/amber, terlambat=info/biru, alpa=merah), reuse mapping warna dari `history_calendar_view.dart`.
3. WHILE hari tertentu adalah hari ini THE sistem SHALL menandai hari tersebut secara visual berbeda (outline/penanda) dari hari lain.
4. WHERE sebuah hari berada di masa depan (setelah hari ini) THE sistem SHALL menampilkannya dalam keadaan non-aktif (redup) tanpa indikator status.
5. WHERE sebuah hari di masa lalu tidak memiliki record presensi THE sistem SHALL menampilkannya netral (tanpa tint status) dan tidak boleh menampilkan status palsu.
6. THE sistem SHALL menampilkan legend status (Hadir / Izin-Sakit / Alpa, dan Terlambat bila status itu dipakai) di dalam atau dekat kartu.

---

### Requirement 2: Agenda hari terpilih

**User Story:** Sebagai mahasiswa, saya ingin menekan satu hari di week strip lalu melihat detail kelas pada hari itu, supaya saya tahu kelas apa saja dan status presensinya.

#### Acceptance Criteria

1. WHEN Beranda pertama kali dibuka THEN sistem SHALL memilih hari ini sebagai hari terpilih default dan menampilkan agenda hari ini.
2. WHEN user menekan salah satu hari di week strip THEN sistem SHALL memperbarui agenda menampilkan daftar record presensi pada hari tersebut.
3. WHERE hari terpilih memiliki record THE sistem SHALL menampilkan tiap record dengan nama mata kuliah, jam, nomor pertemuan, dan badge status (reuse pola `_DayDetailItem`/status pill yang sudah ada).
4. IF hari terpilih tidak memiliki record presensi THEN sistem SHALL menampilkan empty state ramah dalam Bahasa Indonesia (mis. "Tidak ada kelas tercatat di hari ini") tanpa terlihat seperti error.
5. WHEN user menekan hari di masa depan THEN sistem SHALL menampilkan agenda kosong/empty state dan TIDAK menampilkan data palsu.
6. THE label tanggal agenda SHALL ditulis dalam Bahasa Indonesia (mis. "Sabtu, 31 Mei").

---

### Requirement 3: Navigasi antar minggu

**User Story:** Sebagai mahasiswa, saya ingin berpindah ke minggu sebelumnya atau berikutnya dari week strip, supaya saya bisa melihat riwayat kehadiran di luar minggu ini.

#### Acceptance Criteria

1. THE kartu Riwayat Kehadiran SHALL menyediakan kontrol navigasi minggu sebelumnya dan minggu berikutnya (caret kiri/kanan).
2. WHEN user menavigasi ke minggu lain THEN sistem SHALL memperbarui week strip dan label periode (mis. "Mei 2026 · Minggu ini" / rentang tanggal) sesuai minggu yang ditampilkan.
3. WHERE minggu yang ditampilkan adalah minggu berjalan THE label SHALL menandainya sebagai "Minggu ini".
4. THE navigasi minggu SHALL dibatasi pada rentang data yang masuk akal (mulai semester berjalan hingga minggu berjalan), konsisten dengan rentang kalender tab Riwayat.
5. WHEN user berpindah minggu THEN hari terpilih dan agenda SHALL ikut menyesuaikan dengan logika yang jelas (mis. default ke hari pertama berdata pada minggu itu, atau hari ini bila minggu berjalan) — perilaku final ditetapkan di fase design.

---

### Requirement 4: Tautan ke kalender penuh (tab Riwayat)

**User Story:** Sebagai mahasiswa, saya ingin satu tap dari Beranda menuju kalender bulan-penuh, supaya saya bisa melihat detail riwayat lebih lengkap.

#### Acceptance Criteria

1. THE kartu Riwayat Kehadiran SHALL menampilkan aksi "Kalender penuh" (atau setara) yang jelas.
2. WHEN user menekan aksi tersebut THEN sistem SHALL berpindah ke tab Riwayat (index 2) menggunakan pola navigasi tab yang sudah ada (`currentTabProvider.setTab(2)`), bukan membuat route baru.
3. THE navigasi ini SHALL TIDAK menyebabkan dead-end — user tetap bisa kembali ke Beranda lewat bottom nav/back.

---

### Requirement 5: Tiga state (loading, empty, error)

**User Story:** Sebagai mahasiswa, saya ingin Beranda selalu memberi konteks yang jelas saat data sedang dimuat, kosong, atau gagal, supaya saya tidak melihat layar membingungkan.

#### Acceptance Criteria

1. WHILE data riwayat sedang dimuat THE sistem SHALL menampilkan skeleton/placeholder pada area kartu Riwayat Kehadiran (bukan layar kosong dan bukan teks "Loading...").
2. IF pengambilan data riwayat gagal THEN sistem SHALL menampilkan error state ramah Bahasa Indonesia dengan tombol coba lagi yang memicu refetch.
3. IF mahasiswa belum punya satu pun record presensi (akun baru) THEN sistem SHALL menampilkan empty state ramah dengan ajakan, konsisten dengan rule UX (mis. "Belum ada riwayat absen. Yuk mulai absen!").
4. THE penanganan tiga state ini SHALL konsisten dengan komponen yang sudah ada (`ErrorState`, skeleton hero pattern) dan rule `22-mobile-design-system`.

---

### Requirement 6: Integritas data dan sinkronisasi

**User Story:** Sebagai mahasiswa, saya ingin riwayat di Beranda selalu mencerminkan presensi terbaru saya, supaya tidak ada kebingungan antara yang saya lakukan dan yang ditampilkan.

#### Acceptance Criteria

1. WHEN user submit presensi lalu kembali ke Beranda THEN week strip dan agenda SHALL mencerminkan record baru tanpa perlu hot restart manual (hindari BUG-017 — invalidate provider eksplisit setelah mutasi).
2. WHEN user melakukan pull-to-refresh di Beranda THEN sistem SHALL me-refresh data riwayat bersama data sesi aktif yang sudah ada.
3. THE pengelompokan record per tanggal SHALL memakai tanggal lokal `scannedAt` (reuse `_groupByDate`/`_dateKey`), bukan UTC mentah, agar batas hari benar untuk zona waktu pengguna.
4. THE sumber data riwayat minggu ini SHALL diputuskan di fase design — apakah reuse data `historyProvider` yang sudah di-fetch, atau perlu endpoint/parameter baru. IF perlu endpoint server baru `/api/mobile/*` THEN itu SHALL ditandai eksplisit sebagai keputusan design dan mengikuti aturan keamanan (auth, anti-IDOR, audit bila mutasi).

---

### Requirement 7: Konsistensi struktur dan komponen Beranda

**User Story:** Sebagai pengembang, saya ingin redesign ini tidak merusak section Beranda lain dan tetap mengikuti design system, supaya kualitas dan konsistensi terjaga.

#### Acceptance Criteria

1. THE hero session card (state aktif, empty, loading, error) yang sudah ada SHALL dipertahankan di Beranda.
2. THE kartu Statistik Kehadiran (ring persen + legend) SHALL tetap ada sesuai mockup.
3. WHEN section Beranda ditambah/diubah/dihapus THEN konstanta animasi staggered (`_sectionCount`) SHALL diperbarui konsisten agar tidak terjadi RangeError (cegah ulang BUG-12).
4. THE nasib section "Aktivitas Terakhir" dan "Quick Action Grid" SHALL diputuskan eksplisit di fase design (diganti kalender, dipindah, atau dipertahankan) — mockup acuan tidak menampilkan keduanya.
5. THE implementasi SHALL memakai komponen & token design system yang ada (AppCard, AppShadows, Iconsax Plus, AppColors) dan TIDAK menambah package kalender pihak ketiga baru di luar `table_calendar` yang sudah di-approve, kecuali disepakati lewat diskusi.
6. THE seluruh teks user-facing SHALL Bahasa Indonesia, ramah, dan ringkas sesuai rule `09-ux-writing-voice` (sapaan "kamu", bukan jargon teknis).

---

## Out of Scope

- Perubahan UI web admin/dosen.
- Fitur jadwal kuliah (schedule-first / agenda jadwal mendatang) — mockup ini berbasis **riwayat**, bukan jadwal.
- Penambahan status baru di luar enum yang ada (hadir/izin/sakit/alpa; "terlambat" hanya ditampilkan jika sudah dipakai di data).
- Perubahan logika perhitungan/threshold presensi server-side.

## Catatan untuk Fase Design (perlu diputuskan)

1. **Sumber data minggu**: reuse `historyProvider` (sudah fetch semua record semester) lalu filter per minggu di client, ATAU endpoint ringkasan minggu baru. Reuse lebih hemat & cepat bila data sudah ada.
2. **Nasib Quick Action Grid + Activity Feed**: kalender riwayat menggantikan Activity Feed (overlap informasi), Quick Action Grid dipertahankan atau tidak.
3. **Widget kalender**: bikin week-strip kustom ringan (sesuai mockup), atau pakai `table_calendar` mode minggu. Mockup memakai week strip kustom 7-pill, kemungkinan lebih ringan & sesuai visual.
4. **Perilaku hari terpilih saat pindah minggu** (R3.5).
