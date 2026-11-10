import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_collection_kit.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_focus_view.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_list_view.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_session_controller.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_timeline_view.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_view_selector.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/dhikr_view_prefs.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The counters print through the shared formatter, which wraps digits in the
/// LTR isolate; the finder must ask for the same string.
String _num(String value) => NumberFormat.ltrIsolated(value);

ZikrItem _item(String id, {int repeat = 1, String? virtue}) => ZikrItem(
      id: id,
      title: 'ذکر $id',
      arabicText: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      translation: 'ترجمهٔ ذکر $id',
      source: 'صحیح البخاری (۱)',
      period: PrayerPeriod.fajr,
      repeatCount: repeat,
      virtue: virtue ?? '',
    );

/// Four items: a counted 3, a single, a counted 2 with a virtue note, a single.
DhikrSessionController _controller() => DhikrSessionController(items: [
      _item('a', repeat: 3),
      _item('b'),
      _item('c', repeat: 2, virtue: 'فضیلت این ذکر'),
      _item('d'),
    ]);

/// A collection whose first item is said once, for the timeline's pill.
DhikrSessionController _plainFirst() => DhikrSessionController(items: [
      _item('a'),
      _item('b'),
      _item('c'),
    ]);

Widget _host(Widget child, {double width = 360, double scale = 1.0}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

/// The page listens to the controller; the tests must too, or a tap would only
/// change state the widgets never re-read.
Widget _live(
  DhikrSessionController controller,
  Widget Function(BuildContext context) build,
) {
  return AnimatedBuilder(
    animation: controller,
    builder: (context, _) => build(context),
  );
}

void main() {
  group('list mode', () {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('builds at ${width.toInt()}dp / $scale with no overflow',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final controller = _controller();
          await tester.pumpWidget(_host(
            _live(
              controller,
              (context) => DhikrListView(
                controller: controller,
                tone: DhikrTone.of(context),
                showArabic: true,
                arabicSize: 18,
                highlightQuery: '',
                haptics: false,
                onShare: (_) {},
                onCompleteCurrent: () {},
              ),
            ),
            width: width,
            scale: scale,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('the counter pill and «+» walk the count', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => DhikrListView(
          controller: controller,
          tone: DhikrTone.of(context),
          showArabic: false,
          arabicSize: 18,
          highlightQuery: '',
          haptics: false,
          onShare: (_) {},
          onCompleteCurrent: () {},
        ),
      )));
      await tester.pumpAndSettle();

      expect(controller.countOf(0), 0);
      expect(find.text(NumberFormat.fraction(0, 3)), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pump();
      expect(controller.countOf(0), 1);
      expect(find.text(NumberFormat.fraction(1, 3)), findsOneWidget);

      // The plain item's circle completes it.
      await tester.tap(find.bySemanticsLabel('انجام شد').first);
      await tester.pump();
      expect(controller.doneCount, 1);
    });

    testWidgets('a finished card keeps its content and drawn border',
        (tester) async {
      final controller = _controller();
      controller.complete(1);
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => DhikrListView(
          controller: controller,
          tone: DhikrTone.of(context),
          showArabic: true,
          arabicSize: 18,
          highlightQuery: '',
          haptics: false,
          onShare: (_) {},
          onCompleteCurrent: () {},
        ),
      )));
      await tester.pumpAndSettle();
      // The card does not collapse in list mode: the Arabic block stays.
      expect(find.text('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ'), findsWidgets);
      expect(controller.isDone(1), isTrue);
    });

    testWidgets('one completion, one report, one cursor step', (tester) async {
      final controller = DhikrSessionController(items: [
        _item('a'),
        _item('b'),
        _item('c'),
      ]);
      var reported = 0;
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => DhikrListView(
          controller: controller,
          tone: DhikrTone.of(context),
          showArabic: false,
          arabicSize: 18,
          highlightQuery: '',
          haptics: false,
          onShare: (_) {},
          onCompleteCurrent: () {
            reported++;
            controller.advance();
          },
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('انجام شد').first);
      await tester.pumpAndSettle();

      expect(controller.isDone(0), isTrue);
      expect(reported, 1,
          reason: 'the list has exactly one advance per finished dhikr');
      expect(controller.currentIndex, 1, reason: 'and the cursor moved once');

      // Un-ticking is a correction, not a completion: nothing may advance.
      await tester.tap(find.bySemanticsLabel('لغو انجام').first);
      await tester.pumpAndSettle();
      expect(controller.isDone(0), isFalse);
      expect(reported, 1);
      expect(controller.countOf(0), 0,
          reason: 'an un-tick must not invent a partial count');
    });
  });

  group('timeline mode', () {
    testWidgets('the current item is the only full card', (tester) async {
      final controller = _plainFirst();
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => DhikrTimelineView(
          controller: controller,
          tone: DhikrTone.of(context),
          showArabic: true,
          arabicSize: 18,
          haptics: false,
          onShare: (_) {},
          onCompleteCurrent: () {},
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('خواندم · برو بعدی'), findsOneWidget);
      expect(find.text('انجام شد'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a collapsed row becomes the current item when tapped',
        (tester) async {
      final controller = _plainFirst();
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => DhikrTimelineView(
          controller: controller,
          tone: DhikrTone.of(context),
          showArabic: false,
          arabicSize: 18,
          haptics: false,
          onShare: (_) {},
          onCompleteCurrent: () {},
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ذکر c'));
      await tester.pumpAndSettle();
      expect(controller.currentIndex, 2);
    });

    testWidgets('the current pill completes and advances', (tester) async {
      final controller = _plainFirst();
      var advanced = 0;
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => DhikrTimelineView(
          controller: controller,
          tone: DhikrTone.of(context),
          showArabic: false,
          arabicSize: 18,
          haptics: false,
          onShare: (_) {},
          onCompleteCurrent: () {
            advanced++;
            controller.advance();
          },
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('خواندم · برو بعدی'));
      await tester.pumpAndSettle();
      expect(controller.isDone(0), isTrue);
      expect(advanced, 1);
      expect(controller.currentIndex, 1);
      expect(find.text('انجام شد'), findsOneWidget);
    });

    testWidgets('a held button registers the whole target in one tick',
        (tester) async {
      final controller = _controller(); // a: three repetitions
      var reported = 0;
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => DhikrTimelineView(
          controller: controller,
          tone: DhikrTone.of(context),
          showArabic: false,
          arabicSize: 18,
          haptics: false,
          onShare: (_) {},
          onCompleteCurrent: () {
            reported++;
            controller.advance();
          },
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text(kDhikrHoldToRegister), findsOneWidget,
          reason: 'and the card says the gesture exists');
      expect(controller.countOf(0), 0);
      await tester.longPress(find.text('+1  (${NumberFormat.fraction(0, 3)})'));
      await tester.pumpAndSettle();

      expect(controller.isDone(0), isTrue,
          reason: 'the hold is the one tick a «صد بار» dhikr needs');
      expect(controller.countOf(0), 3);
      expect(reported, 1, reason: 'one completion, one report');
      expect(controller.currentIndex, 1);
    });

    for (final width in [320.0, 412.0]) {
      testWidgets('builds at ${width.toInt()}dp / 1.3 with no overflow',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final controller = _controller();
        await tester.pumpWidget(_host(
          _live(
            controller,
            (context) => DhikrTimelineView(
              controller: controller,
              tone: DhikrTone.of(context),
              showArabic: true,
              arabicSize: 24,
              haptics: false,
              onShare: (_) {},
              onCompleteCurrent: () {},
            ),
          ),
          width: width,
          scale: 1.3,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('focus mode', () {
    Widget focus(
      DhikrSessionController controller,
      BuildContext context, {
      bool autoAdvance = true,
      VoidCallback? onNext,
    }) =>
        DhikrFocusView(
          controller: controller,
          tone: DhikrTone.of(context),
          showArabic: true,
          arabicSize: 18,
          autoAdvance: autoAdvance,
          onShare: (_) {},
          onTapRing: () {
            final finished = controller.tap(controller.currentIndex);
            if (finished && autoAdvance) controller.advance();
          },
          // The page's one-tick registration: complete, then the same single
          // advance a finished tap run gets.
          onCompleteAll: () {
            if (controller.complete(controller.currentIndex) && autoAdvance) {
              controller.advance();
            }
          },
          onUndo: () => controller.undo(controller.currentIndex),
          onSkip: () {
            controller.skip(controller.currentIndex);
            controller.advance();
          },
          onPrevious: () {
            if (controller.currentIndex > 0) {
              controller.goTo(controller.currentIndex - 1);
            }
          },
          onNext: onNext ?? controller.advance,
          onRevisitSkipped: () {},
          onRestart: controller.resetAll,
        );

    testWidgets('tapping the ring counts, then advances at the target',
        (tester) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => focus(controller, context),
      )));
      await tester.pumpAndSettle();

      expect(find.text(_num('0')), findsOneWidget);
      await tester.tap(find.text(_num('0')));
      await tester.pump();
      expect(controller.countOf(0), 1);

      await tester.tap(find.text(_num('1')));
      await tester.pump();
      await tester.tap(find.text(_num('2')));
      await tester.pumpAndSettle();

      expect(controller.isDone(0), isTrue);
      expect(controller.currentIndex, 1);
    });

    testWidgets('a held ring registers every repetition at once',
        (tester) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => focus(controller, context),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining(kDhikrHoldToRegister), findsOneWidget,
          reason: 'a counted dhikr says a hold registers it');

      await tester.longPress(find.text(_num('0')));
      await tester.pumpAndSettle();

      expect(controller.isDone(0), isTrue);
      expect(controller.countOf(0), 3);
      expect(controller.currentIndex, 1, reason: 'one advance after the hold');
    });

    testWidgets('without auto-advance the finished dhikr waits for «بعدی»',
        (tester) async {
      final controller = _plainFirst();
      var next = 0;
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => focus(
          controller,
          context,
          autoAdvance: false,
          onNext: () {
            next++;
            final n = controller.nextUnfinishedAfter(controller.currentIndex);
            if (n >= 0) controller.goTo(n);
          },
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_num('0')));
      await tester.pumpAndSettle();
      expect(controller.isDone(0), isTrue);
      expect(controller.currentIndex, 0, reason: 'no auto advance');

      await tester.tap(find.text('بعدی'));
      await tester.pumpAndSettle();
      expect(next, 1);
      expect(controller.currentIndex, 1);
    });

    testWidgets('undo appears after the first count and steps back',
        (tester) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => focus(controller, context),
      )));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      await tester.tap(find.text(_num('0')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      expect(controller.countOf(0), 0);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
    });

    testWidgets('skip moves on without finishing', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => focus(controller, context),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('رد کردن'));
      await tester.pumpAndSettle();
      expect(controller.isSkipped(0), isTrue);
      expect(controller.isDone(0), isFalse);
      expect(controller.currentIndex, 1);
    });

    testWidgets('the completion card appears when everything is done',
        (tester) async {
      final controller = _controller();
      controller.markAll();
      await tester.pumpWidget(_host(_live(
        controller,
        (context) => focus(controller, context),
      )));
      await tester.pumpAndSettle();

      expect(find.text('ماشاءالله، این بخش تمام شد'), findsOneWidget);
      expect(find.text('شروع دوباره'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets('builds at ${width.toInt()}dp / 1.3 without overflow',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final controller = _controller();
        await tester.pumpWidget(_host(
          _live(controller, (context) => focus(controller, context)),
          width: width,
          scale: 1.3,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('mode selector', () {
    testWidgets('shows the three modes and reports the chosen one',
        (tester) async {
      var picked = DhikrViewMode.list;
      await tester.pumpWidget(_host(DhikrViewSelector(
        mode: DhikrViewMode.list,
        onChanged: (mode) => picked = mode,
      )));
      await tester.pumpAndSettle();

      expect(find.text('فهرست'), findsOneWidget);
      expect(find.text('تایم‌لاین'), findsOneWidget);
      expect(find.text('تمرکز'), findsOneWidget);

      await tester.tap(find.text('تمرکز'));
      await tester.pumpAndSettle();
      expect(picked, DhikrViewMode.focus);
    });

    testWidgets('does not overflow at 320dp / 1.3', (tester) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        DhikrViewSelector(
          mode: DhikrViewMode.timeline,
          onChanged: (_) {},
        ),
        width: 320,
        scale: 1.3,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
