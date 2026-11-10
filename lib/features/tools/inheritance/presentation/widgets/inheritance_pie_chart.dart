import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/inheritance_palette.dart';

/// Donut chart for inheritance shares using CustomPainter.
class InheritancePieChart extends StatelessWidget {
  final List<InheritanceShare> shares;
  final double size;
  final double strokeWidth;

  const InheritancePieChart({
    super.key,
    required this.shares,
    this.size = 200,
    this.strokeWidth = 40,
  });

  static const List<Color> _colors = InheritancePalette.series;

  @override
  Widget build(BuildContext context) {
    // Negative, NaN and infinite amounts are skipped rather than poisoning
    // the total: one bogus row must not blank or corrupt the whole chart.
    final valid = shares
        .where((s) => s.amount.isFinite && s.amount > 0)
        .toList(growable: false);
    final total = valid.fold<double>(0, (s, h) => s + h.amount);
    // `total <= 0` alone misses NaN and +inf (both compare false), so a
    // non-finite sum must be checked explicitly — nothing sane to draw.
    if (valid.isEmpty || !total.isFinite || total <= 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(
              shares: valid,
              total: total,
              colors: _colors,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'مجموع',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: TimeThemeKit.of(context).palette.textMuted,
                ),
              ),
              Text(
                NumberFormat.formatPlain(total),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w700,
                  color: TimeThemeKit.of(context).palette.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<InheritanceShare> shares;
  final double total;
  final List<Color> colors;
  final double strokeWidth;

  _DonutPainter({
    required this.shares,
    required this.total,
    required this.colors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - strokeWidth / 2;

    double startAngle = -pi / 2; // Start from top

    for (int i = 0; i < shares.length; i++) {
      final share = shares[i];
      final sweepAngle = (share.amount / total) * 2 * pi;
      final color = colors[i % colors.length];

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Small gap between segments — but never below zero: a tiny share's
      // sweep is drawn whole instead of a negative (backwards) arc.
      const gap = 0.02;
      final drawnSweep = sweepAngle > gap ? sweepAngle - gap : sweepAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        drawnSweep,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    if (oldDelegate.total != total ||
        oldDelegate.shares.length != shares.length) {
      return true;
    }
    // Same total, different distribution (e.g. 250/750 → 500/500) must
    // repaint: compare every segment, not just the sum and the count.
    for (var i = 0; i < shares.length; i++) {
      final a = oldDelegate.shares[i];
      final b = shares[i];
      if (a.type != b.type ||
          a.count != b.count ||
          a.amount != b.amount ||
          a.fraction.n != b.fraction.n ||
          a.fraction.d != b.fraction.d) {
        return true;
      }
    }
    return false;
  }
}

/// Legend widget for the pie chart
class InheritancePieLegend extends StatelessWidget {
  final List<InheritanceShare> shares;

  const InheritancePieLegend({super.key, required this.shares});

  static const List<Color> _colors = InheritancePalette.series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: shares.asMap().entries.map((e) {
        final i = e.key;
        final s = e.value;
        final color = _colors[i % _colors.length];
        final showCount = s.count > 1 &&
            (s.type == HeirType.wife ||
                s.type == HeirType.son ||
                s.type == HeirType.daughter ||
                s.type == HeirType.fullBrother ||
                s.type == HeirType.fullSister ||
                s.type == HeirType.paternalBrother ||
                s.type == HeirType.paternalSister ||
                s.type == HeirType.maternalBrother ||
                s.type == HeirType.maternalSister);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 4),
            Text(
              heirLabel(s.type) + (showCount ? ' (${s.count})' : ''),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: TimeThemeKit.of(context).palette.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
