import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/goals/presentation/screens/goal_editor_screen.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_dates.dart';

Future<void> _pumpEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(
    child: MaterialApp(home: GoalEditorScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a deadline preset fills the deadline in one tap',
      (tester) async {
    await _pumpEditor(tester);

    await tester.tap(find.byKey(const ValueKey('goal_deadline_90')));
    await tester.pumpAndSettle();

    // The deadline tile now shows the Jalali date 90 days out instead of «—».
    final expected =
        goalFaDate(goalIsoOf(DateTime.now().add(const Duration(days: 90))));
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('target plus deadline shows the implied daily pace',
      (tester) async {
    await _pumpEditor(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'مقدار هدف (مثلاً 30)'), '90');
    await tester.pumpAndSettle();
    // Nothing to compute until a deadline exists.
    expect(find.textContaining('روزانه حدود'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('goal_deadline_90')));
    await tester.pumpAndSettle();

    // 90 units over 90 days → one a day.
    expect(find.textContaining('روزانه حدود 1'), findsOneWidget);
  });

  testWidgets('a boolean goal hides the meaningless daily target field',
      (tester) async {
    await _pumpEditor(tester);

    expect(
        find.widgetWithText(
            TextField, 'هدف روزانه (اختیاری، مثلاً 1 جز در روز)'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'انجام / نشد'));
    await tester.pumpAndSettle();

    expect(
        find.widgetWithText(
            TextField, 'هدف روزانه (اختیاری، مثلاً 1 جز در روز)'),
        findsNothing);
  });
}
