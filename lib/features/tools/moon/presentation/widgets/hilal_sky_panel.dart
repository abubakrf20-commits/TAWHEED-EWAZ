import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_sky_profile.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Professional sighting panel: (1) moon/sun altitude vs time chart with the
/// sunset line and the best-time marker, (2) horizon compass showing the
/// moon bearing, sun bearing and crescent tilt at the best sighting moment.
class HilalSkyPanel extends StatelessWidget {
  final DateTime date;
  final double lat;
  final double lng;

  /// Exact best-sighting moment from the visibility card (sunset + 4/9·lag).
  /// When null the marker falls back to the same rule re-derived from the
  /// 4-minute chart samples (minutes coarser).
  final DateTime? bestTime;

  const HilalSkyPanel({
    super.key,
    required this.date,
    required this.lat,
    required this.lng,
    this.bestTime,
  });

  @override
  Widget build(BuildContext context) {
    final samples = HilalSkyProfile.sweep(date: date, lat: lat, lng: lng);
    if (samples.isEmpty) {
      return const SizedBox.shrink();
    }
    final fix = HilalSkyProfile.horizonFix(date: date, lat: lat, lng: lng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('پنل رصدی',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: TopicHues.moon)),
        const SizedBox(height: 8),
        _AltitudeChart(samples: samples, bestTime: bestTime),
        const SizedBox(height: 12),
        if (fix != null) _HorizonCompass(fix: fix),
        if (fix == null)
          Text(
            'این غروب پنجرهٔ رصد ندارد (ماه پیش از خورشید غروب می‌کند).',
            style: TextStyle(
                fontSize: 11,
                color: TimeThemeKit.of(context).palette.textMuted),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ALTITUDE CHART — ارتفاع ماه و خورشید در برابر زمان
// ═══════════════════════════════════════════════════════════════

class _AltitudeChart extends StatelessWidget {
  final List<SkySample> samples;
  final DateTime? bestTime;
  const _AltitudeChart({required this.samples, this.bestTime});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final gridColor = t.outline.withValues(alpha: 0.5);
    final labelColor = t.textMuted;

    // Sunset marker: first sample with sunAlt <= 0.
    final sunsetIdx = samples.indexWhere((s) => s.sunAlt <= 0);

    double xOf(DateTime t) => t.hour + t.minute / 60.0;
    final spotsMoon = [
      for (final s in samples) FlSpot(xOf(s.time), s.moonAlt),
    ];
    final spotsSun = [
      for (final s in samples) FlSpot(xOf(s.time), s.sunAlt),
    ];

    final minX = xOf(samples.first.time);
    final maxX = xOf(samples.last.time);
    // Auto-fit the altitude window: on ordinary evenings the moon rides far
    // above +30° (or below the horizon all dusk), so a fixed window hid both
    // curves entirely. 0° stays in range so the horizon line keeps its anchor,
    // and the range snaps to 10° steps so the axis labels stay round.
    var lo = 0.0;
    var hi = 0.0;
    for (final s in samples) {
      lo = math.min(lo, math.min(s.moonAlt, s.sunAlt));
      hi = math.max(hi, math.max(s.moonAlt, s.sunAlt));
    }
    final minY = ((lo - 5) / 10).floor() * 10.0;
    var maxY = ((hi + 5) / 10).ceil() * 10.0;
    if (maxY - minY < 20) maxY = minY + 20;
    final bestIdx = _bestIndex();

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 6),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 6),
            child: Row(children: [
              const _LegendDot(color: Colors.indigo, label: 'ماه'),
              const SizedBox(width: 14),
              const _LegendDot(color: Colors.orange, label: 'خورشید'),
              const Spacer(),
              Text(
                'ارتفاع (درجه) — زمان محلی',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 10),
                    color: labelColor),
              ),
            ]),
          ),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                // The sunset→moonset sweep can drop the sun far below the
                // window (or lift the moon far above it on ordinary
                // evenings), so un-clipped segments must never escape the
                // card — and the window itself auto-fits the data below.
                clipData: const FlClipData.all(),
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  horizontalInterval: 10,
                  verticalInterval: 0.5,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: gridColor, strokeWidth: 0.6),
                  getDrawingVerticalLine: (v) =>
                      FlLine(color: gridColor, strokeWidth: 0.4),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) => Text(
                        NumberFormat.toLatin('${v.toInt()}'),
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 10),
                            color: labelColor,
                            fontFamily: AppTheme.fontFamily),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 0.5,
                      getTitlesWidget: (v, meta) {
                        final h = v.toInt();
                        final m = ((v - h) * 60).round();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            NumberFormat.toLatin(
                                '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}'),
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 9),
                                color: labelColor,
                                fontFamily: AppTheme.fontFamily),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${s.y.toStringAsFixed(1)}°  '
                          '${NumberFormat.toLatin(_hm(s.x))}',
                          TextStyle(
                            color: s.bar.color ?? Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                    ],
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: Colors.red.withValues(alpha: 0.55),
                      strokeWidth: 1.4,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 9),
                            color: Colors.red.shade300,
                            fontFamily: AppTheme.fontFamily),
                        labelResolver: (_) => 'افق',
                      ),
                    ),
                  ],
                  verticalLines: [
                    if (sunsetIdx >= 0)
                      VerticalLine(
                        x: xOf(samples[sunsetIdx].time),
                        color: Colors.orange.withValues(alpha: 0.5),
                        strokeWidth: 1.2,
                        dashArray: [5, 4],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topLeft,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 9),
                              color: Colors.orange,
                              fontFamily: AppTheme.fontFamily),
                          labelResolver: (_) => 'غروب',
                        ),
                      ),
                    if (bestIdx != null)
                      VerticalLine(
                        x: xOf(samples[bestIdx].time),
                        color: Colors.teal.withValues(alpha: 0.55),
                        strokeWidth: 1.2,
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 9),
                              color: Colors.teal,
                              fontFamily: AppTheme.fontFamily),
                          labelResolver: (_) => 'بهترین رصد',
                        ),
                      ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsMoon,
                    isCurved: true,
                    barWidth: 2.2,
                    color: Colors.indigo,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(),
                  ),
                  LineChartBarData(
                    spots: spotsSun,
                    isCurved: true,
                    barWidth: 1.6,
                    color: Colors.orange,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Best sighting sample index: the sample nearest the card's exact best
  /// time when provided, else the same sunset + 4/9·lag rule re-derived
  /// from the quantized samples (minutes coarser — fallback only).
  int? _bestIndex() {
    final best = bestTime;
    if (best != null) {
      var bestI = 0;
      var bestD = double.infinity;
      for (var i = 0; i < samples.length; i++) {
        final d = samples[i]
            .time
            .difference(best)
            .inMilliseconds
            .abs()
            .toDouble();
        if (d < bestD) {
          bestD = d;
          bestI = i;
        }
      }
      return bestI;
    }
    final sunsetIdx = samples.indexWhere((s) => s.sunAlt <= 0);
    if (sunsetIdx < 0) return null;
    final sunset = samples[sunsetIdx].time;
    // Find first moonset-ish: last rising moon altitude above 0.
    final lastIdx = samples.lastIndexWhere((s) => s.moonAlt > 0);
    if (lastIdx < 0) return null;
    final lag = samples[lastIdx].time.difference(sunset);
    final approx =
        sunset.add(Duration(microseconds: lag.inMicroseconds * 4 ~/ 9));
    var bestI = 0;
    var bestD = double.infinity;
    for (var i = 0; i < samples.length; i++) {
      final d = samples[i]
          .time
          .difference(approx)
          .inMilliseconds
          .abs()
          .toDouble();
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }
    return bestI;
  }

  static String _hm(double x) {
    final h = x.toInt();
    final m = ((x - h) * 60).round();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: TimeThemeKit.of(context).palette.textSecondary)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// HORIZON COMPASS — نقشهٔ جهت هلال در افق
// ═══════════════════════════════════════════════════════════════

class _HorizonCompass extends StatelessWidget {
  final HorizonFix fix;
  const _HorizonCompass({required this.fix});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final ringColor = t.outline;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ringColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('جهت هلال در افق — بهترین زمان رصد',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: AppTheme.scaledFontSize(context, 12.5),
                  color: t.textPrimary)),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 210,
              height: 210,
              child: CustomPaint(
                painter: _HorizonPainter(fix: fix, ringColor: ringColor),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _FixStat(
                  label: 'آزیموت ماه',
                  value: '${fix.moonAz.toStringAsFixed(1)}°'),
              _FixStat(
                  label: 'ارتفاع ماه',
                  value: '${fix.moonAlt.toStringAsFixed(1)}°'),
              _FixStat(
                  label: 'اختلاف آزیموت با خورشید',
                  value: '${fix.relAz.toStringAsFixed(1)}°'),
              _FixStat(
                  label: 'سن ماه',
                  value: '${fix.ageHours.toStringAsFixed(1)} ساعت'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'شاخص هلال: ماه را در آزیموت بالا با ارتفاع کم جستجو کنید؛ '
            'شیب هلال روی افق از اختلاف آزیموت با خورشید تعیین می‌شود.',
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 10.5),
                height: 1.6,
                color: TimeThemeKit.of(context).palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _FixStat extends StatelessWidget {
  final String label;
  final String value;
  const _FixStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w800,
                color: Colors.teal)),
        Text(label,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 10),
                color: TimeThemeKit.of(context).palette.textMuted)),
      ],
    );
  }
}

