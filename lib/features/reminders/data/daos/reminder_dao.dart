import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final reminderDaoProvider = Provider<ReminderDao>((ref) {
  return ReminderDao(ref.read(appDatabaseProvider));
});

class ReminderDao {
  final AppDatabase db;
  ReminderDao(this.db);

  Future<List<ReminderTableData>> getAllReminders() async {
    return db.select(db.reminderTable).get();
  }

  Future<ReminderTableData?> getReminder(String id) async {
    final query = db.select(db.reminderTable)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> upsertReminder(Insertable<ReminderTableData> reminder) async {
    await db.into(db.reminderTable).insertOnConflictUpdate(reminder);
  }

  Future<void> deleteReminder(String id) async {
    await (db.delete(db.reminderTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearAll() async {
    await db.delete(db.reminderTable).go();
  }
}
