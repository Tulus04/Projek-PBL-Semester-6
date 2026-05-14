---
trigger: glob
globs: mypresensi-mobile/**
description: Konvensi koding mypresensi-mobile (Flutter + Riverpod + GoRouter + Dio). Wajib diikuti untuk semua perubahan di folder ini.
---

# Konvensi `mypresensi-mobile/`

Aplikasi Flutter untuk mahasiswa. Backend = Next.js API di `mypresensi-web/app/api/mobile/*` (BUKAN Supabase langsung).

## Struktur `lib/`

```
lib/
├── main.dart                       ← entry: native splash + ProviderScope + MaterialApp.router
├── core/
│   ├── config/app_config.dart      ← baseUrl auto-detect (emulator vs LAN)
│   ├── network/
│   │   ├── dio_client.dart         ← singleton + auth interceptor + 401 auto-logout
│   │   └── api_endpoints.dart      ← konstanta path API (sumber tunggal)
│   ├── router/app_router.dart      ← GoRouter + redirect guard berdasarkan AuthState
│   ├── storage/secure_storage.dart ← wrapper flutter_secure_storage
│   └── theme/                      ← AppColors, AppTheme
├── features/
│   ├── auth/        {data, providers, screens}
│   ├── attendance/  {data, providers, screens, services}
│   ├── face/        {data, providers, screens, services}
│   ├── history/  home/  notifications/  profile/
└── shared/
    ├── models/user_model.dart
    └── widgets/app_shell.dart      ← bottom nav + tab content
```

**Pola feature**: setiap feature ikuti layering `screens` (UI) → `providers` (Riverpod) → `data` (repository + models) → opsional `services` (helper non-state).

## State Management — Riverpod 3

```dart
// Notifier dengan state class
final fooProvider = NotifierProvider<FooNotifier, FooState>(FooNotifier.new);

class FooNotifier extends Notifier<FooState> {
  @override
  FooState build() => const FooState();

  Future<void> doSomething() async {
    state = state.copyWith(status: FooStatus.loading);
    // ...
  }
}

// FutureProvider untuk fetch sederhana yang autoDispose
final activeSessionsProvider = FutureProvider.autoDispose<List<ActiveSession>>((ref) async {
  return ref.read(attendanceRepositoryProvider).getActiveSessions();
});
```

State class wajib **immutable** + punya `copyWith`. Gunakan `enum FooStatus { idle, loading, success, error }` (lihat `AttendanceSubmitState`, `AuthState`).

## Routing — GoRouter

`core/router/app_router.dart` punya pola yang **wajib dipertahankan**:

- `refreshListenable: _AuthNotifier(ref)` — GoRouter hanya re-evaluate redirect, **TIDAK** dibuat ulang setiap state berubah.
- Redirect logic urut: splash dulu → loading → forceChangePassword → authenticated → unauthenticated.
- Transition helpers: `_fadeTransition` (auth), `_slideTransition` (push detail), `_fadeScaleTransition` (masuk home).

Jangan tambahkan route dengan `MaterialPageRoute` mendadak — pakai `GoRoute` + transition helper yang sudah ada.

## Bottom Navigation — `AppShell`

`shared/widgets/app_shell.dart` punya **5 tab tetap**: Beranda · Scan · Riwayat · Notifikasi · Profil.

| Index | Label | Behavior |
|:---:|------|---------|
| 0 | Beranda | `setTab(0)` — pindah tab |
| 1 | **Scan** | **`context.push('/scan')` — push screen, BUKAN ganti tab** |
| 2 | Riwayat | `setTab(2)` |
| 3 | Notifikasi | `setTab(3)` |
| 4 | Profil | `setTab(4)` |

Kalau menambah feature baru yang perlu kamera/full-screen seperti Scan, ikuti pola tab Scan: tab item visual + `context.push('/path')`.

## Back Button Behavior

`AppShell` membungkus dengan `PopScope(canPop: false)`:
1. Jika **bukan di tab Beranda** → tekan back → pindah ke tab Beranda dulu.
2. Jika **di tab Beranda** → tekan back → tampilkan snackbar "Tekan sekali lagi untuk keluar" + reset `_lastBackPress`.
3. Tekan back **kedua kali dalam 2 detik** → exit app via `Navigator.of(context).pop()`.

Jangan ubah pola ini tanpa alasan kuat — UX double-back-to-exit adalah konvensi Android yang diharapkan user.

## HTTP — Dio Singleton

```dart
// AKSES: gunakan getter, bukan field disimpan
class FooRepository {
  Dio get _dio => DioClient.instance;  // ✅ getter — selalu instance terbaru
  // Dio _dio = DioClient.instance;     // ❌ field — pegang instance lama setelah logout
}
```

Alasan: `DioClient.reset()` dipanggil saat logout untuk mencegah token lama dipakai. Field statis akan menyimpan referensi mati.

Interceptor sudah handle:
- **AuthInterceptor** — auto-attach `Authorization: Bearer <token>` (kecuali `/auth/login`).
- **ErrorInterceptor** — kalau 401 dari non-login → trigger `LogoutCallback` (registered di `main.dart`).

Endpoint API: **WAJIB** ambil dari `ApiEndpoints` (`core/network/api_endpoints.dart`), jangan hardcode string.

## baseUrl — Auto-Detect

`AppConfig.baseUrl` di `core/config/app_config.dart`:

| Kondisi | Base URL |
|---------|----------|
| `--dart-define=API_BASE_URL=http://x.x.x.x:3000` | nilai env tersebut |
| Emulator Android | `http://10.0.2.2:3000` |
| Physical Android | `http://192.168.1.15:3000` ← ganti `_lanIp` jika jaringan beda |
| Desktop / iOS | `http://localhost:3000` |

Kalau gagal connect dari HP fisik:
1. Pastikan laptop & HP di WiFi yang sama.
2. Update `_lanIp` di `app_config.dart` sesuai IP laptop saat ini.
3. Pastikan Windows Firewall mengizinkan port 3000.
4. `npm run dev` di laptop harus listen di `0.0.0.0` (default Next.js sudah).

## Error Handling — Pesan Indonesia

`AuthRepository._handleDioError()` menyalakan pola: parse `e.response?.data['error']` (server kirim Bahasa Indonesia), fallback per status code, fallback network error. Repository BARU **wajib** ikuti pola yang sama.

Throw `String` (pesan Indonesia) atau Exception bermakna — **JANGAN** lempar `DioException` mentah ke UI.

## Penting: Permissions & Hardware

| Fitur | Package | Permission Android |
|-------|---------|--------------------|
| Scan QR | `mobile_scanner` | `CAMERA` |
| Face | `camera` + `google_mlkit_face_detection` | `CAMERA` |
| GPS | `geolocator` | `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` |
| Mock detection | `geolocator` (Position.isMocked) | — |

`LocationService.checkAndRequestPermission()` **WAJIB** dipanggil sebelum `getCurrentPosition()`. Throw `LocationException` dengan pesan Indonesia ramah.

## Face Recognition (MobileFaceNet via TFLite)

Sejak 2026-05-14 (CHANGELOG: BUG-fix face recognition), embedding TIDAK lagi
dari ML Kit landmarks. Pipeline yang benar sekarang:

```
CameraImage (NV21/YUV420)
   ↓ FaceDetectionService.processFrame()  ← ML Kit: detection + bbox + liveness signals
FaceDetectionResult (boundingBox, headAngles, eyeOpen)
   ↓ FacePreprocessor.run()  ← convert YUV→RGB, rotate, mirror, crop, resize 112×112, normalize [-1,1]
Float32List [1×112×112×3]
   ↓ FaceEmbeddingService.extractEmbedding()  ← TFLite MobileFaceNet
List<double> 192-d (L2-normalized)
```

**Tiga service kunci**:

| File | Tanggung jawab |
|------|----------------|
| `services/face_detection_service.dart` | ML Kit FaceDetector — return `boundingBox` + liveness signals (`headAngleY`, `leftEyeOpenProb`). **Tidak lagi extract embedding.** |
| `services/image_preprocessor.dart` | CameraImage → 112×112×3 Float32List ternormalisasi. Pakai `package:image` untuk YUV→RGB + rotate + crop. |
| `services/face_embedding_service.dart` | TFLite singleton: load model `assets/models/mobilefacenet.tflite`, run inference → 192-d. Static `cosineSimilarity()` & `averageEmbeddings()`. |

**Hal-hal kritis yang JANGAN dilanggar**:

1. **Asset model HARUS ada** di `assets/models/mobilefacenet.tflite`. Tidak di-commit (gitignored). Lihat `assets/models/README.md` untuk URL download. Tanpa file ini, `Interpreter.fromAsset` akan throw saat startup face screen.
2. **Capture embedding di pose `lookStraight` (step 1)**, BUKAN di akhir liveness. Bug arsitektural lama: embedding dari pose `turnRight` → matching gagal. Lihat `FaceRegistrationNotifier._handleCapturePoseFrame`.
3. **Multi-frame averaging**: 7 frame embedding dari pose lurus → average + L2 normalize. Jangan ubah jadi single-frame.
4. **Threshold default `0.65`** (sesuai LFW benchmark MobileFaceNet 192-d), expose di `FaceEmbeddingService.defaultThreshold`. JANGAN hardcode 0.75 (nilai lama untuk heuristic embedding).
5. **CameraController.ResolutionPreset.high** (BUKAN `medium`) — feature extraction butuh detail wajah cukup.
6. **`imageFormatGroup: ImageFormatGroup.nv21`** untuk Android. Preprocessor handle nv21/yuv420/bgra8888.
7. **Inference NOT thread-safe** untuk single instance — flag `_isExtractingEmbedding` di provider mencegah overlap. Jangan dihilangkan.
8. **Liveness check** (blink, turnLeft, turnRight) sekarang HANYA anti-spoof — TIDAK extract embedding di step ini. Threshold relax tetap berlaku karena keamanan ada di kombinasi step + GPS + OTP.

**Jangan**:
- ❌ Kembali ke landmark heuristic embedding (akurasi rendah karena pose-dependent).
- ❌ Pakai `tflite_flutter_helper` (deprecated, sudah merged ke `tflite_flutter` 0.11+).
- ❌ Gunakan `ResolutionPreset.veryHigh` — lambat untuk inference per frame.

## Submit Presensi

Alur di `AttendanceSubmitNotifier.submitFromQr()`:
1. `gettingLocation` → `LocationService.getCurrentPosition()`.
2. Ambil `device_info_plus` (model + OS).
3. `submitting` → POST `/api/mobile/attendance/submit` dengan body `AttendanceSubmitRequest`.
4. `success` / `error` ditampilkan via state.

`is_mock_location` **dikirim apa adanya** — server yang menolak. Jangan filter di client.

## Setelah Logout

`AuthNotifier.logout()` melakukan:
1. `SecureStorage.clearAll()`
2. `DioClient.reset()` — instance Dio baru saat request berikutnya
3. `HomeScreen.resetWelcome()` — reset banner welcome
4. `currentTabProvider.setTab(0)` — kembali ke Beranda

Kalau menambah feature dengan state lokal yang harus di-reset saat logout, **panggil reset method-nya di `logout()`**.

## Gotchas

1. **GoRouter di-rebuild → kehilangan state**: jangan letakkan `GoRouter()` constructor di builder yang sering dipanggil. Provider sudah handle dengan `refreshListenable`.
2. **`headEulerAngleY` arah berbeda antar device** — `checkLivenessStep()` cek `abs() > threshold`, bukan tanda. Jangan diganti.
3. **`SecureStorage` operasi async** — kalau cek di `build()` widget, gunakan `FutureBuilder` atau provider, jangan `.then()` di build.
4. **APK release** wajib tambah `--obfuscate --split-debug-info=...` saat build untuk hardening.
5. **Hot reload tidak menjalankan `main()`** — kalau ubah `AppConfig.initialize()` atau register interceptor, lakukan **hot restart**.
