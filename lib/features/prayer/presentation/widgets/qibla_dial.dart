import 'dart:math';

import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Text of a labelled 30°-step on the dial rose: the full Persian word at the
/// four cardinal points — initials would collide (شمال/شرق both start with
/// «ش») — and the bearing number with its degree sign in between («30°»).
/// Latin digits, as everywhere.
String qiblaRoseLabel(int bearing) => switch (bearing % 360) {
      0 => 'شمال',
      90 => 'شرق',
      180 => 'جنوب',
      270 => 'غرب',
      final b => '$b°',
    };

/// The Qibla dial — the hero card's focal point.
///
/// Structure, outside in: a bezel ring with a lit sector at the Qibla bearing,
/// a graduation ring (72 ticks in four weights), the framed degree band with
/// its twelve labels, then the needle — tapered stem, counterweight tail and
/// the gold mosque head — over a pivot hub.
///
/// Every layer that moves is a `Transform.rotate` over a painter that never
/// repaints: the rose turns with −heading (so a screen-top label always names
/// the bearing the nose faces and «شمال» really points at true north) and the
/// needle turns with the Qibla angle. The compass feed runs at ~31 Hz, so the
/// dial costs three matrix composites per frame, not a repaint.
class QiblaDial extends StatelessWidget {
  const QiblaDial({
    super.key,
    required this.heading,
    required this.angle,
    required this.isOnTarget,
    required this.hasFirstReading,
    required this.gold,
    required this.palette,
    required this.onTap,
    this.size = 264,
  });

  /// Smoothed TRUE heading (0 = north), null before the first reading.
  final double? heading;

  /// Signed angle from the device nose to the Qibla (−180..180).
  final double angle;
  final bool isOnTarget;
  final bool hasFirstReading;

  /// Fixed gold for the rose/needle — NOT the accent-preset tertiary; the
  /// caller resolves the light/dark shade.
  final Color gold;

  /// Phase palette — the hero card's own surface/ink colours.
  final AppPalette palette;

  final VoidCallback onTap;

  /// Dial diameter; the hero's width budget owns the value.
  final double size;

  /// The degree band's label ring. Pinned at r=90 for the 264 dial (and scaled
  /// with it) — `qibla_dial_test.dart` checks every label's centre against it.
  double get _labelRadius => size * 90 / 264;

  /// Centre of the mosque head. The tip radius is what makes a sweep read as a
  /// needle: a badge orbiting near the hub reads as no needle at all.
  double get _headRadius => size * 60 / 264;
  double get _headSize => size * 42 / 264;

