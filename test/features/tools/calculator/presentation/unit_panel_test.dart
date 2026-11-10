import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/tools/calculator/presentation/widgets/calculator_tool_panels.dart';

void main() {
  setUp(() {
    // The panel now remembers its category/bases/recents via prefs (audit
    // P2-B-UNITS); tests run with an empty store.
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap() => const MaterialApp(
        home: Scaffold(
          body: UnitPanel(accent: Colors.teal),
        ),
      );

  Future<void> convert(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField), value);
    await tester.ensureVisible(find.text('تبدیل'));
    await tester.tap(find.text('تبدیل'));
    await tester.pumpAndSettle();
  }

  testWidgets('default length: 1000 meters = 1 kilometer', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await convert(tester, '1000');
    expect(find.textContaining('1000 متر = 1 کیلومتر'), findsOneWidget);
  });

  testWidgets('volume category: 2 liters = 2000 milliliters', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('حجم'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'حجم'));
    await tester.pumpAndSettle();

    // پس از انتخاب دسته، پیش‌فرض لیتر → میلی‌لیتر است
    await convert(tester, '2');
    expect(find.textContaining('2 لیتر = 2000 میلی‌لیتر'), findsOneWidget);
  });

  testWidgets('time category: 1 hour = 60 minutes', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('زمان'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'زمان'));
    await tester.pumpAndSettle();

    await convert(tester, '1');
    expect(find.textContaining('1 ساعت = 60 دقیقه'), findsOneWidget);
  });

  testWidgets('data category: 1 gigabyte = 1024 megabytes', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('داده'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'داده'));
    await tester.pumpAndSettle();

    await convert(tester, '1');
    expect(find.textContaining('1 گیگابایت = 1024 مگابایت'), findsOneWidget);
  });

  testWidgets('invalid input shows error message', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await convert(tester, 'abc');
    expect(
        find.textContaining('لطفاً مقدار را درست وارد کنید'), findsOneWidget);
  });
}
