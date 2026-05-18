---
inclusion: fileMatch
fileMatchPattern: 'mypresensi-mobile/**'
description: Konvensi platform Android untuk mypresensi-mobile — minSdk, permissions, ProGuard, signing config, cleartext, applicationId.
---

# Android Platform Conventions — `mypresensi-mobile/`

Komplemen `20-mobile-conventions.md`. Fokus di setting native Android (manifest + Gradle).

## A. SDK Version

| Setting | Nilai | Alasan |
|---------|-------|--------|
| `minSdk` | **26** (Android 8.0 Oreo) | `flutter_secure_storage` & `mobile_scanner` butuh API 26+. JANGAN turunkan. |
| `compileSdk` | `flutter.compileSdkVersion` | Mengikuti Flutter — auto-update. |
| `targetSdk` | `flutter.targetSdkVersion` | Mengikuti Flutter. |
| `Java/Kotlin target` | `VERSION_17` | Sesuai Flutter SDK saat ini. |

File: `mypresensi-mobile/android/app/build.gradle.kts`. Kalau perlu naikin minSdk (mis. dependency baru), diskusikan dulu — bisa potong segmen user yang HP-nya di bawah API tersebut.

## B. Permissions (AndroidManifest.xml)

File: `mypresensi-mobile/android/app/src/main/AndroidManifest.xml`. Wajib eksplisit:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

| Permission | Untuk fitur | Catatan |
|------------|-------------|---------|
| `INTERNET` | API calls (Dio → Next.js) | Wajib |
| `CAMERA` | QR scan + face verification | Runtime request via `permission_handler` |
| `ACCESS_FINE_LOCATION` | GPS geofencing presensi | Runtime request, butuh `whileInUse` minimal |
| `ACCESS_COARSE_LOCATION` | Fallback GPS | Tidak akurat, hanya sebagai fallback |

### Yang TIDAK Boleh
- ❌ Tambah permission tanpa fitur yang membutuhkan (mis. `READ_CONTACTS`, `WRITE_EXTERNAL_STORAGE` modern Android sudah tidak butuh).
- ❌ Skip runtime permission request — assume permission granted = crash di Android 6+.
- ❌ Pakai `<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />` kecuali memang butuh tracking di background (saat ini tidak).

### Runtime Permission
Pakai package **`permission_handler ^12.0.1`**. Pola:
```dart
final status = await Permission.camera.request();
if (status.isDenied || status.isPermanentlyDenied) {
  // Tampilkan dialog Bahasa Indonesia: "Izin kamera diperlukan untuk scan QR..."
  // Berikan tombol "Buka Pengaturan" pakai openAppSettings();
  return;
}
```

`LocationService.checkAndRequestPermission()` di `lib/features/attendance/services/location_service.dart` sudah encapsulasi pola ini — pakai itu, jangan call `permission_handler` langsung dari UI.

## C. Application Identity

| Setting | Nilai aktual | Catatan |
|---------|--------------|---------|
| `applicationId` | `ac.id.politani.mypresensi_mobile` | **Note**: ada underscore di segmen terakhir. Idealnya `ac.id.politani.mypresensi` (tanpa underscore di segmen terakhir) — tapi mengubah ini setelah ada user terinstall = beda app baru, harus uninstall manual. **Diskusikan dulu** sebelum ubah. |
| `namespace` (Kotlin) | `ac.id.politani.mypresensi_mobile` | Match `applicationId`. |
| App label | `MyPresensi` | Bukan package name teknis. |

JANGAN ubah `applicationId` tanpa alasan kuat — mengubah berarti app dianggap baru oleh Play Store / device.

## D. Cleartext Traffic (HTTP)

Saat ini **`usesCleartextTraffic="true"`** untuk development (HTTP ke `10.0.2.2:3000` / LAN IP).

### WAJIB sebelum Release
1. Set `usesCleartextTraffic="false"` di `AndroidManifest.xml`.
2. Atau lebih baik: pakai `network_security_config.xml` untuk allow cleartext hanya ke IP lokal saat debug:
   ```xml
   <!-- res/xml/network_security_config.xml -->
   <network-security-config>
     <domain-config cleartextTrafficPermitted="true">
       <domain includeSubdomains="true">10.0.2.2</domain>
       <domain includeSubdomains="true">192.168.1.15</domain>
     </domain-config>
     <base-config cleartextTrafficPermitted="false" />
   </network-security-config>
   ```
