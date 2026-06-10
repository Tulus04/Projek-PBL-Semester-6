// lib/features/history/screens/history_screen.dart
// Halaman riwayat kehadiran v7 — sesuai mockup mobile-riwayat.html (17 Mei 2026).
// Layout: hero progress 5-stat → filter chip 6-status → smart-date group list → tap item buka bottom sheet detail (read-only).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/hero_card.dart';
import '../../../shared/widgets/kpi_icon_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../data/history_models.dart';
import '../providers/history_provider.dart';
import 'history_calendar_view.dart';

// ============================================================================
// Local filter provider — Riverpod 3 NotifierProvider per-screen scoped.
// ============================================================================

enum _HistoryFilter { semua, hadir, telat, izin, sakit, alpa }

final _historyFilterProvider =
    NotifierProvider<_HistoryFilterNotifier, _HistoryFilter>(
  _HistoryFilterNotifier.new,
);

class _HistoryFilterNotifier extends Notifier<_HistoryFilter> {
  @override
  _HistoryFilter build() => _HistoryFilter.semua;

  void set(_HistoryFilter v) => state = v;
}

// ============================================================================
// Local view-mode provider — toggle List ↔ Calendar (rule 22 design system).
// ============================================================================

enum HistoryViewMode { list, calendar }

final historyViewModeProvider =
    NotifierProvider<HistoryViewModeNotifier, HistoryViewMode>(
  HistoryViewModeNotifier.new,
);

class HistoryViewModeNotifier extends Notifier<HistoryViewMode> {
  @override
  HistoryViewMode build() => HistoryViewMode.list;

  void set(HistoryViewMode v) => state = v;
}

// ============================================================================
// Pure helpers — date / format / status mapping
// ============================================================================

const List<String> _idWeekdayNames = [
  'Senin', // 1
  'Selasa', // 2
  'Rabu', // 3
  'Kamis', // 4
  'Jumat', // 5
  'Sabtu', // 6
  'Minggu', // 7
];

const List<String> _idMonthNames = [
  'Januari', // 1
  'Februari', // 2
  'Maret', // 3
  'April', // 4
  'Mei', // 5
  'Juni', // 6
  'Juli', // 7
  'Agustus', // 8
  'September', // 9
  'Oktober', // 10
  'November', // 11
  'Desember', // 12
];

String _idWeekday(int weekday) {
  if (weekday < 1 || weekday > 7) return '';
  return _idWeekdayNames[weekday - 1];
}

String _idMonth(int month) {
  if (month < 1 || month > 12) return '';
  return _idMonthNames[month - 1];
}

/// Format hari + tanggal Indonesia singkat: "Jumat, 15 Mei".
String _formatDayDate(DateTime d) =>
    '${_idWeekday(d.weekday)}, ${d.day} ${_idMonth(d.month)}';

/// Format jam HH:mm dari string ISO scannedAt.
String _formatTimeOnly(String scannedAt) {
  try {
    final dt = DateTime.parse(scannedAt).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  } catch (_) {
    return '--:--';
  }
}



/// Mapping status enum DB → KpiColor untuk leading icon di item card.
KpiColor _statusKpiColor(String status) {
  switch (status) {
    case 'hadir':
      return KpiColor.success;
    case 'terlambat':
      return KpiColor.info;
    case 'izin':
      return KpiColor.warning;
    case 'sakit':
      return KpiColor.warning;
    case 'alpa':
      return KpiColor.danger;
    default:
      return KpiColor.primary;
  }
}

/// Icon utama per status (untuk leading + status pill).
IconData _statusIcon(String status) {
  switch (status) {
    case 'hadir':
      return IconsaxPlusBold.tick_circle;
    case 'terlambat':
      return IconsaxPlusBold.clock;
    case 'izin':
      return IconsaxPlusBold.note_2;
    case 'sakit':
      return IconsaxPlusBold.health;
    case 'alpa':
      return IconsaxPlusBold.close_circle;
    default:
      return IconsaxPlusBold.clock;
  }
}

/// Solid color status untuk text/icon foreground.
Color _statusFg(String status) {
  switch (status) {
    case 'hadir':
      return AppColors.success;
    case 'terlambat':
      return AppColors.info;
    case 'izin':
    case 'sakit':
      return AppColors.warning;
    case 'alpa':
      return AppColors.danger;
    default:
      return AppColors.textSecondary;
  }
}

/// Tint background status (alpha 10%) untuk pill / banner.
Color _statusTint(String status) {
  switch (status) {
    case 'hadir':
      return AppColors.successTint;
    case 'terlambat':
      return AppColors.infoTint;
    case 'izin':
    case 'sakit':
      return AppColors.warningTint;
    case 'alpa':
      return AppColors.dangerTint;
    default:
      return AppColors.surfaceSunken;
  }
}

