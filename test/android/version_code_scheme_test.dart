import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the FROZEN versionCode scheme (decision 2026-10-17): the Android
/// code must NOT move during development. It is one constant in
/// android/app/build.gradle.kts, bumped by 1..10 only right before a publish —
/// and it must always stay above every code real installs carry, or updating
/// users meet INSTALL_FAILED_VERSION_DOWNGRADE ("بسته نامعتبر").
///
/// Dart tests never run Gradle, so this scans the build script instead.
void main() {
  final gradle = File('android/app/build.gradle.kts');

  /// The highest code ever PUBLISHED to users: 1.7.1 = 2_000_010_013 (live
  /// app/update.json); 1.7.0's direct build carried 2_000_004_000.
  const int highestPublished = 2000010013;

  String read() {
    expect(gradle.existsSync(), isTrue,
        reason: 'run from the project root so the Gradle script resolves');
    return gradle.readAsStringSync();
  }

  test('versionCode is assigned from the frozen constant, not a formula', () {
    final src = read();

    expect(src, contains('val FROZEN_VERSION_CODE = 2_000_012_020'));
    expect(src, contains('versionCode = SHIPPED_VERSION_CODE'),
        reason: 'defaultConfig must assign the shipped code');
    expect(src, contains('val SHIPPED_VERSION_CODE = FROZEN_VERSION_CODE + '),
        reason: 'the shipped code is the frozen base plus the universal offset');
    // The offset may be RAISED (3_000 → 3_010) to outrank a build already on a
    // device or in a track; it never shrinks and never enters the retired ABI
    // band, so the universal artifact keeps clearing every split code.
    final offsetPin = RegExp(
      r'val SHIPPED_VERSION_CODE = FROZEN_VERSION_CODE \+ ([\d_]+)',
    ).firstMatch(src)!.group(1)!.replaceAll('_', '');
    expect(int.parse(offsetPin), inInclusiveRange(3000, 3999),
        reason: 'the universal offset only ever grows');
    expect(src, isNot(contains('flutter.versionCode')),
        reason: 'pubspec / --build-number no longer take part in the code');
    expect(src, isNot(contains('20 * 100_000_000 + ')),
        reason: 'the dynamic compound formula moved the code on every build — '
            'the exact thing the freeze forbids');
  });

  test('the frozen code is 2000012020 and beats every published code', () {
    final m = RegExp(r'val FROZEN_VERSION_CODE = ([\d_]+)').firstMatch(read());
    expect(m, isNotNull, reason: 'FROZEN_VERSION_CODE is not declared');

    final code = int.parse(m!.group(1)!.replaceAll('_', ''));
    // Publish-time ritual: bump the constant AND this expectation together,
    // by 1..10 — nowhere else, and only right before publishing.
    expect(code, 2000012020);
    expect(code, greaterThan(highestPublished));
  });

  test('the shipped code outranks every ABI-split code ever installed', () {
    // Earlier builds shipped splits at base+1000 / base+2000. A device holding
    // one of those can only be updated by a HIGHER code — `adb install -d` is
    // debug-only, and the user-visible failure is «بسته نامعتبر». So the one
    // shipped APK must clear base+2000.
    final src = read();
    final base = RegExp(r'val FROZEN_VERSION_CODE = ([\d_]+)')
        .firstMatch(src)!
        .group(1)!
        .replaceAll('_', '');
    final offset = RegExp(r'val SHIPPED_VERSION_CODE = FROZEN_VERSION_CODE \+ ([\d_]+)')
        .firstMatch(src)!
        .group(1)!
        .replaceAll('_', '');

    expect(int.parse(offset), greaterThan(2000),
        reason: 'must exceed the highest ABI-split offset (arm64 = +2000)');
    expect(int.parse(base) + int.parse(offset), greaterThanOrEqualTo(2000015020),
        reason: 'must outrank the 1.9.0 builds already installed');
  });

  test('ABI splits stay off: the arm64 split is malformed on AGP 9', () {
    final src = read();
    // `aapt2 dump badging` on the arm64 split says "could not identify format
    // of APK" — it is packaged without its manifest or resources, so it cannot
    // be installed. One universal artifact is the fix.
    expect(src, contains('isEnable = false'));
    expect(src, isNot(contains('FROZEN_VERSION_CODE + 2000')));
    expect(src, isNot(contains('FROZEN_VERSION_CODE + 1000')));
  });
}
