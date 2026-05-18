// lib/features/attendance/screens/scan_qr_screen.dart
// Halaman scanner QR code — full-screen kamera dengan overlay frame.
// Setelah scan berhasil, auto-submit presensi (GPS + API call).
// Menampilkan loading overlay saat proses submit berlangsung.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../face/data/face_config_models.dart';
import '../../face/data/face_models.dart';
import '../../face/providers/face_provider.dart';
import '../data/attendance_models.dart';
import '../providers/attendance_provider.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Reset submit state saat masuk scanner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceSubmitProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // Parse QR code
    final qrData = ref.read(attendanceSubmitProvider.notifier).parseQrCode(rawValue);
    if (qrData == null) {
      _showError('QR code tidak valid. Pastikan Anda memindai QR presensi yang benar.');
      return;
    }

    // Cegah double-scan
    setState(() => _isProcessing = true);

    // Auto-submit
    _processSubmit(qrData);
  }

  Future<void> _processSubmit(QrCodeData qrData) async {
    // === Pre-flight: cek face_verification_mode ===
    // Phase 2 v7 (17 Mei 2026): kalau mode 'required', mahasiswa harus:
    //   1. Sudah daftar wajah (is_face_registered = true), kalau belum → dialog redirect
    //   2. Verify wajah dulu via /face-verify, hasilnya dikirim ke server saat submit
    // Kalau mode 'optional' (legacy), submit langsung tanpa face verify.
    FaceVerificationResult? faceResult;

    try {
      final faceConfig = await ref.read(faceConfigProvider.future);

      if (faceConfig.verificationMode == FaceVerificationMode.required) {
        // Cek apakah user sudah register wajah
        final isFaceRegistered =
            ref.read(authProvider).user?.isFaceRegistered ?? false;

        if (!isFaceRegistered) {
          if (!mounted) return;
          await _showFaceNotRegisteredDialog();
          setState(() => _isProcessing = false);
          return;
        }

        // Push face verification screen, tunggu result
        if (!mounted) return;
        final result =
            await context.push<FaceVerificationResult?>('/face-verify');

        if (!mounted) return;

        if (result == null) {
          // User cancel atau timeout 15s — izinkan scan ulang
          _showError(
            'Verifikasi wajah gagal atau dibatalkan. Coba lagi dengan pencahayaan yang lebih baik.',
          );
          setState(() => _isProcessing = false);
          return;
        }

        faceResult = result;
      }
    } catch (e) {
      // Network error fetch config — fallback: lanjut submit, server akan gate kalau perlu
      debugPrint('[SCAN QR] Face config fetch error: $e');
    }

    if (!mounted) return;

    // === Submit ke server ===
    final success = await ref
        .read(attendanceSubmitProvider.notifier)
        .submitFromQr(qrData, faceResult: faceResult);

    if (!mounted) return;

    if (success) {
      // Navigate ke result screen
      context.push('/attendance-result');
      return;
    }

    // === Handle error — cek error_code untuk routing dialog yang sesuai ===
    final submitState = ref.read(attendanceSubmitProvider);
    final errCode = submitState.errorCode;
    final errMsg = submitState.errorMessage ?? 'Gagal submit presensi.';

    if (errCode == 'face_not_registered') {
      // Defense in depth: server reject walau pre-flight pass (race condition / cache stale)
      await _showFaceNotRegisteredDialog();
    } else if (errCode == 'face_mismatch') {
      await _showFaceMismatchDialog(errMsg);
    } else {
      _showError(errMsg);
    }

    setState(() => _isProcessing = false);
  }

  /// Dialog: wajah belum terdaftar — ajak ke face registration screen.
  Future<void> _showFaceNotRegisteredDialog() async {
    if (!mounted) return;
    final shouldRegister = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.face_retouching_off, color: AppColors.primary, size: 40),
        title: const Text(
          'Wajah Belum Didaftarkan',
          style: TextStyle(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Sebelum melakukan presensi, Anda perlu mendaftarkan wajah terlebih dahulu. Proses ini hanya perlu dilakukan sekali.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Nanti Saja',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Daftar Sekarang'),
          ),
        ],
      ),
    );

    if (shouldRegister == true && mounted) {
      context.push('/face-register');
    }
  }

  /// Dialog: wajah tidak cocok — minta retry.
  Future<void> _showFaceMismatchDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.face_unlock_outlined, color: AppColors.warning, size: 40),
        title: const Text(
          'Wajah Tidak Cocok',
          style: TextStyle(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(attendanceSubmitProvider);
    final isLoading = submitState.status == SubmitStatus.gettingLocation ||
        submitState.status == SubmitStatus.submitting;

    return Scaffold(
      body: Stack(
        children: [
          // === Camera ===
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // === Overlay ===
          _buildScanOverlay(context),

          // === Top Bar ===
          _buildTopBar(context),

          // === Bottom Instructions ===
          _buildBottomPanel(context, submitState),

          // === Loading overlay ===
          if (isLoading) _buildLoadingOverlay(submitState),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              Material(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
              ),
              // Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Scan QR Presensi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Torch toggle
              ValueListenableBuilder(
                valueListenable: _scannerController,
                builder: (context, state, _) {
                  final torchState = state.torchState;
                  return Material(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _scannerController.toggleTorch(),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          torchState == TorchState.on
                              ? Icons.flash_on
                              : Icons.flash_off,
                          color: torchState == TorchState.on
                              ? AppColors.warning
                              : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        final top = (constraints.maxHeight - scanAreaSize) / 2 - 40;

        return Stack(
          children: [
            // Semi-transparent overlay di seluruh layar
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.5),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                      ),
                    ),
                    // Lubang transparan di tengah
                    Positioned(
                      top: top,
                      left: (constraints.maxWidth - scanAreaSize) / 2,
                      child: Container(
                        width: scanAreaSize,
                        height: scanAreaSize,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Corner borders
            Positioned(
              top: top,
              left: (constraints.maxWidth - scanAreaSize) / 2,
              child: SizedBox(
                width: scanAreaSize,
                height: scanAreaSize,
                child: CustomPaint(
                  painter: _CornerBorderPainter(
                    color: AppColors.primary,
                    strokeWidth: 3,
                    cornerLength: 28,
                    borderRadius: 20,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomPanel(BuildContext context, AttendanceSubmitState state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_2,
                size: 32,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              const Text(
                'Arahkan kamera ke QR Code',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'QR code ditampilkan oleh dosen di layar kelas',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(AttendanceSubmitState state) {
    final isGps = state.status == SubmitStatus.gettingLocation;
    final label = isGps ? 'Mengambil lokasi GPS...' : 'Mengirim presensi...';
    final icon = isGps ? Icons.location_searching : Icons.cloud_upload;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Mohon tunggu sebentar...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter untuk sudut-sudut frame scanner
class _CornerBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double borderRadius;

  _CornerBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final l = cornerLength;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(l, 0),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(w - l, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, l),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, h - l)
        ..lineTo(0, h - r)
        ..quadraticBezierTo(0, h, r, h)
        ..lineTo(l, h),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(w - l, h)
        ..lineTo(w - r, h)
        ..quadraticBezierTo(w, h, w, h - r)
        ..lineTo(w, h - l),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
