import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/design_system/components/section_header.dart';
import 'package:tawheeed/core/design_system/components/share_card_palette.dart';
import 'package:tawheeed/features/home/presentation/widgets/friday_adab_card.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/shared/services/friday_content.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/widgets/expandable_text.dart';

/// 2026-10-16 is a Thursday; 2026-10-16 + 1 = Friday. Pinned so the day gate
/// never depends on the calendar the suite runs on.
final DateTime _friday = DateTime(2026, 10, 16, 9, 30);
final DateTime _notFriday = DateTime(2026, 10, 15, 9, 30);

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, {DateTime? now}) async {
  await tester.pumpWidget(_wrap(FridayAdabCard(now: now)));
  await tester.pump();
}

String _readSource(String rel) {
  // This repo's files can check out CRLF on Windows; normalise so a plain
  // `contains` never fails on the line endings alone.
  final f = File(rel);
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  testWidgets('renders nothing on a non-Friday day', (tester) async {
    await _pump(tester, now: _notFriday);
    expect(find.text(FridayContent.title), findsNothing);
    expect(find.byType(SectionHeader), findsNothing);
  });

  testWidgets('renders on Friday with the single-source content',
      (tester) async {
    await _pump(tester, now: _friday);
    expect(find.text(FridayContent.title), findsOneWidget);
    // Headline hadith from the shared source.
    expect(find.text(FridayContent.headline.arabic), findsOneWidget);
    // Always fully expanded: every adab on screen, and the header carries no
    // «N آداب مستحب…» subtitle any more (user decision, 2026-10-16).
    for (final a in FridayContent.adabs) {
      expect(find.text(a.title), findsOneWidget);
    }
    final header = tester.widget<SectionHeader>(find.byType(SectionHeader));
    expect(header.description, isNull);
  });

  testWidgets('no «بیشتر»/«بستن» control anywhere — the card is fully open',
      (tester) async {
    await _pump(tester, now: _friday);
    expect(find.byKey(const ValueKey('friday_adab_toggle')), findsNothing);
    expect(find.textContaining('بیشتر'), findsNothing);
    expect(find.textContaining('بستن'), findsNothing);
  });

  testWidgets('every row keeps its own hadith and source on screen',
      (tester) async {
    await _pump(tester, now: _friday);
    for (final a in FridayContent.adabs.where((a) => a.hadith != null)) {
      final h = a.hadith!;
      // The row body is ONE text shown IN FULL (detail + «hadith» —
      // translation (source)) — there is no expander that could hide a line
      // or drop a source from the reader's reach.
      expect(find.textContaining(h.arabic), findsOneWidget,
          reason: '${a.title} must carry «${h.arabic}»');
      expect(find.textContaining(h.source), findsAtLeastNWidgets(1),
          reason: '${a.title} must name its own source');
    }
    // No per-row (or card-level) expander survives anywhere on the card.
    expect(find.byType(ExpandableText), findsNothing);
  });

  testWidgets('both share actions are offered with their tooltips',
      (tester) async {
    await _pump(tester, now: _friday);
    expect(find.byTooltip('اشتراک متن'), findsOneWidget);
    expect(find.byTooltip('اشتراک تصویر'), findsOneWidget);
  });

  testWidgets('the accent is the section\'s own fixed topic colour',
      (tester) async {
    expect(HomeColors.friday, isNot(const Color(0xFF558B2F))); // not ریاض
    await _pump(tester, now: _friday);
    final tile = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(DuotoneIconTile),
        matching: find.byType(Container),
      ),
    );
    expect(tile, isNotEmpty);
  });

  testWidgets('no overflow at 320dp × 1.3 text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(320, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, now: _friday);
    // The card is always fully expanded — the worst case is already on screen.
    expect(tester.takeException(), isNull);
  });

  // The card's raster baseline lives with the other home cards, in
  // home_golden_test.dart ('home_friday_day.png') — one place, one recipe.

  testWidgets(
      'the exported surface is opaque cream with fixed ink, whatever theme',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: const Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(child: FridayAdabShareCard()),
        ),
      ),
    ));

    // The reported «تاریک» share: the export must never inherit the sender's
    // dark theme, and it must be OPAQUE — a transparent PNG (the boundary
    // used to sit inside AppCard, outside its background) flattens to black
    // in messaging apps.
    final surface = tester
        .widget<Container>(find.byKey(const ValueKey('friday-share-surface')));
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, ShareCardPalette.bg);
    expect(decoration.color!.a, 1.0);

    final arabic =
        tester.widget<Text>(find.text(FridayContent.headline.arabic));
    expect(arabic.style?.color, ShareCardPalette.ink);

    // Same words as the on-screen card: every adab, in full, with its own
    // hadith and source.
    for (final a in FridayContent.adabs) {
      expect(find.text(a.title), findsOneWidget);
      expect(find.textContaining(a.hadith?.arabic ?? a.detail), findsOneWidget);
      final h = a.hadith;
      if (h != null) {
        expect(find.textContaining(h.source), findsAtLeastNWidgets(1));
      }
    }

    // The export surface carries no interactive share controls.
    expect(find.byTooltip('اشتراک متن'), findsNothing);
    expect(find.byTooltip('اشتراک تصویر'), findsNothing);
  });

  testWidgets('the image share captures an off-screen export surface',
      (tester) async {
    GlobalKey? capturedKey;
    var exportInsideBoundary = false;
    await tester.pumpWidget(_wrap(FridayAdabCard(
      now: _friday,
      captureCard: (key) async {
        capturedKey = key;
        exportInsideBoundary = find
            .descendant(
              of: find.byKey(key),
              matching: find.byType(FridayAdabShareCard),
            )
            .evaluate()
            .isNotEmpty;
        // Stop before the platform share sheet; the point here is WHICH
        // surface the rasterizer is handed.
        throw const ShareCaptureException('test-stop');
      },
    )));
    await tester.pump();

    await tester.tap(find.byTooltip('اشتراک تصویر'));
    await tester.pump();
    expect(find.byType(FridayAdabShareCard), findsOneWidget,
        reason: 'the export surface is built into the overlay, off screen');

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(capturedKey, isNotNull);
    expect(exportInsideBoundary, isTrue,
        reason: 'the captured boundary wraps the cream export surface, '
            'never the theme-following on-screen card');
    expect(find.byType(FridayAdabShareCard), findsNothing,
        reason: 'the overlay entry is removed after the capture');
    expect(find.text('test-stop'), findsOneWidget);

    // Let the failure snackbar's own timer/animation finish.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  test('the card sits below the reminders box on the home page', () {
    final src =
        _readSource('lib/features/home/presentation/screens/home_tab.dart');
    final reminders = src.indexOf('const RemindersCard()');
    final friday = src.indexOf('const FridayAdabCard()');
    final quick = src.indexOf('const QuickActions()');
    expect(reminders, isNot(-1));
    expect(friday, greaterThan(reminders),
        reason: 'the Friday card must come after the reminders card');
    expect(quick, greaterThan(friday),
        reason: 'the Friday card must come before quick access');
  });

  test('the day gate only passes on Friday', () {
    // Sanity on the day gate itself: a Friday passes, its Thursday does not.
    expect(FridayContent.isFriday(DateTime(2026, 10, 16)), isTrue);
    expect(FridayContent.isFriday(DateTime(2026, 10, 15)), isFalse);
    expect(FridayContent.isFriday(DateTime(2026, 10, 18)), isFalse);
  });
}
