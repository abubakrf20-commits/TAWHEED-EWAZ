import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

void main() {
  const accent = Color(0xFF5B4BC4);

  Future<void> pump(
    WidgetTester tester, {
    double size = 28,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: textDirection,
          child: Scaffold(
            body: Center(
              child: DuotoneIconTile(
                accent: accent,
                icon: Icons.home_rounded,
                size: size,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('geometry follows the spec formulas', (tester) async {
    await pump(tester);
    // The flat recipe: one Container — fill @14 % over the card, hairline
    // border @18 %, radius 0.32·S. No ClipRRect, no back circle any more.
    expect(find.byType(ClipRRect), findsNothing);
    expect(find.byType(PositionedDirectional), findsNothing);
    final box = tester.widget<Container>(find.byType(Container));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(0.32 * 28));
    final card = TimeThemeKit.of(
            tester.element(find.byType(DuotoneIconTile)))
        .palette
        .card;
    const fillAlpha = 0x24 / 255;
    // The decoration holds the RAW alpha fill — compositing over the card
    // happens at paint time, so assert the raw value, not alphaBlend.
    expect(decoration.color, accent.withValues(alpha: fillAlpha));
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.size, closeTo(0.54 * 28, 1e-9));
    // The glyph ink is the shared readable-glyph ladder (>= 3:1 on the fill),
    // not the raw accent.
    expect(icon.color,
        dsReadableGlyph(accent, isDark: false, cardSurface: card));
    expect(icon.color, isNot(accent));
  });

  testWidgets('scales with size', (tester) async {
    await pump(tester, size: 34);
    final box = tester.widget<Container>(find.byType(Container));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(0.32 * 34));
  });

  testWidgets('renders in RTL and LTR without exceptions', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    await pump(tester, textDirection: TextDirection.ltr);
    expect(tester.takeException(), isNull);
  });
}
