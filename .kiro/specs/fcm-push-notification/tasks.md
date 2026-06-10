# Implementation Plan: FCM Push Notification

## Overview

Implementation order:
1. **Documentation Firebase setup** untuk user (kritis — setup blocker)
2. **DB Migration** — kolom fcm_token di profiles
3. **Backend** — endpoint token registration + Firebase Admin SDK + sendPush utility
4. **Mobile** — Firebase setup, permission, FCM service, token registration
5. **Trigger integration** — leave + session
6. **Verification** — type-check, lint, analyze, build
7. **Manual smoke test** — HP fisik (user-action)

Effort: **1-2 hari** realistis.

## Tasks

- [ ] 0. Documentation Firebase Setup (USER-ACTION REQUIRED)

  - [x] 0.1 Tulis `docs/setup/firebase-setup.md` dengan step-by-step Firebase project creation + service account + google-services.json
    - File path: `docs/setup/firebase-setup.md`
    - Coverage: Console Firebase create project, add Android app dengan packageName match, download google-services.json, generate service account JSON, env var setup di Vercel + .env.local, verify via test push
    - Include troubleshooting common errors
    - _Requirements: 17.1, 17.2, 17.3_

  - [ ] 0.2 USER-ACTION: setup Firebase project sesuai dokumentasi
    - **NOTE**: Dilakukan oleh user, bukan agent.
    - User SHALL: buat Firebase project, download google-services.json + tempatkan di `mypresensi-mobile/android/app/`, generate service account JSON + set env var `FIREBASE_SERVICE_ACCOUNT` di `.env.local`
    - User SHALL: report ke chat saat setup selesai sebelum lanjut task implementasi
    - _Requirements: 3.2, 7.2, 7.4_

- [x] 1. DB Migration

  - [x] 1.1 Create migration `023_profiles_fcm_token.sql`
    - File path: `mypresensi-web/supabase/migrations/023_profiles_fcm_token.sql` (022 sudah dipakai rolling_qr_seed → naik ke 023)
    - SQL: ADD COLUMN fcm_token + fcm_token_updated_at + partial index
    - Idempotent guard
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [x] 1.2 Apply migration via MCP
    - Applied as `profiles_fcm_token`. Verified via information_schema: fcm_token (text, nullable), fcm_token_updated_at (timestamptz, nullable), index idx_profiles_fcm_token present.
    - _Requirements: 1.5_

  - [x] 1.3 Verify advisor security
    - 0 issue baru (hanya pre-existing auth_leaked_password_protection WARN, tidak terkait).
    - _Requirements: 1.6, 16.1_

- [x] 2. Backend Implementation

  - [x] 2.1 Tambah `firebase-admin` di package.json
    - Installed firebase-admin v13.10.0 (cwd: mypresensi-web/)
    - _Requirements: 7.1_

  - [x] 2.2 Create `app/lib/fcm-admin.ts`
    - Singleton init Firebase Admin SDK dari env FIREBASE_SERVICE_ACCOUNT
    - `sendPushNotification(opts)` per Algorithm 1 + `sendPushToMany()` batch (sendEachForMulticast, chunk 500)
    - Token invalid (messaging/registration-token-not-registered) → clear dari DB
    - logAudit per outcome (fcm_push_sent/skipped/failed/token_invalid). API diverifikasi via Context7.
    - _Requirements: 7.3, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 13.1, 13.2, 13.3_

  - [x] 2.3 Create endpoint `app/api/mobile/profile/fcm-token/route.ts`
    - POST: authenticateRequest + Zod (fcm_token 1-1000 char) + UPDATE profiles (student_id dari auth, anti-IDOR)
    - Audit log `mobile_fcm_token_register` (userId + ipAddress eksplisit per BUG-011)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 2.4 Add ApiEndpoints constant `profileFcmToken` di mobile
    - `/api/mobile/profile/fcm-token` di api_endpoints.dart
    - _Requirements: 2.1_

  - [x] 2.5 Verify backend — type-check + lint
    - TYPECHECK_EXIT=0, LINT_EXIT=0 ("No ESLint warnings or errors")
    - _Requirements: 16.2_

- [x] 3. Mobile Implementation

  - [x] 3.1 Add dependencies di pubspec.yaml
    - firebase_core ^4.9.0, firebase_messaging ^16.2.2, flutter_local_notifications ^18.0.1 (resolved via flutter pub add)
    - _Requirements: 3.1_

  - [x] 3.2 Verify google-services.json placed correctly
    - File ada di android/app/google-services.json (project_id=mypresensi-pbl, package match). git-ignored.
    - _Requirements: 3.2_

  - [x] 3.3 Update `android/app/build.gradle.kts` + `settings.gradle.kts`
    - google-services plugin v4.4.2 di settings.gradle.kts (apply false) + apply di app-level plugins block
    - _Requirements: 3.2_

  - [x] 3.4 Initialize Firebase di `main.dart`
    - Firebase.initializeApp() + FirebaseMessaging.onBackgroundMessage(top-level handler) SEBELUM runApp, dibungkus try/catch
    - _Requirements: 3.3, 3.4_

  - [x] 3.5 Create `lib/core/services/fcm_service.dart`
    - Static: initialize, getCurrentToken, registerTokenWithBackend, clearToken + setNavigationCallback
    - 3 lifecycle (onMessage foreground banner via flutter_local_notifications, onMessageOpenedApp background, getInitialMessage terminated) + onTokenRefresh. API diverifikasi Context7.
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 3.6 Permission flow Android 13+
    - Permission.notification.request() via permission_handler + POST_NOTIFICATIONS di AndroidManifest
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 3.7 Integrate FcmService ke auth flow
    - login sukses → FcmService.initialize() (non-blocking). logout → FcmService.clearToken() sebelum clear storage.
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 3.8 Deep link handler
    - main.dart setNavigationCallback: '/notifications' → setTab(3)+go('/') (bukan GoRoute), route lain → router.go(route). Fallback '/notifications'.
    - _Requirements: 11.1, 11.2, 11.3_

  - [x] 3.9 Verify mobile — flutter analyze
    - "No issues found! (ran in 21.1s)"
    - _Requirements: 16.3_

