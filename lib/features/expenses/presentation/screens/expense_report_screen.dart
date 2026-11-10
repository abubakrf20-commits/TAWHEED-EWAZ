import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_categories_provider.dart';
import 'package:tawheeed/features/expenses/presentation/providers/expense_provider.dart';
import 'package:tawheeed/features/expenses/presentation/widgets/expenses/expenses_common.dart';
import 'package:tawheeed/features/expenses/services/expense_exporter.dart';
import 'package:tawheeed/features/expenses/services/expense_report_pdf.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';
import 'package:tawheeed/features/tools/zakat/presentation/screens/zakat_screen.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

class ExpenseReportScreen extends ConsumerStatefulWidget {
  const ExpenseReportScreen({super.key});

  /// The cash amount the zakat link pre-fills: the SAME «مانده سال» the
  /// summary cards above this button compute.
  ///
  /// It used to be the lifetime net of every recorded row, which is not a
  /// balance at all — years of tracked spending keep subtracting from it, so
  /// the prefilled figure drifted away from the money the user actually
  /// holds. [now] is a parameter so tests can pin the Jalali year.
  @visibleForTesting
  static double zakatPrefillAmount(List<ExpenseModel> expenses, DateTime now) {
    final year = Jalali.fromDateTime(now).year;
    double balance = 0;
    for (final e in expenses) {
      if (Jalali.fromDateTime(e.date).year != year) continue;
      balance += e.isIncome ? e.amount : -e.amount;
    }
    return balance > 0 ? balance : 0;
  }

  @override
  ConsumerState<ExpenseReportScreen> createState() =>
      _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen> {
  bool _showYearly = false;
  bool _exportingPdf = false;

  /// واحد دفتر هزینه‌ها — همین واحد در صفحهٔ اصلی انتخاب می‌شود و اینجا فقط
  /// خوانده می‌شود تا گزارش و بودجه با همان واحد دیده شوند.
  AppCurrency _currency = AppCurrency.toman;

  String get _unit => _currency.unit;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final c = await CurrencyStore.ledger.load();
    if (!mounted || c == _currency) return;
    setState(() => _currency = c);
  }

