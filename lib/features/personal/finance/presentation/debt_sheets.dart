import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/finance/finance_engine.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_providers.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_style.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_widgets.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

// ─── person ─────────────────────────────────────────────────────────────

Future<void> showPersonSheet(BuildContext context, {Person? person}) {
  return showCareSheet<void>(
    context,
    accent: financeLedgerColor,
    child: _PersonSheet(person: person),
  );
}

class _PersonSheet extends ConsumerStatefulWidget {
  const _PersonSheet({this.person});

  final Person? person;

  @override
  ConsumerState<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends ConsumerState<_PersonSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.person?.name ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.person?.phone ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.person?.note ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final store = ref.read(financeStoreProvider.notifier);
    final existing = widget.person;
    if (existing == null) {
      await store.addPerson(name: name, phone: _phone.text, note: _note.text);
    } else {
      await store.updatePerson(existing.copyWith(
        name: name,
        phone: _phone.text.trim(),
        note: _note.text.trim(),
      ));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: widget.person == null ? 'افزودن شخص' : 'ویرایش شخص',
          subtitle: 'نام را خودتان وارد می‌کنید؛ برنامه به مخاطبین گوشی '
              'دسترسی ندارد.',
        ),
        CareField(controller: _name, label: 'نام'),
        CareField(
          controller: _phone,
          label: 'شماره تماس (اختیاری)',
          keyboardType: TextInputType.phone,
          ltr: true,
        ),
        CareField(controller: _note, label: 'یادداشت (اختیاری)', maxLines: 2),
        CareSheetSubmit(
          label: 'ذخیره',
          accent: financeLedgerColor,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ─── entry ──────────────────────────────────────────────────────────────

Future<void> showEntrySheet(
  BuildContext context, {
  required Person person,
  DebtEntry? entry,
}) {
  return showCareSheet<void>(
    context,
    accent: financeLedgerColor,
    child: _EntrySheet(person: person, entry: entry),
  );
}

class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet({required this.person, this.entry});

  final Person person;
  final DebtEntry? entry;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late final TextEditingController _amount = TextEditingController(
      text: widget.entry == null
          ? ''
          : NumberFormat.formatPlain(widget.entry!.amount));
  late final TextEditingController _note =
      TextEditingController(text: widget.entry?.note ?? '');
  late final TextEditingController _witness =
      TextEditingController(text: widget.entry?.witnessNote ?? '');
  late DebtDirection _direction =
      widget.entry?.direction ?? DebtDirection.owedToMe;
  late DateTime? _dueDate = widget.entry?.dueDate;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _witness.dispose();
    super.dispose();
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
    final existing = widget.entry;
    if (existing == null) {
      await store.addEntry(
        personId: widget.person.id,
        direction: _direction,
        amount: amount,
        dueDate: _dueDate,
        note: _note.text,
        witnessNote: _witness.text,
      );
    } else {
      await store.updateEntry(existing.copyWith(
        direction: _direction,
        amount: amount,
        dueDate: _dueDate,
        note: _note.text.trim(),
        witnessNote: _witness.text.trim(),
      ));
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: widget.entry == null
              ? 'ثبت برای ${widget.person.name}'
              : 'ویرایش مورد',
          subtitle:
              'فقط مبلغ، تاریخ و یادداشت ثبت می‌شود؛ برنامه هیچ حکم شرعی '
              'یا نحوهٔ محاسبه‌ای تعیین نمی‌کند.',
        ),
        Row(
          children: [
            for (final d in DebtDirection.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => setState(() => _direction = d),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _direction == d
                            ? financeLedgerColor.withValues(alpha: .14)
                            : t.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _direction == d
                              ? financeLedgerColor
                              : t.outline,
                          width: .5,
                        ),
                      ),
                      child: Text(
                        d.labelFa,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight:
                              _direction == d ? FontWeight.w700 : null,
                          color: _direction == d
                              ? dsContentColor(context, financeLedgerColor)
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
        CareField(
          controller: _amount,
          label: 'مبلغ',
          keyboardType: TextInputType.number,
          digitsOnly: true,
          ltr: true,
        ),
        CareSwitchRow(
          label: 'تاریخ سررسید دارد',
          value: _dueDate != null,
          accent: financeLedgerColor,
          onChanged: (v) => setState(() {
            _dueDate = v ? DateTime.now() : null;
          }),
        ),
        if (_dueDate != null)
          CareDateButton(label: 'سررسید', date: _dueDate, onPicked: (d) {
            setState(() => _dueDate = d);
          }),
        CareField(controller: _note, label: 'یادداشت (اختیاری)', maxLines: 2),
        CareField(
          controller: _witness,
          label: 'شاهد یا توضیح تکمیلی (اختیاری)',
          maxLines: 2,
        ),
        CareSheetSubmit(
          label: 'ذخیره',
          accent: financeLedgerColor,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ─── payment ────────────────────────────────────────────────────────────

Future<void> showPaymentSheet(
  BuildContext context, {
  required DebtEntry entry,
  required double remaining,
}) {
  return showCareSheet<void>(
    context,
    accent: financeLedgerColor,
    child: _PaymentSheet(entry: entry, remaining: remaining),
  );
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.entry, required this.remaining});

  final DebtEntry entry;
  final double remaining;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  late final TextEditingController _amount =
      TextEditingController(text: NumberFormat.formatPlain(widget.remaining));
  final _note = TextEditingController();
  late DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
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
    await ref.read(financeStoreProvider.notifier).addPayment(
          entry: widget.entry,
          amount: amount,
          date: _date,
          note: _note.text,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final unit = CurrencyStore.calculators.current.unit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: 'ثبت پرداخت',
          subtitle:
              'باقی‌مانده: ${NumberFormat.formatMoney(widget.remaining, unit)}'
              ' — پرداخت جزئی هم ثبت می‌شود.',
        ),
        CareDateButton(label: 'تاریخ پرداخت', date: _date, onPicked: (d) {
          setState(() => _date = d);
        }),
        CareField(
          controller: _amount,
          label: 'مبلغ',
          keyboardType: TextInputType.number,
          digitsOnly: true,
          ltr: true,
        ),
        CareField(controller: _note, label: 'یادداشت (اختیاری)'),
        CareSheetSubmit(
          label: 'ثبت',
          accent: financeLedgerColor,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

// ─── polite reminder ────────────────────────────────────────────────────

Future<void> showPoliteMessageSheet(
  BuildContext context, {
  required Person person,
  required DebtEntry entry,
  required double remaining,
}) {
  return showCareSheet<void>(
    context,
    accent: financeLedgerColor,
    child: _PoliteMessageSheet(
      person: person,
      entry: entry,
      remaining: remaining,
    ),
  );
}

class _PoliteMessageSheet extends ConsumerStatefulWidget {
  const _PoliteMessageSheet({
    required this.person,
    required this.entry,
    required this.remaining,
  });

  final Person person;
  final DebtEntry entry;
  final double remaining;

  @override
  ConsumerState<_PoliteMessageSheet> createState() =>
      _PoliteMessageSheetState();
}

class _PoliteMessageSheetState extends ConsumerState<_PoliteMessageSheet> {
  final _text = TextEditingController();
  String? _selectedId;
  bool _initialized = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _fill(DebtMessageTemplate template) {
    final unit = CurrencyStore.calculators.current.unit;
    return buildDebtMessage(
      template,
      personName: widget.person.name,
      amountText: NumberFormat.formatMoney(widget.remaining, unit),
      dateText: widget.entry.dueDate == null
          ? ''
          : financeJalaliDate(widget.entry.dueDate!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(debtTemplatesProvider).value ?? const [];
    final t = TimeThemeKit.of(context).palette;
    if (!_initialized && templates.isNotEmpty) {
      _initialized = true;
      _selectedId = templates.first.id;
      _text.text = _fill(templates.first);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareSheetTitle(
          title: 'یادآوری مؤدبانه',
          subtitle: 'متن را می‌توانید ویرایش کنید. برنامه پیامی نمی‌فرستد؛ '
              'متن را به اشتراک‌گذاری یا کپی می‌کنید.',
        ),
        if (templates.isNotEmpty)
          Wrap(
            spacing: 6,
            children: [
              for (final template in templates)
                ChoiceChip(
                  label: Text(
                    template.title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                    ),
                  ),
                  selected: _selectedId == template.id,
                  onSelected: (_) => setState(() {
                    _selectedId = template.id;
                    _text.text = _fill(template);
                  }),
                ),
            ],
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _text,
          maxLines: 6,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textPrimary,
            height: 1.7,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: t.surfaceAlt,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.outline, width: .5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => ShareService.copyText(context, _text.text),
                child: const Text('کپی'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: financeLedgerColor,
                  foregroundColor: dsOnAccent(context),
                ),
                onPressed: () => ShareService.shareText(_text.text),
                child: const Text('اشتراک‌گذاری'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FinanceAmount(
          value: widget.remaining,
          unit: CurrencyStore.calculators.current.unit,
          size: 12,
          color: t.textMuted,
        ),
      ],
    );
  }
}

// ─── delete confirmation ────────────────────────────────────────────────

/// Shared confirm dialog for the finance page (plan, person, obligation).
Future<bool> confirmFinanceDelete(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('انصراف'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
