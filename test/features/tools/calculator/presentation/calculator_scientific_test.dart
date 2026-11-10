import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/tools/calculator/presentation/screens/calculator_screen.dart';

Future<void> _pump(WidgetTester tester, ProviderContainer container) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CalculatorScreen()),
    ),
  );
}

/// Taps a key, scrolling it into view first (keyboards are scrollable).
Future<void> _tapKey(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
}

String _displayText(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(const ValueKey('calc_display')));
  return text.data!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.withConnection(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('علمی mode shows the scientific keys', (tester) async {
    await _pump(tester, container);
    await tester.pumpAndSettle();

    // Standard keyboard: no science keys yet.
    expect(find.text('sin'), findsNothing);
    expect(find.text('MC'), findsOneWidget);

    await _tapKey(tester, 'علمی');
    await tester.pumpAndSettle();

    expect(find.text('sin'), findsOneWidget);
    expect(find.text('cos'), findsOneWidget);
    expect(find.text('tan'), findsOneWidget);
    expect(find.text('√'), findsOneWidget);
    expect(find.text('x²'), findsOneWidget);
    expect(find.text('xʸ'), findsOneWidget);
    expect(find.text('x!'), findsOneWidget);
    expect(find.text('1/x'), findsOneWidget);
    expect(find.text('π'), findsOneWidget);
    expect(find.text('e'), findsOneWidget);
    // Digits and memory keys stay reachable in scientific mode.
    expect(find.text('7'), findsOneWidget);
    expect(find.text('MS'), findsOneWidget);
  });

  testWidgets('sin wraps the entered value and evaluates in degrees',
      (tester) async {
    await _pump(tester, container);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'علمی');
    await tester.pumpAndSettle();

    await _tapKey(tester, '4');
    await _tapKey(tester, '5');
    await _tapKey(tester, 'sin');
    expect(_displayText(tester), 'sin(45)');

    await _tapKey(tester, '=');
    expect(_displayText(tester), '0.7071067812');
  });

  testWidgets('power, square and factorial keys evaluate correctly',
      (tester) async {
    await _pump(tester, container);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'علمی');
    await tester.pumpAndSettle();

    // xʸ: 2 ^ 3 = 8
    await _tapKey(tester, '2');
    await _tapKey(tester, 'xʸ');
    await _tapKey(tester, '3');
    await _tapKey(tester, '=');
    expect(_displayText(tester), '8');

    // x²: 3² = 9
    await _tapKey(tester, '3');
    await _tapKey(tester, 'x²');
    expect(_displayText(tester), '(3)^2');
    await _tapKey(tester, '=');
    expect(_displayText(tester), '9');

    // x!: 5! = 120
    await _tapKey(tester, '5');
    await _tapKey(tester, 'x!');
    expect(_displayText(tester), '(5)!');
    await _tapKey(tester, '=');
    expect(_displayText(tester), '120');
  });

  testWidgets('pi inserts the constant and evaluates', (tester) async {
    await _pump(tester, container);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'علمی');
    await tester.pumpAndSettle();

    await _tapKey(tester, '2');
    await _tapKey(tester, '×');
    await _tapKey(tester, 'π');
    expect(_displayText(tester), '2*π');
    await _tapKey(tester, '=');
    expect(_displayText(tester), '6.2831853072');
  });

  testWidgets('memory keys store, recall, add and clear', (tester) async {
    await _pump(tester, container);
    await tester.pumpAndSettle();

    // 5 MS → indicator appears.
    await _tapKey(tester, '5');
    await _tapKey(tester, 'MS');
    expect(find.byKey(const ValueKey('memory_indicator')), findsOneWidget);

    // C MR → recalls 5.
    await _tapKey(tester, 'C');
    await _tapKey(tester, 'MR');
    expect(_displayText(tester), '5');

    // 3 M+ → memory = 5 + 3 = 8.
    await _tapKey(tester, '3');
    await _tapKey(tester, 'M+');
    await _tapKey(tester, 'C');
    await _tapKey(tester, 'MR');
    expect(_displayText(tester), '8');

    // MC clears; MR does nothing.
    await _tapKey(tester, 'MC');
    expect(find.byKey(const ValueKey('memory_indicator')), findsNothing);
    await _tapKey(tester, 'C');
    await _tapKey(tester, 'MR');
    expect(_displayText(tester), '0');
  });
}