/// Label uppercase Indonesia untuk status pill.
String _statusLabel(String status) {
  switch (status) {
    case 'hadir':
      return 'HADIR';
    case 'terlambat':
      return 'TELAT';
    case 'izin':
      return 'IZIN';
    case 'sakit':
      return 'SAKIT';
    case 'alpa':
      return 'ALPA';
    default:
      return status.toUpperCase();
  }
}

/// Sub-text status banner untuk bottom sheet detail.
String _statusBannerTitle(String status) {
  switch (status) {
    case 'hadir':
      return 'Berhasil Hadir';
    case 'terlambat':
      return 'Hadir Terlambat';
    case 'izin':
      return 'Izin Disetujui';
    case 'sakit':
      return 'Sakit Tercatat';
    case 'alpa':
      return 'Tidak Hadir';
    default:
      return _statusLabel(status);
  }
}

String _statusBannerSub(String status) {
  switch (status) {
    case 'hadir':
      return 'Verifikasi presensi lolos. Kehadiranmu tercatat.';
    case 'terlambat':
      return 'Kamu hadir tapi sedikit telat dari jam mulai sesi.';
    case 'izin':
      return 'Pengajuan izin telah ditinjau dan disetujui dosen.';
    case 'sakit':
      return 'Pengajuan sakit telah ditinjau dan disetujui dosen.';
    case 'alpa':
      return 'Tidak ada catatan presensi maupun izin untuk sesi ini.';
    default:
      return '';
  }
}

// ============================================================================
// Algorithm 3 — groupHistoryBySmartDate
// ============================================================================

/// Bucket internal untuk grouping berdasarkan rentang waktu relatif.
enum _DateBucket { hariIni, kemarin, mingguIni, bulanIni, lebihLama }

/// Hasil grouping: label tampilan + count + items dalam bucket.
typedef _DateGroup = ({String label, int count, List<AttendanceRecord> items});

/// Smart-date grouping per design.md §Algorithm 3.
///
/// Input: `records` sudah di-sort DESC oleh server (terbaru di atas).
/// Output: list group dengan urutan tetap [hari ini → kemarin → minggu ini →
/// bulan ini → lebih lama], skip empty bucket. Order record dalam tiap
/// bucket = order asli (order-stable).
List<_DateGroup> _groupHistoryBySmartDate(List<AttendanceRecord> records) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final weekStart = todayStart.subtract(const Duration(days: 7));
  final monthStart = todayStart.subtract(const Duration(days: 30));

  final buckets = <_DateBucket, List<AttendanceRecord>>{
    _DateBucket.hariIni: [],
    _DateBucket.kemarin: [],
    _DateBucket.mingguIni: [],
    _DateBucket.bulanIni: [],
    _DateBucket.lebihLama: [],
  };

  for (final r in records) {
    DateTime scanned;
    try {
      scanned = DateTime.parse(r.scannedAt).toLocal();
    } catch (_) {
      // Fallback: kalau gagal parse, masukkan ke bucket lebih lama.
      buckets[_DateBucket.lebihLama]!.add(r);
      continue;
    }

    if (!scanned.isBefore(todayStart)) {
      buckets[_DateBucket.hariIni]!.add(r);
    } else if (!scanned.isBefore(yesterdayStart)) {
      buckets[_DateBucket.kemarin]!.add(r);
    } else if (!scanned.isBefore(weekStart)) {
      buckets[_DateBucket.mingguIni]!.add(r);
    } else if (!scanned.isBefore(monthStart)) {
      buckets[_DateBucket.bulanIni]!.add(r);
    } else {
      buckets[_DateBucket.lebihLama]!.add(r);
    }
  }

  final yesterday = todayStart.subtract(const Duration(days: 1));

  final result = <_DateGroup>[];
  void append(_DateBucket b, String label) {
    final items = buckets[b]!;
    if (items.isEmpty) return;
    result.add((label: label, count: items.length, items: items));
  }

  append(_DateBucket.hariIni, 'Hari Ini · ${_formatDayDate(now)}');
  append(_DateBucket.kemarin, 'Kemarin · ${_formatDayDate(yesterday)}');
  append(_DateBucket.mingguIni, 'Minggu Ini');
  append(_DateBucket.bulanIni, 'Bulan Ini');
  append(_DateBucket.lebihLama, 'Lebih Lama');
  return result;
}

// ============================================================================
// Algorithm 5 — filterByStatus
// ============================================================================

