import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/domain/expense_categories.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_categories_provider.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expense_category_picker.dart';

class _MockRepo implements ExpenseRepository {
  _MockRepo({this.items = const []});

  List<ExpenseModel> items;

  @override
  Future<List<ExpenseModel>> load() async => List.of(items);

  @override
  Future<void> save(List<ExpenseModel> expenses) async {
    items = List.of(expenses);
  }

  @override
  Future<void> migrateFromLegacyIfNeeded() async {}

  @override
  Future<Map<String, double>> loadBudgets() async => const {};

  @override
  Future<void> saveBudget(String category, double monthlyLimit) async {}

  @override
  Future<void> deleteBudget(String category) async {}
}

/// A store whose write always fails, so the inline failure can be reached.
class _FailingStore extends ExpenseCategoryStoreNotifier {
  @override
  Future<void> persist(ExpenseCategoryStore store) async {
    throw StateError('disk full');
  }
}

/// Mounts the picker with [value] selected and records every change.
Future<List<String>> _mount(
  WidgetTester tester, {
  String value = kDefaultExpenseCategory,
  List<ExpenseModel> rows = const [],
  ExpenseCategoryStoreNotifier Function()? store,
}) async {
  final changes = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(_MockRepo(items: rows)),
        if (store != null) expenseCategoryStoreProvider.overrideWith(store),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExpenseCategoryPicker(
              value: value,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return changes;
}

ExpenseModel _row(String category, {String id = 'a'}) => ExpenseModel(
      id: id,
      title: 'خرید',
      amount: 1000,
      category: category,
      date: DateTime(2026, 10, 9),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('offers the built-ins and a way to add one', (tester) async {
    await _mount(tester);

    for (final c in kBuiltInExpenseCategories) {
      expect(find.text(c), findsOneWidget, reason: 'missing chip for $c');
    }
    expect(find.byKey(const ValueKey('expense_category_add')), findsOneWidget);
    expect(find.text('دستهٔ جدید'), findsOneWidget);
  });

  testWidgets('a category the vocabulary dropped still shows as a chip',
      (tester) async {
    // The reader removed «قهوه», but a row still carries it: opening that row
    // must show what its category is, not a row of unselected chips.
    await _mount(tester, value: 'قهوه');

    expect(find.byKey(const ValueKey('expense_category_قهوه')), findsOneWidget);
  });

  testWidgets('tapping the add chip opens a field, cancelling closes it',
      (tester) async {
    await _mount(tester);

    expect(find.byKey(const ValueKey('expense_category_field')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('expense_category_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expense_category_field')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('expense_category_cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expense_category_field')), findsNothing);
  });

  testWidgets('a new category is added, selected and written down',
      (tester) async {
    final changes = await _mount(tester);

    await tester.tap(find.byKey(const ValueKey('expense_category_add')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('expense_category_field')), 'قهوه');
    await tester.tap(find.byKey(const ValueKey('expense_category_submit')));
    await tester.pumpAndSettle();

    // It is offered, it is the selection, and the dialog was told.
    expect(find.byKey(const ValueKey('expense_category_قهوه')), findsOneWidget);
    expect(changes, ['قهوه']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(kCustomExpenseCategoriesPref), ['قهوه']);
  });

  testWidgets('an empty name is refused with a reason', (tester) async {
    final changes = await _mount(tester);

    await tester.tap(find.byKey(const ValueKey('expense_category_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('expense_category_submit')));
    await tester.pumpAndSettle();

    expect(find.text('نام دسته را وارد کنید.'), findsOneWidget);
    expect(changes, isEmpty);
  });

  testWidgets('a duplicate is refused and the existing chip is selected',
      (tester) async {
    final changes = await _mount(tester);

    await tester.tap(find.byKey(const ValueKey('expense_category_add')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('expense_category_field')), 'خوراک');
    await tester.tap(find.byKey(const ValueKey('expense_category_submit')));
    await tester.pumpAndSettle();

    expect(find.text('این دسته از قبل وجود دارد؛ «خوراک» انتخاب شد.'),
        findsOneWidget);
    // Corrected rather than merely refused: the reader typed a name that exists.
    expect(changes, ['خوراک']);
  });

  testWidgets('the remove affordance appears on custom chips only',
      (tester) async {
    await _mount(tester);

    await tester.tap(find.byKey(const ValueKey('expense_category_add')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('expense_category_field')), 'قهوه');
    await tester.tap(find.byKey(const ValueKey('expense_category_submit')));
    await tester.pumpAndSettle();

    // Drawn on the user's own chip whether or not it is selected — selecting a
    // chip changes the transaction's category, so it must not be a step on the
    // way to deleting one.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('expense_category_قهوه')),
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('expense_category_خوراک')),
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('removing an unused category asks, then takes it out',
      (tester) async {
    await _mount(tester);

    await tester.tap(find.byKey(const ValueKey('expense_category_add')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('expense_category_field')), 'قهوه');
    await tester.tap(find.byKey(const ValueKey('expense_category_submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('expense_category_قهوه')),
      matching: find.byIcon(Icons.close_rounded),
    ));
    await tester.pumpAndSettle();
    expect(find.text('حذف دستهٔ «قهوه»؟'), findsOneWidget);
    expect(find.textContaining('هیچ تراکنشی'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('expense_category_قهوه')), findsNothing);
  });

  testWidgets('removing a category in use says what happens to its rows',
      (tester) async {
    // Seeded rather than typed: typing «قهوه» would be refused as a duplicate,
    // because the rows already put it in the vocabulary. The case under test is a
    // category the user added earlier and has since spent against.
    SharedPreferences.setMockInitialValues({
      kCustomExpenseCategoriesPref: ['قهوه'],
    });
    await _mount(tester, rows: [
      _row('قهوه'),
      _row('قهوه', id: 'b'),
    ]);

    expect(find.byKey(const ValueKey('expense_category_قهوه')), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('expense_category_قهوه')),
      matching: find.byIcon(Icons.close_rounded),
    ));
    await tester.pumpAndSettle();

    // The question has to mention the rows and promise their label is untouched,
    // because that is the thing a reader would fear.
    expect(find.textContaining('2 تراکنش'), findsOneWidget);
    expect(find.textContaining('برچسبشان عوض نمی‌شود'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'حذف'));
    await tester.pumpAndSettle();

    // Gone from the picker, and it stays gone: without the hidden list the
    // in-use pass would put it straight back on the next rebuild.
    expect(find.byKey(const ValueKey('expense_category_قهوه')), findsNothing);
  });

  testWidgets('a failed write is said inline, with a retry', (tester) async {
    final changes = await _mount(tester, store: _FailingStore.new);

    await tester.tap(find.byKey(const ValueKey('expense_category_add')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('expense_category_field')), 'قهوه');
    await tester.tap(find.byKey(const ValueKey('expense_category_submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('ذخیره نشد'), findsOneWidget);
    expect(find.byKey(const ValueKey('expense_category_retry')), findsOneWidget);
    // The chip must not appear: a category that exists on screen and not on disk
    // is gone after the next launch, and the reader would have believed it.
    expect(find.byKey(const ValueKey('expense_category_قهوه')), findsNothing);
    // The selection is put back too. It was moved to the new name before the
    // write (so a save tapped mid-flight cannot record the old category), and a
    // failed write must not leave the dialog pointing at a name it does not have.
    expect(changes, ['قهوه', kDefaultExpenseCategory]);
  });
}
