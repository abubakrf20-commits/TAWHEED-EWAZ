import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «صندوق» — today card (opening, cash in/out, expected, counted →
/// difference), open/close buttons, adjustments (برداشت/واریز مالک) and the
/// history with differences.
class ShopCashScreen extends ConsumerStatefulWidget {
  const ShopCashScreen({super.key});

  @override
  ConsumerState<ShopCashScreen> createState() => _ShopCashScreenState();
}

class _ShopCashScreenState extends ConsumerState<ShopCashScreen> {
  CashDayRow? _today;
  List<CashDayRow> _history = [];
  int? _expected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dao3 = ref.read(shop3DaoProvider);
    final today = await dao3.cashDayToday();
    final history = await dao3.cashDayHistory();
    int? expected;
    if (today != null && today.isOpen) {
      expected = await dao3.expectedCashForDay(DateTime.now());
    }
    if (!mounted) return;
    setState(() {
      _today = today;
      _history = history;
      _expected = expected;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
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
          'صندوق',
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
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 12, DsSpacing.page, 40),
                children: [
                  _todayCard(context),
                  const SizedBox(height: 12),
                  const SectionHeader(title: 'تاریخچه', accent: Color(0xFF0E7C86)),
                  const SizedBox(height: 4),
                  for (final day in _history) _historyRow(context, day),
                ],
              ),
      ),
    );
  }

  Widget _todayCard(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final day = _today;
    if (day == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'صندوق امروز باز نشده است.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: t.textSecondary),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _open,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7C86)),
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('باز کردن روز'),
            ),
          ],
        ),
      );
    }

    if (day.isOpen) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B3F45),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'صندوق امروز (${jalaliLabelFa(day.date)})',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: Colors.white.withValues(alpha: .8),
              ),
            ),
            const SizedBox(height: 8),
            _kv('افتتاحیه', NumberFormat.groupDigits('${day.openingCash}')),
            _kv('موجودی مورد انتظار', NumberFormat.groupDigits('$_expected')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _adjust,
                    icon: const Icon(Icons.swap_vert_rounded, size: 18),
                    label: const Text('برداشت/واریز'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _close,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0E7C86)),
                    icon: const Icon(Icons.lock_rounded, size: 18),
                    label: const Text('بستن روز'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Closed: show the difference with semantics.
    final diff = day.difference ?? 0;
    return AppCard(
      borderColor: diff == 0
          ? null
          : const Color(0xFFC9462C).withValues(alpha: .4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'روز بسته‌شده · ${jalaliLabelFa(day.date)}',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _kv('مورد انتظار', NumberFormat.groupDigits('${day.expectedCash}')),
          _kv('شمارش شد', NumberFormat.groupDigits('${day.countedCash}')),
          _kv(
            'اختلاف',
            diff == 0
                ? 'صفر — درست'
                : '${diff > 0 ? '+' : ''}${NumberFormat.groupDigits('$diff')}',
            color: diff == 0
                ? const Color(0xFF2E8B3D)
                : const Color(0xFFC9462C),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: Colors.white.withValues(alpha: .8),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, CashDayRow day) {
    final t = TimeThemeKit.of(context).palette;
    final diff = day.difference;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            DuotoneIconTile(
              accent: day.isOpen
                  ? const Color(0xFFD9922B)
                  : const Color(0xFF0E7C86),
              icon: day.isOpen
                  ? Icons.lock_open_rounded
                  : Icons.lock_rounded,
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jalaliLabelFa(day.date),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily, fontSize: 12),
                  ),
                  Text(
                    day.isOpen ? 'باز' : 'بسته‌شده',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        color: t.textMuted),
                  ),
                ],
              ),
            ),
            if (diff != null && diff != 0)
              Text(
                '${diff > 0 ? '+' : ''}${NumberFormat.groupDigits('$diff')}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: diff > 0
                      ? const Color(0xFF2E8B3D)
                      : const Color(0xFFC9462C),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    await ref.read(shop3DaoProvider).openCashDay();
    _reload();
  }

  Future<void> _close() async {
    final ctrl = TextEditingController();
    final expected = _expected ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بستن صندوق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'موجودی مورد انتظار: ${NumberFormat.groupDigits('$expected')}',
              style: TextStyle(fontFamily: AppTheme.fontFamily),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'پول شمارش‌شده',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('بستن روز'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final counted = int.tryParse(ctrl.text.trim()) ?? 0;
    await ref.read(shop3DaoProvider).closeCashDay(
          day: DateTime.now(),
          countedCash: counted,
        );
    _reload();
  }

  Future<void> _adjust() async {
    final t = TimeThemeKit.of(context).palette;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var kind = 'owner_withdrawal';

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
                Wrap(
                  spacing: 6,
                  children: [
                    for (final (k, label) in const [
                      ('owner_withdrawal', 'برداشت مالک'),
                      ('owner_deposit', 'واریز مالک'),
                      ('other', 'سایر'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: kind == k,
                        onSelected: (_) => setSheetState(() => kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'مبلغ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'یادداشت (اختیاری)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E7C86)),
                  onPressed: () async {
                    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amount <= 0) return;
                    final signed = kind == 'owner_withdrawal' ? -amount : amount;
                    final db = ref.read(shop3DaoProvider).db;
                    await db.customStatement(
                      'INSERT INTO p2_shop_cash_adjustment '
                      '(id, cash_day_id, date, kind, amount, note, created_at) '
                      'VALUES (?, ?, ?, ?, ?, ?, ?)',
                      [
                        'cja_${DateTime.now().microsecondsSinceEpoch}',
                        _today?.id,
                        DateTime.now().millisecondsSinceEpoch,
                        kind,
                        signed,
                        noteCtrl.text.trim(),
                        DateTime.now().millisecondsSinceEpoch,
                      ],
                    );
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    _reload();
                  },
                  child: const Text('ثبت'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
