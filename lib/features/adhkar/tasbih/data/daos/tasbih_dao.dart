import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';

final tasbihDaoProvider = Provider<TasbihDao>((ref) {
  return TasbihDao(ref.read(appDatabaseProvider));
});

class TasbihDao {
  final AppDatabase db;
  TasbihDao(this.db);

  Future<List<TasbihTableData>> getAllTasbihs() async {
    return db.select(db.tasbihTable).get();
  }

  Future<TasbihTableData?> getTasbih(String id) async {
    final query = db.select(db.tasbihTable)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> upsertTasbih(TasbihTableData tasbih) async {
    await db.into(db.tasbihTable).insertOnConflictUpdate(tasbih);
  }

  /// Atomically increments both the current session count and the lifetime
  /// counter in a single SQL UPDATE. Avoids read-modify-write races that
  /// could drop concurrent taps.
  Future<void> incrementLifetimeAndCount(String id) async {
    await db.customUpdate(
      'UPDATE tasbih_table SET count = count + 1, total_lifetime_count = total_lifetime_count + 1 WHERE id = ?',
      variables: [Variable<String>(id)],
      updates: {db.tasbihTable},
    );
  }

  /// Atomically adds [amount] to both the current session count and the
  /// lifetime counter in a single SQL UPDATE (used for bulk manual entry).
  Future<void> addLifetimeAndCount(String id, int amount) async {
    await db.customUpdate(
      'UPDATE tasbih_table SET count = count + ?, total_lifetime_count = total_lifetime_count + ? WHERE id = ?',
      variables: [
        Variable<int>(amount),
        Variable<int>(amount),
        Variable<String>(id)
      ],
      updates: {db.tasbihTable},
    );
  }

  /// Atomically resets the current session count to zero while preserving the
  /// lifetime counter.
  Future<void> resetCount(String id) async {
    await db.customUpdate(
      'UPDATE tasbih_table SET count = 0 WHERE id = ?',
      variables: [Variable<String>(id)],
      updates: {db.tasbihTable},
    );
  }

  /// Resets today's session counts for every tasbih (including custom ones)
  /// while preserving each item and its lifetime counter.
  Future<void> resetAllCounts() async {
    await db.customUpdate(
      'UPDATE tasbih_table SET count = 0',
      updates: {db.tasbihTable},
    );
  }

  Future<void> deleteTasbih(String id) async {
    await (db.delete(db.tasbihTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearAll() async {
    await db.delete(db.tasbihTable).go();
  }

  Future<String?> getSetting(String key) async {
    final query = db.select(db.tasbihSettingsTable)
      ..where((t) => t.key.equals(key));
    final result = await query.getSingleOrNull();
    return result?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await db.into(db.tasbihSettingsTable).insertOnConflictUpdate(
          TasbihSettingsTableData(key: key, value: value),
        );
  }

  // --- Domain-level convenience methods (moved from TasbihRepositoryImpl) ---

  Future<List<TasbihModel>> getAllDomain() async {
    final rows = await getAllTasbihs();
    return rows.map(_toDomain).toList();
  }

  Future<void> saveDomain(TasbihModel model) => upsertTasbih(_toData(model));

  Future<void> updateTarget(String id, int target) async {
    final row = await getTasbih(id);
    if (row == null) return;
    await upsertTasbih(row.copyWith(target: target));
  }

  /// Renames a tasbih's display text (Audit 8.15: previously the only way
  /// to fix a typo was delete + recreate, losing totalLifetimeCount).
  Future<void> rename(String id, String text) async {
    final row = await getTasbih(id);
    if (row == null) return;
    await upsertTasbih(row.copyWith(dhikrText: text));
  }

  /// Normalizes Persian letter forms that had crept into the seeded Arabic
  /// dhikrs (kehepe «ک» → Arabic kāf «ك», Persian yeh «ی» → Arabic yeh «ي»).
  static String _normalizeArabic(String s) =>
      s.replaceAll('ک', 'ك').replaceAll('ی', 'ي');

  Future<void> seedDefaults() async {
    final now = DateTime.now();
    // Every default dhikr counts to 100 — one flat target for all.
    final defaults = [
      ('سبحان الله وبحمده', 100),
      ('سبحان الله', 100),
      ('الحمد لله', 100),
      ('الله أكبر', 100),
      ('اللهم صل وسلم على محمد', 100),
      (
        'لا إله إلا الله وحده لا شريك له له الملك وله الحمد وهو على كل شيء قدير',
        100
      ),
      ('أستغفر الله العظيم وأتوب إليه', 100),
      ('لا حول ولا قوة إلا بالله العلي العظيم', 100),
    ];
    for (int i = 0; i < defaults.length; i++) {
      final (dhikr, count) = (_normalizeArabic(defaults[i].$1), defaults[i].$2);
      await upsertTasbih(TasbihTableData(
        id: 'default_$i',
        dhikrText: dhikr,
        count: 0,
        target: count,
        totalLifetimeCount: 0,
        // Newest timestamp for the first default so the DESC sort shows
        // them in definition order (سبحان الله وبحمده first).
        createdAt: now.subtract(Duration(seconds: i)),
        isDefault: true,
        isEnabled: true,
      ));
    }
  }

  TasbihModel _toDomain(TasbihTableData row) {
    return TasbihModel(
      id: row.id,
      name: row.dhikrText,
      targetDhikr: row.dhikrText,
      targetCount: row.target,
      currentCount: row.count,
      totalLifetimeCount: row.totalLifetimeCount,
      createdAt: row.createdAt,
      isDefault: row.isDefault,
      isEnabled: row.isEnabled,
    );
  }

  TasbihTableData _toData(TasbihModel m) {
    return TasbihTableData(
      id: m.id,
      dhikrText: m.name,
      count: m.currentCount,
      target: m.targetCount,
      totalLifetimeCount: m.totalLifetimeCount,
      createdAt: m.createdAt,
      isDefault: m.isDefault,
      isEnabled: m.isEnabled,
    );
  }
}
