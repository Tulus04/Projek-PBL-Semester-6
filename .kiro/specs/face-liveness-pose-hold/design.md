# Face Liveness Pose Hold — Bugfix Design

## Overview

Bug ini bukan masalah deteksi pose dari ML Kit (yaw jelas terdeteksi >12°), melainkan masalah **akumulasi bukti hold** di lapisan provider Riverpod. Fix yang dipilih adalah **mengganti algoritma confirmation dari "continuity wall-clock time" menjadi "frame-count + minimum wall-time floor"** di dalam `FaceRegistrationNotifier._handleLivenessFrame`. Algoritma baru tahan terhadap frame interval bervariasi (200–400 ms di Realme RMX5000) dan tetap mensyaratkan multi-frame proof (anti-spoof).

Untuk membuat fix ini testable di `flutter_test` tanpa device fisik / `CameraImage` / kamera, logic akumulasi di-extract ke kelas pure `LivenessHoldTracker` (in-memory, deterministic, tick-based). Notifier hanya men-delegate ke tracker. Itu memungkinkan exploration test mereproduksi skenario Realme RMX5000 dengan urutan tick `(passed, timestampMs)` murni di unit test.

Tidak ada dependency baru. Tidak ada threshold deteksi pose yang diubah (`FaceDetectionService.checkLivenessStep` tetap apa adanya). Multi-frame proof preserved (≥3 frame `passed=true`). Gold path device mid/high-tier tidak slower (worst-case 300 ms vs 400 ms sebelumnya).

## Glossary

- **Bug_Condition (C)**: Frame ML Kit dengan interval > rata-rata + jitter `passed=false` transien sehingga `_passedGapResetMs = 500 ms` di logic lama tertabrak → window `_passedSinceMs` selalu di-reset → `holdMs >= 400 ms` tak pernah tercapai.
- **Property (P)**: Setelah fix, untuk semua urutan tick yang merepresentasikan "user menahan pose" (mayoritas frame `passed=true` dalam window ≥ 600 ms wall-clock), step `turnLeft`/`turnRight` SHALL terkonfirmasi dalam ≤ ~1.5 detik real-time.
- **Preservation**: Existing behavior dari blink (event-detection 1 frame), lookStraight capture (7 embedding via TFLite), enforcement arah berlawanan turnRight, threshold deteksi pose, dan logging `[FACE LIVE]` per-5-frame harus tetap utuh.
- **`_handleLivenessFrame`**: Method di `mypresensi-mobile/lib/features/face/providers/face_provider.dart` (sekitar baris 350–390) yang dipanggil per frame saat fase `livenessCheck` aktif.
- **`_passedSinceMs` / `_lastPassedAtMs` / `_passedGapResetMs`**: Tiga state privat di `FaceRegistrationNotifier` yang membentuk algoritma akumulasi lama berbasis wall-clock continuity. Ini yang akan diganti.
- **`LivenessHoldTracker`**: Kelas pure baru (akan dibuat saat fix) yang meng-encapsulate logic akumulasi tick. Tidak menyentuh ML Kit / camera — input cukup `(bool passed, LivenessStep step, int nowMs)`.
- **Frame-count proof**: Mekanisme baru yang menghitung jumlah frame `passed=true` selama window aktif, dengan toleransi sejumlah frame `passed=false` transien sebelum window di-reset.

## Bug Details

### Root Cause Analysis (trace path lengkap di kode)

Hipotesis dari requirements **terkonfirmasi** setelah membaca `face_provider.dart`. Trace:

1. `FaceRegistrationNotifier.onFrame()` (`face_provider.dart` ~baris 250) → setelah lookStraight selesai, panggil `_handleLivenessFrame(result)`.

2. `_handleLivenessFrame` (`face_provider.dart` baris ~352–390) — sumber bug:
   ```dart
   final passed = detector.checkLivenessStep(state.livenessStep, result);
   final now = DateTime.now().millisecondsSinceEpoch;

   if (passed) {
     if (_lastPassedAtMs != null &&
         now - _lastPassedAtMs! > _passedGapResetMs) { // ← 500 ms
       _passedSinceMs = now;                            // ← reset window
     }
     _passedSinceMs ??= now;
     _lastPassedAtMs = now;
   }

   final holdMs = _passedSinceMs == null ? 0 : now - _passedSinceMs!;

   if (passed && holdMs >= _getHoldDurationMs(state.livenessStep)) { // ← 400 ms untuk pose
     _advanceLivenessStep();
   }
   ```

3. Konstanta `_passedGapResetMs = 500` (`face_provider.dart` baris ~205) dan `_getHoldDurationMs(turnLeft|turnRight) = 400` (baris ~190).

