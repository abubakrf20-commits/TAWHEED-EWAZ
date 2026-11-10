import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shared/report_renderer.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/presentation/providers/shop_providers.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The success sheet after posting: the receipt preview, then share
/// (image / PDF / text) and «فروش بعدی».
///
/// The receipt reads the POSTED rows — never the cart — so what the customer
/// sees is exactly what the database recorded (SHOP_DOMAIN.md §3).
class ShopReceiptSheet extends ConsumerStatefulWidget {
  const ShopReceiptSheet({super.key, required this.posted});

  final PostedInvoice posted;

  @override
  ConsumerState<ShopReceiptSheet> createState() => _ShopReceiptSheetState();
}

class _ShopReceiptSheetState extends ConsumerState<ShopReceiptSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;
  ShopCustomer? _customer;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    final id = widget.posted.invoice.customerId;
    if (id == null) return;
    final customer = await ref.read(shopDaoProvider).customer(id);
    if (!mounted) return;
    setState(() => _customer = customer);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final invoice = widget.posted.invoice;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 6),
            RepaintBoundary(
              key: _cardKey,
              child: _receiptCard(context),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sharing ? null : _shareImage,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E7C86),
                    ),
                    icon: const Icon(Icons.image_rounded, size: 18),
                    label: const Text('اشتراک تصویر'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : _sharePdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : _shareText,
                    icon: const Icon(Icons.text_snippet_rounded, size: 18),
                    label: const Text('متن'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B3F45),
              ),
              child: Text(
                'فروش بعدی',
                style: TextStyle(fontFamily: AppTheme.fontFamily),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'فاکتور ${invoice.number} · '
                '${jalaliLabelFa(invoice.date)}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: t.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptCard(BuildContext context) {
    final settings = ref.watch(shopSettingsProvider).value;
    final invoice = widget.posted.invoice;
    final credit = _creditRemaining();

    return Container(
      // Printed paper, like the other share cards.
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6D9C6), width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              (settings?.shopName.isNotEmpty ?? false)
                  ? settings!.shopName
                  : 'حساب مغازه',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF263238),
              ),
            ),
          ),
          if (settings?.phone.isNotEmpty ?? false)
            Center(
              child: Text(
                settings!.phone,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: const Color(0xFF78909C),
                ),
              ),
            ),
          const Divider(height: 16, color: Color(0xFFE6D9C6)),
          _row('شماره فاکتور', invoice.number),
          _row('تاریخ', jalaliLabelFa(invoice.date)),
          if (_customer != null) _row('خریدار', _customer!.name),
          const Divider(height: 16, color: Color(0xFFE6D9C6)),
          for (final item in widget.posted.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.nameSnapshot,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: const Color(0xFF263238),
                      ),
                    ),
                  ),
                  Text(
                    '${qtyMilliToText(item.qtyMilli)} × '
                    '${NumberFormat.groupDigits('${item.unitPrice}')} = '
                    '${NumberFormat.groupDigits('${item.lineTotal}')}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      color: const Color(0xFF263238),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 16, color: Color(0xFFE6D9C6)),
          _row('جمع کل', NumberFormat.groupDigits('${invoice.subtotal}')),
          if (invoice.discountTotal > 0)
            _row('تخفیف', '−${NumberFormat.groupDigits('${invoice.discountTotal}')}'),
          if (invoice.roundingAdj != 0)
            _row('گردهمانده',
                NumberFormat.groupDigits('${invoice.roundingAdj}')),
          _row('قابل پرداخت',
              NumberFormat.groupDigits('${invoice.total}'), bold: true),
          if (credit != null) ...[
            const Divider(height: 16, color: Color(0xFFE6D9C6)),
            _row(
              'ماندهٔ حساب',
              credit == 0
                  ? 'تسویه'
                  : credit > 0
                      ? 'بدهکار ${NumberFormat.groupDigits('$credit')}'
                      : 'بستانکار ${NumberFormat.groupDigits('${-credit}')}',
              bold: true,
            ),
          ],
          if (settings?.receiptFooterText.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                settings!.receiptFooterText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: const Color(0xFF78909C),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Center(
            child: Text(
              ShareService.signatureName,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 9,
                color: const Color(0xFFB0A08C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The customer's balance after this invoice — shown only for credit sales.
  int? _creditRemaining() {
    final invoice = widget.posted.invoice;
    if (invoice.customerId == null) return null;
    return _customerBalanceAfter;
  }

  int? _customerBalanceAfter;

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: const Color(0xFF78909C),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: bold ? 12 : 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF263238),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _sharing = true);
    try {
      final bytes = await ReportRenderer.capturePng(_cardKey);
      if (bytes == null) {
        if (mounted) ShareService.showImageFailure(context);
        return;
      }
      await ReportRenderer.shareImage(
        bytes,
        fileName: 'receipt-${widget.posted.invoice.number}.png',
        text: 'فاکتور ${widget.posted.invoice.number}\n'
            '${ShareService.channelBlock}',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _sharing = true);
    try {
      final settings = ref.read(shopSettingsProvider).value;
      final invoice = widget.posted.invoice;
      final Uint8List pdf = await ReportRenderer.buildPdf(
        title: settings?.shopName.isNotEmpty == true
            ? settings!.shopName
            : 'رسید فروش',
        subtitle: 'فاکتور ${invoice.number} · '
            '${jalaliLabelFa(invoice.date)}',
        accent: const Color(0xFF0E7C86),
        pageSize: ReportPageSize.a5,
        multiPage: false,
        body: [
          for (final item in widget.posted.items)
            pdfRow(
              '${item.nameSnapshot} (${qtyMilliToText(item.qtyMilli)})',
              NumberFormat.groupDigits('${item.lineTotal}'),
              const PdfColor.fromInt(0xFF0E7C86),
            ),
          pw.Divider(),
          pdfRow('جمع کل', NumberFormat.groupDigits('${invoice.subtotal}'),
              const PdfColor.fromInt(0xFF0E7C86)),
          if (invoice.discountTotal > 0)
            pdfRow('تخفیف', '−${NumberFormat.groupDigits('${invoice.discountTotal}')}',
                const PdfColor.fromInt(0xFF0E7C86)),
          pdfRow(
            'قابل پرداخت',
            NumberFormat.groupDigits('${invoice.total}'),
            const PdfColor.fromInt(0xFF0E7C86),
            bold: true,
          ),
          if (settings?.receiptFooterText.isNotEmpty == true)
            pw.SizedBox(height: 8),
          if (settings?.receiptFooterText.isNotEmpty == true)
            pw.Text(
              settings!.receiptFooterText,
              textDirection: pw.TextDirection.rtl,
              style: const pw.TextStyle(fontSize: 9),
            ),
        ],
      );
      await ReportRenderer.sharePdf(
        pdf,
        fileName: 'receipt-${invoice.number}.pdf',
      );
    } catch (e, st) {
      AppLogger.error('ShopReceiptSheet.sharePdf', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ساخت PDF ممکن نشد.',
              style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareText() async {
    final invoice = widget.posted.invoice;
    final buffer = StringBuffer()
      ..writeln('فاکتور ${invoice.number} — ${jalaliLabelFa(invoice.date)}');
    for (final item in widget.posted.items) {
      buffer.writeln(
        '${item.nameSnapshot} ${qtyMilliToText(item.qtyMilli)} × '
        '${NumberFormat.groupDigits('${item.unitPrice}')} = '
        '${NumberFormat.groupDigits('${item.lineTotal}')}',
      );
    }
    buffer.writeln('قابل پرداخت: ${NumberFormat.groupDigits('${invoice.total}')}');
    await ShareService.shareText(
      '$buffer\n${ShareService.appLine('حساب مغازه')}',
      subject: 'فاکتور ${invoice.number}',
    );
  }
}
