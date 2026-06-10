// lib/shared/widgets/app_card.dart
// Card default — white surface + radius 16 + layered shadow + padding 16.
// Pattern dasar untuk list item, info card, summary card (rule 22 §E.3).
// JANGAN pakai Container + Border.all sebagai pengganti — itu flat (anti-pattern §H).

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.elevated = false,
    this.borderRadius = 16,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Optional tap handler — kalau null, card tidak interactive.
  final VoidCallback? onTap;

  /// Elevated = pakai shadow lebih dramatis (untuk modal, bottom sheet, dropdown).
  /// Default = card biasa untuk list/feed.
  final bool elevated;

  /// Default 16. Pakai 14 untuk card kompak, 20 untuk hero/modal.
  final double borderRadius;

  /// Override default white surface kalau perlu (jarang).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: elevated ? AppShadows.cardElevated : AppShadows.card,
        ),
        child: child,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevated ? AppShadows.cardElevated : AppShadows.card,
      ),
      child: Material(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
