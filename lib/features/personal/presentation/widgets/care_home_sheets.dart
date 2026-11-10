import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/presentation/providers/care_providers.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_sheet_kit.dart';
import 'package:tawheeed/features/personal/presentation/widgets/care_widgets.dart';
import 'package:tawheeed/features/personal/services/care_attachment_store.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

const Map<String, String> careBillTypes = {
  'electricity': 'برق',
  'water': 'آب',
  'gas': 'گاز',
  'phone': 'تلفن',
  'internet': 'اینترنت',
  'building': 'شارژ ساختمان',
  'other': 'دیگر',
};

/// Add/edit a bill. When [initialType] is given and no [bill] is passed, the
/// type chip opens pre-selected — used for home installments (mortgage /
/// installment).
Future<void> showBillSheet(
  BuildContext context, {
  required String assetId,
  Bill? bill,
  String? initialType,
}) {
  return showCareSheet<void>(
    context,
    child: _BillSheet(assetId: assetId, bill: bill, initialType: initialType),
  );
}

class _BillSheet extends ConsumerStatefulWidget {
  const _BillSheet({
    required this.assetId,
    this.bill,
    this.initialType,
  });
  final String assetId;
  final Bill? bill;
  final String? initialType;

  @override
  ConsumerState<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends ConsumerState<_BillSheet> {
  late final _title = TextEditingController(text: widget.bill?.title ?? '');
  late final _amount = TextEditingController(
      text: widget.bill?.expectedAmount == null
          ? ''
          : '${widget.bill!.expectedAmount!.round()}');
  late final _dueDay =
      TextEditingController(text: '${widget.bill?.dueDay ?? 1}');
  late final _customDays =
      TextEditingController(text: '${widget.bill?.customDays ?? 30}');
  late String _type =
      widget.bill?.type ?? widget.initialType ?? 'electricity';
  late BillRecurrence _recurrence =
      widget.bill?.recurrence ?? BillRecurrence.monthly;
  DateTime? _anchor;
  final List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    _anchor = widget.bill?.firstDueDate;
    _photos.addAll(widget.bill?.attachmentPaths ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _dueDay.dispose();
    _customDays.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final stored = await CareAttachmentStore.pickAndStore();
    if (!mounted || stored.isEmpty) return;
    setState(() => _photos.addAll(stored));
  }

  Future<void> _save() async {
    final notifier = ref.read(careStoreProvider.notifier);
    final bill = Bill(
      id: widget.bill?.id ?? notifier.billId(),
      assetId: widget.assetId,
      type: _type,
      title: _title.text.trim().isEmpty
          ? careBillTypes[_type] ?? 'قبض'
          : _title.text.trim(),
      recurrence: _recurrence,
      dueDay: NumberFormat.parse(_dueDay.text).round().clamp(1, 31),
      customDays: _recurrence == BillRecurrence.custom
          ? NumberFormat.parse(_customDays.text).round().clamp(1, 3650)
          : null,
      firstDueDate: _anchor,
      expectedAmount: _amount.text.trim().isEmpty
          ? null
          : NumberFormat.parse(_amount.text),
      active: widget.bill?.active ?? true,
      createdAt: widget.bill?.createdAt ?? DateTime.now(),
      attachmentPaths: List.of(_photos),
    );
    await notifier.saveBill(bill);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = careHomeColor;
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(title: widget.bill == null ? 'افزودن قبض' : 'ویرایش قبض'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in careBillTypes.entries)
              CareChip(
                label: entry.value,
                selected: _type == entry.key,
                accent: accent,
                onTap: () => setState(() => _type = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 10),
        CareField(controller: _title, label: 'عنوان', hint: 'قبض برق خانه'),
        Row(
          children: [
            Expanded(
              child: CareField(
                controller: _dueDay,
                label: 'روز سررسید در ماه',
                digitsOnly: true,
                keyboardType: TextInputType.number,
                ltr: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CareField(
                controller: _amount,
                label: 'مبلغ تقریبی',
                digitsOnly: true,
                keyboardType: TextInputType.number,
                ltr: true,
              ),
            ),
          ],
        ),
        Text(
          'دورهٔ پرداخت',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final entry in const {
              BillRecurrence.monthly: 'ماهانه',
              BillRecurrence.bimonthly: 'دوماهانه',
              BillRecurrence.custom: 'بازهٔ دلخواه',
            }.entries)
              CareChip(
                label: entry.value,
                selected: _recurrence == entry.key,
                accent: accent,
                onTap: () => setState(() => _recurrence = entry.key),
              ),
          ],
        ),
        if (_recurrence == BillRecurrence.custom) ...[
          const SizedBox(height: 10),
          CareField(
            controller: _customDays,
            label: 'هر چند روز',
            digitsOnly: true,
            keyboardType: TextInputType.number,
            ltr: true,
          ),
        ],
        const SizedBox(height: 6),
        CareDateButton(
          label: 'تاریخ مبدأ',
          date: _anchor,
          accent: accent,
          onPicked: (d) => setState(() => _anchor = d),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _addPhoto,
              icon: const Icon(Icons.add_a_photo_outlined, size: 17),
              label: const Text('افزودن رسید'),
            ),
            const SizedBox(width: 8),
            if (_photos.isNotEmpty)
              Text(
                '${_photos.length} رسید',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: TimeThemeKit.of(context).palette.textMuted,
                ),
              ),
          ],
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, index) => const SizedBox(width: 6),
              itemBuilder: (_, i) =>
                  CareAttachmentThumb(relativePath: _photos[i]),
            ),
          ),
        ],
        CareSheetSubmit(label: 'ذخیره', accent: accent, onPressed: _save),
      ],
    );
  }
}

