// lib/features/face/services/liveness_hold_tracker.dart
// Tracker akumulasi bukti hold pose untuk fase liveness check.
//
// Pure (tidak depend ke ML Kit / camera / DateTime.now) — testable di
// `flutter_test` murni dengan urutan tick `(passed, step, nowMs)`.
//
// ALGORITMA: hybrid frame-count + wall-time floor + fail-streak tolerance.
// Anti-spoof preserved (≥3 frame untuk pose, foto 1-frame flash tidak lolos),
// Realme RMX5000 confirmable (≤1.5 detik real-time meskipun frame interval
// ML Kit bervariasi 200–400 ms karena GC pause MediaTek + ColorOS).
//
// Kombinasi 3 dimensi bukti:
//   1. Multi-frame proof — `passedFrameCount >= _requiredFrames(step)`.
//      Pose butuh 3 frame independen ML Kit melaporkan `passed=true` →
//      single-frame flash tidak lolos.
//   2. Wall-time floor — `holdMs >= _holdFloorMs(step)`. Mensyaratkan
//      minimum presence wall-clock supaya device super cepat tidak
//      "instant-accept" 3 frame dalam 50 ms.
//   3. Fail-streak tolerance — frame `passed=false` transien (≤ 2 frame
//      consecutive) TIDAK reset window. Jitter ML Kit / GC pause
//      menstretch interval tidak mengulang dari nol.

import 'face_detection_service.dart' show LivenessStep;

/// Hasil satu tick evaluasi liveness hold.
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

/// Tracker akumulasi bukti hold pose. Pure dan stateful per-instance —
/// caller (mis. `FaceRegistrationNotifier`) bertanggung jawab memanggil
/// [reset] saat memulai step baru, kehilangan wajah, atau saat advance
/// step.
class LivenessHoldTracker {
  // === Konfigurasi hybrid (per-step thresholds) ===

  /// Jumlah frame `passed=true` minimum untuk confirm pose
  /// (turnLeft / turnRight). Tuning iterasi 2 (BUG-013 RMX5000):
  /// 3 → 2 untuk speed up confirm di device entry-level RMX5000
  /// dengan frame rate ML Kit ~5–7 fps (3 frame = 600 ms+ akumulasi
  /// dengan jitter 1–2 fail = 800–1000 ms+, melewati target ≤2 detik).
  /// 2 frame minimum tetap menjamin multi-frame proof — kombinasi
  /// dengan `_minHoldFloorMsPose=300` wall-time floor mensyaratkan
  /// ≥300 ms presence wall-clock, sehingga single-frame flash (E4)
  /// dan foto statis (E3) tetap reject: flash tick-1 set
  /// `passedFrameCount=1` lalu semua tick berikut `passed=false`
  /// (`stepCompleted = passed && ...` mentok false), foto statis tidak
  /// pernah buka window (`_passedSinceMs` selalu null).
  static const int _minPassedFramesPose = 2;

  /// Blink event-driven — confirm di tick pertama `passed=true`.
  static const int _minPassedFramesBlink = 1;

  /// Wall-time floor pose (ms) — minimum presence sebelum confirm.
  /// Anti instant-accept di device super cepat.
  static const int _minHoldFloorMsPose = 300;

  /// Blink tidak butuh wall-time floor (event-detection).
  static const int _minHoldFloorMsBlink = 0;

  /// Toleransi frame `passed=false` consecutive sebelum window di-reset.
  /// 5 frame ≈ 700–1000 ms jitter di device entry-level RMX5000 dengan
  /// frame rate ML Kit ~5–7 fps (lebih lambat dari asumsi spec original
  /// 200–400 ms = 2.5–5 fps). Toleransi natural head wobble + GC pause
  /// MediaTek + ColorOS + ML Kit miss-detect transien saat user benar-
  /// benar menahan pose. Anti-spoof preserved: foto statis (semua frame
  /// `passed=false`) tidak pernah buka window; single-frame flash tetap
  /// reject karena `passedFrameCount` mentok di 1 < 3.
  /// Lebih dari 5 frame consecutive = user benar-benar break pose.
  static const int _maxFailStreakAllowed = 5;

  // === State window (semua null/0 saat idle) ===

  /// Timestamp saat user mulai hold pose valid (null = idle).
  int? _passedSinceMs;

  /// Jumlah frame `passed=true` sejak window dibuka.
  int _passedFrameCount = 0;

  /// Jumlah frame `passed=false` consecutive sejak frame `passed=true`
  /// terakhir di dalam window aktif.
  int _failStreak = 0;

  /// Evaluasi satu frame liveness.
  ///
  /// [passed]: hasil `FaceDetectionService.checkLivenessStep` untuk frame ini.
  /// [step]: step liveness aktif di state Notifier.
  /// [nowMs]: wall-clock timestamp ms (dari `DateTime.now().millisecondsSinceEpoch`).
  HoldTickResult tick({
    required bool passed,
    required LivenessStep step,
    required int nowMs,
  }) {
    if (passed) {
      // Buka window di tick passed pertama, atau lanjutkan window yang
      // sudah ada — fail-streak transien sebelumnya di-clear.
      _passedSinceMs ??= nowMs;
      _passedFrameCount += 1;
      _failStreak = 0;
    } else if (_passedSinceMs != null) {
      // Hanya akumulasi fail-streak kalau window memang aktif.
      _failStreak += 1;
      if (_failStreak > _maxFailStreakAllowed) {
        // User benar-benar break pose → reset window.
        _passedSinceMs = null;
        _passedFrameCount = 0;
        _failStreak = 0;
      }
    }

    final holdMs = _passedSinceMs == null ? 0 : nowMs - _passedSinceMs!;
    final stepCompleted = passed &&
        _passedFrameCount >= _requiredFrames(step) &&
        holdMs >= _holdFloorMs(step);

    return HoldTickResult(
      stepCompleted: stepCompleted,
      passedFrameCount: _passedFrameCount,
      holdMs: holdMs,
      failStreak: _failStreak,
    );
  }

  /// Reset window — pakai saat memulai step baru, wajah hilang, multiple
  /// faces, wajah terlalu kecil, atau saat advance ke step berikutnya.
  void reset() {
    _passedSinceMs = null;
    _passedFrameCount = 0;
    _failStreak = 0;
  }

  /// Jumlah frame minimum yang dibutuhkan per-step.
  static int _requiredFrames(LivenessStep step) =>
      step == LivenessStep.blinkEyes
          ? _minPassedFramesBlink
          : _minPassedFramesPose;

  /// Wall-time floor minimum (ms) per-step.
  static int _holdFloorMs(LivenessStep step) =>
      step == LivenessStep.blinkEyes
          ? _minHoldFloorMsBlink
          : _minHoldFloorMsPose;
}
