import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/tools/calculator/presentation/screens/calculator_screen.dart';

Future<void> _pump(WidgetTester tester, ProviderContainer container,
    {Key? key}) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: CalculatorScreen(key: key)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('persists the selected tool mode across re-opens',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _pump(tester, container);
    await tester.pumpAndSettle();

    // Default mode is the standard calculator.
    expect(find.text('محاسبهٔ قسط قرض الحسنه'), findsNothing);

    await tester.tap(find.text('قسط قرض الحسنه'));
    await tester.pumpAndSettle();
    expect(find.text('محاسبهٔ قسط قرض الحسنه'), findsOneWidget);

    // Re-open the screen with a fresh state: the mode must be restored.
    await _pump(tester, container, key: UniqueKey());
    await tester.pumpAndSettle();
    expect(find.text('محاسبهٔ قسط قرض الحسنه'), findsOneWidget);

    // An unknown stored value falls back to the standard mode.
    SharedPreferences.setMockInitialValues({'calculator_mode_v1': 'bogus'});
    await _pump(tester, container, key: UniqueKey());
    await tester.pumpAndSettle();
    expect(find.text('محاسبهٔ قسط قرض الحسنه'), findsNothing);
  });
}
