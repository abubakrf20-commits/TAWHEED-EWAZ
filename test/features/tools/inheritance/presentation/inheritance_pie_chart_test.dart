import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/inheritance_pie_chart.dart';

InheritanceShare _share({
  required HeirType type,
  required double amount,
  int n = 1,
  int d = 2,
  int count = 1,
}) =>
    InheritanceShare(
      type: type,
      count: count,
      fraction: Frac(n, d),
      amount: amount,
      shareType: ShareType.fard,
      reason: '',
    );

/// The chart's own CustomPaint (Material/Scaffold add internal ones).
final _chartPaint = find.descendant(
  of: find.byType(InheritancePieChart),
  matching: find.byType(CustomPaint),
);

CustomPainter _painterOf(WidgetTester tester) =>
    tester.widget<CustomPaint>(_chartPaint.first).painter!;

Future<void> _pump(WidgetTester tester, List<InheritanceShare> shares,
    {double size = 200, double strokeWidth = 40}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: InheritancePieChart(
          shares: shares, size: size, strokeWidth: strokeWidth),
    ),
  ));
}

void main() {
  final shares = [
    _share(type: HeirType.wife, amount: 250, d: 4),
    _share(type: HeirType.son, amount: 750, n: 3, d: 4),
  ];

  testWidgets('paints without error', (tester) async {
    await _pump(tester, shares);
    expect(tester.takeException(), isNull);
    expect(_chartPaint, findsOneWidget);
  });

  testWidgets('a very small share does not break the sweep', (tester) async {
    // 0.05 of 500 is far below the 0.02 rad segment gap, so the old
    // `sweepAngle - 0.02` produced a negative sweep and drawArc threw.
    await _pump(tester, [
      _share(type: HeirType.wife, amount: 500, d: 1),
      _share(type: HeirType.son, amount: 0.05, d: 1000000),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('negative, NaN and infinite shares are ignored', (tester) async {
    await _pump(tester, [
      _share(type: HeirType.wife, amount: 100),
      _share(type: HeirType.son, amount: -20),
      _share(type: HeirType.daughter, amount: double.nan),
      _share(type: HeirType.fullSister, amount: double.infinity),
    ]);
    expect(tester.takeException(), isNull);
    // The valid share is still charted, so the bogus values were skipped
    // rather than poisoning the total.
    expect(_chartPaint, findsOneWidget);
  });

  testWidgets('a non-positive or non-finite total renders nothing',
      (tester) async {
    for (final amount in [0.0, double.nan, double.infinity]) {
      await _pump(tester, [_share(type: HeirType.wife, amount: amount)]);
      expect(tester.takeException(), isNull);
      expect(_chartPaint, findsNothing);
    }
  });

  testWidgets('an empty share list renders nothing', (tester) async {
    await _pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(_chartPaint, findsNothing);
  });

  testWidgets('a stroke wider than the chart does not throw', (tester) async {
    await _pump(tester, shares, size: 100, strokeWidth: 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repaints when the split changes but the total does not',
      (tester) async {
    await _pump(tester, shares);
    final before = _painterOf(tester);

    // Same total, different distribution: the old shouldRepaint only compared
    // total + share count, so the chart kept the stale arcs.
    await _pump(tester, [
      _share(type: HeirType.wife, amount: 500, d: 1),
      _share(type: HeirType.son, amount: 500, d: 1),
    ]);
    final after = _painterOf(tester);

    expect(after.shouldRepaint(before as dynamic), isTrue);
    expect(before.shouldRepaint(after), isTrue);
  });

  testWidgets('does not repaint for identical data', (tester) async {
    await _pump(tester, shares);
    final before = _painterOf(tester);

    await _pump(tester, shares);
    final after = _painterOf(tester);

    expect(after.shouldRepaint(before as dynamic), isFalse);
    expect(before.shouldRepaint(after), isFalse);
  });

  testWidgets('legend shows a count for pool heirs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InheritancePieLegend(
          shares: [
            _share(type: HeirType.fullSister, amount: 500, count: 3),
            _share(type: HeirType.mother, amount: 100),
          ],
        ),
      ),
    ));
    expect(find.textContaining('3'), findsOneWidget);
  });
}