4. Skenario Realme RMX5000 (logcat user):
   - Frame interval ML Kit ≈ 200–400 ms (bukan 50–100 ms karena GC pause MediaTek + ColorOS memboroskan budget per frame).
   - Yaw user oscillate antara 30°–57° (`passed=true`) dan sesekali drop ke ≤12° saat ML Kit miss face partial (`passed=false`).
   - Misal urutan: `t=0 passed`, `t=250 passed`, `t=500 fail`, `t=750 fail`, `t=1100 passed`.
   - Saat `t=1100`: `now - _lastPassedAtMs = 1100 - 250 = 850 > 500` → cabang reset `_passedSinceMs = 1100`.
   - `holdMs = 1100 - 1100 = 0`. Window dimulai ulang dari nol setiap kali ada gap fail >500 ms.
   - Akumulator tak pernah mencapai 400 ms continuity → `_advanceLivenessStep()` tak pernah dipanggil.
   - Logcat `holdMs maksimum = 105 ms` (kebetulan dua passed berdekatan ~100 ms apart, langsung tertekan reset di frame ke-3).

5. Penyebab struktural: algoritma "continuity wall-clock time" mengasumsikan **frame ML Kit reguler dan sering**. Asumsi itu tidak berlaku di chipset entry-level. Algoritma menganggap "gap > 500 ms" = "user balik pose awal", padahal di RMX5000 itu = "ML Kit lagi GC". Confusion antara *kondisi user* dan *kondisi runtime*.

**File:line references**:
- `mypresensi-mobile/lib/features/face/providers/face_provider.dart:182` — komentar konstanta `_passedSinceMs`/`_lastPassedAtMs`
- `mypresensi-mobile/lib/features/face/providers/face_provider.dart:191` — `_getHoldDurationMs()` (blink=0, pose=400)
- `mypresensi-mobile/lib/features/face/providers/face_provider.dart:205` — `_passedGapResetMs = 500`
- `mypresensi-mobile/lib/features/face/providers/face_provider.dart:354` — `_handleLivenessFrame` body (bagian sumber bug)
- `mypresensi-mobile/lib/features/face/services/face_detection_service.dart:139` — `checkLivenessStep()` threshold yaw 12° (TIDAK diubah)

### Bug Condition

Bug muncul saat **stream tick liveness** memenuhi semua kondisi berikut secara bersamaan:
1. Mayoritas tick (≥ 60%) memiliki `passed=true` di dalam window ≥ 600 ms wall-clock — yaitu **user benar-benar menahan pose**.
2. Interval antar tick `passed=true` consecutive **mengalami spike >500 ms** sekali atau lebih (karena 1–3 tick `passed=false` transien di tengah, atau karena GC pause yang menstretch interval ML Kit).
3. Step aktif adalah `turnLeft` atau `turnRight` (`_getHoldDurationMs > 0`).

**Formal Specification:**

```
FUNCTION isBugCondition(tickStream)
  INPUT: tickStream = List<{passed: bool, nowMs: int, step: LivenessStep}>
  OUTPUT: boolean

  isPoseStep    := all ticks have step IN [turnLeft, turnRight]
  windowMs      := tickStream.last.nowMs - tickStream.first.nowMs
  passedCount   := count(tick where tick.passed = true)
  totalCount    := tickStream.length
  hasGapSpike   := exists 2 consecutive passed-true ticks t_i, t_j
                   (no passed-true between them) WHERE
                   t_j.nowMs - t_i.nowMs > 500   // melebihi _passedGapResetMs

  RETURN isPoseStep
         AND windowMs >= 600
         AND passedCount / totalCount >= 0.6
         AND hasGapSpike
END FUNCTION
```

Catatan: `hasGapSpike` dengan pembilang nol-passed di antara berarti "ada periode lebih dari 500 ms tanpa frame `passed=true` baru, padahal user secara wall-time masih menahan pose". Itulah pemicu reset window di logic lama.

### Examples

Tiga skenario tick-stream konkret yang akan dipakai sebagai test fixture (timestamps dalam ms sejak window start):

- **E1 — Realme RMX5000 typical (bug-trigger)**:
  `[(t=0, passed=true), (t=220, passed=true), (t=480, passed=false), (t=720, passed=false), (t=1100, passed=true), (t=1320, passed=true), (t=1550, passed=true)]`
  Step `turnLeft`. Expected pre-fix: **gagal confirm** (`holdMs` reset di t=1100 karena gap 1100−220=880 > 500). Expected post-fix: **confirmed** di tick t=1320 atau t=1550 (passedCount ≥ 3, wallTime sejak first-pass ≥ 300 ms).

