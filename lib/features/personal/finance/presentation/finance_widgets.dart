import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal/finance/finance_engine.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/presentation/finance_style.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Money text: the user's currency unit, thousands separators, and an LTR
/// isolate so «۱٬۲۰۰٬۰۰۰ تومان» never reorders inside a Persian sentence.
class FinanceAmount extends StatelessWidget {
  const FinanceAmount({
    super.key,
    required this.value,
    this.unit,
    this.color,
    this.size = 13,
    this.weight = FontWeight.w700,
    this.strike = false,
  });

  final double value;

  /// Currency word. Omitted → the amount only (the hero prints its own unit).
  final String? unit;
  final Color? color;
  final double size;
  final FontWeight weight;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    final text = NumberFormat.ltrIsolated(
      unit == null
          ? NumberFormat.formatPlain(value)
          : NumberFormat.formatMoney(value, unit!),
    );
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, size),
        fontWeight: weight,
        color: color ?? TimeThemeKit.of(context).palette.textPrimary,
        decoration: strike ? TextDecoration.lineThrough : null,
      ),
    );
  }
}

/// The hero: what must be paid in the next 30 days, split by kind.
class FinanceHero extends StatelessWidget {
  const FinanceHero({
    super.key,
    required this.total,
    required this.breakdown,
    required this.receivable,
    required this.overdueCount,
    required this.unit,
    this.onTapOverdue,
  });

  final double total;
  final Map<ObligationKind, double> breakdown;
  final double receivable;
  final int overdueCount;
  final String unit;
  final VoidCallback? onTapOverdue;

  @override
  Widget build(BuildContext context) {
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sum = entries.fold<double>(0, (s, e) => s + e.value);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.darkWalnut,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'تعهدات ۳۰ روز آینده',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: Colors.white.withValues(alpha: .72),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (overdueCount > 0)
                GestureDetector(
                  onTap: onTapOverdue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.darkError.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$overdueCount عقب‌افتاده',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 9),
                        color: const Color(0xFFFFC9C0),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  NumberFormat.ltrIsolated(NumberFormat.formatPlain(total)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 26),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: Colors.white.withValues(alpha: .7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sum > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final e in entries)
                      Expanded(
                        flex: math.max(1, ((e.value / sum) * 1000).round()),
                        child: Container(color: financeKindColor(e.key)),
                      ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final e in entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: financeKindColor(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${e.key.labelFa} '
                      '${sum <= 0 ? '۰' : NumberFormat.ltrIsolated('${((e.value / sum) * 100).round()}')}٪',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 9),
                        color: Colors.white.withValues(alpha: .78),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (receivable > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.south_west,
                      size: 12, color: Colors.white.withValues(alpha: .8)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'دریافتنی‌ها: '
                      '${NumberFormat.formatMoney(receivable, unit)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        color: Colors.white.withValues(alpha: .88),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small kind label («قسط» / «چک» …) in that kind's colour.
class FinanceKindChip extends StatelessWidget {
  const FinanceKindChip({super.key, required this.kind});

  final ObligationKind kind;

  @override
  Widget build(BuildContext context) {
    final color = financeKindColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        kind.labelFa,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 9),
          fontWeight: FontWeight.w600,
          color: dsContentColor(context, color),
        ),
      ),
    );
  }
}

/// One timeline row: date block, title, chip, remaining text, amount, tick.
class FinanceTimelineRow extends StatelessWidget {
  const FinanceTimelineRow({
    super.key,
    required this.obligation,
    required this.now,
    required this.onTogglePaid,
    this.onTap,
    this.unit,
  });

  final Obligation obligation;
  final DateTime now;
  final VoidCallback onTogglePaid;
  final VoidCallback? onTap;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final kindColor = financeKindColor(obligation.kind);
    final days = financeDaysUntil(obligation.dueDate, now);
    final j = Jalali.fromDateTime(obligation.dueDate);
    final monthName = DateConstants.persianMonths[j.month - 1];
    final isOverdue = days < 0;
    final lateColor = isOverdue ? t.primary : t.textMuted;

