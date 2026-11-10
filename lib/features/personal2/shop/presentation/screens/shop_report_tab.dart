import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shared/report_renderer.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_period_report.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_report_range.dart';
import 'package:tawheeed/features/personal2/shop/presentation/providers/shop_report_providers.dart';
import 'package:tawheeed/features/personal2/shop/presentation/screens/shop_report_sheets.dart';
import 'package:tawheeed/features/personal2/shop/services/shop_export.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/shamsi_date_picker.dart';

/// «گزارش» — the shop's numbers for a window the user chooses.
///
/// The stage-2 tab could only say "today / 7 days / 30 days", as one column of
/// totals, which is not a report: «فروش مهرماه چقدر بود؟» could not be asked and
/// «سود چقدر شد؟» had no answer at all. This version is built around one window
/// value ([ShopReportRange]):
///
///  * presets (today / 7 / 30 / **this Jalali month**) plus a **custom Jalali
///    range** picked through the app's own picker;
///  * the five figures that matter — net sales, gross profit, net profit,
///    returns/discount, expenses — with a previous-window comparison where one
///    is meaningful, and the average ticket;
///  * **drill-downs**: net sales, every payment method and every top product
///    open the invoices behind that number;
///  * **کالاهای کندگرد** — the stock that held money without selling;
///  * two exports: the PDF summary that already existed, and the full CSV ZIP.
class ShopReportTab extends ConsumerWidget {
  const ShopReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final selection = ref.watch(shopReportSelectionProvider);
    final range = selection.range;
    final report = ref.watch(shopPeriodReportProvider(range));

    Future<void> editRange() async {
      final picked = await _pickRange(context, range);
      if (picked != null) {
        ref.read(shopReportSelectionProvider.notifier).selectRange(picked);
      }
    }

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 110),
      children: [
        _PresetChips(
          selected: selection.preset,
          onSelected: (preset) {
            if (preset == ShopReportPreset.custom) {
              editRange();
            } else {
              ref.read(shopReportSelectionProvider.notifier).selectPreset(preset);
            }
          },
        ),
        const SizedBox(height: 8),
        _RangeLine(range: range, onEdit: editRange),
        const SizedBox(height: 12),
        report.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => FailureView(
            id: 'shop_report_failed',
            title: 'گزارش باز نشد',
            detail: 'فاکتورها و هزینه‌ها پاک نشده‌اند؛ فقط خواندنشان ناموفق '
                'بود.',
            onRetry: () => ref.invalidate(shopPeriodReportProvider(range)),
            error: e,
          ),
          // `null` is the DAO's own failure (it logs and returns null rather
          // than throwing), and a screen of zeros would read like a real
          // answer, so both paths say the same thing.
          data: (data) => data == null
              ? FailureView(
                  id: 'shop_report_failed',
                  title: 'گزارش باز نشد',
                  detail: 'فاکتورها و هزینه‌ها پاک نشده‌اند؛ فقط خواندنشان '
                      'ناموفق بود.',
                  onRetry: () =>
                      ref.invalidate(shopPeriodReportProvider(range)),
                )
              : _ReportBody(report: data, range: range),
        ),
        const SizedBox(height: 12),
        if (report.hasValue && report.value != null)
          _ExportButtons(report: report.value!, range: range),
        const SizedBox(height: 10),
        Text(
          'همهٔ ارقام از فاکتورهای ثبت‌شده (بدون فاکتور باطل‌شده) محاسبه '
          'می‌شود؛ برگشتی و تخفیف از فروش کم شده‌اند.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            height: 1.6,
            color: t.textMuted,
          ),
        ),
      ],
    );
  }

  /// Two Jalali picks — «از» then «تا» — and a window that is never backwards.
  ///
  /// [showShamsiDatePicker] takes no bounds (other features use it for expiry
  /// dates years ahead), so the ordering is fixed here: a `to` before `from`
  /// swaps them instead of producing an empty window that silently reports
  /// zero — which reads exactly like a real day with no sales.
  Future<ShopReportRange?> _pickRange(
    BuildContext context,
    ShopReportRange current,
  ) async {
    final from = await showShamsiDatePicker(
      context: context,
      initialDate: current.from,
    );
    if (from == null || !context.mounted) return null;
    final to = await showShamsiDatePicker(
      context: context,
      initialDate: current.to.isBefore(from) ? from : current.to,
    );
    if (to == null) return null;
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return end.isBefore(start)
        ? ShopReportRange(from: end, to: start)
        : ShopReportRange(from: start, to: end);
  }
}

