// lib/features/profile/screens/profile_screen.dart
// Halaman profil mahasiswa v7 — sesuai mockup mobile-profile.html (17 Mei 2026).
// Layout: avatar tap-able dengan camera badge → 3 group settings (Akun /
// Keamanan & Privasi / Aplikasi) → Logout danger row.
// Preserve flow existing: avatar upload, delete face data (UU PDP), navigasi
// ke /face-register, /change-password, /leave-requests, /ai-chat.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../auth/providers/auth_provider.dart';
import '../../face/providers/face_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final uploadState = ref.watch(avatarUploadProvider);
    final isUploading = uploadState.status == AvatarUploadStatus.uploading;
    final isFaceRegistered = user?.isFaceRegistered == true;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
        children: [
          // ===== Hero: avatar + nama + meta =====
          _ProfileHero(
            user: user,
            isUploading: isUploading,
            onTapAvatar: isUploading ? null : _showAvatarSourceSheet,
          ),
          const SizedBox(height: 16),

          // ===== Group: Akun =====
          _SettingsGroup(
            label: 'Akun',
            children: [
              _SettingsItem(
                icon: IconsaxPlusBold.sms,
                iconColor: AppColors.primary,
                iconBg: AppColors.primarySurface,
                title: 'Email Kampus',
                subtitle: user?.email ?? '-',
                onTap: () => _showInfoModal(
                  context,
                  title: 'Email Kampus',
                  message:
                      'Email institusi tidak bisa diubah sendiri. Hubungi BAAK Politani jika perlu update.',
                ),
              ),
              _SettingsItem(
                icon: IconsaxPlusBold.lock_1,
                iconColor: AppColors.info,
                iconBg: AppColors.infoTint,
                title: 'Ubah Kata Sandi',
                subtitle: 'Ganti kata sandi secara berkala',
                onTap: () => context.push('/change-password'),
              ),
            ],
          ),

          // ===== Group: Keamanan & Privasi =====
          _SettingsGroup(
            label: 'Keamanan & Privasi',
            children: [
              _SettingsItem(
                icon: IconsaxPlusBold.user_octagon,
                iconColor: isFaceRegistered ? AppColors.success : AppColors.warning,
                iconBg: isFaceRegistered ? AppColors.successTint : AppColors.warningTint,
                title: 'Data Wajah',
                subtitle: isFaceRegistered
                    ? 'Wajah sudah terdaftar'
                    : 'Belum terdaftar, tap untuk mendaftar',
                onTap: () async {
                  final result = await context.push<bool>('/face-register');
                  if (result == true) {
                    ref.read(authProvider.notifier).markFaceRegistered();
                  }
                },
              ),
              _SettingsItem(
                icon: IconsaxPlusBold.location,
                iconColor: AppColors.warning,
                iconBg: AppColors.accentSoft,
                title: 'Akses Lokasi',
                subtitle: 'Kelola izin GPS di pengaturan sistem',
                onTap: _showLocationPermissionSheet,
              ),
              if (isFaceRegistered)
                _SettingsItem(
                  icon: IconsaxPlusBold.shield_tick,
                  iconColor: AppColors.warning,
                  iconBg: AppColors.warningTint,
                  title: 'Hapus Data Wajah',
                  subtitle: 'Hak hapus data biometrik (UU PDP)',
                  onTap: () => _confirmDeleteFaceData(context, ref),
                ),
            ],
          ),

          // ===== Group: Aplikasi =====
          _SettingsGroup(
            label: 'Aplikasi',
            children: [
              _SettingsItem(
                icon: IconsaxPlusBold.message_question,
                iconColor: AppColors.primary,
                iconBg: AppColors.primarySurface,
                title: 'Asisten AI',
                subtitle: 'Tanya seputar presensi atau aplikasi',
                onTap: () => context.push('/ai-chat'),
              ),
              _SettingsItem(
                icon: IconsaxPlusBold.info_circle,
                iconColor: AppColors.info,
                iconBg: AppColors.infoTint,
                title: 'Tentang',
                subtitle: 'Versi aplikasi dan pengembang',
                onTap: _showAboutSheet,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ===== Logout danger row =====
          _SettingsGroup(
            label: null,
            children: [
              _SettingsItem(
                icon: IconsaxPlusBold.logout,
                iconColor: AppColors.danger,
                iconBg: AppColors.dangerTint,
                title: 'Keluar dari Akun',
                titleColor: AppColors.danger,
                subtitle: 'Akhiri sesi dan kembali ke login',
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Modal helpers =====

  /// Bottom sheet untuk Izin Lokasi — display status real + action buka system settings.
  /// Pakai permission_handler yang sudah ada di project (lihat face_registration_screen.dart).
  Future<void> _showLocationPermissionSheet() async {
    // Cek status izin lokasi saat ini
    final status = await Permission.locationWhenInUse.status;
    if (!mounted) return;

    final (label, description, color, isGranted) = switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited =>
        ('Aktif', 'Aplikasi bisa baca lokasi saat presensi.', AppColors.success, true),
      PermissionStatus.denied => (
        'Belum Diizinkan',
        'Aplikasi belum punya akses lokasi. Buka pengaturan untuk mengizinkan.',
        AppColors.warning,
        false,
      ),
      PermissionStatus.permanentlyDenied => (
        'Ditolak Permanen',
        'Izin lokasi ditolak secara permanen. Atur manual via pengaturan sistem.',
        AppColors.danger,
        false,
      ),
      PermissionStatus.restricted ||
      PermissionStatus.provisional ||
      _ => ('Tidak Diketahui', 'Status izin lokasi tidak terbaca.', AppColors.textSecondary, false),
    };

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(IconsaxPlusBold.location, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Izin Lokasi',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                if (!isGranted) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetCtx).pop();
                        await openAppSettings();
                      },
                      icon: const Icon(IconsaxPlusBold.setting_2, size: 18),
                      label: const Text(
                        'Buka Pengaturan',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// About sheet — versi aplikasi dynamic dari pubspec.yaml via package_info_plus.
  Future<void> _showAboutSheet() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;

    final versionLabel = 'v${info.version} · Build ${info.buildNumber}';
    _showInfoModal(
      context,
      title: 'Tentang MyPresensi',
      message:
          '$versionLabel\n\nSistem absensi mahasiswa Prodi TRPL — Politeknik Pertanian Negeri Samarinda.\n\nVerifikasi 3-layer: QR Code · GPS · Face Recognition.',
    );
  }

  void _showInfoModal(BuildContext context, {required String title, required String message}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Mengerti',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                IconsaxPlusBold.logout,
                color: AppColors.danger,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Keluar dari Akun?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Kamu akan diarahkan ke halaman login. Yakin?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Keluar',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  /// Dialog konfirmasi 2-step untuk hapus data wajah (UU PDP Pasal 5-15).
  /// Step 1: Penjelasan konsekuensi.
  /// Step 2: Konfirmasi final destruktif.
  Future<void> _confirmDeleteFaceData(BuildContext context, WidgetRef ref) async {
    // Step 1 — Edukasi konsekuensi
    final step1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(IconsaxPlusBold.warning_2, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Hapus Data Wajah?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kamu akan menghapus data wajah biometrik yang tersimpan.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              'Konsekuensi:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text('• Tidak bisa presensi di sesi yang membutuhkan verifikasi wajah.', style: TextStyle(fontSize: 13)),
            SizedBox(height: 4),
            Text('• Harus daftar ulang jika ingin pakai verifikasi wajah lagi.', style: TextStyle(fontSize: 13)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Yakin hapus permanen?'),
        content: const Text(
          'Data wajah kamu akan dihapus dari server. Aksi ini tidak bisa dibatalkan.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(IconsaxPlusBold.trash, size: 18),
            label: const Text('Hapus Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
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

  // ===== Avatar upload handlers =====

  void _showAvatarSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(IconsaxPlusBold.gallery, color: AppColors.primary),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(IconsaxPlusBold.camera, color: AppColors.primary),
                title: const Text('Ambil Foto'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka galeri: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (picked == null) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(avatarUploadProvider.notifier);

    final success = await notifier.upload(File(picked.path));

    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui.'),
          backgroundColor: AppColors.success,
        ),
      );
      notifier.reset();
    } else {
      final err = ref.read(avatarUploadProvider).errorMessage ?? 'Gagal mengunggah foto.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.danger,
        ),
      );
      notifier.reset();
    }
  }
}

// ============================================================================
// Sub-widgets
// ============================================================================

/// Hero profile — avatar 88×88 + gold glow + camera badge tap-able + meta info.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.isUploading,
    required this.onTapAvatar,
  });

  final dynamic user; // UserModel
  final bool isUploading;
  final VoidCallback? onTapAvatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          // Avatar wrap dengan gold glow + camera badge
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Gold radial glow (signature)
                Positioned(
                  top: -6,
                  left: -6,
                  child: IgnorePointer(
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [AppColors.accentSoft, Color(0x00F4B400)],
                          stops: [0.0, 0.65],
                        ),
                      ),
                    ),
                  ),
                ),
                // Avatar
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: onTapAvatar,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: user?.avatarUrl == null
                            ? AppColors.primaryGradient
                            : null,
                        color: user?.avatarUrl != null ? AppColors.surface : null,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x402D86FF),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: user?.avatarUrl != null
                          ? Image.network(
                              user!.avatarUrl!,
                              fit: BoxFit.cover,
                              width: 88,
                              height: 88,
                              errorBuilder: (_, _, _) => _buildInitialsAvatar(user),
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return _buildInitialsAvatar(user);
                              },
                            )
                          : _buildInitialsAvatar(user),
                    ),
                  ),
                ),
                // Camera badge (tap-able edit)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onTapAvatar,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x592D86FF),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              IconsaxPlusBold.camera,
                              size: 14,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Nama
          Text(
            user?.fullName ?? '-',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            user?.nimNip ?? '-',
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (user != null) ...[
            const SizedBox(height: 4),
            Text(
              user.semesterKelasLabel ?? '-',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(dynamic user) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          user?.initials ?? '?',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
      ),
    );
  }
}