/// «پرداخت شد» — amount + note, then the period is marked paid.
Future<void> showPayBillSheet(
  BuildContext context, {
  required Bill bill,
  required String periodKey,
  required DateTime dueDate,
}) {
  return showCareSheet<void>(
    context,
    child: _PayBillSheet(bill: bill, periodKey: periodKey, dueDate: dueDate),
  );
}

class _PayBillSheet extends ConsumerStatefulWidget {
  const _PayBillSheet({
    required this.bill,
    required this.periodKey,
    required this.dueDate,
  });

  final Bill bill;
  final String periodKey;
  final DateTime dueDate;

  @override
  ConsumerState<_PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends ConsumerState<_PayBillSheet> {
  late final _amount = TextEditingController(
      text: widget.bill.expectedAmount == null
          ? ''
          : '${widget.bill.expectedAmount!.round()}');
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    await ref.read(careStoreProvider.notifier).payBill(
          bill: widget.bill,
          periodKey: widget.periodKey,
          paidDate: _date,
          amount: _amount.text.trim().isEmpty
              ? null
              : NumberFormat.parse(_amount.text),
          note: _note.text.trim(),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = careHomeColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: 'پرداخت «${widget.bill.title}»',
          subtitle: 'دورهٔ ${careJalali(widget.dueDate)}',
        ),
        CareField(
          controller: _amount,
          label: 'مبلغ پرداخت‌شده',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        CareField(controller: _note, label: 'یادداشت (اختیاری)'),
        CareDateButton(
          label: 'تاریخ پرداخت',
          date: _date,
          accent: accent,
          onPicked: (d) => setState(() => _date = d),
        ),
        CareSheetSubmit(
          label: 'ثبت پرداخت',
          accent: accent,
          busy: _busy,
          onPressed: _pay,
        ),
      ],
    );
  }
}

/// Add/edit a warranty, with receipt photos.
Future<void> showWarrantySheet(
  BuildContext context, {
  required String assetId,
  Warranty? warranty,
}) {
  return showCareSheet<void>(
    context,
    child: _WarrantySheet(assetId: assetId, warranty: warranty),
  );
}

class _WarrantySheet extends ConsumerStatefulWidget {
  const _WarrantySheet({required this.assetId, this.warranty});
  final String assetId;
  final Warranty? warranty;

  @override
  ConsumerState<_WarrantySheet> createState() => _WarrantySheetState();
}

class _WarrantySheetState extends ConsumerState<_WarrantySheet> {
  late final _item =
      TextEditingController(text: widget.warranty?.itemName ?? '');
  late final _store = TextEditingController(text: widget.warranty?.store ?? '');
  late final _serial =
      TextEditingController(text: widget.warranty?.serial ?? '');
  late final _months =
      TextEditingController(text: '${widget.warranty?.months ?? 12}');
  late final _notes = TextEditingController(text: widget.warranty?.notes ?? '');
  late DateTime _purchase;
  late DateTime _expiry;
  late final List<String> _photos = [...?widget.warranty?.receiptPaths];

  @override
  void initState() {
    super.initState();
    _purchase = widget.warranty?.purchaseDate ?? DateTime.now();
    _expiry = widget.warranty?.expiryDate ??
        careWarrantyExpiry(_purchase, 12);
  }

