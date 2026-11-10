import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/design_system/components/components.dart';

/// The contract [SectionPage] now owns on behalf of nine pages.
///
/// Each of those pages used to re-type the transparent scaffold, the two
/// elevation pins and the title style by hand, and two of them (روزه، وضو) had
/// already drifted: their app bar grew a Material-3 surface band the moment a
/// list scrolled under it. These assertions are what makes that drift a test
/// failure instead of a screenshot someone has to notice.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget page) => MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: page),
      );

  SectionPage page({List<SectionSearchEntry>? searchEntries}) => SectionPage(
        id: 'probe',
        title: 'بخش آزمایشی',
        tabs: const ['یک', 'دو'],
        searchEntries: searchEntries,
        children: const [Text('body-one'), Text('body-two')],
      );

  testWidgets('the scaffold stays transparent over the ambient field',
      (tester) async {
    await tester.pumpWidget(wrap(page()));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.transparent);
  });

  testWidgets('the app bar never paints a surface band when scrolled under',
      (tester) async {
    await tester.pumpWidget(wrap(page()));
    await tester.pump();

    final bar = tester.widget<AppBar>(find.byType(AppBar));
    // Material 3 tints a scrolled-under bar with the surface colour; over the
    // gradient that reads as a flat band, which is exactly the defect روزه and
    // وضو shipped with.
    expect(bar.elevation, 0);
    expect(bar.scrolledUnderElevation, 0);
    expect(bar.surfaceTintColor, Colors.transparent);
    expect(bar.backgroundColor, Colors.transparent);
    expect(bar.centerTitle, isTrue);
    expect(find.text('بخش آزمایشی'), findsOneWidget);
  });

  testWidgets('the tab strip is the shared FlatTabs, one tab per child',
      (tester) async {
    await tester.pumpWidget(wrap(page()));
    await tester.pump();

    expect(find.byType(FlatTabs), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    for (final label in ['یک', 'دو']) {
      expect(find.text(label), findsOneWidget);
    }

    // The strip really drives the views.
    expect(find.text('body-one'), findsOneWidget);
    await tester.tap(find.text('دو'));
    await tester.pumpAndSettle();
    expect(find.text('body-two'), findsOneWidget);
  });

  testWidgets('no search action when the page has no index', (tester) async {
    await tester.pumpWidget(wrap(page()));
    await tester.pump();

    expect(find.byType(SectionSearchAction), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);
  });

  testWidgets('a supplied index turns into a working search action',
      (tester) async {
    await tester.pumpWidget(wrap(page(searchEntries: const [
      SectionSearchEntry(tab: 1, tabLabel: 'دو', title: 'طواف'),
    ])));
    await tester.pump();

    expect(find.byType(SectionSearchAction), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'طواف');
    await tester.pumpAndSettle();
    expect(find.text('طواف'), findsWidgets);

    // Choosing the hit closes the sheet and switches to the tab it names.
    await tester.tap(find.text('طواف').last);
    await tester.pumpAndSettle();
    expect(find.text('body-two'), findsOneWidget);
  });

  testWidgets('an entry without a tab closes the sheet and goes nowhere',
      (tester) async {
    // ختم قرآن has no tab strip; the card is the answer, so a tap must not
    // throw on a missing controller or a null index.
    await tester.pumpWidget(wrap(page(searchEntries: const [
      SectionSearchEntry(title: 'سورهٔ الكهف', body: 'جزء ۱۵'),
    ])));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'کهف');
    await tester.pumpAndSettle();
    await tester.tap(find.text('سورهٔ الكهف'));
    await tester.pumpAndSettle();

    // Sheet gone, page still on its first tab.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('body-one'), findsOneWidget);
  });

  test('mismatched tabs and children is a construction error', () {
    expect(
      () => SectionPage(
        id: 'bad',
        title: 'ناقص',
        tabs: const ['یک', 'دو'],
        children: const [Text('only-one')],
      ),
      throwsAssertionError,
    );
  });
}
