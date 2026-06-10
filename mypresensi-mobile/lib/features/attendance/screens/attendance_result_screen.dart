// lib/features/attendance/screens/attendance_result_screen.dart
// Halaman hasil presensi — ditampilkan setelah submit berhasil.
// Menampilkan: status, jarak, lokasi valid/tidak, waktu scan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../history/providers/history_provider.dart';
import '../providers/attendance_provider.dart';

class AttendanceResultScreen extends ConsumerWidget {
  const AttendanceResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitState = ref.watch(attendanceSubmitProvider);
    final response = submitState.response;

    // Guard: jika belum ada response, redirect ke home
    if (response == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isValid = response.isLocationValid;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // === Status Icon ===
              _buildStatusIcon(isValid),
              const SizedBox(height: 24),

              // === Status Title ===
              Text(
                isValid ? 'Presensi Berhasil!' : 'Presensi Tercatat',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          isValid ? AppColors.success : AppColors.warning,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // === Message ===
              Text(
                response.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // === Detail Card ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Mata Kuliah & Topik
                    if (response.courseName != null) ...[
                      _buildDetailRow(
                        context,
                        icon: Icons.book_outlined,
                        label: 'Mata Kuliah',
                        value: response.courseName!,
                      ),
                      const Divider(height: 24),
                    ],
                    if (response.sessionNumber != null) ...[
                      _buildDetailRow(
                        context,
                        icon: Icons.tag_outlined,
                        label: 'Pertemuan',
                        value: 'Ke-${response.sessionNumber}',
                      ),
                      const Divider(height: 24),
                    ],
                    if (response.sessionTopic != null) ...[
                      _buildDetailRow(
                        context,
                        icon: Icons.topic_outlined,
                        label: 'Topik',
                        value: response.sessionTopic!,
                      ),
                      const Divider(height: 24),
                    ],

                    // Session name (Legacy, tetap dibiarkan untuk fallback)
                    if (submitState.sessionName != null && response.courseName == null) ...[
                      _buildDetailRow(
                        context,
                        icon: Icons.class_outlined,
                        label: 'Sesi',
                        value: submitState.sessionName!,
                      ),
                      const Divider(height: 24),
                    ],

                    // Status — handle 'hadir' vs 'terlambat' dengan warna berbeda
                    _buildDetailRow(
                      context,
                      icon: response.status == 'terlambat'
                          ? Icons.schedule
                          : Icons.check_circle_outline,
                      label: 'Status',
                      value: response.status == 'hadir'
                          ? 'Hadir'
                          : response.status == 'terlambat'
                              ? 'Terlambat'
                              : response.status,
                      valueColor: response.status == 'terlambat'
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                    const Divider(height: 24),

                    // Jarak
                    _buildDetailRow(
                      context,
                      icon: Icons.straighten_outlined,
                      label: 'Jarak',
                      value: '${response.distanceMeters} meter',
                    ),
                    const Divider(height: 24),

                    // Lokasi valid?
                    _buildDetailRow(
                      context,
                      icon: isValid
                          ? Icons.location_on_outlined
                          : Icons.location_off_outlined,
                      label: 'Lokasi',
                      value: isValid ? 'Dalam radius' : 'Di luar radius',
                      valueColor:
                          isValid ? AppColors.success : AppColors.warning,
                    ),
                    const Divider(height: 24),

                    // Waktu scan
                    _buildDetailRow(
                      context,
                      icon: Icons.access_time,
                      label: 'Waktu',
                      value: _formatTime(response.scannedAt),
                    ),
                  ],
                ),
              ),

              // === Warning jika di luar radius ===
              if (!isValid) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Presensi Anda tercatat, namun lokasi di luar radius yang ditentukan. Dosen akan menerima notifikasi.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // === Buttons ===
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Invalidate provider cache supaya Beranda (Kalender)
                    // + tab Riwayat refetch data presensi terbaru dari server.
                    // Tanpa ini, Riverpod kadang serve cache pre-submit.
                    ref.invalidate(historyProvider);
                    context.go('/');
                  },
                  child: const Text('Kembali ke Beranda'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isValid) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: (isValid ? AppColors.success : AppColors.warning)
            .withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isValid ? Icons.check_circle : Icons.warning_rounded,
        size: 48,
        color: isValid ? AppColors.success : AppColors.warning,
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textTertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month/${dt.year} $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }
}
