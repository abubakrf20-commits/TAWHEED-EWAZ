import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/calculator/data/calculator_history.dart';
import 'package:tawheeed/features/tools/calculator/data/daos/calculator_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CalculatorDao dao;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = CalculatorDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('migrates the legacy SharedPreferences history once', () async {
    final legacy = [
      CalculationRecord(
          expression: '2+2', result: '4', timestamp: DateTime(2025)),
      CalculationRecord(
          expression: '100×5%',
          result: '5',
          timestamp: DateTime(2025, 1, 2),
          isScientific: true),
    ];
    SharedPreferences.setMockInitialValues({
      'calculator_history': [
        for (final r in legacy) jsonEncode(r.toJson()),
      ],
    });

    await dao.migrateFromLegacyIfNeeded();

    final history = await dao.getHistory();
    expect(history, hasLength(2));
    expect(history.first.expression, '100×5%'); // newest first
    expect(history.last.result, '4');

    // Legacy key is removed and re-running is a no-op.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('calculator_history'), isNull);
    expect(prefs.getBool('calculator_migrated_v1'), isTrue);

    await dao.migrateFromLegacyIfNeeded();
    expect(await dao.getHistory(), hasLength(2));
  });

  test('marks migration done without legacy data', () async {
    SharedPreferences.setMockInitialValues({});

    await dao.migrateFromLegacyIfNeeded();

    expect(await dao.getHistory(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('calculator_migrated_v1'), isTrue);
  });

  test('addRecord + trim keeps at most 100 records', () async {
    for (var i = 0; i < 105; i++) {
      await dao.addRecord(CalculationRecord(
        expression: '$i+1',
        result: '${i + 1}',
        timestamp: DateTime(2025).add(Duration(minutes: i)),
      ));
    }
    final history = await dao.getHistory();
    expect(history, hasLength(100));
    expect(history.first.result, '105');
  });
}
