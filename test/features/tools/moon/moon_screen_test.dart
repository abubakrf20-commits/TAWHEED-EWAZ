import 'package:flutter/material.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/tools/moon/presentation/screens/moon_screen.dart';

class _FakeLocalNotificationsPlatform
    extends FlutterLocalNotificationsPlatform {}

class _FakeSettings extends Settings {
  @override
  Future<AppSettings> build() async =>
      const AppSettings(manualLat: 35.6892, manualLng: 51.389);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance =
        _FakeLocalNotificationsPlatform();
  });

  testWidgets('تب هلال — پنل استهلال رندر میشود و بدون خطاست', (tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_FakeSettings.new)],
        child: const MaterialApp(home: MoonScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'هلال'));
    await tester.pumpAndSettle();

    // پنل استهلال
    expect(find.text('پارامترهای رصدی'), findsOneWidget);
    expect(find.text('معیارهای علمی'), findsOneWidget);
    expect(find.textContaining('یالوپ'), findsAtLeastNWidgets(1));
    expect(find.textContaining('عوده (ICOP)'), findsAtLeastNWidgets(1));
    expect(find.textContaining('بروین'), findsAtLeastNWidgets(1));
    expect(find.textContaining('دانژون'), findsAtLeastNWidgets(1));

    // بخش پیشبینی و مقایسه
    expect(find.textContaining('قمری'), findsAtLeastNWidgets(1));
    expect(find.textContaining('مقایسه'), findsAtLeastNWidgets(1));

    // تعویض مبنا
    await tester.tap(find.widgetWithText(ChoiceChip, 'اقتران نجومی'));
    await tester.pumpAndSettle();
    expect(find.textContaining('قمری'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('تب امروز — تفاوت تاریخ نجومی و تقویم توضیح داده شده',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_FakeSettings.new)],
        child: const MaterialApp(home: MoonScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // تب پیش‌فرض «امروز» است؛ کارت نجومی باید بگوید ملاک مناسبت‌ها تقویم
    // است تا اختلاف یک‌روزه با بخش تقویم تعریف‌شده باشد، نه باگ.
    expect(find.text('ماه هجری (نجومی)'), findsOneWidget);
    expect(find.textContaining('ملاک مناسبت‌ها همان تقویم است'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('تب هلال — سوئیچ اعلان مقدار ذخیره‌شده را نشان می‌دهد',
      (tester) async {
    // The switch used to start «off» for everyone. It is now gated on the
    // stored value: the row must end up ON for a user who enabled the alert,
    // and the gate must open even if the read fails.
    SharedPreferences.setMockInitialValues(
        {'hilal_notification_enabled': true});
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_FakeSettings.new)],
        child: const MaterialApp(home: MoonScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'هلال'));
    await tester.pumpAndSettle();

    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isTrue, reason: 'the stored value must be honoured');
    expect(sw.onChanged, isNotNull,
        reason: 'the switch must not stay inert after the read lands');
    expect(tester.takeException(), isNull);
  });
}
