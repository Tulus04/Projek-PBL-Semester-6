# Requirements Document

## Introduction

Phase 5 Mobile UI Rebuild menyelesaikan rangkaian overhaul UI mahasiswa di aplikasi MyPresensi mobile (Flutter) agar sejajar dengan mockup Solar/Iconsax-style yang sudah final di `docs/ui-research/mockups/`. Fase sebelumnya telah menyelesaikan token migration (`#5483AD` → `#2D86FF`), shadow tokens, helper widgets (`SemanticIcon`, `HeroCard`, `AppCard`, `KpiIconBox`), shell 5-tab v7, plus tiga screen rebuild (Profile / MyLeaveRequests / Notifications). Spec ini menutup rangkaian dengan rebuild **tiga screen mahasiswa terakhir** (Home, History, Submit Leave Request) yang **murni perubahan lapisan UI** — provider, repository, model data, dan endpoint backend tidak diubah. Satu task opsional cross-platform (sinkronisasi token `--color-primary` di `globals.css` web) juga dibahas.

Setiap rebuild wajib lulus `flutter analyze` dengan output "No issues found" sebelum task ditandai selesai (rule `02-quality-debugging-verification.md`), dan diakhiri dengan smoke test manual oleh user untuk memverifikasi visual parity yang tidak bisa dideteksi oleh static analyzer.

## Glossary

- **Mobile_App**: Aplikasi Flutter `mypresensi-mobile/` yang dijalankan di perangkat Android mahasiswa.
- **Home_Screen**: Layar utama tab Beranda di `lib/features/home/screens/home_screen.dart`.
- **History_Screen**: Layar tab Riwayat di `lib/features/history/screens/history_screen.dart`.
- **Submit_Leave_Wizard**: Layar `lib/features/leave_requests/screens/submit_leave_request_screen.dart` setelah refactor menjadi wizard 4-step.
- **Hero_Card_Active**: Komponen hero card dengan gradient primary→navy, gold radial glow, pulse-dot badge, dan tombol "Scan QR Sekarang" yang ditampilkan di Home_Screen ketika ada sesi aktif belum di-submit.
- **Hero_Card_Empty**: Komponen hero dengan dashed border, icon kalender duotone, dan info sesi berikutnya (opsional) yang ditampilkan di Home_Screen ketika tidak ada sesi aktif.
- **Today_Summary_Row**: Strip 3-stat (Hadir / Sisa Sesi / Alpa) di Home_Screen, dihitung lokal dari list `activeSessions`.
- **Quick_Action_Grid**: Grid 4-item di Home_Screen — Scan QR (variant featured gold), Riwayat, Izin, Profil — yang men-trigger `context.push('/scan')` atau `currentTabProvider.setTab(N)`.
- **History_Hero_Summary**: Hero card di History_Screen yang menampilkan progress bar kehadiran + 5-stat (Hadir / Telat / Izin / Sakit / Alpa).
- **History_Filter_Chips**: 6 chip horizontal-scrollable di History_Screen dengan label `Semua / Hadir / Telat / Izin / Sakit / Alpa`. Label `Telat` memetakan ke enum status DB `terlambat`.
- **Smart_Date_Group**: Pengelompokan riwayat berdasarkan kategori `Hari Ini` / `Kemarin` / `Minggu Ini` / `Bulan Ini` / `Lebih Lama` (relatif terhadap `DateTime.now()`).
- **History_Detail_Sheet**: Bottom sheet informational yang muncul saat tap riwayat item, ditutup via swipe-down handle atau tap dim overlay (tanpa tombol aksi).
- **Wizard_Step**: Enum `pickSession | typeAndReason | evidence | review` yang merepresentasikan langkah saat ini di Submit_Leave_Wizard.
- **Step_Bar**: Indikator visual 4 lingkaran + connector line di header Submit_Leave_Wizard yang menunjukkan progress step.
- **Wizard_Footer_CTA**: Tombol pill full-width di footer wizard, label dinamis (`Lanjut ke Tipe Izin` / `Lanjut Lampiran` / `Lanjut ke Review` / `Kirim Pengajuan`) sesuai step aktif.
- **Active_Sessions_Provider**: `activeSessionsProvider` di `lib/features/attendance/providers/attendance_provider.dart`. Endpoint sumber: `GET /api/mobile/sessions/active`.
- **History_Provider**: `historyProvider` di `lib/features/history/providers/history_provider.dart`. Endpoint sumber: `GET /api/mobile/attendance/history`.
- **Submit_Leave_Provider**: `submitLeaveProvider` di `lib/features/leave_requests/providers/leave_provider.dart`. Endpoint sumber: `POST /api/mobile/leave-requests/submit`.
- **Leave_Repository**: `LeaveRepository` di `lib/features/leave_requests/data/leave_repository.dart`, khususnya method `uploadEvidence(File)` → `POST /api/mobile/leave-requests/upload-evidence`.
- **Design_Tokens**: Konstanta dari `lib/core/theme/app_colors.dart` (warna) dan `lib/core/theme/app_shadows.dart` (shadow). Termasuk `AppColors.primary`, `AppColors.bg`, `AppShadows.card`, `AppShadows.hero`, dll.
- **Helper_Widgets**: `SemanticIcon`, `HeroCard`, `AppCard`, `KpiIconBox` di `lib/shared/widgets/`.
- **Iconsax_Bold**: Variant `IconsaxPlusBold.*` dari package `iconsax_plus: ^1.0.0` (Bulk variant tidak tersedia di v1.0.0; Bold dipakai sebagai pengganti paling solid).
- **flutter_analyze**: Perintah `flutter analyze` yang dijalankan di working directory `mypresensi-mobile/`. Output "No issues found" dianggap exit 0.

