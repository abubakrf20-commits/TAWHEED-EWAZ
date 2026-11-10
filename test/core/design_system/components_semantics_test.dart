import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';

Widget app(Widget child) => MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('CheckCircle announces its state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(const CheckCircle(
        checked: true, color: Colors.green)));
    expect(find.bySemanticsLabel('انجام شد'), findsOneWidget);

    await tester.pumpWidget(app(const CheckCircle(
        checked: false, missed: true, color: Colors.green)));
    expect(find.bySemanticsLabel('از دست رفته'), findsOneWidget);

    await tester.pumpWidget(app(const CheckCircle(
        checked: false, color: Colors.green)));
    expect(find.bySemanticsLabel('انجام نشده'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('IconTile carries an optional label for icon-only use',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(const IconTile(
      icon: Icons.mosque_rounded,
      color: Colors.blue,
      semanticLabel: 'مصلی',
    )));
    expect(find.bySemanticsLabel('مصلی'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('AppBottomNav tabs are buttons with a selected state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(AppBottomNav(
      index: 1,
      onSelected: (_) {},
      items: const [
        AppNavItem(
            icon: Icons.home_rounded,
            label: 'خانه',
            hue: Color(0xFF795548)),
        AppNavItem(
            icon: Icons.grid_view_rounded,
            label: 'بیشتر',
            hue: Color(0xFF00897B)),
      ],
    )));
    expect(
        tester.getSemantics(find.text('خانه')),
        matchesSemantics(
            label: 'خانه',
            hasTapAction: true,
            isButton: true,
            hasSelectedState: true));
    expect(
        tester.getSemantics(find.text('بیشتر')),
        matchesSemantics(
            label: 'بیشتر',
            hasTapAction: true,
            isButton: true,
            hasSelectedState: true,
            isSelected: true));
    handle.dispose();
  });

  testWidgets('SegmentedTabs merges its label into a selectable button',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(SegmentedTabs(
      index: 0,
      onChanged: (_) {},
      tabs: const [
        SegmentedTab(label: 'روزانه'),
        SegmentedTab(label: 'هفتگی'),
      ],
    )));
    expect(find.bySemanticsLabel('روزانه'), findsOneWidget);
    expect(find.bySemanticsLabel('هفتگی'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('SliderRow wires a label annotation around the slider',
      (tester) async {
    await tester.pumpWidget(app(SliderRow(
      label: 'ضریب اکول',
      value: 40,
      onChanged: (_) {},
    )));
    // The header text and the annotation both carry the string; assert the
    // annotation node itself, not the merged tree.
    expect(
        find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == 'ضریب اکول'),
        findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
