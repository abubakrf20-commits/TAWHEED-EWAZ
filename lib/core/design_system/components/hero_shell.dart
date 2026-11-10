import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/time_theme.dart';

/// Signature hero shell: radius-24 card painting the phase gradient with a
/// soft gold glow and the fixed star field. The painter is static — it
/// repaints only when the phase palette changes; [lite] drops glow + stars
/// for weak devices. Promoted from the home hero.
class HeroCardShell extends StatelessWidget {
  const HeroCardShell({
    super.key,
    required this.child,
    this.lite = false,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 8),
    this.radius = 24,
  });

  final Widget child;
  final bool lite;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: HeroGradientPainter(t, lite),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Static hero background: three-stop palette gradient, a soft gold radial
/// glow and the star field at fixed fractions.
class HeroGradientPainter extends CustomPainter {
  HeroGradientPainter(this.t, this.lite);

  final AppPalette t;
  final bool lite;

  // (x, y, radius, gold?) as fractions of the size — the design's field.
  static const _stars = <(double, double, double, bool)>[
    (.09, .12, 1.2, false),
    (.17, .30, 1.0, false),
    (.37, .08, 1.0, false),
    (.66, .14, 1.3, true),
    (.82, .09, 1.1, false),
    (.93, .24, 1.0, false),
    (.05, .52, 1.0, false),
    (.95, .50, 1.0, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.heroTop, t.heroMid, t.heroBottom],
          stops: const [0, .5, 1],
        ).createShader(rect),
    );
    if (lite) return;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -.25),
          radius: .65,
          colors: [
            AppPalette.heroGold.withValues(alpha: .24),
            AppPalette.heroGold.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    final white = Paint()..color = const Color(0xB3FFFFFF);
    final gold = Paint()..color = AppPalette.heroGold;
    for (final (x, y, r, isGold) in _stars) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * y),
        r,
        isGold ? gold : white,
      );
    }
  }

  @override
  bool shouldRepaint(HeroGradientPainter old) =>
      old.lite != lite ||
      old.t.heroTop != t.heroTop ||
      old.t.heroMid != t.heroMid ||
      old.t.heroBottom != t.heroBottom;
}