## Requirements

### Requirement 1: Reconciliasi Mockup Home

**User Story:** Sebagai developer yang merebuild Home_Screen, saya ingin tahu mockup mana yang menjadi sumber kebenaran sehingga implementasi tidak bercabang antara dua versi.

#### Acceptance Criteria

1. THE Mobile_App SHALL menggunakan `docs/ui-research/mockups/mobile-home.html` sebagai canonical source untuk Home_Screen rebuild, bukan `mobile-mockup.html`.
2. WHERE komponen Home_Screen ditemukan di kedua mockup dengan visual berbeda, THE Home_Screen SHALL mengikuti definisi di `mobile-home.html`.
3. THE design.md SHALL mendokumentasikan keputusan pemilihan mockup canonical pada section "Decisions Table" baris D1.

### Requirement 2: Home Hero Card — State Aktif

**User Story:** Sebagai mahasiswa yang punya sesi sedang berlangsung, saya ingin Home_Screen menampilkan hero card menonjol yang langsung mengarahkan saya ke Scan QR sehingga saya tidak perlu mencari menu lain.

#### Acceptance Criteria

1. WHEN `Active_Sessions_Provider` mengembalikan minimal satu sesi dengan `alreadySubmitted == false`, THE Home_Screen SHALL menampilkan Hero_Card_Active dengan informasi sesi tersebut (nama mata kuliah, dosen, lokasi, jam mulai-selesai).
2. THE Hero_Card_Active SHALL menggunakan `AppColors.primaryGradient` (linear primary → navy) sebagai background, `AppShadows.hero` untuk drop shadow, dan radial gradient `AppColors.accentSoft` di sudut kanan atas sebagai gold glow signature.
3. THE Hero_Card_Active SHALL menampilkan badge animasi pulse-dot dengan label "SESI AKTIF SEKARANG" di bagian atas card.
4. THE Hero_Card_Active SHALL menampilkan tombol pill putih full-width berlabel "Scan QR Sekarang" dengan icon `IconsaxPlusBold.scan_barcode` (atau equivalent).
5. WHEN mahasiswa menekan tombol "Scan QR Sekarang" di Hero_Card_Active, THE Mobile_App SHALL melakukan `context.push('/scan')` ke `ScanQrScreen` yang sudah ada.

### Requirement 3: Home Hero Card — State Empty

**User Story:** Sebagai mahasiswa yang membuka aplikasi saat tidak ada sesi aktif, saya ingin tahu bahwa tidak ada sesi yang sedang berlangsung dan diberi konteks kapan sesi berikutnya akan dibuka, sehingga saya tidak terjebak di halaman yang terlihat kosong.

#### Acceptance Criteria

1. WHEN `Active_Sessions_Provider` mengembalikan list kosong setelah filter `where(!s.alreadySubmitted)`, THE Home_Screen SHALL menampilkan Hero_Card_Empty.
2. THE Hero_Card_Empty SHALL menggunakan background `AppColors.surface` dengan dashed border `AppColors.borderStrong` 1.5px dan radius 18px.
3. THE Hero_Card_Empty SHALL menampilkan icon `IconsaxPlusBold.calendar_2` (atau equivalent kalender) dalam container 56×56 dengan background `AppColors.primarySurface` dan icon color `AppColors.primary`.
4. THE Hero_Card_Empty SHALL menampilkan judul "Tidak ada sesi aktif saat ini" dan paragraf penjelas "Belum ada dosen yang memulai sesi. Kamu akan mendapat notifikasi saat sesi dimulai."
5. WHERE backend tidak menyediakan informasi sesi berikutnya, THE Hero_Card_Empty SHALL tetap menampilkan card empty tanpa info next-session (tidak ada error rendering).

### Requirement 4: Home Hero Card — State Loading

**User Story:** Sebagai mahasiswa yang membuka aplikasi sambil koneksi sedang lambat, saya ingin melihat indikator loading yang jelas dan tidak halaman kosong yang membingungkan.

#### Acceptance Criteria

1. WHEN `Active_Sessions_Provider` masih dalam state loading (initial fetch atau refresh), THE Home_Screen SHALL menampilkan skeleton placeholder untuk hero, summary, dan quick action.
2. THE skeleton SHALL menggunakan background `AppColors.surfaceSunken` dengan animasi opacity 0.5↔1.0 atau shimmer container, durasi loop 1.4 detik.
3. WHILE skeleton ditampilkan, THE bottom navigation bar SHALL tetap visible dan interactive.

### Requirement 5: Home Today Summary

**User Story:** Sebagai mahasiswa, saya ingin melihat ringkasan kehadiran hari ini di tampilan utama sehingga saya tahu berapa sesi yang sudah saya ikuti dan berapa yang belum.

#### Acceptance Criteria

1. WHEN `Active_Sessions_Provider` mengembalikan data, THE Home_Screen SHALL menampilkan Today_Summary_Row di bawah hero card dengan 3 stat: Hadir, Sisa Sesi, Alpa.
2. THE Today_Summary_Row "Hadir" SHALL menampilkan format `<count_submitted>/<total>` dengan warna hijau `AppColors.success`, menghitung jumlah sesi dengan `alreadySubmitted == true` dibanding total sesi aktif.
3. THE Today_Summary_Row "Sisa Sesi" SHALL menampilkan jumlah sesi dengan `alreadySubmitted == false` dengan warna `AppColors.primary`.
4. THE Today_Summary_Row "Alpa" SHALL menampilkan angka `0` dengan warna `AppColors.danger` sebagai placeholder hingga endpoint dashboard dedicated tersedia.

### Requirement 6: Home Quick Action Grid

