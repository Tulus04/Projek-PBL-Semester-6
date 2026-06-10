# Design Document — Home Calendar Redesign

## Overview

Redesign Beranda mobile agar menampilkan **riwayat kehadiran dalam format kalender** (week strip + agenda per hari) plus **kartu statistik ring**, menggantikan section "Aktivitas Terakhir" (list linear) dan "Ringkasan Hari Ini" (3-stat). Hero session card dan Quick Action Grid dipertahankan.

Prinsip utama desain ini: **reuse, jangan bangun ulang**. Data, logika status, dan komponen visual sudah ada di codebase — fitur ini menyusun ulang dan memanfaatkannya.

Acuan visual: `docs/ui-research/mockups/home-riwayat-kalender.html`.

### Keputusan kunci (resolusi pertanyaan terbuka requirements)

| # | Pertanyaan | Keputusan | Alasan |
|---|-----------|-----------|--------|
| 1 | Sumber data minggu | **Reuse `historyProvider`** (`HistoryResponse`). Filter per minggu di client. | `HistoryResponse` sudah berisi seluruh `history` + `summary`. Tidak perlu endpoint baru → hemat, tidak nambah loading, tidak nambah permukaan keamanan. |
| 2 | Nasib Quick Action Grid & Activity Feed | **Activity Feed dihapus** (digantikan kalender — overlap info). **Quick Action Grid dipertahankan** (shortcut Izin/Scan tidak tercakup kalender). | Kalender = riwayat (sama dengan activity feed). Quick action memberi aksi yang tidak ada di kalender. |
| 3 | Widget kalender | **Week-strip kustom ringan** (7 pill), bukan `table_calendar` mode minggu. | Mockup pakai 7-pill kustom; lebih ringan & presisi visual. `table_calendar` tetap dipakai di tab Riwayat (bulan penuh). |
| 4 | Hari terpilih saat pindah minggu | Default: **hari ini** bila minggu berjalan; selain itu **hari berdata terakhir** di minggu itu; bila kosong → **Senin** minggu itu. | Glanceable & selalu ada konteks, hindari agenda kosong tak beralasan. |

---

## Architecture

### Aliran data

```
historyProvider (FutureProvider.autoDispose<HistoryResponse>)
        │  (sudah ada — GET /api/mobile/attendance/history)
        ▼
HomeScreen.build()  ── ref.watch(historyProvider)
        │
        ├─ Week strip + Agenda  ←  HistoryResponse.history  (List<AttendanceRecord>)
        │         │
        │         └─ helper: groupByLocalDate / dominantStatus / status color mapping
        │                    (diekstrak ke shared agar dipakai Beranda + tab Riwayat)
        │
        └─ Kartu Statistik ring ←  HistoryResponse.summary  (AttendanceSummary)
```

**Tidak ada endpoint/migration baru.** Beranda kini meng-`watch` dua provider:
- `activeSessionsProvider` (existing) → hero + today context.
- `historyProvider` (existing) → kalender riwayat + statistik.

### Ekstraksi helper status (reuse logika tab Riwayat)

Logika status dominan + mapping warna/ikon/label saat ini berada sebagai fungsi privat di `history_calendar_view.dart`. Agar dipakai bersama Beranda tanpa duplikasi (DRY), ekstrak ke file shared:

- **File baru**: `lib/features/history/data/attendance_status_style.dart`
  - `int statusPriority(String)`
  - `String dominantStatus(List<AttendanceRecord>)`
  - `Color statusFg(String)` / `Color statusTint(String)`
  - `IconData statusIcon(String)` / `String statusLabel(String)`
  - `DateTime dateKey(DateTime localDt)` + `Map<DateTime, List<AttendanceRecord>> groupByLocalDate(List<AttendanceRecord>)`

`history_calendar_view.dart` di-refactor untuk meng-import helper ini (hapus duplikat privatnya). Perilaku tab Riwayat TIDAK berubah — hanya pindah lokasi fungsi.

> Catatan: ini refactor non-fungsional; verifikasi `flutter analyze` + visual tab Riwayat tetap sama.

