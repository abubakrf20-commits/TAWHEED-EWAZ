import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/shared/utils/date_range.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

part 'reading_stats_provider.g.dart';

@Riverpod(keepAlive: true)
Future<Map<String, int>> readingStats(Ref ref) async {
  final dao = ref.read(dailyStatusDaoProvider);
  final now = DateTime.now();
  final end =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final start = now.calendarDaysAgo(29);
  final startStr =
      '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  final records = await dao.getAllInDateRange('reading_stats', startStr, end);
  final map = <String, int>{};
  for (final r in records) {
    map[r.date] = (map[r.date] ?? 0) + r.value;
  }
  return map;
}

@Riverpod(keepAlive: true)
Future<int> readingTotal(Ref ref) async {
  final dao = ref.read(dailyStatusDaoProvider);
  final records = await dao.getAllForCategory('reading_stats');
  return records.fold<int>(0, (sum, r) => sum + r.value);
}

@Riverpod(keepAlive: true)
Future<int> readingStreak(Ref ref) async {
  final dao = ref.read(dailyStatusDaoProvider);
  final now = DateTime.now();
  final records = await dao.getAllForCategory('reading_stats');
  final daily = <String, int>{};
  for (final r in records) {
    daily[r.date] = (daily[r.date] ?? 0) + r.value;
  }
  int streak = 0;
  for (int i = 0; i < 365; i++) {
    final d = DateTime(now.year, now.month, now.day - i);
    final key =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if ((daily[key] ?? 0) > 0) {
      streak++;
    } else if (i > 0) {
      break;
    }
  }
  return streak;
}

/// Total minutes spent in the reader, summed over every day.
///
/// Pages alone could not answer the reader's own question — «چقدر وقت گذاشتم؟»
/// — and a rate needs a denominator. The reader writes one row per session
/// under its own category so nothing has to be migrated.
///
/// A hand-written provider on purpose: adding a second `@Riverpod` function to
/// this file would require a code-generation run, and this repo does not run
/// `build_runner` outside an explicit request.
final readingMinutesTotalProvider = FutureProvider<int>((ref) async {
  final dao = ref.read(dailyStatusDaoProvider);
  final records = await dao.getAllForCategory('reading_minutes');
  return records.fold<int>(0, (sum, r) => sum + r.value);
});

Future<void> trackReadingMinutes(WidgetRef ref, int minutes) async {
  if (minutes <= 0) return;
  try {
    final dao = ref.read(dailyStatusDaoProvider);
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final existing =
        await dao.getValue('reading_minutes', dateKey, 'minutes') ?? 0;
    await dao.set('reading_minutes', dateKey, 'minutes', existing + minutes);
  } catch (e) {
    AppLogger.warning('reading_stats', 'Failed to track minutes: $e');
  }
}

Future<void> trackReadingPage(WidgetRef ref, int pagesRead) async {
  try {
    final dao = ref.read(dailyStatusDaoProvider);
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final existing = await dao.getValue('reading_stats', dateKey, 'pages') ?? 0;
    await dao.set('reading_stats', dateKey, 'pages', existing + pagesRead);
  } catch (e) {
    AppLogger.warning('reading_stats', 'Failed to track: $e');
  }
}