**User Story:** Sebagai mahasiswa, saya ingin akses cepat ke 4 aksi paling sering dipakai (Scan QR, Riwayat, Izin, Profil) langsung dari Home_Screen tanpa harus selalu lewat bottom navigation.

#### Acceptance Criteria

1. THE Home_Screen SHALL menampilkan Quick_Action_Grid dengan 4 item: Scan QR (variant featured), Riwayat (variant success), Izin (variant warning), Profil (variant info).
2. THE Quick_Action_Grid item "Scan QR" SHALL menggunakan `KpiIconBox` dengan `KpiColor.featured` (background `AppColors.accent` solid, icon putih) sebagai signature visual gold.
3. WHEN mahasiswa menekan Quick_Action_Grid item "Scan QR", THE Mobile_App SHALL melakukan `context.push('/scan')`.
4. WHEN mahasiswa menekan Quick_Action_Grid item "Riwayat", THE Mobile_App SHALL memanggil `currentTabProvider.notifier.setTab(1)`.
5. WHEN mahasiswa menekan Quick_Action_Grid item "Izin", THE Mobile_App SHALL memanggil `currentTabProvider.notifier.setTab(2)`.
6. WHEN mahasiswa menekan Quick_Action_Grid item "Profil", THE Mobile_App SHALL memanggil `currentTabProvider.notifier.setTab(4)`.

### Requirement 7: Home AI Chat FAB

**User Story:** Sebagai mahasiswa, saya ingin akses cepat ke Asisten AI dari Home_Screen via FAB sehingga saya tidak harus selalu masuk ke menu Profil setiap kali butuh tanya AI.

#### Acceptance Criteria

1. THE Home_Screen SHALL menampilkan AI Chat FAB di posisi bottom-right (Stack overlay di atas konten scrollable, padding 16px dari edge), berdiameter 56×56 px.
2. THE AI Chat FAB SHALL menggunakan gradient `AppColors.accent` → `AppColors.accentSoft` (gold signature) dengan `AppShadows.fab`.
3. THE AI Chat FAB SHALL menampilkan icon `IconsaxPlusBold.message_question` (atau equivalent chat icon) berwarna putih, ukuran 24px.
4. WHEN mahasiswa menekan AI Chat FAB, THE Mobile_App SHALL melakukan `context.push('/ai-chat')` ke `AiChatScreen` yang sudah ada.
5. THE AI Chat FAB SHALL TIDAK menggantikan menu "Asisten AI" di Profile_Screen — kedua entry point dipertahankan untuk fleksibilitas (dual access).
6. WHILE Home_Screen dalam state loading skeleton, THE AI Chat FAB SHALL TETAP visible dan interactive (tidak ikut di-skeleton-kan).

### Requirement 8: Home Activity Feed Omitted

**User Story:** Sebagai pemilik produk, saya ingin Home_Screen tidak menampilkan section yang tidak punya data nyata (dummy placeholder) sehingga UI tidak terlihat dead-end.

#### Acceptance Criteria

1. WHERE backend belum menyediakan endpoint dashboard activity feed, THE Home_Screen SHALL TIDAK menampilkan section "Aktivitas Terakhir" sampai endpoint tersedia.
2. THE design.md SHALL mendokumentasikan keputusan omit di Decisions Table baris D5.

### Requirement 9: History Hero Summary

**User Story:** Sebagai mahasiswa, saya ingin melihat ringkasan kehadiran semester saya di atas list riwayat sehingga saya langsung tahu performa keseluruhan.

#### Acceptance Criteria

1. WHEN `History_Provider` mengembalikan data, THE History_Screen SHALL menampilkan History_Hero_Summary di atas list riwayat.
2. THE History_Hero_Summary SHALL menggunakan `AppColors.primaryGradient` background dengan gold radial glow (pattern `HeroCard`).
3. THE History_Hero_Summary SHALL menampilkan persentase kehadiran besar (font size ≥ 36, weight 800), di-pull dari `summary.percentage`, ditambah label kategori ("Sangat Baik" / "Baik" / "Cukup" / "Perlu Diperhatikan") berdasarkan threshold sederhana.
4. THE History_Hero_Summary SHALL menampilkan progress bar horizontal di bawah angka utama, dengan fill width sesuai persentase, gradient hijau ke gold.
5. THE History_Hero_Summary SHALL menampilkan baris detail 5-stat dengan icon + count: Hadir, Telat, Izin, Sakit, Alpa, dipetakan dari `summary.hadir`, `summary.terlambat`, `summary.izin`, `summary.sakit`, `summary.alpa`.

### Requirement 10: History Filter Chips

**User Story:** Sebagai mahasiswa, saya ingin memfilter riwayat berdasarkan status (mis. lihat semua "Telat" saja) sehingga saya bisa fokus ke status tertentu.

#### Acceptance Criteria

1. THE History_Screen SHALL menampilkan History_Filter_Chips dengan 6 chip dalam horizontal scroll: Semua, Hadir, Telat, Izin, Sakit, Alpa.
2. THE History_Filter_Chips SHALL menampilkan count per chip dalam format `<Label> (<count>)` dimana count dihitung dari `summary` per status.
3. WHEN mahasiswa menekan satu chip, THE History_Screen SHALL meng-update local filter provider dan re-render list dengan filter sesuai.
4. WHILE filter "Semua" aktif, THE History_Screen SHALL menampilkan semua records tanpa filter.
5. WHILE filter "Telat" aktif, THE History_Screen SHALL menampilkan records yang `record.status == "terlambat"` (mapping label TELAT → enum DB `terlambat`).
6. WHILE filter aktif yang menghasilkan list kosong, THE History_Screen SHALL menampilkan empty state ramah dengan icon dan pesan terkait status terpilih.

