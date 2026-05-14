// lib/core/theme/app_colors.dart
// Design token warna yang sinkron dengan web design system

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // === Primary (Biru TRPL) ===
  static const Color primary = Color(0xFF5483AD);
  static const Color primaryLight = Color(0xFF7BA3C7);
  static const Color primaryDark = Color(0xFF3A6B8F);
  static const Color primarySurface = Color(0xFFE8F0F7);

  // === Neutral ===
  static const Color background = Color(0xFFF4F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F9FA);
  static const Color border = Color(0xFFE2E6EA);
  static const Color borderLight = Color(0xFFF0F2F4);
  static const Color divider = Color(0xFFEEF0F2);

  // === Text ===
  static const Color textPrimary = Color(0xFF1A1D21);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // === Status ===
  static const Color success = Color(0xFF1A7F37);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successSurface = Color(0xFFECFDF5);

  static const Color warning = Color(0xFF9A6700);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningSurface = Color(0xFFFFFBEB);

  static const Color danger = Color(0xFFCF222E);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color dangerSurface = Color(0xFFFEF2F2);

  static const Color info = Color(0xFF0969DA);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // === Gradients ===
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5483AD), Color(0xFF3A6B8F)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5483AD), Color(0xFF4A7BA5), Color(0xFF3A6B8F)],
  );
}
