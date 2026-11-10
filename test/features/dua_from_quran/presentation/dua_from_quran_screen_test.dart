import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/design_system/components/flat_tabs.dart';
import 'package:tawheeed/features/dua_from_quran/presentation/screens/dua_from_quran_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DuaFromQuranScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('the page keeps the shared tab strip and the correct plural',
      (tester) async {
    await pump(tester);

    // FlatTabs is what every other section page uses; this page had its own
    // green pill (no outline, different metrics) and a broken plural.
    expect(find.byType(FlatTabs), findsOneWidget);
    expect(find.text('دعاها'), findsOneWidget);
    expect(find.text('دعایان'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the scaffold stays transparent so the ambient field shows',
      (tester) async {
    await pump(tester);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.transparent);
    // The app bar must not paint the theme's opaque scaffold tint either.
    final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
    expect(appBar.backgroundColor, Colors.transparent);
  });
}
