import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/presentation/widgets/evaluation_reset_dialog.dart';

/// A page with one button that opens the confirmation, so the dialog can be
/// driven without mounting the whole evaluation tab.
///
/// The answer lands in a [ValueNotifier] rather than a local: the button's
/// callback is async, so the value is only written after the dialog route pops —
/// reading a captured local right after `pumpAndSettle` would always see null.
Future<ValueNotifier<bool?>> _mount(
  WidgetTester tester, {
  required int days,
  required int points,
  required int bestStreak,
  EvaluationResetScope scope = EvaluationResetScope.daily,
  String rangeLabel = 'امروز',
}) async {
  final answer = ValueNotifier<bool?>(null);
  addTearDown(answer.dispose);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              answer.value = await confirmEvaluationReset(
                context,
                scope: scope,
                rangeLabel: rangeLabel,
                days: days,
                points: points,
                bestStreak: bestStreak,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return answer;
}

void main() {
  testWidgets('states what is lost, in the reader\'s own numbers',
      (tester) async {
    await _mount(tester, days: 12, points: 340, bestStreak: 5);

    expect(find.text('ریست ارزیابی روزانه؟'), findsOneWidget);
    // The counts, not adjectives: a reader deciding about their history needs to
    // see it.
    expect(find.textContaining('12 روز امتیاز ثبت‌شده'), findsOneWidget);
    expect(find.textContaining('340 امتیاز'), findsOneWidget);
    expect(find.textContaining('بهترین رشتهٔ داخل بازه: 5 روز'), findsOneWidget);
  });

  testWidgets('names the range it is about to clear', (tester) async {
    await _mount(
      tester,
      scope: EvaluationResetScope.monthly,
      rangeLabel: 'آبان 1405',
      days: 3,
      points: 90,
      bestStreak: 2,
    );

    expect(find.text('ریست ارزیابی ماهانه؟'), findsOneWidget);
    expect(find.textContaining('ارزیابی این بازه پاک می‌شود: آبان 1405'),
        findsOneWidget);
  });

  testWidgets('says what is kept, and that only the range goes',
      (tester) async {
    await _mount(tester, days: 3, points: 90, bestStreak: 2);

    // The reader's real fear is losing more than the range — the lifetime
    // tasbih total, the period records, the other days — so the dialog says
    // explicitly that only this range zeroes.
    expect(find.textContaining('این‌ها دست‌نخورده می‌مانند'), findsOneWidget);
    expect(find.textContaining('مجموع کل تسبیح'), findsOneWidget);
    expect(find.textContaining('هر روز بیرون از این بازه'), findsOneWidget);
  });

  testWidgets('tells the reader about the temporary undo backup', (tester) async {
    await _mount(tester, days: 3, points: 90, bestStreak: 2);

    // Since 2026-11-05 a reset writes a temporary backup that the snackbar's
    // «بازگردانی» action restores, so the old «برگشت‌پذیر نیست» warning would
    // now be a lie (unit 5 audit, E04).
    expect(find.textContaining('بازگردانی'), findsOneWidget);
  });

  testWidgets('a fresh range gets copy that does not invent history',
      (tester) async {
    // Zero days must not read as «0 روز امتیاز ثبت‌شده» — that is a sentence
    // about a history that does not exist.
    await _mount(tester, days: 0, points: 0, bestStreak: 0);

    expect(find.textContaining('هیچ روز امتیازداری ثبت نشده'), findsOneWidget);
    expect(find.textContaining('رشته‌ای برای پاک شدن در این بازه نیست'),
        findsOneWidget);
  });

  testWidgets('cancel answers false', (tester) async {
    final answer = await _mount(tester, days: 3, points: 90, bestStreak: 2);

    await tester.tap(find.byKey(const ValueKey('evaluation_reset_cancel')));
    await tester.pumpAndSettle();

    expect(find.text('ریست ارزیابی روزانه؟'), findsNothing);
    expect(answer.value, isFalse);
  });

  testWidgets('confirm answers true', (tester) async {
    final answer = await _mount(tester, days: 3, points: 90, bestStreak: 2);

    await tester.tap(find.byKey(const ValueKey('evaluation_reset_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('ریست ارزیابی روزانه؟'), findsNothing);
    expect(answer.value, isTrue);
  });

  testWidgets('the confirming button is the destructive one', (tester) async {
    await _mount(tester, days: 3, points: 90, bestStreak: 2);

    final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey('evaluation_reset_confirm')));
    final cancel = tester.widget<TextButton>(
        find.byKey(const ValueKey('evaluation_reset_cancel')));

    // The safe choice is a text button; the irreversible one is filled and
    // tinted. Reversing that would put the heavier target under the reader's
    // thumb.
    expect(confirm.style?.backgroundColor, isNotNull);
    expect(cancel.style?.backgroundColor, isNull);
    expect(find.text('ریست کن'), findsOneWidget);
    expect(find.text('انصراف'), findsOneWidget);
  });
}
