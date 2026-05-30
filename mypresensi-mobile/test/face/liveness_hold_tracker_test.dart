// test/face/liveness_hold_tracker_test.dart
// Test bugfix face-liveness-pose-hold (BUG-013 RMX5000).
//
// Property 1 — Bug Condition (Task 2.1):
//   Test ini WAJIB FAIL pada implementasi LAMA `LivenessHoldTracker`
//   (continuity wall-clock 500 ms, `passedFrameCount`/`failStreak` di-stub
//   ke 0). Failure = bukti bug ada. Expected behavior properties di sini
//   meng-encode kontrak algoritma hybrid (frame-count + wall-time floor)
//   yang akan diimplementasi di Task 3.
//
// Property 2 — Preservation (Task 2.2):
//   Test 2.2.a–e mengencode baseline behavior pada non-bug inputs
//   (blink event, mid-tier gold path, foto statis spoof, single-frame
//   flash spoof, property-based random stream). WAJIB PASS pada
//   tracker UNFIXED — itulah baseline yang dijaga setelah fix di Task 3.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypresensi_mobile/features/face/services/face_detection_service.dart'
    show LivenessStep;
import 'package:mypresensi_mobile/features/face/services/liveness_hold_tracker.dart';

/// Tick fixture sederhana — wall-clock millisecond + signal `passed`
/// dari `FaceDetectionService.checkLivenessStep`.
typedef Tick = ({int t, bool passed});