- **E2 — Mid-tier device (gold path, jangan regress)**:
  `[(t=0, passed=true), (t=80, passed=true), (t=160, passed=true), (t=240, passed=true)]`
  Expected pre-fix: confirmed di t=400 (atau frame berikutnya) — sebelumnya butuh 400 ms continuity. Expected post-fix: confirmed di t=160 (passedCount=3, wallTime=160<300 → tunggu satu tick lagi → confirmed di t=240, wallTime=240<300 → tunggu… → confirmed saat wallTime ≥ 300 ms). Worst-case ~300 ms — **lebih cepat** dari 400 ms baseline lama.

- **E3 — Spoof attempt (foto statis, pose tidak pernah noleh)**:
  `[(t=0, passed=false), (t=100, passed=false), … sampai t=2000]`
  Step `turnLeft`. Expected pre-fix dan post-fix sama: **never confirmed** (passedCount tetap 0). Anti-spoof preserved.

- **E4 — Edge: single frame flash (anti instant-accept)**:
  `[(t=0, passed=true), (t=100, passed=false), (t=200, passed=false), (t=300, passed=false), (t=400, passed=false)]`
  Step `turnLeft`. Expected pre-fix: tidak confirm (holdMs cuma 0). Expected post-fix: tidak confirm (passedCount=1 < 3). Anti spoof flash preserved.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors** (turunan langsung dari klausul 3.1–3.9 di bugfix.md):

- **Step `blinkEyes` event-driven**: `_getHoldDurationMs(blinkEyes)` tetap `0` ms sesuai semantic asal — blink adalah *event detection*, bukan *hold*. Logic baru SHALL confirm blink di tick pertama `passed=true` (klausul 3.3).
- **Step `lookStraight` (capture 7 embedding)**: `_handleCapturePoseFrame` tidak disentuh — pipeline TFLite + multi-frame averaging tetap (klausul 3.4).
- **`FaceDetectionService.checkLivenessStep` thresholds**: yaw 12°, eye 0.4, lookStraight 15° tidak diubah. Fix tidak boleh melonggarkan deteksi pose (klausul 3.2).
- **Enforcement turnRight arah berlawanan**: `_turnLeftDirection` di `FaceDetectionService` tetap dipakai. Anti-spoof multi-step preserved (klausul 3.6).
- **Logging `[FACE LIVE]` setiap kelipatan 5 frame**: format existing harus tetap muncul. Fix boleh **menambah field** (mis. `passedCount=N failStreak=M`) tapi tidak boleh menghilangkan field existing (`step`, `yaw`, `leftEye`, `rightEye`, `passed`, `holdMs`) (klausul 3.7).
- **Safety net `livenessInstruction`**: tetap menampilkan instruksi step yang benar saat status sempat `detecting` di tengah fase liveness (klausul 3.8).
- **Privacy**: tidak ada embedding array yang ter-log (klausul 3.9).
- **Multi-frame proof anti-spoof**: pose-hold step **tidak boleh confirm di frame `passed=true` pertama**. Threshold frame baru ≥ 3 menjamin ini (klausul 3.5).
- **Gold path performance**: device mid/high-tier (frame interval 50–150 ms) SHALL confirm dalam ≤ 400 ms wall-time (sama atau lebih cepat dari sebelum fix) (klausul 3.1).

**Scope Preservation** — Input yang TIDAK dianggap bug condition (mis. blink event, lookStraight capture, foto statis non-pose, mouse click di UI lain, pengaturan threshold dari server) SHALL menghasilkan output identik dengan sebelum fix.

## Hypothesized Root Cause

Berdasarkan analisis di atas, root cause sudah diturunkan dari **trace kode + logcat user**, bukan tebakan. Hipotesis tertulis di sini sebagai eksplisit untuk Phase Implement:

1. **Algoritma "continuity wall-clock time" rapuh terhadap variasi frame interval**. Konstanta `_passedGapResetMs = 500 ms` mengasumsikan ML Kit menerbitkan frame setidaknya tiap ≤500 ms saat user menahan pose. Asumsi gugur di MediaTek + ColorOS dengan GC pause 100–250 ms.

2. **Tidak ada toleransi terhadap frame `passed=false` transien**. Logic lama implisit menganggap setiap gap "passed=true → passed=true" yang melebihi 500 ms = "user balik pose awal". Padahal di realita, gap itu sering disebabkan miss-detect ML Kit (wajah masih noleh, tapi ML Kit gagal estimate angle satu/dua frame).

3. **Pengukuran "hold" berbasis wall-time saja kehilangan informasi multi-frame**. Bukti "user benar-benar menahan pose" lebih akurat dinyatakan sebagai "ML Kit observe pose `passed` di N frame berbeda" daripada "wall-clock continuity ≥ 400 ms".

Hipotesis ini dikonfirmasi oleh logcat: `passed=true` muncul puluhan kali → bukti ML Kit detect pose-nya stabil → masalah ada di akumulator, bukan di detector.

