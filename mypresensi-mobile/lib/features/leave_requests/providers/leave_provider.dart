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
  return repo.getMyRequests();
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
    String? evidenceUrl,
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
        evidenceUrl: evidenceUrl,
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