// ── Period selector ─────────────────────────────────────────────────────

class _PresetChips extends StatelessWidget {
  const _PresetChips({required this.selected, required this.onSelected});

  final ShopReportPreset selected;
  final ValueChanged<ShopReportPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    // One horizontally scrollable row instead of a SegmentedButton: five
    // labels in a fixed segment control overflow at 320dp, and the custom
    // range entry is a verb («بازهٔ دلخواه») rather than a value.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          for (final preset in ShopReportPreset.values) ...[
            ChoiceChip(
              label: Text(
                preset.label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                ),
              ),
              selected: selected == preset,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onSelected(preset),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _RangeLine extends StatelessWidget {
  const _RangeLine({required this.range, required this.onEdit});

  final ShopReportRange range;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: onEdit,
      child: Row(
        children: [
          DuotoneIconTile(
            accent: const Color(0xFF0E7C86),
            icon: Icons.date_range_rounded,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              range.isSingleDay
                  ? range.label
                  : '${range.label} · ${range.dayCount} روز',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: t.textPrimary,
              ),
            ),
          ),
          Icon(Icons.edit_calendar_rounded, size: 16, color: t.textMuted),
        ],
      ),
    );
  }
}

// ── Figures ─────────────────────────────────────────────────────────────

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.range});

  final ShopPeriodReport report;
  final ShopReportRange range;

  @override
  Widget build(BuildContext context) {
    final figures = report.figures;
    final change = report.salesChangePercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Figure(
                label: 'فروش خالص',
                value: figures.netSales,
                color: const Color(0xFF0E7C86),
                onTap: () => _openInvoices(
                  context,
                  ShopInvoiceQuery(range: range, includeReturns: false),
                  'فاکتورهای فروش',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Figure(
                label: 'سود ناخالص',
                value: figures.grossProfit,
                color: const Color(0xFF2E8B3D),
                hint: report.grossMarginPercent == null
                    ? null
                    : 'حاشیه ${report.grossMarginPercent}٪',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Figure(
                label: 'سود خالص',
                value: figures.netProfit,
                color: const Color(0xFF2F6FB5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _ComparisonLine(change: change, hasPrevious: report.hasPreviousData),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Figure(
                label: 'برگشتی',
                value: figures.returnTotal,
                color: const Color(0xFFC9462C),
                compact: true,
                hint: report.returnCount == 0
                    ? 'ندارد'
                    : '${report.returnCount} فاکتور',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Figure(
                label: 'تخفیف',
                value: figures.discountTotal,
                color: const Color(0xFFB07A35),
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Figure(
                label: 'هزینه',
                value: figures.expenseTotal,
                color: const Color(0xFF8E5BA6),
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          report.invoiceCount == 0
              ? 'در این دوره فروشی ثبت نشده است.'
              : '${report.invoiceCount} فاکتور · میانگین '
                  '${NumberFormat.groupDigits('${report.averageTicket}')}',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            color: TimeThemeKit.of(context).palette.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        _PaymentMixCard(report: report, range: range),
        const SizedBox(height: 12),
        _TopProductsCard(report: report, range: range),
        const SizedBox(height: 12),
        _SlowMoversCard(range: range),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
    this.hint,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final int value;
  final Color color;
  final String? hint;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: EdgeInsets.all(compact ? 9 : 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: t.textMuted,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_left_rounded, size: 14, color: t.textMuted),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              NumberFormat.groupDigits('$value'),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 9,
                color: t.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// «۲۳٪ بیشتر از دورهٔ پیش» — or the honest alternative when there is nothing
/// to compare with. A percentage against zero (or against a window with no
/// invoices) would print «۱۰۰٪» and mean nothing.
class _ComparisonLine extends StatelessWidget {
  const _ComparisonLine({required this.change, required this.hasPrevious});

  final int? change;
  final bool hasPrevious;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final value = change;
    final String text;
    final Color color;
    final IconData icon;
    if (value == null) {
      text = hasPrevious
          ? 'دورهٔ پیش فروشی نداشت؛ درصد تغییر معنا ندارد.'
          : 'دورهٔ پیش داده‌ای ندارد.';
      color = t.textMuted;
      icon = Icons.remove_rounded;
    } else if (value > 0) {
      text = '$value٪ بیشتر از دورهٔ پیش';
      color = const Color(0xFF2E8B3D);
      icon = Icons.trending_up_rounded;
    } else if (value < 0) {
      text = '${value.abs()}٪ کمتر از دورهٔ پیش';
      color = const Color(0xFFC9462C);
      icon = Icons.trending_down_rounded;
    } else {
      text = 'به اندازهٔ دورهٔ پیش';
      color = t.textSecondary;
      icon = Icons.drag_handle_rounded;
    }
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Payment mix ─────────────────────────────────────────────────────────

class _PaymentMixCard extends StatelessWidget {
  const _PaymentMixCard({required this.report, required this.range});

  final ShopPeriodReport report;
  final ShopReportRange range;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final mix = report.byMethod;
    final total = mix.values.fold<int>(0, (s, v) => s + v);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle('ترکیب پرداخت', trailing: 'در این دوره'),
          const SizedBox(height: 8),
          if (mix.isEmpty)
            Text(
              'پرداختی ثبت نشده.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: t.textMuted,
              ),
            )
          else
            for (final entry in mix.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openInvoices(
                    context,
                    ShopInvoiceQuery(
                      range: range,
                      method: entry.key == PaymentMethod.other
                          ? null
                          : entry.key,
                      creditOnly: entry.key == PaymentMethod.other,
                    ),
                    'فاکتورهای ${_methodLabel(entry.key)}',
                    note: entry.key == PaymentMethod.other
                        ? 'فروشی که پرداختی برایش ثبت نشده'
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(
                          _methodLabel(entry.key),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            height: 6,
                            child: Stack(
                              children: [
                                Container(
                                    color: t.outline.withValues(alpha: .3)),
                                FractionallySizedBox(
                                  widthFactor: total <= 0
                                      ? 0
                                      : (entry.value / total).clamp(0.0, 1.0),
                                  child: Container(
                                    color: const Color(0xFF0E7C86),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NumberFormat.groupDigits('${entry.value}'),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: t.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _methodLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => 'نقد',
        PaymentMethod.card => 'کارت',
        PaymentMethod.transfer => 'انتقال',
        PaymentMethod.cheque => 'چک',
        PaymentMethod.other => 'نسیه',
      };
}

// ── Top products ────────────────────────────────────────────────────────

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.report, required this.range});

  final ShopPeriodReport report;
  final ShopReportRange range;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle('پرفروش‌ترین‌ها', trailing: 'بر اساس مبلغ'),
          const SizedBox(height: 8),
          if (report.topProducts.isEmpty)
            Text(
              'فروشی در این دوره ثبت نشده.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: t.textMuted,
              ),
            )
          else
            for (var i = 0; i < report.topProducts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openInvoices(
                    context,
                    ShopInvoiceQuery(
                      range: range,
                      productName: report.topProducts[i].name,
                      includeReturns: false,
                    ),
                    report.topProducts[i].name,
                    note: 'فاکتورهایی که این کالا در آن‌ها فروش رفته',
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        child: Text(
                          '${i + 1}.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: t.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          report.topProducts[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${qtyMilliToText(report.topProducts[i].qtyMilli)} · '
                        '${NumberFormat.groupDigits('${report.topProducts[i].total}')}',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          color: t.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_left_rounded,
                          size: 14, color: t.textMuted),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ── Slow movers ─────────────────────────────────────────────────────────

class _SlowMoversCard extends ConsumerWidget {
  const _SlowMoversCard({required this.range});

  final ShopReportRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final movers = ref.watch(shopSlowMoversProvider(range));
    final rows = movers.value ?? const <ShopSlowMover>[];
    final tied = rows.fold<int>(0, (s, r) => s + r.tiedUpValue);
    return AppCard(
      onTap: movers.isLoading
          ? null
          : () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: t.card,
                builder: (_) => ShopSlowMoversSheet(range: range),
              ),
      child: Row(
        children: [
          const DuotoneIconTile(
            accent: Color(0xFF8A5A44),
            icon: Icons.inventory_2_outlined,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'کالاهای کندگرد',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  movers.isLoading
                      ? 'در حال بررسی موجودی…'
                      : rows.isEmpty
                          ? 'همهٔ موجودی در این دوره فروش داشته.'
                          : '${rows.length} کالا · '
                              '${NumberFormat.groupDigits('$tied')} سرمایهٔ خوابیده',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, size: 16, color: t.textMuted),
        ],
      ),
    );
  }
}

// ── Exports ─────────────────────────────────────────────────────────────

class _ExportButtons extends ConsumerStatefulWidget {
  const _ExportButtons({required this.report, required this.range});

  final ShopPeriodReport report;
  final ShopReportRange range;

  @override
  ConsumerState<_ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends ConsumerState<_ExportButtons> {
  bool _busy = false;

  String get _fileNameStem {
    final from = widget.range.from;
    final to = widget.range.to;
    String two(int v) => v.toString().padLeft(2, '0');
    return 'shop-${from.year}${two(from.month)}${two(from.day)}'
        '-${to.year}${two(to.month)}${two(to.day)}';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(fontFamily: AppTheme.fontFamily)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _sharePdf,
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('اشتراک خلاصهٔ دوره (PDF)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _shareZip,
          icon: const Icon(Icons.folder_zip_rounded, size: 18),
          label: const Text('پشتیبان کامل CSV (ZIP)'),
        ),
      ],
    );
  }

  Future<void> _shareZip() async {
    setState(() => _busy = true);
    try {
      final db = ref.read(shop3DaoProvider).db;
      final bytes = await ShopCsvArchive.build(db);
      final shared = await ShopCsvArchive.share(
        bytes,
        fileName: '$_fileNameStem-csv.zip',
      );
      if (!shared) _toast('ارسال فایل ممکن نشد.');
    } catch (e) {
      AppLogger.warning('ShopReport', 'csv zip failed: $e');
      _toast('ساخت فایل CSV ممکن نشد.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _busy = true);
    final report = widget.report;
    final figures = report.figures;
    try {
      const accent = PdfColor.fromInt(0xFF0E7C86);
      final pdf = await ReportRenderer.buildPdf(
        title: 'گزارش فروش',
        subtitle: widget.range.label,
        accent: const Color(0xFF0E7C86),
        body: [
          pdfRow('فروش خالص', _money(figures.netSales), accent, bold: true),
          pdfRow('سود ناخالص', _money(figures.grossProfit), accent),
          pdfRow('سود خالص', _money(figures.netProfit), accent, bold: true),
          pw.SizedBox(height: 6),
          pdfRow('برگشتی', _money(figures.returnTotal), accent),
          pdfRow('تخفیف', _money(figures.discountTotal), accent),
          pdfRow('هزینه', _money(figures.expenseTotal), accent),
          pw.SizedBox(height: 6),
          pdfRow('تعداد فاکتور', '${report.invoiceCount}', accent),
          pdfRow('میانگین فاکتور', _money(report.averageTicket), accent),
          if (report.hasPreviousData && report.salesChangePercent != null)
            pdfRow(
              'تغییر نسبت به دورهٔ پیش',
              '${report.salesChangePercent}٪',
              accent,
            ),
          pw.SizedBox(height: 8),
          for (final entry in report.byMethod.entries)
            pdfRow(
              _PaymentMixCard._methodLabel(entry.key),
              _money(entry.value),
              accent,
            ),
          pw.SizedBox(height: 8),
          for (var i = 0; i < report.topProducts.length; i++)
            pdfRow(
              '${i + 1}. ${report.topProducts[i].name}',
              '${qtyMilliToText(report.topProducts[i].qtyMilli)} · '
                  '${_money(report.topProducts[i].total)}',
              accent,
            ),
        ],
      );
      final shared = await ReportRenderer.sharePdf(
        pdf,
        fileName: '$_fileNameStem.pdf',
        subject: 'گزارش فروش — ${widget.range.label}',
      );
      if (!shared) _toast('ارسال فایل ممکن نشد.');
    } catch (e, st) {
      AppLogger.error('ShopReportTab.shareSummary', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ساخت خلاصه ممکن نشد.',
              style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _money(int value) => NumberFormat.groupDigits('$value');
}

// ── Small shared pieces ─────────────────────────────────────────────────

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 9,
              color: t.textMuted,
            ),
          ),
      ],
    );
  }
}

/// Opens the invoice list for [query]. One helper so every figure's drill-down
/// uses the same sheet shape (and the same "tap a row → the real receipt").
void _openInvoices(
  BuildContext context,
  ShopInvoiceQuery query,
  String title, {
  String? note,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TimeThemeKit.of(context).palette.card,
    builder: (_) => ShopInvoicesSheet(query: query, title: title, note: note),
  );
}
