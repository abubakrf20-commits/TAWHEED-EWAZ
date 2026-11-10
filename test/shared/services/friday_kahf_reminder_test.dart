import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Guards the two weekly Friday reminders — «آداب روز جمعه» (07:00) and the
/// independent «سوره کهف» (06:00).
///
/// The page had no test proving they reach the scheduler at all: a toggle can
/// persist a key and still arm nothing. On the test host `Platform.isAndroid`
/// is false, so every schedule lands on the plugin channel and the armed id,
/// channel, time and repeat rule are all observable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <({String method, Map<String, Object?> args})>[];

  setUp(() {
    tzdata.initializeTimeZones();
    calls.clear();
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
      if (call.method == 'pendingNotificationRequests') return <Object?>[];
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<Map<String, Object?>> schedules() =>
      calls.where((c) => c.method == 'zonedSchedule').map((c) => c.args).toList();

  List<int> scheduledIds() =>
      schedules().map((a) => a['id'] as int).toList();

  List<int> cancelledIds() => calls
      .where((c) => c.method == 'cancel')
      .map((c) => c.args['id'] as int)
      .toList();

  Map<String, Object?> scheduleOf(int id) =>
      schedules().singleWhere((a) => a['id'] == id);

  DateTime fireTimeOf(Map<String, Object?> schedule) =>
      DateTime.parse(schedule['scheduledDateTime'] as String);

  /// The Android channel rides inside `platformSpecifics` (the plugin packs
  /// the whole AndroidNotificationDetails map there).
  Object? channelOf(Map<String, Object?> schedule) =>
      (schedule['platformSpecifics'] as Map?)?['channelId'];

  group('سوره کهف', () {
    test('arms its own Friday slot, one week apart from the Friday reminder',
        () async {
      SharedPreferences.setMockInitialValues({});

      await NotificationService()
          .scheduleFridayKahfReminder(time: const TimeOfDay(hour: 6, minute: 0));

      final armed = scheduleOf(NotificationIds.fridayKahf);
      expect(armed['title'], 'سوره کهف — جمعه');
      expect(armed['payload'], 'friday_kahf');
      expect(channelOf(armed), 'friday_kahf_v1');
      // Weekly repeat: the native path re-arms on the same weekday.
      expect(armed['matchDateTimeComponents'],
          DateTimeComponents.dayOfWeekAndTime.index);

      final at = fireTimeOf(armed);
      expect(at.weekday, DateTime.friday);
      expect([at.hour, at.minute], [6, 0]);
      expect(at.isAfter(DateTime.now()), isTrue);
      expect(at.difference(DateTime.now()).inDays, lessThanOrEqualTo(7));

      // Replace, never stack: the same id is purged before arming.
      expect(cancelledIds(), contains(NotificationIds.fridayKahf));
      // 406 is the Kahf slot on its own — it must not borrow the Friday or the
      // khatm id, which is how the two reminders used to cancel each other.
      expect(NotificationIds.fridayKahf, isNot(NotificationIds.fridayReminder));
      expect(NotificationIds.fridayKahf, isNot(NotificationIds.khatmReminder));
    });

    test('sync defaults to on at 06:00', () async {
      SharedPreferences.setMockInitialValues({});

      await NotificationService().syncFridayKahfReminder();

      final at = fireTimeOf(scheduleOf(NotificationIds.fridayKahf));
      expect([at.hour, at.minute], [
        NotificationService.defaultFridayKahfHour,
        NotificationService.defaultFridayKahfMinute,
      ]);
    });

    test('honours the stored time', () async {
      SharedPreferences.setMockInitialValues({
        NotificationService.fridayKahfHourKey: 5,
        NotificationService.fridayKahfMinuteKey: 30,
      });

      await NotificationService().syncFridayKahfReminder();

      final at = fireTimeOf(scheduleOf(NotificationIds.fridayKahf));
      expect([at.hour, at.minute], [5, 30]);
    });

    test('off cancels the slot and arms nothing', () async {
      SharedPreferences.setMockInitialValues({
        NotificationService.fridayKahfEnabledKey: false,
      });

      await NotificationService().syncFridayKahfReminder();

      expect(scheduledIds(), isEmpty);
      expect(cancelledIds(), [NotificationIds.fridayKahf]);
    });
  });

  group('the Friday pair together', () {
    test('both are armed by the daily sync, at their own times', () async {
      SharedPreferences.setMockInitialValues({});

      await NotificationService()
          .scheduleDailyRemindersFromSettings(const AppSettings());

      final friday = scheduleOf(NotificationIds.fridayReminder);
      final kahf = scheduleOf(NotificationIds.fridayKahf);
      expect(channelOf(friday), 'friday_reminder_v3');
      expect(channelOf(kahf), 'friday_kahf_v1');

      final fridayAt = fireTimeOf(friday);
      final kahfAt = fireTimeOf(kahf);
      expect(fridayAt.weekday, DateTime.friday);
      expect(kahfAt.weekday, DateTime.friday);
      expect(fridayAt.hour, NotificationService.defaultFridayHour);
      expect(kahfAt.hour, NotificationService.defaultFridayKahfHour);
      expect(fridayAt, isNot(kahfAt));
    });

    test('turning the Friday reminder off leaves the Kahf slot armed', () async {
      SharedPreferences.setMockInitialValues({
        NotificationService.fridayEnabledKey: false,
      });

      await NotificationService()
          .scheduleDailyRemindersFromSettings(const AppSettings());

      expect(scheduledIds(), contains(NotificationIds.fridayKahf));
      expect(cancelledIds(), contains(NotificationIds.fridayReminder));
    });

    test('cancel-all sweeps both weekly slots', () async {
      await NotificationService().cancelAllDailyReminders();

      expect(cancelledIds(), containsAll([
        NotificationIds.fridayReminder,
        NotificationIds.fridayKahf,
        NotificationIds.fastingMonday,
        NotificationIds.fastingThursday,
      ]));
    });
  });
}
