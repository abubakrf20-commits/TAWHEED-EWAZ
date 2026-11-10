import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/shared/services/daily_notification_scheduler.dart';

/// The two halves of the launch-storm fix that CAN be exercised in Dart: the
/// coalescer that turns every boot emitter into one scheduling pass, and the
/// fingerprint-keyed throttle on the "nothing changed" branch.
///
/// [DailyNotificationScheduler] is a singleton, so [begin] clears the queue at
/// the start of every case and `tearDown` at the end — a coalesce timer left
/// behind would both fail the next test ("a Timer is still pending") and leak
/// its pending request into it.
class _StubService implements PrayerTimeService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final scheduler = DailyNotificationScheduler();
  var passes = <(PrayerTimeService, AppSettings, bool)>[];

  /// Must be the FIRST statement of every case, not a `setUp`.
  ///
  /// `flutter_test` runs `setUp` OUTSIDE the binding's fake-async zone, so a
  /// queue tail seeded there belongs to the real zone: a pass chained onto it
  /// is delivered on the real microtask queue, which the fake clock never
  /// flushes — the request would stall silently and the case would hang until
  /// the framework's 10-minute timeout.
  void begin() {
    scheduler.resetCoalescingForTest();
    passes = [];
    scheduler.passOverride = (service, settings, force) async {
      passes.add((service, settings, force));
    };
  }

  tearDown(scheduler.resetCoalescingForTest);

  group('boot passes coalesce into one', () {
    testWidgets('two requests inside the window run ONE pass, on the newest settings',
        (tester) async {
      begin();
      final tehran = _StubService();
      final shiraz = _StubService();

      final first = scheduler.scheduleIfNeeded(
          prayerService: tehran, settings: const AppSettings(city: 'تهران'));
      await tester.pump(const Duration(milliseconds: 600));
      final second = scheduler.scheduleIfNeeded(
          prayerService: shiraz, settings: const AppSettings(city: 'شیراز'));

      await tester.pump(
          DailyNotificationScheduler.coalesceWindow + const Duration(milliseconds: 1));
      await first;
      await second;

      expect(passes, hasLength(1),
          reason: 'the launch emitters must not each rebuild the queue');
      // Trailing, not leading: a boot path that reads settings a moment later
      // must not have its (newer) values dropped.
      expect(passes.single.$1, same(shiraz));
      expect(passes.single.$2.city, 'شیراز');
      expect(passes.single.$3, isFalse);
    });

    testWidgets('the window restarts on every request, so late changes join it',
        (tester) async {
      begin();
      for (var i = 0; i < 5; i++) {
        unawaited(scheduler.scheduleIfNeeded(
            prayerService: _StubService(), settings: AppSettings(city: 'شهر $i')));
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(
          DailyNotificationScheduler.coalesceWindow + const Duration(milliseconds: 1));

      expect(passes, hasLength(1));
      expect(passes.single.$2.city, 'شهر 4');
    });

    testWidgets('a force runs at once and cancels the waiting window', (tester) async {
      begin();
      unawaited(scheduler.scheduleIfNeeded(
          prayerService: _StubService(), settings: const AppSettings(city: 'تهران')));
      await tester.pump(const Duration(milliseconds: 200));

      await scheduler.forceReschedule(
          prayerService: _StubService(), settings: const AppSettings(city: 'شیراز'));

      expect(passes, hasLength(1),
          reason: 'the user is looking at the change; it cannot sit behind the '
              'window');
      expect(passes.single.$3, isTrue);
      expect(passes.single.$2.city, 'شیراز');

      await tester.pump(const Duration(seconds: 10));
      expect(passes, hasLength(1),
          reason: 'the coalesce timer the plain request armed must be gone');
    });

    testWidgets('a forced request queued behind a plain one still forces',
        (tester) async {
      begin();
      unawaited(scheduler.scheduleIfNeeded(
          prayerService: _StubService(), settings: const AppSettings()));
      await tester.pump(const Duration(milliseconds: 300));
      await scheduler.forceReschedule(
          prayerService: _StubService(), settings: const AppSettings());
      await tester.pump(const Duration(seconds: 5));

      expect(passes, hasLength(1));
      expect(passes.single.$3, isTrue,
          reason: 'a force inside the window must never be downgraded to the '
              'coalesced path');
    });

    testWidgets('every caller gets its own future — and the shared error',
        (tester) async {
      begin();
      scheduler.passOverride = (service, settings, force) async {
        passes.add((service, settings, force));
        throw StateError('boom');
      };

      Object? errFirst;
      Object? errSecond;
      final first = scheduler
          .scheduleIfNeeded(
              prayerService: _StubService(), settings: const AppSettings())
          .catchError((Object e) => errFirst = e);
      await tester.pump(const Duration(milliseconds: 500));
      final second = scheduler
          .scheduleIfNeeded(
              prayerService: _StubService(), settings: const AppSettings())
          .catchError((Object e) => errSecond = e);

      await tester.pump(
          DailyNotificationScheduler.coalesceWindow + const Duration(milliseconds: 1));
      await first;
      await second;

      expect(passes, hasLength(1));
      expect(errFirst, isStateError,
          reason: 'the call sites\' existing error handling must keep '
              'describing what happens, exactly as per-call');
      expect(errSecond, isStateError);
    });

    testWidgets('a request made while a pass runs waits for the next one',
        (tester) async {
      begin();
      final gate = Completer<void>();
      scheduler.passOverride = (service, settings, force) async {
        passes.add((service, settings, force));
        await gate.future;
      };

      unawaited(scheduler.scheduleIfNeeded(
          prayerService: _StubService(), settings: const AppSettings(city: 'تهران')));
      await tester.pump(
          DailyNotificationScheduler.coalesceWindow + const Duration(milliseconds: 1));
      await tester.pump();
      expect(passes, hasLength(1));

      unawaited(scheduler.scheduleIfNeeded(
          prayerService: _StubService(), settings: const AppSettings(city: 'شیراز')));
      await tester.pump(
          DailyNotificationScheduler.coalesceWindow + const Duration(milliseconds: 1));
      expect(passes, hasLength(1),
          reason: 'the queue is serial: a second pass must not start over the '
              'first and interleave its cancels');

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(passes, hasLength(2));
      expect(passes[1].$2.city, 'شیراز');
    });
  });

  group('the reconcile throttle is keyed to the settings fingerprint', () {
    const fp = 'fp-a';
    final now = DateTime(2026, 10, 17, 12).millisecondsSinceEpoch;
    const minute = 60000;

    void expectDue(String stamp, bool due, String why) => expect(
        DailyNotificationScheduler.reconcileDueFromStamp(stamp, fp, now), due,
        reason: why);

    test('anything unknown or unreadable is due', () {
      expectDue('', true, 'a first run must always reconcile');
      expectDue('garbage', true, 'a stamp with no fingerprint half');
      expectDue('|$fp', true, 'no milliseconds in front of the separator');
      expectDue('0|$fp', true, 'an unset timestamp');
      expectDue('abc|$fp', true, 'an unparseable timestamp');
    });

    test('a different fingerprint is always due', () {
      expectDue('${now - minute}|fp-b', true,
          'a settings change flips the fingerprint and must re-arm now');
    });

    test('the same fingerprint re-arms at most once per interval', () {
      expectDue('${now - 1000}|$fp', false, 'one second ago');
      expectDue('${now - minute}|$fp', false, 'one minute ago');
      expectDue(
          '${now - DailyNotificationScheduler.reconcileInterval.inMilliseconds}|$fp',
          true,
          'the interval itself is due, not after it');
      expectDue('${now - 5 * minute}|$fp', true, 'well past the interval');
    });

    test('a stamp in the future counts as due', () {
      expectDue('${now + 10 * minute}|$fp', true,
          'a clock correction must not freeze the queue behind an age check');
    });
  });
}
