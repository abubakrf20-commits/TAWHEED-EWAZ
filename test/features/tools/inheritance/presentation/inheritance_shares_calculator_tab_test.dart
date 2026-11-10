import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_shares_calculator_tab.dart';

/// End-to-end UI test of the «ماشین حساب سهام» tab: أصل المسألة، سهام كل
/// فرض، عول/ردّ and optional estate amounts.
void main() {
  Future<void> pumpTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 9000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InheritanceSharesCalculatorTab(),
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
    await tester.ensureVisible(find.text(label).last);
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('اصل مسأله و سهام: 1/2 1/6 1/3 → اصل 6 سهام [3،1،2]',
      (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 0, '1/2 1/6 1/3');
    await tapButton(tester, 'حساب سهام');

    expect(find.text('اصل مسأله = ک.م.م(2، 6، 3) = 6'), findsOneWidget);
    expect(find.text('سهام: 3'), findsOneWidget);
    expect(find.text('سهام: 1'), findsOneWidget);
    expect(find.text('سهام: 2'), findsOneWidget);
    expect(find.text('مجموع سهام'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
    expect(find.text('عادی'), findsOneWidget);
    expect(find.textContaining('اصل تصحیح‌شده = 6'), findsOneWidget);
  });

  testWidgets('عول: 1/2 2/3 → مجموع 7 بیش از اصل 6', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 0, '1/2 2/3');
    await tapButton(tester, 'حساب سهام');

    expect(find.text('اصل مسأله = ک.م.م(2، 3) = 6'), findsOneWidget);
    expect(find.text('سهام: 3'), findsOneWidget);
    expect(find.text('سهام: 4'), findsOneWidget);
    expect(find.text('عول'), findsOneWidget);
    expect(find.textContaining('اصل تصحیح‌شده = 7'), findsOneWidget);
    expect(find.textContaining('عول:'), findsWidgets);
  });

  testWidgets('ردّ: 1/2 1/6 → مجموع 4 کمتر از اصل 6', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 0, '1/2 1/6');
    await tapButton(tester, 'حساب سهام');

    expect(find.text('اصل مسأله = ک.م.م(2، 6) = 6'), findsOneWidget);
    expect(find.text('سهام: 3'), findsOneWidget);
    expect(find.text('سهام: 1'), findsOneWidget);
    expect(find.text('ردّ'), findsOneWidget);
    expect(find.textContaining('اصل تصحیح‌شده = 6'), findsOneWidget);
    expect(find.textContaining('ردّ:'), findsWidgets);
  });

  testWidgets('با مبلغ ترکه، سهم هر فرض به تومان حساب می‌شود', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 0, '1/2 1/3');
    await enterTool(tester, 1, '6000');
    await tapButton(tester, 'حساب سهام');

    // هر دو فرض سهم‌هایشان مبلغ دارند: 6000×3/5 و 6000×2/5
    expect(find.textContaining('مبلغ:'), findsNWidgets(2));
    expect(find.textContaining('اصل تصحیح‌شده = 6'), findsOneWidget);
  });

  testWidgets('ورودی نادرست خطا نشان می‌دهد', (tester) async {
    await pumpTab(tester);
    await enterTool(tester, 0, '1/2 3/0');
    await tapButton(tester, 'حساب سهام');
    expect(find.text('فرض‌ها را با فاصله بنویسید — مثال: 1/2 1/6 1/3'),
        findsOneWidget);
  });
}
