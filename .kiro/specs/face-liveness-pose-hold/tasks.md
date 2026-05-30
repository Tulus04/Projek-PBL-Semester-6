
# Implementation Plan — Face Liveness Pose Hold

## Overview

Bugfix flow untuk fitur akumulasi hold pose `turnLeft`/`turnRight` di `FaceRegistrationNotifier`. Strategi: **refactor pure → exploration + preservation tests pada UNFIXED tracker → implement fix → verify → manual checklist device fisik**.

**Effort estimate**: 3–5 jam (refactor 30 menit, tests 60 menit, fix 45 menit, verifikasi static 30 menit, manual device 60–90 menit).

**Aturan kunci**:

- Task 1 dan Task 2 dijalankan terhadap **logic LAMA** (UNFIXED). Tracker yang dibuat di Task 1 harus berperilaku identik dengan `_handleLivenessFrame` saat ini — refactor murni, **bukan** fix.
- Exploration test di Task 2.1 **HARUS FAIL** terhadap UNFIXED tracker — kegagalan itu yang membuktikan bug ada (counterexample E1).
- Preservation tests di Task 2.2 **HARUS PASS** terhadap UNFIXED tracker — itulah baseline yang dijaga setelah fix.
- Tidak boleh tambah dependency baru ke `pubspec.yaml`. Pakai `flutter_test` + `dart:math` saja.
- Identifier kode dalam Inggris, komentar header dalam Bahasa Indonesia.

**Files baru** (2):
1. `mypresensi-mobile/lib/features/face/services/liveness_hold_tracker.dart`
2. `mypresensi-mobile/test/face/liveness_hold_tracker_test.dart`

**Files modified** (1):
1. `mypresensi-mobile/lib/features/face/providers/face_provider.dart`

