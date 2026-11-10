import 'package:drift/drift.dart' show QueryRow;

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/calculator/data/units/local_unit.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Storage for the user's own local-unit base values.
///
/// A database table rather than preferences on purpose: the existing backup is
/// a whole-file `VACUUM INTO`, so a table rides along automatically and the
/// user's base values survive a restore. Preferences would not.
abstract class LocalUnitsRepository {
  Future<List<LocalUnit>> load();

  Future<void> save(LocalUnit unit);

  Future<void> delete(String id);

  /// Removes every user row. The shipped defaults stay, they live in the
  /// bundled JSON and are never stored.
  Future<void> resetToDefaults();
}

class DriftLocalUnitsRepository implements LocalUnitsRepository {
  DriftLocalUnitsRepository(this._db);

  final AppDatabase _db;

  static const String category = 'local';

  @override
  Future<List<LocalUnit>> load() async {
    final rows = await _db
        .customSelect(
            'SELECT * FROM unit_local_override ORDER BY created_at ASC')
        .get();
    return rows.map(_fromRow).toList();
  }

  LocalUnit _fromRow(QueryRow row) {
    final name = row.read<String>('name');
    final factor = row.read<double>('factor');
    if (factor <= 0) {
      AppLogger.warning('LocalUnits', 'dropped "$name": factor $factor');
      return LocalUnit(
        id: row.read<String>('id'),
        name: name,
        factor: 1,
        baseUnit: row.read<String>('base_unit'),
        isUserEdited: true,
      );
    }
    return LocalUnit(
      id: row.read<String>('id'),
      name: name,
      factor: factor,
      baseUnit: row.read<String>('base_unit'),
      isUserEdited: true,
    );
  }

  @override
  Future<void> save(LocalUnit unit) async {
    await _db.customStatement(
      '''
      INSERT INTO unit_local_override
        (id, name, category, factor, base_unit, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        category = excluded.category,
        factor = excluded.factor,
        base_unit = excluded.base_unit
      ''',
      [
        unit.id,
        unit.name,
        category,
        unit.factor,
        unit.baseUnit,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.customStatement(
        'DELETE FROM unit_local_override WHERE id = ?', [id]);
  }

  @override
  Future<void> resetToDefaults() async {
    await _db.customStatement('DELETE FROM unit_local_override');
  }
}
