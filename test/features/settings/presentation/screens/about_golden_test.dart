import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/settings/presentation/screens/about_screen.dart';

import 'golden_page_fit.dart';

/// Visual baselines for the redesigned About page (Design 1). Four states —
/// the light page at 412 and 320dp, the light page at 1.3 text scale, and the
/// dark page — captured at the page's own measured height so a taller viewport
/// cannot hide a clipped sliver. Like the More set, these guard layout and
/// palette drift; no font is loaded in the test binding, so they do not pin
/// glyph shaping.
Widget _app(ThemeData theme, {double textScale = 1}) {
  // AppTheme.scaledFontSize reads the factor off bodyMedium — the same knob
  // the overflow-matrix tests turn.
  final base = theme.textTheme;
  final scaled = textScale == 1
      ? theme
      : theme.copyWith(
          textTheme: base.copyWith(
            bodyMedium: base.bodyMedium
                ?.copyWith(fontSize: base.bodyMedium!.fontSize! * textScale),
          ),
        );
  return MaterialApp(
    theme: scaled,
    home: const Directionality(
        textDirection: TextDirection.rtl, child: AboutScreen()),
  );
}

/// Pumps at a short surface, measures the real content height, then grows the
/// surface to fit it before the capture.
Future<void> _open(
  WidgetTester tester, {
  required ThemeKind kind,
  required ThemeData theme,
  required double width,
  double textScale = 1,
}) async {
  AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(theme, textScale: textScale));
  await tester.pumpAndSettle();

  // Size the surface to the page's real height: a wrapping row makes the list's
  // own extent estimate unreliable (see `golden_page_fit.dart`).
  await fitPageHeight(tester, width);
}

void main() {
  testWidgets('About golden — day 412dp', (tester) async {
    await _open(tester,
        kind: ThemeKind.day, theme: AppTheme.light, width: 412);
    await expectLater(
        find.byType(AboutScreen), matchesGoldenFile('goldens/about_day.png'));
  });

  testWidgets('About golden — day 320dp', (tester) async {
    await _open(tester,
        kind: ThemeKind.day, theme: AppTheme.light, width: 320);
    await expectLater(find.byType(AboutScreen),
        matchesGoldenFile('goldens/about_day_320.png'));
  });

  testWidgets('About golden — day 412dp, text scale 1.3', (tester) async {
    await _open(tester,
        kind: ThemeKind.day, theme: AppTheme.light, width: 412, textScale: 1.3);
    await expectLater(find.byType(AboutScreen),
        matchesGoldenFile('goldens/about_day_scale13.png'));
  });

  testWidgets('About golden — night 412dp', (tester) async {
    await _open(tester,
        kind: ThemeKind.night, theme: AppTheme.dark, width: 412);
    await expectLater(
        find.byType(AboutScreen), matchesGoldenFile('goldens/about_night.png'));
  });
}