Hipotesis alternatif yang **ditolak**:
- ❌ "ML Kit gagal detect pose" → ditolak: logcat menunjukkan `passed=true` 30+ kali.
- ❌ "Threshold yaw 12° terlalu ketat" → ditolak: logcat yaw 30°–57°, jauh di atas 12°.
- ❌ "Hold duration 400 ms terlalu tinggi untuk entry-level" → ditolak: turunkan ke 200 ms tetap akan kena reset gap karena structural bug.

## Correctness Properties

Property 1: Bug Condition - Pose-Hold Confirms in Realistic Frame Stream

_For any_ tick stream yang memenuhi `isBugCondition` (step pose, window ≥ 600 ms wall-clock, ≥ 60% tick `passed=true`, ada gap spike >500 ms antara tick `passed=true` consecutive), tracker yang sudah di-fix SHALL meng-confirm step (`stepCompleted == true`) sebelum atau pada tick terakhir, dengan jumlah `passedCount >= 3` dan `holdMs >= 300`. Tracker yang lama (unfixed) SHALL **tidak** meng-confirm step pada urutan tick yang sama (counterexample fixture E1).

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - Non-Bug Inputs Behave Identically

_For any_ input yang TIDAK memenuhi `isBugCondition` (blink event-detection, foto statis no-pose, single-frame flash, urutan tick mid-tier dengan interval reguler 50–150 ms, atau step `lookStraight` capture-pose), tracker yang sudah di-fix SHALL menghasilkan keputusan `stepCompleted` yang sama dengan tracker lama untuk skenario observed-passing — yaitu blink confirm di tick pertama, foto statis no-confirm, single-frame flash no-confirm, mid-tier confirm dalam ≤ 400 ms wall-clock.

**Validates: Requirements 3.1, 3.2, 3.3, 3.5, 3.7, 3.8**

## Fix Implementation

### Proposed Fix — Hybrid Frame-Count + Wall-Time Floor

Kandidat yang dipertimbangkan:

| Kandidat | Inti | Verdict |
|---|---|---|
| A. Naikkan `_passedGapResetMs` dari 500 → 1500 | Single-number tweak | ❌ **Ditolak** — masih time-based, fragile, dan menurunkan anti-spoof window kecil |
| B. Frame-count saja (≥ N frame `passed`) | Hilangkan dimensi waktu | ⚠️ Bisa, tapi rentan instant-accept di device super cepat (5 frame dalam 50 ms = 50 ms hold "fake") |
| C. **Hybrid: frame-count + wall-time floor + fail-streak tolerance** | Bukti multi-frame DAN bukti wall-time minimum | ✅ **Dipilih** |
| D. Naikkan threshold deteksi pose di `FaceDetectionService` | Ubah yaw 12° → 20° | ❌ **Ditolak** — melanggar klausul 3.2 |

**Justifikasi pilihan C:**

- **Addresses Expected Behavior 2.1 & 2.3**: bukti pose tahan = `passedCount ≥ 3` (multi-frame). Realme RMX5000 dengan frame interval 200–400 ms accrue 3 frame dalam ~600–1200 ms wall-time. User real-time ≤ ~1.5 detik ✓.
- **Addresses Expected Behavior 2.2**: toleransi frame `passed=false` transien via `failStreak` counter. Window di-reset hanya kalau `failStreak > _maxFailStreakAllowed` (mis. 2 frame consecutive fail). 1 frame jitter di tengah TIDAK reset.
- **Preserves 3.1 (no UX regression high-tier)**: di mid-tier 50–150 ms interval, 3 frame = 100–300 ms wall, lalu wall-time floor 300 ms guard → worst case confirm di 300 ms. Sebelumnya 400 ms continuous → fix **lebih cepat ~25%**.
- **Preserves 3.5 (anti-spoof multi-frame)**: `_minPassedFramesPose = 3` mensyaratkan 3 frame independen ML Kit melaporkan pose. Foto 1 frame flash tidak cukup. Wall-time floor 300 ms juga mensyaratkan setidaknya 300 ms presence.
- **Preserves 3.3 (blink event)**: blink di-config dengan `_minPassedFramesBlink = 1` dan `_minHoldFloorMsBlink = 0` → behavior identik dengan logic lama (`_getHoldDurationMs(blinkEyes) = 0`). Tidak ada regression.
- **Testability**: algoritma ini *pure function* (input: `(passed, step, nowMs)` + state internal; output: `stepCompleted`). Bisa di-unit-test dengan `flutter_test` murni — tidak butuh `CameraImage`, ML Kit, atau device fisik.

### Code changes spec

**File**: `mypresensi-mobile/lib/features/face/providers/face_provider.dart`

**File baru**: `mypresensi-mobile/lib/features/face/services/liveness_hold_tracker.dart`

#### 1. Buat kelas `LivenessHoldTracker` (file baru)

