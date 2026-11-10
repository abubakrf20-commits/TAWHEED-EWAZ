import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';
import 'package:tawheeed/features/personal2/shared/report_renderer.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «پروندهٔ مشتری» — balance header, aging chip, credit-limit progress, the
/// ledger timeline with a running balance, receive-payment FIFO sheet, the
/// polite reminder and the statement export.
class ShopCustomerDetailScreen extends ConsumerStatefulWidget {
  const ShopCustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<ShopCustomerDetailScreen> createState() =>
      _ShopCustomerDetailScreenState();
}

class _ShopCustomerDetailScreenState
    extends ConsumerState<ShopCustomerDetailScreen> {
  ShopCustomer? _customer;
  int? _balance;
  List<OpenInvoice> _open = [];
  List<LedgerRow> _ledger = [];
  ShopSettingsRow? _settings;
  bool _loading = true;
  final GlobalKey _statementKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dao = ref.read(shopDaoProvider);
    final customer = await dao.customer(widget.customerId);
    final balance = await dao.customerBalance(widget.customerId);
    final open = await dao.openInvoices(widget.customerId);
    final ledger = await dao.ledger(widget.customerId);
    final settingsRow = await dao.settings();
    if (!mounted) return;
    setState(() {
      _customer = customer;
      _balance = balance;
      _open = open;
      _ledger = ledger.reversed.toList(); // oldest first for the running sum
      _settings = settingsRow;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: t.primary,
          iconTheme: IconThemeData(color: t.primary),
          title: Text(
            _customer?.name ?? 'مشتری',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              color: t.primary,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final balance = _balance ?? 0;
    final isDebtor = balance > 0;
    final isCreditor = balance < 0;
    final age = oldestDebtDays(openInvoices: _open, now: DateTime.now());
    final buckets = agingBucketsOf(
        openInvoices: _open, now: DateTime.now());
    final limit = _customer?.creditLimit;

    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
      children: [
        // Header: avatar, big balance with semantics, aging chip.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B3F45),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: Color(0xFF0E7C86), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      _customer!.name.characters.first,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDebtor
                              ? 'بدهکار'
                              : isCreditor
                                  ? 'بستانکار'
                                  : 'تسویه',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: .75),
                          ),
                        ),
                        Text(
                          NumberFormat.groupDigits('${balance.abs()}'),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 22),
                            fontWeight: FontWeight.w700,
                            color: isDebtor
                                ? const Color(0xFFF2B53A)
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (age != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'بدهی قدیمی: $age روز',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              if (limit != null && limit > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'سقف اعتبار: ${NumberFormat.groupDigits('$limit')} '
                  '(مصرف ${(balance * 100 ~/ limit).clamp(0, 999)}٪)',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: .8),
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(color: Colors.white.withValues(alpha: .25)),
                        FractionallySizedBox(
                          widthFactor: (balance / limit).clamp(0.0, 1.0),
                          child: Container(
                            color: balance > limit
                                ? const Color(0xFFC9462C)
                                : const Color(0xFF2E8B3D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _receivePayment,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B3D),
                ),
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text('دریافت وجه'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sendReminder,
                icon: const Icon(Icons.sms_outlined, size: 18),
                label: const Text('یادآوری مؤدبانه'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportStatement,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('صورت‌حساب'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _writeOff,
                icon: const Icon(Icons.handshake_outlined, size: 18),
                label: const Text('بخشش مانده'),
              ),
            ),
          ],
        ),
        if (buckets.any((b) => b > 0)) ...[
          const SizedBox(height: 14),
          const SectionHeader(title: 'سنین بدهی', accent: Color(0xFF0E7C86)),
          const SizedBox(height: 4),
          AppCard(
            child: MiniBarsForShop(
              items: [
                for (var i = 0; i < agingBuckets.length; i++)
                  if (buckets[i] > 0)
                    (
                      agingBuckets[i].$1,
                      buckets[i],
                    ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        const SectionHeader(title: 'دفتر حساب', accent: Color(0xFF0E7C86)),
        const SizedBox(height: 4),
        _timeline(context),
      ],
    );
  }

  /// The ledger timeline with the running balance (oldest → newest).
  Widget _timeline(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    if (_ledger.isEmpty) {
      return AppCard(
        child: Text(
          'حرکتی ثبت نشده.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: t.textMuted,
          ),
        ),
      );
    }
    // Running balance: the ledger IS the truth, so the running sum of the
    // entries up to each row IS that row's balance.
    var running = 0;
    final rows = <(LedgerRow, int)>[];
    for (final entry in _ledger) {
      running += entry.signedAmount;
      rows.add((entry, running));
    }
    final display = rows.reversed.toList(); // newest first for display

    return Column(
      children: [
        for (final (entry, after) in display)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  DuotoneIconTile(
                    accent: entry.signedAmount > 0
                        ? const Color(0xFFC9462C)
                        : const Color(0xFF2E8B3D),
                    icon: switch (entry.kind) {
                      'invoice' => Icons.receipt_rounded,
                      'payment' => Icons.payments_rounded,
                      'writeoff' => Icons.handshake_outlined,
                      'opening' => Icons.flag_rounded,
                      _ => Icons.tune_rounded,
                    },
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (entry.kind) {
                            'invoice' => 'فروش نسیه',
                            'payment' => 'دریافت',
                            'writeoff' => 'بخشش',
                            'opening' => 'افتتاحیه',
                            _ => 'تعدیل',
                          },
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                        Text(
                          '${jalaliLabelFa(entry.date)}'
                          '${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10,
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.signedAmount > 0 ? '+' : ''}'
                        '${NumberFormat.groupDigits('${entry.signedAmount}')}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: entry.signedAmount > 0
                              ? const Color(0xFFC9462C)
                              : const Color(0xFF2E8B3D),
                        ),
                      ),
                      Text(
                        'مانده: ${NumberFormat.groupDigits('$after')}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 9,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Receive payment: the FIFO preview list, then one DAO call.
  Future<void> _receivePayment() async {
    final t = TimeThemeKit.of(context).palette;
    final amountCtrl = TextEditingController();
    PaymentMethod method = PaymentMethod.cash;
    final noteCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.elevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final amount = int.tryParse(amountCtrl.text) ?? 0;
          final preview = amount <= 0
              ? null
              : allocateFifo(payment: amount, openInvoices: _open);
          return Padding(
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
                  Text(
                    'دریافت وجه از ${_customer!.name}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'مبلغ',
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
                          onSelected: (_) =>
                              setSheetState(() => method = m.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'یادداشت (اختیاری)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'تخصیص خودکار (قدیمی‌ترین اول):',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: t.textSecondary,
                      ),
                    ),
                    for (final slice in preview.slices)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'فاکتور ${slice.invoiceNumber}: '
                          '${NumberFormat.groupDigits('${slice.amount}')}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                    if (preview.advance > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'مازاد به عنوان پیش‌پرداخت: '
                          '${NumberFormat.groupDigits('${preview.advance}')}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: const Color(0xFF2F6FB5),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E8B3D)),
                    onPressed: amount <= 0
                        ? null
                        : () => Navigator.of(sheetContext).pop(true),
                    child: const Text('ثبت دریافت'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    final amount = int.tryParse(amountCtrl.text) ?? 0;
    await ref.read(shopDaoProvider).receivePayment(
          customerId: widget.customerId,
          amount: amount,
          method: method,
          date: DateTime.now(),
          note: noteCtrl.text.trim(),
        );
    _reload();
  }

  /// The polite reminder: 3 template variants in assets, editable in the
  /// sheet, shared via the system sheet. The app never sends anything.
  Future<void> _sendReminder() async {
    final t = TimeThemeKit.of(context).palette;
    final balance = _balance ?? 0;
    final oldest = _open.isEmpty
        ? DateTime.now()
        : _open
            .reduce((a, b) => a.date.isBefore(b.date) ? a : b)
            .date;
    var variant = 0;
    final ctrl = TextEditingController(
      text: reminderMessage(
        variant: 0,
        customerName: _customer!.name,
        balance: balance,
        oldestDateFa: jalaliLabelFa(oldest),
        shopName: _settings?.shopName.isEmpty ?? true
            ? 'فروشگاه ما'
            : _settings!.shopName,
      ),
    );

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
                Text(
                  'یادآوری مؤدبانه',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var v = 0; v < 3; v++)
                      ChoiceChip(
                        label: Text('متن ${v + 1}'),
                        selected: variant == v,
                        onSelected: (_) => setSheetState(() {
                          variant = v;
                          ctrl.text = reminderMessage(
                            variant: v,
                            customerName: _customer!.name,
                            balance: balance,
                            oldestDateFa: jalaliLabelFa(oldest),
                            shopName: _settings?.shopName.isEmpty ?? true
                                ? 'فروشگاه ما'
                                : _settings!.shopName,
                          );
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    helperText: 'متن قابل ویرایش است؛ ارسال با خودتان.',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E7C86)),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    ShareService.shareText(ctrl.text,
                        subject: 'یادآوری حساب');
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('اشتراک متن'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _writeOff() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بخشش مانده'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'مبلغ بخشش', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final amount = int.tryParse(ctrl.text.trim()) ?? 0;
    final noteCtrl = TextEditingController();
    if (!mounted) return;
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('دلیل بخشش (الزامی)'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
              labelText: 'یادداشت', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(noteCtrl.text.trim()),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    await ref.read(shopDaoProvider).writeOff(
          customerId: widget.customerId,
          amount: amount,
          note: note,
        );
    _reload();
  }

  /// The statement: image + PDF via the ReportRenderer, with the shop header.
  Future<void> _exportStatement() async {
    final t = TimeThemeKit.of(context).palette;
    final settings = _settings ?? const ShopSettingsRow();
    final entries = _ledger;
    var running = 0;
    final rows = <(LedgerRow, int)>[];
    for (final entry in entries) {
      running += entry.signedAmount;
      rows.add((entry, running));
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.elevated,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const SheetHandle(),
            ListTile(
              leading: const Icon(Icons.image_rounded),
              title: const Text('اشتراک تصویر'),
              onTap: () => Navigator.of(sheetContext).pop('image'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('PDF'),
              onTap: () => Navigator.of(sheetContext).pop('pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (choice == 'image') {
      final bytes = await ReportRenderer.capturePng(_statementKey);
      if (bytes == null) {
        messenger.showSnackBar(SnackBar(
          content: Text('ارسال تصویر ممکن نشد.',
              style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ));
        return;
      }
      await ReportRenderer.shareImage(
        bytes,
        fileName: 'statement-${_customer!.id}.png',
      );
      return;
    }

    const accent = PdfColor.fromInt(0xFF0E7C86);
    final pdf = await ReportRenderer.buildPdf(
      title: 'صورت‌حساب ${_customer!.name}',
      subtitle: settings.shopName,
      accent: const Color(0xFF0E7C86),
      body: [
        for (final (entry, after) in rows)
          pdfRow(
            '${jalaliLabelFa(entry.date)} · '
            '${switch (entry.kind) {
              'invoice' => 'فروش نسیه',
              'payment' => 'دریافت',
              'writeoff' => 'بخشش',
              'opening' => 'افتتاحیه',
              _ => 'تعدیل',
            }}',
            '${entry.signedAmount > 0 ? '+' : ''}'
            '${NumberFormat.groupDigits('${entry.signedAmount}')} '
            '(مانده ${NumberFormat.groupDigits('$after')})',
            accent,
          ),
        pw.Divider(),
        pdfRow(
          'ماندهٔ نهایی',
          NumberFormat.groupDigits('${_balance ?? 0}'),
          accent,
          bold: true,
        ),
      ],
    );
    await ReportRenderer.sharePdf(
      pdf,
      fileName: 'statement-${_customer!.id}.pdf',
    );
  }
}

/// A tiny bars row for the aging buckets (reuses the shared painter's row
/// model without importing the kids tool).
class MiniBarsForShop extends StatelessWidget {
  const MiniBarsForShop({super.key, required this.items});

  final List<(String, int)> items;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final max = items.fold<int>(1, (m, e) => e.$2 > m ? e.$2 : m);
    return Column(
      children: [
        for (final (label, value) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      NumberFormat.groupDigits('$value'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(color: t.outline.withValues(alpha: .3)),
                        FractionallySizedBox(
                          widthFactor: value / max,
                          child: Container(
                              color: const Color(0xFF0E7C86)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
