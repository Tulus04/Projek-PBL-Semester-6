// lib/features/attendance/services/qr_decoder_service.dart
// Service untuk DECODE QR code dari frame `package:camera` via ML Kit
// Barcode Scanning. Lahir dari spec `qr-scan-unify-camera-plugin` (BUG-019)
// untuk menyatukan kamera ke 1 plugin Flutter (`package:camera`) — drop
// `mobile_scanner` supaya Camera2 HAL OEM (ColorOS RMX5000, MIUI, FunTouch,
// OneUI) tidak gagal release/re-acquire setelah lifecycle handoff ke
// face flow.
//
// API service ini di-mirror dari `face_detection_service.dart` agar
// integrasi di `ScanQrScreen._onCameraFrame` simetris dengan flow face:
//   1. `initialize()` — construct ML Kit scanner singleton (QR-only).
//   2. `decodeFromCameraImage(image, camera)` — throttle + re-entrance guard
//      + konversi `CameraImage → InputImage` (NV21 / YUV420 / BGRA8888) +
//      run inference. Return raw QR string atau null kalau tidak ada
//      barcode terdeteksi / frame skipped karena throttle.
//   3. `dispose()` — close native scanner.
//
// CATATAN KEAMANAN (rule 04 §B + rule 02 §A.6):
//   • JANGAN log raw QR string (`rawValue`) ke `debugPrint` — payload bisa
//     berisi `session_code` 6-digit OTP yang Tier 1 sensitif (rule 04 §C).
//   • JANGAN simpan history frame / image bytes — service murni stateless
//     selain throttle counter & re-entrance flag.
//   • Hanya log error path (konversi gagal, ML Kit exception) tanpa
//     menyertakan content QR.

import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Service untuk decode QR dari `CameraImage` stream — ML Kit Barcode
/// Scanning, format dibatasi ke `BarcodeFormat.qrCode`.
///
/// Throttle 200ms + re-entrance guard mencegah saturasi CPU saat camera
/// mengeluarkan ≥ 5 fps. Aman dipanggil dari `startImageStream` callback
/// secara langsung — kalau busy / frame masih dalam window throttle,
/// service return `null` tanpa block.
class QrDecoderService {
  BarcodeScanner? _barcodeScanner;
  bool _isProcessing = false;
  int _lastDecodeMs = 0;

  /// Throttle minimal antar decode (ms). 200ms ≈ 5 decode/detik —
  /// cukup untuk QR static, jauh di bawah frame rate kamera.
  static const int _throttleMs = 200;

  /// Inisialisasi ML Kit scanner singleton dengan format QR-only.
  ///
  /// Idempotent — kalau sudah ada instance, biarkan apa adanya supaya
  /// re-init dari `didChangeAppLifecycleState` tidak leak native handle.
  void initialize() {
    if (_barcodeScanner != null) return;
    _barcodeScanner = BarcodeScanner(formats: const [BarcodeFormat.qrCode]);
    debugPrint('[QR DECODE] ML Kit BarcodeScanner initialized (QR-only)');
  }

  /// Process satu frame kamera — return raw QR string kalau ada barcode
  /// terdeteksi & punya `rawValue` non-null, else `null`.
  ///
  /// Skip cepat (return `null` segera) bila:
  ///   • Sebelumnya masih `_isProcessing` (re-entrance guard).
  ///   • `_barcodeScanner` belum di-`initialize()`.
  ///   • Frame masih di dalam window throttle 200ms.
  ///   • Konversi `CameraImage → InputImage` gagal (rotation / format
  ///     tidak didukung).
  ///
  /// Kontrak return string mirror output `mobile_scanner` lama supaya
  /// `attendanceSubmitProvider.parseQrCode(...)` tetap menerima format
  /// JSON `{"session_id":"...","code":"..."}` yang sama (preservation
  /// guarantee Property 2).
  Future<String?> decodeFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isProcessing || _barcodeScanner == null) {
      return null;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastDecodeMs < _throttleMs) {
      return null;
    }

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image, camera);
      if (inputImage == null) {
        return null;
      }

      final barcodes = await _barcodeScanner!.processImage(inputImage);

      if (barcodes.isEmpty) {
        return null;
      }

      final raw = barcodes.first.rawValue;
      if (raw == null) {
        return null;
      }

      // SECURITY: jangan log `raw` — bisa berisi OTP 6-digit (Tier 1).
      return raw;
    } catch (e) {
      // Log error tanpa konten QR.
      debugPrint('[QR DECODE] Process error: $e');
      return null;
    } finally {
      _lastDecodeMs = DateTime.now().millisecondsSinceEpoch;
      _isProcessing = false;
    }
  }

  // ============================================================
  // CameraImage → InputImage konversi
  // (mirror pattern face_detection_service.dart — duplikasi inline OK
  //  per task 3.2 spec, agar kedua service decoupled satu sama lain)
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
      debugPrint('[QR DECODE] Convert error: $e');
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

  /// Tutup ML Kit scanner & lepas native resource.
  Future<void> dispose() async {
    await _barcodeScanner?.close();
    _barcodeScanner = null;
    _isProcessing = false;
    _lastDecodeMs = 0;
    debugPrint('[QR DECODE] Disposed');
  }
}
