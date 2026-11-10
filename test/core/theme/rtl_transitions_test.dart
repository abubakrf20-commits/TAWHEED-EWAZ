import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/rtl_transitions.dart';

void main() {
  Future<void> pumpThemedApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(pageTransitionsTheme: appPageTransitions),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const Scaffold(body: Text('next'))),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pushed page animates through an RTL slide + fade',
      (tester) async {
    await pumpThemedApp(tester);
    await tester.tap(find.text('go'));
    await tester.pump();
    // Mid-flight: the entering page is translated and semi-transparent.
    await tester.pump(const Duration(milliseconds: 100));
    final slide =
        tester.widget<SlideTransition>(find.byType(SlideTransition).last);
    expect(slide.position.value.dx, isNot(0),
        reason: 'page must be sliding mid-transition');
    final fade =
        tester.widget<FadeTransition>(find.byType(FadeTransition).last);
    expect(fade.opacity.value, lessThan(1.0),
        reason: 'page must be fading in mid-transition');
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('pop reverses back to the first page', (tester) async {
    await pumpThemedApp(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
  });
}