void main() {
  group('LivenessHoldTracker', () {
    // ===========================================================
    // Property 1: Bug Condition — Realme RMX5000 Pose Hold
    // ===========================================================
    //
    // Fixture E1 = stream tick logcat realistic dari Realme RMX5000
    // (chipset MediaTek + ColorOS) saat user benar-benar menahan pose
    // turnLeft. Frame interval 200–400 ms karena GC pause; sesekali
    // miss-detect ML Kit menghasilkan `passed=false` transien.
    //
    // EXPECTED PRE-FIX: assertion `passedFrameCount >= 3` FAIL karena
    // logic LAMA stub field tersebut ke 0 (continuity wall-clock tidak
    // pernah menghitung frame). Selain itu, di tick terakhir (t=1550)
    // logic LAMA bisa accidentally confirm via `holdMs=450 >= 400`,
    // tapi semantic-nya tetap salah: tidak ada bukti multi-frame
    // proof — `passedFrameCount` masih 0.
    //
    // EXPECTED POST-FIX (Task 3.1, hybrid algorithm):
    //   - tick t=480 fail → _failStreak=1
    //   - tick t=720 fail → _failStreak=2 (≤ _maxFailStreakAllowed)
    //   - window TIDAK reset
    //   - tick t=1100 passed → _passedFrameCount=3, holdMs=1100
    //   - stepCompleted=true (passedCount≥3 AND holdMs≥300)

    const e1 = <Tick>[
      (t: 0, passed: true),
      (t: 220, passed: true),
      (t: 480, passed: false),
      (t: 720, passed: false),
      (t: 1100, passed: true),
      (t: 1320, passed: true),
      (t: 1550, passed: true),
    ];

    test(
      'Property 1: Bug Condition - E1 RMX5000 pose hold should confirm',
      () {
        // Validates: Requirements 1.1, 1.2, 1.3, 2.1, 2.2, 2.3
        final tracker = LivenessHoldTracker();
        final results = <HoldTickResult>[];

        for (final tick in e1) {
          final result = tracker.tick(
            passed: tick.passed,
            step: LivenessStep.turnLeft,
            nowMs: tick.t,
          );
          results.add(result);
        }

        // Property 1 assertions (sesuai design.md §Correctness Properties):
        // E1 stream WAJIB confirm step di salah satu tick, dengan bukti
        // multi-frame (passedFrameCount >= 3) dan wall-time floor
        // (holdMs >= 300). Algoritma hybrid yang benar memenuhi ketiga
        // properti ini secara bersamaan; algoritma lama tidak.
        expect(
          results.any((r) => r.stepCompleted),
          isTrue,
          reason: 'E1 stream harus confirm step di salah satu tick',
        );
        expect(
          results.last.passedFrameCount,
          greaterThanOrEqualTo(3),
          reason: 'Bukti multi-frame: minimal 3 frame passed=true akumulatif',
        );
        expect(
          results.last.holdMs,
          greaterThanOrEqualTo(300),
          reason: 'Wall-time floor: minimal 300 ms presence sejak first-pass',
        );
      },
    );

    // ===========================================================
    // Property 2: Preservation — Non-Bug Inputs Behave Identically
    // ===========================================================
    //
    // GOAL: Capture baseline behavior tracker LAMA pada non-bug inputs
    // (blink event, mid-tier gold path, foto statis, single-frame flash,
    // random non-bug streams). Test 2.2.a–e WAJIB PASS pada UNFIXED
    // tracker — itulah baseline yang harus tetap utuh setelah fix
    // (klausul 3.1, 3.2, 3.3, 3.5, 3.7).
    //
    // Setelah fix di Task 3.1, test 2.2.e perlu helper `simulateOldDecision`
    // yang meng-emulate logic LAMA (lihat catatan Task 3.4); di Phase 2
    // ini kita cukup compare 2 instance tracker LAMA — keduanya identik
    // by construction.

    // ---- Test 2.2.a — Blink event (klausul 3.3) ----
    test(
      'Property 2: Preservation - 2.2.a blink event confirms on first tick',
      () {
        // Validates: Requirements 3.3
        // Observasi UNFIXED: tick(passed=true, step=blink, nowMs=0) →
        //   _passedSinceMs=0, holdMs=0, _holdDurationMs(blink)=0,
        //   passed && holdMs >= 0 → stepCompleted=true.
        final tracker = LivenessHoldTracker();
        final result = tracker.tick(
          passed: true,
          step: LivenessStep.blinkEyes,
          nowMs: 0,
        );

        expect(
          result.stepCompleted,
          isTrue,
          reason: 'Blink event-detection: confirm di tick pertama (hold=0 ms)',
        );
      },
    );

    // ---- Test 2.2.b — Mid-tier gold path E2 (klausul 3.1) ----
    test(
      'Property 2: Preservation - 2.2.b mid-tier gold path confirms within 480 ms',
      () {
        // Validates: Requirements 3.1
        // Observasi UNFIXED: interval 80 ms < 500 ms → window stabil.
        // Saat holdMs >= 400 (di tick t=400) → stepCompleted=true.
        const e2 = <Tick>[
          (t: 0, passed: true),
          (t: 80, passed: true),
          (t: 160, passed: true),
          (t: 240, passed: true),
          (t: 320, passed: true),
          (t: 400, passed: true),
          (t: 480, passed: true),
        ];

        final tracker = LivenessHoldTracker();
        final results = <(int t, HoldTickResult result)>[];
        for (final tick in e2) {
          final result = tracker.tick(
            passed: tick.passed,
            step: LivenessStep.turnLeft,
            nowMs: tick.t,
          );
          results.add((tick.t, result));
        }

        final confirmed =
            results.where((entry) => entry.$2.stepCompleted).toList();
        expect(
          confirmed.isNotEmpty,
          isTrue,
          reason: 'Mid-tier stream harus confirm di salah satu tick',
        );
        expect(
          confirmed.first.$1,
          lessThanOrEqualTo(480),
          reason: 'Worst-case confirm ≤ 480 ms (≤ 400 ms continuity baseline)',
        );
      },
    );

    // ---- Test 2.2.c — Foto statis E3 (klausul 3.5 anti-spoof) ----
    test(
      'Property 2: Preservation - 2.2.c static photo never confirms',
      () {
        // Validates: Requirements 3.5
        // Observasi UNFIXED: semua tick passed=false → _passedSinceMs
        // selalu null → holdMs=0 → stepCompleted=false di semua tick.
        final tracker = LivenessHoldTracker();
        final results = <HoldTickResult>[];
        for (var i = 0; i < 20; i++) {
          final result = tracker.tick(
            passed: false,
            step: LivenessStep.turnLeft,
            nowMs: i * 100,
          );
          results.add(result);
        }

        expect(
          results.every((r) => !r.stepCompleted),
          isTrue,
          reason: 'Foto statis (no pose) harus tidak pernah confirm',
        );
      },
    );

    // ---- Test 2.2.d — Single-frame flash E4 (klausul 3.5 anti-spoof) ----
    test(
      'Property 2: Preservation - 2.2.d single-frame flash never confirms',
      () {
        // Validates: Requirements 3.5
        // Observasi UNFIXED: tick t=0 set _passedSinceMs=0,
        // _lastPassedAtMs=0. Tick selanjutnya passed=false (no update).
        // Saat holdMs >= 400 (di tick t=400) tapi passed=false di tick
        // tersebut → passed && holdMs >= 400 → false.
        const e4 = <Tick>[
          (t: 0, passed: true),
          (t: 100, passed: false),
          (t: 200, passed: false),
          (t: 300, passed: false),
          (t: 400, passed: false),
          (t: 500, passed: false),
        ];

        final tracker = LivenessHoldTracker();
        final results = <HoldTickResult>[];
        for (final tick in e4) {
          final result = tracker.tick(
            passed: tick.passed,
            step: LivenessStep.turnLeft,
            nowMs: tick.t,
          );
          results.add(result);
        }

        expect(
          results.every((r) => !r.stepCompleted),
          isTrue,
          reason: 'Single-frame flash harus tidak confirm (anti-spoof)',
        );
      },
    );

    // ---- Test 2.2.e — Property-based random non-bug streams ----
    test(
      'Property 2: Preservation - 2.2.e 100 random non-bug streams behave identically',
      () {
        // Validates: Requirements 3.1, 3.2, 3.3, 3.5, 3.7
        // Property invariant: stream non-bug-condition harus menghasilkan
        // keputusan stepCompleted identik antar dua tracker LAMA. Di
        // Phase 2 ini trivially identik (old vs old). Setelah fix di
        // Task 3.4, test ini akan di-adjust pakai `simulateOldDecision`
        // helper.
        final rng = Random(42);

        for (var i = 0; i < 100; i++) {
          final stream = _genNonBugStream(rng);
          final oldTracker = LivenessHoldTracker();
          final simulatedNewTracker = LivenessHoldTracker();
          final oldDecisions = <bool>[];
          final simulatedNewDecisions = <bool>[];

          for (final tick in stream) {
            oldDecisions.add(
              oldTracker
                  .tick(
                    passed: tick.passed,
                    step: tick.step,
                    nowMs: tick.t,
                  )
                  .stepCompleted,
            );
            simulatedNewDecisions.add(
              simulatedNewTracker
                  .tick(
                    passed: tick.passed,
                    step: tick.step,
                    nowMs: tick.t,
                  )
                  .stepCompleted,
            );
          }

          expect(
            oldDecisions,
            equals(simulatedNewDecisions),
            reason:
                'Stream #$i (panjang ${stream.length}) harus berperilaku '
                'identik antar dua tracker — non-bug-condition input',
          );
        }
      },
    );
  });
}

