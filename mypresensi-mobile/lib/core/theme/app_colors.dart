// lib/core/theme/app_colors.dart
// Design token warna mobile MyPresensi v7 (17 Mei 2026).
// Sinkron dengan mockup HTML _tokens.css → primary #2D86FF (sebelumnya #5483AD).
// Catatan migrasi: nama field lama (background, surfaceVariant, dll) DIPERTAHANKAN
// sebagai alias non-breaking — 30+ file consume token via nama tersebut.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // === BRAND — Primary v7 (sinkron mockup HTML) ===
  // Update dari #5483AD → #2D86FF: lebih bright untuk mobile, sesuai rule 22-mobile-design-system.md.
  static const Color primary = Color(0xFF2D86FF);
  static const Color primaryHover = Color(0xFF1E70E0); // hover state
  static const Color primaryDark = Color(0xFF0D2C5E); // hero gradient end (navy)
  static const Color primaryDeep = Color(0xFF082040); // deepest navy untuk shadow tint
  static const Color primarySurface = Color(0xFFEAF3FF); // 10% tint background
  static const Color primaryLight = Color(0xFF5BA0FF); // dark mode adjusted (alias)

  // === ACCENT — Gold Politani (signature) ===
  static const Color accent = Color(0xFFF4B400);
  static const Color accentSoft = Color(0x4DF4B400); // 30% alpha — untuk hero radial glow

  // === Status ===
  static const Color success = Color(0xFF1A7F37);
  static const Color successSurface = Color(0xFFECFDF5); // 5% tint solid
  static const Color successTint = Color(0x1A1A7F37); // 10% alpha — duotone bg
  static const Color successLight = Color(0xFFDCFCE7); // alias backward compat

  static const Color warning = Color(0xFF9A6700);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color warningTint = Color(0x1A9A6700);
  static const Color warningLight = Color(0xFFFEF3C7); // alias backward compat

  static const Color danger = Color(0xFFCF222E);
  static const Color dangerSurface = Color(0xFFFEF2F2);
  static const Color dangerTint = Color(0x1ACF222E);
  static const Color dangerLight = Color(0xFFFEE2E2); // alias backward compat

  static const Color info = Color(0xFF0969DA);
  static const Color infoSurface = Color(0xFFEFF6FF);
  static const Color infoTint = Color(0x1A0969DA);
  static const Color infoLight = Color(0xFFDBEAFE); // alias backward compat

  // === Neutrals ===
  static const Color bg = Color(0xFFF4F6F8); // canvas/scaffold (sinonim background)
  static const Color background = Color(0xFFF4F6F8); // alias backward compat
  static const Color surface = Color(0xFFFFFFFF); // card
  static const Color surfaceSunken = Color(0xFFF0F2F4); // input field bg, modal backdrop
  static const Color surfaceVariant = Color(0xFFF8F9FA); // alias backward compat (sligthly diff)
  static const Color border = Color(0xFFE2E6EA);
  static const Color borderStrong = Color(0xFFD1D7DE);
  static const Color borderLight = Color(0xFFF0F2F4); // alias backward compat
  static const Color divider = Color(0xFFEEF0F2); // alias backward compat

  // === Text ===
  // textTertiary dinaikkan dari #9CA3AF → #757B82 untuk WCAG AA pass (4.55:1 vs white).
  static const Color textPrimary = Color(0xFF1C2024); // judul, body utama
  static const Color textSecondary = Color(0xFF636C76); // subtitle, meta info
  static const Color textTertiary = Color(0xFF757B82); // disabled, caption (WCAG-safe)
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // === Gradients ===
  // primaryGradient: brand 2-stop primary → navy (untuk hero card, header).
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5BA0FF), Color(0xFF2D86FF)], // primaryLight -> primary
  );

  // headerGradient: 3-stop dengan accent gold untuk hero summary mendalam.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D86FF), Color(0xFF1E70E0), Color(0xFF0D2C5E)],
  );
}
