import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/calculator/presentation/widgets/calculator_tool_panels.dart';

void main() {
  Widget wrap() => const MaterialApp(
        home: Scaffold(
          body: QardHasanPanel(accent: Colors.teal),
        ),
      );

  testWidgets(
      'entering amount and months shows even installments with no interest',
      (tester) async {
    await tester.pumpWidget(wrap());

    // مبلغ ۱۲٬۰۰۰٬۰۰۰ در ۱۲ ماه → قسط ماهانه ۱٬۰۰۰٬۰۰۰
    await tester.enterText(find.byType(TextField).at(0), '12000000');
    await tester.enterText(find.byType(TextField).at(1), '12');

    await tester.ensureVisible(find.text('محاسبه'));
    await tester.tap(find.text('محاسبه'));
    await tester.pumpAndSettle();

    expect(find.textContaining('قسط ماهانه'), findsOneWidget);
    expect(find.textContaining('تعداد قسط'), findsOneWidget);
    expect(find.textContaining('بازپرداخت کل'), findsOneWidget);
    expect(find.textContaining('سود پرداختی'), findsOneWidget);
    expect(find.textContaining('1,000,000'), findsOneWidget);
  });

  testWidgets('invalid input shows error message', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byType(TextField).at(0), '0');
    await tester.enterText(find.byType(TextField).at(1), '12');

    await tester.ensureVisible(find.text('محاسبه'));
    await tester.tap(find.text('محاسبه'));
    await tester.pumpAndSettle();

    expect(find.textContaining('لطفاً مقادیر'), findsOneWidget);
  });

  testWidgets('shows interest-free note and no rate field', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.textContaining('قرض الحسنه'), findsWidgets);
    expect(find.textContaining('ربا'), findsNothing);
    expect(find.text('نرخ سود سالانه (٪)'), findsNothing);
  });
}
