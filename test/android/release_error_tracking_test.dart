import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards audit B-06: release crash reporting.
///
/// A plain `flutter build apk --release` passes no `--dart-define`, so Sentry
/// stays silently disabled in the shipped APK — the exact state the audit
/// found. The release script must keep refusing to build without a DSN, and
/// main.dart must keep reading the same define. The DSN itself is a
/// credential: it is injected from the environment and must never appear in
/// the repository.
void main() {
  final script = File('tool/build_release.ps1');
  final mainDart = File('lib/main.dart');
  final guide = File('docs/ERROR_TRACKING.md');

  String read(File f) {
    expect(f.existsSync(), isTrue,
        reason: 'run from the project root so ${f.path} resolves');
    return f.readAsStringSync();
  }

  test('the release script refuses to build without a DSN', () {
    final src = read(script);

    expect(src, contains("'SENTRY_DSN is not set."),
        reason: 'a silent no-Sentry release is the defect B-06 reported');
    expect(src, contains(r'--dart-define=SENTRY_DSN=$($env:SENTRY_DSN)'),
        reason: 'the DSN must reach the build as a define');
    expect(src, contains(r'[switch]$NoSentry'),
        reason: 'a deliberate opt-out is allowed; an accidental one is not');
    expect(src, contains('docs/ERROR_TRACKING.md'),
        reason: 'the failure message must point at the activation guide');
  });

  test('main.dart reads the define and no-ops without it', () {
    final src = read(mainDart);

    expect(src, contains("String.fromEnvironment('SENTRY_DSN')"),
        reason: 'the build-time define is the only DSN source');
    expect(src, contains('_sentryDsn.isNotEmpty'),
        reason: 'an absent DSN must disable reporting, not crash the launch');
    expect(src, contains('options.dsn = _sentryDsn'));
    expect(src, contains('SentryFlutter.init'),
        reason: 'the guarded init is the only capture path');
    expect(src, contains('continuing without it'),
        reason:
            'a failed init must be logged and survived (launch-first rule)');
  });

  test('no DSN literal is committed anywhere', () {
    // Sentry keys are 32 hex chars; the host carries the org/project ids.
    final pattern = RegExp(r'https://[0-9a-f]{32}@[^/\s]+ingest');
    for (final f in [script, mainDart, guide]) {
      expect(pattern.hasMatch(read(f)), isFalse,
          reason: '${f.path} appears to carry a live Sentry DSN');
    }
  });

  test('the activation guide names the one build path', () {
    final src = read(guide);

    expect(src, contains('tool/build_release.ps1'));
    expect(src, contains('SENTRY_DSN'));
  });
}
