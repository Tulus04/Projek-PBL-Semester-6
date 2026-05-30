// test/bugfix/bug_019_dual_plugin_assertion_test.dart
// Test bugfix BUG-019 — QR Scan Unify Camera Plugin (RMX5000 ColorOS).
//
// Property 1 — Bug Condition (Task 1, exploration / Layer A):
//   Test ini WAJIB FAIL pada UNFIXED `pubspec.yaml` yang punya DUA
//   plugin camera aktif (`mobile_scanner` + `camera`). Failure adalah
//   bukti structural bahwa runtime aplikasi menjalankan dua plugin
//   Flutter yang sama-sama claim Camera2 HAL — kondisi yang men-trigger
//   bug freeze kamera setelah lifecycle handoff di OEM ColorOS.
//
// Property 1 — Expected Behavior (akan re-validate di Task 3.5):
//   Setelah `mobile_scanner` di-drop dan diganti `package:camera` +
//   `google_mlkit_barcode_scanning`, intersection set kamera-plugin
//   menyusut ke ≤ 1 dan test ini PASSES — meng-encode invariant
//   "hanya satu plugin Flutter yang boleh claim camera HAL".
//
// Bug Condition (formal, dari design `isBugCondition`):
//   |input.activePlugins ∩ {mobile_scanner, camera}| == 2
//   AND input.deviceClass ∈ {OEM_COLOROS, OEM_MIUI, OEM_FUNTOUCH, OEM_ONEUI}
//   AND input.cameraHandoff == true
//
// Test scope (Layer A — static structural assertion):
//   Property: pubspec.yaml SHALL NOT contain both `mobile_scanner` AND
//   `camera` as active dependencies — only one camera plugin allowed
//   at runtime. Layer A meng-cover komponen `|activePlugins ∩ ...|` —
//   2 komponen lain (`deviceClass`, `cameraHandoff`) di-cover Layer B
//   (manual reproduction RMX5000, dokumentasi
//   `docs/bugfix/bug-019-exploration-evidence.md`).
//
// Validates: Requirements 1.1, 1.2, 1.3, 1.4 (bug condition surface)
//            Requirements 2.4 (post-fix: SATU plugin camera saja)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Set plugin Flutter yang claim Camera2 HAL — diturunkan dari rule 03
/// `03-design-and-libraries.md` §B (library lock mobile) + design BUG-019
/// §Bug Condition. Intersection antara dependencies pubspec.yaml dengan
/// set ini = "active camera plugins di runtime".
const Set<String> _cameraPluginNames = {
  'mobile_scanner',
  'camera',
};

void main() {
  group('BUG-019 — Dual Camera Plugin Assertion (Layer A)', () {
    test(
      'pubspec.yaml SHALL NOT contain more than one camera plugin '
      '(mobile_scanner + camera = bug condition)',
      () {
        // Cari pubspec.yaml relatif ke working directory test runner.
        // `flutter test` jalan dari root project mobile (mypresensi-mobile/).
        final pubspec = _findPubspecYaml();
        expect(
          pubspec.existsSync(),
          isTrue,
          reason: 'pubspec.yaml tidak ditemukan di ${pubspec.path}. '
              'Jalankan `flutter test` dari root mypresensi-mobile/.',
        );

        final activePlugins = _extractDependencyPackageNames(pubspec);

        // Property: |activePlugins ∩ {mobile_scanner, camera}| <= 1
        final cameraPluginsActive =
            activePlugins.intersection(_cameraPluginNames);

        // Susun counterexample message yang informatif kalau test FAIL —
        // tampilkan literal isi pubspec.yaml yang punya dua baris camera
        // plugin sebagai bukti konkret bug condition tercapai.
        final counterexample = _buildCounterexampleMessage(
          pubspec,
          cameraPluginsActive,
        );

        expect(
          cameraPluginsActive.length,
          lessThanOrEqualTo(1),
          reason: counterexample,
        );
      },
    );

    test(
      'pubspec.yaml MUST declare at least one camera plugin '
      '(scan QR membutuhkan kamera)',
      () {
        // Sanity check: post-fix harus tetap ada SATU plugin camera
        // (`camera`) — kalau intersection size = 0, fitur scan QR
        // tidak punya backend kamera sama sekali.
        final pubspec = _findPubspecYaml();
        final activePlugins = _extractDependencyPackageNames(pubspec);
        final cameraPluginsActive =
            activePlugins.intersection(_cameraPluginNames);

        expect(
          cameraPluginsActive,
          isNotEmpty,
          reason: 'Tidak ada plugin camera aktif di pubspec.yaml. '
              'Scan QR membutuhkan minimal `camera: ^0.12.0+1` '
              '(rule 03 library lock).',
        );
      },
    );
  });
}