---

## Components and Interfaces

### Struktur section Beranda (sesudah)

Urutan section di `ListView` Beranda (sesuai mockup, dengan Quick Action dipertahankan):

| Index animasi | Section | Status |
|:---:|---------|--------|
| 0 | `_GreetingHeader` | existing, tetap |
| 1 | Hero session (`_HeroSessionActive` / `_HeroSessionEmpty` / `_HeroSkeleton` / `_HeroErrorBox`) | existing, tetap |
| 2 | **`HomeHistoryCalendarCard`** (week strip + agenda) | **BARU** |
| 3 | **`HomeStatsRingCard`** (ring persen + legend) | **BARU** (gantikan `_TodaySummaryRow`) |
| 4 | `_QuickActionGrid` | existing, tetap |

- `_sectionCount` **tetap 5** (Activity Feed[4] & Today Summary[2] lama digantikan; net jumlah sama). Tetap WAJIB diverifikasi manual agar tidak off-by-one (cegah ulang BUG-12): jumlah child `_animated(i, ...)` == `_sectionCount`.
- `_buildActivityFeedSection` dan `_TodaySummaryRow` lama dihapus dari Beranda (widget Activity Feed + provider `recentActivitiesProvider` boleh ditinggalkan/di-deprecate; tidak dihapus paksa bila dipakai tempat lain — cek referensi dulu).

### `HomeHistoryCalendarCard` (widget BARU)

`ConsumerStatefulWidget` — memegang state `_focusedWeekStart` (Senin minggu aktif) dan `_selectedDay`.

```dart
// lib/features/home/widgets/home_history_calendar_card.dart
class HomeHistoryCalendarCard extends ConsumerStatefulWidget {
  const HomeHistoryCalendarCard({super.key, required this.onOpenFullCalendar});
  final VoidCallback onOpenFullCalendar; // → setTab(2)
}
```

Tanggung jawab:
1. `ref.watch(historyProvider)` → `.when(data/loading/error)`.
2. `data`: bangun map `groupByLocalDate(records)`, render header periode + nav minggu, week strip 7 pill, legend, agenda hari terpilih.
3. `loading`: skeleton kartu (reuse pola shimmer/opacity hero skeleton).
4. `error`: `ErrorState` ramah + tombol coba lagi → `ref.invalidate(historyProvider)`.
5. `data` tapi `records` kosong total: empty state ramah ("Belum ada riwayat absen. Yuk mulai absen!") — tetap render week strip kosong agar layout stabil.

Sub-widget internal:
- `_WeekStrip` — `Row` 7 `_DayPill`. Hitung 7 hari dari `_focusedWeekStart`.
- `_DayPill` — tanggal + nama hari + tint/dot status dominan; varian: berdata / kosong / hari ini (outline) / masa depan (redup) / terpilih (outline primary). Reuse `statusFg`/`statusTint`/`dominantStatus`.
- `_WeekNavRow` — label periode ("Mei 2026 · Minggu ini" atau rentang tanggal) + caret kiri/kanan.
- `_HomeAgendaList` — daftar record hari terpilih memakai pola item yang sama dengan `_DayDetailItem` (MK + jam + pertemuan + status pill). Empty state bila hari terpilih tanpa record.

Aturan navigasi minggu (R3):
- `_focusedWeekStart` mulai dari Senin minggu berjalan.
- Caret kiri/kanan geser ±7 hari. Batas: tidak lebih awal dari awal semester (`DateTime(2026,1,1)` selaras `history_calendar_view`), tidak lebih dari minggu berjalan (tidak ada navigasi ke masa depan penuh).
- Saat pindah minggu → `_selectedDay` di-set ulang sesuai aturan Keputusan #4.

### `HomeStatsRingCard` (widget BARU)

```dart
// lib/features/home/widgets/home_stats_ring_card.dart
class HomeStatsRingCard extends StatelessWidget {
  const HomeStatsRingCard({super.key, required this.summary, required this.onDetail});
  final AttendanceSummary summary;
  final VoidCallback onDetail; // → setTab(2)
}
```

