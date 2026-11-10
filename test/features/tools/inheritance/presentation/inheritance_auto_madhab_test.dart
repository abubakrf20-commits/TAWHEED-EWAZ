import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_calculator_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

  testWidgets('switching madhab after solving recomputes the result',
      (tester) async {
    tester.view.physicalSize = const Size(900, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InheritanceCalculatorTab()),
    ));
    await tester.pump();

    // Add wife + daughter.
    await tester.tap(find
        .byIcon(Icons.add_circle_outline)
        .at(0)); // شوهر row is hidden for male? no — wife is index 1
    // The first tile is شوهر (hidden for male deceased? no: default male → husband hidden).
    // Safer: locate tiles by their row and use the + button inside.
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline).at(0));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline).at(1));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'محاسبه میراث'));
    await tester.pumpAndSettle();

    // Result card header shows the default madhab.
    expect(find.text('ترکه قابل تقسیم'), findsOneWidget);
    expect(find.text('جمهور'), findsWidgets);

    // Switch madhab → must recompute automatically.
    await tester.tap(find.text('حنفی'));
    await tester.pumpAndSettle();

    expect(find.text('حنفی'), findsWidgets);
    // The result is still shown (auto-recomputed, not cleared).
    expect(find.text('ترکه قابل تقسیم'), findsOneWidget);
  });
}
