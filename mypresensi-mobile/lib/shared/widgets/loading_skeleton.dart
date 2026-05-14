// lib/shared/widgets/loading_skeleton.dart
// Skeleton placeholder dengan animasi pulse halus — pengganti CircularProgressIndicator
// untuk loading state yang lebih informatif.
//
// Tidak pakai library `shimmer` agar APK tetap ramping. Implementasi manual via
// `AnimatedBuilder` + `Color.lerp` sudah cukup untuk visual placeholder.
//
// Pakai langsung sebagai box placeholder, atau gabungkan beberapa untuk replicate
// shape kartu/list-item asli.

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Skeleton box dengan animasi pulse 1.2 detik loop.
class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  /// Skeleton bulat untuk avatar.
  const LoadingSkeleton.circle({
    super.key,
    double size = 40,
  })  : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final color = Color.lerp(
          AppColors.surfaceVariant,
          AppColors.border,
          t,
        );
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

/// Helper layout — kartu skeleton untuk list-item presensi/notifikasi/leave.
/// Tampilan: avatar bulat di kiri + 2 baris teks di kanan.
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const LoadingSkeleton.circle(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LoadingSkeleton(height: 14, width: 180),
                const SizedBox(height: 8),
                LoadingSkeleton(height: 12, width: 120, borderRadius: BorderRadius.circular(6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// List of N skeleton cards — convenience builder untuk loading state.
class ListLoadingPlaceholder extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const ListLoadingPlaceholder({
    super.key,
    this.itemCount = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const ListItemSkeleton(),
    );
  }
}