/// Tick lengkap dengan step liveness, dipakai property-based test 2.2.e.
typedef StreamTick = ({int t, bool passed, LivenessStep step});

/// Generator stream non-bug-condition: random pilih salah satu kategori
/// (A: mayoritas fail, B: window pendek, C: mid-tier reguler, D: blink).
/// Semuanya non-bug-condition by construction — tidak punya gap >500 ms
/// antar passed=true ticks DAN tidak melebihi 600 ms window dengan
/// majority pass.
List<StreamTick> _genNonBugStream(Random rng) {
  final category = rng.nextInt(4);
  switch (category) {
    case 0:
      return _genCategoryA(rng);
    case 1:
      return _genCategoryB(rng);
    case 2:
      return _genCategoryC(rng);
    default:
      return _genCategoryD();
  }
}

/// Kategori A — 80% tick passed=false, interval 50–150 ms, step turnLeft,
/// panjang 5–15 tick. Tidak memenuhi isBugCondition (passedRatio < 60%).
List<StreamTick> _genCategoryA(Random rng) {
  final length = 5 + rng.nextInt(11); // 5..15
  final ticks = <StreamTick>[];
  var t = 0;
  for (var i = 0; i < length; i++) {
    final passed = rng.nextDouble() < 0.2; // 20% passed → 80% fail
    ticks.add((t: t, passed: passed, step: LivenessStep.turnLeft));
    t += 50 + rng.nextInt(101); // 50..150 ms
  }
  return ticks;
}

/// Kategori B — semua passed=true, interval 50–150 ms, total window < 600 ms,
/// step turnLeft. Tidak memenuhi isBugCondition (windowMs < 600).
List<StreamTick> _genCategoryB(Random rng) {
  final ticks = <StreamTick>[
    (t: 0, passed: true, step: LivenessStep.turnLeft),
  ];
  var t = 0;
  // Tambah tick selama total window masih < 600 ms.
  while (true) {
    final delta = 50 + rng.nextInt(101);
    final next = t + delta;
    if (next >= 600) break;
    t = next;
    ticks.add((t: t, passed: true, step: LivenessStep.turnLeft));
  }
  return ticks;
}

/// Kategori C — 100% passed=true, interval 50–150 ms, panjang 5–15 tick,
/// step turnLeft atau turnRight. Tidak memenuhi isBugCondition (no gap spike).
List<StreamTick> _genCategoryC(Random rng) {
  final length = 5 + rng.nextInt(11); // 5..15
  final step =
      rng.nextBool() ? LivenessStep.turnLeft : LivenessStep.turnRight;
  final ticks = <StreamTick>[];
  var t = 0;
  for (var i = 0; i < length; i++) {
    ticks.add((t: t, passed: true, step: step));
    t += 50 + rng.nextInt(101); // 50..150 ms
  }
  return ticks;
}

/// Kategori D — 1 tick passed=true, step blinkEyes (event-detection).
List<StreamTick> _genCategoryD() {
  return <StreamTick>[
    (t: 0, passed: true, step: LivenessStep.blinkEyes),
  ];
}
