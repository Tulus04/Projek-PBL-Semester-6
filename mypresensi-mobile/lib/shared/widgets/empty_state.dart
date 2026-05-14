// lib/shared/widgets/empty_state.dart
// Reusable widget untuk halaman/list yang kosong.
// WAJIB pakai pesan ramah Bahasa Indonesia + ada CTA / penjelasan langkah lanjut.
//
// Tidak boleh sekedar tulis "Tidak ada data" — user harus tahu kenapa kosong
// dan apa yang bisa dilakukan selanjutnya.

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  /// Icon yang ditampilkan di tengah, boleh override.
  final IconData icon;

  /// Judul singkat — apa yang kosong.
  final String title;

  /// Penjelasan kenapa kosong + apa langkah lanjut user.
  final String description;

  /// Opsional CTA button (mis. "Buat Pengajuan", "Refresh").
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Padding luar; default 32px supaya tidak nempel ke layar.
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
