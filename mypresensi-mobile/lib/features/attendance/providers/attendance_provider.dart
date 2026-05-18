// lib/features/attendance/providers/attendance_provider.dart
// Riverpod providers untuk fitur presensi — state management scan QR + submit.
// Pattern: UI → Provider → Repository → Dio → API.

import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/attendance_models.dart';
import '../data/attendance_repository.dart';
import '../services/location_service.dart';
import '../../face/data/face_models.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../../shared/utils/error_mapper.dart' show friendlyErrorMessage;

// === Repository & Service providers ===
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// === Active Sessions (FutureProvider — auto-dispose, refresh-able) ===
final activeSessionsProvider = FutureProvider.autoDispose<List<ActiveSession>>((ref) async {
  final repo = ref.read(attendanceRepositoryProvider);
  return repo.getActiveSessions();
});

/// Provider daftar sesi yang eligible untuk diajukan izin/sakit oleh mahasiswa.
///
/// Dipakai oleh wizard "Ajukan Izin" step 1 (Pilih Sesi) — return dua group
/// (active + recent ≤ 7 hari) yang sudah difilter backend (belum hadir, belum
/// punya leave_request pending/approved). UI tidak perlu re-filter.
final eligibleSessionsForLeaveProvider =
    FutureProvider.autoDispose<EligibleSessionsResponse>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getEligibleSessionsForLeave();
});

// === Attendance Submit State ===
enum SubmitStatus {
  idle,
  gettingLocation,
  verifyingFace,
  submitting,
  success,
  error,
}

class AttendanceSubmitState {
  final SubmitStatus status;
  final AttendanceSubmitResponse? response;
  final String? errorMessage;
  /// Error code dari server saat 4xx (mis. 'face_not_registered', 'face_mismatch').
  /// UI layer (scan_qr_screen) cek field ini untuk routing dialog yang sesuai.
  final String? errorCode;
  final String? sessionName;
  final FaceVerificationResult? faceResult;

  const AttendanceSubmitState({
    this.status = SubmitStatus.idle,
    this.response,
    this.errorMessage,
    this.errorCode,
    this.sessionName,
    this.faceResult,
  });

  AttendanceSubmitState copyWith({
    SubmitStatus? status,
    AttendanceSubmitResponse? response,
    String? errorMessage,
    String? errorCode,
    String? sessionName,
    FaceVerificationResult? faceResult,
  }) {
    return AttendanceSubmitState(
      status: status ?? this.status,
      response: response ?? this.response,
      errorMessage: errorMessage,
      errorCode: errorCode,
      sessionName: sessionName ?? this.sessionName,
      faceResult: faceResult ?? this.faceResult,
    );
  }
}

// === Submit Provider (Notifier pattern) ===
final attendanceSubmitProvider =
    NotifierProvider<AttendanceSubmitNotifier, AttendanceSubmitState>(
  AttendanceSubmitNotifier.new,
);

class AttendanceSubmitNotifier extends Notifier<AttendanceSubmitState> {
  @override
  AttendanceSubmitState build() => const AttendanceSubmitState();

  /// Parse QR code raw string ke QrCodeData
  /// Return null jika format tidak valid
  QrCodeData? parseQrCode(String rawValue) {
    try {
      final map = jsonDecode(rawValue) as Map<String, dynamic>;
      return QrCodeData.fromMap(map);
    } catch (e) {
      debugPrint('[QR] Parse error: $e');
      return null;
    }
  }

  /// Submit presensi — full flow: parse QR → get GPS → hit API
  /// faceResult opsional — jika ada, dikirim ke server sebagai data tambahan
  Future<bool> submitFromQr(
    QrCodeData qrData, {
    String? sessionName,
    FaceVerificationResult? faceResult,
  }) async {
    final repo = ref.read(attendanceRepositoryProvider);
    final locationService = ref.read(locationServiceProvider);

    try {
      // 1. Getting GPS location
      state = state.copyWith(
        status: SubmitStatus.gettingLocation,
        sessionName: sessionName,
        errorMessage: null,
      );

      final location = await locationService.getCurrentPosition();

      // Flag peringatan jika mock location terdeteksi
      if (location.isMockLocation) {
        debugPrint('[ATTENDANCE] ⚠️ Mock location detected!');
      }

      // 2. Ambil device info
      final deviceInfo = DeviceInfoPlugin();
      String? deviceModel;
      String? deviceOs;

      try {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        deviceOs = 'Android ${androidInfo.version.release}';
      } catch (_) {
        // Fallback jika bukan Android
        deviceModel = 'Unknown';
        deviceOs = 'Unknown';
      }

      // 3. Submit ke server
      state = state.copyWith(status: SubmitStatus.submitting);

      final request = AttendanceSubmitRequest(
        sessionId: qrData.sessionId,
        sessionCode: qrData.sessionCode,
        latitude: location.latitude,
        longitude: location.longitude,
        isMockLocation: location.isMockLocation,
        deviceModel: deviceModel,
        deviceOs: deviceOs,
        faceConfidence: faceResult?.confidence,
        isFaceMatched: faceResult?.isMatched,
        isLivenessPassed: faceResult?.isLivenessPassed,
      );

      final response = await repo.submitAttendance(request);

      // 4. Success!
      state = state.copyWith(
        status: SubmitStatus.success,
        response: response,
      );

      debugPrint('[ATTENDANCE] Submit berhasil: ${response.message}');
      return true;
    } on LocationException catch (e) {
      state = state.copyWith(
        status: SubmitStatus.error,
        errorMessage: e.message,
      );
      return false;
    } on AttendanceSubmitException catch (e) {
      // Server kirim error_code (mis. face_not_registered, face_mismatch).
      // UI scan_qr_screen cek state.errorCode untuk dialog redirect.
      debugPrint('[ATTENDANCE] Submit error: ${e.errorCode} — ${e.message}');
      state = state.copyWith(
        status: SubmitStatus.error,
        errorMessage: e.message,
        errorCode: e.errorCode,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: SubmitStatus.error,
        errorMessage: friendlyErrorMessage(e),
      );
      return false;
    }
  }

  /// Reset state — untuk scan ulang
  void reset() {
    state = const AttendanceSubmitState();
  }
}
