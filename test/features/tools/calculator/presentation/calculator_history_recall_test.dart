import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/tools/calculator/data/calculator_history.dart';
import 'package:tawheeed/features/tools/calculator/data/daos/calculator_dao.dart';
import 'package:tawheeed/features/tools/calculator/presentation/screens/calculator_screen.dart';

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

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CalculatorScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pressKeys(WidgetTester tester, List<String> keys) async {
    for (final key in keys) {
      // .last: the display can mirror the same digit the keypad offers.
      await tester.tap(find.text(key).last);
      await tester.pump();
    }
  }

  Future<void> recallNewest(WidgetTester tester, String expression) async {
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(expression));
    await tester.pumpAndSettle();
  }

  testWidgets('a stored record keeps the pure expression, not the tape line',
      (tester) async {
    await pumpScreen(tester);
    await pressKeys(tester, ['1', '1', '×', '5', '=']);

    final records = await container.read(calculatorDaoProvider).getHistory();
    // «0 11×5» was the old shape — the running total baked in front.
    expect(records.single.expression, '11×5');
  });

  testWidgets('recalling a record and pressing = repeats the original result',
      (tester) async {
    await pumpScreen(tester);
    await pressKeys(tester, ['1', '2', '×', '3', '=']);
    expect(find.text('36'), findsWidgets);

    await recallNewest(tester, '12×3');
    await pressKeys(tester, ['=']);
    expect(find.text('36'), findsWidgets);
    expect(find.textContaining('خطا'), findsNothing);
  });

  testWidgets('legacy tape-prefixed records recall without the stale total',
      (tester) async {
    // Rows written before the storage fix carried the tape line:
    // «<previous result> <expression>» — the chained keypad already repeats
    // the running total inside the expression itself.
    await container.read(calculatorDaoProvider).addRecord(CalculationRecord(
          expression: '1105 1105×3',
          result: '3315',
          timestamp: DateTime(2026),
        ));
    await pumpScreen(tester);

    await recallNewest(tester, '1105 1105×3');
    await pressKeys(tester, ['=']);
    // The DISPLAY groups a quantity (the product rule for a typed number);
    // the stored record and the parsed value stay the raw «3315».
    expect(find.text('3,315'), findsWidgets);
    expect(find.textContaining('خطا'), findsNothing);
  });
}
