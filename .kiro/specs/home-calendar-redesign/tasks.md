# Implementation Plan — Home Calendar Redesign

## Overview

Rencana implementasi redesign Beranda mobile menjadi format kalender riwayat (week strip + agenda) + kartu statistik ring, menggantikan Activity Feed & Today Summary, mempertahankan hero + Quick Action. Berbasis reuse `historyProvider` dan helper status yang sudah ada. Tugas disusun incremental: helper & test dulu (fondasi pure), lalu widget, lalu integrasi, lalu verifikasi.

## Tasks

- [x] 1. Ekstrak helper status presensi ke file shared (DRY)
  - Buat `lib/features/history/data/attendance_status_style.dart` berisi fungsi publik: `statusPriority`, `dominantStatus`, `statusFg`, `statusTint`, `statusIcon`, `statusLabel`, `dateKey`, `groupByLocalDate`.
  - Pindahkan logika dari fungsi privat yang sekarang ada di `history_calendar_view.dart` (jangan ubah perilakunya).
  - Refactor `history_calendar_view.dart` untuk meng-import helper baru dan menghapus duplikat privatnya.
  - Verifikasi `flutter analyze` 0 issues dan perilaku tab Riwayat tidak berubah.
  - _Requirements: 1.2, 6.3_

- [ ] 2. Buat fungsi pure helper minggu + unit test
- [ ] 2.1 Implementasi helper minggu
  - Tambah fungsi pure (mis. di `lib/features/home/data/week_utils.dart`): `weekStart(DateTime)` → Senin minggu itu; `addWeeks(DateTime weekStart, int delta)`; `clampWeekStart(DateTime, {min, max})`; `daysOfWeek(DateTime weekStart)` → 7 tanggal.
  - _Requirements: 3.1, 3.4, 3.5_
- [~] 2.2 Unit test helper status + minggu (property-based)
  - Tulis `test/features/home/attendance_status_style_test.dart` dan `test/features/home/week_utils_test.dart`.
  - Cover Property 1 (dominantStatus prioritas terburuk), Property 2 (groupByLocalDate jaga jumlah + tanggal lokal), Property 3 (weekStart idempoten & Senin), Property 4 (navigasi maju-mundur konsisten & klamping), Property 6 (hari terpilih dalam minggu aktif).
  - Jalankan `flutter test` — semua hijau.
  - _Requirements: 1.1, 1.2, 1.4, 3.1, 3.4, 3.5, 6.3_

- [ ] 3. Bangun widget `HomeHistoryCalendarCard`
- [~] 3.1 Kerangka card + 3-state dari `historyProvider`
  - Buat `lib/features/home/widgets/home_history_calendar_card.dart` (`ConsumerStatefulWidget`) dengan state `_focusedWeekStart` + `_selectedDay`.
  - `ref.watch(historyProvider).when(...)`: loading → skeleton card; error → `ErrorState` + retry `ref.invalidate(historyProvider)`; data kosong total → empty state ramah ("Belum ada riwayat absen. Yuk mulai absen!").
  - _Requirements: 5.1, 5.2, 5.3_
- [~] 3.2 Week strip + day pill
  - `_WeekStrip` (Row 7 `_DayPill`) memakai `daysOfWeek(_focusedWeekStart)` + `groupByLocalDate(records)`.
  - `_DayPill` varian: berdata (tint + dot status dominan), kosong (netral), hari ini (outline), masa depan (redup, tanpa status), terpilih (outline primary). Reuse `statusFg`/`statusTint`/`dominantStatus`.
  - Tambah legend status (Hadir/Izin-Sakit/Alpa; Terlambat bila dipakai).
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 2.5_
- [~] 3.3 Navigasi minggu
  - `_WeekNavRow`: label periode ("… · Minggu ini" atau rentang tanggal) + caret kiri/kanan; geser `_focusedWeekStart` ±7 hari dengan klamping (awal semester `DateTime(2026,1,1)` … minggu berjalan).
  - Saat pindah minggu set ulang `_selectedDay` (hari ini bila minggu berjalan → hari berdata terakhir → Senin).
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
- [~] 3.4 Agenda hari terpilih
  - `_HomeAgendaList`: daftar record hari terpilih (MK + jam + pertemuan + status pill), reuse pola `_DayDetailItem`. Default hari terpilih = hari ini.
  - Empty state ramah bila hari terpilih tanpa record / hari depan ("Tidak ada kelas tercatat di hari ini").
  - Label tanggal Bahasa Indonesia ("Sabtu, 31 Mei").
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6_

- [~] 4. Bangun widget `HomeStatsRingCard`
  - Buat `lib/features/home/widgets/home_stats_ring_card.dart` (`StatelessWidget`) menerima `AttendanceSummary`.
  - Ring/donut persen `summary.percentage` via `CustomPaint` (tanpa package baru) + legend (Hadir/Izin-Sakit/Alpa; Terlambat bila > 0).
  - Tombol "Detail" → `onDetail` (setTab Riwayat). Sertakan skeleton `_StatsRingSkeleton` untuk state loading.
  - _Requirements: 4.1, 4.2, 7.2_