### Requirement 11: History Smart-Date Grouping

**User Story:** Sebagai mahasiswa yang punya banyak riwayat kehadiran, saya ingin list dikelompokkan berdasarkan rentang waktu relatif (hari ini, kemarin, minggu ini) sehingga lebih mudah menemukan record tertentu.

#### Acceptance Criteria

1. WHEN list records di History_Screen ditampilkan setelah filter, THE History_Screen SHALL mengelompokkan records ke dalam Smart_Date_Group dengan label berurutan: "Hari Ini · {hari}, {tgl} {bulan}", "Kemarin · {hari}, {tgl} {bulan}", "Minggu Ini", "Bulan Ini", "Lebih Lama".
2. THE Smart_Date_Group SHALL menentukan bucket berdasarkan selisih `record.scannedAt.toLocal()` dengan `DateTime.now()`: same-day → Hari Ini; selisih 1 hari → Kemarin; 2-7 hari → Minggu Ini; 8-30 hari → Bulan Ini; >30 hari → Lebih Lama.
3. THE History_Screen SHALL menampilkan group header dengan label di kiri dan count "X SESI" (uppercase) di kanan.
4. WHERE bucket tertentu kosong, THE History_Screen SHALL TIDAK merender header bucket tersebut (skip empty group).
5. WHILE input list sudah ter-sort DESC oleh server, THE Smart_Date_Group SHALL mempertahankan urutan asli di dalam tiap bucket (order-stable).

### Requirement 12: History Item Card

**User Story:** Sebagai mahasiswa, saya ingin setiap row riwayat menampilkan informasi padat (mata kuliah, jam, jarak GPS, status) dalam satu glance.

#### Acceptance Criteria

1. THE History_Screen SHALL merender tiap record dengan card menggunakan `AppCard` (radius 14, `AppShadows.card`).
2. THE History item card SHALL menampilkan icon duotone (`KpiIconBox`) sesuai status: Hadir → success, Telat → info, Izin → warning, Sakit → warning, Alpa → danger.
3. THE History item card SHALL menampilkan nama mata kuliah dengan font Plus Jakarta Sans weight 700 size 13.5, ellipsis 1-line.
4. THE History item card SHALL menampilkan meta row dengan icon clock + jam scan dan icon map-point + jarak meter (jika `distanceMeters != null`).
5. THE History item card SHALL menampilkan status pill dengan label uppercase dan warna duotone tint sesuai status.
6. WHEN mahasiswa menekan History item card, THE History_Screen SHALL menampilkan History_Detail_Sheet untuk record tersebut.

### Requirement 13: History Detail Bottom Sheet

**User Story:** Sebagai mahasiswa yang ingin dispute status atau lihat detail kehadiran, saya ingin satu tampilan yang menampilkan semua informasi kehadiran lengkap (waktu, lokasi, similarity wajah, perangkat) untuk bisa di-screenshot dan dikirim ke dosen.

#### Acceptance Criteria

1. WHEN History item card ditekan, THE History_Screen SHALL menampilkan modal bottom sheet menggunakan `showModalBottomSheet` dengan radius top 24px, max height 88%, background `AppColors.surface`.
2. THE History_Detail_Sheet SHALL menampilkan handle drag bar 36×4px di atas, warna `AppColors.borderStrong`.
3. THE History_Detail_Sheet SHALL menampilkan status banner di atas dengan duotone background tint sesuai status, judul status besar, dan sub-text rangkuman 1 baris.
4. THE History_Detail_Sheet SHALL menampilkan baris detail untuk: Mata Kuliah, Waktu Presensi, Lokasi (jika `distanceMeters != null`), Verifikasi Wajah (jika `faceConfidence != null`), Perangkat (placeholder static atau hidden jika tidak ada data).
5. THE History_Detail_Sheet SHALL TIDAK menampilkan tombol aksi (ElevatedButton/OutlinedButton/TextButton mutating). Sheet bersifat read-only informational.
6. WHEN mahasiswa swipe-down handle atau tap dim overlay di luar sheet, THE Mobile_App SHALL menutup sheet dan kembali ke list view.

### Requirement 14: Submit Leave Wizard — Architecture

**User Story:** Sebagai mahasiswa yang mengajukan izin, saya ingin form dipecah menjadi 4 langkah jelas (Pilih Sesi → Tipe & Alasan → Lampiran → Review) sehingga saya tidak overwhelmed dengan satu form panjang.

#### Acceptance Criteria

1. THE Submit_Leave_Wizard SHALL menampilkan layar 4-step dengan urutan tetap: pickSession, typeAndReason, evidence, review.
2. THE Submit_Leave_Wizard SHALL menampilkan Step_Bar di header dengan 4 lingkaran dan 3 connector lines.
3. THE Step_Bar SHALL menggunakan visual: lingkaran active = filled `AppColors.primary` dengan ring `AppColors.primarySurface` 3px; lingkaran done = filled `AppColors.success` dengan icon check; lingkaran pending = `AppColors.surfaceSunken`.
4. THE Submit_Leave_Wizard SHALL menampilkan tombol footer Wizard_Footer_CTA full-width dengan label dinamis sesuai step: "Lanjut ke Tipe Izin" (step 1), "Lanjut Lampiran" (step 2), "Lanjut ke Review" (step 3), "Kirim Pengajuan" (step 4).
5. THE Submit_Leave_Wizard SHALL menggunakan AppBar default Flutter dengan back button system. WHERE step > 1 dan user tap back, THE Submit_Leave_Wizard SHALL kembali ke step sebelumnya, BUKAN langsung pop route.
6. WHILE step = 1 dan user tap back, THE Submit_Leave_Wizard SHALL memperbolehkan route pop (kembali ke MyLeaveRequests).

