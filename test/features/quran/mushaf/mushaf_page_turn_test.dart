// Test: the reader's page-turn methods — the numbers, the slot wrapper and the
// wiring that makes the choice reachable.
//
// The wrapper deliberately exists in every mode and at every position: dropping
// a link when a page is at rest would change the widget type under a pager slot,
// which unmounts `Qcf4PageViewer` together with the page tree it memoised — the
// move that cost 75–79 ms re-layout frames before (`e198fa7`). The last group
// pins that the chain is unconditional.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/mushaf/mushaf_page_turn.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';

/// One slot's state, read back out of the widget tree.
typedef _SlotFrame = ({
  double dx,
  double tilt,
  double perspective,
  AlignmentGeometry? alignment,
  FilterQuality? quality,
  Rect clip,
  CustomPainter? shade,
  Size size,
});

void main() {
  const pageCount = 604;

  /// The lean of a leaf that has travelled [fraction] of a turn.
  double tiltOf(double fraction) => math.acos(1 - fraction);

  /// The share of the slot the lifted leaf still covers.
  double coverOf(double fraction) {
    final tilt = tiltOf(fraction);
    return math.cos(tilt) / (1 + kMushafFlipDepth * math.sin(tilt));
  }

  MushafTurnFrame frameAt(
    double? page,
    int index, {
    MushafPageTurn mode = MushafPageTurn.bookFlip,
    bool rtl = true,
    int count = pageCount,
  }) =>
      mushafTurnFrameFor(
        mode: mode,
        page: page,
        index: index,
        pageCount: count,
        rtl: rtl,
      );

  group('methods', () {
    test('every method stores its own word', () {
      final wires = MushafPageTurn.values.map((turn) => turn.wire).toList();
      expect(wires.toSet(), hasLength(wires.length));
      expect(wires, <String>['plain', 'bookFlip']);
    });

    test('the sheet offers the two names the reader was promised', () {
      expect(MushafPageTurn.values.map((turn) => turn.label).toList(),
          <String>['عادی', 'ورق کتابی']);
    });

    test('a stored choice survives the rename, and a fresh install slides', () {
      expect(MushafPageTurn.fromWire('plain'), MushafPageTurn.plain);
      expect(MushafPageTurn.fromWire('bookFlip'), MushafPageTurn.bookFlip);
      // The retired roll experiment: its readers asked for a turning page, so
      // they keep one.
      expect(MushafPageTurn.fromWire('scroll'), MushafPageTurn.bookFlip);
      // The old working words: the plain slide is still plain, and both flip
      // experiments were the book turn — nobody who picked a turning page is
      // dropped back to the slide.
      expect(MushafPageTurn.fromWire('slide'), MushafPageTurn.plain);
      expect(MushafPageTurn.fromWire('flip'), MushafPageTurn.bookFlip);
      expect(MushafPageTurn.fromWire('leaf'), MushafPageTurn.bookFlip);
      // Nothing stored is a fresh install, which the spec starts on the plain
      // slide — the effect is opt-in; a word from a build we never shipped
      // cannot throw either.
      expect(MushafPageTurn.fromWire(null), MushafPageTurn.plain);
      expect(MushafPageTurn.fromWire(''), MushafPageTurn.plain);
      expect(MushafPageTurn.fromWire('curl'), MushafPageTurn.plain);
    });

    test('every method carries a glyph and a description', () {
      for (final turn in MushafPageTurn.values) {
        expect(turn.description, isNotEmpty, reason: turn.wire);
        expect(turn.label, isNotEmpty, reason: turn.wire);
        expect(turn.icon, isA<IconData>(), reason: turn.wire);
      }
    });
  });

  group('frame', () {
    test('the plain turn moves nothing at any position', () {
      for (final page in <double?>[null, 0, 1.25, 3, 603.5]) {
        for (var index = 0; index < 4; index++) {
          final frame = frameAt(page, index, mode: MushafPageTurn.plain);
          expect(frame, const MushafTurnFrame.still(),
              reason: 'page $page slot $index');
          expect(frame.isStill, isTrue);
        }
      }
    });

    test('a pager without a settled position paints plainly', () {
      for (final page in <double?>[
        null,
        double.nan,
        double.infinity,
        -0.1,
        pageCount.toDouble(),
      ]) {
        expect(frameAt(page, 1).isStill, isTrue, reason: '$page');
      }
    });

    test('a settled page is drawn by the untouched pipeline', () {
      expect(frameAt(3, 2).isStill, isTrue);
      expect(frameAt(3, 3).isStill, isTrue);
      // Just off the integer the turn has begun, but not before the epsilon.
      expect(frameAt(3 + 2e-5, 3).isStill, isTrue);
      expect(frameAt(3 + 2e-4, 3).isStill, isFalse);
    });

    test('the leaf lifts in place while the page beneath holds still', () {
      final leaf = frameAt(1.25, 1);
      // Both slots cancel the pager: the leaf pivots about the spine where it
      // already sits, and the page beneath does not slide in from the side.
      expect(leaf.dx, -0.25);
      expect(leaf.angle, closeTo(tiltOf(0.25), 1e-12));
      expect(leaf.cover, closeTo(coverOf(0.25), 1e-12));
      expect(leaf.cover, closeTo(0.5692642, 1e-6));
      expect(leaf.progress, 0.25);
      expect(leaf.role, MushafTurnRole.leaf);
      expect(leaf.isTurning, isTrue);

      final reveal = frameAt(1.25, 2);
      expect(reveal.dx, 0.75);
      expect(reveal.role, MushafTurnRole.reveal);
      // The fold is one edge: the page underneath reads the same angle.
      expect(reveal.angle, leaf.angle);
      expect(reveal.cover, leaf.cover);
      expect(reveal.progress, 0.25);

      // Only those two slots move; the rest of the pager is untouched.
      expect(frameAt(1.25, 0).isStill, isTrue);
      expect(frameAt(1.25, 3).isStill, isTrue);
    });

    test('left to right mirrors the shift and the spine', () {
      final leaf = frameAt(1.25, 1, rtl: false);
      expect(leaf.dx, 0.25);
      expect(leaf.cover, coverOf(0.25));

      final reveal = frameAt(1.25, 2, rtl: false);
      expect(reveal.dx, -0.75);
    });

    test('the spine is the right edge in rtl and the left one in ltr', () {
      const frame = MushafTurnFrame(
        dx: 0,
        angle: 1,
        progress: 0.5,
        role: MushafTurnRole.leaf,
      );
      expect(frame.alignmentFor(rtl: true), Alignment.centerRight);
      expect(frame.alignmentFor(rtl: false), Alignment.centerLeft);
    });

    test('the reveal opens from the edge the fold frees', () {
      const size = Size(200, 400);
      // 2.375 is exact in binary, so the widths compare without rounding.
      final reveal = frameAt(2.375, 3);
      final window = size.width * (1 - reveal.cover);

      final rtl = reveal.clipRect(size, rtl: true);
      expect(rtl.left, 0);
      expect(rtl.top, 0);
      expect(rtl.width, window);
      expect(rtl.height, size.height);

      // Mirrored: the window still hangs off the fold, which is now the left
      // edge, so it starts at the right one.
      final ltr = reveal.clipRect(size, rtl: false);
      expect(ltr.left, closeTo(size.width - window, 1e-9));
      expect(ltr.width, window);

      // The leaf and every settled slot are painted whole.
      expect(frameAt(2.375, 2).clipRect(size, rtl: true), Offset.zero & size);
      expect(const MushafTurnFrame.still().clipRect(size, rtl: true),
          Offset.zero & size);
      expect(const MushafTurnFrame.still().cover, 1);
    });

    test('the two painted surfaces tile the slot exactly', () {
      // The leaf's projection is `W·cover` wide and the reveal's window is
      // exactly the rest, so at every angle the two surfaces meet at one edge
      // instead of overlapping or leaving a seam.
      const size = Size(320, 420);
      for (var step = 1; step < 20; step++) {
        final page = 1 + step / 20;
        final leaf = frameAt(page, 1);
        final reveal = frameAt(page, 2);
        expect(
          size.width * leaf.cover + reveal.clipRect(size, rtl: true).width,
          closeTo(size.width, 1e-9),
          reason: 'page $page',
        );
        expect(
          size.width * leaf.cover + reveal.clipRect(size, rtl: false).width,
          closeTo(size.width, 1e-9),
          reason: 'page $page mirrored',
        );
      }
    });

    test('the turn is continuous at both ends', () {
      final start = frameAt(1.0002, 1);
      expect(start.role, MushafTurnRole.leaf);
      expect(start.angle, lessThan(0.03));
      expect(start.cover, greaterThan(0.98));
      expect(
        frameAt(1.0002, 2).clipRect(const Size(320, 420), rtl: true).width,
        lessThan(5),
      );

      final finish = frameAt(1.9998, 1);
      expect(finish.angle, closeTo(math.pi / 2, 0.02));
      expect(finish.cover, lessThan(0.001));
      expect(
        frameAt(1.9998, 2).clipRect(const Size(320, 420), rtl: true).width,
        closeTo(320, 1),
      );
    });

    test('only the leaf carries the camera', () {
      const size = Size(320, 420);

      void expectPose(Matrix4 m, {required double angle, required bool rtl}) {
        // The matrix is the camera times the yaw: `P * Ry`. A yaw leaves the
        // page's own width scaled by cos and lifts its free edge by sin, and
        // the camera divides that lift by the slot width, so the perspective
        // entry carries the same cos.
        final yaw = rtl ? angle : -angle;
        expect(m.entry(0, 0), closeTo(math.cos(yaw), 1e-12));
        expect(m.entry(2, 0), closeTo(-math.sin(yaw), 1e-12));
        expect(
          m.entry(3, 2),
          closeTo(kMushafFlipDepth / size.width * math.cos(yaw), 1e-12),
        );
      }

      void expectIdentity(Matrix4 m) {
        for (var row = 0; row < 4; row++) {
          for (var column = 0; column < 4; column++) {
            expect(
              m.entry(row, column),
              row == column ? 1.0 : 0.0,
              reason: 'entry($row, $column)',
            );
          }
        }
      }

      final leaf = frameAt(1.25, 1);
      expectPose(leaf.matrixFor(rtl: true, size: size),
          angle: leaf.angle, rtl: true);
      final mirrored = frameAt(1.25, 1, rtl: false);
      expectPose(mirrored.matrixFor(rtl: false, size: size),
          angle: mirrored.angle, rtl: false);

      // A slot with no size must still yield a usable matrix, and the camera
      // is then measured in unit widths.
      expect(
        leaf.matrixFor(rtl: true, size: Size.zero).entry(3, 2),
        closeTo(kMushafFlipDepth * math.cos(leaf.angle), 1e-12),
      );

      // Every other slot is the identity, which `RenderTransform` paints
      // without building a layer.
      expectIdentity(frameAt(1.25, 2).matrixFor(rtl: true, size: size));
      expectIdentity(frameAt(1.25, 1, mode: MushafPageTurn.plain)
          .matrixFor(rtl: true, size: size));
      expectIdentity(
          const MushafTurnFrame.still().matrixFor(rtl: true, size: size));
    });

    test('frames compare by their numbers', () {
      expect(frameAt(1.25, 1), frameAt(1.25, 1));
      expect(frameAt(1.25, 1).hashCode, frameAt(1.25, 1).hashCode);
      expect(frameAt(1.25, 1), isNot(frameAt(1.25, 2)));
      expect(frameAt(1.25, 1), isNot(frameAt(1.26, 1)));
    });
  });

  group('slot wrapper', () {
    const viewport = Size(320, 420);

    late PageController controller;
    late StateSetter rebuildPager;
    var mode = MushafPageTurn.bookFlip;

    Future<void> pumpPager(
      WidgetTester tester, {
      TextDirection direction = TextDirection.rtl,
    }) async {
      controller = PageController();
      mode = MushafPageTurn.bookFlip;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(
                width: viewport.width,
                height: viewport.height,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    rebuildPager = setState;
                    return PageView.builder(
                      controller: controller,
                      physics: const NeverScrollableScrollPhysics(),
                      // The reader keeps the neighbour pages resident, which is
                      // why a slot beyond the visible one can still be inspected
                      // here.
                      allowImplicitScrolling: true,
                      itemCount: 4,
                      itemBuilder: (context, index) => MushafTurningPage(
                        controller: controller,
                        index: index,
                        pageCount: 4,
                        mode: mode,
                        palette: MushafPalette.light,
                        child: ColoredBox(
                          color: Colors.white,
                          child: Center(
                            child: Text(
                              'page $index',
                              key: ValueKey('page-$index'),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> settleAt(WidgetTester tester, double page) async {
      controller.jumpTo(controller.position.viewportDimension * page);
      await tester.pump();
    }

    Future<void> switchTo(WidgetTester tester, MushafPageTurn turn) async {
      mode = turn;
      rebuildPager(() {});
      await tester.pump();
    }

    Finder slot(int index) => find.ancestor(
          of: find.byKey(ValueKey('page-$index'), skipOffstage: false),
          matching: find.byType(MushafTurningPage, skipOffstage: false),
        );

    Finder inSlot(int index, Type type) => find.descendant(
          of: slot(index),
          matching: find.byType(type, skipOffstage: false),
        );

    _SlotFrame readSlot(WidgetTester tester, int index) {
      final translation = tester
          .widget<FractionalTranslation>(inSlot(index, FractionalTranslation));
      final clip = tester.widget<ClipRect>(inSlot(index, ClipRect));
      final transform = tester.widget<Transform>(inSlot(index, Transform));
      final paint = tester.widget<CustomPaint>(inSlot(index, CustomPaint));
      final box = tester.renderObject<RenderBox>(inSlot(index, ClipRect));
      final matrix = transform.transform;
      final clipper = clip.clipper!;
      return (
        dx: translation.translation.dx,
        // The lean about the spine, recovered from the rotation the matrix
        // applies to the page's own plane.
        tilt: math.atan2(-matrix.entry(2, 0), matrix.entry(0, 0)).abs(),
        perspective: matrix.entry(3, 2),
        alignment: transform.alignment,
        quality: transform.filterQuality,
        clip: clipper.getClip(box.size),
        shade: paint.foregroundPainter,
        size: box.size,
      );
    }

    testWidgets('the chain is the same in every mode and at every position',
        (tester) async {
      await pumpPager(tester);
      for (final turn in MushafPageTurn.values) {
        await switchTo(tester, turn);
        for (final page in <double>[1, 1.25, 1.5, 1.75, 1.9]) {
          await settleAt(tester, page);
          for (final index in <int>[1, 2]) {
            final where = '${turn.wire} page $page slot $index';
            expect(slot(index), findsOneWidget, reason: where);
            expect(inSlot(index, FractionalTranslation), findsOneWidget,
                reason: where);
            expect(inSlot(index, ClipRect), findsOneWidget, reason: where);
            expect(inSlot(index, Transform), findsOneWidget, reason: where);
            expect(inSlot(index, CustomPaint), findsOneWidget, reason: where);
            // The clip window is written in the pinned child's frame, so it has
            // to live inside the translation, and above the tilt.
            expect(
              find.descendant(
                of: inSlot(index, FractionalTranslation),
                matching: find.byType(ClipRect, skipOffstage: false),
                skipOffstage: false,
              ),
              findsOneWidget,
              reason: where,
            );
            expect(
              find.descendant(
                of: inSlot(index, ClipRect),
                matching: find.byType(Transform, skipOffstage: false),
                skipOffstage: false,
              ),
              findsOneWidget,
              reason: where,
            );
          }
        }
      }
    });

    testWidgets('a settled page paints through the identity chain',
        (tester) async {
      await pumpPager(tester);
      await settleAt(tester, 2);
      for (final index in <int>[1, 2]) {
        final frame = readSlot(tester, index);
        expect(frame.dx, 0, reason: 'slot $index');
        expect(frame.tilt, 0, reason: 'slot $index');
        expect(frame.perspective, 0, reason: 'slot $index');
        expect(frame.quality, isNull, reason: 'slot $index');
        expect(frame.clip, Offset.zero & frame.size, reason: 'slot $index');
        expect(frame.shade, isNull, reason: 'slot $index');
      }
    });

    testWidgets('the leaf hinges on the spine in rtl', (tester) async {
      await pumpPager(tester);
      await settleAt(tester, 1.25);
      final tilt = tiltOf(0.25);
      final cover = coverOf(0.25);

      final leaf = readSlot(tester, 1);
      expect(leaf.size, viewport, reason: 'the slot is one page wide');
      expect(leaf.dx, closeTo(-0.25, 1e-9));
      expect(leaf.tilt, closeTo(tilt, 1e-6));
      // The camera is measured in page widths, and the yaw tilts the lift the
      // camera divides — so the perspective entry carries the same cos.
      expect(
        leaf.perspective,
        closeTo(kMushafFlipDepth / leaf.size.width * math.cos(tilt), 1e-9),
      );
      expect(leaf.alignment, Alignment.centerRight);
      expect(leaf.quality, FilterQuality.low);
      // The leaf itself is never clipped; the tilt is what narrows it.
      expect(leaf.clip, Offset.zero & leaf.size);
      expect(leaf.shade, isNotNull);

      final reveal = readSlot(tester, 2);
      expect(reveal.dx, closeTo(0.75, 1e-9));
      expect(reveal.tilt, 0);
      expect(reveal.perspective, 0);
      expect(reveal.quality, isNull);
      expect(reveal.shade, isNotNull);
      // The window opens away from the spine, at the left edge in rtl.
      expect(reveal.clip.left, 0);
      expect(reveal.clip.width, viewport.width * (1 - cover));
      expect(reveal.clip.height, viewport.height);
    });

    testWidgets('left to right hinges on the other side', (tester) async {
      await pumpPager(tester, direction: TextDirection.ltr);
      await settleAt(tester, 1.25);
      final cover = coverOf(0.25);

      final leaf = readSlot(tester, 1);
      expect(leaf.dx, closeTo(0.25, 1e-9));
      expect(leaf.tilt, closeTo(tiltOf(0.25), 1e-6));
      expect(leaf.alignment, Alignment.centerLeft);

      final reveal = readSlot(tester, 2);
      expect(reveal.dx, closeTo(-0.75, 1e-9));
      expect(reveal.clip.left, closeTo(viewport.width * cover, 1e-9));
      expect(reveal.clip.width, closeTo(viewport.width * (1 - cover), 1e-9));
      expect(reveal.clip.height, viewport.height);
    });

    testWidgets('switching the method keeps the page subtree mounted',
        (tester) async {
      await pumpPager(tester);
      await settleAt(tester, 1.25);
      final before = tester.element(find.byKey(const ValueKey('page-1')));

      await switchTo(tester, MushafPageTurn.plain);
      final after = tester.element(find.byKey(const ValueKey('page-1')));

      expect(identical(before, after), isTrue,
          reason: 'the memoised page tree must survive a method change');
    });

    testWidgets('switching the method mid-turn keeps it mounted too',
        (tester) async {
      await pumpPager(tester);
      await settleAt(tester, 1.6);
      final before = tester.element(find.byKey(const ValueKey('page-1')));

      await switchTo(tester, MushafPageTurn.plain);
      expect(
          identical(
              before, tester.element(find.byKey(const ValueKey('page-1')))),
          isTrue);

      await switchTo(tester, MushafPageTurn.bookFlip);
      final after = tester.element(find.byKey(const ValueKey('page-1')));

      expect(identical(before, after), isTrue);
      expect(readSlot(tester, 1).shade, isNotNull);
      expect(readSlot(tester, 1).tilt, closeTo(tiltOf(0.6), 1e-6));
    });
  });

  group('wiring', () {
    // A CRLF checkout must not make these scans miss.
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    const view = 'lib/features/quran/mushaf/quran_mushaf_view.dart';
    const turn = 'lib/features/quran/mushaf/mushaf_page_turn.dart';

    test('the pager wraps every slot and the reader restores the choice', () {
      final code = read(view);
      expect(code, contains('MushafTurningPage('));
      expect(code, contains('MushafReaderPrefs.loadPageTurnSync(prefs)'));
      expect(code, contains('MushafReaderPrefs.savePageTurn(turn)'));
      // The picker lives in its own section, which the sheet embeds.
      final settings =
          read('lib/features/quran/mushaf/mushaf_page_turn_settings.dart');
      expect(settings,
          contains('for (var i = 0; i < MushafPageTurn.values.length'));
      expect(settings, contains("'افکت ورق‌زدن'"));
      expect(code, contains('MushafPageTurnSection('));
      expect(code,
          contains('MushafReaderPrefs.loadPageChromeByParitySync(prefs)'));
      expect(code, contains('MushafReaderPrefs.savePageTurnSpeed(speed)'));
      expect(code, contains('MushafReaderPrefs.savePageTurnHaptic(on)'));
    });

    test('the wrapper chain is unconditional', () {
      final code = read(turn);
      final wrapper = code.substring(code.indexOf('class MushafTurningPage'));

      final order = <String>[
        'return FractionalTranslation(',
        'child: ClipRect(',
        'child: Transform(',
        'child: CustomPaint(',
      ];
      var previous = -1;
      for (final needle in order) {
        final at = wrapper.indexOf(needle);
        expect(at, greaterThan(previous), reason: needle);
        previous = at;
      }

      // The page stays mounted through the whole turn: the strips hide it with
      // `Visibility` (state, layout and animation kept) instead of swapping the
      // subtree for the painter's image.
      expect(wrapper, contains('maintainState: true'));
      expect(wrapper, contains('maintainAnimation: true'));
      expect(wrapper, contains('maintainSize: true'));
      // Between the translation and the page there is no branch that changes
      // the widget type under the slot.
      final chain = wrapper.substring(
        wrapper.indexOf('return FractionalTranslation('),
        wrapper.indexOf('maintainSize: true'),
      );
      expect(chain, isNot(contains('if (')));
      expect(chain, isNot(contains('mode ==')));
      expect(chain, contains('clipper: _TurnClipper('));
      expect(chain, contains('foregroundPainter:'));
    });

    test('the shading never leaves the palette', () {
      final code = read(turn);
      expect(code, contains('palette.chrome'));
      // The only literal colour is the leaf's back: a fixed 8 % black wash on
      // whatever paper is underneath, which has to stay theme-independent.
      expect(RegExp(r'Color\(0x').allMatches(code), hasLength(1));
      expect(code, contains('Color(0x14000000)'));
      expect(code, isNot(contains('Opacity(')));
      expect(code, isNot(contains('BackdropFilter')));
      expect(code, isNot(contains('blurRadius')));
      expect(code, isNot(contains('saveLayer')));
      expect(code, isNot(contains('TextDirection.ltr')));
    });
  });
}