```dart
// lib/features/face/services/liveness_hold_tracker.dart
// Tracker akumulasi bukti hold pose untuk fase liveness check.
// Pure (tidak depend ke ML Kit / camera / DateTime.now) — testable di flutter_test.

import 'face_detection_service.dart' show LivenessStep;

class HoldTickResult {
  final bool stepCompleted;
  final int passedFrameCount;
  final int holdMs;
  final int failStreak;

  const HoldTickResult({
    required this.stepCompleted,
    required this.passedFrameCount,
    required this.holdMs,
    required this.failStreak,
  });
}

class LivenessHoldTracker {
  // Konfigurasi (default ditarik konstanta — lihat _config()).
  // ≥3 frame untuk pose; 1 untuk blink (event).
  static const int _minPassedFramesPose = 3;
  static const int _minPassedFramesBlink = 1;

  // Wall-time floor untuk pose (anti instant-accept). 0 untuk blink (event).
  static const int _minHoldFloorMsPose = 300;
  static const int _minHoldFloorMsBlink = 0;

  // Toleransi frame `passed=false` transien sebelum reset window.
  // 2 frame: 1 jitter natural + 1 ML Kit miss diperbolehkan.
  static const int _maxFailStreakAllowed = 2;

  // State window (semua nullable / 0 saat idle).
  int _passedFrameCount = 0;
  int _failStreak = 0;
  int? _passedSinceMs;

  HoldTickResult tick({
    required bool passed,
    required LivenessStep step,
    required int nowMs,
  }) {
    if (passed) {
      _passedSinceMs ??= nowMs;
      _passedFrameCount += 1;
      _failStreak = 0;
    } else if (_passedSinceMs != null) {
      _failStreak += 1;
      if (_failStreak > _maxFailStreakAllowed) {
        // User benar-benar break pose → reset window.
        _passedSinceMs = null;
        _passedFrameCount = 0;
        _failStreak = 0;
      }
    }

    final holdMs = _passedSinceMs == null ? 0 : nowMs - _passedSinceMs!;
    final required = _requiredFrames(step);
    final floor = _holdFloorMs(step);
    final stepCompleted = passed &&
        _passedFrameCount >= required &&
        holdMs >= floor;

    return HoldTickResult(
      stepCompleted: stepCompleted,
      passedFrameCount: _passedFrameCount,
      holdMs: holdMs,
      failStreak: _failStreak,
    );
  }

  void reset() {
    _passedFrameCount = 0;
    _failStreak = 0;
    _passedSinceMs = null;
  }

  static int _requiredFrames(LivenessStep step) =>
      step == LivenessStep.blinkEyes ? _minPassedFramesBlink : _minPassedFramesPose;

  static int _holdFloorMs(LivenessStep step) =>
      step == LivenessStep.blinkEyes ? _minHoldFloorMsBlink : _minHoldFloorMsPose;
}
```

#### 2. Modifikasi `FaceRegistrationNotifier` di `face_provider.dart`

Diff sketch (bukan exhaustive — fokus pada bagian yang berubah):

```dart
// === HAPUS bagian ini ===
// int? _passedSinceMs;
// int? _lastPassedAtMs;
// static const _passedGapResetMs = 500;
// int _getHoldDurationMs(LivenessStep step) {
//   return step == LivenessStep.blinkEyes ? 0 : 400;
// }

// === GANTI dengan ===
final LivenessHoldTracker _holdTracker = LivenessHoldTracker();

// === Reset di startRegistration() & reset() & noFace path ===
// (lokasi: startRegistration baris ~218, reset() baris ~498,
// noFace branch baris ~265, multipleFaces branch baris ~289,
// faceWidthRatio<0.25 branch baris ~314)
_holdTracker.reset(); // GANTI dari 'set _passedSinceMs = null; _lastPassedAtMs = null;'

// === Rewrite _handleLivenessFrame() ===
Future<void> _handleLivenessFrame(FaceDetectionResult result) async {
  final detector = ref.read(faceDetectionServiceProvider);
  final passed = detector.checkLivenessStep(state.livenessStep, result);
  final now = DateTime.now().millisecondsSinceEpoch;

  final tick = _holdTracker.tick(
    passed: passed,
    step: state.livenessStep,
    nowMs: now,
  );

  _debugFrameCounter++;
  if (_debugFrameCounter % 5 == 0) {
    debugPrint(
      '[FACE LIVE] step=${state.livenessStep.name} '
      'yaw=${result.headAngleY?.toStringAsFixed(1)} '
      'leftEye=${result.leftEyeOpenProb?.toStringAsFixed(2)} '
      'rightEye=${result.rightEyeOpenProb?.toStringAsFixed(2)} '
      'passed=$passed holdMs=${tick.holdMs} '
      'passedCount=${tick.passedFrameCount} failStreak=${tick.failStreak}',
    );
  }

  if (tick.stepCompleted) {
    debugPrint('[FACE LIVE] ✅ Step ${state.livenessStep.name} PASSED '
        '(passedCount=${tick.passedFrameCount} held ${tick.holdMs}ms)');
    _holdTracker.reset();
    _advanceLivenessStep();
  }
}
```

