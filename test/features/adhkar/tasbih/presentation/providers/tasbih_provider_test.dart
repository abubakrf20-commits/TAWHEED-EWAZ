import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import '../../../../../core/database/mock_daos.dart';

/// Holds the first [getAllDomain] read — i.e. the whole of `build()` — behind a
/// door the test opens, so a mutation can be fired into the loading window.
class _GatedTasbihDao extends MockTasbihDao {
  Completer<void>? gate;

  @override
  Future<List<TasbihModel>> getAllDomain() async {
    final g = gate;
    if (g != null) await g.future;
    return super.getAllDomain();
  }
}

/// Fails the first [incrementLifetimeAndCount] only, and only after the test
/// releases [hold] — the exact window a second, successful write lands inside.
class _FlakyTasbihDao extends MockTasbihDao {
  final Completer<void> hold = Completer<void>();
  int _incrementCalls = 0;

  @override
  Future<void> incrementLifetimeAndCount(String id) async {
    _incrementCalls++;
    if (_incrementCalls == 1) {
      await hold.future;
      throw StateError('disk write failed');
    }
    await super.incrementLifetimeAndCount(id);
  }
}

/// Refuses every delete, so the notifier's rollback path is the one under test.
class _DeleteFailingTasbihDao extends MockTasbihDao {
  @override
  Future<void> deleteTasbih(String id) async {
    throw StateError('delete failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockTasbihDao mockDao;

  setUp(() {
    // The real mock, not a hand-written channel handler: the store invokes the
    // channel as `set<String|Int|Bool|StringList>` (shared_preferences_platform
    // _interface 2.4.2 `setValue` line 30-35), so a handler that only answers
    // `getAll` made EVERY write throw `Null check operator used on a null
    // value`. The daily reset's stamp and the widget-change marker then failed
    // and were swallowed, i.e. these tests never exercised a prefs write.
    SharedPreferences.setMockInitialValues(const {});
    mockDao = MockTasbihDao();
    container = ProviderContainer(overrides: [
      tasbihDaoProvider.overrideWithValue(mockDao),
      dailyStatusDaoProvider.overrideWithValue(MockDailyStatusDao()),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  test('build returns seeded default tasbihs when DAO is empty', () async {
    final tasbihs = await container.read(tasbihProvider.future);
    expect(tasbihs.length, equals(8));
  });

  test('seeded defaults all count to 100', () async {
    final tasbihs = await container.read(tasbihProvider.future);
    expect(tasbihs.length, equals(8));
    for (final t in tasbihs) {
      expect(t.targetCount, equals(100), reason: t.targetDhikr);
    }
  });

  test('build returns tasbihs from DAO sorted by createdAt descending',
      () async {
    final earlier = DateTime(2024);
    final later = DateTime(2024, 6);
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'Earlier',
      count: 0,
      target: 33,
      totalLifetimeCount: 0,
      createdAt: earlier,
      isDefault: false,
      isEnabled: true,
    ));
    await mockDao.upsertTasbih(TasbihTableData(
      id: '2',
      dhikrText: 'Later',
      count: 5,
      target: 33,
      totalLifetimeCount: 0,
      createdAt: later,
      isDefault: false,
      isEnabled: true,
    ));
    final tasbihs = await container.read(tasbihProvider.future);
    expect(tasbihs.length, equals(2));
    expect(tasbihs[0].id, equals('2'));
    expect(tasbihs[1].id, equals('1'));
  });

  test('increment updates count via DAO', () async {
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'Test',
      count: 0,
      target: 33,
      totalLifetimeCount: 0,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await container.read(tasbihProvider.future);
    final notifier = container.read(tasbihProvider.notifier);
    await notifier.increment('1');
    final updated = await mockDao.getTasbih('1');
    expect(updated!.count, equals(1));
  });

  test('increment does nothing for non-existent id', () async {
    await container.read(tasbihProvider.future);
    final notifier = container.read(tasbihProvider.notifier);
    await notifier.increment('nonexistent');
    final all = await mockDao.getAllTasbihs();
    expect(all.length, equals(8));
  });

  test('reset does nothing for non-existent id', () async {
    await container.read(tasbihProvider.future);
    final notifier = container.read(tasbihProvider.notifier);
    await notifier.reset('nonexistent');
    final all = await mockDao.getAllTasbihs();
    expect(all.length, equals(8));
  });

  test('startNew creates a new tasbih in DAO', () async {
    await container.read(tasbihProvider.future);
    final notifier = container.read(tasbihProvider.notifier);
    await notifier.startNew(text: 'ذکر تازه', target: 33);
    final all = await mockDao.getAllTasbihs();
    expect(all.length, equals(9));
    // The seeds share their dhikr texts, so pin the created row by flag —
    // asserting `.first` used to pass by accident on a seed row.
    final created = all.firstWhere((t) => !t.isDefault);
    expect(created.dhikrText, equals('ذکر تازه'));
    expect(created.target, equals(33));
    expect(created.count, equals(0));
  });

  test('delete removes tasbih from DAO', () async {
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'Test',
      count: 0,
      target: 33,
      totalLifetimeCount: 0,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await container.read(tasbihProvider.future);
    final notifier = container.read(tasbihProvider.notifier);
    await notifier.delete('1');
    final all = await mockDao.getAllTasbihs();
    expect(all, isEmpty);
  });

  test('updateTarget changes target in DAO', () async {
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'Test',
      count: 5,
      target: 33,
      totalLifetimeCount: 0,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await container.read(tasbihProvider.future);
    final notifier = container.read(tasbihProvider.notifier);
    await notifier.updateTarget('1', 100);
    final updated = await mockDao.getTasbih('1');
    expect(updated!.target, equals(100));
  });

  test('clearHistory resets counts but preserves tasbihs and lifetime stats',
      () async {
    await mockDao.upsertTasbih(TasbihTableData(
      id: '1',
      dhikrText: 'A',
      count: 12,
      target: 33,
      totalLifetimeCount: 500,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await mockDao.upsertTasbih(TasbihTableData(
      id: '2',
      dhikrText: 'B',
      count: 7,
      target: 33,
      totalLifetimeCount: 200,
      createdAt: DateTime.now(),
      isDefault: false,
      isEnabled: true,
    ));
    await container.read(tasbihProvider.future);
    final notifier = container.read(tasbihProvider.notifier);
    await notifier.clearHistory();
    final all = await mockDao.getAllTasbihs();
    expect(all.length, equals(2));
    for (final t in all) {
      expect(t.count, equals(0));
      expect(t.totalLifetimeCount, greaterThan(0));
    }
  });

  /// A container over an arbitrary fake DAO. The provider is autoDispose, so
  /// every multi-step case below keeps a subscription open — otherwise the
  /// load would be torn down between the two reads the test is measuring.
  ProviderContainer containerOver(MockTasbihDao dao) {
    final c = ProviderContainer(overrides: [
      tasbihDaoProvider.overrideWithValue(dao),
      dailyStatusDaoProvider.overrideWithValue(MockDailyStatusDao()),
    ]);
    addTearDown(c.dispose);
    c.listen(tasbihProvider, (_, __) {});
    return c;
  }

  group('the _ready gate and the inverse-delta rollback', () {
    /// One row at [count], so a case can state exactly what the dial reads.
    TasbihTableData row(String id, String dhikr,
        {int count = 0,
        int target = 33,
        int lifetime = 0,
        DateTime? createdAt}) {
      return TasbihTableData(
        id: id,
        dhikrText: dhikr,
        count: count,
        target: target,
        totalLifetimeCount: lifetime,
        createdAt: createdAt ?? DateTime.now(),
        isDefault: false,
        isEnabled: true,
      );
    }

    test('a tap landed while build() is in flight is neither lost nor silent',
        () async {
      final dao = _GatedTasbihDao()..gate = Completer<void>();
      await dao.upsertTasbih(row('1', 'Test'));
      final c = containerOver(dao);
      expect(c.read(tasbihProvider).isLoading, isTrue,
          reason: 'the load must still be behind the gate');

      final increment = c.read(tasbihProvider.notifier).increment('1');
      expect(c.read(tasbihProvider).value, isNull);

      dao.gate!.complete();
      await increment;

      // Before the gate existed this tap hit `state.value == null` and simply
      // returned: the dial moved for one frame and nothing was written.
      expect(c.read(tasbihProvider).value!.single.currentCount, 1);
      final persisted = await dao.getTasbih('1');
      expect(persisted!.count, 1);
      expect(persisted.totalLifetimeCount, 1);
    });

    test('a failed write undoes only its own delta, never a newer one',
        () async {
      final dao = _FlakyTasbihDao();
      await dao.upsertTasbih(row('1', 'Test'));
      final c = containerOver(dao);
      await c.read(tasbihProvider.future);
      final notifier = c.read(tasbihProvider.notifier);

      // The first tap is optimistic: on screen while its write is in flight.
      final slow = notifier.increment('1');
      // `increment` opens with `await _awaitReady()`, and awaiting an already
      // completed future still defers one turn — the patch is next-turn, not
      // synchronous.
      await Future<void>(() {});
      expect(c.read(tasbihProvider).value!.single.currentCount, 1);

      // A second, successful write lands inside that window.
      await notifier.addCount('1', 5);
      expect(c.read(tasbihProvider).value!.single.currentCount, 6);
      expect((await dao.getTasbih('1'))!.count, 5);

      dao.hold.complete();
      await slow;

      // Restoring the pre-patch snapshot here would print 0 and erase the five
      // real taps that arrived while the failed one was in flight.
      final live = c.read(tasbihProvider).value!.single;
      expect(live.currentCount, 5,
          reason: 'only the failed +1 is rolled back');
      expect(live.totalLifetimeCount, 5);
      expect((await dao.getTasbih('1'))!.count, 5);
    });

    test('a failed delete puts the dhikr back at its own place in the pager',
        () async {
      final dao = _DeleteFailingTasbihDao();
      await dao.upsertTasbih(row('A', 'A', createdAt: DateTime(2024, 6)));
      await dao.upsertTasbih(row('B', 'B', createdAt: DateTime(2024, 3)));
      await dao.upsertTasbih(row('C', 'C', createdAt: DateTime(2024)));
      final c = containerOver(dao);
      await c.read(tasbihProvider.future);
      List<String> ids() =>
          c.read(tasbihProvider).value!.map((t) => t.id).toList();
      expect(ids(), ['A', 'B', 'C'],
          reason: 'the list is sorted by createdAt descending');

      await c.read(tasbihProvider.notifier).delete('B');

      // Re-appending the removed row would move B to the end of the pager —
      // a different dhikr than the one the reader was on.
      expect(ids(), ['A', 'B', 'C']);
      expect((await dao.getAllTasbihs()).length, 3);
    });
  });
}
