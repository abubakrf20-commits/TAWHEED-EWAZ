import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';
import 'package:tawheeed/features/tools/dongi/presentation/screens/dangi_report_screen.dart';

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
          DangiExpenseModel(
            id: 'e2',
            groupId: 'g1',
            payerId: 'm2',
            title: 'بنزین',
            category: 'transport',
            amount: 150,
            date: DateTime(2025, 1, 4),
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
          home: DangiReportScreen(groupId: 'g1'),
        ),
      );

  testWidgets('renders total and expense rows grouped by date', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    expect(find.text('گزارش و تاریخچهٔ هزینه‌ها'), findsOneWidget);
    expect(find.text('مجموع هزینه‌ها'), findsOneWidget);
    expect(find.text('شام'), findsOneWidget);
    expect(find.text('بنزین'), findsOneWidget);
    // Category labels appear inside the date rows.
    expect(find.textContaining('غذا'), findsWidgets);
    expect(find.textContaining('حمل و نقل'), findsWidgets);
  });

  testWidgets('switching to the category tab shows category totals',
      (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('تفکیک دسته'));
    await tester.pumpAndSettle();

    // Category cards with totals.
    expect(find.text('غذا'), findsWidgets);
    expect(find.text('حمل و نقل'), findsWidgets);
    expect(find.textContaining('مورد'), findsNWidgets(2));
    // Progress bars exist (one per category card).
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });

  testWidgets('member tab shows per-member paid/consumed/net stats',
      (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('تفکیک اعضا'));
    await tester.pumpAndSettle();

    // One summary card per member.
    expect(find.text('علی'), findsOneWidget);
    expect(find.text('رضا'), findsOneWidget);
    // Paying عili 300 / رضا 150 shared equally → علی consumed 225, net +75.
    expect(find.text('+75'), findsOneWidget);
    // Each card carries the three mini-stats.
    expect(find.text('پرداختی'), findsNWidgets(2));
    expect(find.text('مانده'), findsNWidgets(2));
  });
}
