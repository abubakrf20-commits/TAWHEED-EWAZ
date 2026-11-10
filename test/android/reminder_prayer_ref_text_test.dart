import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/reminders/domain/entities/reminder_model.dart';

/// Guards the wording of a prayer-based reminder notification.
///
/// `prayerRef` is persisted as raw English codes (`'fajr,dhuhr'`) and the
/// scheduler used to interpolate the code straight into the fallback body, so a
/// Fajr reminder with an empty note notified as «زمان fajr فرا رسید». The body
/// is authored in the provider and posted verbatim by the native receiver, and
/// the provider takes no notification seam a Dart test could observe — so the
/// source scan is the guard (the repo's idiom for such invariants; see
/// reminder_custom_sound_test.dart).
Future<String> readSource(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

void main() {
  group('a reminder body never prints a raw prayer code', () {
    late String provider;

    setUp(() async {
      provider = await readSource(
          'lib/features/reminders/presentation/providers/reminder_provider.dart');
    });

    test('the Persian name is resolved once per ref', () {
      expect(
          provider
              .contains('final refFa = prayerNamesFa(ref);'),
          isTrue,
          reason: 'the loop must resolve the code before composing text');
      expect(
          provider.contains(
              "import 'package:tawheeed/features/reminders/domain/entities/reminder_model.dart'"),
          isTrue,
          reason: 'prayerNamesFa lives in the domain helpers');
      expect(provider.contains('show prayerNamesFa'), isTrue,
          reason: 'the domain import must be scoped to the helper it uses');
    });

    test('both fallback bodies carry the Persian name', () {
      expect(provider.contains("'زمان اذان \$refFa نزدیک است'"), isTrue,
          reason: 'the early body must not interpolate the raw code');
      expect(provider.contains("'زمان اذان \$refFa فرا رسید'"), isTrue,
          reason: 'the main body must not interpolate the raw code');
    });

    test('no user-facing title or body interpolates a bare ref', () {
      // `$refFa` starts with `$ref`, so the identifier guard is required: a
      // bare match is a `$ref` that is not followed by a name character.
      final bare = RegExp(r'\$ref(?![A-Za-z0-9_])');
      final offenders = <String>[];
      for (final line in provider.split('\n')) {
        if (!line.contains('title:') && !line.contains('body:')) continue;
        if (bare.hasMatch(line)) offenders.add(line.trim());
      }
      expect(offenders, isEmpty,
          reason: 'a raw English prayer code reached user-facing text');
    });

    test('keys and payloads keep the raw code', () {
      // The code is the schedule identity: only the visible text changes.
      expect(provider.contains("key: '\${r.id}@\$ref#early'"), isTrue);
      expect(provider.contains("key: '\${r.id}@\$ref'"), isTrue);
      expect(provider.contains("payload: 'reminder_\${r.id}_\$ref'"), isTrue);
    });
  });

  group('the shared Persian name map', () {
    test('names every schedulable prayer', () {
      expect(prayerNamesFa('fajr'), 'صبح');
      expect(prayerNamesFa('dhuhr'), 'ظهر');
      expect(prayerNamesFa('asr'), 'عصر');
      expect(prayerNamesFa('maghrib'), 'مغرب');
      expect(prayerNamesFa('isha'), 'عشاء');
    });

    test('joins several prayers and passes unknown codes through', () {
      expect(prayerNamesFa('fajr,dhuhr'), 'صبح، ظهر');
      expect(prayerNamesFa(' fajr , maghrib '), 'صبح، مغرب');
      expect(prayerNamesFa('tahajjud'), 'tahajjud');
    });
  });
}
