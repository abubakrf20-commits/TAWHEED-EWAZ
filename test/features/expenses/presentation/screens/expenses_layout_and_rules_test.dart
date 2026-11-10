import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository.dart';
import 'package:tawheeed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_provider.dart';
import 'package:tawheeed/features/expenses/presentation/screens/expense_report_screen.dart';
import 'package:tawheeed/features/expenses/presentation/screens/expenses_screen.dart';

/// The ledger's layout rule and the four behaviours its screens promise.
///
/// 1. **It has to fit.** 320 dp is the narrowest phone the app supports and the
///    1.3× text scale is the one the app's own accessibility pass checks. The
///    ledger, the report and the entry sheet all used fixed-width cells in Rows,
///    so a nine-figure amount or a long category pushed them off the card with
///    nothing to show for it but a striped bar. These pump the real screens at
///    that size and fail on any layout exception.
/// 2. **A scheduled row is not a past row.** A transaction dated ahead used to
///    fall through to «گذشته».
/// 3. **A category filter can always be undone.** Deleting the last row of the
///    filtered category used to leave an empty list with the menu hidden.
/// 4. **An edited row does not clone itself.** Making a non-recurring entry
///    recurring used to seed `nextDueDate` with today — which the provider
///    materializes, producing a duplicate at the next launch.
/// 5. **A refused save says why, where it can be read.** The message used to be
///    a SnackBar under the modal sheet.
class _Repo implements ExpenseRepository {
  _Repo([this.items = const []]);
  List<ExpenseModel> items;
  Map<String, double> budgets = const {};

  @override
  Future<List<ExpenseModel>> load() async => List.of(items);
  @override
  Future<void> save(List<ExpenseModel> expenses) async => items = List.of(expenses);
  @override
  Future<void> migrateFromLegacyIfNeeded() async {}
  @override
  Future<Map<String, double>> loadBudgets() async => budgets;
  @override
  Future<void> saveBudget(String category, double monthlyLimit) async {}
  @override
  Future<void> deleteBudget(String category) async {}
}

