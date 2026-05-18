# Requirements Document

## Introduction

Phase P4-#4: FCM Push Notification untuk MyPresensi mobile. Trigger immediate (leave_request approve/reject + session start) plus deferred (face register reminder via cron). Backward compatible dengan polling endpoint existing.

User decisions:
- Scope: full-blown (1-2 hari effort) — bukan minimal
- Setup Firebase project: manual oleh user (saya tidak bisa create akun)

## Glossary

- **FCM**: Firebase Cloud Messaging — Google service untuk push notification.
- **FCM_Token**: Device-specific string token yang FCM generate. Disimpan di `profiles.fcm_token`.
- **Service_Account**: Firebase Admin SDK credentials JSON. Stored sebagai env var `FIREBASE_SERVICE_ACCOUNT`.
- **google-services.json**: Konfigurasi Firebase untuk Android. Disimpan di `mypresensi-mobile/android/app/`.
- **Push_Payload**: Data dikirim via FCM gateway: `{ notification: { title, body }, data: { route, type, related_id? } }`.
- **Trigger_Point**: Server action yang trigger push notification (mis. approve leave, start session).
- **firebase_messaging**: Flutter package.
- **firebase-admin**: Node package untuk server-side push.
- **Permission_Notif**: Android 13+ runtime permission `POST_NOTIFICATIONS`.

## Requirements

### Requirement 1: Migration FCM Token Column

#### Acceptance Criteria

1. THE Web_App backend SHALL menambah migration baru `022_profiles_fcm_token.sql`.
2. THE migration SHALL menambah `fcm_token TEXT NULL` + `fcm_token_updated_at TIMESTAMPTZ NULL` ke tabel `profiles`.
3. THE migration SHALL idempotent (`ADD COLUMN IF NOT EXISTS`).
4. THE migration SHALL menambah partial index `idx_profiles_fcm_token` untuk query token cepat (WHERE fcm_token IS NOT NULL).
5. THE migration SHALL diapply via `mcp_apply_migration`.
6. WHEN migration diapply, THE pengembang SHALL `mcp_get_advisors security` 0 issue baru.

### Requirement 2: Endpoint Token Registration

#### Acceptance Criteria

1. THE Web_App backend SHALL menyediakan endpoint baru `POST /api/mobile/profile/fcm-token`.
2. THE endpoint SHALL `authenticateRequest()` dengan Bearer JWT mahasiswa.
3. THE endpoint SHALL Zod parse body `{ fcm_token: string }` (min 1 char, max 1000 char).
4. THE endpoint SHALL UPDATE `profiles SET fcm_token = $1, fcm_token_updated_at = NOW() WHERE id = auth.user.id`.
5. THE endpoint SHALL return 200 dengan `{ ok: true }`.
6. WHEN auth fail → 401, validation fail → 400, DB error → 500.

### Requirement 3: Mobile FCM Setup

#### Acceptance Criteria

1. THE Mobile_App SHALL menambah dependency `firebase_core` + `firebase_messaging` + `flutter_local_notifications` di pubspec.
2. THE Mobile_App SHALL setup Firebase Android di `android/app/google-services.json` (file dari user via Firebase Console).
3. THE Mobile_App SHALL initialize Firebase di `main.dart` SEBELUM `runApp()`.
4. THE Mobile_App SHALL register `FirebaseMessaging.onBackgroundMessage` handler top-level.

### Requirement 4: Permission Flow Android 13+

#### Acceptance Criteria

1. WHEN user pertama kali buka app post-install, THE Mobile_App SHALL request `POST_NOTIFICATIONS` permission via `permission_handler` (lazy: kalau user ke tab Notifikasi pertama kali, atau saat first login).
2. WHEN user deny, THE Mobile_App SHALL menampilkan dialog gentle "Aktifkan notifikasi via Settings" tanpa terror.
3. WHEN user grant, THE Mobile_App SHALL fetch FCM token + register ke backend.