  @override
  void dispose() {
    for (final c in [_item, _store, _serial, _months, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _recomputeExpiry() {
    final months = NumberFormat.parse(_months.text).round();
    if (months <= 0) return;
    setState(() => _expiry = careWarrantyExpiry(_purchase, months));
  }

  Future<void> _save() async {
    final notifier = ref.read(careStoreProvider.notifier);
    await notifier.saveWarranty(Warranty(
      id: widget.warranty?.id ?? notifier.warrantyId(),
      assetId: widget.assetId,
      itemName: _item.text.trim().isEmpty ? 'گارانتی' : _item.text.trim(),
      store: _store.text.trim(),
      serial: _serial.text.trim(),
      purchaseDate: _purchase,
      months: NumberFormat.parse(_months.text).round().clamp(1, 600),
      expiryDate: _expiry,
      receiptPaths: List.of(_photos),
      notes: _notes.text.trim(),
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addPhoto() async {
    final stored = await CareAttachmentStore.pickAndStore();
    if (!mounted || stored.isEmpty) return;
    setState(() => _photos.addAll(stored));
  }

  @override
  Widget build(BuildContext context) {
    const accent = careHomeColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
            title: widget.warranty == null ? 'افزودن گارانتی' : 'ویرایش گارانتی'),
        CareField(controller: _item, label: 'کالا', hint: 'یخچال'),
        Row(
          children: [
            Expanded(child: CareField(controller: _store, label: 'فروشنده')),
            const SizedBox(width: 8),
            Expanded(
              child: CareField(controller: _serial, label: 'شماره سریال', ltr: true),
            ),
          ],
        ),
        CareDateButton(
          label: 'تاریخ خرید',
          date: _purchase,
          accent: accent,
          onPicked: (d) {
            setState(() => _purchase = d);
            _recomputeExpiry();
          },
        ),
        CareField(
          controller: _months,
          label: 'مدت گارانتی (ماه)',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
          onChanged: (_) => _recomputeExpiry(),
        ),
        CareDateButton(
          label: 'تاریخ انقضا',
          date: _expiry,
          accent: accent,
          onPicked: (d) => setState(() => _expiry = d),
        ),
        CareField(controller: _notes, label: 'یادداشت', maxLines: 2),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _addPhoto,
              icon: const Icon(Icons.add_a_photo_outlined, size: 17),
              label: const Text('افزودن رسید'),
            ),
            const SizedBox(width: 8),
            if (_photos.isNotEmpty)
              Text('${_photos.length} رسید'),
          ],
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, index) => const SizedBox(width: 6),
              itemBuilder: (_, i) =>
                  CareAttachmentThumb(relativePath: _photos[i]),
            ),
          ),
        ],
        const SizedBox(height: 6),
        CareSheetSubmit(label: 'ذخیره', accent: accent, onPressed: _save),
      ],
    );
  }
}

/// Add/edit a subscription.
Future<void> showSubscriptionSheet(
  BuildContext context, {
  Subscription? subscription,
}) {
  return showCareSheet<void>(
    context,
    child: _SubscriptionSheet(subscription: subscription),
  );
}

