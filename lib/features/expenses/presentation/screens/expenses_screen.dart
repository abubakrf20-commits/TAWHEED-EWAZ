import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_provider.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_common.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_virtues.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_summary.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_filters.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_tile.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_dialog.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  ExpenseFilter _filter = ExpenseFilter.all;

  // Search + category narrowing (both combine with the type/month filter).
  bool _searchActive = false;
  String _query = '';
  String? _selectedCategory;
  final _searchCtrl = TextEditingController();

  /// واحد پول **دفتر هزینه‌ها** — عمداً جدا از واحد حسابگرها
  /// ([CurrencyStore.ledger]): آزمایش کردن دلار در حسابگر زکات نباید برچسب
  /// تراکنش‌های ثبت‌شده را عوض کند.
  AppCurrency _currency = AppCurrency.toman;

  String get _unit => _currency.unit;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    // واحد دفتر از صفحهٔ تنظیمات هم عوض می‌شود؛ این صفحه در تب دیگری زنده
    // می‌ماند، پس بدون گوش دادن به انبار برچسب مبالغ قدیمی می‌ماند.
    CurrencyStore.ledger.notifier.addListener(_onStoreCurrencyChanged);
  }

  @override
  void dispose() {
    CurrencyStore.ledger.notifier.removeListener(_onStoreCurrencyChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStoreCurrencyChanged() {
    final next = CurrencyStore.ledger.notifier.value;
    if (!mounted || next == _currency) return;
    setState(() => _currency = next);
  }

  Future<void> _loadCurrency() async {
    final c = await CurrencyStore.ledger.load();
    if (!mounted || c == _currency) return;
    setState(() => _currency = c);
  }

  bool get _narrowed => _selectedCategory != null || _query.trim().isNotEmpty;

  /// The read failed. This used to be invisible: `loaded` went true either way,
  /// so the onboarding screen told a reader with a full ledger to start
  /// recording their first transaction.
  Widget _buildLoadFailure(BuildContext context) {
    return FailureView(
      id: 'expenses_load',
      title: 'دفتر هزینه‌ها باز نشد',
      detail: 'تراکنش‌های شما پاک نشده‌اند؛ فقط خواندنشان ناموفق بود.',
      onRetry: () => ref.read(expenseListProvider.notifier).reload(),
      layout: FailureLayout.page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final expenses = ref.watch(expenseListProvider);
    final loadStatus = ref.watch(expensesLoadedProvider);
    final saveFailed = ref.watch(expenseSaveFailedProvider);
    final now = DateTime.now();

    double totalIncome = 0, totalExpense = 0;
    for (final e in expenses) {
      if (e.isIncome) {
        totalIncome += e.amount;
      } else {
        totalExpense += e.amount;
      }
    }
    final totalBalance = totalIncome - totalExpense;

    // A category narrows the list until the last row carrying it is deleted;
    // the field then points at a name no row has, the list is empty, and the
    // menu that could clear it is hidden (it needs two categories) — a filter
    // the reader cannot undo. Corrected here, before the ledger is computed,
    // so the frame that paints is the frame with the filter already gone.
    if (_selectedCategory != null &&
        !expenses.any((e) => e.category == _selectedCategory)) {
      _selectedCategory = null;
    }

    // The month sums, the filter, the sort and the section split all need the
    // same per-row Jalali conversion. Doing them in one memoised pass means one
    // conversion per row per data change instead of four per row per rebuild.
    final ledger = _ledgerFor(expenses, now);
    final filtered = ledger.filtered;
    final monthIncome = ledger.monthIncome;
    final monthExpense = ledger.monthExpense;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'تراکنش‌ها',
        titleWidget: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 15)),
                decoration: InputDecoration(
                  hintText: 'جستجو در تراکنش‌ها...',
                  hintStyle: TextStyle(color: t.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
                textDirection: TextDirection.rtl,
              )
            : Text('هزینه‌ها',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: t.primary)),
        actions: [
          if (_searchActive)
            IconButton(
              key: const ValueKey('expense_search_close'),
              icon: const Icon(Icons.close),
              tooltip: 'بستن جستجو',
              onPressed: () {
                setState(() {
                  _searchActive = false;
                  _query = '';
                  _searchCtrl.clear();
                });
              },
            )
          else
            IconButton(
              key: const ValueKey('expense_search_btn'),
              icon: const Icon(Icons.search),
              tooltip: 'جستجو',
              onPressed: () => setState(() => _searchActive = true),
            ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'گزارش',
            onPressed: () => context.push(RouteNames.expenseReport),
          ),
        ],
      ),
      body: loadStatus == ExpensesLoadStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : loadStatus == ExpensesLoadStatus.failed
          ? _buildLoadFailure(context)
          : expenses.isEmpty
              ? ExpensesVirtuesScreen(
                  onStart: () => _showDialog(context, ref),
                )
              : CustomScrollView(
                  slivers: [
                    if (saveFailed)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(DsSpacing.page, 10,
                              DsSpacing.page, 0),
                          child: _SaveFailedBanner(),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: ExpensesSummary(
                        balance: totalBalance,
                        income: totalIncome,
                        expense: totalExpense,
                        monthIncome: monthIncome,
                        monthExpense: monthExpense,
                        unit: _unit,
                      ),
                    ),
                    SliverToBoxAdapter(
                        child: _buildFilterRow(filtered.length, expenses)),
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          icon: _filter == ExpenseFilter.all && !_narrowed
                              ? Icons.receipt_long_outlined
                              : Icons.search_off,
                          message: _filter == ExpenseFilter.all && !_narrowed
                              ? 'هنوز تراکنشی ثبت نشده'
                              : 'موردی یافت نشد',
                          accent: expensesAccent,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        sliver: SliverList(
                          // Lazy on purpose: a `SliverChildListDelegate` over
                          // a materialised `List<Widget>` built every tile in
                          // the ledger — thousands of them, each doing its own
                          // theme lookup and date formatting — on every
                          // rebuild, including on every search keystroke.
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _rowWidget(ledger.rows[i]),
                            childCount: ledger.rows.length,
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton.extended(
          onPressed: () => _showDialog(context, ref),
          backgroundColor: expensesAccent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text('تراکنش جدید',
              style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
      ),
    );
  }

  /// Memoised ledger view. Rebuilt only when the data or a filter changes.
  _LedgerCache? _ledgerCache;

  /// Everything the body needs — the filtered+sorted list, the month sums and
  /// the sectioned rows — computed in a single pass.
  ///
  /// WHY the cache: `build()` runs on every keystroke of the search field, and
  /// this used to re-convert every row to the Jalali calendar four times over
  /// (month sums, the month filter, the section split, the top-category scan)
  /// and re-sort the whole list, every time. The identity check on [expenses]
  /// is the real invalidation signal — the provider hands back a new list
  /// instance whenever anything changes.
  _LedgerCache _ledgerFor(List<ExpenseModel> expenses, DateTime now) {
    final dayStamp =
        DateTime(now.year, now.month, now.day).microsecondsSinceEpoch;
    final cached = _ledgerCache;
    if (cached != null &&
        identical(cached.source, expenses) &&
        cached.dayStamp == dayStamp &&
        cached.filter == _filter &&
        cached.category == _selectedCategory &&
        cached.query == _query) {
      return cached;
    }

    final jNow = Jalali.fromDateTime(now);

    // One Jalali conversion per row, and the flags every consumer needs.
    final today = <String>{};
    final future = <String>{};
    final thisMonth = <String>{};
    double monthIncome = 0, monthExpense = 0;
    final todayStart = DateTime(now.year, now.month, now.day);
    for (final e in expenses) {
      final je = Jalali.fromDateTime(e.date);
      final inMonth = je.year == jNow.year && je.month == jNow.month;
      if (inMonth) {
        thisMonth.add(e.id);
        if (e.isIncome) {
          monthIncome += e.amount;
        } else {
          monthExpense += e.amount;
        }
      }
      if (e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day) {
        today.add(e.id);
      } else if (DateTime(e.date.year, e.date.month, e.date.day)
          .isAfter(todayStart)) {
        // Dated ahead (a scheduled payment): it used to fall through to
        // «گذشته», which is simply untrue and unhelpful.
        future.add(e.id);
      }
    }

    final q = _query.trim().toLowerCase();
    final cat = _selectedCategory;
    final filtered = expenses.where((e) {
      switch (_filter) {
        case ExpenseFilter.all:
          break;
        case ExpenseFilter.income:
          if (!e.isIncome) return false;
        case ExpenseFilter.expense:
          if (e.isIncome) return false;
        case ExpenseFilter.month:
          if (!thisMonth.contains(e.id)) return false;
      }
      if (cat != null && e.category != cat) return false;
      if (q.isNotEmpty) {
        return e.title.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q) ||
            (e.note?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Top expense category of the whole current month (today included).
    String? topCategory;
    var topTotal = 0.0;
    final totals = <String, double>{};
    for (final e in expenses) {
      if (e.isIncome || !thisMonth.contains(e.id)) continue;
      final sum = (totals[e.category] ?? 0) + e.amount;
      totals[e.category] = sum;
      if (sum > topTotal) {
        topTotal = sum;
        topCategory = e.category;
      }
    }

    final rows = <_LedgerRow>[];
    void addSection(String title, Iterable<ExpenseModel> items) {
      final list = items.toList();
      if (list.isEmpty) return;
      rows.add(_LedgerSection(title, list.length));
      for (var i = 0; i < list.length; i++) {
        rows.add(_LedgerItem(list[i], lastInSection: i == list.length - 1));
      }
    }

    addSection('امروز', filtered.where((e) => today.contains(e.id)));
    addSection('پیش‌رو', filtered.where((e) => future.contains(e.id)));
    if (topCategory != null) rows.add(_LedgerTopCategory(topCategory));
    addSection(
      'این ماه',
      filtered.where((e) =>
          !today.contains(e.id) &&
          !future.contains(e.id) &&
          thisMonth.contains(e.id)),
    );
    addSection(
      'گذشته',
      filtered.where((e) =>
          !today.contains(e.id) &&
          !future.contains(e.id) &&
          !thisMonth.contains(e.id)),
    );

    return _ledgerCache = _LedgerCache(
      source: expenses,
      dayStamp: dayStamp,
      filter: _filter,
      category: cat,
      query: _query,
      filtered: filtered,
      monthIncome: monthIncome,
      monthExpense: monthExpense,
      rows: rows,
    );
  }

  Widget _rowWidget(_LedgerRow row) {
    switch (row) {
      case _LedgerSection(:final title, :final count):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(title: title, count: count),
            const SizedBox(height: 8),
          ],
        );
      case _LedgerTopCategory(:final category):
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MonthTopCategoryCard(category: category),
        );
      case _LedgerItem(:final expense, :final lastInSection):
        return Padding(
          padding: EdgeInsets.only(bottom: lastInSection ? 6 : 0),
          child: ExpenseTile(
            expense: expense,
            onTap: () => _showDialog(context, ref, expense: expense),
            onDelete: () => _confirmDelete(context, ref, expense),
          ),
        );
    }
  }

  Widget _buildFilterRow(int count, List<ExpenseModel> expenses) {
    final t = TimeThemeKit.of(context).palette;
    // Category narrowing lives in a single menu rather than a second chip
    // row — the duplicate row was removed by an explicit product pass, and
    // opening one menu + tapping one entry is still two interactions.
    final cats = expenses.map((e) => e.category).toSet().toList()..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          ExpenseFilterChip(
              label: 'همه',
              filter: ExpenseFilter.all,
              icon: Icons.grid_view_rounded,
              current: _filter,
              onChanged: (f) => setState(() => _filter = f),
              key: const ValueKey('expense_filter_all')),
          const SizedBox(width: 8),
          ExpenseFilterChip(
              label: 'درآمد',
              filter: ExpenseFilter.income,
              icon: Icons.arrow_upward,
              current: _filter,
              onChanged: (f) => setState(() => _filter = f),
              key: const ValueKey('expense_filter_income')),
          const SizedBox(width: 8),
          ExpenseFilterChip(
              label: 'هزینه',
              filter: ExpenseFilter.expense,
              icon: Icons.arrow_downward,
              current: _filter,
              onChanged: (f) => setState(() => _filter = f),
              key: const ValueKey('expense_filter_expense')),
          const SizedBox(width: 8),
          ExpenseFilterChip(
              label: 'این ماه',
              filter: ExpenseFilter.month,
              icon: Icons.calendar_month,
              current: _filter,
              onChanged: (f) => setState(() => _filter = f),
              key: const ValueKey('expense_filter_month')),
          const SizedBox(width: 16),
          Text(
            '$count تراکنش',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              color: t.textMuted,
            ),
          ),
          if (cats.length >= 2 || _selectedCategory != null) ...[
            const SizedBox(width: 10),
            PopupMenuButton<String>(
              key: const ValueKey('expense_category_filter'),
              tooltip: _selectedCategory == null
                  ? 'فیلتر دسته'
                  : 'دستهٔ فعال: $_selectedCategory',
              icon: Icon(
                _selectedCategory == null
                    ? Icons.filter_alt_outlined
                    : Icons.filter_alt,
                size: 20,
                color: _selectedCategory == null
                    ? t.textMuted
                    : expensesAccent,
              ),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: '',
                  child: Text(
                    'همه دسته‌ها',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: _selectedCategory == null
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                for (final c in cats)
                  PopupMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(
                          _selectedCategory == c
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 16,
                          color: _selectedCategory == c
                              ? expensesAccent
                              : t.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(c,
                            style: TextStyle(fontFamily: AppTheme.fontFamily)),
                      ],
                    ),
                  ),
              ],
              onSelected: (v) =>
                  setState(() => _selectedCategory = v.isEmpty ? null : v),
            ),
          ],
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, WidgetRef ref,
      {ExpenseModel? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          ExpenseDialog(ref: ref, existingExpense: expense, unit: _unit),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, ExpenseModel expense) {
    final notifier = ref.read(expenseListProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأیید حذف'),
        content: Text('آیا از حذف "${expense.title}" اطمینان دارید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.deleteExpense(expense.id);
              if (!context.mounted) return;
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: const Text('تراکنش حذف شد'),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'بازگردانی',
                    onPressed: notifier.undoLastDelete,
                  ),
                ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

/// Says the ledger could not be written.
///
/// The row stays on screen — it is real in memory — but the reader must know it
/// has not reached disk, because the old behaviour was that it silently
/// disappeared on the next launch.
class _SaveFailedBanner extends StatelessWidget {
  const _SaveFailedBanner();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final warn = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warn.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.save_outlined, size: 16, color: warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ذخیره‌سازی ناموفق بود؛ این تغییرات ممکن است با بستن برنامه از '
              'دست بروند.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                height: 1.6,
                color: t.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the ledger list — a section heading, the month's top-category
/// card, or a transaction. A flat row list is what lets the sliver build its
/// children lazily instead of instantiating every tile up front.
sealed class _LedgerRow {
  const _LedgerRow();
}

class _LedgerSection extends _LedgerRow {
  const _LedgerSection(this.title, this.count);

  final String title;
  final int count;
}

class _LedgerTopCategory extends _LedgerRow {
  const _LedgerTopCategory(this.category);

  final String category;
}

class _LedgerItem extends _LedgerRow {
  const _LedgerItem(this.expense, {required this.lastInSection});

  final ExpenseModel expense;

  /// The last tile of its section carries the section's bottom gap, so the
  /// spacing stays identical to the old eager layout.
  final bool lastInSection;
}

/// The whole derived view of the ledger, computed once per data change.
class _LedgerCache {
  const _LedgerCache({
    required this.source,
    required this.dayStamp,
    required this.filter,
    required this.category,
    required this.query,
    required this.filtered,
    required this.monthIncome,
    required this.monthExpense,
    required this.rows,
  });

  /// The provider's list instance this was computed from — the invalidation
  /// signal.
  final List<ExpenseModel> source;

  /// Midnight stamp, so a screen left open overnight re-sections itself.
  final int dayStamp;

  final ExpenseFilter filter;
  final String? category;
  final String query;

  final List<ExpenseModel> filtered;
  final double monthIncome;
  final double monthExpense;
  final List<_LedgerRow> rows;
}