class _HorizonPainter extends CustomPainter {
  final HorizonFix fix;
  final Color ringColor;
  _HorizonPainter({required this.fix, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // Cardinal labels sit at r + 9, so the ring leaves a 24px margin: at
    // r + 9 the 'شمال'/'جنوب' caps stay ~7px inside the 210px box instead of
    // being clipped at the edges.
    final r = size.shortestSide / 2 - 24;

    // Outer ring + cardinal ticks (N at top, compass azimuth clockwise).
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = ringColor;
    canvas.drawCircle(c, r, ring);
    final tick = Paint()
      ..strokeWidth = 1.2
      ..color = ringColor.withValues(alpha: 0.8);
    for (var a = 0; a < 360; a += 15) {
      final rad = (a - 90) * math.pi / 180;
      final p1 = Offset(
          c.dx + (r - 5) * math.cos(rad), c.dy + (r - 5) * math.sin(rad));
      final p2 = Offset(c.dx + r * math.cos(rad), c.dy + r * math.sin(rad));
      canvas.drawLine(p1, p2, tick);
    }
    void label(String txt, double az, Color color) {
      final rad = (az - 90) * math.pi / 180;
      final p = Offset(
          c.dx + (r + 9) * math.cos(rad), c.dy + (r + 9) * math.sin(rad));
      final tp = TextPainter(
        text: TextSpan(
            text: txt,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    label('شمال', 0, Colors.red.shade300);
    label('شرق', 90, ringColor);
    label('جنوب', 180, ringColor);
    label('غرب', 270, ringColor);

    // Horizon line: chord through center.
    final horizon = Paint()
      ..strokeWidth = 1.6
      ..color = Colors.brown.withValues(alpha: 0.55);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), horizon);

    // Moon position: azimuth → angle around circle; altitude → radius
    // fraction (0° at horizon = center height, 45° near the rim).
    final moonAngle = _angleForAz(fix.moonAz);
    final moonFrac = (fix.moonAlt / 45).clamp(0.05, 0.92);
    final moonC = Offset(
      c.dx + r * moonFrac * math.cos(moonAngle),
      c.dy - r * moonFrac * math.sin(moonAngle),
    );
    canvas.drawCircle(moonC, 9, Paint()..color = Colors.indigo.shade300);
    canvas.drawCircle(
        moonC,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.indigo);

    // Sun below horizon: sunAlt is negative → drawn below the horizon chord.
    final sunAngle = _angleForAz(fix.sunAz);
    final sunFrac = ((fix.sunAlt.abs()) / 45).clamp(0.05, 0.5);
    final sunC = Offset(
      c.dx + r * sunFrac * math.cos(sunAngle),
      c.dy + r * sunFrac * math.sin(sunAngle),
    );
    canvas.drawCircle(
        sunC, 7, Paint()..color = Colors.orange.withValues(alpha: 0.85));

    // Crescent tilt guide: from moon toward the sun (bright limb faces the
    // sun — the observer finds the horns on this side).
    final tilt = Paint()
      ..strokeWidth = 1.2
      ..color = Colors.teal.withValues(alpha: 0.5);
    canvas.drawLine(moonC, sunC, tilt);

    // Azimuth readout arc from north (top) clockwise to the moon bearing.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Colors.teal.withValues(alpha: 0.65);
    const startRad = -math.pi / 2;
    var sweepRad = (moonAngle - startRad) % (2 * math.pi);
    if (sweepRad < 0) sweepRad += 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 11), startRad,
        sweepRad, false, arc);
  }

  /// Compass azimuth (deg clockwise from north) → canvas angle (rad, CCW
  /// from +x) with north up: canvas y is down, so invert.
  static double _angleForAz(double azDeg) => (90 - azDeg) * math.pi / 180;

  @override
  bool shouldRepaint(covariant _HorizonPainter oldDelegate) =>
      oldDelegate.fix != fix;
}
