import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

/// The prayer page's steppers write on every tap. Without a debounce a burst of
/// taps enqueues one full notification reconciliation per tap (and the iqamah
/// setters each await the scheduler), which on a low-end device is a visible
/// stutter. The notifier must coalesce a burst into ONE reschedule that carries
/// the LAST value.
///
/// These are widget tests rather than plain tests so the notifier's debounce
/// timer runs inside the test binding's fake clock — `tester.pump(duration)`
/// advances it deterministically without a second async helper package.
void main() {
  late MockSettingsRepository mockRepo;
  late FakeDailyNotificationScheduler scheduler;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockSettingsRepository()..setMockSettings(const AppSettings());
    SharedPreferences.setMockInitialValues({});
    scheduler = FakeDailyNotificationScheduler();
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) async => mockRepo),
      dailyNotificationSchedulerProvider.overrideWithValue(scheduler),
      prayerTimeServiceProvider.overrideWith((ref) => FakePrayerTimeService()),
    ]);
    addTearDown(container.dispose);
  });

  Future<Settings> load(WidgetTester tester) async {
    container.listen(settingsProvider, (_, __) {}, fireImmediately: true);
    final notifier = container.read(settingsProvider.notifier);
    await tester.pump();
    expect(container.read(settingsProvider).hasValue, isTrue,
        reason: 'settings must load before a write can be coalesced');
    return notifier;
  }

  testWidgets('a burst of iqamah stepper writes yields a single reschedule',
      (tester) async {
    final notifier = await load(tester);

    // Five taps inside the debounce window, exactly as a stepper drag emits
    // them — each write cancels the previous pending reschedule.
    for (final value in [1, 2, 3, 4, 9]) {
      unawaited(notifier.setIqamahOffsetFajr(value));
      await tester.pump();
    }
    expect(scheduler.scheduleIfNeededCalls, isEmpty,
        reason: 'nothing should reach the scheduler inside the window');

    await tester.pump(const Duration(milliseconds: 400));

    expect(scheduler.scheduleIfNeededCalls.length, 1,
        reason: 'the burst collapses into one reschedule');
    expect(scheduler.scheduleIfNeededCalls.single.iqamahOffsetFajr, 9,
        reason: 'the last value in the burst wins');
  });

  testWidgets('writes separated by more than the window reschedule separately',
      (tester) async {
    final notifier = await load(tester);

    unawaited(notifier.setIqamahOffsetFajr(5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    unawaited(notifier.setGlobalPrayerOffset(-3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(scheduler.scheduleIfNeededCalls.length, 2);
    expect(scheduler.scheduleIfNeededCalls.last.globalPrayerOffset, -3);
  });

  testWidgets('every per-prayer adhan shift reschedules', (tester) async {
    final notifier = await load(tester);

    // Each per-prayer shift must reach the scheduler (reminders, native
    // adhan alarms and the widget payload all ride the shifted time), even
    // while that prayer's adhan playback is off.
    unawaited(notifier.setFajrOffset(-5));
    unawaited(notifier.setDhuhrOffset(2));
    unawaited(notifier.setAsrOffset(1));
    unawaited(notifier.setMaghribOffset(4));
    unawaited(notifier.setIshaOffset(-1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(scheduler.scheduleIfNeededCalls.length, 1,
        reason: 'the burst collapses into one reschedule');
    final s = scheduler.scheduleIfNeededCalls.single;
    expect(s.fajrOffset, -5);
    expect(s.dhuhrOffset, 2);
    expect(s.asrOffset, 1);
    expect(s.maghribOffset, 4);
    expect(s.ishaOffset, -1);
  });
}