/// Locate `pubspec.yaml` relative to the current working directory used
/// by `flutter test`. Default cwd saat `flutter test` adalah root project
/// Flutter (`mypresensi-mobile/`). Kalau script dipanggil dari direktori
/// lain, fall back ke cari ke atas dari `Directory.current`.
File _findPubspecYaml() {
  final cwd = Directory.current;
  // Cari max 4 level ke atas — cukup untuk skenario sub-directory test.
  Directory? probe = cwd;
  for (var i = 0; i < 4; i++) {
    if (probe == null) break;
    final candidate = File('${probe.path}${Platform.pathSeparator}pubspec.yaml');
    if (candidate.existsSync()) return candidate;
    probe = probe.parent;
  }
  return File('${cwd.path}${Platform.pathSeparator}pubspec.yaml');
}

/// Parse `pubspec.yaml` line-by-line untuk ekstrak nama package di section
/// `dependencies:` dan `dev_dependencies:`. Implementasi minimal tanpa
/// dependency `package:yaml` — robust untuk format pubspec standar:
///   - Top-level keys (kolom 0, no leading whitespace) menandai section.
///   - Dependency entries pada section dependencies/dev_dependencies
///     berformat `  package_name: <version>` (leading 2 spasi).
///   - Komentar (line yang trim-start dengan `#`) di-skip.
///   - Section `flutter:` / `flutter_native_splash:` / dll. di-skip.
Set<String> _extractDependencyPackageNames(File pubspec) {
  final lines = pubspec.readAsLinesSync();
  final result = <String>{};
  String? currentSection; // 'dependencies' | 'dev_dependencies' | other
  // Regex: leading exactly 2 spaces, lalu identifier package name (lowercase
  // + underscore + digit), lalu colon. Versi value boleh apa saja setelahnya.
  final entryPattern = RegExp(r'^ {2}([a-z_][a-z0-9_]*)\s*:');

  for (final raw in lines) {
    final line = raw.trimRight();

    // Skip blank + comment-only lines.
    if (line.trim().isEmpty) continue;
    if (line.trimLeft().startsWith('#')) continue;

    // Top-level key transition (no leading whitespace, ends with `:`).
    if (!line.startsWith(' ') && line.endsWith(':')) {
      final key = line.substring(0, line.length - 1).trim();
      if (key == 'dependencies' || key == 'dev_dependencies') {
        currentSection = key;
      } else {
        currentSection = null; // section lain (flutter:, dll.) — skip.
      }
      continue;
    }

    // Hanya proses entry kalau lagi di section dependencies/dev_dependencies.
    if (currentSection == null) continue;

    final match = entryPattern.firstMatch(line);
    if (match == null) continue;

    final pkgName = match.group(1)!;
    // Skip pseudo-key `flutter:` (Flutter SDK self-reference) — itu bukan
    // package eksternal, tidak punya version constraint.
    if (pkgName == 'flutter') continue;
    result.add(pkgName);
  }

  return result;
}

/// Bangun pesan counterexample yang menunjukkan literal baris `pubspec.yaml`
/// yang men-declare camera plugin yang konflik. Output ini surface bug
/// condition secara konkret (mirror format counterexample fast-check /
/// Hypothesis: literal input yang men-trigger property failure).
String _buildCounterexampleMessage(File pubspec, Set<String> conflictingPlugins) {
  final buffer = StringBuffer()
    ..writeln(
      'BUG-019 Bug Condition tercapai: ${conflictingPlugins.length} plugin '
      'camera aktif di pubspec.yaml (>1 = race di Camera2 HAL OEM ColorOS).',
    )
    ..writeln('Plugin yang konflik: ${conflictingPlugins.toList()..sort()}')
    ..writeln('---')
    ..writeln('Counterexample (literal baris pubspec.yaml):');

  final lines = pubspec.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final plugin in conflictingPlugins) {
      // Match leading "  pluginname:" — entry valid di dependencies block.
      if (line.startsWith('  $plugin:')) {
        buffer.writeln('  L${i + 1}: $line');
        break;
      }
    }
  }
  buffer
    ..writeln('---')
    ..writeln(
      'Expected post-fix: hanya `camera` yang tersisa (drop `mobile_scanner`), '
      'unify ke `package:camera` + `google_mlkit_barcode_scanning`. '
      'Lihat .kiro/specs/qr-scan-unify-camera-plugin/design.md.',
    );
  return buffer.toString();
}
