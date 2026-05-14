// lib/features/face/services/face_embedding_service.dart
// Service untuk ekstraksi face embedding via MobileFaceNet (TFLite).
// Input: cropped face 112x112x3 normalized [-1,1]. Output: 192-d vector.
//
// Singleton lazy-load: model di-load sekali saat `initialize()`,
// inference berikutnya pakai instance yang sama untuk hemat memory.
//
// CATATAN PENTING: model file `assets/models/mobilefacenet.tflite`
// HARUS sudah ada di project. Lihat `assets/models/README.md` untuk
// instruksi download.

import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'image_preprocessor.dart';

class FaceEmbeddingService {
  static const String _modelPath = 'assets/models/mobilefacenet.tflite';
  static const int _inputSize = 112;
  static const int _embeddingDim = 192;

  /// Threshold cosine similarity yang reliable untuk MobileFaceNet 192-d.
  /// Nilai ini sesuai literatur (LFW benchmark): 0.6-0.7 untuk genuine pair.
  /// Disimpan di sini sebagai default; server boleh override via tabel `settings`.
  static const double defaultThreshold = 0.65;

  Interpreter? _interpreter;
  bool _isLoading = false;

  /// Load model dari asset. Idempotent — aman dipanggil berulang.
  Future<void> initialize() async {
    if (_interpreter != null || _isLoading) return;
    _isLoading = true;

    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: options,
      );

      // Validasi shape input/output sesuai ekspektasi MobileFaceNet
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      debugPrint('[FACE EMBED] Model loaded: $_modelPath');
      debugPrint('[FACE EMBED] Input shape: $inputShape');
      debugPrint('[FACE EMBED] Output shape: $outputShape');

      if (inputShape.length != 4 ||
          inputShape[1] != _inputSize ||
          inputShape[2] != _inputSize ||
          inputShape[3] != 3) {
        throw Exception(
          'Model input shape tidak sesuai. Expected [1,$_inputSize,$_inputSize,3], got $inputShape',
        );
      }

      if (outputShape.length != 2 || outputShape[1] != _embeddingDim) {
        // Beberapa varian MobileFaceNet output 128 atau 512.
        // Kita warn tapi tetap jalan — embedding tetap valid asal konsisten.
        debugPrint(
          '[FACE EMBED] ⚠️ Output dim ${outputShape[1]} != $_embeddingDim. '
          'Pastikan threshold dikalibrasi untuk dimensi ini.',
        );
      }
    } catch (e, st) {
      debugPrint('[FACE EMBED] Init error: $e\n$st');
      _interpreter = null;
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Apakah model sudah berhasil di-load.
  bool get isReady => _interpreter != null;

  /// Ekstrak embedding dari sebuah frame kamera + bounding box wajah.
  ///
  /// Return `null` jika preprocessing gagal atau model belum siap.
  /// Throws kalau inference error (catch di caller).
  Future<List<double>?> extractEmbedding({
    required CameraImage cameraImage,
    required FaceBoundingBox boundingBox,
    required int sensorOrientation,
    required bool isFrontCamera,
  }) async {
    if (_interpreter == null) {
      debugPrint('[FACE EMBED] Interpreter belum di-init');
      return null;
    }

    try {
      // 1. Preprocess
      final input = FacePreprocessor.run(
        cameraImage: cameraImage,
        boundingBox: boundingBox,
        sensorOrientation: sensorOrientation,
        isFrontCamera: isFrontCamera,
      );

      // 2. Reshape input ke 4D [1, 112, 112, 3]
      final inputTensor = input.reshape([1, _inputSize, _inputSize, 3]);

      // 3. Allocate output buffer
      final outputDim = _interpreter!.getOutputTensor(0).shape[1];
      final output = List.generate(
        1,
        (_) => List<double>.filled(outputDim, 0.0),
      );

      // 4. Run inference
      _interpreter!.run(inputTensor, output);

      // 5. L2 normalize untuk cosine similarity yang robust
      return _l2Normalize(output[0]);
    } catch (e, st) {
      debugPrint('[FACE EMBED] Inference error: $e\n$st');
      return null;
    }
  }

  /// Average multiple embeddings menjadi satu vector yang stabil,
  /// lalu L2 normalize. Pakai ini untuk multi-frame averaging
  /// saat registrasi (5-10 frame lookStraight).
  ///
  /// Throws jika list kosong atau dimensi tidak konsisten.
  static List<double> averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) {
      throw ArgumentError('Tidak ada embedding untuk di-average');
    }

    final dim = embeddings.first.length;
    final sum = List<double>.filled(dim, 0.0);

    for (final emb in embeddings) {
      if (emb.length != dim) {
        throw ArgumentError(
          'Embedding dimensi tidak konsisten: ${emb.length} vs $dim',
        );
      }
      for (int i = 0; i < dim; i++) {
        sum[i] += emb[i];
      }
    }

    final avg = sum.map((v) => v / embeddings.length).toList();
    return _l2Normalize(avg);
  }

  /// Cosine similarity antara 2 embedding (sudah di-L2-normalize jadi
  /// cukup dot product). Range: -1 (opposite) sampai 1 (identical).
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dot = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }

    // Karena sudah L2-normalized, magnitudo = 1.
    // Tapi kita defensive: hitung magnitudo aktual untuk safety.
    double magA = 0;
    double magB = 0;
    for (int i = 0; i < a.length; i++) {
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    magA = math.sqrt(magA);
    magB = math.sqrt(magB);

    if (magA == 0 || magB == 0) return 0.0;
    return dot / (magA * magB);
  }

  /// L2 normalize → unit vector. Wajib agar cosine similarity menjadi
  /// dot product dan threshold konsisten.
  static List<double> _l2Normalize(List<double> v) {
    double sumSq = 0;
    for (final x in v) {
      sumSq += x * x;
    }
    final norm = math.sqrt(sumSq);
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
  }

  /// Free native interpreter resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    debugPrint('[FACE EMBED] Disposed');
  }
}
