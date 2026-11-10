import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/qibla_dial.dart';

/// The Qibla dial — its rose carries the labels the flat redesign had dropped
/// (user report: «درجه ها حذف شدند … قطب نما که در قبله بود», restored
/// 2026-10-15). The whole screen cannot be pumped in the tester (its map loads
/// OSM tiles over dart:io HttpClient), so the dial is a widget of its own and
/// is verified here: labels, ring geometry, rotation, on-target gold and the
/// accessibility label.

const _gold = Color(0xFFC48A27);

Widget _host({
  double? heading = 0,
  double angle = 0,
  bool isOnTarget = false,
  bool hasFirstReading = true,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: QiblaDial(
          heading: heading,
          angle: angle,
          isOnTarget: isOnTarget,
          hasFirstReading: hasFirstReading,
          gold: _gold,
          palette: AppPalettes.goldLight,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

/// Screen position of a compass bearing (0° up, 90° right) at [radius].
Offset _polar(Offset center, double bearing, double radius) {
  final rad = (bearing - 90) * pi / 180;
  return center + Offset(cos(rad) * radius, sin(rad) * radius);
}

void main() {
  test('qiblaRoseLabel — words at the cardinals, bearings between', () {
    expect(qiblaRoseLabel(0), 'شمال');
    expect(qiblaRoseLabel(90), 'شرق');
    expect(qiblaRoseLabel(180), 'جنوب');
    expect(qiblaRoseLabel(270), 'غرب');
    expect(qiblaRoseLabel(30), '30°');
    expect(qiblaRoseLabel(330), '330°');
  });

  testWidgets('the rose prints four cardinal words and eight bearings',
      (tester) async {
    await tester.pumpWidget(_host());
    for (final word in ['شمال', 'شرق', 'جنوب', 'غرب']) {
      expect(find.text(word), findsOneWidget);
    }
    for (final bearing in [30, 60, 120, 150, 210, 240, 300, 330]) {
      expect(find.text('$bearing°'), findsOneWidget);
    }
    // The cardinal positions carry words, never their numbers.
    expect(find.text('90°'), findsNothing);
    expect(find.text('180°'), findsNothing);
    // Minor steps (every 10°) stay ticks — no label.
    expect(find.text('20°'), findsNothing);
    expect(find.text('100°'), findsNothing);
  });

  testWidgets('every label sits on the r=90 ring at its bearing',
      (tester) async {
    await tester.pumpWidget(_host());
    final dial = tester.getRect(find.byType(QiblaDial));
    expect(dial.size, const Size(264, 264));
    final labels = {
      0: 'شمال',
      30: '30°',
      60: '60°',
      90: 'شرق',
      120: '120°',
      150: '150°',
      180: 'جنوب',
      210: '210°',
      240: '240°',
      270: 'غرب',
      300: '300°',
      330: '330°',
    };
    labels.forEach((bearing, label) {
      final expected = _polar(dial.center, bearing.toDouble(), 90);
      final actual = tester.getRect(find.text(label)).center;
      expect((actual - expected).distance, lessThan(1.5), reason: label);
    });
  });

  testWidgets('the rose rotates with −heading and the needle with the angle',
      (tester) async {
    await tester.pumpWidget(_host(heading: 90, angle: 90));
    final dial = tester.getRect(find.byType(QiblaDial));
    // Facing east (heading 90): north lies to the LEFT of the screen.
    final north = tester.getRect(find.text('شمال')).center;
    expect((north - _polar(dial.center, 270, 90)).distance, lessThan(1.5));
    // Qibla is 90° to the right: the mosque tip rides the r=60 ring (a badge
    // near the hub reads as no needle at all — user report 2026-10-16).
    final mosque = tester.getRect(find.byIcon(Icons.mosque)).center;
    expect((mosque - _polar(dial.center, 90, 60)).distance, lessThan(1.5));
  });

  testWidgets('the needle turns gold only when on target', (tester) async {
    Color badgeColor() => (tester
            .widget<Container>(find
                .ancestor(
                    of: find.byIcon(Icons.mosque),
                    matching: find.byType(Container))
                .first)
            .decoration! as BoxDecoration)
        .color!;
    await tester.pumpWidget(_host());
    expect(badgeColor(), isNot(_gold));
    await tester.pumpWidget(_host(isOnTarget: true));
    expect(badgeColor(), _gold);
  });

  testWidgets('fits a 320 dp phone at scale 1.3, taps and labels for a11y',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tapped = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: _host(isOnTarget: true, onTap: () => tapped++),
    ));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('روبرو قبله هستید'), findsOneWidget);
    await tester.tap(find.byType(QiblaDial));
    expect(tapped, 1);
    // The handle must go before the test body ends — the framework verifies
    // semantics handles ahead of any addTearDown callback.
    handle.dispose();
  });
}