- Ring/donut persen `summary.percentage` + legend (Hadir `summary.hadir`, Izin/Sakit `summary.izin+sakit`, Alpa `summary.alpa`). Terlambat ditampilkan bila > 0.
- Ring digambar pakai `CustomPaint` (sweep arc) atau `conic`-equivalent — tanpa package chart baru.
- Di-feed dari `HistoryResponse.summary` (provider yang sama dengan kalender, jadi 1 fetch).

### Wiring di `HomeScreen`

```dart
final historyAsync = ref.watch(historyProvider);
// ...
_animated(2, HomeHistoryCalendarCard(
  onOpenFullCalendar: () => ref.read(currentTabProvider.notifier).setTab(2),
)),
_animated(3, historyAsync.maybeWhen(
  data: (h) => HomeStatsRingCard(
    summary: h.summary,
    onDetail: () => ref.read(currentTabProvider.notifier).setTab(2),
  ),
  orElse: () => const _StatsRingSkeleton(),
)),
_animated(4, _buildQuickActionsSection(context, ref)),
```

Pull-to-refresh (`RefreshIndicator.onRefresh`) ditambah `ref.invalidate(historyProvider)` di samping `activeSessionsProvider` (R6.2).

---

## Data Models

Tidak ada model baru. Reuse:
- `AttendanceRecord` (`scannedAt`, `status`, `courseName`, `sessionNumber`, `courseCode`, `topic`).
- `AttendanceSummary` (`percentage`, `hadir`, `terlambat`, `izin`, `sakit`, `alpa`, `totalSessions`).
- `HistoryResponse` (`history`, `summary`).

Status enum yang ditangani: `hadir` / `terlambat` / `izin` / `sakit` / `alpa` (sesuai mapping existing). Tidak menambah status baru.

---

## Error Handling

| Kondisi | Penanganan | Requirement |
|---------|-----------|-------------|
| `historyProvider` loading | Skeleton kartu kalender + skeleton ring | R5.1 |
| `historyProvider` error | `ErrorState` Bahasa Indonesia + tombol coba lagi → `ref.invalidate(historyProvider)` | R5.2 |
| `records` kosong (akun baru) | Empty state ramah ("Belum ada riwayat absen. Yuk mulai absen!") | R5.3 |
| Hari terpilih tanpa record | Empty agenda ramah ("Tidak ada kelas tercatat di hari ini") — bukan error | R2.4 |
| Hari masa depan dipilih | Agenda kosong, pill non-aktif | R1.4, R2.5 |
| Pesan error mentah dari Dio | Sudah disanitasi oleh repository/`friendlyErrorMessage` | rule 02/04 |

Semua teks user-facing Bahasa Indonesia, sapaan "kamu", ringkas (rule 09).

---

## Testing Strategy

Mengikuti tier testing rule `05` + verifikasi runtime rule `06` (UI change → butuh konfirmasi visual).

### Unit test (logic murni — `flutter_test`)
- `attendance_status_style_test.dart`:
  - `dominantStatus`: alpa menang atas hadir; izin menang atas hadir; kosong → ''.
  - `groupByLocalDate`: record dengan `scannedAt` lintas tengah malam UTC dikelompokkan ke tanggal lokal yang benar.
  - `statusPriority` urutan benar.
- Helper minggu (week start Senin, navigasi ±7 hari, klamping batas) bila diekstrak sebagai fungsi pure.

### Manual / visual (WAJIB sebelum klaim selesai — rule 06 Law 4)
- `flutter analyze` 0 issues.
- Screenshot Beranda pasca hot restart: week strip render, hari ini ter-outline, tint status benar.
- Tap hari berdata → agenda berubah; tap hari kosong → empty agenda; tap hari depan → kosong.
- Navigasi minggu sebelumnya → data minggu lalu muncul; klamping di batas semester.
- Tap "Kalender penuh" → pindah ke tab Riwayat; back → kembali Beranda (tidak dead-end).
- Submit presensi → kembali Beranda → record baru muncul tanpa hot restart (R6.1, cegah BUG-017).
- 3-state: matikan jaringan → error + retry; akun tanpa data → empty state.

