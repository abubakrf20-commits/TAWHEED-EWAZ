import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/services/kid_evening_summary.dart';
import 'package:tawheeed/features/personal2/shared/soft_notifier.dart';

class _FakePlugin implements NotificationPlugin {
  final List<({int id, String title, String body, DateTime when})> scheduled =
      [];
  final List<int> cancelled = [];

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    String? payload,
    AndroidScheduleMode? androidScheduleMode,
  }) async {
    scheduled.add((id: id, title: title, body: body, when: scheduledDate));
  }

  @override
  Future<void> cancel({required int id}) async => cancelled.add(id);

  @override
  RequestChannel? get channelRequester => null;
}

const _on = KidSettingsRecord(
  eveningSummaryEnabled: true,
  eveningSummaryMinutes: 20 * 60,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  group('plan', () {
    test('off means nothing is planned', () {
      expect(
        planKidEvening(
          settings: const KidSettingsRecord(),
          kidName: 'زهرا',
          done: 1,
          total: 3,
          stars: 2,
          now: DateTime(2026, 11, 5, 9),
        ),
        isEmpty,
      );
    });

    test('tonight carries the real counts, the following nights a nudge', () {
      final plans = planKidEvening(
        settings: _on,
        kidName: 'زهرا',
        done: 2,
        total: 3,
        stars: 4,
        now: DateTime(2026, 11, 5, 9),
      );
      expect(plans, hasLength(kKidEveningHorizonDays));
      expect(plans.first.title, 'خلاصهٔ امروز زهرا');
      expect(plans.first.body, contains('2 از 3'));
      expect(plans.first.body, contains('4 ستاره'));
      expect(plans.first.at, DateTime(2026, 11, 5, 20));
      expect(plans.first.dayKey, kidDayKeyOf(DateTime(2026, 11, 5)));
      // Gregorian input, Jalali key — the bug that made a key read 2648.
      expect(plans.first.dayKey, '1405-08-14');
      expect(plans[1].title, 'دفتر زهرا');
      expect(plans[1].body, isNot(contains('انجام شد')));
      // Every night has its own key, so cancelling one cannot cancel another.
      expect(plans.map((p) => p.key).toSet(), hasLength(plans.length));
    });

    test('a finished day is praised, an empty day says so', () {
      expect(
        kidEveningBody(kidName: 'علی', done: 3, total: 3, stars: 0),
        'همهٔ 3 کار علی امروز انجام شد.',
      );
      expect(
        kidEveningBody(kidName: 'علی', done: 0, total: 0, stars: 0),
        contains('کاری برای امروز ثبت نشده'),
      );
    });

    test("an hour that has already passed is not planned for today", () {
      final plans = planKidEvening(
        settings: _on,
        kidName: 'زهرا',
        done: 1,
        total: 2,
        stars: 1,
        now: DateTime(2026, 11, 5, 21),
      );
      expect(plans, hasLength(kKidEveningHorizonDays - 1));
      expect(plans.first.at.day, 6);
      expect(plans.first.title, 'دفتر زهرا');
    });

    test('an impossible hour plans nothing instead of throwing', () {
      expect(
        planKidEvening(
          settings: const KidSettingsRecord(
            eveningSummaryEnabled: true,
            eveningSummaryMinutes: 2000,
          ),
          kidName: 'زهرا',
          done: 1,
          total: 2,
          stars: 0,
          now: DateTime(2026, 11, 5, 9),
        ),
        isEmpty,
      );
    });
  });

  group('service', () {
    test('switching on schedules a week through the notifier', () async {
      final plugin = _FakePlugin();
      final service =
          KidEveningSummaryService(notifier: SoftNotifier(plugin: plugin));
      // SoftNotifier drops a target that is already past against the wall
      // clock, so the fixture has to start tomorrow: a hardcoded date turns
      // this test red the day after it is written.
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final count = await service.sync(
        settings: _on,
        kidName: 'زهرا',
        done: 1,
        total: 2,
        stars: 1,
        now: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9),
      );
      expect(count, kKidEveningHorizonDays);
      expect(plugin.scheduled, hasLength(kKidEveningHorizonDays));
      // Ids land inside the kids range SoftNotifier reserves.
      for (final row in plugin.scheduled) {
        expect(row.id, greaterThanOrEqualTo(SoftNotifier.kidsBase));
        expect(row.id, lessThan(SoftNotifier.kidsBase + SoftNotifier.kidsSpace));
      }
    });

    test('switching off cancels the keys instead of scheduling', () async {
      final plugin = _FakePlugin();
      final service =
          KidEveningSummaryService(notifier: SoftNotifier(plugin: plugin));
      final count = await service.sync(
        settings: const KidSettingsRecord(),
        kidName: 'زهرا',
        done: 1,
        total: 2,
        stars: 1,
        now: DateTime(2026, 11, 5, 9),
      );
      expect(count, 0);
      expect(plugin.scheduled, isEmpty);
      // Three days back plus the week ahead — including yesterday's stale key.
      expect(plugin.cancelled, hasLength(3 + kKidEveningHorizonDays));
    });

    test('a quiet-hour clash moves the nudge instead of dropping it', () async {
      final plugin = _FakePlugin();
      final service =
          KidEveningSummaryService(notifier: SoftNotifier(plugin: plugin));
      await service.sync(
        settings: const KidSettingsRecord(
          eveningSummaryEnabled: true,
          eveningSummaryMinutes: 23 * 60,
          // 22:00 → 07:00 covers 23:00.
          quietStartMinutes: 22 * 60,
          quietEndMinutes: 7 * 60,
        ),
        kidName: 'زهرا',
        done: 0,
        total: 2,
        stars: 0,
        now: DateTime(2026, 11, 5, 9),
      );
      final tonight = plugin.scheduled.first.when;
      expect(tonight.day, 6, reason: 'moved to the 07:00 boundary');
      expect(tonight.hour, 7);
    });
  });
}
