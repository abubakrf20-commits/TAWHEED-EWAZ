import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_provider.dart';

/// Returns a [ProviderSubscription] that keeps auto-dispose providers alive.
ProviderSubscription _keepAlive(ProviderContainer c) =>
    c.listen(tasbihProvider, (_, __) {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Tasbih integration', () {
    test('DAO + Provider: seed, increment, persist across rebuild', () async {
      final dao = container.read(tasbihDaoProvider);
      final sub = _keepAlive(container);
      addTearDown(sub.close);

      await dao.seedDefaults();
      expect(await dao.getAllDomain(), hasLength(8));

      final tasbihs = await container.read(tasbihProvider.future);
      expect(tasbihs, hasLength(8));

      final notifier = container.read(tasbihProvider.notifier);
      await notifier.increment(tasbihs.first.id);

      final fromDao = await dao.getTasbih(tasbihs.first.id);
      expect(fromDao!.count, 1);
      expect(fromDao.totalLifetimeCount, 1);

      await notifier.startNew(text: 'استغفر الله', target: 100);
      final reloaded = await container.read(tasbihProvider.future);
      expect(reloaded, hasLength(9));
    });

    test('DAO + Provider: atomic increment survives concurrent calls',
        () async {
      final dao = container.read(tasbihDaoProvider);
      final sub = _keepAlive(container);
      addTearDown(sub.close);

      await dao.seedDefaults();
      await container.read(tasbihProvider.future);

      final notifier = container.read(tasbihProvider.notifier);
      final first = (await dao.getAllTasbihs()).first.id;

      await Future.wait([
        notifier.increment(first),
        notifier.increment(first),
        notifier.increment(first),
      ]);

      final updated = await dao.getTasbih(first);
      expect(updated!.count, 3);
      expect(updated.totalLifetimeCount, 3);
    });
  });

  group('DailyStatus integration', () {
    test('write and read worship status via real DAO', () async {
      final dao = container.read(dailyStatusDaoProvider);
      const today = '2026-07-28';
      const category = 'prayer';

      await dao.set(category, today, 'fajr', 1);
      await dao.set(category, today, 'dhuhr', 1);
      await dao.set(category, today, 'asr', 0);

      expect(await dao.getValue(category, today, 'fajr'), 1);
      expect(await dao.getValue(category, today, 'asr'), 0);

      final grouped = await dao.getAllGroupedByDate(category);
      expect(grouped[today]!.length, 3);
      expect(grouped[today]!['fajr'], 1);

      expect(await dao.sumForDateRange(category, today, today), 2);
    });
  });

  group('GeneralAzkar integration', () {
    test('persists azkar across provider rebuild', () async {
      final sub = _keepAlive(container);
      addTearDown(sub.close);

      var state = await container.read(generalAzkarProvider.future);
      expect(state, isEmpty);

      final notifier = container.read(generalAzkarProvider.notifier);
      await notifier.addZikr('سبحان الله', targetCount: 33);

      state = await container.read(generalAzkarProvider.future);
      expect(state, hasLength(1));
      expect(state.first.arabicText, 'سبحان الله');
      expect(state.first.targetCount, 33);

      await notifier.increment(state.first.id);
      state = await container.read(generalAzkarProvider.future);
      expect(state.first.currentCount, 1);

      final dao = container.read(tasbihDaoProvider);
      final fromDb = await dao.getAllDomain();
      expect(fromDb, hasLength(1));
      expect(fromDb.first.name, 'سبحان الله');
      expect(fromDb.first.currentCount, 1);
    });
  });
}
