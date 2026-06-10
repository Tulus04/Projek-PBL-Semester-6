// lib/features/leave_requests/screens/submit_leave_request_screen.dart
// Wizard 4-step pengajuan izin/sakit (Phase 5 rebuild — sesuai mockup
// docs/ui-research/mockups/mobile-leave-request.html).
//
// Step:
//   1. pickSession     — pilih sesi (active + recent ≤ 7 hari) via
//                        eligibleSessionsForLeaveProvider.
//   2. typeAndReason   — pilih jenis (Sakit/Izin) + tulis alasan + counter.
//   3. evidence        — opsional foto bukti. Upload terjadi saat advance.
//   4. review          — ringkasan read-only sebelum kirim.
//
// State persistence: data dipertahankan saat user navigasi mundur via system
// back. Saat step > 1, system back diintercept (kembali ke step sebelumnya);
// saat step = 1, system back pop route. Back diblokir saat upload berjalan.
//
// Catatan keamanan: file sensitif (`pickedImage`) disimpan di local state,
// tidak pernah di-log ke debugPrint. evidencePath dari server adalah path
// relatif di bucket `leave-evidence` (bukan signed URL).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/utils/error_mapper.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../attendance/data/attendance_models.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../data/leave_models.dart';
import '../providers/leave_provider.dart';

// ============================================================================
// Pure helpers — date / format
// ============================================================================

const List<String> _idShortWeekday = [
  'Sen', // 1
  'Sel', // 2
  'Rab', // 3
  'Kam', // 4
  'Jum', // 5
  'Sab', // 6
  'Min', // 7
];

String _shortWeekday(int weekday) {
  if (weekday < 1 || weekday > 7) return '';
  return _idShortWeekday[weekday - 1];
}

/// Format jam HH:mm dari string ISO.
String _formatTimeOnly(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  } catch (_) {
    return '--:--';
  }
}

/// Hitung selisih hari (today - sessionDay) berbasis tanggal lokal.
/// Return null kalau parsing gagal.
int? _daysAgo(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(dt.year, dt.month, dt.day);
    return today.difference(sessionDay).inDays;
  } catch (_) {
    return null;
  }
}

/// Status badge untuk recent_sessions:
/// 0–1 hari → "KEMARIN"; ≥ 2 → "{N} HARI LALU".
String _recentBadgeFor(String iso) {
  final diff = _daysAgo(iso);
  if (diff == null) return 'BARU LALU';
  if (diff <= 1) return 'KEMARIN';
  return '$diff HARI LALU';
}

// ============================================================================
// Wizard step enum + state class
// ============================================================================

enum WizardStep { pickSession, typeAndReason, evidence, review }

@immutable
class WizardState {
  final WizardStep step;
  final ActiveSession? selectedSession;
  final LeaveType selectedType;
  final String reason;
  final File? pickedImage;
  final String? evidencePath;
  final bool isUploadingEvidence;
  final String? evidenceErrorText;

  const WizardState({
    this.step = WizardStep.pickSession,
    this.selectedSession,
    this.selectedType = LeaveType.izin,
    this.reason = '',
    this.pickedImage,
    this.evidencePath,
    this.isUploadingEvidence = false,
    this.evidenceErrorText,
  });

  WizardState copyWith({
    WizardStep? step,
    ActiveSession? selectedSession,
    bool clearSelectedSession = false,
    LeaveType? selectedType,
    String? reason,
    File? pickedImage,
    bool clearPickedImage = false,
    String? evidencePath,
    bool clearEvidencePath = false,
    bool? isUploadingEvidence,
    String? evidenceErrorText,
    bool clearEvidenceErrorText = false,
  }) {
    return WizardState(
      step: step ?? this.step,
      selectedSession: clearSelectedSession
          ? null
          : (selectedSession ?? this.selectedSession),
      selectedType: selectedType ?? this.selectedType,
      reason: reason ?? this.reason,
      pickedImage:
          clearPickedImage ? null : (pickedImage ?? this.pickedImage),
      evidencePath:
          clearEvidencePath ? null : (evidencePath ?? this.evidencePath),
      isUploadingEvidence: isUploadingEvidence ?? this.isUploadingEvidence,
      evidenceErrorText: clearEvidenceErrorText
          ? null
          : (evidenceErrorText ?? this.evidenceErrorText),
    );
  }

