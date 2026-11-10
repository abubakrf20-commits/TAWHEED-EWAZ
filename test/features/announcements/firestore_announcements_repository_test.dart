import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/announcements/data/repositories/firestore_announcements_repository.dart';
import 'package:tawheeed/features/announcements/domain/repositories/announcements_repository.dart';

void main() {
  // In this environment Firebase is never initialized, so `Firebase.apps` is
  // empty and `isAvailable` is false. That is exactly the state the old code
  // got wrong: `publish()` returned silently and the screen reported success.
  group('write without Firebase', () {
    final repo = FirestoreAnnouncementsRepository();

    test('isAvailable is false here, which is the precondition', () {
      expect(repo.isAvailable, isFalse);
    });

    test('publish throws instead of silently doing nothing', () async {
      // The regression: this used to `return` without a write, and the UI then
      // showed «پیام منتشر شد.» — a false success for a message nobody received.
      await expectLater(
        repo.publish(title: 'عنوان', body: 'متن'),
        throwsA(isA<AnnouncementsWriteError>()),
      );
    });

    test('the failure says the service is unavailable', () async {
      try {
        await repo.publish(title: 'عنوان', body: 'متن');
        fail('publish must not succeed without Firebase');
      } on AnnouncementsWriteError catch (e) {
        expect(e.reason, AnnouncementsFailure.unavailable);
        expect(e.message, contains('در دسترس نیست'));
      }
    });

    test('setPinned, update and delete throw too', () async {
      await expectLater(
        repo.setPinned('x', true),
        throwsA(isA<AnnouncementsWriteError>()),
      );
      await expectLater(
        repo.update(id: 'x', title: 'عنوان', body: 'متن'),
        throwsA(isA<AnnouncementsWriteError>()),
      );
      await expectLater(
        repo.delete('x'),
        throwsA(isA<AnnouncementsWriteError>()),
      );
    });

    test('watchAll yields nothing rather than throwing', () async {
      // Reading must stay safe: the screen shows an «unavailable» card, it
      // must not crash the list.
      expect(await repo.watchAll().toList(), isEmpty);
    });
  });

  group('write errors are actionable', () {
    test('permission-denied explains the deploy command', () {
      const e = AnnouncementsWriteError(AnnouncementsFailure.permissionDenied);
      // «دوباره تلاش کنید» would be useless: retrying an identical request
      // against unchanged rules fails identically. Name both likely causes.
      expect(e.message, isNot(contains('دوباره تلاش کنید')));
      expect(e.message, contains('firebase deploy --only firestore:rules'));
      expect(e.message, contains('adminUids'));
      expect(e.message, contains('config/app'));
    });

    test('every failure has a non-empty, distinct message', () {
      final messages = {
        for (final r in AnnouncementsFailure.values)
          r: AnnouncementsWriteError(r).message,
      };
      expect(messages.values.every((m) => m.trim().isNotEmpty), isTrue);
      expect(
        messages.values.toSet().length,
        AnnouncementsFailure.values.length,
      );
    });

    test('toString keeps the underlying cause for the log', () {
      const e = AnnouncementsWriteError(
        AnnouncementsFailure.permissionDenied,
        cause: 'permission-denied: Missing or insufficient permissions.',
      );
      expect(e.toString(), contains('permissionDenied'));
      expect(e.toString(), contains('Missing or insufficient permissions'));
    });
  });

  group('client limits match firestore.rules', () {
    // A mismatch is silently fatal: the client would accept a message that the
    // rules reject, and the admin would only see a generic failure. The rules
    // are the source of truth, so assert against the file rather than a copy.
    late String rules;

    setUpAll(() {
      // The rules live at the repository root; walk up from the test file.
      var dir = Directory.current;
      while (!File(
        '${dir.path}${Platform.pathSeparator}firestore.rules',
      ).existsSync()) {
        final parent = dir.parent;
        if (parent.path == dir.path) {
          fail('firestore.rules not found above ${Directory.current.path}');
        }
        dir = parent;
      }
      rules = File(
        '${dir.path}${Platform.pathSeparator}firestore.rules',
      ).readAsStringSync();
    });

    test('title limit agrees with isValidAnnouncement()', () {
      expect(
        rules,
        contains('title.size() <= $kAnnouncementMaxTitleLength'),
        reason: 'the client would accept a title the rules reject',
      );
    });

    test('body limit agrees with isValidAnnouncement()', () {
      expect(
        rules,
        contains('body.size() <= $kAnnouncementMaxBodyLength'),
        reason: 'the client would accept a body the rules reject',
      );
    });

    test('the announcement collection still requires an admin to create', () {
      expect(rules, contains('match /announcements/{announcementId}'));
      expect(rules, contains('allow create: if isAdmin()'));
    });

    test('the rules let an admin edit an announcement', () {
      // The screen exposes ویرایش; without `allow update` the rules would
      // silently reject it and the admin would only see a generic failure.
      expect(rules, contains('allow update, delete: if isAdmin()'));
    });

    test('isAdmin() handles a missing config document explicitly', () {
      // Without the exists() check a missing `config/app` makes the rule
      // expression error, which reaches the client as an indistinguishable
      // permission-denied. The check must be the STATIC exists(path) form: a
      // `get()` result has no `.exists()` member, and calling it made every
      // isAdmin() rule deny (fixed in a657342 — do not reintroduce it).
      expect(
        rules,
        contains('exists(/databases/\$(database)/documents/config/app)'),
      );
      expect(rules, isNot(contains('cfg.exists()')));
    });

    test(
      'the push outbox is writable by an admin, so publish can queue it',
      () {
        expect(rules, contains('match /admin/outbox/{docId}'));
      },
    );
  });
}
