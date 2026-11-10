// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(totalBalance)
final totalBalanceProvider = TotalBalanceProvider._();

final class TotalBalanceProvider
    extends $FunctionalProvider<double, double, double> with $Provider<double> {
  TotalBalanceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'totalBalanceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$totalBalanceHash();

  @$internal
  @override
  $ProviderElement<double> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  double create(Ref ref) {
    return totalBalance(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$totalBalanceHash() => r'cfc4565da5a9d8293b91e092e7922c5975dd1cda';

/// Expenses of one Jalali month. (The old Gregorian `month` filter compared
/// `date.month` against a Jalali month number, silently dropping
/// Esfand/Farvardin cross-year rows — the report screen groups by
/// [Jalali.fromDateTime], so this provider does the same.)

@ProviderFor(expensesInJalaliMonth)
final expensesInJalaliMonthProvider = ExpensesInJalaliMonthFamily._();

/// Expenses of one Jalali month. (The old Gregorian `month` filter compared
/// `date.month` against a Jalali month number, silently dropping
/// Esfand/Farvardin cross-year rows — the report screen groups by
/// [Jalali.fromDateTime], so this provider does the same.)

final class ExpensesInJalaliMonthProvider extends $FunctionalProvider<
    List<ExpenseModel>,
    List<ExpenseModel>,
    List<ExpenseModel>> with $Provider<List<ExpenseModel>> {
  /// Expenses of one Jalali month. (The old Gregorian `month` filter compared
  /// `date.month` against a Jalali month number, silently dropping
  /// Esfand/Farvardin cross-year rows — the report screen groups by
  /// [Jalali.fromDateTime], so this provider does the same.)
  ExpensesInJalaliMonthProvider._(
      {required ExpensesInJalaliMonthFamily super.from,
      required ({
        int month,
        int year,
      })
          super.argument})
      : super(
          retry: null,
          name: r'expensesInJalaliMonthProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$expensesInJalaliMonthHash();

  @override
  String toString() {
    return r'expensesInJalaliMonthProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<ExpenseModel>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<ExpenseModel> create(Ref ref) {
    final argument = this.argument as ({
      int month,
      int year,
    });
    return expensesInJalaliMonth(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ExpenseModel> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ExpenseModel>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExpensesInJalaliMonthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expensesInJalaliMonthHash() =>
    r'ba2cbf0a4854e6f68b34c312d260e59212b2ffa2';

/// Expenses of one Jalali month. (The old Gregorian `month` filter compared
/// `date.month` against a Jalali month number, silently dropping
/// Esfand/Farvardin cross-year rows — the report screen groups by
/// [Jalali.fromDateTime], so this provider does the same.)

final class ExpensesInJalaliMonthFamily extends $Family
    with
        $FunctionalFamilyOverride<
            List<ExpenseModel>,
            ({
              int month,
              int year,
            })> {
  ExpensesInJalaliMonthFamily._()
      : super(
          retry: null,
          name: r'expensesInJalaliMonthProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Expenses of one Jalali month. (The old Gregorian `month` filter compared
  /// `date.month` against a Jalali month number, silently dropping
  /// Esfand/Farvardin cross-year rows — the report screen groups by
  /// [Jalali.fromDateTime], so this provider does the same.)

  ExpensesInJalaliMonthProvider call(
    ({
      int month,
      int year,
    }) ym,
  ) =>
      ExpensesInJalaliMonthProvider._(argument: ym, from: this);

  @override
  String toString() => r'expensesInJalaliMonthProvider';
}

@ProviderFor(ExpenseList)
final expenseListProvider = ExpenseListProvider._();

final class ExpenseListProvider
    extends $NotifierProvider<ExpenseList, List<ExpenseModel>> {
  ExpenseListProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'expenseListProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$expenseListHash();

  @$internal
  @override
  ExpenseList create() => ExpenseList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ExpenseModel> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ExpenseModel>>(value),
    );
  }
}

String _$expenseListHash() => r'60caebeeea290104e90ca65f7b59a754d26b8ccb';

abstract class _$ExpenseList extends $Notifier<List<ExpenseModel>> {
  List<ExpenseModel> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<ExpenseModel>, List<ExpenseModel>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<ExpenseModel>, List<ExpenseModel>>,
        List<ExpenseModel>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// Per-category budget status for the current Jalali month, combining the
/// configured budgets with this month's actual spending (expenses only —
/// income is excluded).
///
/// Keyed by category. Categories that have spending but no configured budget
/// are also present, with an infinite limit, so the UI can show them as
/// "unlimited" instead of dropping them.

@ProviderFor(budgetStatus)
final budgetStatusProvider = BudgetStatusProvider._();

/// Per-category budget status for the current Jalali month, combining the
/// configured budgets with this month's actual spending (expenses only —
/// income is excluded).
///
/// Keyed by category. Categories that have spending but no configured budget
/// are also present, with an infinite limit, so the UI can show them as
/// "unlimited" instead of dropping them.

final class BudgetStatusProvider extends $FunctionalProvider<
        Map<
            String,
            ({
              double limit,
              bool over,
              double spent,
            })>,
        Map<
            String,
            ({
              double limit,
              bool over,
              double spent,
            })>,
        Map<
            String,
            ({
              double limit,
              bool over,
              double spent,
            })>>
    with
        $Provider<
            Map<
                String,
                ({
                  double limit,
                  bool over,
                  double spent,
                })>> {
  /// Per-category budget status for the current Jalali month, combining the
  /// configured budgets with this month's actual spending (expenses only —
  /// income is excluded).
  ///
  /// Keyed by category. Categories that have spending but no configured budget
  /// are also present, with an infinite limit, so the UI can show them as
  /// "unlimited" instead of dropping them.
  BudgetStatusProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'budgetStatusProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$budgetStatusHash();

  @$internal
  @override
  $ProviderElement<
      Map<
          String,
          ({
            double limit,
            bool over,
            double spent,
          })>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<
      String,
      ({
        double limit,
        bool over,
        double spent,
      })> create(Ref ref) {
    return budgetStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
      Map<
              String,
              ({
                double limit,
                bool over,
                double spent,
              })>
          value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<
          Map<
              String,
              ({
                double limit,
                bool over,
                double spent,
              })>>(value),
    );
  }
}

String _$budgetStatusHash() => r'd5804e429e7cbe83b0aab3671a8068e21adc1cd5';

/// Monthly budget per category («محدودیت بودجه برای هر دسته»).

@ProviderFor(ExpenseBudget)
final expenseBudgetProvider = ExpenseBudgetProvider._();

/// Monthly budget per category («محدودیت بودجه برای هر دسته»).
final class ExpenseBudgetProvider
    extends $NotifierProvider<ExpenseBudget, Map<String, double>> {
  /// Monthly budget per category («محدودیت بودجه برای هر دسته»).
  ExpenseBudgetProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'expenseBudgetProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$expenseBudgetHash();

  @$internal
  @override
  ExpenseBudget create() => ExpenseBudget();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, double> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, double>>(value),
    );
  }
}

String _$expenseBudgetHash() => r'3a93390834f0b908eb648d4dac75c93c22cd5456';

/// Monthly budget per category («محدودیت بودجه برای هر دسته»).

abstract class _$ExpenseBudget extends $Notifier<Map<String, double>> {
  Map<String, double> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<String, double>, Map<String, double>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Map<String, double>, Map<String, double>>,
        Map<String, double>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
