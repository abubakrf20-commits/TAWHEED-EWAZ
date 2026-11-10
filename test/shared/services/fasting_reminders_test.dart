import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Guards the two voluntary-fasting reminder families:
/// - Monday/Thursday: two repeating ids, one per weekday (dayOfWeekAndTime
///   matches exactly one weekday, so one id can never fire twice a week).
/// - ایام بیض (Hijri 13-15): per-day one-shots whose dates drift through the
///   Gregorian calendar, so a weekly match cannot follow them.
///
/// On the test host `Platform.isAndroid` is false, so the native arm is
/// skipped and every schedule lands on the plugin channel — which is exactly
/// what makes the weekday math, the per-day window and the cancel sweep
/// observable here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <({String method, Map<String, Object?> args})>[];
  var pendingResponse = <Map<String, dynamic>>[];

  setUp(() {
    tzdata.initializeTimeZones();
    calls.clear();
    pendingResponse = <Map<String, dynamic>>[];
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments;
      calls.add((
        method: call.method,
        args: arguments is Map
            ? Map<String, Object?>.from(arguments)
            : <String, Object?>{},
      ));
      if (call.method == 'pendingNotificationRequests') {
        return pendingResponse;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<Map<String, Object?>> schedules() => calls
      .where((c) => c.method == 'zonedSchedule')
      .map((c) => c.args)
      .toList();

  List<int> scheduledIds() =>
      schedules().map((a) => a['id'] as int).toList();

  List<int> cancelledIds() => calls
      .where((c) => c.method == 'cancel')
      .map((c) => c.args['id'] as int)
      .toList();

  Map<String, Object?> scheduleOf(int id) =>
      schedules().singleWhere((a) => a['id'] == id);

  DateTime wallClockOf(Map<String, Object?> schedule) =>
      DateTime.parse(schedule['scheduledDateTime'] as String);

  test('arms Monday and Thursday on their own repeating ids', () async {
    SharedPreferences.setMockInitialValues({});

    await NotificationService().scheduleMondayThursdayFasting(
      time: const TimeOfDay(hour: 7, minute: 0),
    );

    expect(scheduledIds(), [NotificationIds.fastingMonday,
        NotificationIds.fastingThursday]);

    final monday = scheduleOf(NotificationIds.fastingMonday);
    expect(monday['title'], 'روزهٔ دوشنبه');
    expect(monday['payload'], 'fasting_monday');
    expect(monday['matchDateTimeComponents'],
        DateTimeComponents.dayOfWeekAndTime.index);
    final mondayAt = wallClockOf(monday);
    expect(mondayAt.weekday, DateTime.monday);
    expect([mondayAt.hour, mondayAt.minute], [7, 0]);
    expect(mondayAt.difference(DateTime.now()).inDays, lessThanOrEqualTo(7));

    final thursday = scheduleOf(NotificationIds.fastingThursday);
    expect(thursday['title'], 'روزهٔ پنجشنبه');
    expect(thursday['payload'], 'fasting_thursday');
    expect(thursday['matchDateTimeComponents'],
        DateTimeComponents.dayOfWeekAndTime.index);
    final thursdayAt = wallClockOf(thursday);
    expect(thursdayAt.weekday, DateTime.thursday);
    expect([thursdayAt.hour, thursdayAt.minute], [7, 0]);

    // Cancel-then-schedule: a re-arm replaces the previous alarm, never stacks.
    final ids = cancelledIds();
    expect(ids, containsAll([NotificationIds.fastingMonday,
        NotificationIds.fastingThursday]));
  });

  test('honours a custom time for the weekdays', () async {
    SharedPreferences.setMockInitialValues({});

    await NotificationService().scheduleMondayThursdayFasting(
      time: const TimeOfDay(hour: 9, minute: 15),
    );

    for (final id in [NotificationIds.fastingMonday,
        NotificationIds.fastingThursday]) {
      final at = wallClockOf(scheduleOf(id));
      expect([at.hour, at.minute], [9, 15]);
    }
  });

  test('sync defaults to enabled at 07:00 for both families', () async {
    SharedPreferences.setMockInitialValues({});

    await NotificationService().syncFastingReminders();

    final ids = scheduledIds();
    expect(ids, contains(NotificationIds.fastingMonday));
    expect(ids, contains(NotificationIds.fastingThursday));
    expect(ids.where((id) => id >= NotificationIds.ayamAlBidhDayBase),
        isNotEmpty);

    for (final id in [
      NotificationIds.fastingMonday,
      NotificationIds.fastingThursday,
    ]) {
      final at = wallClockOf(scheduleOf(id));
      expect([at.hour, at.minute], [7, 0]);
    }
    for (final schedule in schedules().where(
        (a) => (a['id'] as int) >= NotificationIds.ayamAlBidhDayBase)) {
      final at = wallClockOf(schedule);
      expect([at.hour, at.minute], [7, 0]);
    }
  });

  test('disabled prefs cancel both families and arm nothing', () async {
    SharedPreferences.setMockInitialValues({
      NotificationService.fastingMonThuEnabledKey: false,
      NotificationService.fastingBidhEnabledKey: false,
    });

    await NotificationService().syncFastingReminders();

    expect(scheduledIds(), isEmpty);
    expect(cancelledIds(), containsAll([
      NotificationIds.fastingMonday,
      NotificationIds.fastingThursday,
    ]));
    // The window decline still sweeps its pending ids.
    expect(
      calls.where((c) => c.method == 'pendingNotificationRequests'),
      isNotEmpty,
    );
  });

  test('each family keeps its own stored time', () async {
    SharedPreferences.setMockInitialValues({
      NotificationService.fastingBidhEnabledKey: false,
      NotificationService.fastingMonThuHourKey: 5,
      NotificationService.fastingMonThuMinuteKey: 30,
    });

    await NotificationService().syncFastingReminders();

    for (final id in [
      NotificationIds.fastingMonday,
      NotificationIds.fastingThursday,
    ]) {
      final at = wallClockOf(scheduleOf(id));
      expect([at.hour, at.minute], [5, 30]);
    }
    expect(
      scheduledIds().where((id) => id >= NotificationIds.ayamAlBidhDayBase),
      isEmpty,
    );
  });

  group('ایام بیض window', () {
    setUp(() {
      // Isolate the window from the weekdays in these cases.
      SharedPreferences.setMockInitialValues({
        NotificationService.fastingMonThuEnabledKey: false,
      });
    });

    test('arms only Hijri 13-15 days as per-day one-shots', () async {
      await NotificationService().scheduleAyamAlBidhFasting(
        hijriOffset: 2,
        time: const TimeOfDay(hour: 7, minute: 0),
      );

      final schedulesInWindow = schedules()
          .where((a) => (a['id'] as int) >= NotificationIds.ayamAlBidhDayBase)
          .toList();
      expect(schedulesInWindow, isNotEmpty);
      // 45 days always contain at least one complete 13/14/15 block and can
      // never contain more than two.
      expect(schedulesInWindow.length, inInclusiveRange(3, 6));

      final dates = <DateTime>{};
      final months = <String, Set<int>>{};
      for (final schedule in schedulesInWindow) {
        final at = wallClockOf(schedule);
        final date = DateTime(at.year, at.month, at.day);
        expect([at.hour, at.minute], [7, 0]);

        // Id = base + 0-based day-of-year of the fire date.
        final dayOfYear = date.difference(DateTime(date.year)).inDays;
        expect(schedule['id'], NotificationIds.ayamAlBidhDayBase + dayOfYear);

        final hijri = HijriUtils.hijriFromGreg(
            date.year, date.month, date.day,
            offset: 2);
        expect(hijri.day, inInclusiveRange(13, 15));
        expect(schedule['payload'], 'ayam_al_bidh');
        // One-shots: a weekly/daily component would re-fire a day that the
        // next reschedule merely re-arms.
        expect(schedule.containsKey('matchDateTimeComponents'), isFalse);

        final monthName = DateConstants.hijriMonths[hijri.month - 1];
        expect(schedule['title'], 'روزهٔ ایام بیض — ${hijri.day} $monthName');
        expect(dates.add(date), isTrue, reason: 'duplicate fire date $date');
        months
            .putIfAbsent('${hijri.year}-${hijri.month}', () => <int>{})
            .add(hijri.day);
      }

      // At least one block is complete — the window can clip the edges, but it
      // must never skip a whole 13/14/15.
      expect(
        months.values.any((days) => days.containsAll(const {13, 14, 15})),
        isTrue,
        reason: 'window covered $months',
      );
    });

    test('the user Hijri offset moves the window', () async {
      await NotificationService().scheduleAyamAlBidhFasting(
        hijriOffset: 0,
        time: const TimeOfDay(hour: 7, minute: 0),
      );
      final withoutOffset = schedules()
          .where((a) => (a['id'] as int) >= NotificationIds.ayamAlBidhDayBase)
          .map((a) => a['scheduledDateTime'])
          .toSet();
      calls.clear();

      await NotificationService().scheduleAyamAlBidhFasting(
        hijriOffset: 2,
        time: const TimeOfDay(hour: 7, minute: 0),
      );
      final withOffset = schedules()
          .where((a) => (a['id'] as int) >= NotificationIds.ayamAlBidhDayBase)
          .map((a) => a['scheduledDateTime'])
          .toSet();

      expect(withOffset, isNot(equals(withoutOffset)),
          reason: 'offset 2 must shift the bidh days off offset 0');
    });

    test('re-running the window never leaves duplicate ids', () async {
      final service = NotificationService();
      await service.scheduleAyamAlBidhFasting(
        hijriOffset: 2,
        time: const TimeOfDay(hour: 7, minute: 0),
      );
      final first = scheduledIds()
          .where((id) => id >= NotificationIds.ayamAlBidhDayBase)
          .toList();
      calls.clear();

      await service.scheduleAyamAlBidhFasting(
        hijriOffset: 2,
        time: const TimeOfDay(hour: 7, minute: 0),
      );
      final second = scheduledIds()
          .where((id) => id >= NotificationIds.ayamAlBidhDayBase)
          .toList();

      expect(second, first);
      expect(second.toSet().length, second.length);
    });

    test('cancel also sweeps ids the plugin still lists as pending', () async {
      // Native-armed ids are invisible to the plugin's pending list; the
      // reverse — a plugin one-shot left over from an older build — is only
      // visible there, so both sides must be swept.
      pendingResponse = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': NotificationIds.ayamAlBidhDayBase + 10,
          'title': 'stale',
          'body': 'stale',
          'payload': 'ayam_al_bidh',
        },
        <String, dynamic>{
          'id': NotificationIds.fastingMonday,
          'title': 'unrelated',
          'body': 'unrelated',
          'payload': 'fasting_monday',
        },
      ];

      await NotificationService().cancelAyamAlBidhFasting();

      expect(cancelledIds(), contains(NotificationIds.ayamAlBidhDayBase + 10));
      expect(cancelledIds(), isNot(contains(NotificationIds.fastingMonday)));
    });
  });

  test('cancelAllDailyReminders clears both fasting families', () async {
    SharedPreferences.setMockInitialValues({});

    await NotificationService().cancelAllDailyReminders();

    expect(cancelledIds(), containsAll([
      NotificationIds.fastingMonday,
      NotificationIds.fastingThursday,
    ]));
  });
}
