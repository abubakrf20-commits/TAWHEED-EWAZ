import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/services/islamic_events_service.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';
import 'package:tawheeed/shared/services/daily_notification_scheduler.dart';
import 'package:tawheeed/shared/services/notification_service.dart';

/// Hand-written test fakes for the notification infrastructure.
///
/// These replace the mockito `NiceMock`s that used to live in
/// `notification_settings_notifier_test.mocks.dart` (1320 generated lines):
/// every member the production paths actually touch is implemented with
/// recordable behavior; anything unexpected throws loudly with the member
/// name instead of silently returning null.
class FakeNotificationService implements NotificationService {
  /// One entry per call, `memberName` or `memberName:arg` for simple args.
  final calls = <String>[];

  int countOf(String member) =>
      calls.where((c) => c == member || c.startsWith('$member:')).length;

  /// Mirrors the real service: a public mutable field persisted on write.
  @override
  int snoozeMinutes = 10;

  @override
  Future<bool> postPrayerEnabled() async {
    calls.add('postPrayerEnabled');
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(NotificationService.postPrayerEnabledKey) ?? true;
  }

  @override
  Future<int> postPrayerDelayMinutes() async {
    calls.add('postPrayerDelayMinutes');
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(NotificationService.postPrayerDelayKey) ??
            NotificationService.defaultPostPrayerDelay)
        .clamp(0, 120);
  }

  @override
  Future<void> setPostPrayerEnabled(bool value) async {
    calls.add('setPostPrayerEnabled:$value');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.postPrayerEnabledKey, value);
  }

  @override
  Future<void> persistPostPrayerDelay(int minutes) async {
    calls.add('persistPostPrayerDelay:$minutes');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(NotificationService.postPrayerDelayKey, minutes);
  }

  @override
  Future<void> persistSnoozeMinutes(int minutes) async {
    calls.add('persistSnoozeMinutes:$minutes');
    snoozeMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(NotificationService.snoozeMinutesKey, minutes);
  }

  @override
  Future<bool> isAzkarManual({required bool morning}) async {
    calls.add('isAzkarManual:morning=$morning');
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(morning
            ? NotificationService.azkarMorningManualKey
            : NotificationService.azkarEveningManualKey) ??
        false;
  }

  @override
  Future<void> cancelPostPrayerNotifications() async {
    calls.add('cancelPostPrayerNotifications');
  }

  @override
  Future<void> cancelAllPrayerRelated() async {
    calls.add('cancelAllPrayerRelated');
  }

  @override
  Future<void> cancelIslamicEventNotifications() async {
    calls.add('cancelIslamicEventNotifications');
  }

  @override
  Future<void> scheduleMonthlyIslamicEvents(
    List<IslamicEventOccurrence> events, {
    int daysBefore = 3,
    int hour = 9,
  }) async {
    calls.add('scheduleMonthlyIslamicEvents');
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancelAll');
  }

  @override
  Future<void> scheduleTestAdhan({
    String azanSound = 'kamel',
    String? customAzanPath,
  }) async {
    calls.add('scheduleTestAdhan:$azanSound:${customAzanPath ?? ''}');
  }

  @override
  Future<void> syncFridayReminder() async {
    calls.add('syncFridayReminder');
  }

  @override
  Future<void> syncFridayKahfReminder() async {
    calls.add('syncFridayKahfReminder');
  }

  @override
  Future<void> syncFastingReminders({int hijriOffset = 2}) async {
    calls.add('syncFastingReminders:hijriOffset=$hijriOffset');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    throw UnimplementedError(
        'FakeNotificationService: unstubbed member $name — '
        'add it to the fake so the test records real behavior.');
  }
}

class FakeDailyNotificationScheduler implements DailyNotificationScheduler {
  final forceRescheduleCalls =
      <({PrayerTimeService prayerService, AppSettings settings})>[];

  /// Every [scheduleIfNeeded] call, in order — the settings notifier's debounced
  /// reschedule side effect lands here.
  final scheduleIfNeededCalls = <AppSettings>[];

  @override
  Future<void> scheduleIfNeeded({
    required PrayerTimeService prayerService,
    required AppSettings settings,
  }) async {
    scheduleIfNeededCalls.add(settings);
  }

  @override
  Future<void> forceReschedule({
    required PrayerTimeService prayerService,
    required AppSettings settings,
    SettingsWriter? writer,
  }) async {
    forceRescheduleCalls
        .add((prayerService: prayerService, settings: settings));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    throw UnimplementedError(
        'FakeDailyNotificationScheduler: unstubbed member $name — '
        'add it to the fake so the test records real behavior.');
  }
}

/// Pure pass-through: [forceReschedule] never touches it in these tests, and
/// any unexpected member call fails loudly with its name.
class FakePrayerTimeService implements PrayerTimeService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    throw UnimplementedError('FakePrayerTimeService: unstubbed member $name — '
        'add it to the fake so the test records real behavior.');
  }
}
