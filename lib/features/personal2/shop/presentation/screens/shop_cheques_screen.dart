import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';

/// «چک‌ها» — tabs دریافتی | صادره, sorted by due date with status chips, the
/// state actions (each with confirmation + visible effect), and the
/// «چک‌های در جریان» header.
class ShopChequesScreen extends ConsumerStatefulWidget {
  const ShopChequesScreen({super.key});

  @override
  ConsumerState<ShopChequesScreen> createState() => _ShopChequesScreenState();
}

class _ShopChequesScreenState extends ConsumerState<ShopChequesScreen> {
  List<ShopCheque> _cheques = [];
  ChequeDirection _tab = ChequeDirection.received;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final cheques = await ref.read(shop3DaoProvider).cheques();
    if (!mounted) return;
    setState(() {
      _cheques = cheques;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final forTab = _cheques.where((c) => c.direction == _tab).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final inFlight = forTab.where((c) => c.inFlight).toList();
    final inFlightTotal =
        inFlight.fold<int>(0, (s, c) => s + c.amount);

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
          'چک‌ها',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: const Color(0xFF0E7C86),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('ثبت چک', style: TextStyle(fontFamily: AppTheme.fontFamily)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 0),
                    child: SegmentedButton<ChequeDirection>(
                      segments: const [
                        ButtonSegment(
                            value: ChequeDirection.received,
                            label: Text('دریافتی')),
                        ButtonSegment(
                            value: ChequeDirection.issued,
                            label: Text('صادره')),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (s) =>
                          setState(() => _tab = s.first),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.page),
                    child: AppCard(
                      child: Row(
                        children: [
                          const DuotoneIconTile(
                            accent: Color(0xFF0E7C86),
                            icon: Icons.receipt_long_outlined,
                            size: 34,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'چک‌های در جریان',
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11,
                                    color: t.textSecondary),
                              ),
                              Text(
                                NumberFormat.groupDigits('$inFlightTotal'),
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: forTab.isEmpty
                        ? Center(
                            child: Text(
                              'چکی ثبت نشده.',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  color: t.textMuted),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                                DsSpacing.page, 10, DsSpacing.page, 90),
                            children: [
                              for (final c in forTab) _row(context, c),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _row(BuildContext context, ShopCheque c) {
    final t = TimeThemeKit.of(context).palette;
    final daysLeft = c.dueDate.difference(DateTime.now()).inDays;
    final dueSoon = daysLeft >= 0 && daysLeft <= 7 && c.inFlight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () => _actions(c),
        child: Row(
          children: [
            DuotoneIconTile(
              accent: c.status == ChequeStatus.bounced
                  ? const Color(0xFFC9462C)
                  : c.status == ChequeStatus.cleared
                      ? const Color(0xFF2E8B3D)
                      : const Color(0xFF0E7C86),
              icon: Icons.receipt_long_outlined,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'چک ${c.number.isEmpty ? 'بدون شماره' : c.number}'
                    '${c.bank.isEmpty ? '' : ' · ${c.bank}'}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'سررسید ${jalaliLabelFa(c.dueDate)}'
                    '${c.inFlight && daysLeft >= 0 ? ' ($daysLeft روز)' : ''}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      color: dueSoon
                          ? const Color(0xFFC9462C)
                          : t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              NumberFormat.groupDigits('${c.amount}'),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0E7C86).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                c.status.titleFa,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9,
                  color: const Color(0xFF0E7C86),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The state actions sheet, each with the effect summary before confirming.
  Future<void> _actions(ShopCheque c) async {
    final t = TimeThemeKit.of(context).palette;
    final actions = <(ChequeStatus, String, String)>[
      if (canTransition(
          direction: c.direction, from: c.status, to: ChequeStatus.deposited))
        (ChequeStatus.deposited, 'واگذاری به بانک', 'چک در جریان می‌ماند؛ فقط سمت بانک ثبت می‌شود.'),
      if (canTransition(
          direction: c.direction, from: c.status, to: ChequeStatus.cleared))
        (ChequeStatus.cleared, 'وصول شد', 'چک از «در جریان» خارج و در بانک می‌نشیند.'),
      if (canTransition(
          direction: c.direction, from: c.status, to: ChequeStatus.bounced))
        (
          ChequeStatus.bounced,
          'برگشت خورد',
          c.direction == ChequeDirection.received
              ? 'مانده مشتری به اندازهٔ چک برمی‌گردد.'
              : 'بدهی ما به تأمین‌کننده به اندازهٔ چک برمی‌گردد.'
        ),
      if (canTransition(
          direction: c.direction, from: c.status, to: ChequeStatus.endorsed))
        (ChequeStatus.endorsed, 'خرج چک', 'چک به تأمین‌کننده واگذار می‌شود.'),
      if (canTransition(
          direction: c.direction, from: c.status, to: ChequeStatus.cancelled))
        (ChequeStatus.cancelled, 'ابطال', 'با ثبت دلیل؛ اگر پرداخت بود برمی‌گردد.'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.elevated,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 10),
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'چک ${c.number} · ${NumberFormat.groupDigits('${c.amount}')}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            for (final (status, label, effect) in actions)
              ListTile(
                title: Text(label,
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13)),
                subtitle: Text(effect,
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final noteCtrl = TextEditingController();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(label),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(effect,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  height: 1.7)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: noteCtrl,
                            decoration: const InputDecoration(
                                labelText: 'یادداشت (اختیاری)',
                                border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('انصراف'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('تأیید'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !mounted) return;
                  await ref.read(shop3DaoProvider).transitionCheque(
                        chequeId: c.id,
                        to: status,
                        note: noteCtrl.text.trim(),
                        endorsedToSupplierId: status == ChequeStatus.endorsed
                            ? 'sup_manual'
                            : null,
                      );
                  _reload();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    final t = TimeThemeKit.of(context).palette;
    final numberCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var direction = ChequeDirection.received;
    var due = DateTime.now().add(const Duration(days: 30));

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
                SegmentedButton<ChequeDirection>(
                  segments: const [
                    ButtonSegment(
                        value: ChequeDirection.received, label: Text('دریافتی')),
                    ButtonSegment(
                        value: ChequeDirection.issued, label: Text('صادره')),
                  ],
                  selected: {direction},
                  onSelectionChanged: (s) =>
                      setSheetState(() => direction = s.first),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(
                      labelText: 'شماره چک', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bankCtrl,
                  decoration: const InputDecoration(
                      labelText: 'بانک', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'مبلغ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await ShamsiDatePicker.show(
                      context,
                      initialDate: due,
                      earliestDate: DateTime(2020),
                      latestDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setSheetState(() => due = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text('سررسید: ${jalaliLabelFa(due)}'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E7C86)),
                  onPressed: () async {
                    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amount <= 0) return;
                    await ref.read(shop3DaoProvider).addCheque(
                          direction: direction,
                          amount: amount,
                          dueDate: due,
                          number: numberCtrl.text.trim(),
                          bank: bankCtrl.text.trim(),
                        );
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    _reload();
                  },
                  child: const Text('ثبت چک'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