**Catatan penting**:
- Logging existing format dipertahankan (klausul 3.7). Field `passedCount` dan `failStreak` ditambah di akhir baris untuk diagnostic — bukan menggantikan field lama.
- Reset tracker di semua jalur "wajah hilang / multiple faces / wajah terlalu kecil" sama persis seperti perilaku lama (yang reset `_passedSinceMs`/`_lastPassedAtMs`). Tidak ada perubahan kontrol flow di luar `_handleLivenessFrame`.
- `_isInCooldown`, `_advanceLivenessStep`, `_handleCapturePoseFrame` TIDAK disentuh.
- Comment lama tentang `_passedGapResetMs` dan `_getHoldDurationMs` ikut dihapus, diganti dengan blok komentar baru di awal `_handleLivenessFrame` yang menjelaskan algoritma hybrid.

#### 3. Konstanta yang harus tetap ada (regression guard)

| Konstanta lama | Status | Catatan |
|---|---|---|
| `_targetEmbeddings = 7` | KEEP | Klausul 3.4 |
| `_noFaceThreshold = 5` | KEEP | Tidak terkait fix |
| `_cooldownDuration = 500ms` | KEEP | Antar-step debounce |
| `_passedGapResetMs = 500` | **REMOVE** | Diganti `_maxFailStreakAllowed` di tracker |
| `_getHoldDurationMs()` | **REMOVE** | Diganti `_holdFloorMs()` static di tracker |

## Testing Strategy

### Validation Approach

Strategi dua-fase: (1) **eksplor** dengan tick stream Realme RMX5000 di unit test untuk surface counterexample pada logic lama, (2) **preserve** dengan tick stream representative dari blink/foto-statis/mid-tier/edge-case.

Karena logic akumulasi di-extract ke `LivenessHoldTracker` sebagai bagian dari fix, exploration test perlu skenario refactor minimal di Phase 1: **sebelum fix**, kelas `LivenessHoldTracker` belum ada — maka task pertama pada `tasks.md` akan **membuat kelas dengan logic LAMA terlebih dulu** (refactor pure, tanpa behavior change), sehingga test bisa langsung mereproduksi bug pada API yang stabil. Task fix kemudian **mengganti implementasi `tick()` saja** (bukan API).

Manfaat: API tracker stabil sepanjang lifecycle PR; test exploration langsung bisa berbicara dalam istilah `tracker.tick(...)` tanpa harus mengakses field privat di Notifier.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexample E1 (Realme RMX5000) untuk membuktikan logic akumulasi lama gagal pada frame stream realistic.

**Test Plan**: Refactor `_handleLivenessFrame` body ke `LivenessHoldTracker` dengan logic LAMA (Phase 1, pre-fix). Tulis test yang:
1. Instantiate `LivenessHoldTracker` (logic lama).
2. Feed urutan tick E1 dari §Examples (`turnLeft`, 7 tick dengan timestamps konkret).
3. Assert pada akhir stream: tidak ada satu pun tick yang return `stepCompleted == true`.
4. Pada code FIXED: assert sebaliknya — minimal salah satu tick di stream return `stepCompleted == true` (idealnya tick t=1320 atau t=1550).

**Test Cases**:
1. **`testWidgets / test('Realme RMX5000 — pose hold confirms', …)`**: Feed E1 → assert `stepCompleted` TRUE pada salah satu tick. Akan FAIL pada logic lama karena window di-reset di t=1100 (gap 880 ms > 500 ms).
2. **(Opsional, sebagai sanity) `test('Realme RMX5000 — pre-fix demonstrates bug', …)`**: Feed E1 → assert `stepCompleted` FALSE di semua tick. Test ini PASS pada logic lama (bukti bug exist), kemudian akan FAIL pada logic baru (yang sekarang confirm). Test ini di-mark sebagai "characterization test" dan boleh di-delete setelah fix merged.

**Expected Counterexamples**:
- E1 tick stream: di logic lama, akumulator `_passedSinceMs` di-reset di t=1100 → `holdMs` selalu < 400 ms → `stepCompleted` selalu false. Frame interval 200–400 ms + gap 880 ms = bug condition terpenuhi.
- Possible underlying cause: konstanta `_passedGapResetMs = 500` ms tidak akomodatif terhadap frame burst pattern MediaTek + ColorOS.

### Fix Checking

