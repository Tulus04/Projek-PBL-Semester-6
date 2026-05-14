// lib/features/leave_requests/screens/submit_leave_request_screen.dart
// Form mahasiswa mengajukan izin/sakit untuk sebuah sesi aktif.
// Mengambil daftar sesi aktif via activeSessionsProvider — user pilih dari dropdown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../attendance/data/attendance_models.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../data/leave_models.dart';
import '../providers/leave_provider.dart';

class SubmitLeaveRequestScreen extends ConsumerStatefulWidget {
  const SubmitLeaveRequestScreen({super.key});

  @override
  ConsumerState<SubmitLeaveRequestScreen> createState() =>
      _SubmitLeaveRequestScreenState();
}

class _SubmitLeaveRequestScreenState
    extends ConsumerState<SubmitLeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  ActiveSession? _selectedSession;
  LeaveType _selectedType = LeaveType.izin;

  @override
  void initState() {
    super.initState();
    // Reset state submit saat masuk screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(submitLeaveProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSession == null) {
      _showSnackbar('Pilih sesi terlebih dahulu', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await ref.read(submitLeaveProvider.notifier).submit(
          sessionId: _selectedSession!.id,
          type: _selectedType,
          reason: _reasonController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      final response = ref.read(submitLeaveProvider).response;
      _showSnackbar(
        response?.message ?? 'Pengajuan berhasil dikirim',
        isError: false,
      );
      // Pop dengan flag true agar caller bisa refresh list
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) context.pop(true);
      });
    } else {
      final err = ref.read(submitLeaveProvider).errorMessage;
      _showSnackbar(err ?? 'Gagal mengirim pengajuan', isError: true);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
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

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(activeSessionsProvider);
    final submitState = ref.watch(submitLeaveProvider);
    final isLoading = submitState.status == SubmitLeaveStatus.submitting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ajukan Izin / Sakit'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Info banner
              _buildInfoBanner(),
              const SizedBox(height: 20),

              // Pilih sesi
              _buildSectionLabel('Sesi Perkuliahan'),
              const SizedBox(height: 8),
              sessionsAsync.when(
                data: (sessions) {
                  // Filter: hanya sesi aktif yang BELUM ada presensi
                  final eligible =
                      sessions.where((s) => !s.alreadySubmitted).toList();

                  if (eligible.isEmpty) {
                    return _buildEmptySessionState();
                  }
                  return _buildSessionDropdown(eligible);
                },
                loading: () => _buildSkeletonField(),
                error: (e, _) => _buildErrorField(
                  'Gagal memuat sesi: ${e.toString()}',
                  () => ref.invalidate(activeSessionsProvider),
                ),
              ),
              const SizedBox(height: 20),

              // Pilih tipe
              _buildSectionLabel('Jenis Pengajuan'),
              const SizedBox(height: 8),
              _buildTypeSelector(),
              const SizedBox(height: 20),

              // Alasan
              _buildSectionLabel('Alasan'),
              const SizedBox(height: 8),
              _buildReasonField(),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kirim Pengajuan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pengajuan izin/sakit harus disetujui oleh dosen pengampu. Status akan muncul di daftar pengajuan setelah dikirim.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSessionDropdown(List<ActiveSession> eligible) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ActiveSession>(
          value: _selectedSession,
          isExpanded: true,
          hint: const Text(
            'Pilih sesi yang akan diajukan izin',
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
          icon: const Icon(Icons.expand_more, color: AppColors.textTertiary),
          items: eligible.map((session) {
            return DropdownMenuItem<ActiveSession>(
              value: session,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.courseName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Pertemuan ${session.sessionNumber}'
                    '${session.topic != null ? ' — ${session.topic}' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedSession = value),
        ),
      ),
    );
  }

  Widget _buildEmptySessionState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tidak ada sesi aktif yang bisa diajukan izin saat ini.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonField() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildErrorField(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: LeaveType.values.map((type) {
        final isSelected = _selectedType == type;
        final icon = type == LeaveType.sakit
            ? Icons.healing_outlined
            : Icons.event_note_outlined;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type == LeaveType.values.first ? 8 : 0,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedType = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReasonField() {
    return TextFormField(
      controller: _reasonController,
      maxLines: 5,
      maxLength: 500,
      decoration: InputDecoration(
        hintText: 'Tulis alasan izin/sakit yang spesifik (minimal 10 karakter)',
        hintStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.all(14),
        counterStyle: const TextStyle(
          fontSize: 11,
          color: AppColors.textTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Alasan wajib diisi';
        if (v.length < 10) return 'Alasan minimal 10 karakter';
        if (v.length > 500) return 'Alasan maksimal 500 karakter';
        return null;
      },
    );
  }
}