class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet({this.subscription});
  final Subscription? subscription;

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet> {
  late final _name =
      TextEditingController(text: widget.subscription?.name ?? '');
  late final _amount = TextEditingController(
      text: widget.subscription == null
          ? ''
          : '${widget.subscription!.amount.round()}');
  late SubscriptionPeriod _period =
      widget.subscription?.period ?? SubscriptionPeriod.monthly;
  late DateTime _next =
      widget.subscription?.nextChargeDate ?? DateTime.now();
  final _category = TextEditingController();

  @override
  void initState() {
    super.initState();
    _category.text = widget.subscription?.category ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(careStoreProvider.notifier);
    await notifier.saveSubscription(Subscription(
      id: widget.subscription?.id ?? notifier.subscriptionId(),
      name: _name.text.trim().isEmpty ? 'اشتراک' : _name.text.trim(),
      amount: NumberFormat.parse(_amount.text),
      period: _period,
      nextChargeDate: _next,
      category: _category.text.trim(),
      active: widget.subscription?.active ?? true,
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const accent = careHomeColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
            title: widget.subscription == null
                ? 'افزودن اشتراک'
                : 'ویرایش اشتراک'),
        CareField(controller: _name, label: 'نام', hint: 'اسپاتیفای'),
        CareField(
          controller: _amount,
          label: 'مبلغ هر دوره',
          digitsOnly: true,
          keyboardType: TextInputType.number,
          ltr: true,
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final entry in const {
              SubscriptionPeriod.monthly: 'ماهانه',
              SubscriptionPeriod.yearly: 'سالانه',
            }.entries)
              CareChip(
                label: entry.value,
                selected: _period == entry.key,
                accent: accent,
                onTap: () => setState(() => _period = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 10),
        CareDateButton(
          label: 'شارژ بعدی',
          date: _next,
          accent: accent,
          onPicked: (d) => setState(() => _next = d),
        ),
        CareField(controller: _category, label: 'دسته (اختیاری)'),
        CareSheetSubmit(label: 'ذخیره', accent: accent, onPressed: _save),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Home Expense sheets (هزینه‌های خانه)
// Categories are limited to home/building — no food or groceries.
// ════════════════════════════════════════════════════════════════════

const Map<String, String> homeExpenseCategories = {
  'maintenance': 'تعمیرات',
  'repair': 'سرویس',
  'furniture': 'لوازم خانگی',
  'cleaning': 'نظافت',
  'security': 'امنیت',
  'utilities_extra': 'سایر هزینه‌های خانه',
  'other': 'سایر',
};

Future<CareRecord?> showAddHomeExpenseSheet(
  BuildContext context, {
  required String homeId,
}) {
  return showCareSheet<CareRecord?>(
    context,
    child: _HomeExpenseSheet(homeId: homeId),
  );
}

Future<CareRecord?> showEditHomeExpenseSheet(
  BuildContext context, {
  required String homeId,
  required CareRecord expense,
}) {
  return showCareSheet<CareRecord?>(
    context,
    child: _HomeExpenseSheet(homeId: homeId, expense: expense),
  );
}

class _HomeExpenseSheet extends ConsumerStatefulWidget {
  const _HomeExpenseSheet({required this.homeId, this.expense});
  final String homeId;
  final CareRecord? expense;

  @override
  ConsumerState<_HomeExpenseSheet> createState() => _HomeExpenseSheetState();
}

class _HomeExpenseSheetState extends ConsumerState<_HomeExpenseSheet> {
  late final _title = TextEditingController();
  late final _amount = TextEditingController();
  late final _note = TextEditingController();
  late DateTime _date = DateTime.now();
  late String _category = 'maintenance';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _title.text = widget.expense!.title;
      _amount.text = '${widget.expense!.cost?.round() ?? 0}';
      _note.text = widget.expense!.note;
      _date = widget.expense!.date;
      // Try to read a stored category back ("دسته: X · ...").
      final note = widget.expense!.note;
      const prefix = 'دسته: ';
      final idx = note.indexOf(prefix);
      if (idx >= 0) {
        final after = note.substring(idx + prefix.length);
        final end = after.indexOf(' · ');
        final cat = end >= 0 ? after.substring(0, end).trim() : after.trim();
        if (homeExpenseCategories.containsKey(cat)) {
          _category = cat;
          _note.text = end >= 0 ? after.substring(end + 3).trim() : '';
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final amount = NumberFormat.parse(_amount.text.trim());
    if (title.isEmpty || amount <= 0) return;
    setState(() => _busy = true);
    final parts = <String>['دسته: $_category'];
    final extra = _note.text.trim();
    if (extra.isNotEmpty) parts.add(extra);
    final record = CareRecord(
      id: widget.expense?.id ??
          ref.read(careStoreProvider.notifier).newId('home_expense'),
      assetId: widget.homeId,
      title: title,
      date: _date,
      cost: amount,
      note: parts.join(' · '),
      attachmentPaths: widget.expense?.attachmentPaths ?? const [],
    );
    await ref.read(careStoreProvider.notifier).saveRecord(record);
    if (!mounted) return;
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSheetTitle(
          title: widget.expense == null ? 'افزودن هزینه خانه' : 'ویرایش هزینه',
          subtitle: 'هزینه‌های تعمیر، نگهداری، تجهیزات خانه (بدون خوراکی).',
        ),
        CareField(controller: _title, label: 'عنوان', hint: 'مثلاً تعمیر سقف'),
        Row(
          children: [
            Expanded(
              child: CareField(
                controller: _amount,
                label: 'مبلغ',
                digitsOnly: true,
                keyboardType: TextInputType.number,
                ltr: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CareDateButton(
                label: 'تاریخ',
                date: _date,
                accent: careHomeColor,
                onPicked: (d) => setState(() => _date = d),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in homeExpenseCategories.entries)
              CareChip(
                label: entry.value,
                selected: _category == entry.key,
                accent: careHomeColor,
                onTap: () => setState(() => _category = entry.key),
              ),
          ],
        ),
        CareField(controller: _note, label: 'یادداشت (اختیاری)', maxLines: 2),
        CareSheetSubmit(
          label: widget.expense == null ? 'ثبت هزینه' : 'ذخیره',
          accent: careHomeColor,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}
