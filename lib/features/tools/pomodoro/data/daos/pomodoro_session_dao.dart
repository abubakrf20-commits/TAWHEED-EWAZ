import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final pomodoroSessionDaoProvider = Provider<PomodoroSessionDao>((ref) {
  return PomodoroSessionDao(ref.read(appDatabaseProvider));
});

class PomodoroSessionDao {
  final AppDatabase db;
  PomodoroSessionDao(this.db);

  Future<void> insert({
    required DateTime startedAt,
    required int durationMinutes,
    required String mode,
    required String focusType,
  }) {
    return db
        .into(db.pomodoroSessionTable)
        .insert(PomodoroSessionTableCompanion.insert(
          startedAt: startedAt,
          durationMinutes: durationMinutes,
          mode: mode,
          focusType: focusType,
        ));
  }

  Future<List<PomodoroSessionTableData>> recentSessions({int limit = 10}) {
    final q = db.select(db.pomodoroSessionTable)
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
      ..limit(limit);
    return q.get();
  }

  /// مجموع دقایق تمرکز از آغازِ «امروز» (به وقت محلی).
  Future<int> todayMinutes() async {
    final startOfDay = DateTime.now();
    final dayStart =
        DateTime(startOfDay.year, startOfDay.month, startOfDay.day);
    final sum = db.pomodoroSessionTable.durationMinutes.sum();
    final q = db.selectOnly(db.pomodoroSessionTable)
      ..addColumns([sum])
      ..where(db.pomodoroSessionTable.startedAt.isBiggerOrEqualValue(dayStart));
    final row = await q.getSingle();
    return row.read(sum) ?? 0;
  }

  /// مجموع دقایق هفت روز گذشته (از 6 روز قبل تا امروز، اندیس 6 = امروز).
  Future<List<int>> last7DaysTotals() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final totals = List<int>.filled(7, 0);
    final rows = await (db.select(db.pomodoroSessionTable)
          ..where((t) => t.startedAt
              .isBiggerOrEqualValue(today.subtract(const Duration(days: 6)))))
        .get();
    for (final r in rows) {
      final d = DateTime(r.startedAt.year, r.startedAt.month, r.startedAt.day);
      final idx = d.difference(today).inDays;
      if (idx >= -6 && idx <= 0) totals[idx + 6] += r.durationMinutes;
    }
    return totals;
  }

  Future<void> clearAll() => db.delete(db.pomodoroSessionTable).go();
}
