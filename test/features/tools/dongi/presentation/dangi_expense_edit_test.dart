import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';
import 'package:tawheeed/features/tools/dongi/presentation/screens/dangi_group_screen.dart';

class _FakeDangiNotifier extends DangiNotifier {
  @override
  DangiState build() {
    final t = DateTime(2025, 1, 10);
    return DangiState(
      groups: [
        DangiGroupModel(
          id: 'g1',
          name: 'سفر مشهد',
          colorHex: '#00ACC1',
          createdAt: t,
        ),
      ],
      membersByGroup: {
        'g1': [
          DangiMemberModel(id: 'm1', groupId: 'g1', name: 'علی', createdAt: t),
          DangiMemberModel(id: 'm2', groupId: 'g1', name: 'رضا', createdAt: t),
        ],
      },
      expensesByGroup: {
        'g1': [
          DangiExpenseModel(
            id: 'e1',
            groupId: 'g1',
            payerId: 'm1',
            title: 'شام',
            category: 'food',
            amount: 300,
            date: DateTime(2025, 1, 5),
            createdAt: t,
          ),
        ],
      },
      loaded: true,
    );
  }
}

void main() {
  Widget build() => ProviderScope(
        overrides: [dangiProvider.overrideWith(_FakeDangiNotifier.new)],
        child: const MaterialApp(
          home: DangiGroupScreen(groupId: 'g1'),
        ),
      );

  testWidgets('long-press on an expense opens the prefilled edit sheet',
      (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // The expense tile shows the title.
    expect(find.text('شام'), findsOneWidget);

    await tester.longPress(find.text('شام'));
    await tester.pumpAndSettle();

    // Edit mode UI.
    expect(find.text('ویرایش هزینه'), findsOneWidget);
    expect(find.text('ذخیره تغییرات'), findsOneWidget);
    // Title and amount are prefilled from the expense.
    expect(find.widgetWithText(TextField, 'شام'), findsOneWidget);
    expect(find.widgetWithText(TextField, '300'), findsOneWidget);
    // The payer chip is preselected and the date row shows the expense's
    // Jalali date (2025-01-05 = 16 دی 1403).
    expect(find.text('تاریخ'), findsOneWidget);
    expect(find.text('16 دی 1403'), findsOneWidget);
    // Expense categories are offered.
    expect(find.text('غذا'), findsWidgets);
  });

  testWidgets('category chips carry their icon, not a bare label',
      (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('شام'));
    await tester.pumpAndSettle();

    final foodChip = find.widgetWithText(ChoiceChip, 'غذا');
    expect(foodChip, findsOneWidget);
    expect(
      find.descendant(of: foodChip, matching: find.byIcon(Icons.restaurant)),
      findsOneWidget,
    );
  });

  testWidgets('the edit icon also opens the edit sheet', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ویرایش'));
    await tester.pumpAndSettle();

    expect(find.text('ویرایش هزینه'), findsOneWidget);
    expect(find.text('ذخیره تغییرات'), findsOneWidget);
  });
}