  Future<void> _exportPdf(List<dynamic> expenses) async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final jNow = Jalali.fromDateTime(DateTime.now());
      // Both chart modes report on the current Jalali year (the «ماهانه»
      // view is its months), so one PDF shape covers them: the whole year,
      // with the month-by-month section inside.
      final bytes = await buildExpenseReportPdf(
        expenses: expenses.cast(),
        jalaliYear: jNow.year,
        budgets: ref.read(expenseBudgetProvider),
        unit: _unit,
      );
      await shareToolReportPdf(
          bytes: bytes, fileName: 'expenses-${jNow.year}.pdf');
    } catch (e) {
      AppLogger.warning('ExpenseReport', 'PDF export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ساخت فایل PDF ممکن نشد.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseListProvider);
    final now = DateTime.now();
    // One Jalali conversion per row for the whole screen; the three sections
    // below each used to do their own.
    final rows = _jalaliRows(expenses);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'گزارش هزینه‌ها',
        actions: [
          IconButton(
            key: const ValueKey('expense_report_pdf'),
            tooltip: 'خروجی PDF',
            icon: _exportingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _exportPdf(expenses),
          ),
          IconButton(
            key: const ValueKey('expense_report_csv'),
            tooltip: 'خروجی CSV',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _exportCsv(expenses),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('ماهانه')),
              ButtonSegment(value: true, label: Text('سالیانه')),
            ],
            selected: {_showYearly},
            onSelectionChanged: (v) => setState(() => _showYearly = v.first),
          ),
          const SizedBox(height: 24),
          if (_showYearly)
            _buildYearlyChart(rows, now)
          else
            _buildMonthlyChart(rows, now),
          const SizedBox(height: 24),
          _buildSummaryCards(rows, now),
          const SizedBox(height: 24),
          _buildZakatLink(expenses),
          const SizedBox(height: 24),
          _BudgetSection(unit: _unit),
        ],
      ),
    );
  }

  Future<void> _exportCsv(List<dynamic> expenses) async {
    final csv = ExpenseExporter.buildCsv(
      expenses.cast(),
    );
    // `share` reports failure by returning false instead of throwing, so the
    // old one-liner turned a failed export into a tap that did nothing.
    final shared = await ExpenseExporter.share(csv);
    if (!shared && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اشتراک‌گذاری فایل CSV ممکن نشد.')),
      );
    }
  }

  /// Natural link to the زکات feature: opens the calculator with this year's
  /// balance prefilled as the cash amount.
  ///
  /// The balance is in the LEDGER's unit, and the calculator opens in the
  /// CALCULATORS' unit — two stores that are deliberately independent. If the
  /// two differ, the same number would silently mean something else (85 grams
  /// of gold against «5,000,000» afghani is not the same nisab test as against
  /// toman), so the figure is handed over together with its unit and the
  /// calculator drops it, with the reason printed under its field. This screen
  /// never switches a unit: «واحد پول» changes in the settings only.
  Widget _buildZakatLink(List<dynamic> expenses) {
    final t = TimeThemeKit.of(context).palette;
    final positive = ExpenseReportScreen.zakatPrefillAmount(
        expenses.cast<ExpenseModel>(), DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('زکات', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openZakatFor(positive),
          icon: const Icon(Icons.account_balance_outlined, size: 20),
          label: Text(
            positive > 0
                ? 'محاسبه زکات مانده امسال '
                    '(${NumberFormat.formatMoney(positive, _unit)})'
                : 'محاسبه زکات موجودی',
            style: TextStyle(fontFamily: AppTheme.fontFamily),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: TopicHues.zakat,
            side: BorderSide(color: TopicHues.zakat.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(46),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'مانده سال جاری (درآمدهای امسال منهای هزینه‌های آن) به‌عنوان موجودی '
          'نقدی در زکات‌نامه وارد می‌شود — به واحد دفتر ($_unit)',
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: t.textMuted,
          ),
        ),
      ],
    );
  }

  /// Opens the calculator with this year's balance, in the ledger's unit.
  ///
  /// The unit is never switched from here (2026-11-09): «واحد پول» is changed
  /// in the settings only, so one screen can no longer rewrite another tool's
  /// choice behind its back. The amount is still handed over together with the
  /// unit it is counted in — the calculator is the one place that knows
  /// whether the two agree, and it drops the figure there, with the reason
  /// written under the field, instead of this screen guessing on its behalf.
  Future<void> _openZakatFor(double balance) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AmbientBackground(
          child: ZakatScreen(
            initialCashAmount: balance > 0 ? balance : null,
            initialCashUnit: balance > 0 ? _currency : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(List<_JalaliRow> rows, DateTime now) {
    final jNow = Jalali.fromDateTime(now);
    final months = List.generate(12, (i) => i + 1);
    final incomeData = List<double>.filled(12, 0);
    final expenseData = List<double>.filled(12, 0);

    // One pass over the ledger. This used to be twelve — one per month, each
    // re-converting every row to the Jalali calendar.
    for (final r in rows) {
      if (r.year != jNow.year) continue;
      if (r.isIncome) {
        incomeData[r.month - 1] += r.amount;
      } else {
        expenseData[r.month - 1] += r.amount;
      }
    }

    final maxVal = _max(incomeData + expenseData, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نمودار ماهانه ${jNow.year}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.center,
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${months[group.x.toInt()]}:\n${NumberFormat.formatPlain(rod.toY)}',
                        TextStyle(color: Colors.white, fontSize: AppTheme.scaledFontSize(context, 12)),
                      );
                    },
                  )),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          if (v.toInt() >= 0 && v.toInt() < 12) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_monthName(v.toInt()),
                                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 9))),
                            );
                          }
                          return const SizedBox();
                        })),
                leftTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
              ),
              gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxVal * 1.2 / 4),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(
                  12,
                  (i) => BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                            toY: incomeData[i], color: incomeColor, width: 10),
                        BarChartRodData(
                            toY: expenseData[i],
                            color: Colors.red.shade400,
                            width: 10),
                      ])),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _Legend(color: incomeColor, label: 'درآمد'),
            const SizedBox(width: 24),
            _Legend(color: Colors.red.shade400, label: 'هزینه'),
          ],
        ),
      ],
    );
  }

  Widget _buildYearlyChart(List<_JalaliRow> rows, DateTime now) {
    final jNow = Jalali.fromDateTime(now);
    final years = List.generate(5, (i) => jNow.year - 4 + i);
    final incomeData = List<double>.filled(years.length, 0);
    final expenseData = List<double>.filled(years.length, 0);

    // One pass, indexed by year — was five passes with a Jalali conversion
    // per row inside each.
    final first = years.first;
    for (final r in rows) {
      final idx = r.year - first;
      if (idx < 0 || idx >= years.length) continue;
      if (r.isIncome) {
        incomeData[idx] += r.amount;
      } else {
        expenseData[idx] += r.amount;
      }
    }

    final maxVal = _max(incomeData + expenseData, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نمودار سالیانه', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.center,
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${years[group.x.toInt()]}:\n${NumberFormat.formatPlain(rod.toY)}',
                        TextStyle(color: Colors.white, fontSize: AppTheme.scaledFontSize(context, 12)),
                      );
                    },
                  )),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx >= 0 && idx < years.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${years[idx]}',
                                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 9))),
                            );
                          }
                          return const SizedBox();
                        })),
                leftTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
              ),
              gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxVal * 1.2 / 4),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(
                  years.length,
                  (i) => BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                            toY: incomeData[i], color: incomeColor, width: 14),
                        BarChartRodData(
                            toY: expenseData[i],
                            color: Colors.red.shade400,
                            width: 14),
                      ])),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _Legend(color: incomeColor, label: 'درآمد'),
            const SizedBox(width: 24),
            _Legend(color: Colors.red.shade400, label: 'هزینه'),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(List<_JalaliRow> rows, DateTime now) {
    final jNow = Jalali.fromDateTime(now);
    double totalIncome = 0, totalExpense = 0;
    for (final r in rows) {
      if (r.year != jNow.year) continue;
      if (r.isIncome) {
        totalIncome += r.amount;
      } else {
        totalExpense += r.amount;
      }
    }

    final yearBalance = totalIncome - totalExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('خلاصه سال ${jNow.year}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _SummaryCard(
                    label: 'درآمد سال',
                    amount: totalIncome,
                    unit: _unit,
                    color: incomeColor)),
            const SizedBox(width: 12),
            Expanded(
                child: _SummaryCard(
                    label: 'هزینه سال',
                    amount: totalExpense,
                    unit: _unit,
                    color: Colors.red.shade400)),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          label: 'مانده سال',
          amount: yearBalance,
          unit: _unit,
          color: yearBalance >= 0 ? incomeColor : Colors.red.shade400,
        ),
      ],
    );
  }

  String _monthName(int index) {
    return DateConstants.persianMonths[index];
  }

  double _max(List<double> values, double fallback) {
    final m = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    return m > 0 ? m : fallback;
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 12))),
      ],
    );
  }
}

