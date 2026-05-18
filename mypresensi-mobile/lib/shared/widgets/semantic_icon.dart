// lib/shared/widgets/semantic_icon.dart
// Helper widget untuk Semantic System (rule 22 §C.5).
// JANGAN langsung pakai Icon(IconsaxPlus..., color: ...) — pakai widget ini agar
// warna konsisten dengan token semantic dan mudah refactor masal.

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 6 semantic variants per rule 22 §C.3.
/// Default ke `action` saat ragu (rule 22 §C.6).
enum IconSemanticVariant {
  /// Tindakan utama — biru primary. Home, Profile, Notif, Search, Favorite.
  action,

  /// Highlight signature — gold accent. Scan QR, Hero badge, Achievement.
  featured,

  /// Status positif — hijau. Hadir, Verified, Submit OK.
  success,

  /// Caution / permission — amber. Izin, Sakit, Pending, Camera.
  warning,

  /// Destructive / alert — merah. Mock GPS, Alpa, Logout, Delete.
  danger,

  /// Utility / nav — slate. Settings, Calendar past, Filter, Chevron.
  neutral,
}

class SemanticIcon extends StatelessWidget {
  const SemanticIcon({
    super.key,
    required this.icon,
    this.variant = IconSemanticVariant.action,
    this.size = 22,
  });

  final IconData icon;
  final IconSemanticVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: _resolveColor(variant), size: size);
  }

  static Color _resolveColor(IconSemanticVariant v) => switch (v) {
        IconSemanticVariant.action => AppColors.primary,
        IconSemanticVariant.featured => AppColors.accent,
        IconSemanticVariant.success => AppColors.success,
        IconSemanticVariant.warning => AppColors.warning,
        IconSemanticVariant.danger => AppColors.danger,
        IconSemanticVariant.neutral => AppColors.textTertiary,
      };
}
