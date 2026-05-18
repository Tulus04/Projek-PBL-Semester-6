# Requirements Document

## Introduction

Phase B3: Onboarding 3-step (Welcome → Cara Pakai → Get Started) untuk mobile MyPresensi. Tampil sekali saat first install via flag `SharedPreferences.hasSeenOnboarding`. Mockup: `docs/ui-research/mockups/mobile-onboarding.html` (baru dibuat).

User decisions sebelum spec: 3 step content (welcome + cara pakai + get started), visual sesuai design system mobile (Iconsax Bold + #2D86FF gradient), TIDAK include consent UU PDP (consent face tetap di Face Register existing).

Effort: ~2 jam.

## Glossary

- **Onboarding_Screen**: Layar `lib/features/onboarding/screens/onboarding_screen.dart` baru.
- **Page_View**: Flutter `PageView` widget untuk swipe horizontal antar step.
- **Page_Controller**: `PageController` untuk programmatic navigation (skip ke step terakhir).
- **Step_Indicator**: 3 dot di top center yang animasi width saat active step berubah.
- **Has_Seen_Onboarding**: Boolean flag di `SharedPreferences` (key: `'hasSeenOnboarding'`).
- **Splash_Screen**: Existing screen `lib/features/auth/screens/splash_screen.dart` yang akan ditambah cek flag.
- **GoRouter**: `go_router` package existing di `core/router/app_router.dart`.
- **App_Colors**: Theme tokens existing di `lib/core/theme/app_colors.dart`.
- **iconsax_plus**: Package icon existing dengan Bold variant.

## Requirements

### Requirement 1: Route Setup

#### Acceptance Criteria

1. THE Mobile_App SHALL menambah route baru `/onboarding` di `core/router/app_router.dart` GoRouter config.
2. THE route SHALL pakai `_fadeTransition` helper existing.
3. THE route SHALL render `OnboardingScreen` (Component 3).

### Requirement 2: Splash Redirect Logic

#### Acceptance Criteria

1. WHEN user buka app di splash, THE Splash_Screen SHALL cek `Has_Seen_Onboarding` flag dari SharedPreferences SEBELUM session check existing.
2. WHEN flag = false (atau null/default), THE Splash_Screen SHALL redirect `context.go('/onboarding')`.
3. WHEN flag = true, THE Splash_Screen SHALL lanjut existing flow (session check → /home atau /login).
4. THE Splash_Screen SHALL TIDAK modify flag itself — hanya read.

### Requirement 3: 3-Step PageView

#### Acceptance Criteria

1. THE Onboarding_Screen SHALL render PageView dengan 3 page (Welcome / Cara Pakai / Get Started).
2. THE PageView SHALL gunakan `physics: ClampingScrollPhysics()` agar swipe natural.
3. THE PageView SHALL emit `onPageChanged` callback yang update local state `currentPage`.
4. THE animation transition SHALL 300ms `Curves.easeInOut`.

### Requirement 4: Step Indicator

#### Acceptance Criteria

1. THE Step_Indicator SHALL render 3 dot horizontal di top center area.
2. THE active dot SHALL berwidth 24px, inactive 8px (square ratio).
3. THE active dot color SHALL `AppColors.primary`, inactive `AppColors.primary` 20% alpha.
4. THE width transition SHALL animasi 300ms `Curves.easeInOut`.

### Requirement 5: Skip Button

#### Acceptance Criteria

1. THE Onboarding_Screen SHALL menampilkan tombol "Lewati" di top-right pada step 1 dan step 2.
2. THE step 3 SHALL TIDAK menampilkan tombol "Lewati" (final step, langsung "Masuk Sekarang").
3. WHEN user tap "Lewati", THE app SHALL set flag `Has_Seen_Onboarding = true` AND navigate `context.go('/login')`.

### Requirement 6: Step 1 — Welcome

#### Acceptance Criteria

1. THE step 1 SHALL menampilkan brand tag pill "Politani Samarinda" dengan icon verified.
2. THE step 1 SHALL menampilkan illustration card 200×200 dengan gradient `AppColors.primary → AppColors.primaryDark`, icon `IconsaxPlusBold.hand_shake` (atau equivalent), shadow primary.
3. THE step 1 SHALL menampilkan title "Selamat Datang di MyPresensi" (Plus Jakarta Sans w800 28pt).
4. THE step 1 SHALL menampilkan subtitle copy: "Sistem absensi pintar dengan tiga lapis verifikasi — QR Code, GPS, dan Face Recognition. Khusus mahasiswa Prodi TRPL Politeknik Pertanian Negeri Samarinda."
5. THE step 1 footer SHALL menampilkan tombol "Lanjut" pill primary dengan icon arrow-right.

### Requirement 7: Step 2 — Cara Pakai

#### Acceptance Criteria

1. THE step 2 SHALL menampilkan illustration card 200×200 dengan gradient success light, icon `IconsaxPlusBold.shield_tick` warna success.
2. THE step 2 SHALL menampilkan title "Cara Kerja Presensi" + subtitle penjelas tentang 3-layer.
3. THE step 2 SHALL menampilkan feature list 3-item:
   - "1. Scan QR Code Sesi" — icon `qr_code` color primary, deskripsi
   - "2. Verifikasi Lokasi GPS" — icon `location` color warning, deskripsi
   - "3. Face Recognition" — icon `scan` (atau face) color success, deskripsi
4. THE feature item SHALL menggunakan card putih dengan shadow `AppShadows.card`.
5. THE step 2 footer SHALL menampilkan tombol "Lanjut".

### Requirement 8: Step 3 — Get Started

#### Acceptance Criteria

1. THE step 3 SHALL menampilkan illustration card dengan gradient amber light, icon `IconsaxPlusBold.rocket` (atau equivalent).
2. THE step 3 SHALL menampilkan title "Siap Untuk Mulai?" + subtitle tentang login dengan NIM.
3. THE step 3 SHALL menampilkan privacy summary 2 point dengan check icon success:
   - "Data kamu disimpan aman dan hanya dipakai internal kampus"
   - "Bisa hapus data wajah kapan saja lewat menu Profil"
4. THE step 3 SHALL TIDAK menampilkan consent UU PDP formal (compliance tetap di Face Register screen).
5. THE step 3 footer SHALL menampilkan tombol "Masuk Sekarang" pill primary dengan icon login.
6. WHEN user tap "Masuk Sekarang", THE app SHALL set flag `Has_Seen_Onboarding = true` AND navigate `context.go('/login')`.

### Requirement 9: Visual Style — Sesuai Design System

#### Acceptance Criteria

1. THE Onboarding_Screen SHALL pakai background gradient `linear-gradient(180deg, #f8fafc 0%, #ffffff 60%)` (atau equivalent token).
2. THE radial accents SHALL ada di top-right (primary alpha) dan top-left (accent alpha) — match mockup.
3. THE color tokens SHALL pakai `AppColors.*` semua, BUKAN hardcode hex.
4. THE icons SHALL pakai `IconsaxPlusBold` variant.
5. THE button SHALL pakai pill shape (`AppRadius.button = 999`), font Plus Jakarta Sans w700.
6. THE shadow SHALL pakai `AppShadows.button` atau equivalent token.

### Requirement 10: Bahasa Indonesia Copy

#### Acceptance Criteria

1. THE Onboarding_Screen SHALL menampilkan semua label visible dalam Bahasa Indonesia natural.
2. THE copy SHALL mengikuti tone yang sudah established di mockup HTML `mobile-onboarding.html`.

### Requirement 11: Library Dependencies

#### Acceptance Criteria

1. THE Mobile_App SHALL menggunakan `shared_preferences` package untuk flag storage.
2. WHEN `shared_preferences` belum ada di `pubspec.yaml`, THE pengembang SHALL install via `flutter pub add shared_preferences`.
3. THE versi SHALL kompatibel dengan Flutter 3.11.4 SDK.

### Requirement 12: Verification Gate

#### Acceptance Criteria

1. WHEN engineer menyelesaikan implementasi, THE engineer SHALL menjalankan `flutter analyze` di `mypresensi-mobile/` dan memastikan "No issues found".
2. WHEN engineer menambah dependency baru (`shared_preferences`), THE engineer SHALL `flutter pub get` sukses.
3. THE manual smoke test SHALL dilakukan oleh user: cold install → onboarding muncul → swipe 3 step → tap Masuk → ke /login.

### Requirement 13: Out of Scope

#### Acceptance Criteria

1. THE spec ini SHALL TIDAK include consent UU PDP formal di onboarding (tetap di Face Register screen existing).
2. THE spec ini SHALL TIDAK include animasi Lottie atau library complex animation.
3. THE spec ini SHALL TIDAK refactor splash screen UI (hanya tambah logic check flag).
4. THE spec ini SHALL TIDAK localize ke bahasa lain (Bahasa Indonesia only).