**Files NOT modified**:
- `mypresensi-mobile/lib/features/face/services/face_detection_service.dart` — threshold deteksi pose (yaw 12°, eye 0.4) preserved (klausul 3.2)
- `mypresensi-mobile/pubspec.yaml` — no new dependency
- `mypresensi-web/**` — bug murni di mobile

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "name": "Refactor pure (sequential)",
      "tasks": ["1.1", "1.2", "1.3"],
      "depends_on": []
    },
    {
      "wave": 2,
      "name": "Exploration + preservation tests pada UNFIXED",
      "tasks": ["2.1", "2.2", "2.3"],
      "depends_on": ["1.3"]
    },
    {
      "wave": 3,
      "name": "Implement fix + re-verify tests",
      "tasks": ["3.1", "3.2", "3.3", "3.4", "3.5"],
      "depends_on": ["2.3"]
    },
    {
      "wave": 4,
      "name": "Full test suite checkpoint",
      "tasks": ["4"],
      "depends_on": ["3.5"]
    },
    {
      "wave": 5,
      "name": "Manual verification device fisik (USER-ACTION)",
      "tasks": ["5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7"],
      "depends_on": ["4"]
    }
  ]
}
```

| ID | Task | Depends on |
|----|------|------------|
| 1.1 | Buat `liveness_hold_tracker.dart` dengan logic LAMA | – |
| 1.2 | Refactor `FaceRegistrationNotifier` delegate ke tracker | 1.1 |
| 1.3 | Verifikasi `flutter analyze` + `flutter build apk --debug` clean | 1.2 |
| 2.1 | **Property 1: Bug Condition** — Tulis exploration test E1 (EXPECTED FAIL) | 1.3 |
| 2.2 | **Property 2: Preservation** — Tulis preservation tests E2/E3/E4/blink + property-based 100 random streams | 1.3 |
| 2.3 | Verifikasi exploration FAIL + preservation PASS | 2.1, 2.2 |
| 3.1 | Update `LivenessHoldTracker.tick()` ke algoritma hybrid | 2.3 |
| 3.2 | Update logging `[FACE LIVE]` tambah `passedCount`+`failStreak` | 3.1 |
| 3.3 | **Property 1: Expected Behavior** — Re-run exploration E1 (EXPECTED PASS) | 3.1 |
| 3.4 | **Property 2: Preservation** — Re-run preservation tests (EXPECTED PASS) | 3.1 |
| 3.5 | Verifikasi `flutter analyze` + `flutter build apk --debug` clean pasca-fix | 3.2, 3.3, 3.4 |
| 4 | Full test suite + final analyze | 3.5 |
| 5.1–5.7 | Manual verification RMX5000 (USER) | 4 |

## Tasks

- [x] 1. Refactor pure — extract logic akumulasi lama ke `LivenessHoldTracker`

  - [x] 1.1 Buat file `mypresensi-mobile/lib/features/face/services/liveness_hold_tracker.dart`
    - Definisikan kelas `HoldTickResult` dengan field final: `bool stepCompleted`, `int passedFrameCount`, `int holdMs`, `int failStreak` (semua wajib di-pass via constructor `const`)
    - Definisikan kelas `LivenessHoldTracker` dengan API publik:
      - `HoldTickResult tick({required bool passed, required LivenessStep step, required int nowMs})`
      - `void reset()`
    - Import `LivenessStep` dari `face_detection_service.dart` (`show LivenessStep`)
    - **Implementasi `tick()` di task ini WAJIB MENIRU LOGIC LAMA `_handleLivenessFrame`** persis: state internal `int? _passedSinceMs`, `int? _lastPassedAtMs`; konstanta `static const int _passedGapResetMs = 500`; `_holdDurationMs(step)` return `step == LivenessStep.blinkEyes ? 0 : 400`. Branch:
      - Jika `passed` true: kalau `_lastPassedAtMs != null && nowMs - _lastPassedAtMs! > _passedGapResetMs` → set `_passedSinceMs = nowMs`. Lalu `_passedSinceMs ??= nowMs; _lastPassedAtMs = nowMs;`
      - Hitung `holdMs = _passedSinceMs == null ? 0 : nowMs - _passedSinceMs!`
      - `stepCompleted = passed && holdMs >= _holdDurationMs(step)`
    - Field `passedFrameCount` dan `failStreak` di `HoldTickResult` di-return dengan nilai `0` di Task 1 (placeholder; akan dipakai sungguhan setelah fix di Task 3) — komentari "// LAMA: tidak dipakai logic continuity, di-return 0 untuk kompat API."
    - Tulis komentar header file Bahasa Indonesia: tujuan + catatan "logic LAMA, equivalent dengan `_handleLivenessFrame` continuity wall-clock"
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 1.2 Refactor `FaceRegistrationNotifier` agar delegate ke tracker
    - File: `mypresensi-mobile/lib/features/face/providers/face_provider.dart`
    - Tambah import `'../services/liveness_hold_tracker.dart'`
    - Tambah field instance `final LivenessHoldTracker _holdTracker = LivenessHoldTracker();` di Notifier
    - Hapus field `int? _passedSinceMs;` (line 207) dan `int? _lastPassedAtMs;` (line 208)
    - Hapus konstanta `static const _passedGapResetMs = 500;` (line 237) dan method `int _getHoldDurationMs(LivenessStep step)` (line 231–234)
    - Ganti semua `_passedSinceMs = null; _lastPassedAtMs = null;` (di `startRegistration`, branch `noFace`, `multipleFaces`, `faceWidthRatio<0.25`, dan `reset()`) dengan `_holdTracker.reset();`
    - Rewrite body `_handleLivenessFrame` (line 461–497):
      - Panggil `final tick = _holdTracker.tick(passed: passed, step: state.livenessStep, nowMs: now);`
      - Pertahankan format log existing `[FACE LIVE] step=… yaw=… leftEye=… rightEye=… passed=… holdMs=…` setiap kelipatan 5 frame; pakai `tick.holdMs`. **JANGAN tambah field baru di Task 1** (klausul 3.7 — log format identik dengan sebelum refactor)
      - Kondisi advance: `if (tick.stepCompleted) { … _holdTracker.reset(); _advanceLivenessStep(); }`
    - **Behavior runtime di Task 1 WAJIB identik dengan sebelum refactor.** Tidak ada fix di sini, hanya re-organize kode
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.7_

  - [x] 1.3 Verifikasi static analysis & build
    - Jalankan `flutter analyze` di `mypresensi-mobile/` — WAJIB 0 issues
    - Jalankan `flutter build apk --debug` di `mypresensi-mobile/` — WAJIB exit 0 (sesuai rule 06 §A Law 1: runtime affect → butuh build success)
    - Smoke check di emulator atau analog: pastikan flow registrasi wajah masih jalan untuk skenario non-bug-condition (gold path mid-tier) — test dependent step `lookStraight` capture + `blinkEyes` event harus tetap confirm. Optional: cukup verifikasi via test di Task 2.2 (preservation tests pada tracker LAMA harus PASS — itulah confirmation behavior preserved)
    - _Requirements: 3.1, 3.3, 3.4_

- [x] 2. Tulis exploration + preservation tests pada UNFIXED tracker

  - [x] 2.1 **Property 1: Bug Condition** — Realme RMX5000 Pose Hold Counterexample
    - **CRITICAL**: Test ini WAJIB FAIL di kode UNFIXED (logic lama dari Task 1). Failure = bukti bug ada
    - **DO NOT attempt to fix the test or the code when it fails di Task 2** — failure adalah expected outcome
    - **NOTE**: Test ini meng-encode expected behavior — akan validate fix saat PASS di Task 3.3
    - **GOAL**: Surface counterexample fixture E1 yang membuktikan algoritma continuity wall-clock 500 ms gagal
    - **Scoped PBT Approach**: Untuk bug deterministik ini, scope property ke fixture konkret E1 (single concrete tick stream) — reproducibility absolut, tidak butuh `Random`
    - Buat file `mypresensi-mobile/test/face/liveness_hold_tracker_test.dart`
    - Tulis fixture `E1` (Realme RMX5000) sebagai `const List<({int t, bool passed})>`:
      ```dart
      const e1 = [
        (t: 0,    passed: true),
        (t: 220,  passed: true),
        (t: 480,  passed: false),
        (t: 720,  passed: false),
        (t: 1100, passed: true),
        (t: 1320, passed: true),
        (t: 1550, passed: true),
      ];
      ```
    - Test case: `test('Property 1: Bug Condition - E1 RMX5000 pose hold should confirm', () { ... })`
    - Loop semua tick E1, panggil `tracker.tick(passed: tick.passed, step: LivenessStep.turnLeft, nowMs: tick.t)`, kumpulkan `List<HoldTickResult>`
    - Assertion (sesuai design §Correctness Properties Property 1):
      - `expect(results.any((r) => r.stepCompleted), isTrue, reason: 'E1 stream harus confirm step di salah satu tick')`
      - `expect(results.last.passedFrameCount, greaterThanOrEqualTo(3))`
      - `expect(results.last.holdMs, greaterThanOrEqualTo(300))`
    - Run: `flutter test test/face/liveness_hold_tracker_test.dart --plain-name "Property 1"` di `mypresensi-mobile/`
    - **EXPECTED OUTCOME**: Test FAIL di UNFIXED tracker. Counterexample yang akan terbukti: di tick t=1100, gap dari `_lastPassedAtMs=220` adalah 880 ms > 500 ms → window `_passedSinceMs` di-reset ke 1100 → `holdMs` selalu < 400 ms → `stepCompleted` selalu false di seluruh stream. Itu mengkonfirmasi bug ada
    - Dokumentasikan counterexample yang ditemukan (catat di output `flutter test` atau di komentar test) sebagai bukti root cause
    - Mark task complete saat test ditulis, dijalankan, dan failure-nya terdokumentasi (BUKAN saat test PASS)
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3_

  - [x] 2.2 **Property 2: Preservation** — Non-Bug Inputs Behave Identically
    - **IMPORTANT**: Follow observation-first methodology — observe behavior tracker LAMA pada non-bug inputs, lalu encode hasil observasi ke property tests
    - **GOAL**: Capture baseline behavior yang WAJIB tetap utuh setelah fix (klausul 3.1, 3.2, 3.3, 3.5, 3.7, 3.8)
    - Tambahkan ke `mypresensi-mobile/test/face/liveness_hold_tracker_test.dart`:

    **Test 2.2.a — Blink event (klausul 3.3)**
    - Skenario: 1 tick `(t: 0, passed: true)` dengan `step: LivenessStep.blinkEyes`
    - Observasi pada UNFIXED: `tick(passed=true, step=blink, nowMs=0)` → `holdMs=0`, `_holdDurationMs(blink)=0`, `passed && holdMs >= 0` → `stepCompleted=true`
    - Assert: `expect(result.stepCompleted, isTrue)`. Test PASS di UNFIXED

    **Test 2.2.b — Mid-tier gold path E2 (klausul 3.1)**
    - Fixture: `[(t:0,p:true), (t:80,p:true), (t:160,p:true), (t:240,p:true), (t:320,p:true), (t:400,p:true), (t:480,p:true)]` step `turnLeft`
    - Observasi pada UNFIXED: tick t=0 set `_passedSinceMs=0`. Setiap tick berikutnya `_lastPassedAtMs` di-update; gap maks 80 ms < 500 ms → window stabil. Saat `holdMs >= 400` (di tick t=400 atau t=480) → `stepCompleted=true`
    - Assert: `expect(results.where((r) => r.stepCompleted).isNotEmpty, isTrue)`; `expect(firstConfirmedTick.t, lessThanOrEqualTo(480))` (≤ 400 ms continuity sebelumnya). Test PASS di UNFIXED. Setelah fix, akan tetap PASS (worst-case lebih cepat ~300 ms, klausul 3.1 tidak slower)

    **Test 2.2.c — Foto statis E3 (klausul 3.5 anti-spoof)**
    - Fixture: 20 tick consecutive `passed: false`, interval 100 ms, step `turnLeft`
    - Observasi pada UNFIXED: `_passedSinceMs` selalu null → `holdMs=0` → `stepCompleted=false` di semua tick
    - Assert: `expect(results.every((r) => !r.stepCompleted), isTrue)`. Test PASS di UNFIXED

    **Test 2.2.d — Single-frame flash E4 (klausul 3.5 anti-spoof)**
    - Fixture: `[(t:0,p:true), (t:100,p:false), (t:200,p:false), (t:300,p:false), (t:400,p:false), (t:500,p:false)]` step `turnLeft`
    - Observasi pada UNFIXED: tick t=0 set `_passedSinceMs=0`, `_lastPassedAtMs=0`. Tick t=100 false (no update). `holdMs` hitung saat tick t=400 false: `400-0 = 400`, tapi karena `passed=false` di tick itu → `passed && holdMs >= 400` → false. Tidak pernah confirm di stream ini
    - Assert: `expect(results.every((r) => !r.stepCompleted), isTrue)`. Test PASS di UNFIXED

    **Test 2.2.e — Property-based random non-bug streams**
    - Pakai `import 'dart:math';` — instantiate `Random(42)` (seed deterministik untuk reproducibility)
    - Generator helper `List<Tick> genNonBugStream(Random rng)` yang menghasilkan salah satu kategori (random pilih):
      - **Kategori A** (mayoritas fail): 80% tick `passed=false`, interval 50–150 ms, step `turnLeft`, panjang 5–15 tick
      - **Kategori B** (window pendek): semua `passed=true`, interval 50–150 ms, total window < 600 ms, step `turnLeft`
      - **Kategori C** (mid-tier reguler): 100% `passed=true`, interval 50–150 ms, panjang 5–15 tick, step `turnLeft` atau `turnRight`
      - **Kategori D** (blink): 1 tick `passed=true` step `blinkEyes`
    - Loop 100 stream:
      - Buat 2 tracker instance terpisah: `oldTracker = LivenessHoldTracker()` (Task 1 implementasi LAMA), dan `simulatedNewTracker = LivenessHoldTracker()` (di Phase 2 ini, simulated-new = old karena belum ada fix)
      - Feed stream identik ke kedua tracker, kumpulkan `List<bool>` keputusan `stepCompleted` per tick
      - Assert: `expect(oldDecisions, equals(simulatedNewDecisions), reason: 'Stream non-bug-condition harus berperilaku identik')`
    - **EXPECTED OUTCOME**: Test PASS di Phase 2 (trivially — old vs old). Setelah fix di Task 3 dengan tracker yang baru, test ini akan re-run di Task 3.4 dan akan **tetap PASS** karena property design menjamin preservation untuk non-bug inputs (dijamin oleh fix yang hanya mengubah branch yang relevan dengan bug condition)
    - **Catatan untuk reviewer**: Test E2/E3/E4 + property-based di Task 2.2 ini seluruhnya PASS di UNFIXED tracker. Setelah fix, semua tetap PASS. Itu yang menjadi preservation guarantee
    - Run: `flutter test test/face/liveness_hold_tracker_test.dart --plain-name "Property 2"` di `mypresensi-mobile/`
    - **EXPECTED OUTCOME**: Semua test 2.2.a–2.2.e PASS di UNFIXED. Mark task complete saat semua tests written, run, dan PASS pada UNFIXED
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 3.7_

  - [x] 2.3 Verifikasi exploration FAIL + preservation PASS sebelum lanjut
    - Run full test file: `flutter test test/face/liveness_hold_tracker_test.dart` di `mypresensi-mobile/`
    - **EXPECTED OUTCOME** (di kode UNFIXED, sebelum Task 3):
      - Test 2.1 (Property 1): **FAIL** dengan counterexample E1 — bukti bug exist
      - Test 2.2.a–e (Property 2): **PASS** semua — baseline preservation captured
    - Output `flutter test` adalah artifact yang menjustifikasi keberadaan Task 3 (fix). Simpan log singkat (ringkasan PASS/FAIL count) di komentar commit atau PR description
    - **JANGAN lanjut ke Task 3 sampai pattern di atas tercapai.** Kalau Test 2.1 PASS di UNFIXED → ada kemungkinan refactor Task 1 tidak benar-benar identik dengan logic lama → balik ke Task 1.2
    - _Requirements: validates Property 1 fail-state and Property 2 baseline_

- [x] 3. Implement fix — replace `LivenessHoldTracker.tick()` dengan algoritma hybrid

  - [x] 3.1 Update `LivenessHoldTracker` ke algoritma hybrid frame-count + wall-time floor + fail-streak
    - File: `mypresensi-mobile/lib/features/face/services/liveness_hold_tracker.dart`
    - Hapus konstanta `_passedGapResetMs = 500` dan method `_holdDurationMs` legacy. Hapus state field `_lastPassedAtMs`
    - Tambahkan konstanta baru (sesuai design §Fix Implementation):
      - `static const int _minPassedFramesPose = 3;`
      - `static const int _minPassedFramesBlink = 1;`
      - `static const int _minHoldFloorMsPose = 300;`
      - `static const int _minHoldFloorMsBlink = 0;`
      - `static const int _maxFailStreakAllowed = 2;`
    - Tambahkan state baru: `int _passedFrameCount = 0;`, `int _failStreak = 0;`. Tetap pakai `int? _passedSinceMs;`
    - Tambahkan helper static private:
      - `static int _requiredFrames(LivenessStep step) => step == LivenessStep.blinkEyes ? _minPassedFramesBlink : _minPassedFramesPose;`
      - `static int _holdFloorMs(LivenessStep step) => step == LivenessStep.blinkEyes ? _minHoldFloorMsBlink : _minHoldFloorMsPose;`
    - Implementasi baru `tick()`:
      - Jika `passed` true: `_passedSinceMs ??= nowMs; _passedFrameCount += 1; _failStreak = 0;`
      - Else (passed false) DAN `_passedSinceMs != null`: `_failStreak += 1; if (_failStreak > _maxFailStreakAllowed) { _passedSinceMs = null; _passedFrameCount = 0; _failStreak = 0; }`
      - `final holdMs = _passedSinceMs == null ? 0 : nowMs - _passedSinceMs!;`
      - `final stepCompleted = passed && _passedFrameCount >= _requiredFrames(step) && holdMs >= _holdFloorMs(step);`
      - Return `HoldTickResult(stepCompleted: stepCompleted, passedFrameCount: _passedFrameCount, holdMs: holdMs, failStreak: _failStreak);`
    - Update `reset()` untuk zero `_passedFrameCount` dan `_failStreak` juga
    - Update komentar header file: ganti dari "logic LAMA continuity wall-clock" ke "hybrid frame-count + wall-time floor + fail-streak tolerance — anti-spoof preserved (≥3 frame), Realme RMX5000 confirmable (≤1.5 detik real-time)"
    - _Bug_Condition: isBugCondition(tickStream) where step IN [turnLeft, turnRight] AND windowMs >= 600 AND passedCount/total >= 0.6 AND hasGapSpike (>500 ms between consecutive passed-true ticks)_
    - _Expected_Behavior: `stepCompleted == true` dengan `passedFrameCount >= 3` dan `holdMs >= 300` untuk semua tick stream yang memenuhi isBugCondition_
    - _Preservation: blink event-detect 1-frame, foto statis no-confirm, single-frame flash no-confirm, mid-tier ≤400 ms (sekarang ≤300 ms — lebih cepat, tidak slower)_
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.5_

  - [x] 3.2 Update logging di `_handleLivenessFrame` untuk emit `passedCount` dan `failStreak`
    - File: `mypresensi-mobile/lib/features/face/providers/face_provider.dart`
    - Di `_handleLivenessFrame` (block log per-5-frame), append field baru ke baris log existing:
      ```dart
      debugPrint(
        '[FACE LIVE] step=${state.livenessStep.name} '
        'yaw=${result.headAngleY?.toStringAsFixed(1)} '
        'leftEye=${result.leftEyeOpenProb?.toStringAsFixed(2)} '
        'rightEye=${result.rightEyeOpenProb?.toStringAsFixed(2)} '
        'passed=$passed holdMs=${tick.holdMs} '
        'passedCount=${tick.passedFrameCount} failStreak=${tick.failStreak}',
      );
      ```
    - Update juga log "✅ PASSED" untuk include `passedCount`:
      ```dart
      debugPrint('[FACE LIVE] ✅ Step ${state.livenessStep.name} PASSED '
          '(passedCount=${tick.passedFrameCount} held ${tick.holdMs}ms)');
      ```
    - **CRITICAL** (klausul 3.7): Field log existing `step`, `yaw`, `leftEye`, `rightEye`, `passed`, `holdMs` HARUS tetap ada — fix hanya **menambah** `passedCount` dan `failStreak`, tidak mengganti
    - Verifikasi: `flutter analyze` 0 issues
    - _Requirements: 2.4, 3.7_

  - [x] 3.3 **Property 1: Expected Behavior** — Verify exploration test E1 sekarang PASSES
    - **IMPORTANT**: Re-run test yang SAMA dari Task 2.1 — JANGAN tulis test baru. Test di Task 2.1 sudah meng-encode expected behavior; saat ia PASS, itu konfirmasi fix bekerja
    - Run: `flutter test test/face/liveness_hold_tracker_test.dart --plain-name "Property 1"` di `mypresensi-mobile/`
    - **EXPECTED OUTCOME**: Test 2.1 (E1 RMX5000) PASS — `stepCompleted` true di salah satu tick (ekspektasi: di tick t=1320 dengan `passedCount=4`, `holdMs=1320` atau di tick t=1550)
    - Trace cepat verifikasi (debugging hint kalau gagal): di logic baru, tick t=480 fail → `_failStreak=1`. Tick t=720 fail → `_failStreak=2`. **`_failStreak` masih ≤ `_maxFailStreakAllowed=2`** → window TIDAK reset. Tick t=1100 passed → `_passedFrameCount=3`, `_failStreak=0`, `holdMs=1100` ≥ 300 → `stepCompleted=true`. **Bug terkonfirmasi resolved**
    - _Requirements: 2.1, 2.2, 2.3 (Expected Behavior Properties)_

  - [x] 3.4 **Property 2: Preservation** — Verify preservation tests tetap PASS
    - **IMPORTANT**: Re-run tests SAMA dari Task 2.2 — JANGAN tulis test baru
    - Run: `flutter test test/face/liveness_hold_tracker_test.dart --plain-name "Property 2"` di `mypresensi-mobile/`
    - **EXPECTED OUTCOME**:
      - Test 2.2.a (blink event): PASS — blink confirm di tick pertama (`_minPassedFramesBlink=1`, `_minHoldFloorMsBlink=0`) ✓
      - Test 2.2.b (mid-tier gold path E2): PASS — confirm di tick t=240 atau t=320 dengan `passedFrameCount=3` dan `holdMs=240` (atau t=320, `holdMs=320` ≥ 300). Worst-case ≤ 320 ms, lebih cepat dari baseline 400 ms ✓
      - Test 2.2.c (foto statis E3): PASS — semua tick `passed=false` → `_passedSinceMs` tetap null → `stepCompleted=false` ✓
      - Test 2.2.d (single-frame flash E4): PASS — tick t=0 set `_passedFrameCount=1`. Tick t=100/200 fail → `_failStreak=1, 2`. Tick t=300 fail → `_failStreak=3 > 2` → window reset → `_passedFrameCount=0`. Tidak pernah `>= 3` → `stepCompleted=false` ✓
      - Test 2.2.e (property-based random 100 streams): PASS — keputusan identik antara `oldTracker` (sekarang sudah jadi tracker baru karena fix) vs simulated-old logic. Catatan: setelah fix, perlu update test 2.2.e supaya `oldTracker` di-simulasikan via helper terpisah yang meng-emulate logic LAMA — atau, lebih sederhana, ganti assertion ke property invariant: untuk stream non-bug-condition, decision baru harus konsisten dengan ekspektasi observasional (blink confirm, foto statis no-confirm, mid-tier confirm dalam ≤320 ms)
    - **Catatan implementasi 2.2.e setelah fix**: Karena `LivenessHoldTracker` di Task 3.1 menggantikan logic lama (kelas yang sama), property-based test harus diadjust agar pakai 2 helper internal yang meng-emulate keputusan: (a) `simulateOldDecision(stream)` — fungsi private di file test yang meniru continuity wall-clock 500 ms; (b) `simulateNewDecision(stream)` — pakai instance `LivenessHoldTracker` baru. Assert keduanya equal untuk stream non-bug-condition. Helper `simulateOldDecision` adalah ~15 baris dart pure (state `_passedSinceMs`, `_lastPassedAtMs`, threshold 500/400/0)
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 3.7_

  - [x] 3.5 Verifikasi static analysis pasca-fix
    - Jalankan `flutter analyze` di `mypresensi-mobile/` — WAJIB 0 issues
    - Jalankan `flutter build apk --debug` di `mypresensi-mobile/` — WAJIB exit 0 (sesuai rule 06 §A Law 1)
    - _Requirements: validates implementation does not regress static checks_

- [x] 4. Re-run full test suite + checkpoint

  - Jalankan SEMUA test di `mypresensi-mobile/`: `flutter test` (full suite, bukan hanya file liveness)
  - **EXPECTED OUTCOME**:
    - Test 2.1 (Property 1, E1 exploration): PASS ✓
    - Test 2.2.a–e (Property 2, preservation): PASS ✓
    - `widget_test.dart` (existing): PASS ✓ (tidak boleh regress)
  - Jalankan `flutter analyze` final — WAJIB 0 issues
  - Jika ada test fail → STOP, debug root cause sesuai rule 02 §B (4 fase debugging sistematis), **jangan stack fix di atas fix**
  - Catat ringkasan hasil di output / komentar PR: total tests, passed count, time elapsed
  - _Requirements: validates entire fix end-to-end via test suite_

- [ ] 5. Manual verification checklist — RMX5000 device fisik (USER-ACTIONABLE)

  > **CATATAN**: Task ini BUKAN implementation — ini checklist langkah verifikasi runtime yang **WAJIB** dijalankan user di device fisik sebelum klaim fix "verified" (sesuai rule 06 §A Law 4 Screenshot-as-proof). Subagent tidak menjalankan device fisik.

  - [~] 5.1 Preconditions & build
    - Pastikan laptop dev dan RMX5000 di WiFi yang sama
    - Update `_lanIp` di `mypresensi-mobile/lib/core/config/app_config.dart` ke IP laptop terkini (cek via `ipconfig` di PowerShell)
    - Aktifkan USB debugging di RMX5000, sambungkan kabel USB
    - Jalankan backend Next.js: `npm run dev` di `mypresensi-web/` (PowerShell window terpisah)
    - Cek device terdaftar: `adb devices` (PowerShell)

  - [~] 5.2 Run debug build di device fisik
    - Command: `flutter run -d <RMX5000-device-id>` di `mypresensi-mobile/`
    - **CATATAN**: Debug build cukup. Bug condition ini timing-based dari ML Kit, tidak depend ProGuard/R8 release optimizations (algoritma akumulasi adalah Dart-pure, observable di debug)

  - [~] 5.3 Reproduce flow registrasi wajah end-to-end
    - Login mobile dengan akun mahasiswa test (kredensial dari `mypresensi-web/.dev-accounts.md`)
    - Navigate: Profil → Daftarkan Wajah
    - **Step `lookStraight`**: capture 7 embedding TFLite. Verifikasi UI menampilkan progress bar 1/7 → 7/7. **HARUS jalan** (klausul 3.4 preservation)
    - **Step `blinkEyes`**: kedipkan mata sekali. Verifikasi step confirm cepat (≤ 1 frame). **HARUS jalan** (klausul 3.3 preservation)
    - **Step kunci `turnLeft`**: noleh kepala ke kiri (yaw > 12°), tahan ~1 detik. Verifikasi step confirm dan UI pindah ke `turnRight`. **WAJIB confirm di RMX5000 setelah fix**
    - **Step kunci `turnRight`**: noleh kepala ke kanan (yaw < -12°), tahan ~1 detik. Verifikasi step confirm dan UI pindah ke finalize
    - Verifikasi finalize: registrasi berhasil, kembali ke profil dengan status "Wajah Terdaftar"

  - [~] 5.4 Observe logcat pattern
    - Window PowerShell terpisah, jalankan: `adb logcat -s flutter | Select-String "FACE LIVE"`
    - **EXPECTED PATTERN setelah fix**:
      ```
      [FACE LIVE] step=turnLeft yaw=37.4 leftEye=0.92 rightEye=0.93 passed=true holdMs=215 passedCount=2 failStreak=0
      [FACE LIVE] step=turnLeft yaw=42.1 leftEye=0.91 rightEye=0.93 passed=true holdMs=420 passedCount=3 failStreak=0
      [FACE LIVE] ✅ Step turnLeft PASSED (passedCount=3 held 420ms)
      [FACE LIVE] step=turnRight yaw=-31.8 leftEye=0.94 rightEye=0.92 passed=true holdMs=180 passedCount=2 failStreak=0
      [FACE LIVE] ✅ Step turnRight PASSED (passedCount=3 held 530ms)
      ```
    - Verifikasi field `passedCount` dan `failStreak` muncul di log (signal baru klausul 2.4)
    - Verifikasi field lama (`step`, `yaw`, `leftEye`, `rightEye`, `passed`, `holdMs`) masih ada di log (klausul 3.7 regression check)

  - [~] 5.5 Negative path verification
    - **Path 1 — Tahan kepala lurus**: di step `turnLeft`, jangan noleh; tahan kepala lurus 5 detik. Step `turnLeft` SHALL TIDAK confirm. Logcat: `passedCount` tetap 0, `failStreak` mungkin naik tapi window tidak pernah accrue (klausul 3.5 anti-spoof)
    - **Path 2 — Flash 1 frame**: di step `turnLeft`, noleh kiri **sekali sebentar** (~100 ms) lalu langsung balik lurus. Step SHALL TIDAK confirm. Logcat: `passedCount` capped di 1, lalu window di-reset setelah `failStreak > 2` (klausul 3.5 anti-spoof preserved)

  - [~] 5.6 Visual confirmation — kirim screenshot/screencast ke session
    - **WAJIB** (rule 06 §A Law 4): user kirim ke chat:
      - Screenshot logcat saat `turnLeft` PASSED + `turnRight` PASSED (boleh 1 screenshot atau 2)
      - Screenshot atau screencast UI saat sequence `turnLeft` → `turnRight` → completed berhasil
      - (Opsional, recommended) Screenshot logcat saat negative path (tahan lurus, flash) — `passedCount` tidak pernah ≥ 3
    - Tanpa bukti runtime ini, status fix HANYA "static checks pass" — BUKAN "verified". Sesuai rule 06 §B Verification Log Table

  - [x] 5.7 Update CHANGELOG.md
    - Append entry ke `CHANGELOG.md` (di workspace root) dengan format yang dipakai existing:
      ```markdown
      ## YYYY-MM-DD
      | HH:MM | [FIX] | mypresensi-mobile/lib/features/face/services/liveness_hold_tracker.dart | Algoritma hybrid frame-count + wall-time floor untuk pose hold (BUG-013 RMX5000) |
      | HH:MM | [MOD] | mypresensi-mobile/lib/features/face/providers/face_provider.dart | Delegate akumulasi liveness ke LivenessHoldTracker, tambah field passedCount+failStreak di log [FACE LIVE] |
      | HH:MM | [ADD] | mypresensi-mobile/test/face/liveness_hold_tracker_test.dart | PBT exploration E1 + preservation E2/E3/E4/blink + property-based 100 random streams |
      ```
    - (Opsional) Tambah entry di `dev-log.md` dengan retro singkat (rule 06 §D Bug Retro Discipline) — symptom, root cause, why slipped past, prevention

## Notes

### Mengapa task ordering ini

1. **Task 1 sebelum Task 2** — kita butuh API `LivenessHoldTracker` stabil agar test di Task 2 bisa berbicara dalam istilah `tracker.tick(...)` tanpa harus mengakses field privat `FaceRegistrationNotifier`. Refactor pure menjamin behavior identik dengan logic lama → exploration test di Task 2.1 benar-benar mengukur bug, bukan artifact refactor.

2. **Task 2 sebelum Task 3** — sesuai bugfix workflow rule. Exploration test FAIL di kode UNFIXED adalah bukti bug exist. Tanpa baseline ini, fix tidak bisa diklaim "memperbaiki" sesuatu — bisa jadi cuma side-effect refactor.

3. **Task 3.1 (`tracker.tick()`) sebelum 3.2 (logging)** — algoritma yang benar dulu, polish logging field belakangan.

4. **Task 4 (full suite) sebelum Task 5 (manual)** — pre-flight check: kalau test suite merah, jangan buang waktu cabut HP.

### Property test naming convention

- `Property 1: Bug Condition` — di Task 2.1 (sebelum fix), label-nya tetap "Bug Condition" karena meng-encode bug yang sedang di-explore.
- `Property 1: Expected Behavior` — di Task 3.3 (setelah fix), test yang SAMA di-rename label-nya menjadi "Expected Behavior" karena sekarang ia memvalidasi fix bekerja. Implementasi test code TIDAK berubah, hanya label/title-nya supaya hover status PBT mencerminkan fase.
- `Property 2: Preservation` — di Task 2.2 dan 3.4, label tetap sama karena perannya tetap "preserve baseline".

### Optional task tagging

Tidak ada optional task di plan ini. Task 5.7 (update CHANGELOG) adalah administrative tapi WAJIB sesuai rule 05 §C.

### Threshold tuning fallback

Kalau di field test pasca-fix masih ada device yang gagal confirm (mis. chipset Helio yang lebih lambat dari MediaTek RMX5000), tuning konstanta di `liveness_hold_tracker.dart` cukup di satu file:
- Turunkan `_minPassedFramesPose` dari 3 ke 2 (kurang aman terhadap spoof tapi lebih ramah device sangat lambat)
- Turunkan `_minHoldFloorMsPose` dari 300 ke 200

Tidak ada perubahan API, tidak ada migration, tidak ada dependency. Rollback total: revert kedua file modifikasi + delete file tracker baru.

## ✅ Verifikasi Phase 3 (Tasks)

| Check | Result |
|-------|--------|
| Task list mengikuti urutan refactor → exploration+preservation → fix → verify → manual | ✅ 5 task utama |
| Format `**Property N:**` dipakai untuk hover status PBT | ✅ Property 1 di 2.1 & 3.3, Property 2 di 2.2 & 3.4 |
| Exploration test (Property 1) ditulis BEFORE fix dan EXPECTED FAIL di unfixed | ✅ Task 2.1 |
| Preservation tests (Property 2) ditulis BEFORE fix dan EXPECTED PASS di unfixed | ✅ Task 2.2.a–e |
| Tidak tambah dependency baru | ✅ Pakai `flutter_test` + `dart:math` saja |
| File path Windows-friendly (forward slash) | ✅ Semua path |
| Acceptance criteria konkret (file, function, threshold, log pattern) | ✅ Tiap sub-task |
| Bug_Condition + Expected_Behavior + Preservation refs di Task 3.1 | ✅ Annotations lengkap |
| Manual verification checklist sesuai rule 06 §A Law 4 (screenshot proof) | ✅ Task 5.6 |
| Bahasa Indonesia untuk task description | ✅ |

Status legend: ✅ Confirmed / ❌ Failed / ⏳ Pending

**Phase 3 selesai.** User klik "Execute Tasks" di UI untuk mulai eksekusi. Subagent `spec-task-execution` akan handle PBT validation flow per task — exploration test FAIL adalah expected outcome di Task 2.1, dan akan PASS setelah Task 3 selesai.
