import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final settingsDaoProvider = Provider<SettingsDao>((ref) {
  return SettingsDao(ref.read(appDatabaseProvider));
});

class SettingsDao {
  final AppDatabase db;
  SettingsDao(this.db);

  Future<AppSettingsTableData?> getSettings(String id) async {
    final query = db.select(db.appSettingsTable)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> upsertSettings(AppSettingsTableData settings) async {
    // insertOnConflictUpdate builds its DO UPDATE from toCompanion(true),
    // which turns NULL fields into Value.absent() — so nullable columns
    // (e.g. custom_azan_path) could never be cleared back to NULL. Write
    // explicitly with nullToAbsent=false, falling back to a fresh insert.
    final updated = await (db.update(db.appSettingsTable)
          ..where((t) => t.id.equals(settings.id)))
        .write(settings.toCompanion(false));
    if (updated == 0) {
      await db.into(db.appSettingsTable).insert(settings);
    }
  }
}
