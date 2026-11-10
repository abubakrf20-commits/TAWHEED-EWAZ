import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards audit C-03: the Play artifact must carry the `play` channel.
///
/// With the frozen versionCode (2026-10-17) Play and self-hosted builds share
/// one code, so the versionCode floor can no longer tell them apart. If the
/// AAB is built without `--dart-define=APP_CHANNEL=play`, every Play install
/// is classified as a direct build and the update dialog offers a raw APK.
void main() {
  final ci = File('.github/workflows/ci.yml');
  final checker = File('lib/features/settings/services/update_checker.dart');

  String read(File f) {
    expect(f.existsSync(), isTrue,
        reason: 'run from the project root so ${f.path} resolves');
    return f.readAsStringSync();
  }

  test('every AAB build in CI passes APP_CHANNEL=play', () {
    final lines = read(ci)
        .split(RegExp(r'\r?\n'))
        .where((line) => line.contains('build appbundle'))
        .where((line) => !line.trimLeft().startsWith('#'))
        .toList();

    expect(lines, isNotEmpty, reason: 'CI no longer builds an AAB at all');
    for (final line in lines) {
      expect(line, contains('--dart-define=APP_CHANNEL=play'),
          reason: 'a Play artifact without the play channel offers raw APKs');
    }
  });

  test('the checker separates the channel before the versionCode fallback', () {
    final src = read(checker);

    expect(src, contains("String.fromEnvironment('APP_CHANNEL')"));
    expect(src, contains("if (_channel == 'play') return false;"),
        reason: 'a Play build must never be classified as direct');
    expect(src, contains("if (_channel == 'direct') return true;"));
    expect(src, contains('return runningCode >= _directCode;'),
        reason: 'builds predating the define keep the versionCode fallback');
  });

  test('the APK script stays a direct build (no play define)', () {
    final script = File('tool/build_release.ps1').readAsStringSync();

    expect(script, contains("'build', 'apk'"));
    expect(script, isNot(contains('APP_CHANNEL=play')),
        reason: 'self-hosted APKs are the direct channel by design');
  });

  test('the OTA script publishes pinned per-ABI variants', () {
    final script = read(File('tools/prepare_update.ps1'));

    expect(script, contains('--split-per-abi'),
        reason: 'a split install must be able to fetch a split artifact');
    expect(script, contains('apkVariants'));
    expect(script, contains(r'apkSha256   = $universalSha'),
        reason: 'an unpinned manifest is ignored by the checker');
    expect(script, contains(r'$FrozenCode + 2000'));
    expect(script, contains(r'$FrozenCode + 1000'));
    expect(script, isNot(contains('Set-Content')),
        reason: 'PS 5.1 writes a BOM that jsonDecode() rejects');
  });

  test('the checker only accepts pinned variants from allowed hosts', () {
    final src = read(checker);

    expect(src, contains("manifest['apkVariants']"));
    expect(src, contains('if (!isAllowedApkUrl(url) || sha == null) continue;'),
        reason: 'a variant must never be selected unpinned or off-host');
  });
}