### Requirement 15: Wizard Step 1 — Pilih Sesi

**User Story:** Sebagai mahasiswa yang ingin mengajukan izin, saya ingin memilih sesi yang akan diizinkan dari list sesi saya (sedang berlangsung dan yang sudah lewat tapi belum saya hadiri max 7 hari) sehingga server otomatis tahu sesi mana tanpa saya input manual tanggal.

#### Acceptance Criteria

1. WHEN Submit_Leave_Wizard dibuka pada step pickSession, THE Submit_Leave_Wizard SHALL fetch list dari endpoint baru `GET /api/mobile/sessions/eligible-for-leave` melalui `eligibleSessionsForLeaveProvider` (atau provider equivalent), dan menerima dua array: `active_sessions` dan `recent_sessions`.
2. THE Submit_Leave_Wizard step pickSession SHALL menampilkan setiap sesi sebagai card dengan radio button kanan, tanggal/hari di kiri, info MK + jam + dosen di tengah, dan status badge dinamis: "AKTIF" untuk `active_sessions`, "KEMARIN" untuk recent dengan selisih 1 hari, "{N} HARI LALU" untuk selisih ≥ 2 hari.
3. THE Submit_Leave_Wizard step pickSession SHALL menampilkan dua section group dengan header dan icon:
   - Group A: "Sedang berlangsung" (icon `IconsaxPlusBold.radar` warna success) — render hanya jika `active_sessions.isNotEmpty`
   - Group B: "Belum sempat hadir" (icon `IconsaxPlusBold.previous` warna textSecondary) — render hanya jika `recent_sessions.isNotEmpty`
4. WHEN mahasiswa menekan satu session card (dari group A atau B), THE Submit_Leave_Wizard SHALL meng-update `selectedSession` dan menandai card terpilih dengan border `AppColors.primary` dan background `AppColors.primarySurface`.
5. WHILE belum ada sesi yang dipilih, THE Wizard_Footer_CTA SHALL disabled.
6. WHERE kedua list `active_sessions` dan `recent_sessions` kosong, THE Submit_Leave_Wizard step pickSession SHALL menampilkan info-banner "Sesi muncul di sini begitu dosen membukanya. Sesi yang sudah kamu hadiri atau lebih dari 7 hari tidak ditampilkan." dan Wizard_Footer_CTA tetap disabled.
7. THE Submit_Leave_Wizard step pickSession SHALL menampilkan loading skeleton selama provider dalam state loading, dan `ErrorState` dengan tombol retry jika provider error.

### Requirement 16: Wizard Step 2 — Tipe & Alasan

**User Story:** Sebagai mahasiswa, saya ingin memilih jenis izin (Sakit/Izin) dan menuliskan alasan dengan bantuan counter karakter sehingga saya tahu apakah alasan saya cukup detail.

#### Acceptance Criteria

1. WHEN Submit_Leave_Wizard berada di step typeAndReason, THE Submit_Leave_Wizard SHALL menampilkan read-only card menampilkan ringkasan sesi yang dipilih di Step 1.
2. THE Submit_Leave_Wizard step typeAndReason SHALL menampilkan 2 type tile dalam grid 1×2: "Sakit" dengan icon `IconsaxPlusBold.health` (mendekati `solar:pills-bold-duotone`) dan "Izin" dengan icon `IconsaxPlusBold.note_2`.
4. THE Type tile yang terpilih SHALL menggunakan border `AppColors.primary`, background `AppColors.primarySurface`, dan icon-wrap solid `AppColors.primary` dengan icon putih.
5. THE Type tile SHALL TIDAK menampilkan subtitle (label saja, tanpa deskripsi tambahan).
6. THE Submit_Leave_Wizard step typeAndReason SHALL menampilkan textarea alasan dengan placeholder "Jelaskan singkat kenapa kamu tidak bisa hadir..." dan max length 500.
7. THE Submit_Leave_Wizard step typeAndReason SHALL menampilkan counter karakter live di bawah textarea, format `<panjang>/500`, warna hijau saat panjang ≥ 10, abu-abu saat panjang < 10.
8. WHILE alasan kurang dari 10 karakter (setelah trim) atau panjang melebihi 500, THE Wizard_Footer_CTA SHALL disabled.

### Requirement 17: Wizard Step 3 — Lampiran

**User Story:** Sebagai mahasiswa, saya ingin opsional melampirkan foto bukti (mis. surat dokter) atau skip jika tidak ada, sehingga proses tidak terblok ketika bukti belum tersedia.

#### Acceptance Criteria

1. WHEN Submit_Leave_Wizard berada di step evidence, THE Submit_Leave_Wizard SHALL menampilkan upload-zone dengan icon, judul "Tambahkan Foto Bukti", dan sub-text "JPG / PNG / WEBP, maks 5 MB" jika belum ada file.
2. WHEN mahasiswa menekan upload-zone, THE Submit_Leave_Wizard SHALL membuka bottom sheet pilihan source: Galeri / Ambil Foto, mengikuti pattern `_showEvidencePickerSheet` existing.
3. WHEN mahasiswa selesai memilih file, THE Submit_Leave_Wizard SHALL menampilkan preview thumbnail + tombol X untuk hapus pilihan, mengikuti pattern existing `Image.file` preview.
4. WHEN mahasiswa menekan Wizard_Footer_CTA dan ada `pickedImage` belum di-upload, THE Submit_Leave_Wizard SHALL memanggil `Leave_Repository.uploadEvidence(pickedImage)` sebelum advance ke step review.
5. WHILE upload sedang berjalan (`isUploadingEvidence == true`), THE Wizard_Footer_CTA SHALL menampilkan loading state dan disabled.
6. IF upload gagal (network error / size exceeded / mime invalid), THEN THE Submit_Leave_Wizard SHALL tetap di step evidence dengan error text di bawah upload zone (Bahasa Indonesia ramah via `friendlyErrorMessage`), `pickedImage` dipertahankan.
7. WHILE upload sedang berjalan, IF mahasiswa tap system back, THEN THE Submit_Leave_Wizard SHALL memblokir aksi back hingga upload selesai (sukses atau gagal).
8. WHERE mahasiswa tidak melampirkan file, THE Wizard_Footer_CTA SHALL tetap aktif dan advance langsung ke step review tanpa upload.

