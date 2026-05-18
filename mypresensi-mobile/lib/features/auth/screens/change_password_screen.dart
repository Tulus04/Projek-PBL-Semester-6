// lib/features/auth/screens/change_password_screen.dart
// Halaman force change password — ditampilkan saat mahasiswa login pertama kali.
// Validasi real-time: min 8 karakter, huruf kapital, angka.
// Setelah berhasil ganti, redirect otomatis ke home via auth state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // Password strength checks — match dengan Supabase Auth project policy
  // (settings → Authentication → Password requirements: lower + upper + digit).
  bool get _hasMinLength => _newPasswordController.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newPasswordController.text);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_newPasswordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newPasswordController.text);
  bool get _allValid =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber;

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allValid) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(authProvider.notifier).changePassword(
            newPassword: _newPasswordController.text,
            confirmPassword: _confirmPasswordController.text,
          );

      if (!mounted) return;

      if (!success) {
        setState(() {
          _errorMessage = 'Gagal mengubah password. Silakan coba lagi.';
        });
      }
      // Jika success, GoRouter akan auto-redirect ke home karena
      // auth state berubah ke AuthStatus.authenticated
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.fullName ?? 'Mahasiswa';

    return Scaffold(
      // Tap area kosong → dismiss keyboard + clear text selection (Issue #2).
      // GestureDetector dengan behavior:opaque hanya respond di area tidak-tertutup
      // child interactive (TextField, Button) → tidak ganggu single-tap pada field.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // === Header Icon ===
                  _buildHeader(),
                  const SizedBox(height: 32),

                  // === Card ===
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      // AutofillGroup — supaya OS-level password manager
                      // (Smart Lock / Samsung Pass) treat kedua field password
                      // sebagai satu form newPassword + confirm. UX consistent
                      // dengan login_screen yang juga punya autofill hints.
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Greeting
                          Text(
                            'Halo, $userName!',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Silakan ubah password Anda sebelum melanjutkan.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),

                          // Info box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.infoSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.info.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: AppColors.info, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ini adalah login pertama Anda. Password baru harus memenuhi syarat keamanan di bawah.',
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.info),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Error message
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.danger, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // New Password
                          _buildLabel('Password Baru'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNew,
                            enabled: !_isSubmitting,
                            textInputAction: TextInputAction.next,
                            // Match UX login_screen — disable suggestion/autocorrect
                            // untuk hindari interference dengan tap gesture di Realme.
                            autocorrect: false,
                            enableSuggestions: false,
                            // OS-level password manager autofill hint.
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Masukkan password baru',
                              prefixIcon:
                                  const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNew
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppColors.textTertiary,
                                ),
                                onPressed: () =>
                                    setState(() => _obscureNew = !_obscureNew),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password baru tidak boleh kosong';
                              }
                              if (value.length < 8) {
                                return 'Password minimal 8 karakter';
                              }
                              return null;
                            },
                          ),

                          // Strength indicators
                          if (_newPasswordController.text.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildStrengthItem(_hasMinLength, 'Minimal 8 karakter'),
                            const SizedBox(height: 4),
                            _buildStrengthItem(
                                _hasUppercase, 'Mengandung huruf kapital (A-Z)'),
                            const SizedBox(height: 4),
                            _buildStrengthItem(
                                _hasLowercase, 'Mengandung huruf kecil (a-z)'),
                            const SizedBox(height: 4),
                            _buildStrengthItem(
                                _hasNumber, 'Mengandung angka (0-9)'),
                          ],
                          const SizedBox(height: 18),

                          // Confirm Password
                          _buildLabel('Konfirmasi Password'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            enabled: !_isSubmitting,
                            textInputAction: TextInputAction.done,
                            // Match UX login_screen — disable suggestion/autocorrect.
                            autocorrect: false,
                            enableSuggestions: false,
                            // OS-level — same new-password context.
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) => _handleSubmit(),
                            decoration: InputDecoration(
                              hintText: 'Ketik ulang password baru',
                              prefixIcon:
                                  const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppColors.textTertiary,
                                ),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Konfirmasi password tidak boleh kosong';
                              }
                              if (value != _newPasswordController.text) {
                                return 'Password tidak cocok';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _handleSubmit,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Simpan',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Logout link — eksplisit konsekuensi (bukan sekadar kembali).
                  // User keluar dari force-change-password flow = logout + hapus token.
                  TextButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => ref.read(authProvider.notifier).logout(),
                    icon: const Icon(
                      Icons.logout_outlined,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    label: const Text(
                      'Logout & kembali ke login',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset,
            color: AppColors.warning,
            size: 32,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ubah Password',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
    );
  }

  Widget _buildStrengthItem(bool valid, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: valid ? AppColors.success : AppColors.border,
            shape: BoxShape.circle,
          ),
          child: valid
              ? const Icon(Icons.check, size: 10, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: valid ? AppColors.success : AppColors.textTertiary,
            fontWeight: valid ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
