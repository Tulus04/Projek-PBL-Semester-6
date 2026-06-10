// lib/features/auth/screens/login_screen.dart
// Halaman login mahasiswa — modern, clean, profesional.
// Terintegrasi dengan API /api/mobile/auth/login via Riverpod.
// Handle: loading, error, force change password.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    // Auto-fill email dari login terakhir (rule 04-security: email = Tier 2 PII,
    // OK disimpan secure storage). Password TIDAK pernah disimpan — user tetap
    // wajib ketik manual untuk re-login. Plus autofillHints di TextField biar
    // OS-level keychain (Smart Lock / Samsung Pass) bisa offer fill password.
    _loadLastLoginEmail();
  }

  Future<void> _loadLastLoginEmail() async {
    final email = await SecureStorage.getLastLoginEmail();
    if (!mounted || email == null || email.isEmpty) return;
    setState(() {
      _emailController.text = email;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Hapus keyboard
    FocusScope.of(context).unfocus();

    final success = await ref.read(authProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      // Login berhasil — GoRouter akan redirect ke home via auth state.
      // Tidak perlu navigasi manual.
      return;
    }

    final authState = ref.read(authProvider);

    // Jika mustChangePassword — GoRouter akan auto-redirect ke /change-password
    if (authState.mustChangePassword) return;

    // Tampilkan snackbar error
    final errorMsg = authState.errorMessage ?? 'Login gagal. Coba lagi.';
    _showErrorSnackbar(
      errorMsg.replaceAll('Exception: ', ''),
    );

    // Delay sebelum clear error: beri waktu GoRouter memproses state saat ini
    // agar tidak terjadi flicker (loading → error → unauthenticated → login form)
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    ref.read(authProvider.notifier).clearError();
  }

  /// DEV ONLY — auto-fill kredensial test + langsung submit.
  /// HANYA aktif saat `kDebugMode == true`. Di release build, panel quick login
  /// di-strip dari widget tree → method ini tidak pernah dipanggil.
  /// Tujuan: hilangkan friction "ketik email + password" saat dev/testing.
  Future<void> _quickLogin(String email, String password) async {
    _emailController.text = email;
    _passwordController.text = password;
    await _handleLogin();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(IconsaxPlusBold.warning_2, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Drag scroll → keyboard dismiss (Material standard pattern,
            // lebih intuitive dari tap-outside).
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // === Logo & Branding ===
                    _buildLogo(),
                    const SizedBox(height: 40),

                    // === Login Card ===
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppColors.border, width: 0.5),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masuk ke Akun',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gunakan akun yang terdaftar di sistem',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 28),

                            // Email Field
                            _buildLabel('Email'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !authState.isLoading,
                              // Email field — autocorrect off standar (jangan
                              // ubah email user), tapi suggestion ON supaya
                              // bar suggestion email muncul (UX umumnya Android).
                              autocorrect: false,
                              // OS-level autofill (Android Smart Lock / Samsung Pass).
                              autofillHints: const [
                                AutofillHints.email,
                                AutofillHints.username,
                              ],
                              decoration: const InputDecoration(
                                hintText: 'nama@politani.ac.id',
                                prefixIcon:
                                    Icon(IconsaxPlusLinear.sms, size: 20),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email tidak boleh kosong';
                                }
                                if (!value.contains('@')) {
                                  return 'Format email tidak valid';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Password Field
                            _buildLabel('Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              enabled: !authState.isLoading,
                              onFieldSubmitted: (_) => _handleLogin(),
                              // OS-level autofill — kalau user pernah save di
                              // Smart Lock / password manager, bisa offer fill.
                              // App TIDAK simpan password sendiri (rule 04-security).
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                hintText: 'Masukkan password',
                                prefixIcon: const Icon(IconsaxPlusLinear.lock_1,
                                    size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? IconsaxPlusLinear.eye_slash
                                        : IconsaxPlusLinear.eye,
                                    size: 20,
                                    color: AppColors.textTertiary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password tidak boleh kosong';
                                }
                                if (value.length < 6) {
                                  return 'Password minimal 6 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed:
                                    authState.isLoading ? null : _handleLogin,
                                child: authState.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Masuk'),
                              ),
                            ),

                            // DEV ONLY — Quick login panel (auto-strip di release build).
                            if (kDebugMode) ...[
                              const SizedBox(height: 20),
                              _DevQuickLoginPanel(
                                disabled: authState.isLoading,
                                onPick: _quickLogin,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Footer
                    Text(
                      'Butuh bantuan? Hubungi admin prodi.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'v1.0.0',
                      style: Theme.of(context).textTheme.labelSmall,
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

  Widget _buildLogo() {
    return Column(
      children: [
        // Logo icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            IconsaxPlusBold.finger_scan,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'MyPresensi',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'TRPL · Politani Samarinda',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
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
}


// ============================================================================
// DEV ONLY — Quick Login Panel
// ============================================================================
//
// Panel ini HANYA muncul saat `kDebugMode == true` (debug build).
// Di release build, Flutter compiler men-strip dead code di balik
// `if (kDebugMode)` → seluruh widget tree ini hilang dari binary.
//
// Tujuan: hilangkan friction "ketik email + password" saat dev/testing.
// Tap salah satu chip → kredensial auto-fill + langsung submit.
//
// Akun yang dipakai = sama dengan `mypresensi-web/.dev-accounts.md`.
// JANGAN tambah akun di sini yang TIDAK ada di .dev-accounts.md.

class _DevQuickLoginAccount {
  const _DevQuickLoginAccount({
    required this.label,
    required this.subtitle,
    required this.email,
    required this.password,
  });

  final String label;
  final String subtitle;
  final String email;
  final String password;
}

const _devAccounts = <_DevQuickLoginAccount>[
  _DevQuickLoginAccount(
    label: 'Mhs. Ahmad',
    subtitle: 'NIM H233600430',
    email: 'ahmad@student.ac.id',
    password: 'H233600430@politani',
  ),
  _DevQuickLoginAccount(
    label: 'Mhs. Siti',
    subtitle: 'NIM P2100002',
    email: 'siti.nurhaliza@student.ac.id',
    password: 'P2100002@politani',
  ),
  _DevQuickLoginAccount(
    label: 'Mhs. Budi',
    subtitle: 'NIM P2100003',
    email: 'budi.santoso@student.ac.id',
    password: 'P2100003@politani',
  ),
];

class _DevQuickLoginPanel extends StatelessWidget {
  const _DevQuickLoginPanel({
    required this.disabled,
    required this.onPick,
  });

  final bool disabled;
  final Future<void> Function(String email, String password) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_outlined,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                'DEV ONLY · QUICK LOGIN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Hilang otomatis di release build.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _devAccounts.map((acc) {
              return _DevAccountChip(
                account: acc,
                disabled: disabled,
                onTap: () => onPick(acc.email, acc.password),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DevAccountChip extends StatelessWidget {
  const _DevAccountChip({
    required this.account,
    required this.disabled,
    required this.onTap,
  });

  final _DevQuickLoginAccount account;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: disabled
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                account.subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontFamily: 'JetBrains Mono',
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