- [x] 4. Trigger Integration

  - [x] 4.1 Modify `app/lib/actions/leave-requests.ts`
    - approveLeaveRequest + rejectLeaveRequest: panggil sendPushNotification setelah createNotification (polling fallback tetap — D12)
    - Title "Pengajuan Izin Disetujui/Ditolak", route `/leave-requests`, type `leave_status`. Reject TIDAK sertakan reviewNote di body (privacy R14.2).
    - _Requirements: 9.1, 9.2, 9.3, 14.2_

  - [x] 4.2 Modify `app/lib/actions/sessions.ts`
    - toggleSessionAction (is_active=true): sendPushToMany ke semua enrolled (sendEachForMulticast chunk 500)
    - Title "Sesi Presensi Dimulai", route `/scan`, type `session_start`
    - _Requirements: 10.1, 10.2, 10.3, 14.2_

  - [x] 4.3 Verify backend trigger integration — type-check + lint
    - TYPECHECK_EXIT=0, LINT_EXIT=0 ("No ESLint warnings or errors")
    - _Requirements: 16.2_

- [x] 5. Final Verification

  - [x] 5.1 Build APK debug
    - `flutter build apk --debug` → "Built build\app\outputs\flutter-apk\app-debug.apk" (228.6 MB debug)
    - FIX-1: flutter_local_notifications v18 butuh core library desugaring → enable `isCoreLibraryDesugaringEnabled` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` di app build.gradle.kts
    - FIX-2: JBR 21 (Android Studio baru) → "Inconsistent JVM-target" (tflite_flutter Java 11 vs Kotlin 17). Fix resmi Kotlin: `kotlin.jvm.target.validation.mode=warning` di gradle.properties (bytecode 11 & 17 interop aman di runtime JDK 21)
    - _Requirements: 16.4_

  - [x] 5.2 Web build verify
    - `npm run build` → compiled successfully, semua route ter-render, no error marker
    - _Requirements: 16.2_

- [ ] 6. Manual Smoke Test (USER-ACTION HP FISIK)

  - [ ] 6.1 Cold install APK ke HP fisik
    - User install APK debug ke HP Android API 26+
    - User SHALL bukan emulator (FCM emulator unreliable)
    - _Requirements: 15.1_

  - [ ] 6.2 Test login + token registration
    - Login mahasiswa di HP
    - Check console log: "fcm_token registered: ..."
    - Verify DB: `SELECT fcm_token FROM profiles WHERE id = ...` non-null
    - _Requirements: 6.1, 15.2_

  - [ ] 6.3 Test leave_request push
    - Web admin/dosen approve leave_request mahasiswa tsb
    - Within 5 detik: notif muncul di HP screen lock
    - Tap notif → app open ke /leave-requests
    - _Requirements: 9.1, 11.1, 15.2_

  - [ ] 6.4 Test session start push
    - Dosen "Mulai Sesi" via web
    - All enrolled students dapat notif
    - _Requirements: 10.1, 15.2_

  - [ ] 6.5 Test foreground/background/terminated lifecycle
    - Foreground: in-app banner muncul
    - Background: system notif muncul
    - Terminated: app open via tap → navigate correctly
    - _Requirements: 5.3, 11.1, 15.2_

  - [ ] 6.6 Document smoke test result
    - User update `dev-log.md` dengan tanggal + result
    - _Requirements: 15.3_

## Notes

- Task 0.1 (dokumentasi setup) DAN 0.2 (user-action setup) wajib selesai SEBELUM task 1+
- Task 6.x dilakukan oleh user manual di HP fisik
- File baru (5 + 1 doc):
  1. `docs/setup/firebase-setup.md`
  2. `mypresensi-web/supabase/migrations/022_profiles_fcm_token.sql`
  3. `mypresensi-web/app/lib/fcm-admin.ts`
  4. `mypresensi-web/app/api/mobile/profile/fcm-token/route.ts`
  5. `mypresensi-mobile/lib/core/services/fcm_service.dart`
- File modified:
  1. `mypresensi-mobile/pubspec.yaml`
  2. `mypresensi-mobile/android/app/build.gradle.kts`
  3. `mypresensi-mobile/android/build.gradle.kts`
  4. `mypresensi-mobile/lib/main.dart`
  5. `mypresensi-mobile/lib/core/network/api_endpoints.dart`
  6. `mypresensi-mobile/lib/features/auth/providers/auth_provider.dart`
  7. `mypresensi-web/app/lib/actions/leave-requests.ts`
  8. `mypresensi-web/app/lib/actions/sessions.ts`
  9. `mypresensi-web/package.json`
- Files placed by user:
  1. `mypresensi-mobile/android/app/google-services.json` (DO NOT commit)
  2. `mypresensi-web/.env.local` add `FIREBASE_SERVICE_ACCOUNT=...`
- New deps: 3 mobile + 1 web
- Migration baru: 1
- Endpoint baru: 1 (`/profile/fcm-token`)
