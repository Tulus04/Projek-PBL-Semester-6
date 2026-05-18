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

- [ ] 1. DB Migration

  - [ ] 1.1 Create migration `022_profiles_fcm_token.sql`
    - File path: `mypresensi-web/supabase/migrations/022_profiles_fcm_token.sql`
    - SQL: ADD COLUMN fcm_token + fcm_token_updated_at + partial index
    - Idempotent guard
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [ ] 1.2 Apply migration via MCP
    - Verify via list_migrations + execute_sql cek `information_schema.columns`
    - _Requirements: 1.5_

  - [ ] 1.3 Verify advisor security
    - 0 issue baru
    - _Requirements: 1.6, 16.1_

- [ ] 2. Backend Implementation

  - [ ] 2.1 Tambah `firebase-admin` di package.json
    - cwd: `mypresensi-web/`
    - `npm install firebase-admin`
    - _Requirements: 7.1_

  - [ ] 2.2 Create `app/lib/fcm-admin.ts`
    - Singleton init Firebase Admin SDK dari env var
    - Export `sendPushNotification(opts)` function per Algorithm 1
    - Handle token invalid: clear dari DB
    - logAudit per outcome
    - _Requirements: 7.3, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 13.1, 13.2, 13.3_

  - [ ] 2.3 Create endpoint `app/api/mobile/profile/fcm-token/route.ts`
    - POST handler dengan auth + Zod parse + UPDATE profiles
    - Audit log `mobile_fcm_token_register`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [ ] 2.4 Add ApiEndpoints constant `profileFcmToken` di mobile
    - File: `mypresensi-mobile/lib/core/network/api_endpoints.dart`
    - _Requirements: 2.1_

  - [ ] 2.5 Verify backend — type-check + lint
    - Expected: exit 0
    - _Requirements: 16.2_

- [ ] 3. Mobile Implementation

  - [ ] 3.1 Add dependencies di pubspec.yaml
    - `firebase_core`, `firebase_messaging`, `flutter_local_notifications`
    - `flutter pub get`
    - _Requirements: 3.1_

  - [ ] 3.2 Verify google-services.json placed correctly
    - File path: `mypresensi-mobile/android/app/google-services.json`
    - Verify Android Gradle plugin reads it (build.gradle.kts include `apply plugin: com.google.gms.google-services`)
    - _Requirements: 3.2_

  - [ ] 3.3 Update `android/app/build.gradle.kts` + `android/build.gradle.kts`
    - Add `com.google.gms:google-services` classpath
    - Apply plugin di app-level
    - _Requirements: 3.2_

  - [ ] 3.4 Initialize Firebase di `main.dart`
    - `await Firebase.initializeApp()` SEBELUM `runApp()`
    - Register `FirebaseMessaging.onBackgroundMessage` top-level handler
    - _Requirements: 3.3, 3.4_

  - [ ] 3.5 Create `lib/core/services/fcm_service.dart`
    - Static methods: initialize, getCurrentToken, registerTokenWithBackend, clearToken
    - Handle 3 lifecycle (foreground/background/terminated)
    - Listen onTokenRefresh
    - Use `flutter_local_notifications` untuk foreground banner
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [ ] 3.6 Permission flow Android 13+
    - Lazy: minta saat first login OR first buka tab Notifikasi
    - Pakai `permission_handler` package existing
    - Dialog gentle saat denied
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ] 3.7 Integrate FcmService ke auth flow
    - LoginNotifier: setelah login sukses → FcmService.initialize() + register token
    - LogoutNotifier: clear token via endpoint atau setNull lokal
    - _Requirements: 6.1, 6.2, 6.3_

  - [ ] 3.8 Deep link handler
    - Parse `data.route` dari payload
    - context.go(route) saat tap notif
    - Default fallback /notifications kalau route absent
    - _Requirements: 11.1, 11.2, 11.3_

  - [ ] 3.9 Verify mobile — flutter analyze
    - Expected: "No issues found."
    - _Requirements: 16.3_

- [ ] 4. Trigger Integration

  - [ ] 4.1 Modify `app/lib/actions/leave-requests.ts`
    - approveLeaveRequestAction: AFTER UPDATE status, call sendPushNotification(studentId, ...)
    - rejectLeaveRequestAction: same
    - Title: "Pengajuan Izin Disetujui/Ditolak", body MK + alasan singkat, route `/leave-requests`, type `leave_status`
    - _Requirements: 9.1, 9.2, 9.3, 14.2_

  - [ ] 4.2 Modify `app/lib/actions/sessions.ts`
    - toggleSessionAction: when is_active=true, fetch enrollments untuk MK tsb
    - Use `admin.messaging().sendEachForMulticast()` BATCH max 500 token per call
    - Title "Sesi Baru Dimulai", body "MK X · Pertemuan N", route `/scan`, type `session_start`
    - _Requirements: 10.1, 10.2, 10.3, 14.2_

  - [ ] 4.3 Verify backend trigger integration — type-check + lint
    - Expected: exit 0
    - _Requirements: 16.2_

- [ ] 5. Final Verification

  - [ ] 5.1 Build APK debug
    - cwd: `mypresensi-mobile/`
    - `flutter build apk --debug`
    - Expected: success
    - _Requirements: 16.4_

  - [ ] 5.2 Web build verify
    - cwd: `mypresensi-web/`
    - `npm run build`
    - Expected: exit 0
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