### Requirement 18: Wizard Step 4 — Review

**User Story:** Sebagai mahasiswa yang sudah mengisi form, saya ingin melihat ringkasan pengajuan saya sebelum klik kirim sehingga saya bisa cek ulang sebelum komit.

#### Acceptance Criteria

1. WHEN Submit_Leave_Wizard berada di step review, THE Submit_Leave_Wizard SHALL menampilkan card review dengan baris read-only: Sesi (nama MK + tanggal/jam), Jenis (Sakit/Izin), Alasan (full text), Lampiran (nama file atau "Tidak ada lampiran").
2. THE Wizard_Footer_CTA pada step review SHALL berlabel "Kirim Pengajuan" dengan icon `IconsaxPlusBold.send_2` (atau equivalent).
3. WHEN mahasiswa menekan Wizard_Footer_CTA "Kirim Pengajuan", THE Submit_Leave_Wizard SHALL memanggil `Submit_Leave_Provider.submit(sessionId, type, reason, evidencePath)`.
4. WHILE submission sedang berjalan, THE Wizard_Footer_CTA SHALL menampilkan loading dan disabled.
5. IF submission berhasil, THEN THE Submit_Leave_Wizard SHALL menampilkan snackbar success + delay 800ms + `context.pop(true)` agar caller (`MyLeaveRequestsScreen`) dapat refresh list.
6. IF submission gagal, THEN THE Submit_Leave_Wizard SHALL menampilkan snackbar danger dengan `errorMessage` dan tetap di step review (user dapat retry atau back).

### Requirement 19: Wizard State Preservation

**User Story:** Sebagai mahasiswa yang menavigasi mundur di wizard untuk koreksi, saya ingin data yang sudah saya isi tidak hilang sehingga saya tidak perlu mengulang input.

#### Acceptance Criteria

1. WHEN mahasiswa menavigasi backward dari step N ke step N-1 menggunakan system back, THE Submit_Leave_Wizard SHALL mempertahankan semua field yang sudah diisi: `selectedSession`, `selectedType`, `reason`, `pickedImage`, `evidencePath`.
2. WHEN mahasiswa menavigasi forward kembali dari step N-1 ke step N, THE Submit_Leave_Wizard SHALL menampilkan field dengan nilai yang dipertahankan.
3. WHILE step navigation tidak melibatkan upload baru, THE Submit_Leave_Wizard SHALL TIDAK memanggil `Leave_Repository.uploadEvidence` ulang jika `evidencePath` sudah ter-set (idempotent advance).

### Requirement 20: Reuse Existing Providers

**User Story:** Sebagai engineer yang me-rebuild UI, saya ingin tidak menambah provider baru sehingga business logic tetap konsisten dan tidak memperkenalkan dependency cycle baru.

#### Acceptance Criteria

1. THE Home_Screen rebuild SHALL menggunakan `Active_Sessions_Provider` dan `authProvider` yang sudah ada, tanpa menambah top-level provider baru.
2. THE History_Screen rebuild SHALL menggunakan `History_Provider` yang sudah ada, plus boleh tambah satu screen-scoped local NotifierProvider untuk filter state (`_historyFilterProvider`).
3. THE Submit_Leave_Wizard SHALL menggunakan `Active_Sessions_Provider`, `Submit_Leave_Provider`, dan `Leave_Repository` yang sudah ada, tanpa menambah top-level provider baru. Wizard step state boleh disimpan di `setState`/local Notifier dalam screen widget tersebut.
4. THE rebuild SHALL TIDAK mengubah method signature atau body file di `lib/features/<feat>/data/` dan `lib/features/<feat>/providers/` (kecuali jika provider tersebut memang harus diubah, dan itu out-of-scope spec ini).

### Requirement 21: Design Token Usage

**User Story:** Sebagai engineer yang menjaga konsistensi visual, saya ingin semua warna dan shadow di screen rebuild diambil dari token resmi sehingga tidak ada drift visual atau hardcode hex.

#### Acceptance Criteria

1. THE Home_Screen, History_Screen, dan Submit_Leave_Wizard SHALL menggunakan `AppColors.*` untuk semua warna, kecuali alpha overlay yang diturunkan dari token via `.withValues(alpha: x)`.
2. THE rebuild SHALL TIDAK mengandung literal `Color(0xFF...)` selain di kasus pre-existing yang juga merupakan turunan token (whitelisted di code review).
3. THE card-surface widgets di rebuild SHALL menggunakan `AppShadows.card` (atau `cardElevated`/`hero`/`fab` sesuai konteks), BUKAN `Border.all` 1px sebagai pengganti shadow primary separation.
4. THE Hero_Card_Active dan History_Hero_Summary SHALL menggunakan `AppShadows.hero` sebagai primary shadow.
5. THE Submit_Leave_Wizard FAB-equivalent (jika ada di sub-pattern) SHALL menggunakan `AppShadows.fab`.

### Requirement 22: Iconography

