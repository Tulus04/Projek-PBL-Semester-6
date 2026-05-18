// lib/shared/widgets/kpi_icon_box.dart
// Duotone icon box — Container kotak rounded + tint background + solid icon.
// Pattern WAJIB untuk quick action, list item leading, summary KPI (rule 22 §E.2).
// 6 variants: primary, success, warning, danger, info, accent (gold), featured.

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum KpiColor { primary, success, warning, danger, info, accent, featured }

class KpiIconBox extends StatelessWidget {
  const KpiIconBox({
    super.key,
    required this.icon,
    this.variant = KpiColor.primary,
    this.size = 38,
    this.borderRadius = 12,
  });

  final IconData icon;
  final KpiColor variant;

  /// Default 38px. Pakai 32 untuk compact list, 44+ untuk hero/CTA.
  final double size;

  /// Default 12. Match radius card kalau pakai 14, atau pill 999.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(variant);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, color: colors.fg, size: size * 0.47),
    );
  }

  ({Color bg, Color fg}) _resolveColors(KpiColor v) => switch (v) {
        KpiColor.primary => (bg: AppColors.primarySurface, fg: AppColors.primary),
        KpiColor.success => (bg: AppColors.successTint, fg: AppColors.success),
        KpiColor.warning => (bg: AppColors.warningTint, fg: AppColors.warning),
        KpiColor.danger => (bg: AppColors.dangerTint, fg: AppColors.danger),
        KpiColor.info => (bg: AppColors.infoTint, fg: AppColors.info),
        // Accent gold untuk highlight signature (jarang)
        KpiColor.accent => (bg: AppColors.accentSoft, fg: AppColors.warning),
        // Featured untuk signature CTA (Scan QR) — full gold solid
        KpiColor.featured => (bg: AppColors.accent, fg: Colors.white),
      };
}
