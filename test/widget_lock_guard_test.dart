import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/widget_lock.dart';

/// The prayer and tasbih widgets are LOCKED.
///
/// The user's words: «ویجت را قفل کنید که هیچ دستیاری بدون اجازهٔ صریح ویجت را
/// دستکاری نکند». This test is that lock's enforcement: if any file the
/// widgets are built from changed, the suite goes red until someone states
/// who allowed the change and why.
///
/// To change a widget file you must first have the user's explicit
/// permission, then:
///
///     dart run tool/widget_lock.dart --update --reason "…"
///
/// which rewrites `widget_lock.json` and appends a dated line to
/// `WIDGET_LOCK_LOG.md`. See `WIDGET_LOCK.md`.
void main() {
  test('the prayer and tasbih widgets are untouched since they were locked', () {
    final report = verifyLock();
    if (!report.isClean) {
      fail(
        'WIDGET LOCK VIOLATED (${report.problems.length} file(s)).\n'
        'The prayer / tasbih widgets are locked — do not edit them without '
        "the user's explicit permission.\n"
        '${report.changed.map((p) => '  changed: $p').join('\n')}'
        '${report.added.map((p) => '\n  added:   $p').join()}'
        '${report.missing.map((p) => '\n  missing: $p').join()}\n'
        'With permission, re-lock and say why:\n'
        '  dart run tool/widget_lock.dart --update --reason "…"',
      );
    }
    // A lock that covers nothing would pass this test forever.
    expect(report.checked, greaterThanOrEqualTo(20),
        reason: 'the lock must actually cover the widget sources');
  });

  test('a re-lock without a stated reason is refused', () {
    // An unlock with no reason is the exact thing the lock exists to stop, so
    // the tool refuses it rather than quietly rewriting the manifest.
    expect(() => updateLock(reason: '   '), throwsArgumentError);
  });

  test('the manifest names the widget files, not a stale path list', () {
    // Guard against the manifest drifting to paths that no longer exist: the
    // verifier would then report them missing, and this test says so first.
    final report = verifyLock();
    expect(report.missing, isEmpty,
        reason: 'every locked path must still exist');
  });

  test('a worktree that writes CRLF is not a change', () {
    // Several Windows worktrees share this repo and `core.autocrlf` gives each
    // of them different line endings for the same committed blob. Hashing raw
    // bytes reported untouched widget files as «changed» for that reason
    // alone, so the digest normalises endings and a BOM first.
    final lf = utf8.encode('fun label(i: Int) = NAMES[i]\n');
    final crlf = utf8.encode('fun label(i: Int) = NAMES[i]\r\n');
    final bom = <int>[0xEF, 0xBB, 0xBF, ...lf];

    expect(digestOfBytes(crlf), digestOfBytes(lf));
    expect(digestOfBytes(bom), digestOfBytes(lf));
  });

  test('a single changed character still trips the lock', () {
    // The normalisation above must not blunt the tripwire: one letter of real
    // code moving is exactly what the user asked us to notice.
    expect(
      digestOfBytes(utf8.encode('fun label(i: Int) = NAMES[i]\r\n')),
      isNot(digestOfBytes(utf8.encode('fun label(i: Int) = NAMES[j]\r\n'))),
    );
    // A lone CR is content, not an ending: it must survive normalisation.
    expect(
      digestOfBytes(utf8.encode('a\rb')),
      isNot(digestOfBytes(utf8.encode('ab'))),
    );
  });
}