**User Story:** Sebagai pemilik produk yang mengontrol library lock, saya ingin semua icon di screen rebuild menggunakan Iconsax_Bold (variant dari `iconsax_plus`) sehingga konsisten dengan helper widget yang sudah dipakai.

#### Acceptance Criteria

1. THE Home_Screen, History_Screen, dan Submit_Leave_Wizard SHALL menggunakan `IconsaxPlusBold.*` untuk semua icon dalam scope rebuild.
2. THE rebuild SHALL TIDAK menggunakan `Icons.*` Material outlined, emoji, atau library icon lain (Lucide/Cupertino).
3. THE icon dengan semantic warna SHALL menggunakan `SemanticIcon` helper widget atau inline `KpiIconBox` dengan variant warna sesuai mapping di rule 22.

### Requirement 23: Bahasa Indonesia Copy

**User Story:** Sebagai user mahasiswa yang berbahasa Indonesia, saya ingin semua label, placeholder, dan pesan di screen mahasiswa berbahasa Indonesia natural sesuai mockup yang sudah dipoles.

#### Acceptance Criteria

1. THE Home_Screen SHALL menampilkan semua label visible (greeting, badge, button, section header) dalam Bahasa Indonesia sesuai copy mockup `mobile-home.html`.
2. THE History_Screen SHALL menampilkan semua label visible (judul, chip, group header, banner status, detail label) dalam Bahasa Indonesia sesuai copy mockup `mobile-riwayat.html`.
3. THE Submit_Leave_Wizard SHALL menampilkan semua label visible (step bar, button label, placeholder, helper text, error text) dalam Bahasa Indonesia sesuai copy mockup `mobile-leave-request.html`.
4. WHERE error message ditampilkan ke user, THE Mobile_App SHALL melalui `friendlyErrorMessage(e)` (existing utility) yang mengembalikan pesan Bahasa Indonesia ramah, BUKAN stack trace atau pesan teknis bahasa Inggris.

### Requirement 24: 3-State UI Compliance

**User Story:** Sebagai mahasiswa, saya ingin setiap halaman yang fetch data menampilkan loading, empty, dan error state yang jelas sehingga saya tidak terjebak di halaman kosong tanpa konteks.

#### Acceptance Criteria

1. THE Home_Screen SHALL menampilkan skeleton loading saat `Active_Sessions_Provider` dalam state loading.
2. THE Home_Screen SHALL menampilkan Hero_Card_Empty saat data tersedia tapi `activeSessions.where(!alreadySubmitted)` kosong.
3. THE Home_Screen SHALL menampilkan `ErrorState` widget dengan tombol retry saat `Active_Sessions_Provider` dalam state error.
4. THE History_Screen SHALL menampilkan `ListLoadingPlaceholder` saat `History_Provider` dalam state loading.
5. THE History_Screen SHALL menampilkan empty state dengan icon dan pesan ramah saat list filtered kosong.
6. THE History_Screen SHALL menampilkan `ErrorState` widget dengan tombol retry saat `History_Provider` dalam state error.
7. THE Submit_Leave_Wizard step pickSession SHALL menampilkan info-banner empty saat list eligible session kosong.

### Requirement 25: Preserve Business Logic

**User Story:** Sebagai pemilik produk, saya ingin rebuild UI tidak meregresi flow business yang sudah berjalan (face required pre-flight di Scan, evidence upload integrasi, audit logging, mock GPS rejection, navigation guards).

#### Acceptance Criteria

1. THE rebuild SHALL TIDAK mengubah flow `attendanceSubmitProvider.submitFromQr()` yang dipanggil dari `ScanQrScreen`.
2. THE rebuild SHALL TIDAK mengubah body endpoint atau handler validation di `mypresensi-web/app/api/mobile/*`.
3. THE Submit_Leave_Wizard SHALL menggunakan `Leave_Repository.uploadEvidence` dengan parameter sama seperti existing screen, sehingga server-side rate-limit, magic-byte validation, dan path generation tetap berfungsi.
4. WHEN submission Submit_Leave_Wizard berhasil, THE Mobile_App SHALL `ref.invalidate(myLeaveRequestsProvider)` (sudah dilakukan oleh `submitLeaveProvider`) sehingga MyLeaveRequestsScreen refresh tanpa intervensi tambahan.
5. WHEN attendance submit dari `ScanQrScreen` berhasil, THE Mobile_App SHALL tetap dispatch event refresh ke `Active_Sessions_Provider` (existing `ref.invalidate`) sehingga Home_Screen menyegarkan summary.

### Requirement 26: Verification Gate

**User Story:** Sebagai engineer yang menjaga kualitas, saya ingin setiap screen rebuild diverifikasi secara teknis sebelum task ditandai selesai sehingga tidak ada warning/error tertumpuk yang baru terdeteksi pasca-merge.

#### Acceptance Criteria

1. WHEN engineer menyelesaikan rebuild satu screen, THE Mobile_App SHALL lulus `flutter analyze` (exit code 0, output "No issues found.") sebelum task untuk screen tersebut ditandai selesai.
2. WHEN engineer menyelesaikan keseluruhan spec, THE Mobile_App SHALL lulus `flutter analyze` keseluruhan project sebelum spec ditutup.
3. WHERE `flutter analyze` melaporkan warning/error, THE rebuild task SHALL TIDAK dianggap selesai hingga semua issue diperbaiki.

### Requirement 27: Web Token Sync (Optional)

**User Story:** Sebagai pemilik produk yang mengejar konsistensi cross-platform, saya ingin token primary di web `globals.css` di-sync ke `#2D86FF` agar tampilan mobile dan web punya brand color yang sama.

#### Acceptance Criteria

