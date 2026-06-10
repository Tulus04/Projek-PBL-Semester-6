// lib/features/home/widgets/stat_ring_card.dart
// Kartu statistik ring (donut chart) kehadiran untuk Beranda.
// Menggantikan _TodaySummaryRow (3 stat card) dengan visual yang lebih informatif.
// CustomPaint ring — tidak menambah package chart baru (library lock rule).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../history/data/history_models.dart';

// ============================================================================
// StatRingCard — main widget
// ============================================================================

class StatRingCard extends StatelessWidget {
  const StatRingCard({super.key, required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Ring chart
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _RingPainter(summary: summary),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.percentage.round()}%',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'kehadiran',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Statistik Kehadiran',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _LegendItem(
                        color: AppColors.success,
                        icon: IconsaxPlusBold.tick_circle,
                        label: 'Hadir',
                        value: summary.hadir,
                      ),
                    ),
                    Expanded(
                      child: _LegendItem(
                        color: AppColors.info,
                        icon: IconsaxPlusBold.clock,
                        label: 'Telat',
                        value: summary.terlambat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _LegendItem(
                        color: AppColors.warning,
                        icon: IconsaxPlusBold.note_2,
                        label: 'Izin',
                        value: summary.izin + summary.sakit,
                      ),
                    ),
                    Expanded(
                      child: _LegendItem(
                        color: AppColors.danger,
                        icon: IconsaxPlusBold.close_circle,
                        label: 'Alpa',
                        value: summary.alpa,
                      ),
                    ),
                  ],
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
// _LegendItem — satu baris legend: dot + icon + label + value
// ============================================================================

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
  });
  final Color color;
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          '$value',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _RingPainter — CustomPaint donut chart
// ============================================================================

class _RingPainter extends CustomPainter {
  _RingPainter({required this.summary});
  final AttendanceSummary summary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 8.0;
    final effectiveRadius = radius - strokeWidth / 2;
    const startAngle = -math.pi / 2; // 12 jam

    final total = summary.totalSessions;
    if (total == 0) {
      // Draw empty ring
      final paint = Paint()
        ..color = AppColors.surfaceSunken
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, effectiveRadius, paint);
      return;
    }

    // Segments: hadir, terlambat, izin+sakit, alpa
    final segments = <_Segment>[
      _Segment(value: summary.hadir, color: AppColors.success),
      _Segment(value: summary.terlambat, color: AppColors.info),
      _Segment(value: summary.izin + summary.sakit, color: AppColors.warning),
      _Segment(value: summary.alpa, color: AppColors.danger),
    ];

    final rect = Rect.fromCircle(center: center, radius: effectiveRadius);
    var currentAngle = startAngle;

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweepAngle = (seg.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, currentAngle, sweepAngle, false, paint);
      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.summary.totalSessions != summary.totalSessions ||
        oldDelegate.summary.hadir != summary.hadir ||
        oldDelegate.summary.terlambat != summary.terlambat ||
        oldDelegate.summary.izin != summary.izin ||
        oldDelegate.summary.sakit != summary.sakit ||
        oldDelegate.summary.alpa != summary.alpa;
  }
}

class _Segment {
  const _Segment({required this.value, required this.color});
  final int value;
  final Color color;
}

// ============================================================================
// StatsRingSkeleton — skeleton placeholder untuk StatRingCard
// ============================================================================

class StatsRingSkeleton extends StatelessWidget {
  const StatsRingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Ring chart skeleton
          const LoadingSkeleton.circle(size: 80),
          const SizedBox(width: 16),

          // Legend skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const LoadingSkeleton(height: 14, width: 130),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Expanded(child: _LegendSkeletonItem()),
                    Expanded(child: _LegendSkeletonItem()),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Expanded(child: _LegendSkeletonItem()),
                    Expanded(child: _LegendSkeletonItem()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendSkeletonItem extends StatelessWidget {
  const _LegendSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        LoadingSkeleton.circle(size: 8),
        SizedBox(width: 4),
        LoadingSkeleton.circle(size: 12),
        SizedBox(width: 3),
        LoadingSkeleton(height: 10, width: 35),
      ],
    );
  }
}
