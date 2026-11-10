import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/tools/calculator/data/calculator_history.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

final calculatorDaoProvider = Provider<CalculatorDao>((ref) {
  return CalculatorDao(ref.read(appDatabaseProvider));
});

class CalculatorDao {
  final AppDatabase db;
  CalculatorDao(this.db);

  static const int _maxRecords = 100;

  Future<List<CalculationRecord>> getHistory() async {
    final rows = await (db.select(db.calculatorRecordTable)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
    return rows.map(_toRecord).toList();
  }

  Future<void> addRecord(CalculationRecord record) async {
    await db.into(db.calculatorRecordTable).insert(
          CalculatorRecordTableCompanion(
            expression: Value(record.expression),
            result: Value(record.result),
            timestamp: Value(record.timestamp),
            isScientific: Value(record.isScientific),
          ),
        );
    await _trimExcess();
  }

  Future<void> _trimExcess() async {
    final all = await (db.select(db.calculatorRecordTable)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
    if (all.length > _maxRecords) {
      final toDelete = all.skip(_maxRecords).map((r) => r.id);
      await (db.delete(db.calculatorRecordTable)
            ..where((t) => t.id.isIn(toDelete)))
          .go();
    }
  }

  Future<void> clearHistory() async {
    await db.delete(db.calculatorRecordTable).go();
  }

  Future<void> removeRecord(int id) async {
    await (db.delete(db.calculatorRecordTable)..where((t) => t.id.equals(id)))
        .go();
  }

  Future<void> migrateFromLegacyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlag) == true) return;

    const legacyKey = 'calculator_history';
    final jsonList = prefs.getStringList(legacyKey);
    if (jsonList == null || jsonList.isEmpty) {
      await prefs.setBool(_migratedFlag, true);
      return;
    }

    try {
      for (final json in jsonList) {
        final record = CalculationRecord.fromJson(jsonDecode(json));
        await addRecord(record);
      }
    } catch (e) {
      AppLogger.warning('CalculatorDao', 'Legacy migration failed: $e');
    }

    await prefs.setBool(_migratedFlag, true);
    await prefs.remove(legacyKey);
  }

  static const String _migratedFlag = 'calculator_migrated_v1';

  CalculationRecord _toRecord(CalculatorRecordTableData r) {
    return CalculationRecord(
      id: r.id,
      expression: r.expression,
      result: r.result,
      timestamp: r.timestamp,
      isScientific: r.isScientific,
    );
  }
}