/// Group container untuk settings items — label uppercase + list items.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.label,
    required this.children,
  });

  /// Null = no label (dipakai untuk Logout standalone).
  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text(
                label!.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          ...children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: child,
              )),
        ],
      ),
    );
  }
}

/// Settings item — duotone icon + title + subtitle + trailing (chevron/toggle).
/// `trailing` saat ini tidak dipakai (toggle dummy dihapus di v7+) tapi disimpan
/// untuk forward compatibility — toggle/badge custom future-use.
class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    // ignore: unused_element_parameter
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              // Duotone icon box
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: titleColor ?? AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Trailing
              const SizedBox(width: 8),
              trailing ??
                  const Icon(
                    IconsaxPlusBold.arrow_right_3,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle switch sederhana — visual only (state dikelola caller).
/// CATATAN: tidak dipakai di profile screen v7+ (toggle dummy "Izin Lokasi"
/// diganti jadi action sheet real-status). Disimpan dulu untuk pemakaian
/// future kalau ada toggle preference yang real (mis. dark mode, notif).
@Deprecated('Reserved untuk future use case. Kalau ada toggle baru, pakai widget ini dengan parameter onChanged.')
// ignore: unused_element
class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 28,
      decoration: BoxDecoration(
        color: value ? AppColors.primary : AppColors.borderStrong,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: 3,
            left: value ? 23 : 3,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
