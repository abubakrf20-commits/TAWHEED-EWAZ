import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/presentation/screens/battery_optimization_screen.dart';

/// Section 8.20 audit: the screen must render every OEM guide and must sort
/// the user's own manufacturer first (Audit 4.7) — a fix that regressed to a
/// compile-time const probe would break the second test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.tawheeed/settings');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String> visibleTexts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();

  void useTallSurface(WidgetTester tester) {
    // The list is lazy — a viewport tall enough to build every section,
    // so index-based order assertions see the whole guide.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders every brand guide and the general steps',
      (tester) async {
    useTallSurface(tester);
    // No channel mock: deviceManufacturer fails, the guide keeps the
    // declared order and nothing crashes.
    await tester
        .pumpWidget(const MaterialApp(home: BatteryOptimizationScreen()));
    await tester.pumpAndSettle();

    final texts = visibleTexts(tester);
    expect(texts, contains('بررسی خودکار وضعیت گوشی'));
    expect(texts, contains('باز کردن تنظیمات باتری گوشی'));
    expect(texts.indexOf('سامسونگ (Samsung)'),
        lessThan(texts.indexOf('شیائومی (Xiaomi)')));
    expect(texts.indexOf('شیائومی (Xiaomi)'),
        lessThan(texts.indexOf('هواوی (Huawei)')));
  });

  testWidgets('the detected manufacturer guide sorts first (Audit 4.7)',
      (tester) async {
    useTallSurface(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'deviceManufacturer') return 'XIAOMI';
      return null;
    });
    await tester
        .pumpWidget(const MaterialApp(home: BatteryOptimizationScreen()));
    await tester.pumpAndSettle();

    final texts = visibleTexts(tester);
    final mi = texts.indexOf('شیائومی (Xiaomi)');
    expect(mi, isNonNegative);
    expect(mi, lessThan(texts.indexOf('سامسونگ (Samsung)')));
    expect(mi, lessThan(texts.indexOf('هواوی (Huawei)')));
  });

  void mockBatteryStatus(Object? Function() answer) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermission' &&
          (call.arguments as Map?)?['permission'] == 'batteryOptimization') {
        return answer();
      }
      if (call.method == 'deviceManufacturer') return 'samsung';
      return null;
    });
  }

  testWidgets('A-05: a restricted app sees the warning and the system action',
      (tester) async {
    useTallSurface(tester);
    mockBatteryStatus(() => false);
    await tester
        .pumpWidget(const MaterialApp(home: BatteryOptimizationScreen()));
    await tester.pumpAndSettle();

    final texts = visibleTexts(tester);
    expect(texts, contains('توحید در فهرست بهینه‌سازی باتری نیست'));
    expect(texts, contains('باز کردن فهرست بهینه‌سازی باتری'));
    expect(texts, isNot(contains('بهینه‌سازی باتری غیرفعال است')));
  });

  testWidgets('A-05: an exempt app sees the confirmation, not the warning',
      (tester) async {
    useTallSurface(tester);
    mockBatteryStatus(() => true);
    await tester
        .pumpWidget(const MaterialApp(home: BatteryOptimizationScreen()));
    await tester.pumpAndSettle();

    final texts = visibleTexts(tester);
    expect(texts, contains('بهینه‌سازی باتری غیرفعال است'));
    expect(texts, isNot(contains('توحید در فهرست بهینه‌سازی باتری نیست')));
    expect(texts, isNot(contains('باز کردن فهرست بهینه‌سازی باتری')));
  });

  testWidgets('A-05: a failed probe makes no claim either way', (tester) async {
    useTallSurface(tester);
    mockBatteryStatus(
        () => throw PlatformException(code: 'unavailable'));
    await tester
        .pumpWidget(const MaterialApp(home: BatteryOptimizationScreen()));
    await tester.pumpAndSettle();

    final texts = visibleTexts(tester);
    expect(texts, isNot(contains('بهینه‌سازی باتری غیرفعال است')));
    expect(texts, isNot(contains('توحید در فهرست بهینه‌سازی باتری نیست')));
    // The always-present controls still render.
    expect(texts, contains('باز کردن تنظیمات باتری گوشی'));
  });
}
