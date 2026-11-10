import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// One preview row: what the shopkeeper sees before approving the change.
///
/// It is computed with [bulkPriceAfter] — the same function the DAO writes
/// with — so «پیش‌نمایش» can never disagree with the posted prices.
class BulkPricePreviewRow {
  const BulkPricePreviewRow({
    required this.product,
    required this.newSell,
    required this.newBuy,
  });

  final ShopProduct product;
  final int newSell;
  final int newBuy;

  /// A negative result is skipped by the DAO (never a negative price).
  bool get skipped => newSell < 0 || newBuy < 0;
}

/// Builds the preview for the products the sheet was opened with.
List<BulkPricePreviewRow> bulkPricePreview({
  required List<ShopProduct> products,
  required int delta,
  required bool percent,
  required int roundingStep,
}) =>
    [
      for (final p in products)
        BulkPricePreviewRow(
          product: p,
          newSell: bulkPriceAfter(
            price: p.sellPrice,
            delta: delta,
            percent: percent,
            roundingStep: roundingStep,
          ),
          newBuy: bulkPriceAfter(
            price: p.buyPriceLast,
            delta: delta,
            percent: percent,
            roundingStep: roundingStep,
          ),
        ),
    ];

/// «تغییر قیمت گروهی» — percent or amount over the products currently listed,
/// with a diff preview and a one-tap undo of the whole batch.
Future<void> showShopBulkPriceSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<ShopProduct> products,
  required int roundingStep,
  required Future<void> Function() onApplied,
}) async {
  final t = TimeThemeKit.of(context).palette;
  final dao = ref.read(shopDaoProvider);
  final deltaCtrl = TextEditingController(text: '10');
  var percent = true;
  var applying = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.elevated,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final delta =
            int.tryParse(NumberFormat.toLatin(deltaCtrl.text.trim())) ?? 0;
        final preview = delta == 0 || products.isEmpty
            ? const <BulkPricePreviewRow>[]
            : bulkPricePreview(
                products: products,
                delta: delta,
                percent: percent,
                roundingStep: roundingStep,
              );
        final applied = preview.where((r) => !r.skipped).length;
        final changedRows = preview.where((r) => !r.skipped).take(6).toList();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  Text(
                    'تغییر قیمت گروهی',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'روی همان ${NumberFormat.groupDigits('${products.length}')} '
                    'کالایی که در فهرست می‌بینید اعمال می‌شود '
                    '(جستجو و فیلترها هم حساب می‌شوند).',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text(
                          'درصدی',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily, fontSize: 11),
                        ),
                        selected: percent,
                        onSelected: (_) => setSheetState(() => percent = true),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(
                          'مبلغی',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily, fontSize: 11),
                        ),
                        selected: !percent,
                        onSelected: (_) => setSheetState(() => percent = false),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: deltaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true),
                          textAlign: TextAlign.end,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: percent ? 'درصد (منفی = کاهش)' : 'مبلغ',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    percent
                        ? 'مثلاً ۱۰ یعنی همه ۱۰ ٪ گران‌تر، ۵- یعنی ۵ ٪ ارزان‌تر.'
                        : 'مثلاً ۵۰۰ یعنی ۵۰۰ به مبلغ هر واحد، ۵۰۰- یعنی ارزان‌تر.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textMuted,
                    ),
                  ),
                  if (roundingStep > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'گرد شدن به مضرب '
                        '${NumberFormat.groupDigits('$roundingStep')}',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: t.textMuted,
                        ),
                      ),
                    ),
                  if (changedRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Column(
                        children: [
                          for (final row in changedRows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 11,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${NumberFormat.groupDigits('${row.product.sellPrice}')}'
                                    ' → '
                                    '${NumberFormat.groupDigits('${row.newSell}')}',
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 11,
                                      color: row.newSell > row.product.sellPrice
                                          ? const Color(0xFF2E8B3D)
                                          : const Color(0xFFC9462C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (preview.length > changedRows.length)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'و ${NumberFormat.groupDigits('${preview.length - changedRows.length}')} کالای دیگر',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  color: t.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E7C86),
                    ),
                    onPressed: applying || applied == 0
                        ? null
                        : () async {
                            setSheetState(() => applying = true);
                            final batch = await dao.applyBulkPriceChange(
                              items: [
                                for (final row in preview)
                                  if (!row.skipped)
                                    (
                                      productId: row.product.id,
                                      oldSell: row.product.sellPrice,
                                      oldBuy: row.product.buyPriceLast,
                                    ),
                              ],
                              deltaPerUnit: delta,
                              percent: percent,
                              roundingStep: roundingStep,
                            );
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            await onApplied();
                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            if (batch == null) {
                              messenger.showSnackBar(SnackBar(
                                content: Text(
                                  'تغییر قیمت ثبت نشد.',
                                  style: TextStyle(
                                      fontFamily: AppTheme.fontFamily),
                                ),
                              ));
                              return;
                            }
                            messenger.showSnackBar(SnackBar(
                              content: Text(
                                'قیمت ${NumberFormat.groupDigits('$applied')} '
                                'کالا به‌روز شد.',
                                style:
                                    TextStyle(fontFamily: AppTheme.fontFamily),
                              ),
                              action: SnackBarAction(
                                label: 'واگرد',
                                onPressed: () async {
                                  await dao.undoBulkPriceChange(batch);
                                  await onApplied();
                                },
                              ),
                            ));
                          },
                    child: Text(
                      applying
                          ? 'در حال ثبت…'
                          : applied == 0
                              ? 'مقداری وارد کنید'
                              : 'اعمال روی ${NumberFormat.groupDigits('$applied')} کالا',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  deltaCtrl.dispose();
}
