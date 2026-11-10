import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_recurring_sheet.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «هزینه‌ها» — month list with category chips and totals, the add sheet,
/// and the monthly breakdown. The recurring-rules manager is a follow-on
/// sheet here.
class ShopExpensesScreen extends ConsumerStatefulWidget {
  const ShopExpensesScreen({super.key});

  @override
  ConsumerState<ShopExpensesScreen> createState() => _ShopExpensesScreenState();
}

class _ShopExpensesScreenState extends ConsumerState<ShopExpensesScreen> {
  List<ShopExpense> _expenses = [];
  List<({int id, String name})> _categories = [];
  int? _categoryFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dao3 = ref.read(shop3DaoProvider);
    await dao3.ensureExpenseCategoriesSeeded();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month).millisecondsSinceEpoch;
    final to = now.millisecondsSinceEpoch;
    final expenses = await dao3.expenses(
      fromMs: from,
      toMs: to,
      categoryId: _categoryFilter,
    );
    final categories = await dao3.expenseCategories();
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _categories = categories;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final total = _expenses.fold<int>(0, (s, e) => s + e.amount);

    // Monthly breakdown by category.
    final byCategory = <int, int>{};
    for (final e in _expenses) {
      if (e.categoryId != null) {
        byCategory[e.categoryId!] = (byCategory[e.categoryId!] ?? 0) + e.amount;
      }
    }
    final maxCat = byCategory.values.fold<int>(1, (m, v) => v > m ? v : m);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: t.primary,
        iconTheme: IconThemeData(color: t.primary),
        title: Text(
          'هزینه‌های این ماه',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            color: t.primary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'هزینه‌های ماهانه (تکراری)',
            icon: const Icon(Icons.repeat_rounded),
            onPressed: _manageRecurring,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(),
        backgroundColor: const Color(0xFF0E7C86),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label:
            Text('هزینه', style: TextStyle(fontFamily: AppTheme.fontFamily)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 12, DsSpacing.page, 90),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        const DuotoneIconTile(
                          accent: Color(0xFFC9462C),
                          icon: Icons.payments_rounded,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        // Expanded: an unbounded Column here overflowed the card
                        // on a 320 dp screen as soon as the amount grew.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'جمع هزینه‌های این ماه',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11,
                                    color: t.textSecondary),
                              ),
                              Text(
                                NumberFormat.groupDigits('$total'),
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (byCategory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'به تفکیک دسته',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          for (final entry in byCategory.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      _catName(entry.key),
                                      style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 11),
                                    ),
                                  ),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: SizedBox(
                                        height: 6,
                                        child: Stack(
                                          children: [
                                            Container(
                                                color: t.outline
                                                    .withValues(alpha: .3)),
                                            FractionallySizedBox(
                                              widthFactor:
                                                  entry.value / maxCat,
                                              child: Container(
                                                  color: const Color(
                                                      0xFF0E7C86)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    NumberFormat.groupDigits('${entry.value}'),
                                    style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: const Text('همه'),
                            selected: _categoryFilter == null,
                            onSelected: (_) {
                              setState(() => _categoryFilter = null);
                              _reload();
                            },
                          ),
                        ),
                        for (final c in _categories)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text(c.name),
                              selected: _categoryFilter == c.id,
                              onSelected: (_) {
                                setState(() => _categoryFilter = c.id);
                                _reload();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final e in _expenses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            const DuotoneIconTile(
                              accent: Color(0xFFC9462C),
                              icon: Icons.receipt_outlined,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _catName(e.categoryId),
                                    style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${jalaliLabelFa(e.date)} · '
                                    '${e.method == PaymentMethod.cash ? 'نقد' : 'غیرنقد'}'
                                    '${e.payee.isEmpty ? '' : ' · ${e.payee}'}',
                                    style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 10,
                                        color: t.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              NumberFormat.groupDigits('${e.amount}'),
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _catName(int? id) {
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return 'سایر';
  }

  /// The recurring-rules manager. A rule generates a REMINDER each period —
  /// never an automatic posting (the brief is explicit); «ثبت این ماه» opens
  /// the pre-filled expense sheet.
  Future<void> _manageRecurring() async {
    final dao3 = ref.read(shop3DaoProvider);
    await RecurringManagerSheet.show(
      context,
      dao3: dao3,
      onAddThisMonth: (rule) {
        _add(
          presetCategory: rule.categoryId,
          presetAmount: rule.amount,
          presetMethod: rule.method,
          recurringRuleId: rule.id,
        );
      },
    );
    _reload();
  }

  Future<void> _add({
    int? presetCategory,
    int? presetAmount,
    PaymentMethod? presetMethod,
    String? recurringRuleId,
  }) async {
    final amountCtrl = TextEditingController(
        text: presetAmount == null ? '' : '$presetAmount');
    final payeeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final t = TimeThemeKit.of(context).palette;
    var categoryId = presetCategory ?? _categories.firstOrNull?.id;
    var method = presetMethod ?? PaymentMethod.cash;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'مبلغ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in _categories)
                      ChoiceChip(
                        label: Text(c.name),
                        selected: categoryId == c.id,
                        onSelected: (_) =>
                            setSheetState(() => categoryId = c.id),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final m in const [
                      (PaymentMethod.cash, 'نقد'),
                      (PaymentMethod.card, 'کارت'),
                      (PaymentMethod.transfer, 'انتقال'),
                    ])
                      ChoiceChip(
                        label: Text(m.$2),
                        selected: method == m.$1,
                        onSelected: (_) => setSheetState(() => method = m.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: payeeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'پرداخت‌گیرنده (اختیاری)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E7C86)),
                  onPressed: () async {
                    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amount <= 0) return;
                    await ref.read(shop3DaoProvider).addExpense(
                          date: DateTime.now(),
                          categoryId: categoryId,
                          amount: amount,
                          method: method,
                          payee: payeeCtrl.text.trim(),
                          note: noteCtrl.text.trim(),
                        );
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    _reload();
                  },
                  child: const Text('ثبت هزینه'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
