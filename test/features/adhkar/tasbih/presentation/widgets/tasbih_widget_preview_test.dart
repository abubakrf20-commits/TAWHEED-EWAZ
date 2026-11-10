import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/widgets/tasbih_widget_preview.dart';
import 'package:tawheeed/features/settings/presentation/widgets/widget_design_tokens.dart';

Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  testWidgets('TasbihWidgetPreview renders', (tester) async {
    await tester.pumpWidget(wrap(const TasbihWidgetPreview()));
    await tester.pump();
    expect(find.byType(TasbihWidgetPreview), findsOneWidget);
  });

  testWidgets('the caption is «2/5 · today N», always on', (tester) async {
    await tester.pumpWidget(wrap(const TasbihWidgetPreview()));
    // Single zikr: no position half, but the day total always renders —
    // the native caption never pops in and out between taps.
    expect(find.text('امروز 0'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const TasbihWidgetPreview(
        zikrCount: 5,
        zikrIndex: 1,
        todayCount: 42,
      )),
    );
    await tester.pump();
    // Latin digits — the native caption is built by a Kotlin template.
    expect(find.text('2/5 · امروز 42'), findsOneWidget);
  });

  testWidgets('the completed state reads green, the target badge with it',
      (tester) async {
    await tester.pumpWidget(
      wrap(const TasbihWidgetPreview(
        count: 100,
      )),
    );
    await tester.pump();

    final number = tester.widget<Text>(find.text('100'));
    // The preview now reads AppPalette.emerald, the same green the native
    // card paints for a completed day, instead of its own bright green.
    expect(number.style?.color, const Color(0xFF1B7A4B));
    expect(find.text('✓ کامل شد'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const TasbihWidgetPreview(count: 4)),
    );
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('4')).style?.color,
      const Color(0xFFC9A94E),
    );
  });

  testWidgets('a light palette darkens the success green', (tester) async {
    await tester.pumpWidget(
      wrap(const TasbihWidgetPreview(count: 33, target: 33, light: true)),
    );
    await tester.pump();
    expect(tester.widget<Text>(find.text('33')).style?.color,
        const Color(0xFF1B7A4B));
  });

  testWidgets('no counter label carries a text halo any more', (tester) async {
    await tester.pumpWidget(wrap(const TasbihWidgetPreview(target: 33)));
    await tester.pump();

    // The halo was pure look, not legibility — the flat widget dropped it, so
    // the preview must not paint one either.
    for (final label in ['0', 'از 33', 'الله أكبر']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.shadows, isNull, reason: '$label still paints a halo');
    }
  });

  testWidgets('each button pill sits in a 44 dp touch row', (tester) async {
    await tester.pumpWidget(wrap(const TasbihWidgetPreview()));
    await tester.pump();

    for (final glyph in ['‹', '↻', '›']) {
      final text = find.text(glyph);
      final row = find.ancestor(of: text, matching: find.byType(SizedBox)).first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(44.0),
          reason: '$glyph lost its Android touch minimum');
      final pill =
          find.ancestor(of: text, matching: find.byType(Container)).first;
      expect(tester.getSize(pill).height, lessThanOrEqualTo(36.0),
          reason: '$glyph pill must stay airy inside the touch row');
    }
  });

  testWidgets('the card carries the shared widget corner radius',
      (tester) async {
    await tester.pumpWidget(wrap(const TasbihWidgetPreview()));
    await tester.pump();

    final card = tester.widget<Container>(
      find
          .descendant(
              of: find.byType(TasbihWidgetPreview),
              matching: find.byType(Container))
          .first,
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(
      decoration.borderRadius,
      BorderRadius.circular(WidgetTokens.widgetRadius),
    );
  });
}