### Requirement 5: FCM Service Class

#### Acceptance Criteria

1. THE Mobile_App SHALL menyediakan `FcmService` class di `lib/core/services/fcm_service.dart`.
2. THE class SHALL expose method statis: `initialize()`, `getCurrentToken()`, `registerTokenWithBackend(token)`, `clearToken()`.
3. THE class SHALL handle 3 lifecycle: foreground via `FirebaseMessaging.onMessage` (show banner via flutter_local_notifications), background via `onBackgroundMessage` (system notification), terminated via `getInitialMessage` (deep link saat tap).
4. THE class SHALL listen `onTokenRefresh` dan re-register otomatis.

### Requirement 6: Token Lifecycle

#### Acceptance Criteria

1. WHEN user login sukses, THE Mobile_App SHALL `FcmService.initialize()` + register token.
2. WHEN user logout, THE Mobile_App SHALL `FcmService.clearToken()` (clear di DB via endpoint baru atau fallback null update).
3. WHEN Firebase rotate token (auto), THE Mobile_App SHALL re-register ke backend.

### Requirement 7: Backend Firebase Admin Setup

#### Acceptance Criteria

1. THE Web_App backend SHALL menambah dependency `firebase-admin` di `package.json`.
2. THE backend SHALL menyimpan service account JSON di env var `FIREBASE_SERVICE_ACCOUNT` (single-line stringified).
3. THE backend SHALL initialize Firebase Admin SDK di `app/lib/fcm-admin.ts` (singleton, init once).
4. THE service account JSON SHALL TIDAK di-commit ke Git (rule `.gitignore` `.env.local`).

### Requirement 8: Send Push Utility

#### Acceptance Criteria

1. THE backend SHALL expose function `sendPushNotification({ studentId, title, body, route, type, relatedId? })` di `app/lib/fcm-admin.ts`.
2. THE function SHALL fetch fcm_token dari profiles. WHEN null, return `{ success: false, error: 'no_token' }` + audit log.
3. THE function SHALL call `admin.messaging().send()` dengan payload include data `{ route, type, related_id? }`.
4. WHEN error code `messaging/registration-token-not-registered`, THE function SHALL clear `fcm_token` di DB.
5. THE function SHALL `logAudit('fcm_push_sent' | 'fcm_push_failed' | 'fcm_token_invalid', ...)` per outcome.
6. THE function SHALL TIDAK include data sensitif (no embedding, no password) dalam payload.

### Requirement 9: Trigger Leave Request

#### Acceptance Criteria

1. WHEN dosen approve leave request via web (`approveLeaveRequestAction`), AFTER status update, THE server action SHALL call `sendPushNotification` dengan title "Pengajuan Izin Disetujui" + body MK + route `/leave-requests`.
2. WHEN dosen reject leave request, THE same flow dengan title "Pengajuan Izin Ditolak" + body alasan + route `/leave-requests`.
3. THE existing path INSERT ke tabel `notifications` SHALL TETAP berfungsi (defense in depth).

### Requirement 10: Trigger Session Start

#### Acceptance Criteria

1. WHEN dosen toggle `is_active = true` via `toggleSessionAction`, THE server action SHALL fetch enrollments untuk MK tsb.
2. THE action SHALL call `sendPushNotification` BATCH ke semua student via `admin.messaging().sendEachForMulticast()` dengan title "Sesi Baru Dimulai" + body "MK X · Pertemuan N" + route `/scan`.
3. THE batch SHALL <= 500 tokens per call (FCM limit). Kalau ada >500 students, chunk into multiple calls.

### Requirement 11: Deep Link on Tap

#### Acceptance Criteria

1. WHEN user tap notification (foreground/background/terminated), THE Mobile_App SHALL parse `data.route` dari payload.
2. THE Mobile_App SHALL `context.go(route)` (atau `context.push(route)`) navigate ke screen relevan.
3. WHEN payload tidak include route, THE app SHALL navigate ke `/notifications` (default fallback).

