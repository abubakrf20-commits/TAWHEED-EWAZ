import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';
import 'package:tawheeed/features/tools/dongi/presentation/widgets/dangi_form_sheets.dart';

class _FakeDangiNotifier extends DangiNotifier {
  @override
  DangiState build() => const DangiState();
}

/// Opens the expense sheet directly, independent of the group screen layout.
class _SheetHost extends ConsumerWidget {
  const _SheetHost({required this.members, required this.expense});

  final List<DangiMemberModel> members;
  final DangiExpenseModel expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showDangiExpenseSheet(
            context,
            ref,
            'g1',
            members,
            expense: expense,
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  final t = DateTime(2025, 1, 10);

  List<DangiMemberModel> membersOf(int n) => [
        for (var i = 1; i <= n; i++)
          DangiMemberModel(
              id: 'm$i', groupId: 'g1', name: 'نفر $i', createdAt: t),
      ];

  DangiExpenseModel expenseWith({Map<String, double> consumers = const {}}) =>
      DangiExpenseModel(
        id: 'e1',
        groupId: 'g1',
        payerId: 'm1',
        title: 'شام',
        category: 'food',
        amount: 300,
        date: DateTime(2025, 1, 5),
        createdAt: t,
        consumers: consumers,
      );

  Future<void> openSheet(
    WidgetTester tester, {
    required List<DangiMemberModel> members,
    required DangiExpenseModel expense,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [dangiProvider.overrideWith(_FakeDangiNotifier.new)],
      child: MaterialApp(
        home: _SheetHost(members: members, expense: expense),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش هزینه'), findsOneWidget);
  }

  /// The three fixed rows a phone-sized sheet must show without scrolling.
  Finder saveLabel() => find.text('ذخیره تغییرات');
  Finder dateLabel() => find.text('تاریخ');
  Finder splitLabel() => find.text('تقسیم هزینه');

  testWidgets(
      'the default form fits a 360x780 phone with the save button on screen',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0; // 360x780 logical
    addTearDown(tester.view.reset);

    await openSheet(tester,
        members: membersOf(3), expense: expenseWith());

    // The date row and the save button are both fully inside the viewport,
    // so the form does not open with its primary action pushed off screen.
    expect(tester.getRect(dateLabel()).bottom, lessThanOrEqualTo(780.5));
    final save = tester.getRect(saveLabel());
    expect(save.bottom, lessThanOrEqualTo(780.5));
    expect(save.top, greaterThanOrEqualTo(0.0));

    // Category chips are compact (about 26px, not the old ~48px rows).
    final chip = tester.getRect(find.widgetWithText(ChoiceChip, 'غذا'));
    expect(chip.height, lessThan(34));

    // No dead band between the category chips and the split section: the
    // section header sits right below the chips.
    final categoryWrap = tester.getRect(
      find.ancestor(of: find.text('غذا'), matching: find.byType(Wrap)),
    );
    expect(tester.getRect(splitLabel()).top - categoryWrap.bottom, lessThan(30));
  });

  testWidgets(
      'activating consumers keeps the save button pinned and the fields near the switch',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openSheet(tester,
        members: membersOf(8), expense: expenseWith());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final switchRect = tester.getRect(find.byType(Switch));
    final firstField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0');
    expect(firstField, findsNWidgets(8));
    expect(tester.getRect(firstField.first).top - switchRect.bottom,
        lessThan(60));

    // The primary action stays reachable even when the member list is long.
    expect(tester.getRect(saveLabel()).bottom, lessThanOrEqualTo(780.5));
  });

  testWidgets('the split summary tracks the running total live',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final consumerField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0');

    await openSheet(
      tester,
      members: membersOf(3),
      expense: expenseWith(consumers: {'m1': 100, 'm2': 200}),
    );

    // 100 + 200 == 300, the expense total.
    expect(find.textContaining('برابر است'), findsOneWidget);

    // Lower a share: 50 + 200 = 250 leaves 50 unassigned.
    await tester.enterText(consumerField.first, '50');
    await tester.pumpAndSettle();
    expect(find.textContaining('باقی مانده'), findsOneWidget);
    expect(find.textContaining('برابر است'), findsNothing);

    // Overshoot the total instead.
    await tester.enterText(consumerField.first, '400');
    await tester.pumpAndSettle();
    expect(find.textContaining('بیشتر از مبلغ خرج'), findsOneWidget);
  });
}
