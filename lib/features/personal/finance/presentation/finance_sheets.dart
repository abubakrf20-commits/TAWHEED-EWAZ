import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_providers.dart';
import 'package:tawheeed/features/personal/finance/presentation/debt_sheets.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_style.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/services/care_attachment_store.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «+» on the finance bar: cheque, installment plan, other commitment, ledger.
Future<void> showFinanceAddMenu(BuildContext context) {
  return showCareSheet<void>(
    context,
    accent: financeInstallmentColor,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(
          title: 'افزودن',
          subtitle: 'چک و قسط در تب اول، دَین و طلب در تب دوم ثبت می‌شوند.',
        ),
        _MenuRow(
          icon: Icons.receipt_long_outlined,
          label: 'چک',
          hint: 'صادره یا دریافتی، با شماره و بانک',
          color: financeChequeColor,
          onTap: () {
            Navigator.of(context).pop();
            showObligationSheet(context);
          },
        ),
        _MenuRow(
          icon: Icons.event_repeat_outlined,
          label: 'قسط یا وام (برنامهٔ اقساط)',
          hint: 'همهٔ قسط‌ها یک‌جا ساخته می‌شوند',
          color: financeInstallmentColor,
          onTap: () {
            Navigator.of(context).pop();
            showPlanSheet(context);
          },
        ),
        _MenuRow(
          icon: Icons.more_horiz,
          label: 'تعهد دیگر',
          hint: 'یک پرداخت یا دریافت تک‌باره',
          color: financeOtherColor,
          onTap: () {
            Navigator.of(context).pop();
            showObligationSheet(context, kind: ObligationKind.other);
          },
        ),
        _MenuRow(
          icon: Icons.handshake_outlined,
          label: 'دَین / طلب',
          hint: 'دفتر اشخاص؛ در تب دوم',
          color: financeLedgerColor,
          onTap: () {
            Navigator.of(context).pop();
            showPersonSheet(context);
          },
        ),
      ],
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            DuotoneIconTile(accent: color, icon: icon, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  Text(
                    hint,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, size: 18, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── one obligation (cheque / other / single installment) ───────────────

Future<void> showObligationSheet(
  BuildContext context, {
  ObligationKind kind = ObligationKind.cheque,
  Obligation? existing,
}) {
  return showCareSheet<void>(
    context,
    accent: financeKindColor(kind),
    child: _ObligationSheet(kind: kind, existing: existing),
  );
}

class _ObligationSheet extends ConsumerStatefulWidget {
  const _ObligationSheet({required this.kind, this.existing});

  final ObligationKind kind;
  final Obligation? existing;

  @override
  ConsumerState<_ObligationSheet> createState() => _ObligationSheetState();
}

class _ObligationSheetState extends ConsumerState<_ObligationSheet> {
  late final TextEditingController _title;
  late final TextEditingController _counterparty;
  late final TextEditingController _amount;
  late final TextEditingController _chequeNumber;
  late final TextEditingController _bank;
  late final TextEditingController _note;
  late final TextEditingController _remind;
  late DateTime _dueDate;
  late ObligationDirection _direction;
  List<String> _photos = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _counterparty = TextEditingController(text: e?.counterparty ?? '');
    _amount = TextEditingController(
        text: e == null ? '' : NumberFormat.formatPlain(e.amount));
    _chequeNumber = TextEditingController(text: e?.chequeNumber ?? '');
    _bank = TextEditingController(text: e?.bankName ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _remind = TextEditingController(
        text: '${e?.remindBeforeDays ?? widget.kind.defaultRemindBeforeDays}');
    _dueDate = e?.dueDate ?? DateTime.now();
    _direction = e?.direction ?? widget.kind.defaultDirection;
    _photos = e?.attachmentPaths ?? const [];
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _counterparty,
      _amount,
      _chequeNumber,
      _bank,
      _note,
      _remind,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await CareAttachmentStore.pickAndStore();
    if (!mounted || picked.isEmpty) return;
    setState(() => _photos = [..._photos, ...picked]);
  }

  Future<void> _save() async {
    final amount = NumberFormat.parse(_amount.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ باید بزرگ‌تر از صفر باشد.')),
      );
      return;
    }
    setState(() => _busy = true);
    final store = ref.read(financeStoreProvider.notifier);
    final remind = NumberFormat.parse(_remind.text).round().clamp(0, 90);
    final existing = widget.existing;
    if (existing == null) {
      await store.addObligation(
        kind: widget.kind,
        direction: _direction,
        title: _title.text,
        amount: amount,
        dueDate: _dueDate,
        counterparty: _counterparty.text,
        chequeNumber: _chequeNumber.text,
        bankName: _bank.text,
        note: _note.text,
        remindBeforeDays: remind,
        attachmentPaths: _photos,
      );
    } else {
      await store.updateObligation(existing.copyWith(
        direction: _direction,
        title: _title.text.trim().isEmpty ? existing.title : _title.text.trim(),
        counterparty: _counterparty.text.trim(),
        amount: amount,
        dueDate: _dueDate,
        chequeNumber: _chequeNumber.text.trim(),
        bankName: _bank.text.trim(),
        note: _note.text.trim(),
        remindBeforeDays: remind,
        attachmentPaths: _photos,
      ));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = financeKindColor(widget.kind);
    final isCheque = widget.kind == ObligationKind.cheque;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: widget.existing == null
              ? 'افزودن ${widget.kind.labelFa}'
              : 'ویرایش ${widget.kind.labelFa}',
          subtitle: 'مبلغ و تاریخ را وارد کنید؛ یادآوری خودکار تنظیم می‌شود.',
        ),
        _DirectionPicker(
          value: _direction,
          accent: accent,
          onChanged: (v) => setState(() => _direction = v),
        ),
        CareField(controller: _title, label: 'عنوان', hint: 'مثلاً چک اجاره'),
        CareField(
          controller: _amount,
          label: 'مبلغ',
          hint: '۰',
          keyboardType: TextInputType.number,
          digitsOnly: true,
          ltr: true,
        ),
        CareDateButton(label: 'تاریخ سررسید', date: _dueDate, onPicked: (d) {
          setState(() => _dueDate = d);
        }),
        if (isCheque) ...[
          CareField(
            controller: _chequeNumber,
            label: 'شمارهٔ چک (اختیاری)',
            ltr: true,
            digitsOnly: true,
          ),
          CareField(controller: _bank, label: 'بانک (اختیاری)'),
        ],
        CareField(controller: _counterparty, label: 'طرف حساب (اختیاری)'),
        CareField(
          controller: _remind,
          label: 'یادآوری چند روز قبل',
          keyboardType: TextInputType.number,
          digitsOnly: true,
          ltr: true,
        ),
        CareField(controller: _note, label: 'یادداشت (اختیاری)', maxLines: 2),
        if (isCheque)
          _PhotoRow(
            count: _photos.length,
            accent: accent,
            onAdd: _pickPhoto,
          ),
        const SizedBox(height: 4),
        CareSheetSubmit(
          label: 'ذخیره',
          accent: accent,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _DirectionPicker extends StatelessWidget {
  const _DirectionPicker({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final ObligationDirection value;
  final Color accent;
  final ValueChanged<ObligationDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          for (final d in ObligationDirection.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: InkWell(
                  onTap: () => onChanged(d),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == d
                          ? accent.withValues(alpha: .14)
                          : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: value == d ? accent : t.outline,
                        width: .5,
                      ),
                    ),
                    child: Text(
                      d.labelFa,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: value == d ? FontWeight.w700 : null,
                        color: value == d
                            ? dsContentColor(context, accent)
                            : t.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.count,
    required this.accent,
    required this.onAdd,
  });

  final int count;
  final Color accent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Icon(Icons.photo_camera_outlined, size: 16, color: t.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            count == 0 ? 'عکس چک (اختیاری)' : '$count عکس پیوست شده',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              color: t.textMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: onAdd,
          child: Text(
            'افزودن عکس',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              color: dsContentColor(context, accent),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── installment plan ───────────────────────────────────────────────────

Future<void> showPlanSheet(BuildContext context, {InstallmentPlan? plan}) {
  return showCareSheet<void>(
    context,
    accent: financeInstallmentColor,
    child: _PlanSheet(plan: plan),
  );
}

class _PlanSheet extends ConsumerStatefulWidget {
  const _PlanSheet({this.plan});

  final InstallmentPlan? plan;

  @override
  ConsumerState<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<_PlanSheet> {
  late final TextEditingController _title;
  late final TextEditingController _counterparty;
  late final TextEditingController _amount;
  late final TextEditingController _count;
  late final TextEditingController _interval;
  late final TextEditingController _note;
  late DateTime _firstDue;
  late ObligationKind _kind;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _title = TextEditingController(text: p?.title ?? '');
    _counterparty = TextEditingController(text: p?.counterparty ?? '');
    _amount = TextEditingController(
        text: p == null ? '' : NumberFormat.formatPlain(p.amount));
    _count = TextEditingController(text: '${p?.count ?? 12}');
    _interval = TextEditingController(text: '${p?.intervalMonths ?? 1}');
    _note = TextEditingController(text: p?.note ?? '');
    _firstDue = p?.firstDueDate ?? DateTime.now();
    _kind = p?.kind ?? ObligationKind.installment;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _counterparty,
      _amount,
      _count,
      _interval,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final amount = NumberFormat.parse(_amount.text);
    final count = NumberFormat.parse(_count.text).round();
    final interval = NumberFormat.parse(_interval.text).round();
    if (amount <= 0 || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ و تعداد باید بزرگ‌تر از صفر باشند.')),
      );
      return;
    }
    setState(() => _busy = true);
    final store = ref.read(financeStoreProvider.notifier);
    final plan = widget.plan;
    if (plan == null) {
      await store.addPlan(
        title: _title.text,
        kind: _kind,
        firstDueDate: _firstDue,
        count: count.clamp(1, 240),
        amount: amount,
        intervalMonths: interval.clamp(1, 12),
        counterparty: _counterparty.text,
        note: _note.text,
      );
    } else {
      await store.updatePlan(plan.copyWith(
        title: _title.text.trim().isEmpty ? plan.title : _title.text.trim(),
        counterparty: _counterparty.text.trim(),
        firstDueDate: _firstDue,
        count: count.clamp(1, 240),
        amount: amount,
        intervalMonths: interval.clamp(1, 12),
        note: _note.text.trim(),
      ));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = financeInstallmentColor;
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: widget.plan == null ? 'برنامهٔ اقساط' : 'ویرایش برنامهٔ اقساط',
          subtitle: 'همهٔ قسط‌ها هم‌زمان ساخته می‌شوند. با ویرایش، فقط '
              'قسط‌های پرداخت‌نشدهٔ آینده تغییر می‌کنند.',
        ),
        Row(
          children: [
            for (final k in const [
              ObligationKind.installment,
              ObligationKind.loan,
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => setState(() => _kind = k),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kind == k
                            ? accent.withValues(alpha: .14)
                            : t.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _kind == k ? accent : t.outline,
                          width: .5,
                        ),
                      ),
                      child: Text(
                        k.labelFa,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: _kind == k ? FontWeight.w700 : null,
                          color: _kind == k
                              ? dsContentColor(context, accent)
                              : t.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        CareField(controller: _title, label: 'عنوان', hint: 'مثلاً وام مسکن'),
        CareField(controller: _counterparty, label: 'طرف حساب (اختیاری)'),
        CareField(
          controller: _amount,
          label: 'مبلغ هر قسط',
          keyboardType: TextInputType.number,
          digitsOnly: true,
          ltr: true,
        ),
        Row(
          children: [
            Expanded(
              child: CareField(
                controller: _count,
                label: 'تعداد قسط',
                keyboardType: TextInputType.number,
                digitsOnly: true,
                ltr: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CareField(
                controller: _interval,
                label: 'فاصله (ماه)',
                keyboardType: TextInputType.number,
                digitsOnly: true,
                ltr: true,
              ),
            ),
          ],
        ),
        CareDateButton(label: 'تاریخ اولین قسط', date: _firstDue, onPicked: (d) {
          setState(() => _firstDue = d);
        }),
        CareField(controller: _note, label: 'یادداشت (اختیاری)', maxLines: 2),
        CareSheetSubmit(
          label: widget.plan == null ? 'ساخت اقساط' : 'ذخیره',
          accent: accent,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ─── mark paid / postpone ───────────────────────────────────────────────

class PaidInput {
  const PaidInput({required this.date, required this.amount, this.note = ''});

  final DateTime date;
  final double amount;
  final String note;
}

Future<PaidInput?> showMarkPaidSheet(
  BuildContext context, {
  required Obligation obligation,
}) {
  return showCareSheet<PaidInput>(
    context,
    accent: financeLoanColor,
    child: _MarkPaidSheet(obligation: obligation),
  );
}

class _MarkPaidSheet extends StatefulWidget {
  const _MarkPaidSheet({required this.obligation});

  final Obligation obligation;

  @override
  State<_MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends State<_MarkPaidSheet> {
  late final TextEditingController _amount = TextEditingController(
      text: NumberFormat.formatPlain(widget.obligation.amount));
  final _note = TextEditingController();
  late DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = financeLoanColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: 'پرداخت ${widget.obligation.title}',
          subtitle: 'مبلغ واقعی را در صورت تفاوت با مبلغ برنامه‌ریزی‌شده '
              'اصلاح کنید.',
        ),
        CareDateButton(label: 'تاریخ پرداخت', date: _date, onPicked: (d) {
          setState(() => _date = d);
        }),
        CareField(
          controller: _amount,
          label: 'مبلغ پرداخت‌شده',
          keyboardType: TextInputType.number,
          digitsOnly: true,
          ltr: true,
        ),
        CareField(controller: _note, label: 'یادداشت (اختیاری)'),
        CareSheetSubmit(
          label: 'پرداخت شد',
          accent: accent,
          onPressed: () {
            final amount = NumberFormat.parse(_amount.text);
            Navigator.of(context).pop(PaidInput(
              date: _date,
              amount: amount <= 0 ? widget.obligation.amount : amount,
              note: _note.text,
            ));
          },
        ),
      ],
    );
  }
}

Future<DateTime?> showPostponeSheet(
  BuildContext context, {
  required Obligation obligation,
}) {
  return showCareSheet<DateTime>(
    context,
    accent: financeInstallmentColor,
    child: _PostponeSheet(obligation: obligation),
  );
}

class _PostponeSheet extends StatefulWidget {
  const _PostponeSheet({required this.obligation});

  final Obligation obligation;

  @override
  State<_PostponeSheet> createState() => _PostponeSheetState();
}

class _PostponeSheetState extends State<_PostponeSheet> {
  late DateTime _date = widget.obligation.dueDate;

  @override
  Widget build(BuildContext context) {
    const accent = financeInstallmentColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(
          title: 'به تعویق انداختن',
          subtitle: 'تاریخ جدید را انتخاب کنید؛ مبلغ و عنوان دست نمی‌خورند.',
        ),
        CareDateButton(label: 'تاریخ جدید', date: _date, onPicked: (d) {
          setState(() => _date = d);
        }),
        CareSheetSubmit(
          label: 'ذخیره',
          accent: accent,
          onPressed: () => Navigator.of(context).pop(_date),
        ),
      ],
    );
  }
}