**Goal**: Setelah fix, untuk semua tick stream yang memenuhi `isBugCondition`, tracker SHALL meng-confirm step.

**Pseudocode:**

```
FOR ALL tickStream WHERE isBugCondition(tickStream) DO
  tracker := LivenessHoldTracker_fixed()
  result  := <last HoldTickResult dari tracker.tick(...) atas seluruh stream>
  ASSERT result.passedFrameCount >= 3
  ASSERT result.holdMs >= 300
  ASSERT exists tick t in stream WHERE tracker.tick(t).stepCompleted = true
END FOR
```

### Preservation Checking

**Goal**: Untuk semua input non-bug-condition, tracker fixed berperilaku identik dengan tracker lama untuk keputusan `stepCompleted`.

**Pseudocode:**

```
FOR ALL tickStream WHERE NOT isBugCondition(tickStream) DO
  oldDecision := simulateOldTracker(tickStream)   // bool
  newDecision := simulateFixedTracker(tickStream) // bool
  ASSERT oldDecision = newDecision
END FOR
```

**Testing Approach**: Property-based testing dengan generator tick-stream sederhana (tanpa lib eksternal — pakai `Random` dari `dart:math` di `flutter_test`). Cukup karena domain input adalah bool×int yang mudah di-enumerate. Generator menghasilkan stream yang TIDAK memenuhi `isBugCondition` (mayoritas fail, atau mayoritas pass tanpa gap, atau step blink, atau window < 600 ms), lalu simulasi paralel dua tracker dan assert keputusan akhir sama.

**Test Plan**: Observasi dulu behavior on UNFIXED logic untuk skenario E2, E3, E4 di §Examples (jalankan tracker lama dengan input itu, catat hasil `stepCompleted` per tick). Lalu tulis test asseting hasil yang sama pada tracker fixed.

**Test Cases**:
1. **Blink event preservation (E1-blink scenario)**: Feed `[(t=0, passed=true)]` dengan step `blinkEyes` → assert `stepCompleted = true` pada tick pertama. Identik di unfixed dan fixed (klausul 3.3).
2. **Foto statis no-confirm (E3)**: Feed 20 tick `passed=false` dengan step `turnLeft` → assert `stepCompleted = false` pada semua tick. Identik di unfixed dan fixed (klausul 3.5).
3. **Single-frame flash no-confirm (E4)**: Feed 1 tick passed lalu 4 tick fail → assert `stepCompleted = false`. Identik (klausul 3.5).
4. **Mid-tier gold path (E2)**: Feed 4 tick interval 80 ms `[t=0, t=80, t=160, t=240]` semua passed → assert tracker fixed confirm dalam ≤ 400 ms wall-clock (sebelumnya 400 ms continuous, sekarang ~300 ms floor). Tidak slower (klausul 3.1).
5. **Property-based — random non-bug streams**: 100 stream acak yang TIDAK memenuhi `isBugCondition` → assert `oldDecision == newDecision`.

### Unit Tests

- Test setiap branch di `LivenessHoldTracker.tick()`: passed first time (start window), passed continuing, fail within tolerance, fail exceeding tolerance (reset).
- Test `reset()` mengosongkan state.
- Test bahwa step `blinkEyes` confirm di tick pertama.
- Test bahwa step `turnLeft`/`turnRight` butuh ≥3 frame DAN ≥300 ms.

### Property-Based Tests

Lihat preservation test #5 di atas. Domain input cukup terbatas → 100 random sample sufficient untuk kepercayaan; tidak butuh lib `glados` atau eksternal lain (rule pubspec lock — no new deps).

### Integration Tests

(Tidak ditambahkan dalam fix ini — `flutter_test` cukup. Integration test face flow utuh butuh device kamera fisik yang di luar scope verifikasi pre-merge.) Verifikasi end-to-end di RMX5000 fisik dilakukan secara manual sesuai §Verification Plan.

## Verification Plan (Device Entry-Level — RMX5000, Tanpa APK Release)

### Preconditions

- Laptop dev dan RMX5000 di WiFi yang sama; `_lanIp` di `app_config.dart` sudah pointing ke IP laptop terkini.
- USB debugging aktif di RMX5000.
- Backend Next.js running (`npm run dev` di `mypresensi-web`).

### Steps

1. **Static check**:
   ```powershell
   flutter analyze
   ```
   Harus 0 issues.

2. **Unit test**:
   ```powershell
   flutter test test/face/liveness_hold_tracker_test.dart
   ```
   Semua test pass setelah fix (exploration test E1 PASS pada fixed; preservation E2/E3/E4 PASS).

3. **Run debug build di device fisik**:
   ```powershell
   flutter run -d <RMX5000-device-id>
   ```
   Debug build cukup karena bug condition adalah timing-based dari ML Kit, **tidak tergantung ProGuard/R8 release optimizations**. Algoritma akumulasi adalah Dart-pure — observable di debug.

