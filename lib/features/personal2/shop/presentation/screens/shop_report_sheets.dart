import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_period_report.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_report_range.dart';
import 'package:tawheeed/features/personal2/shop/presentation/providers/shop_report_providers.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_home_screen.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The rows behind one report figure.
///
/// A numbers-only report is a dead end: «فروش خالص ۱۲٬۴۰۰٬۰۰۰» invites the
/// question "which invoices?", and the shopkeeper cannot answer it from the tab.
/// Every figure on the report opens this sheet with its own filter, and a tap
/// on a row opens the real receipt (the POS in view mode) — the same receipt the
/// customer got, not a second read-only copy.
class ShopInvoicesSheet extends ConsumerWidget {
  const ShopInvoicesSheet({
    super.key,
    required this.query,
    required this.title,
    this.note,
  });

  final ShopInvoiceQuery query;
  final String title;

  /// One line under the title — the filter's meaning in words («نسیه»، «چک»).
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final invoices = ref.watch(shopRangeInvoicesProvider(query));

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [note, query.range.label]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: invoices.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => FailureView(
                  id: 'shop_report_invoices_failed',
                  title: 'فهرست فاکتورها باز نشد',
                  detail: 'فاکتورها پاک نشده‌اند؛ فقط خواندنشان ناموفق بود.',
                  onRetry: () => ref.invalidate(shopRangeInvoicesProvider(query)),
                  error: e,
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        'در این دوره فاکتوری با این شرط نیست.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: t.textMuted,
                        ),
                      ),
                    );
                  }
                  final total = rows.fold<int>(0, (s, r) => s + r.total);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              '${rows.length} فاکتور',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                color: t.textMuted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              NumberFormat.groupDigits('$total'),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) =>
                              _InvoiceRow(invoice: rows[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final ShopInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final accent =
        invoice.isReturn ? const Color(0xFFC9462C) : const Color(0xFF0E7C86);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () {
        // Leave the sheet before pushing the POS: two stacked routes with the
        // same receipt would read as a bug, and the sheet is a drill-down, not
        // a place to stay.
        Navigator.of(context).pop();
        openPos(context, invoiceId: invoice.id);
      },
      child: Row(
        children: [
          DuotoneIconTile(
            accent: accent,
            icon: invoice.isReturn
                ? Icons.undo_rounded
                : Icons.receipt_long_rounded,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.number,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  invoice.isReturn
                      ? 'برگشت · ${jalaliLabelFa(invoice.date)}'
                      : jalaliLabelFa(invoice.date),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.groupDigits('${invoice.total}'),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// «کالاهای کندگرد» — stock that held money through the window without selling.
///
/// The list answers the inventory question the numbers cannot: not "how much
/// did I sell" but "what is my money sitting in". Value is `qty × avgCost`, the
/// cost basis — the retail price would count profit that has not happened yet.
class ShopSlowMoversSheet extends ConsumerWidget {
  const ShopSlowMoversSheet({super.key, required this.range});

  final ShopReportRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final movers = ref.watch(shopSlowMoversProvider(range));

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کالاهای کندگرد',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'کالاهایی که از ${range.label} فروشی نداشته‌اند و هنوز '
                    'موجودی دارند.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: movers.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => FailureView(
                  id: 'shop_slow_movers_failed',
                  title: 'فهرست کالاهای کندگرد باز نشد',
                  detail: 'موجودی و فروش‌ها پاک نشده‌اند؛ فقط خواندنشان '
                      'ناموفق بود.',
                  onRetry: () => ref.invalidate(shopSlowMoversProvider(range)),
                  error: e,
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'همهٔ موجودی در این دوره فروش داشته — چیزی روی دست '
                          'نمانده است.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: t.textMuted,
                          ),
                        ),
                      ),
                    );
                  }
                  final tied =
                      rows.fold<int>(0, (s, r) => s + r.tiedUpValue);
                  final now = DateTime.now();
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Row(
                          children: [
                            Text(
                              '${rows.length} کالا',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                color: t.textMuted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${NumberFormat.groupDigits('$tied')} '
                              'سرمایهٔ خوابیده',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: t.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) =>
                              _SlowMoverRow(mover: rows[i], now: now),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlowMoverRow extends StatelessWidget {
  const _SlowMoverRow({required this.mover, required this.now});

  final ShopSlowMover mover;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final idle = mover.idleDays(now);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          DuotoneIconTile(
            accent: const Color(0xFF8A5A44),
            icon: Icons.inventory_2_outlined,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mover.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${qtyMilliToText(mover.stockMilli)} عدد · '
                  '${idle == null ? 'هرگز فروش نرفته' : '$idle روز بی‌حرکت'}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.groupDigits('${mover.tiedUpValue}'),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: t.outline.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
