import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/components/share_card_shell.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_share_text.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';

// Neutral palette — the card body stays a pure cool grey so the only hue
// comes from the purple issue banner and the per-type accents. Never use
// warm/beige greys here: they read as yellow lines on phone screens.
const Color _cardBgLight = InheritancePalette.cardBg;
const Color _cardBgDark = InheritancePalette.cardBgDark;
const Color _boxBgLight = InheritancePalette.boxBg;
const Color _boxTextLight = InheritancePalette.boxInk;
const Color _labelLight = InheritancePalette.label;
const Color _trackLight = InheritancePalette.track;

/// A polished, print-ready share card for an inheritance result:
/// a purple issue banner (بسم الله + title + مذهب/روش chips), a soft estate
/// summary box, an اصل مسأله stats strip, share rows carrying a type-colored
/// rail + pill + proportional bar, and the app mark over the «برنامه توحید»
/// signature line. Rendered offscreen and shared as a portrait PNG.
class InheritanceShareCard extends StatelessWidget {
  const InheritanceShareCard({
    super.key,
    required this.result,
    required this.estate,
  });

  final InheritanceResult result;
  final double estate;

  static const Color _asabaColor = InheritancePalette.asabaInk;
  static const Color _raddColor = InheritancePalette.raddInk;
  static const Color _hajbColor = InheritancePalette.hajb;
  static const Color _mandatoryWillColor = InheritancePalette.mandatoryWillInk;
  static const Color _accent = TopicHues.inheritance;

  /// Amount with Latin digits and the Persian thousand separator
  /// (e.g. «450٬000»).
  static String _money(double v) => inheritanceMoney(v).replaceAll(',', '٬');

  static String _int(int n) => '$n';

  /// Today's date in the Jalali calendar, e.g. «23 شهریور 1405».
  ///
  /// Injectable because the card stamps the share image with the current day:
  /// the golden test would otherwise drift one pixel row per day and go red
  /// the morning after its baseline was recorded.
  @visibleForTesting
  static DateTime Function() clockForTest = DateTime.now;

  static String _today() {
    final j = Jalali.fromDateTime(clockForTest());
    final months = DateConstants.persianMonths;
    return '${_int(j.day)} ${months[j.month - 1]} ${_int(j.year)}';
  }

  Color _typeColor(ShareType t) {
    switch (t) {
      case ShareType.fard:
        return _accent;
      case ShareType.asaba:
        return _asabaColor;
      case ShareType.radd:
        return _raddColor;
      case ShareType.hajb:
        return _hajbColor;
      case ShareType.mandatoryWill:
        return _mandatoryWillColor;
    }
  }

