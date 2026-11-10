import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_infra_providers.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/settings/presentation/screens/notification_diagnostics_screen.dart';

import '../../../../core/database/mock_daos.dart';
import '../fake_notification_infra.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.tawheeed/settings');

  void mockSettings({
    required bool notifications,
    required bool exactAlarm,
    required bool battery,
    required bool dnd,
    bool location = true,
    bool gps = true,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermission') {
        final perm = call.arguments['permission'] as String;
        return switch (perm) {
          'notifications' => notifications,
          'exactAlarm' => exactAlarm,
          'batteryOptimization' => battery,
          'dnd' => dnd,
          'location' => location,
          _ => gps, // checkGpsEnabled falls through here too
        };
      }
      if (call.method == 'checkGpsEnabled') return gps;
      return true;
    });
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    // ConsumerState needs a scope; no overrides — these tests never tap rows
    // that read providers.
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: NotificationDiagnosticsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows ready summary when every check passes', (tester) async {
    mockSettings(
        notifications: true, exactAlarm: true, battery: true, dnd: true);
    await pumpScreen(tester);

    expect(find.text('همه‌چیز مرتب است'), findsOneWidget);
    expect(find.text('اعلان‌ها'), findsOneWidget);
    expect(find.text('هشدار دقیق'), findsOneWidget);
    expect(find.text('بهینه‌سازی باتری'), findsOneWidget);
    expect(find.text('رژیم مزاحم نشو (اختیاری)'), findsOneWidget);
    // No fix buttons when everything is granted.
    expect(find.text('رفع'), findsNothing);
    expect(find.text('فعال‌سازی'), findsNothing);
  });

  testWidgets('reports failing checks and offers fix actions', (tester) async {
    mockSettings(
        notifications: false, exactAlarm: false, battery: false, dnd: false);
    await pumpScreen(tester);

    // location/gps default to granted; the 4 explicitly-false checks fail,
    // but DND is optional so only 3 count as blocking.
    expect(find.text('3 مورد نیاز به بررسی دارد'), findsOneWidget);
    expect(find.text('رفع'), findsNWidgets(2)); // exact alarm + battery
    expect(find.text('فعال‌سازی'), findsNWidgets(2)); // notifications + dnd
    // location/gps are granted, so they show no fix button.
  });

  testWidgets('optional DND failure alone counts as a warning item',
      (tester) async {
    mockSettings(
        notifications: true, exactAlarm: true, battery: true, dnd: false);
    await pumpScreen(tester);

    expect(find.text('1 مورد اختیاری برای بررسی است'), findsOneWidget);
    expect(find.text('فعال‌سازی'), findsOneWidget);
    expect(find.text('رفع'), findsNothing);
  });

  testWidgets('pull of the refresh action re-runs the checks', (tester) async {
    mockSettings(
        notifications: false, exactAlarm: false, battery: false, dnd: false);
    await pumpScreen(tester);
    expect(find.text('3 مورد نیاز به بررسی دارد'), findsOneWidget);

    // User fixes everything in system settings and returns.
    mockSettings(
        notifications: true, exactAlarm: true, battery: true, dnd: true);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('همه‌چیز مرتب است'), findsOneWidget);
    expect(find.text('۴ مورد نیاز به بررسی دارد'), findsNothing);
  });

  testWidgets('surfaces an armed-reminders section', (tester) async {
    // The populated list is Android-only (armedReminders reads the native
    // channel); on the test host it resolves to empty, which must still
    // render the section rather than throw. The on-device populated view is
    // covered by the reliability doc + manual test.
    mockSettings(
        notifications: true, exactAlarm: true, battery: true, dnd: true);
    await pumpScreen(tester);

    // The card lives below six check rows in a lazy ListView, so it is not
    // built until scrolled into view.
    await tester.scrollUntilVisible(
      find.text('هشدارهای زمان‌بندی‌شده'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('هشدارهای زمان‌بندی‌شده'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
    expect(find.textContaining('هیچ هشداری'), findsOneWidget);
  });

  testWidgets('test-adhan row schedules with the configured sound',
      (tester) async {
    mockSettings(
        notifications: true, exactAlarm: true, battery: true, dnd: true);
    SharedPreferences.setMockInitialValues({});
    final repo = MockSettingsRepository()
      ..setMockSettings(const AppSettings());
    final fake = FakeNotificationService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(fake),
          settingsRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: const MaterialApp(home: NotificationDiagnosticsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('تست اعلان اذان'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('تست اعلان اذان'));
    await tester.pumpAndSettle();

    // The bare default ('kamel') would prove the row ignores the picker.
    expect(
      fake.calls.any((c) => c == 'scheduleTestAdhan:takbir:'),
      isTrue,
    );
  });
}
