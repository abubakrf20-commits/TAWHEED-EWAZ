import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/calculator/data/units/local_unit.dart';
import 'package:tawheeed/features/tools/calculator/data/units/local_units_repository.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_models.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_providers.dart';
import 'package:tawheeed/features/tools/calculator/presentation/widgets/unit_converter_view.dart';

class _FakeLocalUnits implements LocalUnitsRepository {
  final List<LocalUnit> rows = [];

  @override
  Future<List<LocalUnit>> load() async => List.of(rows);

  @override
  Future<void> save(LocalUnit unit) async {
    rows.removeWhere((u) => u.id == unit.id);
    rows.add(unit);
  }

  @override
  Future<void> delete(String id) async => rows.removeWhere((u) => u.id == id);

  @override
  Future<void> resetToDefaults() async => rows.clear();
}

final _catalog = UnitsCatalog.parse(
  File('assets/data/units.json').readAsStringSync(),
);

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 1600),
  double scale = 1,
  _FakeLocalUnits? units,
  Map<String, Object> prefs = const {},
}) async {
  AppTheme.applyTheme(kind: ThemeKind.day, phase: TimePhase.day);
  SharedPreferences.setMockInitialValues(prefs);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unitsCatalogProvider.overrideWith((ref) async => _catalog),
        localUnitsRepositoryProvider
            .overrideWithValue(units ?? _FakeLocalUnits()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: UnitConverterView()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the keypad types into «از» and the result updates',
      (tester) async {
    await _pump(tester);
    final state = tester.state<UnitConverterViewState>(
      find.byType(UnitConverterView),
    );
    state.applyKeypad('1');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    // 1 متر = 100 سانتی‌متر
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('a dot is allowed once and backspace removes it', (tester) async {
    await _pump(tester);
    final state = tester.state<UnitConverterViewState>(
      find.byType(UnitConverterView),
    );
    state.applyKeypad('2');
    state.applyKeypad('.');
    state.applyKeypad('5');
    await tester.pump();
    expect(find.text('2.5'), findsOneWidget);
    state.applyKeypad('⌫');
    await tester.pump();
    expect(find.text('2.'), findsOneWidget);
  });

  testWidgets('C clears the input', (tester) async {
    await _pump(tester);
    final state = tester.state<UnitConverterViewState>(
      find.byType(UnitConverterView),
    );
    state.applyKeypad('7');
    state.applyKeypad('C');
    await tester.pump();
    expect(find.text('۷'), findsNothing);
    expect(find.text('۰'), findsOneWidget);
  });

  testWidgets('the local category shows the region note', (tester) async {
    await _pump(
      tester,
      prefs: {'calculator.units.last_category': 'local'},
    );
    expect(find.textContaining('مبنای پیش‌فرض'), findsOneWidget);
    expect(find.textContaining('قابل ویرایش'), findsOneWidget);
  });

  testWidgets('no overflow at 320 dp and scale 1.3', (tester) async {
    await _pump(tester, size: const Size(320, 1600), scale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('golden: converter, day 360', (tester) async {
    await _pump(tester);
    final state = tester.state<UnitConverterViewState>(
      find.byType(UnitConverterView),
    );
    state.applyKeypad('1');
    await tester.pump();
    await expectLater(
      find.byType(UnitConverterView),
      matchesGoldenFile('goldens/unit_converter_day.png'),
    );
  });
}