    String remaining;
    if (obligation.isPaid) {
      remaining = 'پرداخت شد';
    } else if (isOverdue) {
      remaining = '${-days} روز دیر';
    } else if (days == 0) {
      remaining = 'امروز';
    } else {
      remaining = '$days روز دیگر';
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: kindColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  NumberFormat.ltrIsolated('${j.day}'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: dsContentColor(context, kindColor),
                  ),
                ),
                Text(
                  monthName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 8),
                    color: dsContentColor(context, kindColor)
                        .withValues(alpha: .8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        obligation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                          decoration: obligation.isPaid
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    FinanceKindChip(kind: obligation.kind),
                    const SizedBox(width: 5),
                    if (obligation.counterparty.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          obligation.counterparty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: t.textMuted,
                          ),
                        ),
                      ),
                      Text(
                        ' · ',
                        style: TextStyle(color: t.textMuted, fontSize: 10),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        remaining,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10),
                          fontWeight: isOverdue ? FontWeight.w700 : null,
                          color: lateColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: FinanceAmount(
                    value: obligation.amount,
                    unit: unit,
                    size: 11,
                    color: obligation.direction == ObligationDirection.receive
                        ? t.primary
                        : t.textPrimary,
                    strike: obligation.isPaid,
                  ),
                ),
                if (obligation.direction == ObligationDirection.receive)
                  Text(
                    'دریافتی',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 8),
                      color: t.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (obligation.attachmentPaths.isNotEmpty)
            IconButton(
              tooltip: 'پیوست‌ها',
              icon: const Icon(Icons.photo_outlined, size: 18),
              onPressed: () => showAttachmentViewer(
                context,
                obligation.attachmentPaths,
              ),
            ),
          const SizedBox(width: 4),
          Semantics(
            label: obligation.isPaid ? 'برگرداندن پرداخت' : 'پرداخت شد',
            button: true,
            child: InkWell(
              onTap: onTogglePaid,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  obligation.isPaid
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: obligation.isPaid
                      ? dsContentColor(context, financeLoanColor)
                      : t.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Six-bar preview of the next Jalali months, drawn without a chart package.
class FinanceMonthBars extends StatelessWidget {
  const FinanceMonthBars({
    super.key,
    required this.totals,
    required this.unit,
    this.height = 116,
  });

  final List<FinanceMonthTotal> totals;
  final String unit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final maxValue =
        totals.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    if (totals.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final item in totals)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      item.total <= 0
                          ? '—'
                          : NumberFormat.formatPlain(item.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 8),
                        color: t.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      height: maxValue <= 0
                          ? 4
                          : math.max(4, (height - 44) * item.total / maxValue),
                      decoration: BoxDecoration(
                        color: item.total <= 0
                            ? t.surfaceAlt
                            : financeInstallmentColor.withValues(alpha: .75),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateConstants.persianMonths[item.month - 1],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 8),
                        color: t.textSecondary,
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
}

/// Owed to me / I owe / net.
class DebtSummaryCard extends StatelessWidget {
  const DebtSummaryCard({
    super.key,
    required this.totals,
    required this.unit,
  });

  final DebtTotals totals;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    Widget cell(String label, double value, Color color, IconData icon) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FinanceAmount(value: value, unit: unit, color: color, size: 12),
          ],
        );

    final net = totals.net;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: cell('طلب من', totals.owedToMe,
                dsContentColor(context, AppTheme.lightSuccess), Icons.south_west),
          ),
          Expanded(
            child: cell('بدهی من', totals.iOwe,
                dsContentColor(context, AppTheme.lightError), Icons.north_east),
          ),
          Expanded(
            child: cell(
              'خالص',
              net.abs(),
              net >= 0
                  ? dsContentColor(context, AppTheme.lightSuccess)
                  : dsContentColor(context, AppTheme.lightError),
              net >= 0 ? Icons.trending_up : Icons.trending_down,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of one person: name, net amount, count of open entries.
class DebtPersonRow extends StatelessWidget {
  const DebtPersonRow({
    super.key,
    required this.person,
    required this.net,
    required this.openCount,
    required this.unit,
    this.onTap,
  });

  final Person person;
  final double net;
  final int openCount;
  final String unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
      onTap: onTap,
      child: Row(
        children: [
          DuotoneIconTile(
            accent: financeLedgerColor,
            icon: net >= 0 ? Icons.south_west : Icons.north_east,
            size: 30,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  openCount == 0 ? 'تسویه‌شده' : '$openCount مورد باز',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          FinanceAmount(
            value: net.abs(),
            unit: unit,
            size: 11,
            color: net >= 0
                ? dsContentColor(context, AppTheme.lightSuccess)
                : dsContentColor(context, AppTheme.lightError),
          ),
        ],
      ),
    );
  }
}

/// Opens a simple swipeable viewer for cheque / receipt photos the user
/// attached to an obligation. The attachments are file paths the camera picker
/// stored in the app's private directory.
Future<void> showAttachmentViewer(
  BuildContext context,
  List<String> paths,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _AttachmentViewer(paths: paths),
  );
}

class _AttachmentViewer extends StatelessWidget {
  const _AttachmentViewer({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withValues(alpha: .92),
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'بستن',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 360,
            child: PageView(
              children: [
                for (final p in paths)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.file(
                      File(p),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image,
                            color: Colors.white70, size: 40),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
