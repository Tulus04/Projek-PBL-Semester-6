// test/attendance/parse_qr_code_property_test.dart
// Test bugfix BUG-019 — Preservation Property 2 Layer A.
//
// Property 2 — Preservation: QR Parse Contract & Submit Pipeline Identity
//   `attendanceSubmitProvider.notifier.parseQrCode(String) -> QrCodeData?`
//   adalah pure function dari raw QR string ke model. Test ini lock down
//   kontrak tersebut SEBELUM refactor `ScanQrScreen` sehingga regressi
//   kontrak parse di-detect post-fix. `attendance_provider.dart` TIDAK
//   boleh berubah (Files NOT Touched, design.md §preservation).
//
// Properties (sesuai task 2 spec):
//   1. Purity valid:
//        ∀ s ∈ validQrGen.
//          parseQrCode(s) != null
//          AND parseQrCode(s).sessionId   == extracted_uuid
//          AND parseQrCode(s).sessionCode == extracted_code
//   2. Purity invalid:
//        ∀ s ∈ invalidQrGen. parseQrCode(s) == null
//   3. Idempotence / no state leakage:
//        ∀ s. parseQrCode(s) ≡ parseQrCode(s)  (call dua kali return identik)
//
// Trial count: 100 valid + 100 invalid (sesuai task 2 spec).
//
// Pre-fix expectation: PASS (kontrak `attendance_provider.dart` belum
//   tersentuh — baseline preservation dari unfixed code).
// Post-fix expectation: PASS (`attendance_provider.dart` masih NOT
//   touched — verifikasi via git diff di Task 3.6).
//
// Generator strategy (rule 03: no new dep, hanya `flutter_test` +
// `dart:math`):
//   - validQrGen   — random UUID v4 + random 6-digit code → JSON encode
//                    pakai canonical key `{"session_id": ..., "code": ...}`
//                    (format aktif yang dosen QR display generate).
//   - invalidQrGen — campuran 5 kategori non-valid (random ASCII /
//                    JSON malformed / JSON missing field / non-map JSON /
//                    empty / unicode) untuk cover input domain luas.
//
// Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9,
//            3.10, 3.11, 3.12, 3.13, 3.14

import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypresensi_mobile/features/attendance/data/attendance_models.dart';
import 'package:mypresensi_mobile/features/attendance/providers/attendance_provider.dart';

/// Seed deterministic supaya counterexample reproducible kalau test gagal.
const int _kSeed = 0xBE12A019;
const int _kValidTrials = 100;
const int _kInvalidTrials = 100;