/// Pure pattern match filter — order-stable.
List<AttendanceRecord> _filterByStatus(
  List<AttendanceRecord> records,
  _HistoryFilter filter,
) {
  return switch (filter) {
    _HistoryFilter.semua => List<AttendanceRecord>.unmodifiable(records),
    _HistoryFilter.hadir =>
      records.where((r) => r.status == 'hadir').toList(growable: false),
    _HistoryFilter.telat =>
      records.where((r) => r.status == 'terlambat').toList(growable: false),
    _HistoryFilter.izin =>
      records.where((r) => r.status == 'izin').toList(growable: false),
    _HistoryFilter.sakit =>
      records.where((r) => r.status == 'sakit').toList(growable: false),
    _HistoryFilter.alpa =>
      records.where((r) => r.status == 'alpa').toList(growable: false),
  };
}

// ============================================================================
// HistoryScreen — wiring utama
// ============================================================================

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const _AppBarTitle(),
      ),
      body: SafeArea(
        child: historyAsync.when(
          data: (data) => _buildContent(context, ref, data),
          loading: () => const ListLoadingPlaceholder(itemCount: 5),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              ErrorState(
                title: 'Gagal memuat riwayat',
                message: friendlyErrorMessage(error),
                onRetry: () => ref.invalidate(historyProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    HistoryResponse data,
  ) {
    final viewMode = ref.watch(historyViewModeProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(historyProvider);
        await ref.read(historyProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Hero summary — 5-stat + progress bar.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _HistoryHero(summary: data.summary),
            ),
          ),

          // View toggle — List ↔ Calendar.
          const SliverToBoxAdapter(child: _HistoryViewToggle()),

          if (viewMode == HistoryViewMode.list) ...[
            // Filter chips — horizontal scroll (hanya muncul di mode list).
            SliverToBoxAdapter(
              child: _HistoryFilterChips(
                counts: <_HistoryFilter, int>{
                  _HistoryFilter.semua: data.summary.totalSessions,
                  _HistoryFilter.hadir: data.summary.hadir,
                  _HistoryFilter.telat: data.summary.terlambat,
                  _HistoryFilter.izin: data.summary.izin,
                  _HistoryFilter.sakit: data.summary.sakit,
                  _HistoryFilter.alpa: data.summary.alpa,
                },
              ),
            ),

            // Body — empty / filtered-empty / grouped list.
            ..._buildListSlivers(context, ref, data),
          ] else ...[
            // Calendar heatmap view.
            SliverToBoxAdapter(
              child: HistoryCalendarView(records: data.history),
            ),
          ],

          // Bottom spacing.
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _buildListSlivers(
    BuildContext context,
    WidgetRef ref,
    HistoryResponse data,
  ) {
    // Total kosong (mahasiswa baru).
    if (data.history.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildAllEmpty(),
        ),
      ];
    }

    final activeFilter = ref.watch(_historyFilterProvider);
    final filtered = _filterByStatus(data.history, activeFilter);

    if (filtered.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildFilterEmpty(activeFilter),
        ),
      ];
    }

    final groups = _groupHistoryBySmartDate(filtered);

    return [
      for (final group in groups) ...[
        SliverToBoxAdapter(
          child: _DateGroupHeader(label: group.label, count: group.count),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final record = group.items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HistoryItemCard(
                    record: record,
                    onTap: () => _openDetailSheet(context, record),
                  ),
                );
              },
              childCount: group.items.length,
            ),
          ),
        ),
      ],
    ];
  }

  void _openDetailSheet(BuildContext context, AttendanceRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.primaryDeep.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      builder: (sheetCtx) => _HistoryDetailSheet(record: record),
    );
  }

  Widget _buildAllEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              IconsaxPlusBold.clipboard_text,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum ada riwayat kehadiran',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Riwayat presensi kamu akan muncul di sini setelah scan QR di sesi pertemuan.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterEmpty(_HistoryFilter filter) {
    final (msg, icon) = switch (filter) {
      _HistoryFilter.semua => (
          'Belum ada riwayat di semester ini',
          IconsaxPlusBold.clipboard_text,
        ),
      _HistoryFilter.hadir => (
          'Belum ada catatan hadir',
          IconsaxPlusBold.tick_circle,
        ),
      _HistoryFilter.telat => (
          'Tidak ada riwayat terlambat',
          IconsaxPlusBold.clock,
        ),
      _HistoryFilter.izin => (
          'Belum ada izin tercatat',
          IconsaxPlusBold.note_2,
        ),
      _HistoryFilter.sakit => (
          'Belum ada sakit tercatat',
          IconsaxPlusBold.health,
        ),
      _HistoryFilter.alpa => (
          'Tidak ada absen tercatat',
          IconsaxPlusBold.close_circle,
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AppBar title
// ============================================================================

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Riwayat',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Catatan kehadiran semester',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _HistoryHero — gradient + 5-stat + progress bar
// ============================================================================

class _HistoryHero extends StatelessWidget {
  const _HistoryHero({required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final percentage = summary.percentage.clamp(0.0, 100.0);

    final percentageText = percentage.toStringAsFixed(percentage % 1 == 0 ? 0 : 1);

    return HeroCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label uppercase tipis di atas.
          Text(
            'KEHADIRAN SEMESTER INI',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),

          // Persentase besar + kategori.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                percentageText,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 36,
                  letterSpacing: -1,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '% dari ${summary.totalSessions} Sesi',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar — gradient hijau → gold.
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage / 100,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.success, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5-stat detail row — wrap supaya aman saat sempit.
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _HeroStat(
                icon: IconsaxPlusBold.tick_circle,
                count: summary.hadir,
                label: 'Hadir',
              ),
              _HeroStat(
                icon: IconsaxPlusBold.clock,
                count: summary.terlambat,
                label: 'Telat',
              ),
              _HeroStat(
                icon: IconsaxPlusBold.note_2,
                count: summary.izin,
                label: 'Izin',
              ),
              _HeroStat(
                icon: IconsaxPlusBold.health,
                count: summary.sakit,
                label: 'Sakit',
              ),
              _HeroStat(
                icon: IconsaxPlusBold.close_circle,
                count: summary.alpa,
                label: 'Alpa',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _HistoryViewToggle — segmented toggle List ↔ Calendar
// ============================================================================

class _HistoryViewToggle extends ConsumerWidget {
  const _HistoryViewToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(historyViewModeProvider);
    final notifier = ref.read(historyViewModeProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Expanded(
              child: _ToggleSegment(
                label: 'Daftar',
                icon: IconsaxPlusBold.task_square,
                active: mode == HistoryViewMode.list,
                onTap: () => notifier.set(HistoryViewMode.list),
              ),
            ),
            Expanded(
              child: _ToggleSegment(
                label: 'Kalender',
                icon: IconsaxPlusBold.calendar_1,
                active: mode == HistoryViewMode.calendar,
                onTap: () => notifier.set(HistoryViewMode.calendar),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _HistoryFilterChips — 6 chips horizontal scroll
// ============================================================================

class _HistoryFilterChips extends ConsumerWidget {
  const _HistoryFilterChips({required this.counts});
  final Map<_HistoryFilter, int> counts;

  static const _items = <({_HistoryFilter filter, String label})>[
    (filter: _HistoryFilter.semua, label: 'Semua'),
    (filter: _HistoryFilter.hadir, label: 'Hadir'),
    (filter: _HistoryFilter.telat, label: 'Telat'),
    (filter: _HistoryFilter.izin, label: 'Izin'),
    (filter: _HistoryFilter.sakit, label: 'Sakit'),
    (filter: _HistoryFilter.alpa, label: 'Alpa'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_historyFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              _FilterChip(
                label: _items[i].label,
                count: counts[_items[i].filter] ?? 0,
                active: active == _items[i].filter,
                onTap: () => ref
                    .read(_historyFilterProvider.notifier)
                    .set(_items[i].filter),
              ),
              if (i < _items.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _DateGroupHeader — uppercase label kiri + count "X SESI" kanan
// ============================================================================

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count SESI',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.textTertiary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _HistoryItemCard — leading icon box + info MK + status pill
// ============================================================================

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({required this.record, required this.onTap});

  final AttendanceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Leading: KpiIconBox 44x44 dengan icon status.
          KpiIconBox(
            icon: _statusIcon(record.status),
            variant: _statusKpiColor(record.status),
            size: 44,
            borderRadius: 12,
          ),
          const SizedBox(width: 12),

          // Center: nama MK + meta row.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.courseName,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _ItemMetaRow(record: record),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Trailing: status pill duotone.
          _StatusPill(status: record.status),
        ],
      ),
    );
  }
}

class _ItemMetaRow extends StatelessWidget {
  const _ItemMetaRow({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final time = _formatTimeOnly(record.scannedAt);
    final hasDistance = record.distanceMeters != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          IconsaxPlusBold.clock,
          size: 12,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 3),
        Text(
          time,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (hasDistance) ...[
          const SizedBox(width: 8),
          const Text(
            '·',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(width: 8),
          const Icon(
            IconsaxPlusBold.location,
            size: 12,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 3),
          Text(
            '${record.distanceMeters} m',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final fg = _statusFg(status);
    final bg = _statusTint(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }
}

// ============================================================================
// _HistoryDetailSheet — read-only bottom sheet (no buttons)
// ============================================================================

class _HistoryDetailSheet extends StatelessWidget {
  const _HistoryDetailSheet({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    DateTime? scannedDt;
    try {
      scannedDt = DateTime.parse(record.scannedAt).toLocal();
    } catch (_) {
      scannedDt = null;
    }

    final timeStr = scannedDt != null
        ? '${scannedDt.hour.toString().padLeft(2, '0')}:${scannedDt.minute.toString().padLeft(2, '0')} WIB'
        : '--:--';
    final dateStr = scannedDt != null
        ? '${_idWeekday(scannedDt.weekday)}, ${scannedDt.day} ${_idMonth(scannedDt.month)} ${scannedDt.year}'
        : 'Tanggal tidak diketahui';

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle 36x4.
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          // Scrollable content.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBanner(status: record.status),
                  const SizedBox(height: 18),

                  // Detail rows.
                  _DetailRow(
                    icon: IconsaxPlusBold.book_1,
                    label: 'MATA KULIAH',
                    value: record.courseName,
                    sub: '${record.courseCode} · Pertemuan ${record.sessionNumber}'
                        '${record.topic != null ? ' · ${record.topic}' : ''}',
                  ),
                  _DetailRow(
                    icon: IconsaxPlusBold.calendar_2,
                    label: 'WAKTU PRESENSI',
                    value: timeStr,
                    sub: dateStr,
                  ),

                  // Lokasi — render hanya jika data tersedia.
                  if (record.distanceMeters != null)
                    _DetailRow(
                      icon: IconsaxPlusBold.location,
                      label: 'LOKASI',
                      value: '${record.distanceMeters} meter dari titik pusat',
                      sub: (record.isLocationValid ?? false)
                          ? 'Valid · masih dalam radius geofence kampus'
                          : 'Di luar radius geofence',
                      iconColor:
                          (record.isLocationValid ?? false) ? AppColors.success : null,
                      iconBg:
                          (record.isLocationValid ?? false) ? AppColors.successTint : null,
                      subColor:
                          (record.isLocationValid ?? false) ? AppColors.success : null,
                    ),

                  // Verifikasi wajah — render hanya jika ada confidence.
                  if (record.faceConfidence != null)
                    _FaceVerificationRow(confidence: record.faceConfidence!),

                  // Perangkat — placeholder static (data tidak di-expose backend).
                  const _DetailRow(
                    icon: IconsaxPlusBold.mobile,
                    label: 'PERANGKAT',
                    value: 'Tercatat di sistem',
                    sub: 'Detail perangkat hanya bisa diakses oleh dosen / admin.',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final fg = _statusFg(status);
    final bg = _statusTint(status);
    final icon = _statusIcon(status);
    final title = _statusBannerTitle(status);
    final sub = _statusBannerSub(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: fg,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.iconColor,
    this.iconBg,
    this.subColor,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  /// Override warna icon foreground (default textSecondary).
  final Color? iconColor;

  /// Override warna icon background (default surfaceSunken).
  final Color? iconBg;

  /// Override warna sub-text (mis. success untuk lokasi valid).
  final Color? subColor;

  /// Hilangkan border bottom kalau ini row terakhir.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon box 32x32 duotone-style.
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: iconBg ?? AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: iconColor ?? AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),

          // Info.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                if (sub != null && sub!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: subColor ?? AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Row khusus verifikasi wajah — pakai _DetailRow + trailing _FaceMatchThumb.
class _FaceVerificationRow extends StatelessWidget {
  const _FaceVerificationRow({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    const threshold = 0.65;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: AppColors.successTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              IconsaxPlusBold.user_octagon,
              size: 16,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'VERIFIKASI WAJAH',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                _FaceMatchThumb(
                  confidence: confidence,
                  threshold: threshold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _FaceMatchThumb — placeholder gradient avatar + match label
// ============================================================================

class _FaceMatchThumb extends StatelessWidget {
  const _FaceMatchThumb({
    required this.confidence,
    required this.threshold,
  });

  final double confidence;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).clamp(0.0, 100.0);
    final thrPct = (threshold * 100).clamp(0.0, 100.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 56x56 placeholder avatar — gradient primary → primaryHover.
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryHover],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success, width: 2),
            boxShadow: AppShadows.card,
          ),
          child: const Icon(
            IconsaxPlusBold.user_octagon,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),

        // Label cocok + threshold.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cocok ${pct.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Threshold ${thrPct.toStringAsFixed(0)}% · Liveness OK',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
