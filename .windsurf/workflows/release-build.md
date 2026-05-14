---
description: Build APK release MyPresensi Mobile dengan obfuscate + signing + smoke test. Pakai sebelum kirim ke dosen pembimbing atau distribusi internal kampus.
---

# /release-build — Build APK Release Mobile

Workflow untuk build APK production-ready: obfuscated, signed, ProGuard-stripped, smoke-tested.

## ⚠️ Status Saat Ini (per 2026-05-14): Belum Release-Ready

Audit kondisi proyek saat workflow ini dibuat — **5 prerequisite masih kosong**, harus disetup dulu sebelum bisa jalankan release build:

| Item | Status | Lokasi |
|------|--------|--------|
| **Upload keystore** (`upload-keystore.jks`) | ❌ Tidak ada | Belum dibuat |
| **`key.properties`** (password keystore) | ❌ Tidak ada | `mypresensi-mobile/android/key.properties` |
| **`proguard-rules.pro`** (keep rules ML Kit/TFLite/Dio) | ❌ Tidak ada | `mypresensi-mobile/android/app/proguard-rules.pro` |
| **`network_security_config.xml`** (HTTPS + cleartext whitelist) | ❌ Tidak ada | `mypresensi-mobile/android/app/src/main/res/xml/network_security_config.xml` |
| **`build.gradle.kts` signing config release** | ❌ Masih pakai debug key | `mypresensi-mobile/android/app/build.gradle.kts` line 37: `signingConfig = signingConfigs.getByName("debug")` |
| `usesCleartextTraffic` | ⚠️ Masih `"true"` (untuk dev HTTP ke localhost) | `mypresensi-mobile/android/app/src/main/AndroidManifest.xml:15` |

**Implikasi**: Jalankan `flutter build apk --release` sekarang akan menghasilkan APK yang:
- Signed dengan **debug keystore** → tidak bisa diupload ke Play Store, tidak bisa di-update di device pengguna nantinya.
- **Tidak obfuscated** (kalau lupa pasang `--obfuscate` flag).
- **Cleartext HTTP** masih diizinkan ke semua domain.
- Tanpa **ProGuard keep rules** → ML Kit / TFLite bisa runtime-error karena class di-strip.

Workflow ini dirancang dengan asumsi 5 prerequisite di atas **sudah disetup**. Step "Prasyarat (sekali setup)" di bawah memberikan template lengkap untuk membuatnya pertama kali. Sekali sudah setup, step tersebut tidak perlu diulang.

## Prasyarat (sekali setup)

### 1. Upload Keystore
```powershell
keytool -genkey -v `
  -keystore upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload
```

Simpan output di tempat aman (Bitwarden / encrypted drive). **Kehilangan keystore = tidak bisa update app di Play Store**.

### 2. `key.properties`

File: `mypresensi-mobile/android/key.properties` (WAJIB di-gitignore):
```properties
storePassword=<password keystore>
keyPassword=<password key>
keyAlias=upload
storeFile=../upload-keystore.jks
```

### 3. Update `build.gradle.kts`

File: `mypresensi-mobile/android/app/build.gradle.kts`. Tambah signing config + minify:

```kts
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... yang sudah ada

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### 4. ProGuard Rules

File: `mypresensi-mobile/android/app/proguard-rules.pro`. Tambah keep rules:

```proguard
# === Flutter ===
-keep class io.flutter.embedding.** { *; }

# === ML Kit Face Detection ===
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# === TFLite ===
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.support.** { *; }

# === Dio + JSON Serialization ===
-keepattributes *Annotation*
-keepattributes Signature
-keep class * extends java.lang.Exception { *; }

# === Riverpod (jika pakai code-gen) ===
-keep class * extends dev.flutter.plugins.flutter_native_splash.** { *; }
```

## Step 1 — Pre-Release Verification

```powershell
cd mypresensi-mobile

# Static analysis harus pass
flutter analyze
```
Output: `No issues found!`. Kalau ada warning, evaluasi dulu — jangan release dengan warning yang belum dipahami.

```powershell
# Update dependencies kalau ada perubahan
flutter pub get

# Cek versi
Get-Content pubspec.yaml | Select-String -Pattern "^version:"
```

**WAJIB naikkan `versionCode`** sebelum build release baru. Format `version: <semver>+<buildNumber>`. Contoh: `1.0.0+1` → `1.0.1+2` atau `1.1.0+3`.

```powershell
# Edit pubspec.yaml
# version: 1.0.1+2
```

