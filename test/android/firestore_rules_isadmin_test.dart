import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Firestore admin gate. A `get()` result is a Resource and has no
/// member exists call; the 2026-09-28 deployed rules used one, so every
/// isAdmin() evaluation died with "Function not found" and all admin panels
/// silently denied. The Rules compiler does NOT validate member calls (a bogus
/// member also compiles), so only static source checks catch this class.
void main() {
  final rules = File('firestore.rules');

  /// Comments may quote the forbidden form; only executable lines are scanned.
  String code() {
    expect(rules.existsSync(), isTrue,
        reason: 'run from the project root so firestore.rules resolves');
    return rules
        .readAsStringSync()
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(RegExp(r'//.*'), ''))
        .join('\n');
  }

  test('isAdmin uses the static exists(path), never a member call', () {
    final src = code();

    expect(src,
        contains(r'exists(/databases/$(database)/documents/config/app)'),
        reason: 'the documented static form is the only valid existence check');
    expect(src, isNot(contains('.exists()')),
        reason: 'calling exists on a get() result throws at runtime and turns '
            'every admin rule into a deny');
    expect(src, isNot(contains('let cfg = get(')),
        reason: 'the stale get()-result local was the source of the bug');
  });

  test('isAdmin still checks auth, list shape and uid membership', () {
    final src = code();

    expect(src, contains('request.auth != null'));
    expect(src, contains('.data.adminUids is list'));
    expect(src, contains('.adminUids.hasAny([request.auth.uid])'));
  });

  test('admin-gated writes stay gated', () {
    final src = code();

    expect(src, contains('allow write: if isAdmin();'));
    expect(src, contains('allow update, delete: if isAdmin();'));
    expect(src, contains('isAdmin() && isValidAnnouncement()'));
  });

  /// Audit B-01: production ran an older ruleset where suggestions were
  /// admin-read only, so the live project and this file disagreed. The
  /// deployed 2026-10-18 ruleset carries the line below; `watchPublic()`
  /// filters `isPublic == true` and shows nothing without it. Pin it so the
  /// drift cannot return through a well-meaning tightening.
  test('public reads the app depends on stay public', () {
    final src = code();

    expect(src, contains('allow read: if resource.data.isPublic == true || isAdmin();'),
        reason: 'watchPublic() reads isPublic suggestions');
    expect(src, contains('allow read: if true;'),
        reason: 'announcements are read by every signed-out install');
    expect(
        src,
        contains(
            'allow read, write, delete: if isSignedIn() && request.auth.uid == userId;'),
        reason: 'a user backup must stay owner-only');
  });
}
