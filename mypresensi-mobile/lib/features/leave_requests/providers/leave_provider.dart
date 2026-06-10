// lib/features/leave_requests/providers/leave_provider.dart
// Riverpod providers untuk fitur pengajuan izin/sakit.
// Mengikuti pola NotifierProvider untuk submit (state machine) dan
// FutureProvider.autoDispose untuk fetch list.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/leave_models.dart';
import '../data/leave_repository.dart';
import '../../../shared/utils/error_mapper.dart';

/// Provider untuk repository instance
final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository();
});

/// Daftar pengajuan saya — auto-dispose, refresh-able via ref.invalidate.
/// Filter status opsional via [LeaveListFilter] yang dipassing dari UI.
final myLeaveRequestsProvider =
    FutureProvider.autoDispose<MyLeaveRequestsResponse>((ref) async {
  final repo = ref.read(leaveRepositoryProvider);
  
  List<LeaveRequestItem> remoteRequests = [];
  try {
    final response = await repo.getMyRequests();
    remoteRequests = response.requests;
  } catch (e) {
    debugPrint('[LEAVE] Failed to fetch remote requests, using dummy only: $e');
  }

  // INJECT DUMMY DATA UNTUK DEMO (LEAVE REQUESTS)
  final now = DateTime.now();
  final dummy1 = LeaveRequestItem(
    id: 'leave1',
    type: LeaveType.sakit,
    status: LeaveStatus.approved,
    reason: 'Demam tinggi dan flu berat. Harus bed rest.',
    evidenceUrl: 'https://dummy.url/surat-dokter.jpg',
    createdAt: now.subtract(const Duration(days: 2)).toIso8601String(),
    reviewedAt: now.subtract(const Duration(days: 1)).toIso8601String(),
    reviewNote: 'Semoga lekas sembuh. Lampiran valid.',
    session: LeaveRequestSession(
      id: 'session1',
      courseName: 'Pemrograman Web (Dummy)',
      courseCode: 'TIF101',
      sessionNumber: 3,
      startedAt: now.subtract(const Duration(days: 2)).toIso8601String(),
    ),
  );

  final dummy2 = LeaveRequestItem(
    id: 'leave2',
    type: LeaveType.izin,
    status: LeaveStatus.pending,
    reason: 'Ada acara keluarga (Pernikahan Kakak) di luar kota.',
    evidenceUrl: 'https://dummy.url/undangan.jpg',
    createdAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
    session: LeaveRequestSession(
      id: 'session2',
      courseName: 'Basis Data Lanjut (Dummy)',
      courseCode: 'TIF102',
      sessionNumber: 4,
      startedAt: now.toIso8601String(),
    ),
  );

  final dummy3 = LeaveRequestItem(
    id: 'leave3',
    type: LeaveType.izin,
    status: LeaveStatus.rejected,
    reason: 'Bangun kesiangan.',
    evidenceUrl: null,
    createdAt: now.subtract(const Duration(days: 5)).toIso8601String(),
    reviewedAt: now.subtract(const Duration(days: 4)).toIso8601String(),
    reviewNote: 'Alasan tidak dapat diterima secara akademik.',
    session: LeaveRequestSession(
      id: 'session3',
      courseName: 'Jaringan Komputer (Dummy)',
      courseCode: 'TIF103',
      sessionNumber: 2,
      startedAt: now.subtract(const Duration(days: 5)).toIso8601String(),
    ),
  );

  final allRequests = [dummy1, dummy2, dummy3, ...remoteRequests];
  
  // Urutkan berdasarkan waktu pembuatan terbaru (descending)
  allRequests.sort((a, b) {
    final dateA = DateTime.tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = DateTime.tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  });
  final pendingCount = allRequests.where((r) => r.status == LeaveStatus.pending).length;
  final approvedCount = allRequests.where((r) => r.status == LeaveStatus.approved).length;
  final rejectedCount = allRequests.where((r) => r.status == LeaveStatus.rejected).length;

  return MyLeaveRequestsResponse(
    summary: LeaveSummary(
      total: allRequests.length,
      pending: pendingCount,
      approved: approvedCount,
      rejected: rejectedCount,
    ),
    requests: allRequests,
  );
});

/// State submit pengajuan
enum SubmitLeaveStatus { idle, submitting, success, error }

class SubmitLeaveState {
  final SubmitLeaveStatus status;
  final SubmitLeaveResponse? response;
  final String? errorMessage;

  const SubmitLeaveState({
    this.status = SubmitLeaveStatus.idle,
    this.response,
    this.errorMessage,
  });

  SubmitLeaveState copyWith({
    SubmitLeaveStatus? status,
    SubmitLeaveResponse? response,
    String? errorMessage,
  }) {
    return SubmitLeaveState(
      status: status ?? this.status,
      response: response ?? this.response,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier untuk proses submit pengajuan
final submitLeaveProvider =
    NotifierProvider<SubmitLeaveNotifier, SubmitLeaveState>(
  SubmitLeaveNotifier.new,
);

class SubmitLeaveNotifier extends Notifier<SubmitLeaveState> {
  @override
  SubmitLeaveState build() => const SubmitLeaveState();

  /// Submit form ke server.
  /// Return true jika berhasil, false jika gagal (cek state.errorMessage).
  Future<bool> submit({
    required String sessionId,
    required LeaveType type,
    required String reason,
    String? evidencePath,
  }) async {
    state = state.copyWith(
      status: SubmitLeaveStatus.submitting,
      errorMessage: null,
    );

    try {
      final repo = ref.read(leaveRepositoryProvider);
      final response = await repo.submit(SubmitLeaveRequest(
        sessionId: sessionId,
        type: type,
        reason: reason,
        evidencePath: evidencePath,
      ));

      state = state.copyWith(
        status: SubmitLeaveStatus.success,
        response: response,
      );

      // Invalidate list provider agar list refresh setelah submit berhasil
      ref.invalidate(myLeaveRequestsProvider);

      return true;
    } catch (e) {
      debugPrint('[LEAVE] Submit error: $e');
      state = state.copyWith(
        status: SubmitLeaveStatus.error,
        errorMessage: friendlyErrorMessage(e),
      );
      return false;
    }
  }

  /// Reset state — untuk membuka form ulang
  void reset() {
    state = const SubmitLeaveState();
  }
}