  String _shareTypeLabel(ShareType t) {
    switch (t) {
      case ShareType.fard:
        return 'فرض';
      case ShareType.asaba:
        return 'تعصیب';
      case ShareType.radd:
        return 'رد';
      case ShareType.hajb:
        return 'حجب';
      case ShareType.mandatoryWill:
        return 'وصیت واجبه';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? _cardBgDark : _cardBgLight;
    final softBoxBg =
        isDark ? Colors.white.withValues(alpha: 0.07) : _boxBgLight;
    final track = isDark ? Colors.white.withValues(alpha: 0.10) : _trackLight;
    final chipText = isDark ? Colors.white : _boxTextLight;
    final label = isDark ? Colors.white.withValues(alpha: 0.9) : _labelLight;
    final ink = isDark ? Colors.white : InheritancePalette.ink;
    final body = isDark
        ? Colors.white.withValues(alpha: 0.82)
        : InheritancePalette.inkMuted;

    // Display-only Hare rounding: row percentages add to 100 and row amounts
    // to the distributed estate, which per-row `.round()` cannot guarantee.
    final amounts = [for (final s in result.shares) s.amount];
    final displayAmounts = hareAllocate(amounts, result.totalAllocated);
    final percents = harePercents(amounts);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Issuer banner ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: InheritancePalette.purpleDeep,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _BannerPatternPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    children: [
                      Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'نتایج تقسیم میراث',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 19),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: _BannerChip(madhabLabel(result.madhab)),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: _BannerChip(result.methodLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Estate summary box ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: isDark ? 0.16 : 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _summaryRow(
                          context, 'ترکه اولیه', _money(estate), ink, label),
                      _summaryRow(
                        context,
                        result.mandatoryWillAmount > 0
                            ? 'ترکه پس از هزینه، دیون و وصیت عادی'
                            : 'ترکه قابل تقسیم',
                        _money(result.netEstate),
                        ink,
                        label,
                      ),
                      if (result.mandatoryWillAmount > 0) ...[
                        _summaryRow(
                            context,
                            'وصیت واجبه (کسر شده)',
                            _money(result.mandatoryWillAmount),
                            _mandatoryWillColor,
                            label),
                        _summaryRow(context, 'مانده برای وراث اصلی',
                            _money(result.estateForMainHeirs), ink, label),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── اصل مسأله stats strip ────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatsBox(
                        bg: softBoxBg,
                        text: 'اصل مسأله: ${_int(result.baseAsl)}',
                        color: ink,
                      ),
                    ),
                    if (result.baseAsl != result.correctedAsl) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatsBox(
                          bg: softBoxBg,
                          text: result.baseAsl < result.correctedAsl
                              ? 'پس از عول: ${_int(result.correctedAsl)}'
                              : 'پس از رد: ${_int(result.correctedAsl)}',
                          color: label,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatsBox(
                        bg: softBoxBg,
                        text: 'جمع سهمها: ${_money(result.totalAllocated)}',
                        color: label,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Heirs section ────────────────────────────────────────
                Text(
                  'سهم هر وارث',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w800,
                    color: label,
                  ),
                ),
                const SizedBox(height: 2),
                for (var i = 0; i < result.shares.length; i++) ...[
                  _shareRow(
                    context,
                    result.shares[i],
                    totalAmount: result.totalAllocated,
                    displayAmount: displayAmounts[i],
                    percent: percents[i],
                    isDark: isDark,
                    softBoxBg: softBoxBg,
                    track: track,
                    chipText: chipText,
                    label: label,
                    ink: ink,
                    body: body,
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  _today(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: label.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 14),
                // ── signature: the app mark beside the signature line ────
                Divider(
                  height: 1,
                  color: label.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 10),
                ShareCardSignature(section: 'میراث', color: label),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String textLabel, String value,
      Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              textLabel,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareRow(
    BuildContext context,
    InheritanceShare s, {
    required double totalAmount,
    required double displayAmount,
    required int percent,
    required bool isDark,
    required Color softBoxBg,
    required Color track,
    required Color chipText,
    required Color label,
    required Color ink,
    required Color body,
  }) {
    final c = _typeColor(s.shareType);
    final ratio =
        totalAmount > 0 ? (s.amount / totalAmount).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 34,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
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
                            heirLabel(s.type) +
                                (s.count > 1 ? ' (${_int(s.count)} نفر)' : ''),
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: isDark ? 0.25 : 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _shareTypeLabel(s.shareType),
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 10),
                              fontWeight: FontWeight.w800,
                              color: c,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${s.fraction.toArString()} • ${_money(displayAmount)}',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w800,
                              color: chipText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 5,
                              backgroundColor: track,
                              valueColor: AlwaysStoppedAnimation(c),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$percent٪',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w700,
                            color: label,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (s.reason.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              s.reason,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                height: 1.6,
                color: body,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsBox extends StatelessWidget {
  const _StatsBox({required this.bg, required this.text, required this.color});

  final Color bg;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 11),
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 10),
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Subtle geometric lattice (Islamic-style diamonds) drawn at very low
/// opacity over the banner so it stays readable.
class _BannerPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    const step = 46.0;
    const half = 23.0;
    for (double x = -step; x < size.width + step; x += step) {
      for (double y = -step; y < size.height + step; y += step) {
        final path = Path()
          ..moveTo(x, y - half * 0.55)
          ..lineTo(x + half * 0.55, y)
          ..lineTo(x, y + half * 0.55)
          ..lineTo(x - half * 0.55, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