---

## Correctness Properties

Properti yang harus selalu benar (kandidat property-based test untuk logika murni — UI di-verifikasi manual sesuai rule 06):

### Property 1: Status dominan = prioritas terburuk
Untuk sembarang daftar record non-kosong dalam satu hari, `dominantStatus` SHALL mengembalikan status dengan `statusPriority` tertinggi. Hasil selalu ada di antara status input, dan tidak ada status input yang berprioritas lebih tinggi dari hasil.

**Validates: Requirements 1.2**

### Property 2: Grouping menjaga jumlah dan tanggal lokal
`groupByLocalDate` SHALL menjaga total jumlah record (jumlah seluruh nilai map == jumlah input yang `scannedAt`-nya valid), dan setiap record masuk ke key tanggal lokal yang sesuai (`year/month/day` lokal `scannedAt`).

**Validates: Requirements 6.3, 2.2**

### Property 3: Week start idempoten dan selalu Senin
Untuk sembarang tanggal, fungsi penentu awal minggu SHALL mengembalikan hari Senin (`weekday == 1`), dan memanggilnya ulang pada hasilnya mengembalikan tanggal yang sama (idempoten).

**Validates: Requirements 1.1**

### Property 4: Navigasi minggu konsisten dan ter-klamping
Geser maju lalu mundur satu minggu (dalam rentang valid) SHALL mengembalikan `_focusedWeekStart` semula; hasil navigasi SHALL tidak pernah melewati batas (awal semester ≤ minggu ≤ minggu berjalan).

**Validates: Requirements 3.1, 3.4**

### Property 5: Hari masa depan tak pernah berstatus
Untuk hari setelah hari ini, week strip SHALL tidak menampilkan tint/dot status apa pun, terlepas dari isi data.

**Validates: Requirements 1.4, 2.5**

### Property 6: Hari terpilih selalu valid dalam minggu aktif
Setelah berpindah minggu, `_selectedDay` SHALL selalu berada dalam 7 hari `_focusedWeekStart`.

**Validates: Requirements 3.5**

## Design Decisions & Rationale

1. **Reuse `historyProvider` ketimbang endpoint baru** — `HistoryResponse` sudah memuat semua yang dibutuhkan (records + summary). Menambah endpoint = kerja sia-sia + permukaan keamanan baru. Trade-off: fetch seluruh riwayat semester (bukan hanya minggu ini), tapi data ini sudah biasa di-fetch tab Riwayat dan ukurannya kecil.
2. **Ekstrak helper status ke shared file** — hindari duplikasi antara Beranda dan tab Riwayat (DRY, rule 02). Refactor non-fungsional, perilaku tab Riwayat dijaga.
3. **Week strip kustom, bukan `table_calendar`** — sesuai mockup, lebih ringan untuk 7 pill, kontrol penuh atas tint/dot. `table_calendar` tetap untuk bulan penuh di tab Riwayat.
4. **Activity Feed dihapus, Quick Action dipertahankan** — kalender riwayat menggantikan informasi Activity Feed (sama-sama riwayat). Quick Action memberi aksi (Izin/Scan) yang tidak tercakup kalender, jadi tidak redundan dengan bottom nav untuk Izin.
5. **`_sectionCount` tetap 5 + verifikasi manual** — net jumlah section sama; tetap audit eksplisit jumlah `_animated()` (Law 3 rule 06) untuk cegah RangeError BUG-12.
6. **Ring statistik via `CustomPaint`** — tanpa package chart baru (library lock rule 03).

## Catatan implementasi (untuk tasks)
- Cek referensi `recentActivitiesProvider` & `_TodaySummaryRow` sebelum menghapus — pastikan tidak dipakai di tempat lain.
- Pastikan `currentTabProvider.setTab(2)` adalah index tab Riwayat yang benar (sesuai `app_shell.dart`).
- Invalidate `historyProvider` di handler pasca-submit presensi (`attendance_result_screen.dart`) bila belum, selaras pencegahan BUG-017.