1. WHERE engineer mengeksekusi task opsional sinkronisasi web token, THE `mypresensi-web/app/globals.css` SHALL meng-update `--color-primary` value dari `#5483AD` ke `#2D86FF`, beserta token turunan (primary-hover, primary-dark) sesuai pattern di mockup `_tokens.css`.
2. WHEN web token sync dilakukan, THE Mobile_App side SHALL TIDAK terkena dampak (tidak ada coupling — mobile sudah menggunakan `AppColors.primary = #2D86FF`).
3. WHEN web token sync di-skip, THE Mobile_App rebuild scope SHALL TETAP dianggap selesai (web sync bersifat opsional).

### Requirement 28: Manual Smoke Test

**User Story:** Sebagai pemilik produk, saya ingin verifikasi visual dan integrasi yang tidak terdeteksi oleh static analyzer divalidasi secara manual oleh user di emulator atau perangkat fisik sebelum spec ditandai complete.

#### Acceptance Criteria

1. WHEN keseluruhan rebuild Phase 5 selesai dan semua `flutter analyze` lulus, THE pemilik produk SHALL melakukan smoke test manual yang mencakup: (a) login mahasiswa demo, (b) buka tab Beranda dengan dan tanpa sesi aktif, (c) buka tab Riwayat, tap satu item untuk lihat bottom sheet, (d) buka tab Izin, jalankan wizard 4-step happy path tanpa lampiran, (e) jalankan wizard 4-step dengan lampiran foto.
2. THE manual smoke test SHALL menggunakan akun yang ada di `mypresensi-web/.dev-accounts.md` (BUKAN tebak credential).
3. THE manual smoke test SHALL didokumentasikan di `dev-log.md` atau `CHANGELOG.md` (entri `[MOD]` atau `[STYLE]` per screen) setelah selesai.

### Requirement 29: Endpoint Backend — Eligible Sessions for Leave

**User Story:** Sebagai pengembang sistem, saya ingin endpoint baru yang return list sesi eligible untuk diajukan izin (sedang aktif + sudah lewat ≤ 7 hari, exclude yang sudah hadir/sudah ada izin), sehingga UI wizard step 1 punya sumber data yang sesuai mockup tanpa duplikasi business logic di client.

#### Acceptance Criteria

1. THE Mobile_App backend SHALL menyediakan endpoint baru `GET /api/mobile/sessions/eligible-for-leave` di `mypresensi-web/app/api/mobile/sessions/eligible-for-leave/route.ts`.
2. THE endpoint SHALL menggunakan helper `authenticateRequest()` dari `_lib/auth.ts` untuk verifikasi Bearer JWT, role mahasiswa, dan `is_active=true`.
3. WHEN request masuk dan auth berhasil, THE endpoint SHALL mengembalikan response dengan shape `{ active_sessions: EligibleSession[], recent_sessions: EligibleSession[] }` dimana `EligibleSession = { id, course_code, course_name, session_number, topic, started_at, ended_at, dosen_name }`.
4. THE endpoint SHALL include sesi di array `active_sessions` jika `sessions.is_active = true` AND mahasiswa enrolled di course-nya AND tidak ada `attendances` dengan `status='hadir'` AND tidak ada `leave_requests` dengan `status IN ('pending','approved')` untuk sesi tersebut.
5. THE endpoint SHALL include sesi di array `recent_sessions` jika `sessions.is_active = false` AND `sessions.started_at >= NOW() - INTERVAL '7 days'` AND mahasiswa enrolled di course-nya AND tidak ada `attendances` hadir AND tidak ada leave_request pending/approved.
6. THE endpoint SHALL menggunakan `createAdminClient()` (service_role) untuk query DB, dijalankan SETELAH auth check berhasil — sesuai pattern existing `/api/mobile/sessions/active/route.ts`.
7. THE endpoint SHALL menggunakan `Promise.all` untuk parallel fetch exclusion sets (attendances + leave_requests) sehingga single round-trip ke Supabase.
8. THE endpoint SHALL menerapkan rate limit 30 request per 5 menit per kombinasi `(user_id, device_id)` menggunakan helper `checkRateLimit` existing.
9. THE endpoint SHALL TIDAK mengembalikan field sensitif (`session_code`, `face_embedding`, JWT) dalam response.
10. THE endpoint SHALL TIDAK memanggil `logAudit()` (read-only endpoint, tidak ada mutasi state).
11. THE endpoint SHALL mengembalikan response error standar (`errorResponse`) dengan status code yang tepat: 401 untuk unauthorized, 429 untuk rate limit, 500 untuk DB error.
12. THE response SHALL ter-sort `started_at` DESC di kedua array sehingga sesi terbaru muncul di atas.

### Requirement 30: Migration — Index `sessions.started_at`

**User Story:** Sebagai pengembang yang menjaga performa query, saya ingin index pada kolom `started_at` di tabel `sessions` sehingga filter `started_at >= NOW() - 7 days` tidak melakukan sequential scan saat tabel sessions berkembang.

#### Acceptance Criteria

1. THE Mobile_App backend SHALL memiliki migration baru `020_sessions_started_at_index.sql` di `mypresensi-web/supabase/migrations/`.
2. THE migration SHALL membuat index `CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at DESC)`.
3. THE migration SHALL diapply via `mcp0_apply_migration` agar ter-track di history Supabase, BUKAN manual via SQL Editor.
4. WHEN migration diapply, THE pengembang SHALL menjalankan `mcp0_get_advisors({ type: 'security' })` dan memastikan tidak ada issue baru.
5. WHEN migration diapply, THE pengembang SHALL menjalankan `mcp0_get_advisors({ type: 'performance' })` dan memastikan tidak ada warning unused index baru terkait migration ini.