### Requirement 12: Backward Compat Polling

#### Acceptance Criteria

1. THE existing endpoint `GET /api/mobile/notifications` SHALL TETAP berfungsi.
2. THE existing tabel `notifications` SHALL TETAP di-INSERT setiap trigger point fire (sehingga polling dan FCM dapat data sama).
3. WHEN FCM fail, polling fallback SHALL tetap deliver notifikasi.

### Requirement 13: Audit Logging

#### Acceptance Criteria

1. EACH `sendPushNotification` call SHALL menghasilkan exactly 1 entry di `audit_logs`.
2. THE action name SHALL salah satu: `fcm_push_sent`, `fcm_push_failed`, `fcm_push_skipped`, `fcm_token_invalid`.
3. THE details JSON SHALL include: studentId, type, route, dan messageId/error sesuai outcome.

### Requirement 14: Privacy Hardening

#### Acceptance Criteria

1. THE Push_Payload SHALL TIDAK include face embedding, password, JWT, atau full PII (alamat, NIK).
2. THE notification body SHALL gunakan generic copy yang tidak leak detail (contoh: "Pengajuan Izin Disetujui" BUKAN "Izin sakit untuk MK Pemrograman Web 2026-05-18 disetujui Pak Andi").
3. THE `fcm_token` SHALL TIDAK di-leak via response endpoint mobile lain (mis. profile GET tidak return fcm_token).

### Requirement 15: Manual Smoke Test HP Fisik

#### Acceptance Criteria

1. THE pemilik produk SHALL test pakai HP fisik (BUKAN emulator) karena FCM emulator unreliable.
2. THE smoke test SHALL cover:
   - Login mahasiswa di HP → verify console log "fcm_token registered"
   - Web admin approve leave_request → notif muncul di HP HP screen lock dalam 5 detik
   - Tap notif → app open, navigate /leave-requests
   - Repeat untuk reject + session start
   - Test background/terminated state
3. THE smoke test result SHALL didokumentasikan di `dev-log.md`.

### Requirement 16: Verification Gate

#### Acceptance Criteria

1. WHEN engineer menyelesaikan migration, THE pengembang SHALL `mcp_get_advisors security` 0 issue baru.
2. WHEN engineer menyelesaikan, THE engineer SHALL `npm run type-check` exit 0 + `npm run lint` clean (web).
3. WHEN engineer menyelesaikan, THE engineer SHALL `flutter analyze` "No issues found" (mobile).
4. WHEN engineer menyelesaikan, THE engineer SHALL `flutter build apk --debug` sukses (mobile build verifikasi).

### Requirement 17: Documentation User-Facing

#### Acceptance Criteria

1. THE pengembang SHALL menulis `docs/setup/firebase-setup.md` step-by-step:
   - Buka https://console.firebase.google.com → Create new project
   - Add Android app dengan applicationId match `mypresensi-mobile/android/app/build.gradle.kts`
   - Download `google-services.json` → tempatkan di `mypresensi-mobile/android/app/`
   - Generate Service Account JSON → minify ke single line → set env var `FIREBASE_SERVICE_ACCOUNT` di Vercel + `.env.local`
   - Verify via test push dari Firebase Console
2. THE doc SHALL include screenshot atau panduan visual minimal.
3. THE doc SHALL include section "Troubleshooting umum" untuk error common (token tidak generate, push tidak sampai).

### Requirement 18: Out of Scope

1. THE spec ini SHALL TIDAK include cron job face register reminder (defer ke spec terpisah).
2. THE spec ini SHALL TIDAK include iOS APNs setup (Android only untuk PBL).
3. THE spec ini SHALL TIDAK include rich media notification (image, action button).
4. THE spec ini SHALL TIDAK include in-app message inbox UI baru (existing tab Notifikasi sudah cukup).
