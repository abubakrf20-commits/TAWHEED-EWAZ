// Test: the two page-turn effects and the section that offers them.
//
// The geometry is pure numbers ([mushafTurnStripAngles], [mushafTurnStripCount])
// and the painters are pure painters, so everything here runs without a mushaf:
// no glyph is rendered, no page is loaded, and the numbers are the ones the
// reader will see on the device.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_page_turn.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_page_turn_settings.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';

void main() {
  const pageCount = 604;

  group('the book turn', () {
    test('a closed book is flat and an opened one is past a right angle', () {
      const strips = 24;
      final closed = mushafTurnStripAngles(
          mode: MushafPageTurn.bookFlip, p: 0, strips: strips);
      expect(closed, everyElement(0));

      final open = mushafTurnStripAngles(
          mode: MushafPageTurn.bookFlip, p: 1, strips: strips);
      // At the end of the turn the bend has flattened, so every strip sits at
      // the leaf's own 100°.
      for (final angle in open) {
        expect(angle, closeTo(kBookFlipMaxAngle, 1e-9));
      }
      expect(kBookFlipMaxAngle, greaterThan(math.pi / 2),
          reason: 'the leaf must pass edge-on, or the page never turns');
    });

    test('the curve bends in the middle and flattens at both ends', () {
      const strips = 24;
      final middle = mushafTurnStripAngles(
          mode: MushafPageTurn.bookFlip, p: 0.5, strips: strips);
      final first = middle.first;
      final last = middle.last;
      expect(last - first, closeTo((strips - 1) * kBookFlipBend, 1e-9),
          reason: 'the chain accumulates one bend per hinge');

      final quarter = mushafTurnStripAngles(
          mode: MushafPageTurn.bookFlip, p: 0.25, strips: strips);
      expect(quarter.last - quarter.first, lessThan(last - first + 1e-12),
          reason: 'the page is curved, not folded like a door');
    });

    test('hinge count follows the slot width, lite stays cheaper', () {
      // A 412 dp phone gets ~30 hinges at ~14 dp each; the same slot in lite
      // gets roughly half. A fixed count could not promise that: 8 hinges on
      // a dense page kinked the glyph baseline at every seam.
      expect(mushafTurnStripCount(MushafPageTurn.bookFlip,
          width: 412, lite: false), 30);
      expect(mushafTurnStripCount(MushafPageTurn.bookFlip,
          width: 412, lite: true), 15);
      expect(mushafTurnStripCount(MushafPageTurn.bookFlip,
          width: 320, lite: false), greaterThanOrEqualTo(12));
      // The clamps hold at any width, and a plain turn needs no strips.
      expect(mushafTurnStripCount(MushafPageTurn.bookFlip,
          width: 4096, lite: false), kBookFlipStripsMax);
      expect(mushafTurnStripCount(MushafPageTurn.bookFlip,
          width: 4, lite: false), kBookFlipStripsMin);
      expect(
          mushafTurnStripCount(MushafPageTurn.plain, width: 412, lite: false),
          0);
      expect(
          mushafTurnStripCount(MushafPageTurn.bookFlip,
              width: 0, lite: false),
          0);
    });

    test('the leaf only ever rises as the reader turns it', () {
      var previous = -1.0;
      for (var i = 0; i <= 20; i++) {
        final angles = mushafTurnStripAngles(
            mode: MushafPageTurn.bookFlip, p: i / 20, strips: 8);
        expect(angles.first, greaterThanOrEqualTo(previous));
        previous = angles.first;
      }
    });
  });

  group('the chain', () {
    test('an unknown progress or a slot out of reach is still', () {
      for (final page in <double?>[null, double.nan, -1, pageCount + 1]) {
        expect(
          mushafTurnFrameFor(
            mode: MushafPageTurn.bookFlip,
            page: page,
            index: 1,
            pageCount: pageCount,
            rtl: true,
          ).isStill,
          isTrue,
        );
      }
      expect(
        mushafTurnFrameFor(
          mode: MushafPageTurn.bookFlip,
          page: 3.4,
          index: 8,
          pageCount: pageCount,
          rtl: true,
        ).isStill,
        isTrue,
        reason: 'only the leaf and the page beneath it carry the turn',
      );
    });

    test('the leaf and the reveal are the only two roles', () {
      MushafTurnRole roleOf(int index, {bool rtl = true}) => mushafTurnFrameFor(
            mode: MushafPageTurn.bookFlip,
            page: 4.25,
            index: index,
            pageCount: pageCount,
            rtl: rtl,
          ).role;
      expect(roleOf(4), MushafTurnRole.leaf);
      expect(roleOf(5), MushafTurnRole.reveal);
      expect(roleOf(3), MushafTurnRole.none);
    });

    test('RTL travels the other way from LTR', () {
      double dxOf({required bool rtl, required int index}) =>
          mushafTurnFrameFor(
            mode: MushafPageTurn.bookFlip,
            page: 4.25,
            index: index,
            pageCount: pageCount,
            rtl: rtl,
          ).dx;
      expect(dxOf(rtl: true, index: 4), lessThan(0));
      expect(dxOf(rtl: false, index: 4), greaterThan(0));
      expect(dxOf(rtl: true, index: 5), greaterThan(0));
    });

    test('the reveal window is exactly what the leaf has uncovered', () {
      for (final fraction in <double>[0.1, 0.5, 0.9]) {
        final frame = mushafTurnFrameFor(
          mode: MushafPageTurn.bookFlip,
          page: 4 + fraction,
          index: 5,
          pageCount: pageCount,
          rtl: true,
        );
        final clip = frame.clipRect(const Size(400, 800), rtl: true);
        expect(clip.left, 0, reason: 'RTL opens from the binding on the right');
        expect(clip.width, closeTo(400 * (1 - frame.cover), 1e-6));
      }
      // The leaf is never clipped away.
      final leaf = mushafTurnFrameFor(
        mode: MushafPageTurn.bookFlip,
        page: 4.5,
        index: 4,
        pageCount: pageCount,
        rtl: true,
      );
      expect(leaf.clipRect(const Size(400, 800), rtl: true),
          const Rect.fromLTWH(0, 0, 400, 800));
    });

    test('the plain turn is the untouched reader at every position', () {
      for (final page in <double?>[null, 0, 2, 2.5, 603.5]) {
        final frame = mushafTurnFrameFor(
          mode: MushafPageTurn.plain,
          page: page,
          index: 2,
          pageCount: pageCount,
          rtl: true,
        );
        expect(frame, const MushafTurnFrame.still());
      }
    });
  });

  group('the paper back', () {
    test('a turned leaf shows its own back, never a mirrored glyph', () {
      const paper = Color(0xFFF3E9D2);
      final back = mushafLeafBackOn(paper);
      expect(back, isNot(paper));
      expect(back.computeLuminance(), lessThan(paper.computeLuminance()));
    });
  });

  group('the speeds', () {
    test('the three settings are the ones the sheet offers', () {
      expect(MushafTurnSpeed.values.map((s) => s.label).toList(),
          <String>['سریع', 'عادی', 'آهسته']);
      expect(MushafTurnSpeed.fast.millis, 260);
      expect(MushafTurnSpeed.normal.millis, 380);
      expect(MushafTurnSpeed.slow.millis, 520);
      expect(MushafTurnSpeed.fromWire(null), MushafTurnSpeed.normal);
      for (final speed in MushafTurnSpeed.values) {
        expect(MushafTurnSpeed.fromWire(speed.wire), speed);
      }
    });
  });

  group('the painters', () {
    Future<void> paint(void Function(Canvas) drawTest) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      drawTest(canvas);
      recorder.endRecording().dispose();
    }

    test('every thumbnail draws in the current paper', () async {
      for (final turn in MushafPageTurn.values) {
        await paint((canvas) => MushafTurnThumbPainter(
              turn: turn,
              ink: MushafPalette.light.onChrome,
              paper: MushafPalette.light.surface,
              accent: MushafPalette.light.accent,
            ).paint(canvas, const Size(34, 26)));
      }
    });

    test('the preview draws every effect at every step, day and night',
        () async {
      for (final palette in <MushafPalette>[
        MushafPalette.light,
        MushafPalette.night,
      ]) {
        for (final turn in MushafPageTurn.values) {
          for (final p in <double>[0, 0.25, 0.5, 0.75, 1]) {
            await paint((canvas) => MushafTurnPreviewPainter(
                  turn: turn,
                  progress: p,
                  palette: palette,
                ).paint(canvas, const Size(64, 44)));
          }
        }
      }
    });

    test('a repaint is asked for only when something visible changed', () {
      const a = MushafTurnPreviewPainter(
          turn: MushafPageTurn.bookFlip,
          progress: 0.5,
          palette: MushafPalette.light);
      expect(
        a.shouldRepaint(const MushafTurnPreviewPainter(
            turn: MushafPageTurn.bookFlip,
            progress: 0.5,
            palette: MushafPalette.light)),
        isFalse,
      );
      expect(
        a.shouldRepaint(const MushafTurnPreviewPainter(
            turn: MushafPageTurn.plain,
            progress: 0.5,
            palette: MushafPalette.light)),
        isTrue,
      );
    });
  });

  group('the settings section', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      double width = 360,
      double textScale = 1,
      bool reduceMotion = false,
      MushafTurnSpeed speed = MushafTurnSpeed.normal,
      ValueChanged<MushafPageTurn>? onSelected,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: width,
                    child: MushafPageTurnSection(
                      palette: MushafPalette.light,
                      selected: MushafPageTurn.bookFlip,
                      speed: speed,
                      haptic: true,
                      reduceMotion: reduceMotion,
                      onSelected: onSelected ?? (_) {},
                      onSpeed: (_) {},
                      onHaptic: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('it offers the two turns, the preview and the options',
        (tester) async {
      await pumpSection(tester);
      expect(find.text('افکت ورق‌زدن'), findsOneWidget);
      // The two cards are InkWell-backed; «عادی» is also the name of the
      // middle speed, so the cards are counted where the taps are.
      Finder card(String label) =>
          find.descendant(of: find.byType(InkWell), matching: find.text(label));
      for (final turn in MushafPageTurn.values) {
        expect(card(turn.label), findsOneWidget, reason: turn.wire);
      }
      expect(find.text('پیش‌نمایش'), findsOneWidget);
      expect(find.text('سرعت'), findsOneWidget);
      for (final speed in MushafTurnSpeed.values) {
        expect(find.text(speed.label), findsWidgets, reason: speed.wire);
      }
      expect(find.text('لرزش ملایم هنگام ورق‌زدن'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap on a card reports the turn', (tester) async {
      MushafPageTurn? picked;
      await pumpSection(tester, onSelected: (turn) => picked = turn);
      await tester.tap(find.descendant(
          of: find.byType(InkWell), matching: find.text('ورق کتابی')));
      expect(picked, MushafPageTurn.bookFlip);
    });

    testWidgets('the preview plays once without an exception', (tester) async {
      await pumpSection(tester);
      await tester.tap(find.text('پیش‌نمایش'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion explains itself and takes the pick away',
        (tester) async {
      MushafPageTurn? picked;
      await pumpSection(tester,
          reduceMotion: true, onSelected: (turn) => picked = turn);
      expect(
        find.text('با فعال بودن کاهش حرکت سیستم، افکت ساده استفاده می‌شود.'),
        findsOneWidget,
      );
      await tester.tap(find.descendant(
          of: find.byType(InkWell), matching: find.text('ورق کتابی')));
      expect(picked, isNull,
          reason: 'the choice is kept, not changed, while motion is reduced');
    });

    testWidgets('it fits a 320 dp phone at 1.3 text scale', (tester) async {
      await pumpSection(tester, width: 320, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });
}