4. **Reproduce flow**:
   - Login mobile dengan akun mahasiswa test (dari `mypresensi-web/.dev-accounts.md`).
   - Masuk ke flow registrasi wajah (Profil → Daftarkan Wajah).
   - Lewati pose `lookStraight` (capture 7 embedding) — sudah jalan sebelum fix.
   - Lewati `blinkEyes` (event-detect, sudah jalan sebelum fix).
   - **Step kunci**: `turnLeft` — user noleh kiri, tahan ~1 detik. Step harus confirm dan pindah ke `turnRight`.
   - Step `turnRight` — user noleh kanan, tahan ~1 detik. Step harus confirm dan pindah ke `lookStraight` finalize.

5. **Observe logcat** (jendela PowerShell terpisah):
   ```powershell
   adb logcat -s flutter | Select-String "FACE LIVE"
   ```
   Pattern yang diharapkan setelah fix:
   ```
   [FACE LIVE] step=turnLeft yaw=37.4 leftEye=0.92 rightEye=0.93 passed=true holdMs=215 passedCount=2 failStreak=0
   [FACE LIVE] step=turnLeft yaw=42.1 leftEye=0.91 rightEye=0.93 passed=true holdMs=420 passedCount=3 failStreak=0
   [FACE LIVE] ✅ Step turnLeft PASSED (passedCount=3 held 420ms)
   [FACE LIVE] step=turnRight yaw=-31.8 leftEye=0.94 rightEye=0.92 passed=true holdMs=180 passedCount=2 failStreak=0
   [FACE LIVE] ✅ Step turnRight PASSED (passedCount=3 held 530ms)
   ```
   Field `passedCount` dan `failStreak` adalah signal baru — gunakan untuk tuning di field test selanjutnya kalau perlu.

6. **Negative path**:
   - Tahan kepala lurus, jangan noleh — step `turnLeft` SHALL tidak confirm. `passedCount` di log tetap 0.
   - Flash noleh kiri 1 frame lalu kembali lurus — step SHALL tidak confirm (`passedCount` capped 1, lalu reset setelah `failStreak > 2`).

7. **Visual confirmation (RUNTIME)**: Mohon screenshot / screencast dari `adb logcat` saat pose hold berhasil + screenshot UI saat step `turnLeft` → `turnRight` → completed berhasil. Sesuai rule 06 §A Law 4 (Screenshot-as-proof untuk UI changes), klaim "verified" hanya boleh setelah user kirim bukti runtime.

### Risk & Rollback

- **Risk**: jika di field test pasca-fix masih gagal di device tertentu (mis. chipset Helio yang lebih lambat lagi), tuning konstanta `_minPassedFramesPose` (turunkan ke 2) atau `_minHoldFloorMsPose` (turunkan ke 200) cukup di satu file. Tidak ada perubahan API.
- **Rollback**: revert perubahan di `face_provider.dart` + delete `liveness_hold_tracker.dart`. Tidak ada migration DB / dependency change.

## ✅ Verifikasi Phase 2 (Design)

| Check | Result |
|-------|--------|
| `bugfix.md` klausul 1.x/2.x/3.x ter-trace ke design | ✅ Glossary + Preservation + Properties cross-ref klausul |
| Trace path kode `_handleLivenessFrame` lengkap dengan file:line | ✅ §Bug Details |
| Pendekatan fix dipilih dengan justifikasi terhadap 3.1, 3.5, testability | ✅ §Fix Implementation |
| Code change spec konkret (file, fungsi, value) + diff sketch | ✅ §Fix Implementation |
| Test strategy mereproduksi bug + preservation, jalan di `flutter_test` | ✅ §Testing Strategy |
| Verification plan untuk RMX5000 tanpa APK release | ✅ §Verification Plan |
| Tidak ada dependency baru | ✅ pubspec tidak disentuh |
| Multi-frame proof preserved (klausul 3.5) | ✅ `_minPassedFramesPose = 3` |
| Mid-tier no slowdown (klausul 3.1) | ✅ Worst-case 300 ms vs baseline 400 ms |
| Threshold deteksi pose tidak diubah (klausul 3.2) | ✅ `FaceDetectionService.checkLivenessStep` not touched |
| Format `[FACE LIVE]` log existing dipertahankan (klausul 3.7) | ✅ Field lama tetap, field baru di-append |
| Privacy: tidak ada embedding ter-log (klausul 3.9) | ✅ Logging hanya signal turunan |

Status legend: ✅ Confirmed / ❌ Failed / ⏳ Pending user action

**Phase 2 selesai. Stop di sini.** User akan klik "Move to Tasks" di UI untuk lanjut ke Phase 3 (tasks.md).
