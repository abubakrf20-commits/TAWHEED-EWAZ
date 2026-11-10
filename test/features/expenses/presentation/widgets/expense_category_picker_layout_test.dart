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

/// The picker inside a bottom sheet, at the narrowest width the app supports and
/// with the text size setting turned up.
///
/// WHY this exists separately from the behaviour tests: the picker is a `Wrap`
/// inside a sheet, and a chip row is the kind of thing that fits at 412 dp and
/// overflows at 320 dp with the scale at 1.3 — which is a shipped configuration,
/// not a hypothetical. A `RenderFlex` overflow throws inside a widget test, so
/// `takeException()` being null *is* the assertion.
class _Repo implements ExpenseRepository {
  _Repo({this.items = const []});
  List<ExpenseModel> items;

  @override
  Future<List<ExpenseModel>> load() async => List.of(items);
  @override
  Future<void> save(List<ExpenseModel> expenses) async => items = List.of(expenses);
  @override
  Future<void> migrateFromLegacyIfNeeded() async {}
  @override
  Future<Map<String, double>> loadBudgets() async => const {};
  @override
  Future<void> saveBudget(String category, double monthlyLimit) async {}
  @override
  Future<void> deleteBudget(String category) async {}
}

Future<void> _pump(
  WidgetTester tester, {
  required Size logicalSize,
  double scale = 1.3,
  String value = kDefaultExpenseCategory,
  List<ExpenseModel> rows = const [],
}) async {
  tester.view.physicalSize = Size(logicalSize.width * 3, logicalSize.height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [expenseRepositoryProvider.overrideWithValue(_Repo(items: rows))],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: logicalSize,
            textScaler: TextScaler.linear(scale),
          ),
          // The real home is a bottom sheet: constrained width, own scroll view.
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: logicalSize.width,
                child: ExpenseCategoryPicker(
                  value: value,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('320 dp at scale 1.3 lays out the built-ins without overflow',
      (tester) async {
    await _pump(tester, logicalSize: const Size(320, 640));

    expect(tester.takeException(), isNull);
    // The add affordance is reachable — it is the whole point of the change.
    expect(find.byKey(const ValueKey('expense_category_add')), findsOneWidget);
    final add = tester.getRect(find.byKey(const ValueKey('expense_category_add')));
    expect(add.right, lessThanOrEqualTo(320.5));
  });

  testWidgets('a name at the length limit still wraps inside 320 dp',
      (tester) async {
    // The longest name the rules allow, in a chip, at the largest scale.
    final longest = 'ا' * kMaxExpenseCategoryLength;
    SharedPreferences.setMockInitialValues({
      kCustomExpenseCategoriesPref: [longest],
    });
    await _pump(tester, logicalSize: const Size(320, 640));

    expect(tester.takeException(), isNull);
    final chip = tester.getRect(find.byKey(ValueKey('expense_category_$longest')));
    expect(chip.right, lessThanOrEqualTo(320.5));
    expect(chip.left, greaterThanOrEqualTo(-0.5));
  });

  testWidgets('the inline field fits beside its two buttons at 320 dp',
      (tester) async {
    await _pump(tester, logicalSize: const Size(320, 640));

    await tester.tap(find.byKey(const ValueKey('expense_category_add')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final field = tester.getRect(find.byKey(const ValueKey('expense_category_field')));
    expect(field.right, lessThanOrEqualTo(320.5));
    // Two icon buttons beside it must stay on screen rather than being squeezed
    // to zero width by the expanded field.
    expect(find.byKey(const ValueKey('expense_category_submit')), findsOneWidget);
    expect(find.byKey(const ValueKey('expense_category_cancel')), findsOneWidget);
    final submit = tester.getRect(find.byKey(const ValueKey('expense_category_submit')));
    expect(submit.width, greaterThan(30));
  });

  testWidgets('a validation error does not push the chips off the sheet',
      (tester) async {
    await _pump(tester, logicalSize: const Size(320, 640));

    await tester.tap(find.byKey(const ValueKey('expense_category_add')));
    await tester.pumpAndSettle();
    // Empty submit, then a duplicate: the second message is the long one, and it
    // is the one that used to be able to grow the field without bound.
    await tester.tap(find.byKey(const ValueKey('expense_category_submit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.enterText(
        find.byKey(const ValueKey('expense_category_field')), 'خوراک');
    await tester.tap(find.byKey(const ValueKey('expense_category_submit')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('از قبل وجود دارد'), findsOneWidget);
  });
}
