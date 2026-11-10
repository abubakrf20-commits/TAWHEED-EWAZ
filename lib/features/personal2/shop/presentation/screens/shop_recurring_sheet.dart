import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// One recurring rule row.
class RecurringRule {
  RecurringRule({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.dayOfMonth,
    required this.method,
    required this.active,
  });

  final String id;
  final int? categoryId;
  final int amount;
  final int dayOfMonth;
  final PaymentMethod method;
  final bool active;
}

/// The recurring-expense rules manager: list with active toggles, add sheet,
/// and the «ثبت این ماه» action which hands the rule back to the caller (a
/// REMINDER turned into a pre-filled expense sheet — never an auto-posting,
/// per the brief).
class RecurringManagerSheet extends StatefulWidget {
  const RecurringManagerSheet({
    super.key,
    required this.dao3,
    required this.onAddThisMonth,
  });

  final Shop3Dao dao3;
  final void Function(RecurringRule rule) onAddThisMonth;

  static Future<void> show(
    BuildContext context, {
    required Shop3Dao dao3,
    required void Function(RecurringRule rule) onAddThisMonth,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TimeThemeKit.of(context).palette.elevated,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .7,
          child: RecurringManagerSheet(
            dao3: dao3,
            onAddThisMonth: onAddThisMonth,
          ),
        ),
      ),
    );
  }

  @override
  State<RecurringManagerSheet> createState() => _RecurringManagerSheetState();
}

class _RecurringManagerSheetState extends State<RecurringManagerSheet> {
  List<RecurringRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rows = await widget.dao3.db.customSelect(
      'SELECT * FROM p2_shop_recurring_expense ORDER BY day_of_month ASC',
    ).get();
    if (!mounted) return;
    setState(() {
      _rules = [
        for (final r in rows)
          RecurringRule(
            id: r.read<String>('id'),
            categoryId: r.readNullable<int>('category_id'),
            amount: r.read<int>('amount'),
            dayOfMonth: r.read<int>('day_of_month'),
            method: PaymentMethod.fromWire(r.read<String>('method')),
            active: r.read<int>('active') == 1,
          ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      children: [
        const SheetHandle(),
        Row(
          children: [
            Expanded(
              child: Text(
                'هزینه‌های ماهانه',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addRule),
          ],
        ),
        Text(
          'هر دوره یادآوری می‌شوند؛ ثبت خودکار نمی‌شوند.',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily, fontSize: 10, color: t.textMuted),
        ),
        const SizedBox(height: 8),
        if (_rules.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'قاعده‌ای نیست. با + اجاره یا اینترنت را ماهانه کنید.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: t.textMuted),
            ),
          ),
        for (final rule in _rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const DuotoneIconTile(
                    accent: Color(0xFF0E7C86),
                    icon: Icons.repeat_rounded,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${NumberFormat.groupDigits('${rule.amount}')} · '
                          'روز ${rule.dayOfMonth}',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily, fontSize: 12),
                        ),
                        Text(
                          rule.method == PaymentMethod.cash ? 'نقد' : 'غیرنقد',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10,
                              color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (rule.active)
                    TextButton(
                      onPressed: () => widget.onAddThisMonth(rule),
                      child: const Text('ثبت این ماه'),
                    ),
                  Switch(
                    value: rule.active,
                    activeThumbColor: const Color(0xFF0E7C86),
                    onChanged: (v) async {
                      await widget.dao3.db.customStatement(
                        'UPDATE p2_shop_recurring_expense SET active = ? '
                        'WHERE id = ?',
                        [v ? 1 : 0, rule.id],
                      );
                      _reload();
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addRule() async {
    final amountCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '1');
    final categories = await widget.dao3.expenseCategories();
    if (!mounted) return;
    final t = TimeThemeKit.of(context).palette;
    var categoryId = categories.isEmpty ? null : categories.first.id;
    var method = PaymentMethod.cash;

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
                      labelText: 'مبلغ ماهانه', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'روز ماه (جلالی)',
                    helperText: 'روز ۳۱ در ماه کوتاه به آخر ماه می‌چسبد',
                    border: OutlineInputBorder(),
                  ),
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
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E7C86)),
                  onPressed: () async {
                    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    final day = int.tryParse(dayCtrl.text.trim()) ?? 1;
                    if (amount <= 0 || day < 1 || day > 31) return;
                    await widget.dao3.db.customStatement(
                      'INSERT INTO p2_shop_recurring_expense '
                      '(id, category_id, amount, day_of_month, method, note, '
                      "last_reminded_key, active) "
                      "VALUES (?, ?, ?, ?, ?, '', '', 1)",
                      [
                        'rec_${DateTime.now().microsecondsSinceEpoch}',
                        categoryId,
                        amount,
                        day,
                        method.wire,
                      ],
                    );
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    _reload();
                  },
                  child: const Text('افزودن قاعده'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
