import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/home/presentation/providers/arc_style_provider.dart';
import 'package:tawheeed/features/home/presentation/widgets/arc/arc_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/arc/home_arc.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';

ArcState _arc({double now = 0.5}) {
  final base = DateTime(2026, 11, 1, 5);
  const fractions = [0.0, 1 / 6, 1 / 3, 0.5, 7 / 12, 8 / 12, 9 / 12, 1.0];
  const labels = ['صبح', 'طلوع', 'ضحی', 'ظهر', 'عصر', 'مغرب', 'عشاء', 'صبح (فردا)'];
  const kinds = [
    ArcMarkerKind.prayer,
    ArcMarkerKind.derived,
    ArcMarkerKind.derived,
    ArcMarkerKind.prayer,
    ArcMarkerKind.prayer,
    ArcMarkerKind.prayer,
    ArcMarkerKind.prayer,
    ArcMarkerKind.prayer,
  ];
  return ArcState(
    markers: [
      for (var i = 0; i < fractions.length; i++)
        ArcMarker(
          label: labels[i],
          kind: kinds[i],
          fraction: fractions[i],
          time: base.add(Duration(hours: i * 2)),
          state: i == 3
              ? ArcMarkerState.next
              : (i < 3 ? ArcMarkerState.passed : ArcMarkerState.upcoming),
          isEnd: i == fractions.length - 1,
        ),
    ],
    nowFraction: now,
    moon: false,
    endTomorrow: true,
  );
}

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF1B2233),
          body: Center(child: child),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the arc renders in every style', () {
    for (final style in HomeArcStyle.values) {
      for (final width in [320.0, 412.0]) {
        testWidgets('${style.wire} at ${width.toInt()}dp', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_host(SizedBox(
            width: width,
            child: HomeArc(
              arc: _arc(),
              style: style,
              smallLabels: true,
              textScale: 1.0,
            ),
          )));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(CustomPaint), findsWidgets);
        });
      }
    }

    testWidgets('lite mode draws the same arc without the sky decoration',
        (tester) async {
      await tester.pumpWidget(_host(SizedBox(
        width: 360,
        child: HomeArc(
          arc: _arc(),
          style: HomeArcStyle.sky,
          smallLabels: false,
          textScale: 1.0,
          lite: true,
        ),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('painter repaint policy', () {
    test('a sub-minute move does not repaint the arc', () {
      final theme = ArcTheme.resolve(true);
      ArcPainter painter(double now) => ArcPainter(
            arc: _arc(now: now),
            style: HomeArcStyle.tags,
            theme: theme,
            textScale: 1,
            smallLabels: true,
          );
      // shouldRepaint(old): the argument is the previous painter.
      expect(painter(0.51005).shouldRepaint(painter(0.51000)), isFalse);
      expect(painter(0.5150).shouldRepaint(painter(0.5100)), isTrue);
    });

    test('every style change repaints', () {
      final theme = ArcTheme.resolve(true);
      final tags = ArcPainter(
        arc: _arc(),
        style: HomeArcStyle.tags,
        theme: theme,
        textScale: 1,
        smallLabels: true,
      );
      final sky = ArcPainter(
        arc: _arc(),
        style: HomeArcStyle.sky,
        theme: theme,
        textScale: 1,
        smallLabels: true,
      );
      final segments = ArcPainter(
        arc: _arc(),
        style: HomeArcStyle.segments,
        theme: theme,
        textScale: 1,
        smallLabels: true,
      );
      expect(tags.shouldRepaint(sky), isTrue);
      expect(segments.shouldRepaint(tags), isTrue);
      expect(tags.shouldRepaint(tags), isFalse);
    });
  });

  group('preferences', () {
    test('tags is the default, and a choice persists', () async {
      final prefs = HomeArcPrefs();
      await pumpEventQueue();
      expect(prefs.style, HomeArcStyle.tags);
      expect(prefs.smallLabels, isTrue);

      await prefs.setStyle(HomeArcStyle.segments);
      await prefs.setSmallLabels(false);
      final stored = await SharedPreferences.getInstance();
      expect(stored.getString(HomeArcPrefs.styleKey), 'segments');
      expect(stored.getBool(HomeArcPrefs.smallLabelsKey), isFalse);

      final reloaded = HomeArcPrefs();
      await pumpEventQueue();
      expect(reloaded.style, HomeArcStyle.segments);
      expect(reloaded.smallLabels, isFalse);
      prefs.dispose();
      reloaded.dispose();
    });

    test('a stored value the app does not know falls back to tags', () async {
      SharedPreferences.setMockInitialValues({
        HomeArcPrefs.styleKey: 'retired-style',
      });
      final prefs = HomeArcPrefs();
      await pumpEventQueue();
      expect(prefs.style, HomeArcStyle.tags);
      prefs.dispose();
    });
  });
}