- [ ] 5. Integrasikan ke `HomeScreen`
- [~] 5.1 Susun ulang section + audit `_sectionCount`
  - Ganti `_animated(2, _TodaySummaryRow)` → `HomeStatsRingCard` (feed dari `historyProvider.summary`).
  - Ganti `_animated(4, _buildActivityFeedSection)` → struktur baru; urutan final: greeting(0) → hero(1) → `HomeHistoryCalendarCard`(2) → `HomeStatsRingCard`(3) → quick action(4).
  - Pastikan jumlah `_animated(i, ...)` == `_sectionCount` (audit eksplisit, cegah BUG-12 RangeError).
  - Cek referensi `recentActivitiesProvider` & `_TodaySummaryRow` di seluruh codebase sebelum menghapus; hapus/biarkan deprecate dengan aman.
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_
- [~] 5.2 Wiring navigasi + pull-to-refresh
  - `HomeHistoryCalendarCard.onOpenFullCalendar` & `HomeStatsRingCard.onDetail` → `currentTabProvider.setTab(2)` (verifikasi index tab Riwayat di `app_shell.dart`).
  - Tambah `ref.invalidate(historyProvider)` di `RefreshIndicator.onRefresh` Beranda (samping `activeSessionsProvider`).
  - _Requirements: 4.2, 4.3, 6.2_

- [~] 6. Sinkronisasi data pasca-submit presensi
  - Pastikan handler "Kembali ke Beranda" di `attendance_result_screen.dart` memanggil `ref.invalidate(historyProvider)` (selain provider lain) agar week strip/agenda/statistik segar tanpa hot restart.
  - _Requirements: 6.1_

- [~] 7. Verifikasi akhir + dokumentasi
  - `flutter analyze` 0 issues; `flutter test` hijau.
  - Verifikasi visual (rule 06 Law 4): screenshot Beranda — week strip, hari ini ter-outline, tint status, tap hari berdata/kosong/depan, navigasi minggu + klamping, "Kalender penuh" → tab Riwayat → back, submit presensi → record muncul tanpa hot restart, 3-state (loading/empty/error).
  - Update `CHANGELOG.md` (entri per file) + `dev-log.md` (keputusan redesign + cross-ref BUG-12/BUG-017).
  - _Requirements: 5.1, 5.2, 5.3, 6.1, 7.3_

## Task Dependency Graph

```
1 (helper status shared)
├─► 2.1 (helper minggu) ─► 2.2 (unit test helper status + minggu)
│
└─► 3.1 (kerangka card + 3-state)
       ├─► 3.2 (week strip + day pill)   [butuh 1, 2.1]
       ├─► 3.3 (navigasi minggu)         [butuh 2.1]
       └─► 3.4 (agenda hari terpilih)    [butuh 1]

4 (HomeStatsRingCard)                     [independen, butuh model existing]

5.1 (susun ulang section + audit _sectionCount)  [butuh 3.x, 4]
└─► 5.2 (wiring navigasi + pull-to-refresh)

6 (invalidate pasca-submit)               [independen, bisa paralel setelah 1]

7 (verifikasi akhir + dokumentasi)        [butuh semua: 1–6]
```

Urutan eksekusi disarankan: 1 → 2.1 → 2.2 → (3.1 → 3.2/3.3/3.4) & 4 (paralel) → 5.1 → 5.2 → 6 → 7.

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1"] },
    { "wave": 2, "tasks": ["2.1", "4", "6"] },
    { "wave": 3, "tasks": ["2.2", "3.1"] },
    { "wave": 4, "tasks": ["3.2", "3.3", "3.4"] },
    { "wave": 5, "tasks": ["5.1"] },
    { "wave": 6, "tasks": ["5.2"] },
    { "wave": 7, "tasks": ["7"] }
  ]
}
```

## Notes

- **Cegah BUG-12**: setiap kali jumlah section Beranda berubah, audit eksplisit `_sectionCount` == jumlah `_animated(i, ...)`.
- **Cegah BUG-017**: invalidate `historyProvider` setelah mutasi presensi (task 6) dan di pull-to-refresh (task 5.2).
- **Library lock**: tidak menambah package kalender/chart baru. Week strip kustom + ring `CustomPaint`. `table_calendar` hanya di tab Riwayat.
- **UX writing (rule 09)**: semua teks Bahasa Indonesia, sapaan "kamu", ringkas.
- **Verifikasi runtime (rule 06)**: perubahan UI butuh konfirmasi visual (screenshot) sebelum klaim selesai — bukan sekadar `flutter analyze`.
- **Refactor task 1 bersifat non-fungsional**: pastikan tab Riwayat tetap identik perilakunya.