  @override
  Widget build(BuildContext context) {
    final headingValue = heading ?? 0.0;
    final onTarget = isOnTarget && hasFirstReading;
    final accent = onTarget ? gold : Colors.white.withValues(alpha: 0.85);
    final r = size / 2;
    return Semantics(
      label: onTarget
          ? 'روبرو قبله هستید'
          : 'صفحهٔ قطب‌نما؛ جهت قبله با علامت طلایی مشخص شده است',
      child: GestureDetector(
        onTap: onTap,
        child: RepaintBoundary(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Field — a dished glass wash: light at the centre, falling
                // away to the rim, so the dial reads as a recessed instrument
                // face rather than a flat disc.
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.03),
                        Colors.black.withValues(alpha: 0.16),
                      ],
                      stops: const [0.0, 0.66, 1.0],
                    ),
                  ),
                ),
                // Bezel light at the Qibla bearing: a sector of the outer ring
                // that brightens and widens once the nose is on target. Drawn
                // in the needle's rotating frame (the arc is symmetric about
                // the top) so it needs no repaint as the phone turns.
                Transform.rotate(
                  angle: angle * pi / 180,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: CustomPaint(
                      painter: _TargetSectorPainter(
                        gold: gold,
                        onTarget: onTarget,
                        radius: r,
                      ),
                    ),
                  ),
                ),
                // The rose carries the labels, so it rotates with −heading.
                Transform.rotate(
                  angle: -headingValue * pi / 180,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DialRosePainter(
                              inkHigh: gold,
                              inkLow: Colors.white.withValues(alpha: 0.5),
                              bandInk: gold.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        ExcludeSemantics(child: _degreeRing(context)),
                      ],
                    ),
                  ),
                ),
                // Needle: counterweight tail, tapered stem, mosque head.
                Transform.rotate(
                  angle: angle * pi / 180,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _NeedlePainter(
                              head: accent,
                              tail: Colors.white.withValues(alpha: 0.30),
                              radius: r,
                              stemEnd: _headRadius - _headSize / 2,
                            ),
                          ),
                        ),
                        Positioned(
                          top: r - _headRadius - _headSize / 2,
                          left: r - _headSize / 2,
                          child: Container(
                            width: _headSize,
                            height: _headSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent,
                              border: Border.all(
                                color: palette.heroMid.withValues(alpha: 0.85),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            // Dark glyph in BOTH states: cream on a white head
                            // was invisible, and cream on gold is barely
                            // better. The head colour alone carries "on
                            // target".
                            child: Icon(
                              Icons.mosque,
                              size: _headSize * 0.52,
                              color: palette.heroMid,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Pivot hub — a ring inside a ring, like a real compass cap.
                Container(
                  width: size * 26 / 264,
                  height: size * 26 / 264,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.heroMid,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: size * 11 / 264,
                      height: size * 11 / 264,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        // Same reasoning as the head: a cream hairline on a
                        // white or gold dot is no hairline at all.
                        border: Border.all(
                          color: palette.heroMid.withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The labelled degree band: a label every 30°, sitting INSIDE the tick
  /// ring — the four cardinal words in the needle gold, the bearings as quiet
  /// digits. This is the compass reading the flat redesign had dropped
  /// (user request, 2026-10-15): do not remove the labels.
  ///
  /// Geometry is tuned to the 264 dial: label centres at r=90 while the
  /// longest (cardinal) tick starts at r=124, so nothing overlaps. Keep it
  /// there — the rects are pinned by `qibla_dial_test.dart`.
  Widget _degreeRing(BuildContext context) {
    final labelRadius = _labelRadius;
    final center = size / 2;
    final labels = <Widget>[];
    for (var i = 0; i < 36; i += 3) {
      final bearing = i * 10;
      final isCardinal = bearing % 90 == 0;
      // Compass bearing → screen: 0° up, 90° right.
      final a = (bearing - 90) * pi / 180;
      final w = isCardinal ? 50.0 : 36.0;
      final h = isCardinal ? 20.0 : 16.0;
      labels.add(Positioned(
        left: center + labelRadius * cos(a) - w / 2,
        top: center + labelRadius * sin(a) - h / 2,
        width: w,
        height: h,
        child: Center(
          child: Text(
            qiblaRoseLabel(bearing),
            maxLines: 1,
            style: isCardinal
                ? TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: gold,
                  )
                : TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 9),
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
          ),
        ),
      ));
    }
    return SizedBox(width: size, height: size, child: Stack(children: labels));
  }
}

/// The graduation ring: 72 ticks (every 5°) in four weights, hanging inward
/// from the band circle. One painter, no per-frame text layout.
class _DialRosePainter extends CustomPainter {
  const _DialRosePainter({
    required this.inkHigh,
    required this.inkLow,
    required this.bandInk,
  });

  final Color inkHigh;
  final Color inkLow;

  /// The hairline that the ticks hang from.
  final Color bandInk;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final base = r - 8;
    final high = Paint()
      ..color = inkHigh
      ..isAntiAlias = true
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final major = Paint()
      ..color = inkLow
      ..isAntiAlias = true
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final medium = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..isAntiAlias = true
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final minor = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..isAntiAlias = true
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    // The band the ticks hang from, and the hairline that frames the labels
    // from outside — two circles are what turn a spray of lines into a dial.
    canvas.drawCircle(
      center,
      base,
      Paint()
        ..color = bandInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawCircle(
      center,
      r - 29,
      Paint()
        ..color = bandInk.withValues(alpha: bandInk.a * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    for (var i = 0; i < 72; i++) {
      final bearing = i * 5;
      final a = (bearing - 90) * pi / 180;
      final isCardinal = bearing % 90 == 0;
      final isMajor = bearing % 30 == 0;
      final isMedium = bearing % 10 == 0;
      final len = isCardinal ? 16.0 : (isMajor ? 11.0 : (isMedium ? 7.0 : 4.0));
      final paint = isCardinal
          ? high
          : (isMajor ? major : (isMedium ? medium : minor));
      canvas.drawLine(
        Offset(center.dx + cos(a) * (base - len),
            center.dy + sin(a) * (base - len)),
        Offset(center.dx + cos(a) * base, center.dy + sin(a) * base),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DialRosePainter oldDelegate) =>
      inkHigh != oldDelegate.inkHigh ||
      inkLow != oldDelegate.inkLow ||
      bandInk != oldDelegate.bandInk;
}

/// The needle, drawn in its own rotating frame (0° = up): a counterweight
/// tail below the hub, a tapered stem that widens toward the hub, and nothing
/// above — the mosque head is a widget sitting at [_headRadius].
class _NeedlePainter extends CustomPainter {
  const _NeedlePainter({
    required this.head,
    required this.tail,
    required this.radius,
    required this.stemEnd,
  });

  final Color head;
  final Color tail;
  final double radius;

  /// Radial distance where the stem stops (the head's inner edge).
  final double stemEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final hub = radius * 26 / 264 / 2; // pivot cap radius
    final scale = radius / 132;

    // Stem: a trapezoid, narrow where it meets the head, widest at the hub.
    final stem = Path()
      ..moveTo(c.dx - 3.6 * scale, c.dy - stemEnd)
      ..lineTo(c.dx + 3.6 * scale, c.dy - stemEnd)
      ..lineTo(c.dx + 8 * scale, c.dy - hub)
      ..lineTo(c.dx - 8 * scale, c.dy - hub)
      ..close();
    canvas.drawPath(
      stem,
      Paint()
        ..color = head
        ..isAntiAlias = true
        ..style = PaintingStyle.fill,
    );

    // Tail: the same shape mirrored, in a muted ink — this is what makes the
    // sweep read as a needle instead of a floating badge on a stick.
    final tailPath = Path()
      ..moveTo(c.dx - 8 * scale, c.dy + hub)
      ..lineTo(c.dx + 8 * scale, c.dy + hub)
      ..lineTo(c.dx, c.dy + 28 * scale)
      ..close();
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = tail
        ..isAntiAlias = true
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) =>
      head != oldDelegate.head ||
      tail != oldDelegate.tail ||
      radius != oldDelegate.radius ||
      stemEnd != oldDelegate.stemEnd;
}

/// The lit sector of the bezel around the Qibla bearing. Static in the
/// needle's frame: it only repaints when the target state flips.
class _TargetSectorPainter extends CustomPainter {
  const _TargetSectorPainter({
    required this.gold,
    required this.onTarget,
    required this.radius,
  });

  final Color gold;
  final bool onTarget;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = radius - 1.0;
    // The bezel itself: one hairline ring, drawn here so the lit segment can
    // sit exactly on it instead of floating a couple of pixels inside.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = gold.withValues(alpha: 0.30)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    const sweep = 9.0 * pi / 180;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -pi / 2 - sweep,
      sweep * 2,
      false,
      Paint()
        ..color = gold.withValues(alpha: onTarget ? 0.95 : 0.45)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = onTarget ? 4.5 : 3.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TargetSectorPainter oldDelegate) =>
      gold != oldDelegate.gold ||
      onTarget != oldDelegate.onTarget ||
      radius != oldDelegate.radius;
}
