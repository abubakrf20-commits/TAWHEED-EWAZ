import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/shared/soft_notifier.dart';

/// Pure tests for the pieces of ParentLock and SoftNotifier that do not need a
/// Keystore or a platform channel: the policy maths.
///
/// The PIN hashing itself cannot run here — `Isolate.run` plus
/// flutter_secure_storage need real platform services, and mocking the
/// Keystore would only test the mock. What IS pinned is every rule the brief
/// states numerically: the quiet-hours window (including the one that crosses
/// midnight), the daily cap, and the reserved id ranges.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The quiet-hours helpers take TZDateTime, so the database must be loaded.
  tzdata.initializeTimeZones();

  group('quiet hours', () {
    test('a window that does not wrap', () {
      // 13:00 → 15:00
      expect(SoftNotifier.isQuiet(13 * 60, 780, 900), isTrue);
      expect(SoftNotifier.isQuiet(14 * 60 + 30, 780, 900), isTrue);
      expect(SoftNotifier.isQuiet(12 * 60, 780, 900), isFalse);
      expect(SoftNotifier.isQuiet(15 * 60, 780, 900), isFalse);
    });

    test('a window that crosses midnight', () {
      // 22:00 → 07:00
      const start = 22 * 60;
      const end = 7 * 60;
      expect(SoftNotifier.isQuiet(23 * 60, start, end), isTrue);
      expect(SoftNotifier.isQuiet(2 * 60, start, end), isTrue);
      expect(SoftNotifier.isQuiet(6 * 60 + 59, start, end), isTrue);
      expect(SoftNotifier.isQuiet(7 * 60, start, end), isFalse);
      expect(SoftNotifier.isQuiet(12 * 60, start, end), isFalse);
      expect(SoftNotifier.isQuiet(21 * 60 + 59, start, end), isFalse);
    });

    test('equal bounds mean the window is disabled', () {
      expect(SoftNotifier.isQuiet(0, 600, 600), isFalse);
      expect(SoftNotifier.isQuiet(12 * 60, 600, 600), isFalse);
    });

    test('an in-window time moves to the window end (same day)', () {
      final result = SoftNotifier.moveOutOfQuietHours(
        tzLocal(2026, 6, 24, 13, 30),
        780, // 13:00
        900, // 15:00
      );
      expect(result.hour, 15);
      expect(result.minute, 0);
      expect(result.day, 24);
    });

    test('a late-evening time moves to the NEXT morning', () {
      final result = SoftNotifier.moveOutOfQuietHours(
        tzLocal(2026, 6, 24, 23, 0),
        1320, // 22:00
        420, // 07:00
      );
      expect(result.hour, 7);
      expect(result.minute, 0);
      expect(result.day, 25, reason: 'the window ends tomorrow morning');
    });

    test('an early-morning time moves to the same day end', () {
      final result = SoftNotifier.moveOutOfQuietHours(
        tzLocal(2026, 6, 24, 2, 0),
        1320,
        420,
      );
      expect(result.hour, 7);
      expect(result.day, 24);
    });

    test('a time outside the window is untouched', () {
      final when = tzLocal(2026, 6, 24, 16, 0);
      final result = SoftNotifier.moveOutOfQuietHours(when, 1320, 420);
      expect(result, when);
    });
  });

  group('reserved notification id ranges', () {
    test('kids and teacher ids never leave their own range', () {
      for (var i = 0; i < 400; i++) {
        final kids = SoftNotifier.idFor(tool: 'kids', key: 'k$i');
        final teacher = SoftNotifier.idFor(tool: 'teacher', key: 't$i');
        expect(kids, inInclusiveRange(14000, 14998));
        expect(teacher, inInclusiveRange(15000, 15998));
      }
    });

    test('the summary ids sit at the top of each range', () {
      expect(SoftNotifier.kidsSummaryId, 14999);
      expect(SoftNotifier.teacherSummaryId, 15999);
    });

    test('an unknown tool falls back to the kids range, never the teacher one',
        () {
      final id = SoftNotifier.idFor(tool: 'nonsense', key: 'x');
      expect(id, inInclusiveRange(14000, 14998));
    });

    test('the same key maps to the same id (stable across restarts)', () {
      expect(
        SoftNotifier.idFor(tool: 'kids', key: 'evening_summary|1404-07-03'),
        SoftNotifier.idFor(tool: 'kids', key: 'evening_summary|1404-07-03'),
      );
    });

    test('different keys usually differ (no trivially colliding scheme)', () {
      final ids = {
        for (var i = 0; i < 200; i++)
          SoftNotifier.idFor(tool: 'kids', key: 'reminder_$i'),
      };
      // Not zero collisions guaranteed for a hash, but a scheme that mapped
      // everything to one id would collapse to 1 here.
      expect(ids.length, greaterThan(180));
    });

    test('the daily cap is the documented 3', () {
      expect(SoftNotifier.dailyCap, 3);
    });

    test('the channel name is versioned, as the brief requires', () {
      expect(SoftNotifier.channelName, contains('ابزارهای شخصی'));
      expect(SoftNotifier.channelId, endsWith('_v1'));
    });
  });

  group('kids day keys used by the notifier payloads', () {
    test('the evening summary lands on the same day key the logs use', () {
      final evening = DateTime(2026, 6, 24, 20, 0);
      expect(
        kidDayKey(evening, dayStartMinutes: 0),
        kidDayKey(DateTime(2026, 6, 24, 9, 0), dayStartMinutes: 0),
      );
    });
  });
}

/// A local-zone TZDateTime for the quiet-hours tests.
///
/// `tz.local` in a plain unit test is UTC, which is fine: the window maths is
/// wall-clock arithmetic on whatever zone the process has, and the assertion is
/// about hours and days, not about an absolute instant.
tz.TZDateTime tzLocal(int y, int m, int d, int h, int min) =>
    tz.TZDateTime(tz.local, y, m, d, h, min);