3. Backend production WAJIB pakai HTTPS.

## E. Build Types & Release Hardening

### Status Saat Ini (gap yang harus ditutup sebelum release)
File: `mypresensi-mobile/android/app/build.gradle.kts`.

```kts
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        signingConfig = signingConfigs.getByName("debug")  // ⚠️ pakai debug key
    }
}
```

**Yang masih harus dikerjakan**:
1. **Signing config**: buat upload keystore terpisah dari debug key. JANGAN commit `keystore.jks` ke Git.
2. **`minifyEnabled true`** + **`shrinkResources true`** untuk ProGuard/R8 di release:
   ```kts
   release {
       isMinifyEnabled = true
       isShrinkResources = true
       proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
       signingConfig = signingConfigs.getByName("release")
   }
   ```
3. **`proguard-rules.pro`** — tambah keep rules untuk:
   - ML Kit Face Detection
   - TFLite (`tflite_flutter`)
   - Dio + JSON serialization
   - Riverpod generated code (jika pakai code-gen)

### Build Release dengan Obfuscate
```powershell
flutter build apk --release `
  --obfuscate `
  --split-debug-info=build/symbols
```

`--split-debug-info` simpan symbol di luar APK — kalau crash di production, baru pakai symbol untuk decode stack trace. JANGAN commit folder symbols ke Git public.

## F. Keystore Management

1. Generate upload keystore:
   ```powershell
   keytool -genkey -v -keystore upload-keystore.jks `
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Simpan password & alias di `android/key.properties` (file ini **WAJIB di-gitignore**):
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```
3. Tambah `key.properties` ke `.gitignore`.
4. Backup keystore di tempat aman (Bitwarden / encrypted drive). **Hilang keystore = tidak bisa update app di Play Store** — harus daftar app baru.

## G. Emulator & Testing

- **Standard emulator**: Pixel 9a API 36 (atau ≥ API 26). Lihat workflow `/run-emulator`.
- **Physical device** wajib API 26+. Cek via `adb shell getprop ro.build.version.sdk`.
- **Mock location di emulator** otomatis di-bypass saat **debug build** (lihat `LocationService.getCurrentPosition()`). Untuk test mock-rejection sebenarnya, pakai release build / HP fisik.

## H. Network Configuration

`baseUrl` auto-detect di `lib/core/config/app_config.dart`:

| Kondisi | Base URL | Catatan |
|---------|----------|---------|
| `--dart-define=API_BASE_URL=http://x.x.x.x:3000` | env tersebut | CI/CD, custom override |
| Android emulator | `http://10.0.2.2:3000` | Loopback ke host Windows |
| Physical Android | `http://192.168.1.15:3000` | Ganti `_lanIp` jika beda jaringan |
| Desktop / iOS | `http://localhost:3000` | Dev di laptop |

**JANGAN hardcode URL** di file selain `app_config.dart`.

## I. Connectivity Check

Pakai package **`connectivity_plus ^7.1.0`** sebelum sync data berat:
```dart
final connectivity = await Connectivity().checkConnectivity();
if (connectivity.contains(ConnectivityResult.none)) {
  throw 'Tidak ada koneksi internet. Periksa WiFi atau data seluler.';
}
```

Untuk fitur kritis (submit presensi), **lebih baik try POST dan tangani error** daripada cek connectivity dulu — connectivity check bisa menipu (WiFi tersambung tapi internet down).

## J. Common Pitfalls Android

1. **APK release stuck di splash** → biasa karena ProGuard strip class yang dipakai reflection. Tambah keep rules di `proguard-rules.pro`.
2. **TFLite model load error di release** → asset path case-sensitive di Android. Pastikan `assets/models/mobilefacenet.tflite` exact match.
3. **ML Kit "Module unavailable"** → buka Play Store di emulator, biarkan auto-update Google Play Services. Atau di HP fisik: Settings → Apps → Google Play Services → Update.
4. **Camera buram** → cek `imageFormatGroup: ImageFormatGroup.nv21` di `CameraController` (Android-specific). `bgra8888` lebih cepat untuk iOS tapi tidak optimal di Android.
5. **GPS lambat first-fix** → indoor seringkali butuh 30-60 detik. Tampilkan loading state Bahasa Indonesia: "Mencari sinyal GPS, tetap di tempat terbuka..."
6. **`isMocked` selalu true di emulator** → sudah di-bypass otomatis di debug build (`kDebugMode`). Test rejection pakai release build.
