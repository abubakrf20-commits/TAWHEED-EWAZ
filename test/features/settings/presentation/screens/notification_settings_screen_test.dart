import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/notification_settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:tawheeed/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show SettingsSwitch;
import 'package:tawheeed/shared/services/notification_service.dart';
import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

const _alarmChannels = [
  'com.tawheeed/alarms',
  'com.tawheeed/prayer_scheduler',
];

void main() {
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
    // «لغو همه» awaits NativePrayerAlarmService().cancelAll(). Without a mock
    // handler the platform reply never lands inside the fake-async zone, so
    // disableAllReminders() would never return and the pref-backed cards would
    // never remount on the bumped cancel-all tick.
    for (final name in _alarmChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
    }
  });

  tearDown(() {
    for (final name in _alarmChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  Widget wrap() => ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
          notificationServiceProvider.overrideWithValue(fakeNotif),
          dailyNotificationSchedulerProvider.overrideWithValue(fakeScheduler),
          prayerTimeServiceProvider.overrideWith((ref) => fakePrayer),
        ],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      );

  Finder switchOf(String title) => find.descendant(
        of: find.widgetWithText(SwitchTile, title),
        matching: find.byType(SettingsSwitch),
      );

  // The screen is a long lazy ListView — use a tall viewport so every section
  // is laid out and reachable without scrolling.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders every notification category in one place',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Section headers
    expect(find.text('اذکار صبح و شب'), findsOneWidget);
    expect(find.text('یادآوری‌های روزانه'), findsOneWidget);
    expect(find.text('یادآوری قرآن'), findsOneWidget);
    expect(find.text('مناسبت‌های اسلامی'), findsOneWidget);
    // Section header + the Friday toggle tile both carry the same label.
    expect(find.text('یادآوری روز جمعه'), findsNWidgets(2));
    expect(find.text('یادآوری روزه‌های مستحب'), findsOneWidget);
    expect(find.text('روزهٔ دوشنبه و پنجشنبه'), findsOneWidget);
    expect(find.text('روزهٔ ایام بیض'), findsOneWidget);

    // Key toggles
    expect(find.text('اذکار صبح'), findsOneWidget);
    expect(find.text('اذکار شب'), findsOneWidget);
    expect(find.text('آیه روز'), findsOneWidget);
    expect(find.text('حدیث روز'), findsOneWidget);
    expect(find.text('دعای روز'), findsOneWidget);
    expect(find.text('لغو همه یادآوری‌ها'), findsOneWidget);

    // Azkar times default to the prayer-anchored mode: the hint explains the
    // 45-min/1-hour offsets and no fixed clock is rendered yet.
    expect(find.text('زمان اذکار صبح'), findsOneWidget);
    expect(find.text('زمان اذکار شب'), findsOneWidget);
    expect(find.text('مبتنی بر اذان'), findsNWidgets(2));
    expect(find.textContaining('پیش‌فرض: 45 دقیقه پس از اذان صبح'),
        findsOneWidget);
    expect(
        find.textContaining('پیش‌فرض: 1 ساعت پس از اذان عصر'), findsOneWidget);
  });

  testWidgets('«ساعت ثابت» shows a picker that follows the 12-hour setting',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('ساعت ثابت').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.azkarMorningManualKey), isTrue);
    // use12Hour defaults to true → «6:00 ق.ظ» rather than the raw «06:00».
    expect(find.text('06:00'), findsNothing);
    expect(find.textContaining('ق.ظ'), findsWidgets);
  });

  testWidgets('«مبتنی بر اذان» clears the manual flag again', (tester) async {
    useTallViewport(tester);
    SharedPreferences.setMockInitialValues({
      NotificationService.azkarMorningManualKey: true,
    });
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('مبتنی بر اذان').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.azkarMorningManualKey), isFalse);
    expect(find.textContaining('پیش‌فرض: 45 دقیقه پس از اذان صبح'),
        findsOneWidget);
  });

  testWidgets('toggling an azkar switch persists and reschedules immediately',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Evening azkar is ON by default → tap to turn OFF.
    await tester.tap(switchOf('اذکار شب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Persisted via the canonical settings repository.
    final saved = await mockRepo.getSettings();
    expect(saved.eveningAzkarNotification, isFalse);
    // And the scheduler was told to reconcile right away.
    expect(fakeScheduler.forceRescheduleCalls.length, 1);
  });

  testWidgets('cancel-all turns every reminder off and cancels notifications',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('لغو همه یادآوری‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خاموش کردن همه'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final saved = await mockRepo.getSettings();
    expect(saved.morningAzkarNotification, isFalse);
    expect(saved.eveningAzkarNotification, isFalse);
    expect(saved.prayerNotifications, isFalse);
    expect(fakeNotif.countOf('cancelAll'), 1);
  });

  testWidgets(
      'cancel-all also switches off the pref-backed Friday and post-prayer cards',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      NotificationService.fridayEnabledKey: true,
      NotificationService.postPrayerEnabledKey: true,
    });
    // The fake reads the same prefs the production service uses, so the card
    // reload after cancel-all observes the keys the notifier just flipped.
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    // Both pref-backed cards start ON.
    expect(tester.widget<SettingsSwitch>(switchOf('یادآوری روز جمعه')).value, isTrue);
    expect(tester.widget<SettingsSwitch>(switchOf('اذکار بعد از نماز')).value, isTrue);

    await tester.tap(find.text('لغو همه یادآوری‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خاموش کردن همه'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The keys outside AppSettings are flipped too — otherwise the next
    // forceReschedule would silently re-enable both reminders.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.fridayEnabledKey), isFalse);
    expect(prefs.getBool(NotificationService.postPrayerEnabledKey), isFalse);

    // Keys flipped — force another frame so watch-based reloads settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.widget<SettingsSwitch>(switchOf('یادآوری روز جمعه')).value, isFalse);
    expect(tester.widget<SettingsSwitch>(switchOf('اذکار بعد از نماز')).value, isFalse);
  });

  testWidgets('fasting cards default to ON at 07:00 with a time row each',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
        tester.widget<SettingsSwitch>(switchOf('روزهٔ دوشنبه و پنجشنبه')).value,
        isTrue);
    expect(tester.widget<SettingsSwitch>(switchOf('روزهٔ ایام بیض')).value,
        isTrue);

    final times = tester.widgetList<TimePickerTile>(find.byType(TimePickerTile));
    // Other sections carry their own «زمان یادآوری» rows (Friday), so scope the
    // lookup to each fasting card.
    TimePickerTile timeUnder(String title) => tester.widget<TimePickerTile>(
          find.descendant(
            of: find.widgetWithText(SettingsCard, title),
            matching: find.byType(TimePickerTile),
          ),
        );
    expect(times.length, greaterThanOrEqualTo(2));
    for (final time in [
      timeUnder('روزهٔ دوشنبه و پنجشنبه').time,
      timeUnder('روزهٔ ایام بیض').time,
    ]) {
      expect(time.hour, NotificationService.defaultFastingHour);
      expect(time.minute, NotificationService.defaultFastingMinute);
    }
    expect(find.text('دوشنبه و پنجشنبه'), findsOneWidget);
    expect(find.text('هر ماه قمری'), findsOneWidget);
  });

  testWidgets('toggling a fasting card persists and re-syncs the reminders',
      (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(switchOf('روزهٔ دوشنبه و پنجشنبه'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.fastingMonThuEnabledKey), isFalse);
    expect(fakeNotif.countOf('syncFastingReminders'), 1);
    // The time row hides with the switch off, leaving the card compact.
    expect(find.text('دوشنبه و پنجشنبه'), findsNothing);
  });

  testWidgets('cancel-all also flips both fasting cards off', (tester) async {
    SharedPreferences.setMockInitialValues({
      NotificationService.fastingMonThuEnabledKey: true,
      NotificationService.fastingBidhEnabledKey: true,
    });
    useTallViewport(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        tester.widget<SettingsSwitch>(switchOf('روزهٔ دوشنبه و پنجشنبه')).value,
        isTrue);
    expect(tester.widget<SettingsSwitch>(switchOf('روزهٔ ایام بیض')).value,
        isTrue);

    await tester.tap(find.text('لغو همه یادآوری‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خاموش کردن همه'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationService.fastingMonThuEnabledKey), isFalse);
    expect(prefs.getBool(NotificationService.fastingBidhEnabledKey), isFalse);

    // The cards remount on the bumped tick and reload the flipped keys.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        tester.widget<SettingsSwitch>(switchOf('روزهٔ دوشنبه و پنجشنبه')).value,
        isFalse);
    expect(tester.widget<SettingsSwitch>(switchOf('روزهٔ ایام بیض')).value,
        isFalse);
  });

  // ── «هر گزینه واقعاً کار میکند؟» ────────────────────────────────────────
  //
  // One page-open per test keeps the fake's call log readable; tapping a switch
  // must both persist the value the switch then shows and hand the change to
  // the notification layer, or the option is decoration.
  group('every reminder option works', () {
    Future<void> openPage(WidgetTester tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(wrap());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    Future<void> tapSwitch(WidgetTester tester, String title) async {
      await tester.tap(switchOf(title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('the Kahf card starts on Friday 06:00 and turns off cleanly',
        (tester) async {
      await openPage(tester);

      expect(tester.widget<SettingsSwitch>(switchOf('یادآوری سوره کهف')).value,
          isTrue);
      // Its own 06:00 row, next to — not inside — the Friday 07:00 reminder.
      final kahfTime = tester.widget<TimePickerTile>(find.descendant(
        of: find.widgetWithText(SettingsCard, 'یادآوری سوره کهف'),
        matching: find.byType(TimePickerTile),
      ));
      expect(kahfTime.time.hour, NotificationService.defaultFridayKahfHour);
      expect(kahfTime.time.minute, NotificationService.defaultFridayKahfMinute);
      expect(kahfTime.note, 'هر جمعه');

      await tapSwitch(tester, 'یادآوری سوره کهف');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationService.fridayKahfEnabledKey), isFalse);
      expect(fakeNotif.countOf('syncFridayKahfReminder'), 1);
      expect(
          tester.widget<SettingsSwitch>(switchOf('یادآوری سوره کهف')).value,
          isFalse);
      // The time row goes with the switch — an inert clock on a cancelled
      // reminder is a promise the app does not keep.
      expect(
          find.descendant(
            of: find.widgetWithText(SettingsCard, 'یادآوری سوره کهف'),
            matching: find.byType(TimePickerTile),
          ),
          findsNothing);

      await tapSwitch(tester, 'یادآوری سوره کهف');
      expect(prefs.getBool(NotificationService.fridayKahfEnabledKey), isTrue);
      expect(fakeNotif.countOf('syncFridayKahfReminder'), 2);
    });

    testWidgets('a new Kahf time is stored and re-armed', (tester) async {
      await openPage(tester);

      await tester.tap(find.descendant(
        of: find.widgetWithText(SettingsCard, 'یادآوری سوره کهف'),
        matching: find.byType(TimePickerTile),
      ));
      await tester.pumpAndSettle();
      expect(find.text('زمان یادآوری'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, '5');
      await tester.enterText(find.byType(TextField).last, '30');
      await tester.tap(find.text('تأیید'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(NotificationService.fridayKahfHourKey), 5);
      expect(prefs.getInt(NotificationService.fridayKahfMinuteKey), 30);
      expect(fakeNotif.countOf('syncFridayKahfReminder'), 1);
      // The row now prints the picked clock instead of the default.
      expect(find.text('5:30 ق.ظ'), findsOneWidget);
    });

    testWidgets('the Friday card keeps its own 07:00 time apart from Kahf',
        (tester) async {
      await openPage(tester);

      final fridayTime = tester.widget<TimePickerTile>(find.descendant(
        of: find.widgetWithText(SettingsCard, 'یادآوری روز جمعه'),
        matching: find.byType(TimePickerTile),
      ));
      expect(fridayTime.time.hour, NotificationService.defaultFridayHour);
      expect(fridayTime.time.minute, NotificationService.defaultFridayMinute);

      await tapSwitch(tester, 'یادآوری روز جمعه');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationService.fridayEnabledKey), isFalse);
      expect(fakeNotif.countOf('syncFridayReminder'), 1);
      // Turning Friday off must not touch the Kahf slot.
      expect(prefs.getBool(NotificationService.fridayKahfEnabledKey), isNull);
      expect(fakeNotif.countOf('syncFridayKahfReminder'), 0);
    });

    testWidgets('each daily content switch persists and forces a reschedule',
        (tester) async {
      await openPage(tester);
      final cases = <String, bool Function(AppSettings)>{
        'آیه روز': (s) => s.dailyVerse,
        'حدیث روز': (s) => s.dailyHadith,
        'دعای روز': (s) => s.dailyDua,
        'یادآوری تلاوت قرآن': (s) => s.quranReminder,
      };
      var expectedReschedules = 0;

      for (final entry in cases.entries) {
        await tapSwitch(tester, entry.key);
        expectedReschedules++;
        final saved = await mockRepo.getSettings();
        // All four default to ON except dua and Quran; the tap flips whichever
        // value the page was showing.
        expect(entry.value(saved),
            entry.key == 'دعای روز' || entry.key == 'یادآوری تلاوت قرآن',
            reason: '${entry.key} did not persist its new value');
        expect(fakeScheduler.forceRescheduleCalls.length, expectedReschedules,
            reason: '${entry.key} did not reschedule');
      }
    });

    testWidgets('the events switch saves its key and cancels or re-arms',
        (tester) async {
      await openPage(tester);

      await tapSwitch(tester, 'یادآوری مناسبت‌ها');
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(islamicEventsEnabledKey), isFalse);
      expect(fakeNotif.countOf('cancelIslamicEventNotifications'), 1);

      await tapSwitch(tester, 'یادآوری مناسبت‌ها');
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(islamicEventsEnabledKey), isTrue);
      expect(fakeNotif.countOf('scheduleMonthlyIslamicEvents'), 1);
    });

    testWidgets('the post-prayer switch cancels its queue when turned off',
        (tester) async {
      await openPage(tester);

      await tapSwitch(tester, 'اذکار بعد از نماز');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationService.postPrayerEnabledKey), isFalse);
      expect(fakeNotif.countOf('cancelPostPrayerNotifications'), 1);
      // Its delay row belongs to the switch.
      expect(find.text('فاصله از اقامه'), findsNothing);
    });

    testWidgets('both fasting cards own their keys and re-sync', (tester) async {
      await openPage(tester);

      await tapSwitch(tester, 'روزهٔ دوشنبه و پنجشنبه');
      await tapSwitch(tester, 'روزهٔ ایام بیض');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationService.fastingMonThuEnabledKey), isFalse);
      expect(prefs.getBool(NotificationService.fastingBidhEnabledKey), isFalse);
      expect(fakeNotif.countOf('syncFastingReminders'), 2);
    });

    testWidgets('the snooze control persists the chosen minutes', (tester) async {
      await openPage(tester);

      await tester.tap(find.text('15 دقیقه'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(fakeNotif.snoozeMinutes, 15);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(NotificationService.snoozeMinutesKey), 15);
    });

    testWidgets('a time row opens the Latin picker and stores the answer',
        (tester) async {
      await openPage(tester);

      await tester.tap(find.text('زمان آیه روز'));
      await tester.pumpAndSettle();

      // Latin digits, never the Persian ones a Material dial would print.
      await tester.enterText(find.byType(TextField).first, '4');
      await tester.enterText(find.byType(TextField).last, '45');
      await tester.tap(find.text('تأیید'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final saved = await mockRepo.getSettings();
      expect(saved.dailyVerseTime.hour, 4);
      expect(saved.dailyVerseTime.minute, 45);
      expect(fakeScheduler.forceRescheduleCalls, isNotEmpty);
    });
  });
}
