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

class _SheetHost extends ConsumerWidget {
  const _SheetHost({required this.members, this.expense});

  final List<DangiMemberModel> members;
  final DangiExpenseModel? expense;

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

  final members = [
    for (var i = 1; i <= 2; i++)
      DangiMemberModel(
          id: 'm$i', groupId: 'g1', name: 'نفر $i', createdAt: t),
  ];

  DangiExpenseModel expenseWith({String title = '', String amount = ''}) =>
      DangiExpenseModel(
        id: 'e1',
        groupId: 'g1',
        payerId: 'm1',
        title: title.isEmpty ? 'شام' : title,
        category: 'food',
        amount: amount.isEmpty ? 300 : double.parse(amount),
        date: DateTime(2025, 1, 5),
        createdAt: t,
      );

  Future<void> openSheet(
    WidgetTester tester, {
    required List<DangiMemberModel> sheetMembers,
    DangiExpenseModel? expense,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [dangiProvider.overrideWith(_FakeDangiNotifier.new)],
      child: MaterialApp(
        home: _SheetHost(members: sheetMembers, expense: expense),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Clears a field and leaves the caret there.
  Future<void> clearAndType(WidgetTester tester, String hint, String value) async {
    // TextFormField exposes `decoration` only as a constructor argument, but it
// builds a TextField internally — so match on that, like the layout test does.
final field = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
  }

  testWidgets('an empty title blocks save and shows an inline hint',
      (tester) async {
    await openSheet(tester,
        sheetMembers: members, expense: expenseWith(amount: '250'));

    // Wipe the title, then press save.
    await clearAndType(tester, 'مثلاً شام رستوران', '');
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();

    expect(find.text('عنوان هزینه را وارد کنید'), findsOneWidget);
    // The sheet stays open instead of saving an invalid expense.
    expect(find.text('ویرایش هزینه'), findsOneWidget);
  });

  testWidgets('a non-positive or unparseable amount is rejected', (tester) async {
    await openSheet(tester,
        sheetMembers: members, expense: expenseWith(amount: '250'));

    await clearAndType(tester, 'مثلاً 250000', '0');
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();
    expect(find.text('مبلغ باید بزرگ‌تر از صفر باشد'), findsOneWidget);

    // Letters cannot reach the field at all any more — `LatinGroupingFormatter`
    // keeps only digits, so the amount the PARSER can still refuse is a lone
    // separator, which must not be read as zero.
    await clearAndType(tester, 'مثلاً 250000', '.');
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();
    expect(find.text('مبلغ باید عدد باشد'), findsOneWidget);
  });

  testWidgets('a missing payer is called out only after a failed save',
      (tester) async {
    // No expense given => the payer chip defaults to the first member, so
    // build a sheet whose payer cannot be resolved.
    await tester.pumpWidget(ProviderScope(
      overrides: [dangiProvider.overrideWith(_FakeDangiNotifier.new)],
      child: const MaterialApp(home: _SheetHost(members: [])),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // No hint is shown before the user presses save.
    expect(find.text('پرداخت‌کننده را انتخاب کنید'), findsNothing);
  });

  testWidgets('a valid form saves and closes the sheet', (tester) async {
    await openSheet(tester,
        sheetMembers: members, expense: expenseWith(amount: '250'));

    // Nothing is flagged for a well-formed expense, and the sheet closes.
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();

    expect(find.text('عنوان هزینه را وارد کنید'), findsNothing);
    expect(find.text('مبلغ را وارد کنید'), findsNothing);
    expect(find.text('پرداخت‌کننده را انتخاب کنید'), findsNothing);
  });
}