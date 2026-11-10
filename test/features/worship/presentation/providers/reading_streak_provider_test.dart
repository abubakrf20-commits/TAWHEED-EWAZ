import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/worship/presentation/providers/reading_streak_provider.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import '../../../../core/database/mock_daos.dart';

/// Captures the DAO snapshot when the read starts, then holds it until the
/// gate opens — a slow initial load while the user keeps reading.
class _GatedDailyStatusDao extends MockDailyStatusDao {
  final gate = Completer<void>();

  @override
  Future<Map<String, int>> getAllAsMap(String category) async {
    final snapshot = await super.getAllAsMap(category);
    await gate.future;
    return snapshot;
  }
}

void main() {
  test('loads the stored reading days', () async {
    final dao = _GatedDailyStatusDao()..gate.complete();
    final container = ProviderContainer(overrides: [
      dailyStatusDaoProvider.overrideWithValue(dao),
    ]);
    addTearDown(container.dispose);

    await dao.set('reading', dateKeyOf(DateTime.now()), '', 4);
    container.read(readingStreakProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(container.read(readingStreakProvider).todayPages, 4);
  });

  test('a reading logged while the initial load is in flight survives it',
      () async {
    // The load assigns the whole cache, so a log made in that window used to
    // be overwritten by the older snapshot the read had captured.
    final dao = _GatedDailyStatusDao();
    final container = ProviderContainer(overrides: [
      dailyStatusDaoProvider.overrideWithValue(dao),
    ]);
    addTearDown(container.dispose);

    container.read(readingStreakProvider);
    final pending =
        container.read(readingStreakProvider.notifier).logReading(pages: 3);
    dao.gate.complete();
    await pending;
    // Let the gated load land too: the snapshot it captured predates the
    // log, so the bug only shows once its assignment runs.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(container.read(readingStreakProvider).todayPages, 3);
    expect(
      await dao.getValue('reading', dateKeyOf(DateTime.now()), ''),
      3,
    );
  });
}
