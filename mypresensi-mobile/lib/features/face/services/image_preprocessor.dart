// lib/features/face/services/image_preprocessor.dart
// Helper konversi CameraImage (NV21/YUV420) → input tensor 112x112x3 float32
// dengan normalisasi `[-1, 1]` untuk MobileFaceNet.
//
// Catatan teknis:
// - Stream kamera Android default: `nv21` atau `yuv420` (lihat
//   `imageFormatGroup` saat init CameraController).
// - Front camera mengembalikan frame yang TER-MIRROR — biasanya OK karena
//   face_detection ML Kit pakai sumber yang sama, tapi untuk visual
//   crop, kita ikuti orientasi yang sama dengan ML Kit.
// - Bounding box dari ML Kit (`Face.boundingBox`) berada dalam koordinat
//   image RAW (sebelum rotasi). Kita rotate-aware crop di sini.

import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  ImagePreprocessor._();

  /// Convert + crop + resize + normalize.
  ///
  /// Return tensor `Float32List` shape `[1*112*112*3]` (flat HWC),
  /// nilai di-normalize ke range `[-1.0, 1.0]` (`(p - 127.5) / 128.0`).
  ///
  /// [cameraImage] — frame dari `controller.startImageStream`.
  /// [boundingBox] — `Face.boundingBox` dari ML Kit (Rect dalam koordinat image
  ///   yang sudah di-rotasi sesuai sensorOrientation).
  /// [sensorOrientation] — `camera.sensorOrientation` (0/90/180/270).
  /// [isFrontCamera] — true kalau front camera (perlu mirror horizontal).
  ///
  /// Throws [Exception] jika konversi gagal.
  static Float32List preprocessForMobileFaceNet({
    required CameraImage cameraImage,
    required FaceBoundingBox boundingBox,
    required int sensorOrientation,
    required bool isFrontCamera,
  }) {
    // 1. CameraImage → img.Image RGB
    final rgbImage = _cameraImageToRgb(cameraImage);

    // 2. Rotate sesuai sensor orientation
    final rotated = _rotate(rgbImage, sensorOrientation);

    // 3. Mirror jika front camera
    final oriented = isFrontCamera ? img.flipHorizontal(rotated) : rotated;

    // 4. Crop sesuai bounding box dengan padding 20%
    final cropped = _cropFace(oriented, boundingBox);

    // 5. Resize ke 112x112
    final resized = img.copyResize(
      cropped,
      width: 112,
      height: 112,
      interpolation: img.Interpolation.linear,
    );

    // 6. Convert ke Float32List dengan normalisasi (-1..1)
    return _imageToFloat32(resized);
  }

  // ============================================================
  // STEP 1: CameraImage → img.Image RGB
  // ============================================================

  static img.Image _cameraImageToRgb(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        return _yuv420ToRgb(image);
      case ImageFormatGroup.nv21:
        return _nv21ToRgb(image);
      case ImageFormatGroup.bgra8888:
        return _bgra8888ToRgb(image);
      default:
        throw Exception(
          'Format kamera ${image.format.group} tidak didukung. '
          'Pakai ImageFormatGroup.nv21 atau .yuv420.',
        );
    }
  }

  /// YUV420 (3 plane terpisah) → RGB
  static img.Image _yuv420ToRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final out = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;

        final yp = yPlane.bytes[yIndex];
        final up = uPlane.bytes[uvIndex];
        final vp = vPlane.bytes[uvIndex];

        // YUV → RGB (ITU-R BT.601)
        int r = (yp + 1.402 * (vp - 128)).round();
        int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
        int b = (yp + 1.772 * (up - 128)).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  /// NV21 (Y plane + interleaved VU plane) → RGB
  static img.Image _nv21ToRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;

    // NV21: byte order = Y plane (full), then VU interleaved (half size)
    // Pada CameraImage Android, planes[0]=Y, planes[1]=VU interleaved (di Android NV21)
    final yPlane = image.planes[0];
    final uvPlane = image.planes[1];

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uvPlane.bytesPerRow;
    final uvPixelStride = uvPlane.bytesPerPixel ?? 2;

    final out = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        // NV21: V dulu lalu U → tapi Android ImageFormat.NV21 di CameraImage
        // sudah di-split: planes[1] = interleaved VU (V di offset 0, U di offset 1)
        // Jika system pakai NV12 (UV order), beberapa device tetap bekerja karena
        // diff cukup kecil di noise grayscale wajah.
        final uvBaseIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;

        final yp = yPlane.bytes[yIndex];
        final vp = uvPlane.bytes[uvBaseIndex];
        final up = uvPlane.bytes[uvBaseIndex + 1];

        int r = (yp + 1.402 * (vp - 128)).round();
        int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
        int b = (yp + 1.772 * (up - 128)).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  /// BGRA8888 (iOS) → RGB
  static img.Image _bgra8888ToRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;

    final out = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final rowOffset = y * rowStride;
      for (int x = 0; x < width; x++) {
        final i = rowOffset + x * 4;
        final b = bytes[i];
        final g = bytes[i + 1];
        final r = bytes[i + 2];
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  // ============================================================
  // STEP 2: Rotate sesuai sensor orientation
  // ============================================================

  static img.Image _rotate(img.Image src, int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return src;
      case 90:
        return img.copyRotate(src, angle: 90);
      case 180:
        return img.copyRotate(src, angle: 180);
      case 270:
        return img.copyRotate(src, angle: 270);
      default:
        return src;
    }
  }

  // ============================================================
  // STEP 4: Crop face dengan padding
  // ============================================================

  /// Crop area wajah + padding 20% (agar fitur tepi tidak hilang).
  static img.Image _cropFace(img.Image src, FaceBoundingBox box) {
    final imgW = src.width;
    final imgH = src.height;

    // Padding 20% dari ukuran box
    final padX = (box.width * 0.2).round();
    final padY = (box.height * 0.2).round();

    var x = (box.left - padX).round();
    var y = (box.top - padY).round();
    var w = (box.width + padX * 2).round();
    var h = (box.height + padY * 2).round();

    // Clamp ke dalam image bounds
    if (x < 0) {
      w += x; // kurangi width sebanyak overflow
      x = 0;
    }
    if (y < 0) {
      h += y;
      y = 0;
    }
    if (x + w > imgW) w = imgW - x;
    if (y + h > imgH) h = imgH - y;

    if (w <= 0 || h <= 0) {
      // Fallback: crop center square
      final size = math.min(imgW, imgH);
      x = (imgW - size) ~/ 2;
      y = (imgH - size) ~/ 2;
      w = size;
      h = size;
    }

    return img.copyCrop(src, x: x, y: y, width: w, height: h);
  }

  // ============================================================
  // STEP 6: img.Image → Float32List ternormalisasi
  // ============================================================

  /// Convert ke Float32List dengan layout HWC (height-width-channel),
  /// normalisasi ke `[-1, 1]` ala MobileFaceNet:
  /// `pixel_normalized = (pixel - 127.5) / 128.0`
  static Float32List _imageToFloat32(img.Image image) {
    assert(image.width == 112 && image.height == 112,
        'Expected 112x112, got ${image.width}x${image.height}');

    final tensor = Float32List(1 * 112 * 112 * 3);
    int idx = 0;

    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        final pixel = image.getPixel(x, y);
        // image package versi 4.x menggunakan API getPixel().r/.g/.b
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        tensor[idx++] = (r - 127.5) / 128.0;
        tensor[idx++] = (g - 127.5) / 128.0;
        tensor[idx++] = (b - 127.5) / 128.0;
      }
    }
    return tensor;
  }
}

// ============================================================
// Helper struct: bounding box independent dari Flutter (`Rect`).
// Mempermudah testing & menghindari import package:flutter di service core.
// ============================================================

/// Bounding box wajah — koordinat dalam pixel image.
/// Konstruksi dari `face.boundingBox` ML Kit:
/// `FaceBoundingBox(left: r.left, top: r.top, width: r.width, height: r.height)`.
class FaceBoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const FaceBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  @override
  String toString() => 'FaceBoundingBox($left, $top, $width x $height)';
}

/// Wrapper buat dipakai dari luar (test-friendly).
class FacePreprocessor {
  /// Lihat docstring `ImagePreprocessor.preprocessForMobileFaceNet`.
  static Float32List run({
    required CameraImage cameraImage,
    required FaceBoundingBox boundingBox,
    required int sensorOrientation,
    required bool isFrontCamera,
  }) {
    try {
      return ImagePreprocessor.preprocessForMobileFaceNet(
        cameraImage: cameraImage,
        boundingBox: boundingBox,
        sensorOrientation: sensorOrientation,
        isFrontCamera: isFrontCamera,
      );
    } catch (e, st) {
      debugPrint('[PREPROCESS] Error: $e\n$st');
      rethrow;
    }
  }
}