## Step 2 — Build Configuration Check

```powershell
# Cek AndroidManifest — usesCleartextTraffic harus false di release
Select-String -Path "android/app/src/main/AndroidManifest.xml" -Pattern "usesCleartextTraffic"
```

**Untuk release production**, harus salah satu:
1. `usesCleartextTraffic="false"` (block semua HTTP), atau
2. Ada `network_security_config.xml` yang allow HTTP hanya untuk IP development.

Kalau backend production sudah HTTPS → set `usesCleartextTraffic="false"`.

```powershell
# Cek base URL default di app_config.dart — harus production URL atau via --dart-define
Select-String -Path "lib/core/config/app_config.dart" -Pattern "baseUrl"
```

Pastikan tidak hardcode `localhost:3000` atau `192.168.x.x` ke release tanpa override.

## Step 3 — Build APK Release

// turbo
```powershell
flutter build apk --release `
  --obfuscate `
  --split-debug-info=build/symbols `
  --dart-define=API_BASE_URL=https://api.mypresensi.politani.ac.id
```

cwd: `mypresensi-mobile`. Ganti URL dengan endpoint production aktual.

Tunggu ~3-5 menit. Output di `build/app/outputs/flutter-apk/app-release.apk`.

### Variant Per-ABI (opsional, untuk APK lebih kecil)
```powershell
flutter build apk --release `
  --obfuscate `
  --split-debug-info=build/symbols `
  --split-per-abi `
  --dart-define=API_BASE_URL=https://api.mypresensi.politani.ac.id
```

Output: 3 APK (`armeabi-v7a`, `arm64-v8a`, `x86_64`). Distribusi pilih sesuai target device.

### Atau Build App Bundle (untuk Play Store)
```powershell
flutter build appbundle --release `
  --obfuscate `
  --split-debug-info=build/symbols `
  --dart-define=API_BASE_URL=https://api.mypresensi.politani.ac.id
```

Output: `build/app/outputs/bundle/release/app-release.aab`. Format Play Store-only.

## Step 4 — Verify Build Output

```powershell
# Cek size APK
Get-ChildItem build/app/outputs/flutter-apk/app-release.apk | Select-Object Name, Length

# Convert ke MB
(Get-Item build/app/outputs/flutter-apk/app-release.apk).Length / 1MB
```

Target size: **15-25 MB** untuk APK universal. Kalau >40 MB, ada yang salah (debug info masuk, ProGuard tidak jalan).

```powershell
# Verify signing
$keytoolPath = "$env:JAVA_HOME\bin\keytool.exe"
& $keytoolPath -printcert -jarfile "build/app/outputs/flutter-apk/app-release.apk"
```

Output harus tunjukkan certificate dengan `Owner` dan `Issuer` yang sesuai dengan upload keystore (BUKAN debug keystore Android).

## Step 5 — Backup Symbol Files

Symbol files dipakai untuk decode crash report dari obfuscated APK. **WAJIB backup**, jangan commit ke Git public:

```powershell
# Backup ke folder timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$version = (Get-Content pubspec.yaml | Select-String "^version:").ToString().Split(":")[1].Trim()
New-Item -ItemType Directory -Force -Path "../release-symbols/v$version-$timestamp"
Copy-Item -Recurse "build/symbols/*" "../release-symbols/v$version-$timestamp/"
```

Simpan folder ini di tempat aman (Bitwarden file attachment / encrypted drive / private repo).

## Step 6 — Smoke Test di HP Fisik

JANGAN skip — release build behavior beda dengan debug.

```powershell
# Install ke HP fisik (ADB enabled)
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Smoke Test Checklist (10-15 menit)

#### Splash & Launch
- [ ] Splash screen muncul (background `#F0F4F8`, smooth ke home/login).
- [ ] Tidak crash di startup.
- [ ] App icon TRPL tampak di launcher.

#### Auth Flow
- [ ] Login dengan akun mahasiswa valid → home muncul.
- [ ] Login dengan password salah → pesan Indonesia.
- [ ] Login dengan akun `must_change_password` → diarahkan ke ganti password.
- [ ] Logout → kembali ke login, storage clear.

#### Presensi (Core Flow)
- [ ] Scan QR sesi aktif → kamera buka, parse QR berhasil.
- [ ] GPS ambil lokasi → permission dialog muncul (kalau belum granted).
- [ ] Submit dengan GPS dalam radius → success, muncul notifikasi.
- [ ] Submit dengan GPS jauh → tolak dengan pesan jarak.

