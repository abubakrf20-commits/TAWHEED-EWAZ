import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/settings/presentation/screens/about_screen.dart';

void main() {
  testWidgets('AboutScreen renders header', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pump();

    expect(find.text('درباره توحید'), findsOneWidget);
    // The «توحید» word under the logo is gone (user request) — the AppBar
    // title and the footer still carry the name.
    expect(find.text('توحید'), findsNothing);
    expect(find.text('همراه عبادت روزانه'), findsOneWidget);
  });

  testWidgets('AboutScreen renders all sections when scrolled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pump();

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('امکانات برنامه'), 200,
        scrollable: list);
    expect(find.text('امکانات برنامه'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('ارتباط با ما'), 300,
        scrollable: list);
    expect(find.text('ارتباط با ما'), findsOneWidget);
  });

  testWidgets('AboutScreen renders feature grid items', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pump();

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('اوقات شرعی'), 100,
        scrollable: list);
    expect(find.text('اوقات شرعی'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('آفلاین کامل'), 400,
        scrollable: list);
    expect(find.text('آفلاین کامل'), findsOneWidget);

    // Sixteen features, four per row — the last cell completes the grid.
    await tester.scrollUntilVisible(find.text('تقویم اسلامی'), 400,
        scrollable: list);
    expect(find.text('تقویم اسلامی'), findsOneWidget);
  });

  testWidgets('the feature grid renders More-style tiles, four per row',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pump();

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('امکانات برنامه'), 200,
        scrollable: list);
    expect(find.text('امکانات برنامه'), findsOneWidget);

    // Four columns with the More tile-size formula, and no legacy IconTile
    // cells inside the grid: their big back-circle read as a gradient behind
    // the glyph (user request: «مثل ایکون‌های بخش بیشتر … گرادیان پس زمینه
    // حذف»). SettingRow icons elsewhere on the page legitimately use IconTile.
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);
    expect(
      find.descendant(
          of: find.byType(GridView), matching: find.byType(IconTile)),
      findsNothing,
    );
  });

  testWidgets('AboutScreen renders action list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pump();

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('اشتراک‌گذاری برنامه'), 300,
        scrollable: list);
    expect(find.text('اشتراک‌گذاری برنامه'), findsOneWidget);
    expect(find.text('حریم خصوصی و دسترسی‌ها'), findsOneWidget);
    expect(find.text('امتیاز به توحید'), findsOneWidget);
  });

  testWidgets('the logo sits flat on the page — no gradient box around it',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pump();

    // `cacheWidth` wraps the AssetImage in a ResizeImage that hides the asset
    // name, so the mark is matched by its box: it is the page's only Image.
    // The logo is 20 % larger than the previous cut (user request: 117 → 140).
    final logo =
        find.byWidgetPredicate((w) => w is Image && w.width == 140);
    expect(logo, findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final image = tester.widget<Image>(logo);
    expect(image.height, 140);

    // The user's verdict on the About header: the mark carries the brand, so
    // nothing paints a box behind it. A Container with a gradient compiles to a
    // DecoratedBox, so checking that covers both.
    expect(
      find.ancestor(
          of: logo,
          matching: find.byWidgetPredicate((w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).gradient != null)),
      findsNothing,
      reason: 'the About logo must not sit inside a gradient box',
    );

    // The identity text stays, inked for the surface instead of for a dark card.
    // The word «توحید» under the mark is gone (user request) — the AppBar
    // title and the footer still carry the name.
    expect(find.text('توحید'), findsNothing);
    expect(find.text('همراه عبادت روزانه'), findsOneWidget);
    expect(find.byType(SettingsValueChip), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('lays out at ${width.toInt()}dp x$scale with no overflow',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const AboutScreen(),
        ));
        await tester.pump();

        final list = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
            find.text('© 1404 - توحید'), 400,
            scrollable: list);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
