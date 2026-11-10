import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/app/router/home_bottom_nav.dart';
import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int currentIndex,
  required void Function(int) onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        bottomNavigationBar: HomeBottomNav(
          currentIndex: currentIndex,
          onTap: onTap,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('six equal pills with labels inside, selected state marked',
      (tester) async {
    var tapped = -1;
    await _pump(tester, currentIndex: 0, onTap: (i) => tapped = i);

    // All six labels render exactly once — inside the pills.
    for (final label in [
      'خانه',
      'قرآن',
      'تسبیح',
      'تقویم',
      'ارزیابی',
      'بیشتر'
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    // Semantics: every tab exposes its label + selected flag.
    final semantics = tester.getSemantics(find.text('خانه'));
    expect(semantics.label, contains('خانه'));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    final other = tester.getSemantics(find.text('قرآن'));
    expect(other.flagsCollection.isSelected, Tristate.isFalse);

    // Pills share the row equally: same widths.
    final pillWidths = <double>[];
    for (final label in [
      'خانه',
      'قرآن',
      'تسبیح',
      'تقویم',
      'ارزیابی',
      'بیشتر'
    ]) {
      final pill = find
          .ancestor(
            of: find.text(label),
            matching: find.byType(Container),
          )
          .first;
      pillWidths.add(tester.getSize(pill).width);
    }
    for (final w in pillWidths) {
      expect(w, moreOrLessEquals(pillWidths.first, epsilon: 0.5));
    }

    // Tapping switches.
    await tester.tap(find.text('تقویم'));
    await tester.pump();
    expect(tapped, 3);
  });

  testWidgets('selected pill moves with currentIndex', (tester) async {
    await _pump(tester, currentIndex: 4, onTap: (_) {});
    expect(
      tester.getSemantics(find.text('ارزیابی')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(find.text('خانه')).flagsCollection.isSelected,
      Tristate.isFalse,
    );
  });

  testWidgets('no overflow at 320dp width with text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HomeBottomNav(
              currentIndex: 4,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('ارزیابی'), findsOneWidget);
  });

  // "Each tab lights up in its own colour": the selected pill must carry the
  // SAME hue as the tab's identity, not the theme's navy for all six — and the
  // cream label must stay readable on it in every theme.
  testWidgets('the selected pill wears the tab\'s own hue at AA contrast',
      (tester) async {
    const tabs = <(String, Color)>[
      ('خانه', SectionHues.home),
      ('قرآن', SectionHues.quran),
      ('تسبیح', SectionHues.tasbih),
      ('تقویم', SectionHues.calendar),
      ('ارزیابی', SectionHues.evaluation),
      ('بیشتر', SectionHues.more),
    ];

    for (var i = 0; i < tabs.length; i++) {
      final (label, hue) = tabs[i];
      await _pump(tester, currentIndex: i, onTap: (_) {});

      final pill = find
          .ancestor(
            of: find.text(label),
            matching: find.byType(Container),
          )
          .first;
      final decoration =
          tester.widget<Container>(pill).decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      final top = gradient.colors.first;
      final bottom = gradient.colors.last;

      expect(
        (HSVColor.fromColor(top).hue - HSVColor.fromColor(hue).hue).abs(),
        lessThan(3),
        reason: '$label must keep its SectionHue',
      );
      expect(top, isNot(bottom), reason: '$label keeps the soft top-to-bottom');
      expect(
        dsContrastRatio(AppPalette.cream, top),
        greaterThanOrEqualTo(4.5),
        reason: '$label label must stay readable on its own pill',
      );
    }
  });

  // The tab pill must settle on the SAME frame as the tap. The old 180 ms
  // ease tweened a gradient and two text colours on every tab switch, which
  // read as lag on the phones this app targets.
  testWidgets('the pill switches on the first frame, with no tween',
      (tester) async {
    await _pump(tester, currentIndex: 0, onTap: (_) {});

    expect(
      find.descendant(
        of: find.byType(HomeBottomNav),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
      reason: 'no implicit animation may remain in the bar',
    );

    // One rebuild (the shell passes the new index) and one pump: the final
    // colour is already there, there is no intermediate frame to wait for.
    await _pump(tester, currentIndex: 5, onTap: (_) {});
    final pill = find
        .ancestor(of: find.text('بیشتر'), matching: find.byType(Container))
        .first;
    final decoration =
        tester.widget<Container>(pill).decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(
      (HSVColor.fromColor(gradient.colors.first).hue -
              HSVColor.fromColor(SectionHues.more).hue)
          .abs(),
      lessThan(3),
    );
  });
}
