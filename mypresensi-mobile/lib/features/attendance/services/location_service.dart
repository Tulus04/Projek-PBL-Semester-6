// lib/features/attendance/services/location_service.dart
// Service untuk GPS location — permission handling, position, mock detection.
// Menggunakan geolocator package. Semua error di-handle gracefully.

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Hasil dari operasi ambil lokasi
class LocationResult {
  final double latitude;
  final double longitude;
  final bool isMockLocation;
  final double accuracy;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.isMockLocation,
    required this.accuracy,
  });
}

/// Exception khusus untuk masalah lokasi
class LocationException implements Exception {
  final String message;
  final LocationErrorType type;

  const LocationException(this.message, this.type);

  @override
  String toString() => message;
}

enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class LocationService {
  /// Cek dan minta permission lokasi
  /// Throws [LocationException] jika ditolak
  Future<void> checkAndRequestPermission() async {
    // 1. Cek apakah location service enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Layanan lokasi tidak aktif. Aktifkan GPS di pengaturan perangkat.',
        LocationErrorType.serviceDisabled,
      );
    }

    // 2. Cek permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Izin lokasi ditolak. Aplikasi memerlukan akses lokasi untuk presensi.',
          LocationErrorType.permissionDenied,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan akses lokasi.',
        LocationErrorType.permissionDeniedForever,
      );
    }
  }

  /// Ambil posisi saat ini
  /// Return [LocationResult] dengan lat, lng, mock detection, accuracy
  Future<LocationResult> getCurrentPosition() async {
    // Pastikan permission sudah granted
    await checkAndRequestPermission();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      debugPrint(
        '[LOCATION] Position: ${position.latitude}, ${position.longitude} '
        '(accuracy: ${position.accuracy}m, mock: ${position.isMocked})',
      );

      // ⚠️ DEV-ONLY OVERRIDE: emulator Android selalu return isMocked=true,
      // server me-reject mock_location → presensi gagal di emulator.
      // Bypass ini HANYA aktif saat `kDebugMode == true` (debug build).
      // Release build (production APK) TIDAK terpengaruh — `is_mock_location`
      // tetap dikirim apa adanya & server tetap menolak mock.
      bool isMock = position.isMocked;
      if (kDebugMode && isMock) {
        debugPrint(
          '[LOCATION] ⚠️ DEV-ONLY: Mock detected pada debug build → '
          'override jadi false. Test mock-rejection di RELEASE build / HP fisik.',
        );
        isMock = false;
      }

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        isMockLocation: isMock,
        accuracy: position.accuracy,
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        'GPS dimatikan saat proses berlangsung. Aktifkan GPS dan coba lagi.',
        LocationErrorType.serviceDisabled,
      );
    } catch (e) {
      if (e is LocationException) rethrow;

      debugPrint('[LOCATION] Error: $e');
      throw const LocationException(
        'Gagal mendapatkan lokasi. Pastikan GPS aktif dan coba lagi.',
        LocationErrorType.unknown,
      );
    }
  }
}
