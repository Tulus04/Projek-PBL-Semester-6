# Implementation Plan: Onboarding Mobile 3-Step

## Overview

Implementation order:
1. **Dependency check** — pastikan `shared_preferences` di pubspec.
2. **Onboarding screen** + sub-components.
3. **Route setup** di `app_router.dart`.
4. **Splash redirect logic** — cek flag sebelum session check.
5. **Verification** — `flutter analyze` clean.
6. **Manual smoke test** — cold install user-action.

Effort estimasi: ~2 jam.

## Tasks

- [ ] 0. Dependency Check

  - [ ] 0.1 Cek + install `shared_preferences`
    - cwd: `mypresensi-mobile/`
    - Cek `pubspec.yaml` apakah `shared_preferences` sudah ada
    - Kalau belum: `flutter pub add shared_preferences`
    - Kalau sudah: skip
    - Run `flutter pub get` untuk pastikan dependencies sync
    - _Requirements: 11.1, 11.2, 11.3_

- [ ] 1. Onboarding Screen

  - [ ] 1.1 Create `lib/features/onboarding/screens/onboarding_screen.dart`
    - File path: `mypresensi-mobile/lib/features/onboarding/screens/onboarding_screen.dart`
    - Komentar header Bahasa Indonesia
    - `ConsumerStatefulWidget` dengan `PageController` + `currentPage` state
    - Sub-components private (semua di file yang sama):
      - `_OnboardingTopbar` — Skip button + Step Indicator dot
      - `_OnboardingStep1` — Welcome (illustration card primary + title + subtitle)
      - `_OnboardingStep2` — Cara Pakai (illustration card success + 3 feature items)
      - `_OnboardingStep3` — Get Started (illustration card amber + privacy points)
      - `_StepDot` — animated dot indicator (active 24px, inactive 8px)
      - `_IllustrationCard` — 200×200 gradient + icon
      - `_FeatureListItem` — icon wrap + name + desc
      - `_PrivacyPoint` — check icon + text
      - `_OnboardingFooterButton` — pill primary
    - Helper methods:
      - `Future<void> _markOnboardingSeen()` — set flag SharedPreferences
      - `void _handleSkip()` — set flag + go('/login')
      - `void _handleFinish()` — set flag + go('/login')
      - `void _handleNext()` — animate PageController atau finish kalau di step 3
    - Layout: Column(Topbar + Expanded(PageView) + Footer button)
    - Background gradient `LinearGradient` 180deg `[bg, surface]`
    - Radial accent overlay (Container with `decoration: BoxDecoration(gradient: RadialGradient(...))`)
    - Match mockup `docs/ui-research/mockups/mobile-onboarding.html`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 6.1, 6.2, 6.3, 6.4, 6.5, 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 10.1, 10.2_

- [ ] 2. Route Setup

  - [ ] 2.1 Tambah `/onboarding` route di `core/router/app_router.dart`
    - File path: `mypresensi-mobile/lib/core/router/app_router.dart`
    - Tambah GoRoute new di routes list:
      ```dart
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const OnboardingScreen(),
        ),
      ),
      ```
    - Import `OnboardingScreen` from feature folder
    - _Requirements: 1.1, 1.2, 1.3_

- [ ] 3. Splash Modification

  - [ ] 3.1 Tambah cek `hasSeenOnboarding` di `splash_screen.dart`
    - File path: `mypresensi-mobile/lib/features/auth/screens/splash_screen.dart`
    - Cari method yang handle initial routing (mis. `_initialRouteCheck()` atau `initState` async)
    - SEBELUM existing session check, tambah:
      ```dart
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      if (!hasSeenOnboarding) {
        if (mounted) context.go('/onboarding');
        return;
      }
      ```
    - Import `package:shared_preferences/shared_preferences.dart`
    - JANGAN ubah existing session check logic
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 4. Verification

  - [ ] 4.1 Run `flutter analyze`
    - cwd: `mypresensi-mobile/`
    - Expected: "No issues found."
    - Fix issue sebelum mark task complete
    - _Requirements: 12.1_

  - [ ] 4.2 (Optional) Run `flutter pub get` to confirm dependencies
    - Expected: success, no version conflict
    - _Requirements: 11.3, 12.2_

- [ ] 5. Manual Smoke Test (user-action)

  - [ ] 5.1 Cold install + onboarding flow
    - **NOTE**: User-action manual.
    - Steps:
      - (a) Uninstall app (atau pakai emulator fresh) → install ulang
      - (b) Buka app → splash dwell ~2s → verify navigate ke /onboarding (BUKAN /login)
      - (c) Verify Step 1 visual: brand tag, illustration card primary gradient + hand-shake icon, title "Selamat Datang", subtitle, tombol "Lanjut" + tombol "Lewati" top-right
      - (d) Tap "Lanjut" → verify slide animasi ke Step 2
      - (e) Verify Step 2 visual: illustration card success + shield icon, feature list 3-item duotone (QR primary / GPS warning / Face success)
      - (f) Tap "Lanjut" → verify slide ke Step 3
      - (g) Verify Step 3 visual: illustration card amber + rocket icon, privacy summary 2 point, tombol "Masuk Sekarang"
      - (h) Tap "Masuk Sekarang" → verify navigate ke /login
      - (i) Restart app (kill + buka lagi) → verify TIDAK lagi muncul onboarding (langsung splash → /login)
      - (j) Test skip path: uninstall + reinstall → di Step 1 tap "Lewati" → verify navigate /login + flag set
    - User SHALL document hasil di `dev-log.md` atau `CHANGELOG.md`
    - _Requirements: 12.3_

## Notes

- Setiap task reference `_Requirements: X.Y_` untuk traceability.
- File baru (1):
  1. `mypresensi-mobile/lib/features/onboarding/screens/onboarding_screen.dart`
- File modified (2):
  1. `mypresensi-mobile/lib/core/router/app_router.dart` (tambah route)
  2. `mypresensi-mobile/lib/features/auth/screens/splash_screen.dart` (tambah cek flag)
- Dependency baru (1, kalau belum ada): `shared_preferences`
- Tidak ada migration DB. Tidak ada perubahan API.
- Reuse: `AppColors`, `AppShadows`, `AppRadius` tokens, `iconsax_plus`, `go_router`, `flutter_riverpod`.
