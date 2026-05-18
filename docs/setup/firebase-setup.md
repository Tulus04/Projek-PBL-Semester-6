# Firebase Cloud Messaging (FCM) Setup — MyPresensi

> Dokumentasi step-by-step setup Firebase untuk push notification mobile MyPresensi. **Wajib dilakukan oleh user (pemilik project) sebelum implementasi backend + mobile FCM**.

## Prasyarat

- Akun Google (gmail) — Firebase pakai infrastruktur Google
- `applicationId` Android: `ac.id.politani.mypresensi_mobile` (cek di `mypresensi-mobile/android/app/build.gradle.kts`)
- Akses ke folder lokal repo `mypresensi-web/.env.local` dan `mypresensi-mobile/android/app/`

## Step 1: Create Firebase Project (5 menit)

1. Buka https://console.firebase.google.com
2. Login dengan akun Google
3. Klik **"Add project"** atau **"Create a project"**
4. Project name: `MyPresensi-PBL` (atau bebas)
5. Disable Google Analytics (toggle off) — tidak butuh untuk PBL scope
6. Klik **"Create project"** → tunggu provisioning ~30 detik

## Step 2: Add Android App ke Firebase Project

1. Di Firebase Console → klik icon Android di overview page (atau "Add app" → Android)
2. Form "Add Firebase to your Android app":
   - **Android package name**: `ac.id.politani.mypresensi_mobile` (HARUS exact match dengan `applicationId` di Gradle)
   - **App nickname** (opsional): `MyPresensi Mobile`
   - **Debug signing certificate SHA-1** (opsional untuk dev): SKIP untuk sekarang, bisa tambah nanti
3. Klik **"Register app"**

## Step 3: Download `google-services.json`

1. Setelah register app, Firebase Console akan redirect ke "Download config file"
2. Klik **"Download google-services.json"**
3. Simpan file itu ke `mypresensi-mobile/android/app/google-services.json`
4. **PENTING**: file ini WAJIB di `.gitignore`. Cek `mypresensi-mobile/android/app/.gitignore`:
   ```
   google-services.json
   ```
   Jika belum ada, tambahkan.

## Step 4: Add Firebase SDK ke Gradle (manual edit)

Firebase Console akan kasih instruksi Gradle. Update files berikut di repo:

### File 1: `mypresensi-mobile/android/build.gradle.kts` (project-level)

Tambah di buildscript dependencies:
```kotlin
buildscript {
    dependencies {
        // ... existing
        classpath("com.google.gms:google-services:4.4.2")
    }
}
```

### File 2: `mypresensi-mobile/android/app/build.gradle.kts` (app-level)

Tambah di akhir file (atau dekat plugins block):
```kotlin
plugins {
    // ... existing
}

apply(plugin = "com.google.gms.google-services")
```

Atau untuk Kotlin DSL modern (Flutter 3.11+):
```kotlin
plugins {
    id("dev.flutter.flutter-gradle-plugin")
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")  // <-- TAMBAH INI
}
```

## Step 5: Generate Service Account JSON (untuk Backend)

Service account dipakai backend Next.js untuk authenticate ke FCM Admin SDK saat send push.

1. Di Firebase Console → klik gear icon ⚙️ (settings) di kiri atas → **"Project settings"**
2. Tab **"Service accounts"**
3. Klik **"Generate new private key"** → confirm download
4. File JSON akan ter-download (nama mirip `mypresensi-pbl-firebase-adminsdk-xxxxx.json`)
5. Buka file JSON itu di text editor, copy ALL content
6. **Minify** ke single line (penting untuk env var):
   - Pakai online JSON minifier, atau
   - Pakai Node:
     ```bash
     node -e "console.log(JSON.stringify(require('./mypresensi-pbl-firebase-adminsdk-xxxxx.json')))"
     ```
   - Atau PowerShell:
     ```powershell
     (Get-Content -Raw mypresensi-pbl-firebase-adminsdk-xxxxx.json | ConvertFrom-Json | ConvertTo-Json -Compress)
     ```
7. **Set env var**:
   - Local dev: tambah ke `mypresensi-web/.env.local`:
     ```
     FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}
     ```
   - Production (Vercel): Vercel Dashboard → Project Settings → Environment Variables → Add `FIREBASE_SERVICE_ACCOUNT` dengan value JSON minified

8. **HAPUS file JSON** asli setelah env var di-set. JANGAN commit ke Git!

### Verify .gitignore

Pastikan `mypresensi-web/.gitignore` include:
```
.env.local
.env*.local
```

Pastikan `.gitignore` root atau `mypresensi-web/` exclude pattern Service Account:
```
**/firebase-adminsdk-*.json
**/google-services.json
```

## Step 6: Verify via Test Push (after backend implemented)

Setelah backend implementasi `app/lib/fcm-admin.ts` selesai, kamu bisa test:

```ts
// Sementara di route handler test atau Server Action
import { sendPushNotification } from '@/lib/fcm-admin'

const result = await sendPushNotification({
  studentId: '<UUID-student-yang-sudah-login-mobile>',
  title: 'Test Push',
  body: 'Halo, ini test FCM',
  route: '/notifications',
  type: 'announcement',
})
console.log(result)
```

Expect: notif muncul di HP fisik dalam 5 detik.

## Troubleshooting Umum

### Error: "Failed to load FirebaseOptions" saat app start
- Pastikan `google-services.json` ada di `mypresensi-mobile/android/app/`
- Pastikan plugin `com.google.gms.google-services` di-apply di `app/build.gradle.kts`
- Run `flutter clean && flutter pub get && flutter run`

### Error: "Token tidak ter-generate"
- Cek permission `POST_NOTIFICATIONS` di-grant (Android 13+)
- Pastikan device punya internet
- Pastikan Google Play Services up-to-date di device

### Error: "FIREBASE_SERVICE_ACCOUNT env var not parseable"
- Pastikan JSON minified ke single line (no newline)
- Escape `"` di dalam JSON sudah benar
- Test parse:
  ```ts
  const parsed = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  console.log(parsed.project_id)  // should print "mypresensi-pbl"
  ```

### Error: "Push tidak sampai"
- Cek `audit_logs` di Supabase: filter `action = 'fcm_push_failed'` — lihat error message
- Token mungkin expired: re-login di mobile, token akan refresh
- Notif Android disabled di Settings: enable manual

### Push muncul di foreground tapi background tidak
- Pastikan `FirebaseMessaging.onBackgroundMessage` registered top-level di `main.dart` (BUKAN inside class)
- Pastikan `flutter_local_notifications` initialized

## Catatan Keamanan

- **JANGAN commit `google-services.json`** — meski isinya tidak super sensitif (public key + project ID), best practice keep out of public repo
- **JANGAN commit Service Account JSON** — ini WAJIB private. Kalau bocor, bisa kena akses ke project Firebase. Rotate via Firebase Console kalau bocor.
- Service Account = setara service_role key Supabase. Treat dengan respect yang sama.

## Reference

- https://firebase.google.com/docs/cloud-messaging/flutter/client
- https://firebase.google.com/docs/admin/setup
- https://firebase.google.com/docs/cloud-messaging/concept-options
