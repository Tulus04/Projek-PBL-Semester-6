import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

/// App bar transparan khusus layar wajah (menimpa kamera feed).
class FaceAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onInfo;
  final Widget? trailing;

  const FaceAppBar({
    super.key,
    required this.title,
    required this.onBack,
    this.onInfo,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      // Gradasi tipis agar appbar tetap terbaca meski background kamera terang
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.black54, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          _buildIconButton(IconsaxPlusBold.arrow_left, onBack),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ),
          if (trailing != null) trailing!
          else if (onInfo != null)
            _buildIconButton(IconsaxPlusBold.info_circle, onInfo!),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// CustomPainter untuk menggambar area gelap menutupi layar dengan lubang
/// oval transparan di tengah, serta garis progres di sekitar oval.
class FaceOvalPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color progressColor;
  final bool isVerifying; // Jika true, progress bar mungkin dibuat putus-putus atau animasi
  final bool isProcessing;
  final double spinAnimation;

  FaceOvalPainter({
    required this.progress,
    required this.progressColor,
    this.isVerifying = false,
    this.isProcessing = false,
    this.spinAnimation = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Gambar latar belakang gelap dengan lubang oval (menggunakan fillType evenOdd)
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.85);
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final center = Offset(size.width / 2, size.height / 2);
    // Ukuran standar oval wajah (sedikit lebih lebar & tinggi agar fit)
    final ovalWidth = size.width * 0.7; // ~280px di HP
    final ovalHeight = ovalWidth * 1.35; // Aspect ratio wajah

    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    bgPath.addOval(ovalRect);
    bgPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(bgPath, bgPaint);

    // 2. Gambar track dasar (garis abu abu)
    final trackPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawOval(ovalRect, trackPaint);

    // 3. Gambar garis progress atau animasi loading
    if (isProcessing) {
      final activePaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5.0;

      final startAngle = -math.pi / 2 + (spinAnimation * 2 * math.pi);
      final sweepAngle = 0.5 * math.pi; // 90 degrees length

      canvas.drawArc(ovalRect, startAngle, sweepAngle, false, activePaint);
    } else if (progress > 0) {
      final activePaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5.0;

      // Start dari atas (-pi / 2), arah clockwise
      final startAngle = -math.pi / 2;
      final sweepAngle = progress * 2 * math.pi;

      canvas.drawArc(ovalRect, startAngle, sweepAngle, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant FaceOvalPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.isVerifying != isVerifying ||
        oldDelegate.isProcessing != isProcessing ||
        oldDelegate.spinAnimation != spinAnimation;
  }
}

/// Widget pembungkus untuk seluruh layar wajah.
class FaceCameraOverlay extends StatefulWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onInfo;
  final Widget? trailingAppBar;
  
  final Widget cameraPreview;
  final double progress; // 0.0 to 1.0
  final Color progressColor;
  final String? progressLabel; // e.g. "Sampel 5 dari 7"
  
  final String? hintLabel; // e.g. "Tahan posisi"
  final String? hintSub; // e.g. "Sedang mengambil sampel wajah Anda"
  
  // Jika ini verifikasi, kita ganti progress indicator menjadi status success/verifying.
  final bool isVerifying;
  final bool isProcessing;

  const FaceCameraOverlay({
    super.key,
    required this.title,
    required this.onBack,
    this.onInfo,
    this.trailingAppBar,
    required this.cameraPreview,
    required this.progress,
    required this.progressColor,
    this.progressLabel,
    this.hintLabel,
    this.hintSub,
    this.isVerifying = false,
    this.isProcessing = false,
  });

  @override
  State<FaceCameraOverlay> createState() => _FaceCameraOverlayState();
}

class _FaceCameraOverlayState extends State<FaceCameraOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isProcessing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(FaceCameraOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isProcessing && !oldWidget.isProcessing) {
      _controller.repeat();
    } else if (!widget.isProcessing && oldWidget.isProcessing) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Fullscreen Camera (pastikan aspect ratio terjaga)
        Positioned.fill(
          child: widget.cameraPreview,
        ),

        // 2. Dim Radial Overlay & Oval Cutout
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: FaceOvalPainter(
                  progress: widget.progress,
                  progressColor: widget.progressColor,
                  isVerifying: widget.isVerifying,
                  isProcessing: widget.isProcessing,
                  spinAnimation: _controller.value,
                ),
              );
            },
          ),
        ),

        // 3. SafeArea Top Elements (AppBar, Progress Label)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              FaceAppBar(
                title: widget.title,
                onBack: widget.onBack,
                onInfo: widget.onInfo,
                trailing: widget.trailingAppBar,
              ),
              if (widget.progressLabel != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    widget.progressLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              
              // Instruksi pindah ke atas agar lebih jelas dan tidak tertutup tombol
              if (widget.hintLabel != null) ...[
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isVerifying && widget.progress == 1.0 
                          ? IconsaxPlusBold.verify
                          : IconsaxPlusBold.scan_barcode, 
                        color: widget.progressColor, 
                        size: 24
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.hintLabel!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // 4. Bottom Hint (hintSub)
        if (widget.hintSub != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 120, // Beri jarak dari tombol / navigasi bawah
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.hintSub!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
