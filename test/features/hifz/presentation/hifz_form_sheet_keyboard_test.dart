import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hifz/presentation/screens/hifz_screen.dart';
import 'package:tawheeed/features/hifz/presentation/providers/hifz_provider.dart';

class _FakeHifzNotifier extends HifzNotifier {
  @override
  HifzState build() => const HifzState(loaded: true);
}

void main() {
  Widget build() => ProviderScope(
        overrides: [hifzProvider.overrideWith(_FakeHifzNotifier.new)],
        child: const MaterialApp(home: HifzScreen()),
      );

  testWidgets('hafiz form sheet handles keyboard insets without overflow',
      (tester) async {
    // Simulate an open keyboard via a tall bottom view inset.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // Empty state has an "add" entry point; open the sheet from the app bar.
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(find.text('افزودن حافظ'), findsOneWidget);
    // Keyboard-friendly layout: animated padding + scrollable body.
    expect(find.byType(AnimatedPadding), findsWidgets);
    expect(find.byType(SingleChildScrollView), findsWidgets);

    // Typing a name works while the keyboard is up.
    await tester.enterText(find.byType(TextField), 'محمد');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'محمد',
    );
  });
}
