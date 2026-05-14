// lib/features/profile/screens/profile_screen.dart
// Halaman profil mahasiswa — info akun + logout + hak hapus data wajah (UU PDP).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../face/providers/face_provider.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar + Nama
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      user?.initials ?? '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.fullName ?? '-',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.nimNip ?? '-',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (user != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.semesterKelasLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Info cards
          _buildSection(context, 'Informasi Akun', [
            _buildTile(context, Icons.badge_outlined, 'NIM', user?.nimNip ?? '-'),
            _buildTile(context, Icons.school_outlined, 'Semester', user?.semester?.toString() ?? '-'),
            _buildTile(context, Icons.class_outlined, 'Kelas', user?.kelas ?? '-'),
            _buildTile(
              context,
              Icons.face_outlined,
              'Verifikasi Wajah',
              user?.isFaceRegistered == true ? 'Terdaftar' : 'Belum terdaftar',
              valueColor: user?.isFaceRegistered == true
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ]),

          const SizedBox(height: 12),

          // Face registration button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await context.push<bool>('/face-register');
                if (result == true) {
                  // Update flag lokal — JANGAN invalidate authProvider
                  // karena akan menyebabkan flash loading/splash
                  ref.read(authProvider.notifier).markFaceRegistered();
                }
              },
              icon: Icon(
                user?.isFaceRegistered == true
                    ? Icons.face_retouching_natural
                    : Icons.face_outlined,
                size: 20,
              ),
              label: Text(
                user?.isFaceRegistered == true
                    ? 'Perbarui Data Wajah'
                    : 'Daftarkan Wajah',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: user?.isFaceRegistered == true
                    ? AppColors.surface
                    : AppColors.primary,
                foregroundColor: user?.isFaceRegistered == true
                    ? AppColors.textPrimary
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: user?.isFaceRegistered == true
                      ? const BorderSide(color: AppColors.border)
                      : BorderSide.none,
                ),
              ),
            ),
          ),

          // Tombol hapus data wajah — hanya muncul kalau sudah register
          // (UU PDP Pasal 5-15: hak hapus data pribadi sensitif)
          if (user?.isFaceRegistered == true) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDeleteFaceData(context, ref),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Hapus Data Wajah'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Pengajuan Izin/Sakit
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/leave-requests'),
              icon: const Icon(Icons.event_note_outlined, size: 20),
              label: const Text('Pengajuan Izin / Sakit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // App info
          _buildSection(context, 'Aplikasi', [
            _buildTile(context, Icons.info_outline, 'Versi', 'v1.0.0'),
          ]),

          const SizedBox(height: 24),

          // Logout button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Keluar'),
                    content: const Text('Yakin ingin keluar dari akun?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                        ),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authProvider.notifier).logout();
                }
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
              label: const Text(
                'Keluar dari Akun',
                style: TextStyle(color: AppColors.danger),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  /// Dialog konfirmasi 2-step untuk hapus data wajah (UU PDP Pasal 5-15).
  /// Step 1: Penjelasan konsekuensi.
  /// Step 2: Konfirmasi final dengan tombol destruktif.
  Future<void> _confirmDeleteFaceData(BuildContext context, WidgetRef ref) async {
    // Step 1 — Edukasi konsekuensi
    final step1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Hapus Data Wajah?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda akan menghapus data wajah biometrik yang tersimpan.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Konsekuensi:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text('• Anda tidak bisa presensi di sesi yang membutuhkan verifikasi wajah.', style: TextStyle(fontSize: 13)),
            SizedBox(height: 4),
            Text('• Anda harus daftar ulang jika ingin pakai verifikasi wajah lagi.', style: TextStyle(fontSize: 13)),
            SizedBox(height: 4),
            Text('• Tindakan ini tidak bisa dibatalkan.', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjut', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (step1 != true || !context.mounted) return;

    // Step 2 — Konfirmasi final destruktif
    final step2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Yakin hapus permanen?'),
        content: const Text(
          'Data wajah Anda akan dihapus dari server. Aksi ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Hapus Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (step2 != true || !context.mounted) return;

    // Eksekusi delete
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(faceDeletionProvider.notifier).deleteMyFaceData();

    if (!context.mounted) return;

    if (success) {
      // Update auth flag lokal supaya UI Profile refresh tanpa full reload
      ref.read(authProvider.notifier).markFaceUnregistered();
      ref.read(faceDeletionProvider.notifier).reset();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Data wajah berhasil dihapus.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final err = ref.read(faceDeletionProvider).errorMessage ?? 'Gagal menghapus data wajah.';
      ref.read(faceDeletionProvider.notifier).reset();

      messenger.showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