#### Mock GPS Detection (CRITICAL untuk release)
- [ ] Install Fake GPS app dari Play Store.
- [ ] Aktifkan mock location di Developer Options.
- [ ] Set Fake GPS ke koordinat Politani.
- [ ] Coba submit → harus **REJECT 403** dengan pesan "Lokasi palsu terdeteksi" + audit log.
- [ ] (Optional) Verify di Supabase Studio: `audit_logs` ada row `action='mock_location_detected'`.

#### Face Recognition
- [ ] Belum register face → tombol "Daftar Wajah" tampil.
- [ ] First-time face register → dialog consent muncul.
- [ ] Setuju → lanjut ke kamera.
- [ ] Liveness 4 step (lookStraight, blinkEyes, turnLeft, turnRight) jalan smooth.
- [ ] Capture 7 frame → loading → success.
- [ ] Verify wajah → similarity ≥ 0.65 → match.
- [ ] Verify orang lain → similarity < 0.65 → reject.

#### Riwayat & Profil
- [ ] Tab Riwayat → list presensi muncul.
- [ ] Filter periode → query benar.
- [ ] Tab Profil → data user, foto profil, tombol logout.

#### Network Resilience
- [ ] Matikan WiFi/data → submit → error message ramah dengan retry.
- [ ] Aktifkan kembali → retry berhasil.
- [ ] Backend down (matikan `npm run dev`) → error "Tidak dapat terhubung ke server."

#### Performance
- [ ] App tidak lag saat buka tab.
- [ ] Face detection real-time, tidak frame drop berlebihan.
- [ ] Submit presensi response < 3 detik (GPS + network).

## Step 7 — Versioning & Tagging

Update di Git:
```powershell
$version = "1.0.1"
git tag -a "v$version" -m "Release v$version"
git push origin "v$version"
```

Update CHANGELOG dengan entri release:
```markdown
## v1.0.1 — 2026-05-20

### Highlights
- Build production dengan obfuscate + ProGuard
- ...

### Files
| 14:30 | [CHORE] | `pubspec.yaml` | Bump version 1.0.0+1 → 1.0.1+2 |
| 14:35 | [BUILD] | `android/app/build.gradle.kts` | Aktifkan minify + signing config release |
```

## Step 8 — Distribusi

### Untuk Dosen Pembimbing PBL
- Upload APK ke Google Drive folder PBL.
- Bagikan link via WhatsApp grup PBL.
- Sertakan QR code download untuk kemudahan.

### Untuk Internal Kampus (jika scope expand)
- Upload ke private hosting / file server kampus.
- Setup kode QR + URL pendek.
- Update via OTA channel internal (kalau ada infra-nya).

### Play Store Internal Track (jika ada akun developer)
- Upload `.aab` ke Play Console → Internal testing.
- Tambah tester email.
- Distribusi via internal share link.

## Anti-Pattern (JANGAN dilakukan)

| Anti-Pattern | Realita |
|--------------|---------|
| Distribusi APK debug ke pengguna akhir | Size besar, tidak obfuscated, debug log aktif. Tidak production-ready. |
| Sign dengan debug keystore | Tidak bisa update di Play Store, tidak diterima. |
| Skip smoke test di HP fisik | Bug spesifik release sering muncul (ProGuard strip class, mock GPS detect). |
| Commit `key.properties` atau `*.jks` | Kebocoran kredensial — siapapun bisa sign update palsu app ini. |
| Lupa naik versionCode | Build kedua tidak bisa replace yang pertama di device (tanpa uninstall manual). |
| Hardcode production URL di kode | Sulit testing di dev. Pakai `--dart-define=API_BASE_URL=...`. |

## Troubleshooting

### "Execution failed for task ':app:lintVitalRelease'"
ProGuard strip class yang dipakai reflection. Tambah keep rules di `proguard-rules.pro`.

### APK install tapi crash di splash
Biasanya: TFLite model tidak load, atau ML Kit unavailable.
```powershell
adb logcat -s flutter:E AndroidRuntime:E
```
Cek error spesifik.

### Build cepat tapi APK debug masuk ke release
Pastikan `--release` flag ada di command. `flutter build apk` tanpa flag = debug build.

### Size APK >50MB
Cek:
- ProGuard enabled? (`isMinifyEnabled = true`)
- Shrink resources? (`isShrinkResources = true`)
- Asset besar? (TFLite model 5MB harus ada, tapi jangan ada model duplikat)
- Pakai `--split-per-abi` untuk APK per arsitektur.
