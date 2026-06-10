import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../data/leave_models.dart';

class LeaveRequestDetailScreen extends StatelessWidget {
  final LeaveRequestItem item;

  const LeaveRequestDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Detail Pengajuan',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusBanner(),
              const SizedBox(height: 24),
              _buildSectionHeader('INFO SESI'),
              _buildSessionInfo(),
              const SizedBox(height: 24),
              _buildSectionHeader('ALASAN'),
              _buildReasonBox(),
              if (item.reviewNote != null && item.reviewNote!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('CATATAN DOSEN'),
                _buildReviewNoteBox(),
              ],
              if (item.evidenceUrl != null && item.evidenceUrl!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('LAMPIRAN'),
                _buildEvidence(context),
              ],
              const SizedBox(height: 40),
              _buildTimeline(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final (bg, fg, iconData, statusText) = switch (item.status) {
      LeaveStatus.pending => (
          AppColors.warningTint,
          AppColors.warning,
          IconsaxPlusBold.clock,
          'Menunggu Review',
        ),
      LeaveStatus.approved => (
          AppColors.successTint,
          AppColors.success,
          IconsaxPlusBold.tick_circle,
          'Disetujui',
        ),
      LeaveStatus.rejected => (
          AppColors.dangerTint,
          AppColors.danger,
          IconsaxPlusBold.close_circle,
          'Ditolak',
        ),
      LeaveStatus.unknown => (
          AppColors.surfaceSunken,
          AppColors.textTertiary,
          IconsaxPlusBold.minus_cirlce,
          'Status Tidak Diketahui',
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(iconData, size: 40, color: fg),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: fg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Diajukan ${item.timeAgo}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSessionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.session?.courseName ?? '(Sesi tidak ditemukan)',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.session?.courseCode ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.type.label.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          Row(
            children: [
              const Icon(IconsaxPlusBold.calendar_1, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Text(
                item.session != null
                    ? 'Pertemuan ${item.session!.sessionNumber}'
                    : 'Tidak ada data pertemuan',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (item.session?.topic != null && item.session!.topic!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(IconsaxPlusBold.book, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.session!.topic!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReasonBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Text(
        item.reason.isNotEmpty ? item.reason : '(Tidak ada deskripsi alasan)',
        style: const TextStyle(
          fontSize: 14.5,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildReviewNoteBox() {
    final bgColor = item.status == LeaveStatus.approved 
        ? AppColors.successTint 
        : AppColors.dangerTint;
    final fgColor = item.status == LeaveStatus.approved 
        ? AppColors.success 
        : AppColors.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bgColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(IconsaxPlusBold.message_text, size: 20, color: fgColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.reviewNote!,
              style: TextStyle(
                fontSize: 14,
                color: fgColor,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidence(BuildContext context) {
    // If we have an evidenceUrl, we assume it's a full signed URL or path.
    // For MVP, we use Image.network
    return GestureDetector(
      onTap: () {
        _showFullScreenImage(context, item.evidenceUrl!);
      },
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.surfaceSunken,
          image: DecorationImage(
            image: NetworkImage(item.evidenceUrl!),
            fit: BoxFit.cover,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(IconsaxPlusBold.maximize_circle, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Perbesar',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) {
        return Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  },
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Material(
                color: Colors.white.withValues(alpha: 0.2),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y $hh:$mm';
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineItem(
          icon: IconsaxPlusBold.send_1,
          title: 'Pengajuan Dikirim',
          subtitle: item.timeAgo,
          isLast: item.status == LeaveStatus.pending,
        ),
        if (item.status != LeaveStatus.pending)
          _buildTimelineItem(
            icon: item.status == LeaveStatus.approved
                ? IconsaxPlusBold.tick_circle
                : IconsaxPlusBold.close_circle,
            title: item.status == LeaveStatus.approved ? 'Disetujui Dosen' : 'Ditolak Dosen',
            subtitle: item.reviewedAt != null 
                ? 'Direview pada ${_formatDateTime(item.reviewedAt!)}'
                : 'Selesai direview',
            isLast: true,
          ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
