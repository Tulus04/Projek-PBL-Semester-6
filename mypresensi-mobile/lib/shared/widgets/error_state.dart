// lib/shared/widgets/error_state.dart
// Reusable widget untuk error state — tampilkan icon error + pesan ramah +
// tombol Coba Lagi opsional.
//
// JANGAN tampilkan stack trace ke user. Pesan harus Indonesia, ramah,
// dan kalau memungkinkan kasih hint kenapa error (mis. "Periksa koneksi internet").

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ErrorState extends StatelessWidget {
  /// Icon dasar — default broken cloud.
  final IconData icon;

  /// Judul singkat (mis. "Gagal memuat data").
  final String title;

  /// Pesan ramah Indonesia, sudah dipetakan dari `friendlyErrorMessage`.
  final String message;

  /// Callback Coba Lagi — boleh null kalau retry tidak relevan.
  final VoidCallback? onRetry;

  /// Padding luar; default 32px.
  final EdgeInsetsGeometry padding;

  const ErrorState({
    super.key,
    this.icon = Icons.cloud_off_outlined,
    this.title = 'Terjadi kesalahan',
    required this.message,
    this.onRetry,
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
              decoration: const BoxDecoration(
                color: AppColors.dangerSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.danger),
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
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba Lagi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