void main() {
  group('parseQrCode — preservation property tests (BUG-019 Layer A)', () {
    late ProviderContainer container;
    late AttendanceSubmitNotifier notifier;

    setUp(() {
      // ProviderContainer minimal — `parseQrCode` tidak invoke
      // dependency repository / location service, jadi tidak butuh
      // mock. Akses notifier lewat container biar Riverpod 3 wire
      // ref-nya dengan benar.
      container = ProviderContainer();
      notifier = container.read(attendanceSubmitProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    // ---------------------------------------------------------------
    // Property 1 — Purity valid
    // ---------------------------------------------------------------
    test(
      'Property 1 (purity valid): valid QR JSON returns QrCodeData with '
      'matching sessionId and sessionCode (100 trials)',
      () {
        final rng = Random(_kSeed);

        for (var i = 0; i < _kValidTrials; i++) {
          final sample = _genValidQr(rng);

          final result = notifier.parseQrCode(sample.raw);

          expect(
            result,
            isA<QrCodeData>(),
            reason: 'Trial #$i: parseQrCode(${_truncate(sample.raw)}) '
                'returned null — expected non-null QrCodeData. '
                'Counterexample raw: ${sample.raw}',
          );
          expect(
            result!.sessionId,
            equals(sample.uuid),
            reason: 'Trial #$i: sessionId mismatch. '
                'Expected ${sample.uuid}, got ${result.sessionId}. '
                'Counterexample raw: ${sample.raw}',
          );
          expect(
            result.sessionCode,
            equals(sample.code),
            reason: 'Trial #$i: sessionCode mismatch. '
                'Expected ${sample.code}, got ${result.sessionCode}. '
                'Counterexample raw: ${sample.raw}',
          );
        }
      },
    );

    // ---------------------------------------------------------------
    // Property 2 — Purity invalid
    // ---------------------------------------------------------------
    test(
      'Property 2 (purity invalid): non-conforming QR strings return null '
      '(100 trials)',
      () {
        final rng = Random(_kSeed ^ 0x55AA);

        for (var i = 0; i < _kInvalidTrials; i++) {
          final raw = _genInvalidQr(rng);

          final result = notifier.parseQrCode(raw);

          expect(
            result,
            isNull,
            reason: 'Trial #$i: parseQrCode returned non-null for input '
                'expected to be invalid. '
                'Counterexample raw: ${_truncate(raw)} '
                '(category-derived non-conforming sample). '
                'Returned: ${result?.sessionId} / ${result?.sessionCode}',
          );
        }
      },
    );

    // ---------------------------------------------------------------
    // Property 3 — Idempotence / no state leakage
    // ---------------------------------------------------------------
    test(
      'Property 3 (idempotence): two consecutive parseQrCode calls return '
      'structurally equal results (100 valid + 100 invalid trials)',
      () {
        final rng = Random(_kSeed ^ 0x1DEA);

        // Mix 100 valid + 100 invalid samples — total 200 trials.
        for (var i = 0; i < _kValidTrials; i++) {
          final sample = _genValidQr(rng);
          _assertIdempotent(notifier, sample.raw, trial: 'valid#$i');
        }
        for (var i = 0; i < _kInvalidTrials; i++) {
          final raw = _genInvalidQr(rng);
          _assertIdempotent(notifier, raw, trial: 'invalid#$i');
        }
      },
    );

    // ---------------------------------------------------------------
    // Hand-picked edge cases (sesuai task 2 observation list)
    //   → keep alongside generator tests untuk regression sentinel
    //     pada input spesifik yang task spec mention eksplisit.
    // ---------------------------------------------------------------
    group('hand-picked edge cases (task 2 observation list)', () {
      test('valid: canonical UUID + 6-digit code returns QrCodeData', () {
        const raw = '{"session_id":"550e8400-e29b-41d4-a716-446655440000",'
            '"code":"123456"}';
        final result = notifier.parseQrCode(raw);
        expect(result, isNotNull);
        expect(result!.sessionId, equals('550e8400-e29b-41d4-a716-446655440000'));
        expect(result.sessionCode, equals('123456'));
      });

      test('invalid (non-JSON plaintext) returns null', () {
        expect(notifier.parseQrCode('hello world'), isNull);
        expect(notifier.parseQrCode('123456'), isNull);
      });

      test('invalid (malformed JSON) returns null', () {
        expect(notifier.parseQrCode('{session_id: x}'), isNull);
        expect(notifier.parseQrCode('{}'), isNull);
      });

      test('invalid (missing required fields) returns null', () {
        expect(notifier.parseQrCode('{"session_id":"x"}'), isNull);
        expect(notifier.parseQrCode('{"code":"123456"}'), isNull);
      });

      test('edge (empty / unicode) returns null', () {
        expect(notifier.parseQrCode(''), isNull);
        expect(notifier.parseQrCode('\u{1F600}'), isNull);
      });
    });
  });
}

// =================================================================
// Generators (no external dep — `dart:math` only, sesuai rule 03)
// =================================================================

/// Sample valid QR — store extracted_uuid + extracted_code untuk
/// di-assert ulang setelah parse (Property 1).
class _ValidQrSample {
  final String raw;
  final String uuid;
  final String code;

  const _ValidQrSample({
    required this.raw,
    required this.uuid,
    required this.code,
  });
}

/// Generate random UUID v4 + 6-digit code, encode jadi JSON canonical
/// `{"session_id":"<uuid>","code":"<code>"}`. Pakai `jsonEncode` supaya
/// escape character ditangani benar (defensive untuk future edge case).
_ValidQrSample _genValidQr(Random rng) {
  final uuid = _randomUuidV4(rng);
  final code = _randomSixDigitCode(rng);
  final raw = jsonEncode({
    'session_id': uuid,
    'code': code,
  });
  return _ValidQrSample(raw: raw, uuid: uuid, code: code);
}

/// Generate input string yang TIDAK lolos kontrak `parseQrCode`. Pilih
/// random salah satu dari 5 kategori untuk cover input domain luas:
///   0. Empty string ("")
///   1. Random ASCII non-JSON (panjang 0-200, mostly never parse)
///   2. JSON malformed (kunci tanpa quotes, trailing comma, dll.)
///   3. JSON valid tapi missing satu/dua field wajib
///   4. JSON non-map (array / number / string / boolean / null)
///   5. JSON map dengan empty string di salah satu field wajib
///
/// Defensive guard: kalau random ASCII tidak sengaja membentuk JSON
/// yang lolos parse (probabilitas mendekati nol untuk panjang 0-200),
/// regenerate sampai `parseQrCode` benar-benar return null untuk
/// menghindari false-positive flake.
String _genInvalidQr(Random rng) {
  // Up to 8 attempts untuk regenerate kalau kebetulan random ASCII
  // membentuk JSON valid (extremely unlikely tapi safe).
  for (var attempt = 0; attempt < 8; attempt++) {
    final category = rng.nextInt(6);
    final candidate = switch (category) {
      0 => '',
      1 => _genRandomAscii(rng, maxLen: 200),
      2 => _genMalformedJson(rng),
      3 => _genJsonMissingField(rng),
      4 => _genJsonNonMap(rng),
      5 => _genJsonEmptyField(rng),
      _ => '',
    };

    if (_definitelyInvalid(candidate)) return candidate;
  }
  // Hard fallback — empty string is always invalid by contract.
  return '';
}

/// Quick sanity check: verifikasi candidate benar-benar tidak lolos
/// parse — guard dari kasus random ASCII kebetulan jadi JSON valid.
bool _definitelyInvalid(String candidate) {
  try {
    final decoded = jsonDecode(candidate);
    if (decoded is! Map<String, dynamic>) return true;
    final hasSession = (decoded['sid'] ?? decoded['session_id']) is String &&
        ((decoded['sid'] ?? decoded['session_id']) as String).isNotEmpty;
    final hasCode = (decoded['code'] ?? decoded['session_code']) is String &&
        ((decoded['code'] ?? decoded['session_code']) as String).isNotEmpty;
    // Valid jika kedua field ada & non-empty → BUKAN invalid → false.
    return !(hasSession && hasCode);
  } catch (_) {
    return true; // Tidak bisa decode = pasti invalid.
  }
}

/// UUID v4: 8-4-4-4-12 hex digits, dengan version bit '4' di char 14
/// dan variant bit '8/9/a/b' di char 19. Generate via Random byte-level.
String _randomUuidV4(Random rng) {
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  // Set version 4 (bits 12-15 of clock_seq_hi_and_reserved).
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  // Set variant RFC 4122 (bits 6-7 of clock_seq_hi).
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final hexParts = bytes.map(hex).toList();
  return '${hexParts.sublist(0, 4).join()}-'
      '${hexParts.sublist(4, 6).join()}-'
      '${hexParts.sublist(6, 8).join()}-'
      '${hexParts.sublist(8, 10).join()}-'
      '${hexParts.sublist(10, 16).join()}';
}

/// Generate 6-digit numeric code (zero-padded) — match dosen OTP format.
String _randomSixDigitCode(Random rng) {
  final n = rng.nextInt(1000000); // 0..999999
  return n.toString().padLeft(6, '0');
}

/// Random ASCII string panjang 0..maxLen, char range printable
/// + sebagian special supaya kemungkinan jadi JSON valid hampir nol.
String _genRandomAscii(Random rng, {required int maxLen}) {
  final len = rng.nextInt(maxLen + 1);
  final buf = StringBuffer();
  for (var i = 0; i < len; i++) {
    // Range 32..126 = printable ASCII (space, letter, digit, symbol).
    buf.writeCharCode(32 + rng.nextInt(95));
  }
  return buf.toString();
}

/// JSON-looking tapi malformed — kombinasi acak dari pattern:
///   - kunci tanpa quotes: {session_id: x}
///   - trailing comma: {"session_id":"x",}
///   - kurung tidak match: {"session_id":"x"
///   - colon hilang: {"session_id" "x"}
String _genMalformedJson(Random rng) {
  final patterns = <String>[
    '{session_id: x, code: 123456}',
    '{"session_id":"x",}',
    '{"session_id":"x"',
    '{"session_id" "x", "code":"123456"}',
    '{"session_id":"x", "code":}',
    '{"session_id":"x" "code":"123456"}',
    '{"session_id":}',
    '{:"x"}',
  ];
  return patterns[rng.nextInt(patterns.length)];
}

/// JSON valid tapi missing satu/dua field wajib (atau wrong key).
String _genJsonMissingField(Random rng) {
  final patterns = <Map<String, dynamic>>[
    {}, // both missing
    {'session_id': 'abc-123'}, // code missing
    {'code': '123456'}, // session_id missing
    {'foo': 'bar'}, // unrelated keys
    {'session_id': 'abc-123', 'wrong_code': '123456'}, // wrong code key
    {'wrong_id': 'abc-123', 'code': '123456'}, // wrong session key
  ];
  return jsonEncode(patterns[rng.nextInt(patterns.length)]);
}

/// JSON valid yang BUKAN map (`as Map<String, dynamic>` cast akan throw).
String _genJsonNonMap(Random rng) {
  final patterns = <String>[
    '[]',
    '["session_id","code"]',
    '"plain string"',
    '12345',
    'true',
    'null',
  ];
  return patterns[rng.nextInt(patterns.length)];
}

/// JSON map dengan empty string di salah satu/keduanya field wajib —
/// `QrCodeData.fromMap` throw FormatException untuk empty value.
String _genJsonEmptyField(Random rng) {
  final patterns = <Map<String, dynamic>>[
    {'session_id': '', 'code': '123456'},
    {'session_id': 'abc', 'code': ''},
    {'session_id': '', 'code': ''},
  ];
  return jsonEncode(patterns[rng.nextInt(patterns.length)]);
}

// =================================================================
// Helpers
// =================================================================

/// Assert dua call beruntun ke `parseQrCode` return hasil structurally
/// identik. Cover Property 3 (idempotence) — pastikan tidak ada state
/// internal yang bocor antar call.
void _assertIdempotent(
  AttendanceSubmitNotifier notifier,
  String raw, {
  required String trial,
}) {
  final first = notifier.parseQrCode(raw);
  final second = notifier.parseQrCode(raw);

  // Both null OR both non-null with equal fields.
  if (first == null) {
    expect(
      second,
      isNull,
      reason: 'Trial $trial: first call returned null but second '
          'returned non-null — state leakage. Raw: ${_truncate(raw)}',
    );
    return;
  }
  expect(
    second,
    isNotNull,
    reason: 'Trial $trial: first call returned non-null but second '
        'returned null — state leakage. Raw: ${_truncate(raw)}',
  );
  expect(
    second!.sessionId,
    equals(first.sessionId),
    reason: 'Trial $trial: sessionId differs between two calls '
        '(${first.sessionId} vs ${second.sessionId}). '
        'Raw: ${_truncate(raw)}',
  );
  expect(
    second.sessionCode,
    equals(first.sessionCode),
    reason: 'Trial $trial: sessionCode differs between two calls '
        '(${first.sessionCode} vs ${second.sessionCode}). '
        'Raw: ${_truncate(raw)}',
  );
}

/// Truncate long counterexample strings untuk reporting yang readable.
String _truncate(String s, {int max = 80}) {
  if (s.length <= max) return s;
  return '${s.substring(0, max)}... (len=${s.length})';
}
