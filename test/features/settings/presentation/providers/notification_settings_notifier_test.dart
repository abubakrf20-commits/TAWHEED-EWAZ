import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/notification_settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/shared/services/notification_service.dart';
import 'package:tawheeed/shared/models/day_time.dart';
import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

void main() {
  late ProviderContainer container;
  late MockSettingsRepository mockRepo;
  late FakeNotificationService fakeNotif;
  late FakeDailyNotificationScheduler fakeScheduler;
  late FakePrayerTimeService fakePrayer;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepo = MockSettingsRepository()..setMockSettings(const AppSettings());
    fakeNotif = FakeNotificationService();
    fakeScheduler = FakeDailyNotificationScheduler();
    fakePrayer = FakePrayerTimeService();
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      notificationServiceProvider.overrideWithValue(fakeNotif),
      dailyNotificationSchedulerProvider.overrideWithValue(fakeScheduler),
      prayerTimeServiceProvider.overrideWith((ref) => fakePrayer),
    ]);
  });

  tearDown(() => container.dispose());

  test('build mirrors AppSettings from repository', () async {
    final settings = await container.read(notificationSettingsProvider.future);
    expect(settings.prayerNotifMinutes, 5);
    expect(settings.prayerNotifications, isTrue);
  });

  test('toggleAdhkarNotifications(false) recalls the previous pair on re-on',
      () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container
        .read(settingsProvider.notifier)
        .setEveningAzkarNotification(false);

    await notifier.toggleAdhkarNotifications(false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(NotificationSettings.adhkarRecallKey), 'true,false');
    var settings = await container.read(notificationSettingsProvider.future);
    expect(settings.morningAzkarNotification, isFalse);
    expect(settings.eveningAzkarNotification, isFalse);

    await notifier.toggleAdhkarNotifications(true);

    settings = await container.read(notificationSettingsProvider.future);
    expect(settings.morningAzkarNotification, isTrue);
    expect(settings.eveningAzkarNotification, isFalse);
    expect(prefs.getString(NotificationSettings.adhkarRecallKey), isNull);
  });

  test('setAzkarPrayerAnchored clears the manual flag and reschedules',
      () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.azkarMorningManualKey, true);

    await notifier.setAzkarPrayerAnchored(morning: true);

    expect(prefs.getBool(NotificationService.azkarMorningManualKey), isFalse);
    expect(fakeScheduler.forceRescheduleCalls.length, 1);
  });

  test('setFridayReminder persists prefs and re-arms the weekly alarm',
      () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);

    await notifier.setFridayReminder(enabled: true, hour: 8, minute: 30);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.fridayEnabledKey), isTrue);
    expect(prefs.getInt(NotificationService.fridayHourKey), 8);
    expect(prefs.getInt(NotificationService.fridayMinuteKey), 30);
    expect(fakeNotif.countOf('syncFridayReminder'), 1);
  });

  test('setFridayKahfReminder persists prefs and re-arms the Kahf alarm',
      () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);

    await notifier.setFridayKahfReminder(enabled: false, hour: 6, minute: 45);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.fridayKahfEnabledKey), isFalse);
    expect(prefs.getInt(NotificationService.fridayKahfHourKey), 6);
    expect(prefs.getInt(NotificationService.fridayKahfMinuteKey), 45);
    expect(fakeNotif.countOf('syncFridayKahfReminder'), 1);
  });

  test('setFastingMonThu persists the toggle + time and re-syncs with the '
      'user Hijri offset', () async {
    mockRepo.setMockSettings(const AppSettings(hijriOffset: 3));
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);

    await notifier.setFastingMonThu(enabled: true, hour: 5, minute: 40);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.fastingMonThuEnabledKey), isTrue);
    expect(prefs.getInt(NotificationService.fastingMonThuHourKey), 5);
    expect(prefs.getInt(NotificationService.fastingMonThuMinuteKey), 40);
    expect(fakeNotif.calls,
        contains('syncFastingReminders:hijriOffset=3'));
  });

  test('setFastingBidh persists the toggle + time and re-syncs', () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);

    await notifier.setFastingBidh(enabled: false, hour: 6, minute: 20);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.fastingBidhEnabledKey), isFalse);
    expect(prefs.getInt(NotificationService.fastingBidhHourKey), 6);
    expect(prefs.getInt(NotificationService.fastingBidhMinuteKey), 20);
    expect(fakeNotif.countOf('syncFastingReminders'), 1);
  });

  test('disableAllReminders flips the prefs-backed khatm and friday toggles, '
      'and clears every per-prayer adhan flag', () async {
    mockRepo.setMockSettings(const AppSettings(
      azanEnabledForFajr: true,
      azanEnabledForDhuhr: true,
      azanEnabledForAsr: true,
      azanEnabledForMaghrib: true,
      azanEnabledForIsha: true,
    ));
    final before = await container.read(notificationSettingsProvider.future);
    expect(before.anyAzanEnabled, isTrue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.khatmEnabledKey, true);
    await prefs.setBool(NotificationService.fridayEnabledKey, true);
    await prefs.setBool(NotificationService.fastingMonThuEnabledKey, true);
    await prefs.setBool(NotificationService.fastingBidhEnabledKey, true);

    await container
        .read(notificationSettingsProvider.notifier)
        .disableAllReminders();

    expect(prefs.getBool(NotificationService.khatmEnabledKey), isFalse);
    expect(prefs.getBool(NotificationService.fridayEnabledKey), isFalse);
    // Fasting reminders ride the same prefs pattern: a stale `true` here would
    // let the next forceReschedule re-arm them right after «لغو همه».
    expect(prefs.getBool(NotificationService.fastingMonThuEnabledKey), isFalse);
    expect(prefs.getBool(NotificationService.fastingBidhEnabledKey), isFalse);
    expect(fakeNotif.countOf('cancelAll'), 1);

    final after = await container.read(notificationSettingsProvider.future);
    expect(after.anyAzanEnabled, isFalse);
    expect(after.azanEnabledForFajr, isFalse);
    expect(after.azanEnabledForDhuhr, isFalse);
    expect(after.azanEnabledForAsr, isFalse);
    expect(after.azanEnabledForMaghrib, isFalse);
    expect(after.azanEnabledForIsha, isFalse);
    // The five flags persist too, not just the in-memory mirror.
    expect(mockRepo.getMockSettings().anyAzanEnabled, isFalse);
  });

  test('setPostPrayerEnabled(true) rebuilds when it was off', () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.postPrayerEnabledKey, false);

    await notifier.setPostPrayerEnabled(true);

    expect(fakeNotif.countOf('setPostPrayerEnabled:true'), 1);
    expect(fakeScheduler.forceRescheduleCalls.length, 1);
  });

  test('setPostPrayerEnabled(false) cancels the post-prayer queue', () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);

    await notifier.setPostPrayerEnabled(false);

    expect(fakeNotif.countOf('setPostPrayerEnabled:false'), 1);
    expect(fakeNotif.countOf('cancelPostPrayerNotifications'), 1);
    expect(fakeScheduler.forceRescheduleCalls, isEmpty);
  });

  test('rescheduleAll invokes the DailyNotificationScheduler', () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);

    await notifier.rescheduleAll();

    expect(fakeScheduler.forceRescheduleCalls.length, 1);
    expect(fakeNotif.countOf('scheduleMonthlyIslamicEvents'), 1);
  });

  test('setSnooze forwards minutes to the notification service', () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);

    await notifier.setSnooze(const Duration(minutes: 15));

    expect(fakeNotif.countOf('persistSnoozeMinutes:15'), 1);
    expect(fakeNotif.snoozeMinutes, 15);
  });

  test('setAzkarTime persists the manual time + flag and reschedules',
      () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);

    await notifier.setAzkarTime(const DayTime(hour: 7, minute: 45),
        morning: true);

    final settings = await container.read(notificationSettingsProvider.future);
    expect(settings.morningAzkarTime, const DayTime(hour: 7, minute: 45));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.azkarMorningManualKey), isTrue);
    expect(fakeScheduler.forceRescheduleCalls.length, 1);
  });

  test('toggleIslamicEventNotifications(false) cancels event reminders',
      () async {
    await container.read(notificationSettingsProvider.future);
    final notifier = container.read(notificationSettingsProvider.notifier);

    await notifier.toggleIslamicEventNotifications(false);

    expect(fakeNotif.countOf('cancelIslamicEventNotifications'), 1);
    expect(await container.read(islamicEventsEnabledProvider.future), isFalse);
  });
}