  /// Apakah wizard boleh advance dari step saat ini?
  bool get canAdvance {
    switch (step) {
      case WizardStep.pickSession:
        return selectedSession != null;
      case WizardStep.typeAndReason:
        final r = reason.trim();
        return r.length >= 10 && r.length <= 500;
      case WizardStep.evidence:
        // Boleh advance walau tidak ada lampiran. Hanya block saat upload aktif.
        return !isUploadingEvidence;
      case WizardStep.review:
        return true;
    }
  }
}


// ============================================================================
// SubmitLeaveRequestScreen — wizard utama
// ============================================================================

class SubmitLeaveRequestScreen extends ConsumerStatefulWidget {
  const SubmitLeaveRequestScreen({super.key});

  @override
  ConsumerState<SubmitLeaveRequestScreen> createState() =>
      _SubmitLeaveRequestScreenState();
}

class _SubmitLeaveRequestScreenState
    extends ConsumerState<SubmitLeaveRequestScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _reasonController = TextEditingController();

  WizardState _state = const WizardState();

  @override
  void initState() {
    super.initState();
    // Reset state submit saat masuk screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(submitLeaveProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Algorithm 1 — advanceWizardStep (async karena step evidence upload)
  // ---------------------------------------------------------------------------

  Future<WizardState> _advanceWizardStep(WizardState s) async {
    switch (s.step) {
      case WizardStep.pickSession:
        assert(s.selectedSession != null);
        return s.copyWith(step: WizardStep.typeAndReason);

      case WizardStep.typeAndReason:
        final trimmed = s.reason.trim();
        assert(trimmed.length >= 10 && trimmed.length <= 500);
        return s.copyWith(step: WizardStep.evidence);

      case WizardStep.evidence:
        if (s.pickedImage != null && s.evidencePath == null) {
          // Upload evidence dulu sebelum lanjut ke review.
          setState(() {
            _state = _state.copyWith(
              isUploadingEvidence: true,
              clearEvidenceErrorText: true,
            );
          });
          try {
            final repo = ref.read(leaveRepositoryProvider);
            final upload = await repo.uploadEvidence(s.pickedImage!);
            if (!mounted) return _state;
            return _state.copyWith(
              evidencePath: upload.path,
              isUploadingEvidence: false,
              step: WizardStep.review,
            );
          } catch (e) {
            if (!mounted) return _state;
            return _state.copyWith(
              isUploadingEvidence: false,
              evidenceErrorText: friendlyErrorMessage(e),
            );
          }
        }
        // Tidak ada gambar baru → langsung lanjut.
        return s.copyWith(step: WizardStep.review);

      case WizardStep.review:
        // Review → submit di-handle terpisah oleh _handleSubmit.
        return s;
    }
  }

  // ---------------------------------------------------------------------------
  // Algorithm 2 — goBackWizardStep (sync, return tuple)
  // ---------------------------------------------------------------------------

  ({WizardState newState, bool shouldPopRoute}) _goBackWizardStep(
    WizardState s,
  ) {
    if (s.isUploadingEvidence) {
      // Block back saat upload — hindari orphan upload.
      return (newState: s, shouldPopRoute: false);
    }
    switch (s.step) {
      case WizardStep.pickSession:
        return (newState: s, shouldPopRoute: true);
      case WizardStep.typeAndReason:
        return (
          newState: s.copyWith(step: WizardStep.pickSession),
          shouldPopRoute: false,
        );
      case WizardStep.evidence:
        return (
          newState: s.copyWith(step: WizardStep.typeAndReason),
          shouldPopRoute: false,
        );
      case WizardStep.review:
        return (
          newState: s.copyWith(step: WizardStep.evidence),
          shouldPopRoute: false,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Action handlers
  // ---------------------------------------------------------------------------

  Future<void> _handleAdvance() async {
    if (!_state.canAdvance) return;

    if (_state.step == WizardStep.review) {
      // Review → kirim pengajuan via provider.
      await _handleSubmit();
      return;
    }

    final next = await _advanceWizardStep(_state);
    if (!mounted) return;
    setState(() => _state = next);
  }

  void _handleGoBack() {
    final result = _goBackWizardStep(_state);
    if (result.shouldPopRoute) {
      context.pop();
      return;
    }
    setState(() => _state = result.newState);
  }

  Future<void> _handleSubmit() async {
    final session = _state.selectedSession;
    if (session == null) return;

    FocusScope.of(context).unfocus();

    final success = await ref.read(submitLeaveProvider.notifier).submit(
          sessionId: session.id,
          type: _state.selectedType,
          reason: _state.reason.trim(),
          evidencePath: _state.evidencePath,
        );

    if (!mounted) return;

    if (success) {
      final response = ref.read(submitLeaveProvider).response;
      _showSnackbar(
        response?.message ?? 'Pengajuan berhasil dikirim',
        isError: false,
      );
      // Pop dengan flag true agar caller bisa refresh list.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) context.pop(true);
      });
    } else {
      final err = ref.read(submitLeaveProvider).errorMessage;
      _showSnackbar(err ?? 'Gagal mengirim pengajuan', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Evidence picker handlers
  // ---------------------------------------------------------------------------

  Future<void> _pickEvidence(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          pickedImage: File(picked.path),
          // Image baru → batalkan path upload sebelumnya agar advance re-upload.
          clearEvidencePath: true,
          clearEvidenceErrorText: true,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          evidenceErrorText: 'Gagal memilih foto: ${e.toString()}',
        );
      });
    }
  }

  void _showEvidencePickerSheet() {
    if (_state.isUploadingEvidence) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  IconsaxPlusBold.gallery_add,
                  color: AppColors.primary,
                ),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickEvidence(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  IconsaxPlusBold.camera,
                  color: AppColors.primary,
                ),
                title: const Text('Ambil Foto'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickEvidence(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _removeEvidence() {
    if (_state.isUploadingEvidence) return;
    setState(() {
      _state = _state.copyWith(
        clearPickedImage: true,
        clearEvidencePath: true,
        clearEvidenceErrorText: true,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Snackbar
  // ---------------------------------------------------------------------------

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? IconsaxPlusBold.close_circle : IconsaxPlusBold.tick_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(submitLeaveProvider);
    final isSubmitting = submitState.status == SubmitLeaveStatus.submitting;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleGoBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 24,
            ),
            onPressed: _state.isUploadingEvidence ? null : _handleGoBack,
          ),
          title: const Text(
            'Pengajuan Izin',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // Step bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _StepBar(currentStep: _state.step),
              ),

              // Content
              Expanded(
                child: _buildStepContent(),
              ),

              // Footer CTA
              _WizardFooter(
                label: _footerLabel(_state.step),
                icon: _footerIcon(_state.step),
                enabled: _state.canAdvance && !isSubmitting,
                loading: _state.isUploadingEvidence || isSubmitting,
                onTap: _handleAdvance,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_state.step) {
      case WizardStep.pickSession:
        return _StepPickSession(
          selected: _state.selectedSession,
          onPick: (s) {
            setState(() {
              _state = _state.copyWith(selectedSession: s);
            });
          },
        );
      case WizardStep.typeAndReason:
        // Pastikan controller sinkron dengan state saat user kembali ke step 2.
        if (_reasonController.text != _state.reason) {
          _reasonController.value = TextEditingValue(
            text: _state.reason,
            selection:
                TextSelection.collapsed(offset: _state.reason.length),
          );
        }
        return _StepTypeAndReason(
          session: _state.selectedSession!,
          type: _state.selectedType,
          reasonController: _reasonController,
          onTypeChanged: (t) {
            setState(() {
              _state = _state.copyWith(selectedType: t);
            });
          },
          onReasonChanged: (v) {
            setState(() {
              _state = _state.copyWith(reason: v);
            });
          },
        );
      case WizardStep.evidence:
        return _StepEvidence(
          pickedImage: _state.pickedImage,
          errorText: _state.evidenceErrorText,
          isUploading: _state.isUploadingEvidence,
          onPick: _showEvidencePickerSheet,
          onRemove: _removeEvidence,
        );
      case WizardStep.review:
        return _StepReview(
          session: _state.selectedSession!,
          type: _state.selectedType,
          reason: _state.reason.trim(),
          evidencePath: _state.evidencePath,
          hasPickedImage: _state.pickedImage != null,
        );
    }
  }

  String _footerLabel(WizardStep step) {
    switch (step) {
      case WizardStep.pickSession:
        return 'Lanjut ke Keterangan';
      case WizardStep.typeAndReason:
        return 'Lanjut ke Lampiran';
      case WizardStep.evidence:
        if (_state.isUploadingEvidence) return 'Mengunggah bukti...';
        return 'Lanjut ke Review';
      case WizardStep.review:
        final submitState = ref.read(submitLeaveProvider);
        if (submitState.status == SubmitLeaveStatus.submitting) {
          return 'Mengirim...';
        }
        return 'Kirim Pengajuan';
    }
  }

  IconData _footerIcon(WizardStep step) {
    if (step == WizardStep.review) return IconsaxPlusBold.send_2;
    return IconsaxPlusBold.arrow_right_3;
  }
}


// ============================================================================
// _StepBar — 4 lingkaran + 3 connector line
// ============================================================================

class _StepBar extends StatelessWidget {
  const _StepBar({required this.currentStep});
  final WizardStep currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Sesi', 'Keterangan', 'Bukti', 'Review'];
    final steps = WizardStep.values;
    final currentIndex = currentStep.index;

    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final isDone = i < currentIndex;
      final isActive = i == currentIndex;
      children.add(
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepCircle(
                index: i,
                isDone: isDone,
                isActive: isActive,
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  letterSpacing: 0.2,
                  color: isActive
                      ? AppColors.primary
                      : isDone
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
      if (i < steps.length - 1) {
        children.add(
          Container(
            width: 24,
            height: 2,
            margin: const EdgeInsets.only(bottom: 22),
            color: isDone ? AppColors.success : AppColors.border,
          ),
        );
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.index,
    required this.isDone,
    required this.isActive,
  });
  final int index;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          IconsaxPlusBold.tick_circle,
          color: Colors.white,
          size: 16,
        ),
      );
    }
    if (isActive) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: AppColors.primarySurface,
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    // Pending
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunken,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

// ============================================================================
// _SessionPickItem — card pilih sesi (date box + info + status badge + radio)
// ============================================================================

class _SessionPickItem extends StatelessWidget {
  const _SessionPickItem({
    required this.session,
    required this.selected,
    required this.onTap,
    this.statusBadge,
    this.statusBadgeColor = _StatusBadgeColor.upcoming,
  });

  final ActiveSession session;
  final bool selected;
  final VoidCallback onTap;
  final String? statusBadge;
  final _StatusBadgeColor statusBadgeColor;

  @override
  Widget build(BuildContext context) {
    final dt = _safeParse(session.startedAt);
    final dayLabel = dt == null ? '--' : _shortWeekday(dt.weekday);
    final dayNum = dt == null ? '--' : dt.day.toString();
    final time = _formatTimeOnly(session.startedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySurface : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
              boxShadow: selected ? null : AppShadows.card,
            ),
            child: Row(
              children: [
                // Date box (gradient primary→hover)
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryHover],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayLabel,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: Colors.white,
                          letterSpacing: 0.4,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayNum,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.courseName,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pertemuan ${session.sessionNumber} · $time',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (session.dosenName != null &&
                          session.dosenName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          session.dosenName!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status badge
                if (statusBadge != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBadgeColor == _StatusBadgeColor.active
                          ? AppColors.successTint
                          : AppColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusBadge!,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        letterSpacing: 0.3,
                        color: statusBadgeColor == _StatusBadgeColor.active
                            ? AppColors.success
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),

                // Radio circle
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.borderStrong,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static DateTime? _safeParse(String iso) {
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }
}

enum _StatusBadgeColor { active, neutral, upcoming }


// ============================================================================
// _StepPickSession — Step 1
// ============================================================================

class _StepPickSession extends ConsumerWidget {
  const _StepPickSession({
    required this.selected,
    required this.onPick,
  });

  final ActiveSession? selected;
  final ValueChanged<ActiveSession> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibleAsync = ref.watch(eligibleSessionsForLeaveProvider);

    return eligibleAsync.when(
      data: (response) => _buildContent(context, ref, response),
      loading: () => const _SessionListSkeleton(),
      error: (e, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: ErrorState(
          icon: IconsaxPlusBold.cloud_cross,
          title: 'Gagal memuat sesi',
          message: friendlyErrorMessage(e),
          onRetry: () => ref.invalidate(eligibleSessionsForLeaveProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    EligibleSessionsResponse response,
  ) {
    if (response.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        children: [
          _buildEmptyHint(),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(eligibleSessionsForLeaveProvider);
        await ref.read(eligibleSessionsForLeaveProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSectionHeading(),
          const SizedBox(height: 14),

          if (response.activeSessions.isNotEmpty) ...[
            _GroupHeader(
              icon: IconsaxPlusBold.radar_2,
              label: 'Sedang berlangsung',
              color: AppColors.success,
            ),
            const SizedBox(height: 4),
            for (final s in response.activeSessions)
              _SessionPickItem(
                session: s,
                selected: selected?.id == s.id,
                onTap: () => onPick(s),
                statusBadge: 'AKTIF',
                statusBadgeColor: _StatusBadgeColor.active,
              ),
            const SizedBox(height: 8),
          ],

          if (response.recentSessions.isNotEmpty) ...[
            _GroupHeader(
              icon: IconsaxPlusBold.previous,
              label: 'Belum sempat hadir',
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            for (final s in response.recentSessions)
              _SessionPickItem(
                session: s,
                selected: selected?.id == s.id,
                onTap: () => onPick(s),
                statusBadge: _recentBadgeFor(s.startedAt),
                statusBadgeColor: _StatusBadgeColor.neutral,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeading() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Pilih Sesi',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Sesi yang belum kamu hadiri. Pilih satu untuk diajukan izin.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              IconsaxPlusBold.calendar_remove,
              size: 56,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tidak ada sesi yang aktif',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Sesi akan muncul di sini begitu dosen membukanya di kelas. Kamu tidak bisa mengajukan izin jika tidak ada sesi.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionListSkeleton extends StatelessWidget {
  const _SessionListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      children: [
        const SizedBox(
          height: 60,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
      ],
    );
  }
}


// ============================================================================
// _SelectedSessionBadge — read-only ringkasan sesi di Step 2 & Review
// ============================================================================

class _SelectedSessionBadge extends StatelessWidget {
  const _SelectedSessionBadge({required this.session});
  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final dt = _safeParse(session.startedAt);
    final dayLabel = dt == null ? '--' : _shortWeekday(dt.weekday);
    final dayNum = dt == null ? '--' : dt.day.toString();
    final time = _formatTimeOnly(session.startedAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryHover],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  dayLabel,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: Colors.white,
                    letterSpacing: 0.4,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayNum,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.courseName,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      IconsaxPlusBold.clock,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Pertemuan ${session.sessionNumber} · $time'
                        '${(session.dosenName != null && session.dosenName!.trim().isNotEmpty) ? ' · ${session.dosenName}' : ''}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static DateTime? _safeParse(String iso) {
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// _TypeTile — pilihan kategori (Sakit / Izin)
// ============================================================================

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
            boxShadow: selected ? null : AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 24,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _StepTypeAndReason — Step 2
// ============================================================================

class _StepTypeAndReason extends StatelessWidget {
  const _StepTypeAndReason({
    required this.session,
    required this.type,
    required this.reasonController,
    required this.onTypeChanged,
    required this.onReasonChanged,
  });

  final ActiveSession session;
  final LeaveType type;
  final TextEditingController reasonController;
  final ValueChanged<LeaveType> onTypeChanged;
  final ValueChanged<String> onReasonChanged;

  @override
  Widget build(BuildContext context) {
    final reasonLength = reasonController.text.trim().length;
    final reasonOk = reasonLength >= 10;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      children: [
        const Text(
          'Keterangan & Alasan',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih keterangan absensi dan tuliskan alasannya.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        _SelectedSessionBadge(session: session),
        const SizedBox(height: 20),

        const _FieldLabel('Keterangan'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TypeTile(
                icon: IconsaxPlusBold.health,
                label: 'Sakit',
                selected: type == LeaveType.sakit,
                onTap: () => onTypeChanged(LeaveType.sakit),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TypeTile(
                icon: IconsaxPlusBold.note_2,
                label: 'Izin',
                selected: type == LeaveType.izin,
                onTap: () => onTypeChanged(LeaveType.izin),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const _FieldLabel('Alasan'),
        const SizedBox(height: 8),
        TextField(
          controller: reasonController,
          maxLines: 5,
          maxLength: 500,
          onChanged: onReasonChanged,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText:
                'Tuliskan alasan Anda di sini...',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.all(14),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  IconsaxPlusBold.info_circle,
                  size: 12,
                  color: reasonOk ? AppColors.success : AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Min. 10 karakter',
                  style: TextStyle(
                    fontSize: 11,
                    color: reasonOk
                        ? AppColors.success
                        : AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '$reasonLength/500',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: reasonOk ? AppColors.success : AppColors.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}


// ============================================================================
// _StepEvidence — Step 3 (opsional foto bukti)
// ============================================================================

class _StepEvidence extends StatelessWidget {
  const _StepEvidence({
    required this.pickedImage,
    required this.errorText,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
  });

  final File? pickedImage;
  final String? errorText;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      children: [
        const Text(
          'Lampiran',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lampirkan foto bukti seperti surat dokter (opsional). Boleh dilewati.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        if (pickedImage == null)
          _UploadZone(onTap: isUploading ? null : onPick)
        else
          _EvidencePreview(
            file: pickedImage!,
            isUploading: isUploading,
            onReplace: isUploading ? null : onPick,
            onRemove: isUploading ? null : onRemove,
          ),

        if (errorText != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                IconsaxPlusBold.warning_2,
                size: 14,
                color: AppColors.danger,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorText!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.danger,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _UploadZone extends StatelessWidget {
  const _UploadZone({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconsaxPlusBold.gallery_add,
                size: 32,
                color: AppColors.primary,
              ),
              SizedBox(height: 8),
              Text(
                'Tambahkan Foto Bukti',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'JPG / PNG / WEBP, maks 5 MB',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({
    required this.file,
    required this.isUploading,
    required this.onReplace,
    required this.onRemove,
  });

  final File file;
  final bool isUploading;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: 180,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surfaceSunken,
                    alignment: Alignment.center,
                    child: const Icon(
                      IconsaxPlusBold.gallery_slash,
                      color: AppColors.textTertiary,
                      size: 32,
                    ),
                  ),
                ),
              ),
              if (isUploading)
                Container(
                  width: double.infinity,
                  height: 180,
                  color: AppColors.primaryDeep.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        IconsaxPlusBold.close_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onReplace,
          icon: const Icon(IconsaxPlusBold.refresh, size: 16),
          label: const Text('Ganti Foto'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}


// ============================================================================
// _StepReview — Step 4 (read-only summary)
// ============================================================================

class _StepReview extends StatelessWidget {
  const _StepReview({
    required this.session,
    required this.type,
    required this.reason,
    required this.evidencePath,
    required this.hasPickedImage,
  });

  final ActiveSession session;
  final LeaveType type;
  final String reason;
  final String? evidencePath;
  final bool hasPickedImage;

  @override
  Widget build(BuildContext context) {
    final time = _formatTimeOnly(session.startedAt);
    final hasEvidence = evidencePath != null || hasPickedImage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      children: [
        const Text(
          'Review',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cek lagi sebelum kamu kirim. Pengajuan akan diteruskan ke dosen.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        AppCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 14,
          child: Column(
            children: [
              _ReviewRow(
                icon: IconsaxPlusBold.calendar_2,
                label: 'SESI',
                value:
                    '${session.courseName} · Pertemuan ${session.sessionNumber}',
                sub: [
                  if (session.dosenName != null &&
                      session.dosenName!.trim().isNotEmpty)
                    session.dosenName!,
                  'Mulai $time',
                ].join(' · '),
              ),
              _ReviewRow(
                icon: type == LeaveType.sakit
                    ? IconsaxPlusBold.health
                    : IconsaxPlusBold.note_2,
                label: 'KETERANGAN',
                value: type.label,
              ),
              _ReviewRow(
                icon: IconsaxPlusBold.note_text,
                label: 'ALASAN',
                value: reason,
                multiline: true,
              ),
              _ReviewRow(
                icon: IconsaxPlusBold.gallery_add,
                label: 'LAMPIRAN',
                value:
                    hasEvidence ? '1 file dilampirkan' : 'Tidak ada lampiran',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.multiline = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final bool multiline;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                  maxLines: multiline ? null : 2,
                  overflow:
                      multiline ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                if (sub != null && sub!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _WizardFooter — pill button full-width di bawah
// ============================================================================

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: canTap ? AppShadows.fab : null,
            ),
            child: Material(
              color: canTap
                  ? AppColors.primary
                  : AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: canTap ? onTap : null,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.14,
                          color: canTap ? Colors.white : AppColors.textTertiary,
                        ),
                      ),
                      if (!loading && icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(icon, size: 18, color: canTap ? Colors.white : AppColors.textTertiary),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
