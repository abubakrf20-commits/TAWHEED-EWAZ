import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_fraction_calculator_tab.dart';

/// End-to-end UI test of the «ماشین حساب کسرها» tab (rebuilt to match the 7
/// tools of almwareeth.com/tools/fraction-farsi): ک.م.م، جمع، تفریق، ضرب،
/// تقسیم، ساده‌سازی و تبدیل به اعشار with space-separated inputs.
void main() {
  Future<void> pumpTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InheritanceFractionCalculatorTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterTool(
    WidgetTester tester,
    int fieldIndex,
    String input,
  ) async {
    final field = find.byType(TextField).at(fieldIndex);
    await tester.ensureVisible(field);
    await tester.enterText(field, input);
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('ک.م.م: 4 6 8 → 24', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 0, '4 6 8');
    await tapButton(tester, 'حساب ک.م.م');

    expect(find.text('ک.م.م(4، 6، 8) = 24'), findsOneWidget);
  });

  testWidgets('جمع: 1/2 1/3 → مخرج مشترک 6 و نتیجه 5/6', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 1, '1/2 1/3');
    await tapButton(tester, 'جمع کن');

    expect(find.textContaining('ک.م.م(2، 3) = 6'), findsOneWidget);
    expect(find.text('3/6 + 2/6 = 5/6'), findsOneWidget); // گام تبدیل
    expect(find.text('5/6'), findsWidgets); // کسر ساده‌شده
    expect(find.text('0.8333'), findsOneWidget); // اعشاری
  });

  testWidgets('جمع سه کسر: 1/2 1/3 1/4 → 13/12 و مخلوط 1 و 1/12',
      (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 1, '1/2 1/3 1/4');
    await tapButton(tester, 'جمع کن');

    expect(find.text('13/12'), findsWidgets);
    expect(find.text('1 و 1/12'), findsOneWidget);
    expect(find.text('1.0833'), findsOneWidget);
  });

  testWidgets('تفریق: 3/4 1/2 → 1/4', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 2, '3/4 1/2');
    await tapButton(tester, 'تفریق کن');

    expect(find.text('3/4 − 2/4 = 1/4'), findsOneWidget);
    expect(find.text('1/4'), findsWidgets);
  });

  testWidgets('ضرب: 2/3 3/4 → 1/2', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 3, '2/3 3/4');
    await tapButton(tester, 'ضرب کن');

    expect(find.text('2/3 × 3/4 = 6/12 = 1/2  (ب.م.م 6)'), findsOneWidget);
    expect(find.text('0.5'), findsOneWidget);
  });

  testWidgets('تقسیم: 3/4 ÷ 1/2 → 3/2 → مخلوط 1 و 1/2', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 4, '3/4 1/2');
    await tapButton(tester, 'تقسیم کن');

    expect(find.text('3/4 ÷ 1/2 = 6/4 = 3/2  (ب.م.م 2)'), findsOneWidget);
    expect(find.text('3/2'), findsWidgets);
    expect(find.text('1 و 1/2'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget);
  });

  testWidgets('ساده‌سازی: 8/12 10/4 → 2/3 و 5/2', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 5, '8/12 10/4');
    await tapButton(tester, 'ساده کن');

    expect(find.textContaining('2/3'), findsWidgets);
    expect(find.textContaining('5/2'), findsWidgets);
    expect(find.textContaining('(ب.م.م 4)'), findsOneWidget); // 8/12
  });

  testWidgets('تبدیل به اعشار: 1/3 3/4 → 0.3333 و 0.75', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 6, '1/3 3/4');
    await tapButton(tester, 'به اعشار تبدیل کن');

    expect(find.text('0.3333'), findsOneWidget);
    expect(find.text('0.75'), findsOneWidget);
  });

  testWidgets('ورودی نامعتبر (مخرج صفر) خطا نشان می‌دهد', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 1, '1/0 1/2');
    await tapButton(tester, 'جمع کن');

    expect(
      find.text('کسرها را با فاصله بنویسید — مثال: 1/3 1/2'),
      findsOneWidget,
    );
  });

  testWidgets('تقسیم بر صفر خطا نشان می‌دهد', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 4, '1/2 0/4');
    await tapButton(tester, 'تقسیم کن');

    expect(find.text('تقسیم بر صفر مجاز نیست.'), findsOneWidget);
  });

  testWidgets('تفریق و تقسیم با یک کسر خطا نشان می‌دهند', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 2, '3/4');
    await tapButton(tester, 'تفریق کن');

    expect(
      find.text('برای «تفریق» دستکم دو کسر بنویسید.'),
      findsOneWidget,
    );
  });
}
