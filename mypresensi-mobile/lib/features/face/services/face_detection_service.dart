// lib/features/face/services/face_detection_service.dart
// Service untuk DETECTION wajah saja (bukan embedding extraction).
// Tugas: jalankan ML Kit FaceDetector di setiap frame, return info untuk:
// - Liveness check (eye blink, head turn)
// - Bounding box untuk crop di FaceEmbeddingService
// - Multiple face / no face detection
//
// Embedding extraction TIDAK lagi di sini — pindah ke
// `face_embedding_service.dart` yang pakai TFLite + MobileFaceNet.

import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'image_preprocessor.dart';

/// Hasil deteksi wajah dari satu frame kamera
class FaceDetectionResult {
  final bool faceDetected;
  final bool multipleFaces;
  final FaceBoundingBox? boundingBox;
  final double? leftEyeOpenProb;
  final double? rightEyeOpenProb;
  final double? headAngleY; // Yaw (kiri-kanan)
  final double? headAngleZ; // Roll
  final double? faceWidthRatio; // Rasio lebar wajah vs lebar frame (0.0-1.0)
  final double? faceCenterXRatio; // Rasio posisi X tengah wajah
  final double? faceCenterYRatio; // Rasio posisi Y tengah wajah
  final String? errorMessage;

  const FaceDetectionResult({
    this.faceDetected = false,
    this.multipleFaces = false,
    this.boundingBox,
    this.leftEyeOpenProb,
    this.rightEyeOpenProb,
    this.headAngleY,
    this.headAngleZ,
    this.faceWidthRatio,
    this.faceCenterXRatio,
    this.faceCenterYRatio,
    this.errorMessage,
  });
}

/// Liveness check state — instruksi ke user
enum LivenessStep {
  lookStraight,   // Step 1: Hadapkan wajah lurus ke kamera
  blinkEyes,      // Step 2: Kedipkan mata
  turnLeft,       // Step 3: Miringkan sedikit kepala ke kiri
  turnRight,      // Step 4: Miringkan sedikit kepala ke kanan
  completed,      // Semua step selesai
}

/// Service untuk face detection (ML Kit) — TANPA embedding extraction.
class FaceDetectionService {
  FaceDetector? _faceDetector;
  bool _isProcessing = false;

  /// Throttle: jeda minimal antar frame yang DIPROSES.
  /// Kamera stream ±30fps — memproses semua frame hanya membuang CPU
  /// (konversi planes per frame = alokasi besar → GC churn → jank).
  /// 150ms ≈ 6-7 deteksi/detik, lebih dari cukup untuk liveness + UX.
  static const Duration _minProcessInterval = Duration(milliseconds: 150);
  DateTime _lastProcessStart = DateTime.fromMillisecondsSinceEpoch(0);

  /// Menyimpan arah toleh saat turnLeft (positif/negatif)
  /// Digunakan untuk memastikan turnRight berlawanan arah
  double? _turnLeftDirection;