/// Per-category monthly budget tracking («محدودیت بودجه برای هر دسته»):
/// shows the current Jalali month's spend against each limit with a progress
/// bar, and lets the user add / edit / remove limits.
class _BudgetSection extends ConsumerWidget {
  const _BudgetSection({required this.unit});

  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final expenses = ref.watch(expenseListProvider);
    final budgets = ref.watch(expenseBudgetProvider);
    final jNow = Jalali.fromDateTime(DateTime.now());

    final spend = <String, double>{};
    for (final e in expenses) {
      if (e.isIncome) continue;
      final je = Jalali.fromDateTime(e.date);
      if (je.year == jNow.year && je.month == jNow.month) {
        spend[e.category] = (spend[e.category] ?? 0) + e.amount;
      }
    }
    // The same vocabulary the expense dialog offers. Deriving it from the rows
    // instead — which is what this used to do — meant a category with no spending
    // yet could not be budgeted, and one the user had just added was invisible
    // here until a transaction used it.
    final usedCategories = ref.watch(expenseCategoryChoicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'بودجه ماهانه دسته‌ها',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'افزودن بودجه',
              icon: const Icon(Icons.add_circle_outline),
              color: TopicHues.expenses,
              onPressed: () =>
                  _showBudgetDialog(context, ref, categories: usedCategories),
            ),
          ],
        ),
        if (budgets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TopicHues.expenses.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: TopicHues.expenses.withValues(alpha: 0.25)),
            ),
            child: Text(
              'برای هر دسته سقف بودجه ماهانه تعیین کنید تا میزان مصرف کنار هر دسته نشان داده شود.',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted,
              ),
            ),
          )
        else
          for (final entry in budgets.entries) ...[
            _BudgetCard(
              category: entry.key,
              limit: entry.value,
              spent: spend[entry.key] ?? 0,
              unit: unit,
              onEdit: () => _showBudgetDialog(context, ref,
                  categories: usedCategories,
                  editingCategory: entry.key,
                  editingLimit: entry.value),
              onDelete: () => ref
                  .read(expenseBudgetProvider.notifier)
                  .removeBudget(entry.key),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Future<void> _showBudgetDialog(
    BuildContext context,
    WidgetRef ref, {
    required List<String> categories,
    String? editingCategory,
    double? editingLimit,
  }) async {
    final notifier = ref.read(expenseBudgetProvider.notifier);
    final available = <String>{
      ...categories,
      if (editingCategory != null) editingCategory,
    }.toList()
      ..sort();

    String? selected = editingCategory ??
        (available.contains('عمومی')
            ? 'عمومی'
            : (available.isNotEmpty ? available.first : null));
    final ctrl = TextEditingController(
      text: editingLimit != null ? NumberFormat.formatPlain(editingLimit) : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(editingCategory == null
                  ? 'بودجه جدید'
                  : 'ویرایش بودجه «$editingCategory»'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (available.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selected,
                      decoration: const InputDecoration(labelText: 'دسته'),
                      items: [
                        for (final c in available)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setState(() => selected = v),
                    )
                  else
                    const Text('هنوز دسته‌ای ثبت نشده است'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    decoration: InputDecoration(
                      labelText: 'سقف ماهانه ($unit)',
                      suffixText: unit,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: const [LatinGroupingFormatter()],
                  ),
                ],
              ),
              actions: [
                if (editingCategory != null)
                  TextButton(
                    onPressed: () {
                      notifier.removeBudget(editingCategory);
                      Navigator.of(ctx).pop();
                    },
                    child:
                        const Text('حذف', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () {
                    final limit = NumberFormat.parse(ctrl.text);
                    final cat = selected?.trim();
                    if (cat != null && cat.isNotEmpty && limit > 0) {
                      notifier.setBudget(cat, limit);
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('ذخیره'),
                ),
              ],
            );
          },
        );
      },
    );
    ctrl.dispose();
  }
}

class _BudgetCard extends StatelessWidget {
  final String category;
  final double limit;
  final double spent;
  final String unit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.category,
    required this.limit,
    required this.spent,
    required this.unit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final ratio = limit > 0 ? (spent / limit) : 0.0;
    final over = spent > limit;
    final color = over ? Colors.red.shade400 : TopicHues.expenses;
    final remaining = limit - spent;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 14), fontWeight: FontWeight.w700),
                ),
              ),
              // Flexible + ellipsis: a nine-figure spend against a nine-figure
              // limit plus the two buttons is wider than a 320 dp card.
              Flexible(
                child: Text(
                  '${NumberFormat.formatPlain(spent)} / ${NumberFormat.formatPlain(limit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: AppTheme.scaledFontSize(context, 12), color: color),
                ),
              ),
              IconButton(
                tooltip: 'ویرایش',
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: t.textMuted,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline, size: 18),
                color: t.textMuted,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: t.divider,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            over
                ? '${NumberFormat.formatPlain(-remaining)} $unit بیشتر از بودجه'
                : '${NumberFormat.formatPlain(remaining)} $unit تا سقف بودجه',
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: over ? Colors.red.shade400 : t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One expense with its Jalali year/month resolved once.
///
/// WHY: the report converts every row to the Jalali calendar to bucket it. It
/// used to do that inside each aggregation — twelve times over for the monthly
/// chart, five for the yearly one, once more for the summary — so opening the
/// report was O(18 × rows) conversions, on every rebuild. One pass now, and the
/// aggregations are plain arithmetic.
class _JalaliRow {
  const _JalaliRow({
    required this.amount,
    required this.isIncome,
    required this.year,
    required this.month,
  });

  final double amount;
  final bool isIncome;
  final int year;
  final int month;
}

List<_JalaliRow> _jalaliRows(List<ExpenseModel> expenses) {
  final rows = <_JalaliRow>[];
  for (final e in expenses) {
    final j = Jalali.fromDateTime(e.date);
    rows.add(_JalaliRow(
      amount: e.amount,
      isIncome: e.isIncome,
      year: j.year,
      month: j.month,
    ));
  }
  return rows;
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  /// The ledger's unit. The three cards used to print a bare number, so a
  /// reader had no way to tell «۱۲٬۵۰۰٬۰۰۰» from a count.
  final String unit;

  const _SummaryCard(
      {required this.label,
      required this.amount,
      required this.color,
      this.unit = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: AppTheme.scaledFontSize(context, 12))),
          const SizedBox(height: 4),
          // Scale down rather than overflow: this card is half the page width,
          // and «۱۲٬۳۴۵٬۶۷۸٬۹۰۱ تومان» at 19 px is wider than that on a 320 dp
          // phone (the text used to wrap mid-amount instead).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              NumberFormat.formatMoney(amount, unit),
              maxLines: 1,
              style: TextStyle(
                  color: color, fontSize: AppTheme.scaledFontSize(context, 19), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