ExpenseModel _row({
  required String id,
  required String title,
  required double amount,
  String category = 'عمومی',
  bool isIncome = false,
  DateTime? date,
  bool recurring = false,
  String? recurringType,
  DateTime? nextDue,
}) =>
    ExpenseModel(
      id: id,
      title: title,
      amount: amount,
      isIncome: isIncome,
      category: category,
      date: date ?? DateTime.now(),
      isRecurring: recurring,
      recurringType: recurringType,
      nextDueDate: nextDue,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async => call.method == 'setValue'
        ? true
        : call.method == 'getAll'
            ? <String, dynamic>{}
            : null,
  );

  /// Pumps a screen and fails on any error the frame reports.
  ///
  /// The default is 320 dp with the text at 1.3× — the app's narrowest supported
  /// width. The functional tests ask for a roomier width instead: their subject
  /// is a rule, and at 320 dp the horizontal filter row puts some controls out
  /// of reach, which is a scrolling fact, not a bug.
  Future<void> pumpAt320(
    WidgetTester tester,
    _Repo repo,
    Widget screen, {
    double width = 320,
    double scale = 1.3,
  }) async {
    tester.view.physicalSize = Size(width * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 2600),
              textScaler: TextScaler.linear(scale),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: screen,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    FlutterError.onError = previous;
    tester.takeException();
    expect(errors, isEmpty,
        reason: errors.map((e) => e.toString()).join('\n---\n'));
  }

  group('at 320 dp with the text at 1.3×', () {
    final now = DateTime.now();
    final heavy = _Repo([
      _row(
        id: '1',
        title: 'خرید هفتگی خانه و مایحتاج آشپزخانه از بازار',
        amount: 1234567890,
        category: 'حمل و نقل',
        date: now,
        recurring: true,
        recurringType: 'monthly',
        nextDue: now.add(const Duration(days: 30)),
      ),
      _row(
        id: '2',
        title: 'حقوق',
        amount: 9876543210,
        isIncome: true,
        category: 'حقوق',
      ),
    ]..forEach((e) {}));

    testWidgets('the ledger keeps its amount, category and date on the card',
        (tester) async {
      await pumpAt320(tester, heavy, const ExpensesScreen());

      expect(find.text('خرید هفتگی خانه و مایحتاج آشپزخانه از بازار'),
          findsOneWidget);
      expect(find.text('-1,234,567,890'), findsOneWidget);
      expect(find.text('بیشترین هزینه ماه: حمل و نقل'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the report keeps its summary cards', (tester) async {
      await pumpAt320(tester, heavy, const ExpenseReportScreen());

      expect(find.text('درآمد سال'), findsOneWidget);
      expect(find.text('هزینه سال'), findsOneWidget);
      expect(find.text('مانده سال'), findsOneWidget);
      expect(find.text('بودجه ماهانه دسته‌ها'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the entry sheet keeps its date row and its save button',
        (tester) async {
      await pumpAt320(tester, heavy, const ExpensesScreen());
      await tester.tap(find.widgetWithText(FloatingActionButton, 'تراکنش جدید'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ذخیره'));
      await tester.pumpAndSettle();

      expect(find.text('تاریخ تراکنش'), findsOneWidget);
      expect(find.text('ذخیره'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a transaction dated ahead sits under «پیش‌رو», not «گذشته»',
      (tester) async {
    final now = DateTime.now();
    final repo = _Repo([
      _row(id: '1', title: 'قبض برق', amount: 200000, date: now),
      _row(
        id: '2',
        title: 'اجاره آبان',
        amount: 300000,
        category: 'قبض',
        date: now.add(const Duration(days: 12)),
      ),
      _row(
        id: '3',
        title: 'بیمه',
        amount: 100000,
        date: now.subtract(const Duration(days: 40)),
      ),
    ]);

    await pumpAt320(tester, repo, const ExpensesScreen());

    expect(find.text('پیش‌رو'), findsOneWidget);
    expect(find.text('گذشته'), findsOneWidget);
    // Ordering, not just presence: the upcoming row must not be painted under
    // the past heading (which is what happened before this fix).
    expect(
      tester.getTopLeft(find.text('اجاره آبان')).dy,
      lessThan(tester.getTopLeft(find.text('گذشته')).dy),
      reason: 'the future row must be above the past section',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a category filter clears itself when its last row is deleted',
      (tester) async {
    final now = DateTime.now();
    final repo = _Repo([
      _row(id: '1', title: 'قبض برق', amount: 200000, category: 'قبض', date: now),
      _row(id: '2', title: 'بیمه', amount: 100000, date: now),
    ]);

    // Room enough for the whole filter row: the category menu sits after four
    // chips and the count, so on a phone it lives one swipe to the right.
    await pumpAt320(tester, repo, const ExpensesScreen(), width: 800);

    await tester.tap(find.byKey(const ValueKey('expense_category_filter')));
    await tester.pumpAndSettle();
    // The tile behind the overlay carries the same badge text, so the entry is
    // addressed through its own widget rather than by text position.
    await tester.tap(find.byWidgetPredicate(
      (w) => w is PopupMenuItem && w.value == 'قبض',
    ));
    await tester.pumpAndSettle();
    expect(find.text('بیمه'), findsNothing);

    // Delete the only row the filter matches.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    // The filter cannot outlive its category: the list is whole again and the
    // reader is not left staring at «موردی یافت نشد» with no way back.
    expect(find.text('موردی یافت نشد'), findsNothing);
    expect(find.text('بیمه'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('making an existing row recurring keeps its next due date ahead',
      (tester) async {
    final repo = _Repo([
      _row(id: '1', title: 'قبض برق', amount: 200000, category: 'قبض'),
    ]);
    await pumpAt320(tester, repo, const ExpensesScreen(), width: 420);

    await tester.tap(find.text('قبض برق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ماهانه'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ذخیره'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ExpensesScreen)),
    );
    final saved = container.read(expenseListProvider).single;
    expect(saved.isRecurring, isTrue);
    expect(saved.recurringType, 'monthly');
    expect(saved.nextDueDate, isNotNull);
    // Today or earlier is exactly what `_materializeRecurring` turns into a
    // duplicate copy on the next launch.
    expect(saved.nextDueDate!.isAfter(DateTime.now()), isTrue,
        reason: 'a due date of today clones the row on the next load');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused save explains itself inside the sheet',
      (tester) async {
    await pumpAt320(tester, _Repo(), const ExpensesScreen(), width: 420);
    await tester.tap(find.text('افزودن اولین تراکنش'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ذخیره'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    // A SnackBar under the modal sheet is invisible; the message has to be in
    // the sheet, and the sheet has to stay open so it can be corrected.
    expect(find.text('عنوان و مبلغ را وارد کنید.'), findsOneWidget);
    expect(find.text('تاریخ تراکنش'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Typing is the acknowledgement: the message goes away.
    await tester.enterText(find.byType(TextField).at(0), 'نان');
    await tester.pumpAndSettle();
    expect(find.text('عنوان و مبلغ را وارد کنید.'), findsNothing);
  });
}