  /// Initialize ML Kit face detector
  void initialize() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,   // Eye open probability
        enableLandmarks: false,       // Tidak perlu — embedding via TFLite
        enableContours: false,        // Tidak perlu
        enableTracking: true,         // Track face across frames
        // `fast` adalah mode yang direkomendasikan Google untuk live camera
        // stream. Mode `accurate` sebelumnya terlalu lambat per-frame →
        // delay scan + mayoritas frame ter-skip.
        performanceMode: FaceDetectorMode.fast,
        // 0.15 = wajah minimal ~15% lebar frame. Nilai 0.3 sebelumnya
        // membuat wajah yang sudah masuk frame (tapi agak jauh dari kamera)
        // TIDAK terdeteksi sama sekali.
        minFaceSize: 0.15,
      ),
    );
    debugPrint('[FACE DETECT] ML Kit FaceDetector initialized (detection-only)');
  }

  /// Process satu frame kamera — return FaceDetectionResult dengan
  /// info bounding box, eye/head angles, dll.
  ///
  /// Return `null` jika frame DI-SKIP (detector sibuk / throttle interval
  /// belum lewat). Caller WAJIB mengabaikan hasil null — null BUKAN berarti
  /// "tidak ada wajah". Sebelumnya frame skip mengembalikan
  /// FaceDetectionResult kosong (faceDetected=false) yang diteruskan ke
  /// provider → terbaca sebagai "wajah hilang" → deteksi flicker.
  ///
  /// JANGAN dipakai untuk extract embedding — pakai
  /// `FaceEmbeddingService.extractEmbedding(...)` setelah kita dapat
  /// `boundingBox` dari result ini.
  Future<FaceDetectionResult?> processFrame(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isProcessing || _faceDetector == null) {
      return null;
    }

    final now = DateTime.now();
    if (now.difference(_lastProcessStart) < _minProcessInterval) {
      return null;
    }
    _lastProcessStart = now;

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image, camera);
      if (inputImage == null) {
        return const FaceDetectionResult(
          errorMessage: 'Gagal memproses frame kamera',
        );
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        return const FaceDetectionResult(faceDetected: false);
      }

      if (faces.length > 1) {
        return const FaceDetectionResult(
          faceDetected: true,
          multipleFaces: true,
          errorMessage: 'Terdeteksi lebih dari 1 wajah',
        );
      }

      final face = faces.first;
      final box = face.boundingBox;

      // Catatan: face.boundingBox dalam koordinat input image (image yang
      // sudah ML Kit rotate sesuai metadata). Kita pakai apa adanya.
      final boundingBox = FaceBoundingBox(
        left: box.left,
        top: box.top,
        width: box.width,
        height: box.height,
      );

      final rotation = _getInputImageRotation(camera);
      final isPortrait = rotation == InputImageRotation.rotation90deg || 
                         rotation == InputImageRotation.rotation270deg;
      
      final logicalWidth = isPortrait ? image.height.toDouble() : image.width.toDouble();
      final logicalHeight = isPortrait ? image.width.toDouble() : image.height.toDouble();

      final faceWidthRatio = box.width / logicalWidth;
      final faceCenterXRatio = (box.left + box.width / 2) / logicalWidth;
      final faceCenterYRatio = (box.top + box.height / 2) / logicalHeight;

      return FaceDetectionResult(
        faceDetected: true,
        boundingBox: boundingBox,
        leftEyeOpenProb: face.leftEyeOpenProbability,
        rightEyeOpenProb: face.rightEyeOpenProbability,
        headAngleY: face.headEulerAngleY,
        headAngleZ: face.headEulerAngleZ,
        faceWidthRatio: faceWidthRatio,
        faceCenterXRatio: faceCenterXRatio,
        faceCenterYRatio: faceCenterYRatio,
      );
    } catch (e) {
      debugPrint('[FACE DETECT] Process error: $e');
      return FaceDetectionResult(
        errorMessage: 'Error deteksi wajah: ${e.toString()}',
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Check liveness berdasarkan current step.
  ///
  /// CATATAN tentang `headEulerAngleY` di front camera:
  /// Arah angle bervariasi antar device dan versi ML Kit.
  /// Untuk menghindari masalah ini, turnLeft & turnRight cukup
  /// mengecek bahwa kepala SUDAH MENOLEH (`abs > threshold`),
  /// tanpa peduli arah positif/negatif. Keamanan dijamin karena
  /// kedua step harus dilewati berurutan dengan arah BERLAWANAN.
  ///
  /// Threshold sengaja relax untuk kurangi false-negative di kondisi nyata.
  /// Anti-spoof dijamin oleh kombinasi multi-step + GPS + OTP, BUKAN per-step ketat.
  bool checkLivenessStep(LivenessStep step, FaceDetectionResult result) {
    switch (step) {
      case LivenessStep.lookStraight:
        // Wajah menghadap lurus — head angle Y mendekati 0
        final yAngle = result.headAngleY?.abs() ?? 99;
        return yAngle < 15 && result.faceDetected;

      case LivenessStep.blinkEyes:
        // Mata tertutup (kedip) — threshold 0.4 lebih toleran
        final leftEye = result.leftEyeOpenProb ?? 1.0;
        final rightEye = result.rightEyeOpenProb ?? 1.0;
        return leftEye < 0.4 && rightEye < 0.4;

      case LivenessStep.turnLeft:
        // Cek kepala menoleh ke satu arah (abs > 12°)
        final yAngleL = result.headAngleY ?? 0;
        if (yAngleL.abs() > 12) {
          _turnLeftDirection = yAngleL; // Simpan arah toleh
          return true;
        }
        return false;

      case LivenessStep.turnRight:
        // Cek kepala menoleh ke arah BERLAWANAN dari turnLeft
        final yAngleR = result.headAngleY ?? 0;
        if (yAngleR.abs() > 12) {
          if (_turnLeftDirection != null) {
            return (yAngleR > 0) != (_turnLeftDirection! > 0);
          }
          return true;
        }
        return false;

      case LivenessStep.completed:
        _turnLeftDirection = null; // Reset
        return true;
    }
  }

  // ============================================================
  // CameraImage → InputImage konversi (untuk ML Kit detection)
  // ============================================================

  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final rotation = _getInputImageRotation(camera);
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('[FACE DETECT] Convert error: $e');
      return null;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    int totalBytes = 0;
    for (final plane in planes) {
      totalBytes += plane.bytes.length;
    }
    final allBytes = Uint8List(totalBytes);
    int offset = 0;
    for (final plane in planes) {
      allBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return allBytes;
  }

  InputImageRotation? _getInputImageRotation(CameraDescription camera) {
    switch (camera.sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
    debugPrint('[FACE DETECT] Disposed');
  }
}
