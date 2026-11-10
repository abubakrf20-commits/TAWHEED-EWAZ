import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';

/// The six decisions [SectionAppBar] now owns for the eighty-four pushed pages
/// that re-typed them.
///
/// The bar is not a styling convenience: two of the six are load-bearing.
/// `backgroundColor: transparent` because the route already sits on the ambient
/// field, and both elevation pins because Material 3 tints a scrolled-under bar
/// with the surface colour — over the gradient that is a visible band cutting
/// the glow in two. Screens that dropped the pins grew the band only once their
/// content scrolled, which is exactly the state a screenshot test taken at rest
/// never sees.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  Future<AppBar> pumpBar(WidgetTester tester, Widget bar) async {
    await tester.pumpWidget(wrap(
      Scaffold(appBar: bar as PreferredSizeWidget, body: const SizedBox()),
    ));
    return tester.widget<AppBar>(find.byType(AppBar));
  }

  testWidgets('the bar is transparent and both elevations are pinned at zero',
      (tester) async {
    final bar = await pumpBar(tester, const SectionAppBar(title: 'کتابخانه'));

    expect(bar.backgroundColor, Colors.transparent);
    expect(bar.elevation, 0);
    expect(bar.scrolledUnderElevation, 0);
  });

  testWidgets('the title is the app font, 16dp, w500 and centred',
      (tester) async {
    await pumpBar(tester, const SectionAppBar(title: 'کتابخانه'));

    final title = tester.widget<Text>(find.text('کتابخانه'));
    expect(title.style?.fontWeight, FontWeight.w500);
    expect(title.style?.fontSize, isNotNull);
    expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);
  });

  testWidgets('titleWidget replaces the drawn title, the string still names it',
      (tester) async {
    await pumpBar(
      tester,
      const SectionAppBar(
        title: 'کتابخانه',
        titleWidget: TextField(key: ValueKey('search')),
      ),
    );

    expect(find.byKey(const ValueKey('search')), findsOneWidget);
    expect(find.text('کتابخانه'), findsNothing);
  });

  testWidgets('a bottom strip adds its height to preferredSize',
      (tester) async {
    const bar = SectionAppBar(
      title: 'کتابخانه',
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(48),
        child: SizedBox(height: 48),
      ),
    );

    expect(bar.preferredSize.height, kToolbarHeight + 48);
  });

  testWidgets('actions are passed through in order', (tester) async {
    await pumpBar(
      tester,
      SectionAppBar(
        title: 'کتابخانه',
        actions: [
          IconButton(
              onPressed: () {}, icon: const Icon(Icons.search), tooltip: 'جستجو'),
          IconButton(
              onPressed: () {}, icon: const Icon(Icons.more_vert), tooltip: 'بیشتر'),
        ],
      ),
    );

    expect(find.byTooltip('جستجو'), findsOneWidget);
    expect(find.byTooltip('بیشتر'), findsOneWidget);
  });

  testWidgets('a pushed route keeps its back button', (tester) async {
    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const Scaffold(
                  appBar: SectionAppBar(title: 'کتابخانه'),
                ),
              )),
              child: const Text('برو'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('برو'));
    await tester.pumpAndSettle();

    // The arrow is what makes this bar different from a tab page's: the reader
    // got here from somewhere, and the bar has to say so.
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a root route gets no arrow', (tester) async {
    await pumpBar(tester, const SectionAppBar(title: 'کتابخانه'));

    expect(find.byType(BackButton), findsNothing);
  });
}
