import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/features/search/search.dart';

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => openGlobalSearch(context, ref),
          child: const Text('open-search'),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> openSearch(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: _Host()),
    ));
    await tester.tap(find.text('open-search'));
    await tester.pumpAndSettle();
  }

  testWidgets('openGlobalSearch opens the overlay with hint and categories',
      (tester) async {
    await openSearch(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('جستجو در قرآن، دعا، اذکار و یادداشت‌ها'), findsOneWidget);
    expect(find.text('حداقل 2 حرف وارد کنید'), findsOneWidget);

    // Category chips from the empty-state hint.
    expect(find.text('همه'), findsOneWidget);
    expect(find.text('دعاها'), findsOneWidget);
    expect(find.text('یادداشت‌ها'), findsOneWidget);
    expect(find.text('اذکار'), findsOneWidget);
    expect(find.text('قرآن'), findsOneWidget);
  });

  testWidgets('the hint names the real scope and its «بیشتر» door selects that tab',
      (tester) async {
    // The overlay route makes the host offstage, so the container is held
    // directly instead of being resolved from the host element.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: _Host()),
    ));
    await tester.tap(find.text('open-search'));
    await tester.pumpAndSettle();

    // The label no longer promises «تمام بخش‌ها»; the hint states the four
    // sources and offers the door to the wide search.
    expect(find.text('تمام بخش‌ها...'), findsNothing);
    expect(find.text('این جستجو قرآن، دعاها، اذکار و یادداشت‌ها را می‌گردد.'),
        findsOneWidget);
    expect(container.read(shellTabIndexProvider), 0);

    await tester.tap(find.text('جستجو در همهٔ بخش‌ها'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing, reason: 'overlay must close');
    expect(container.read(shellTabIndexProvider), 5,
        reason: '«بیشتر» is the last shell tab and owns the deep search');
  });

  testWidgets('queries shorter than 2 letters keep the hint and never search',
      (tester) async {
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), 'ب');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Still the empty-state hint — no spinner, no results list.
    expect(find.text('حداقل 2 حرف وارد کنید'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('the leading back button closes the overlay', (tester) async {
    await openSearch(tester);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('open-search'), findsOneWidget);
  });
}
