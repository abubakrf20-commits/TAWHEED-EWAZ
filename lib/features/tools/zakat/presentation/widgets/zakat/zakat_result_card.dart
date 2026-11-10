import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/zakat/domain/entities/zakat_result.dart';
import 'package:tawheeed/features/tools/zakat/domain/services/zakat_calculator.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class ZakatResultCard extends StatelessWidget {
  final ZakatResult result;
  final bool isDark;
  final Color accent;
  final String selectedCropType;
  final VoidCallback onSharePdf;

  const ZakatResultCard({
    super.key,
    required this.result,
    required this.isDark,
    required this.accent,
    required this.selectedCropType,
    required this.onSharePdf,
  });

  Color _fg(BuildContext c) =>
      result.hasZakat ? Colors.white : TimeThemeKit.of(c).palette.textPrimary;
  Color _muted(BuildContext c) => result.hasZakat
      ? Colors.white.withValues(alpha: 0.68)
      : TimeThemeKit.of(c).palette.textMuted;
  Color _cardBg(BuildContext c) => result.hasZakat
      ? Colors.white.withValues(alpha: 0.12)
      : (isDark
          ? TimeThemeKit.of(c).palette.surfaceAlt
          : const Color(0xFFF7F7F8));

  @override
  Widget build(BuildContext context) {
    final hasDetails = result.breakdownLines.any((l) => l.trim().isNotEmpty) ||
        result.grazingNote.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: result.hasZakat
            ? (isDark ? const Color(0xFF1A2E1A) : AppTheme.success)
            : TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(20),
        border: result.hasZakat
            ? null
            : Border.all(color: TimeThemeKit.of(context).palette.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            const SizedBox(height: 12),
            if (!result.priceKnown) ...[
              _priceMissingNote(context),
              const SizedBox(height: 12),
            ],
            if (result.hasZakat) _summary(context) else _emptyState(context),
            if (hasDetails) ...[
              const SizedBox(height: 10),
              _details(context),
            ],
            const SizedBox(height: 12),
            _pdfButton(context),
            if (result.hasZakat) ...[
              const SizedBox(height: 10),
              _explanationNote(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _priceMissingNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'قیمت روز طلا و نقره وارد نشده است؛ نصاب قابل محاسبه نیست. '
              'قیمت هر گرم طلا (یا نقره) را به ${result.unit} وارد کنید یا '
              '«دریافت قیمت روز» را بزنید. هیچ قیمت پیش‌فرضی جای آن را '
              'نمی‌گیرد، چون نصاب را به عددی کهنه گره می‌زند.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: Colors.orange.shade800,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }


  Widget _header(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: result.hasZakat
                ? Colors.white.withValues(alpha: 0.18)
                : accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            result.hasZakat
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: result.hasZakat ? Colors.white : accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.hasZakat ? 'زکات واجب شده' : 'زکات واجب نیست',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w800,
                  color: _fg(context),
                ),
              ),
              if (!result.hasZakat)
                Text(
                  'بر اساس مذهب ${zakatMadhabLabel(result.madhab)}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: _muted(context),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: result.hasZakat
                ? Colors.white.withValues(alpha: 0.18)
                : TimeThemeKit.of(context).palette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: result.hasZakat
                    ? Colors.white.withValues(alpha: 0.30)
                    : TimeThemeKit.of(context).palette.outline),
          ),
          child: Text(
            zakatMadhabLabel(result.madhab),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              fontWeight: FontWeight.w700,
              color: result.hasZakat
                  ? Colors.white
                  : TimeThemeKit.of(context).palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    // hero amount — the combined monetary obligation (in the chosen unit) across
    // categories (money/gold/silver + kanz + collectible debt + horses).
    final hasCash = result.totalCashZakat > 0;
    return Container(
      decoration: BoxDecoration(
        color: _cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _muted(context).withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        children: [
          if (hasCash) ...[
            Text('جمع زکات نقدی',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: _muted(context))),
            const SizedBox(height: 2),
            Text(
              '${NumberFormat.formatPlain(result.totalCashZakat)} ${result.unit}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 20),
                fontWeight: FontWeight.w800,
                color: _fg(context),
              ),
            ),
            Text('پول/طلا/نقره + گنج + دین مرجو + اسب',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: _muted(context))),
            const SizedBox(height: 8),
            Divider(height: 1, color: _muted(context).withValues(alpha: 0.18)),
          ],
          // secondary categories — compact rows
          _compactRow(context, 'زکات دام',
              result.hasLivestockZakat ? result.livestockDescription : null),
          _compactRow(
              context,
              'زکات کشاورزی ($selectedCropType)',
              result.hasAgricultureZakat
                  ? '${NumberFormat.formatPlain(result.agricultureZakat)} کیلوگرم'
                  : null,
              trailing: result.hasAgricultureZakat &&
                      result.agricultureZakatValue > 0
                  ? '≈ ${NumberFormat.formatPlain(result.agricultureZakatValue)} ${result.unit}'
                  : null),
          _compactRow(
              context,
              'زکات گنج (یک‌پنجم)',
              result.kanzZakat > 0
                  ? '${NumberFormat.formatPlain(result.kanzZakat)} ${result.unit}'
                  : null),
          _compactRow(
              context,
              'زکات دین مرجو (قابل وصول)',
              result.friendlyDebtZakat > 0
                  ? '${NumberFormat.formatPlain(result.friendlyDebtZakat)} ${result.unit}'
                  : null,
              sub: 'هر سال با حول'),
          _compactRow(
              context,
              'زکات دین غیرمرجو (پس از وصول)',
              result.uglyDebtZakat > 0
                  ? '${NumberFormat.formatPlain(result.uglyDebtZakat)} ${result.unit}'
                  : null,
              sub: 'برای 1 سال — اکنون واجب نیست'),
          _compactRow(
              context,
              'زکات عسل',
              result.honeyZakatKg > 0
                  ? '${NumberFormat.formatPlain(result.honeyZakatKg)} کیلوگرم'
                  : null,
              sub: 'حنبلی و حنفی — شافعی/مالکی ندارد'),
          _compactRow(
              context,
              'زکات اسب (5 رأس)',
              result.horsesZakatValue > 0
                  ? '${NumberFormat.formatPlain(result.horsesZakatValue)} ${result.unit}'
                  : null,
              sub: 'مبنای حنفی — جمهور/شافعی/مالکی ندارند'),
        ],
      ),
    );
  }

  Widget _compactRow(BuildContext context, String label, String? value,
      {String? trailing, String? sub}) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: _muted(context))),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w700,
                        color: _fg(context))),
                if (trailing != null)
                  Text(trailing,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10),
                          color: _muted(context))),
                if (sub != null)
                  Text(sub,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10),
                          color: _muted(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        result.explanation,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          color: TimeThemeKit.of(context).palette.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _details(BuildContext context) {
    final lines =
        result.breakdownLines.where((l) => l.trim().isNotEmpty).toList();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(12),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            iconColor: _fg(context),
            collapsedIconColor: _muted(context),
            title: Text('جزئیات محاسبه',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: _fg(context))),
            subtitle: Text('دارایی، نصاب و شرایط',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: _muted(context))),
            children: [
              Divider(
                  height: 1, color: _muted(context).withValues(alpha: 0.15)),
              const SizedBox(height: 8),
              _kv(context, 'خالص دارایی',
                  '${NumberFormat.formatPlain(result.netAssets)} ${result.unit}'),
              _kv(context, 'نصاب',
                  '${result.nisabBasis} — ${NumberFormat.formatPlain(result.nisabThreshold)} ${result.unit}'),
              _kv(context, 'وضعیت نصاب',
                  result.meetsNisab ? 'رسیده ✓' : 'نرسیده'),
              _kv(context, 'حول قمری', result.hawlComplete ? 'کامل' : 'ناکامل'),
              if (result.grazingNote.isNotEmpty)
                _kv(context, 'شرط دام', result.grazingNote),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('ریز محاسبه',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: _fg(context))),
                ),
                const SizedBox(height: 4),
                ...lines.take(10).map((l) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ',
                              style: TextStyle(
                                  color: _muted(context), fontSize: AppTheme.scaledFontSize(context, 11))),
                          Expanded(
                            child: Text(l,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: AppTheme.scaledFontSize(context, 10),
                                    color: _muted(context),
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    )),
                if (lines.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('و ${lines.length - 10} مورد دیگر در گزارش PDF',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: _muted(context).withValues(alpha: 0.9))),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text('$k: ',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: _muted(context))),
          Expanded(
            child: Text(v,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: _fg(context))),
          ),
        ],
      ),
    );
  }

  Widget _pdfButton(BuildContext context) {
    return SizedBox(
      height: 42,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onSharePdf,
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
        label: Text('دانلود گزارش PDF',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: result.hasZakat ? Colors.white : accent,
          side: BorderSide(
              color: result.hasZakat
                  ? Colors.white.withValues(alpha: 0.55)
                  : accent.withValues(alpha: 0.45)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _explanationNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        result.explanation,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 11),
          color: _muted(context),
          height: 1.5,
        ),
      ),
    );
  }
}
