import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/domain/repositories/azkar_repository.dart'
    as repo;
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_provider.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart';
import 'package:tawheeed/features/adhkar/data/repositories/azkar_repository_impl.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import '../../../../core/database/mock_daos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late MockAzkarRepository mockAzkarRepo;
  late MockTasbihDao mockTasbihDao;

  final sampleItems = [
    const ZikrItem(
      id: 'zikr_1',
      title: 'تسبیح',
      arabicText: 'سُبْحَانَ اللَّهِ',
      translation: 'Glory be to Allah',
      source: 'quran',
      period: PrayerPeriod.morningAzkar,
      count: 0,
      repeatCount: 33,
    ),
    const ZikrItem(
      id: 'zikr_2',
      title: 'حمد',
      arabicText: 'الْحَمْدُ لِلَّهِ',
      translation: 'Praise be to Allah',
      source: 'quran',
      period: PrayerPeriod.morningAzkar,
      count: 0,
      repeatCount: 33,
    ),
    const ZikrItem(
      id: 'zikr_3',
      title: 'تکبیر',
      arabicText: 'اللَّهُ أَكْبَرُ',
      translation: 'Allah is the Greatest',
      source: 'quran',
      period: PrayerPeriod.eveningAzkar,
      count: 0,
      repeatCount: 34,
    ),
  ];

  setUp(() {
    mockAzkarRepo = MockAzkarRepository();
    mockAzkarRepo.setItems(sampleItems);
    mockTasbihDao = MockTasbihDao();
    AzkarData.setTestData(sampleItems);
    container = ProviderContainer(overrides: [
      azkarRepositoryProvider.overrideWith((ref) async => mockAzkarRepo),
      tasbihDaoProvider.overrideWithValue(mockTasbihDao),
    ]);
    // build() now awaits SharedPreferences (real event-loop gap), which lets an
    // unlistened autoDispose element recycle between read() calls. In the app
    // widgets always hold a listener — mirror that here.
    container.listen(azkarProvider, (_, __) {});
  });

  tearDown(() {
    container.dispose();
    Azkar.nowOverride = DateTime.now;
    AzkarData.setTestData([]);
  });

  test('build returns all azkar items', () async {
    await container.read(azkarProvider.future);
    final items = container.read(azkarProvider).value;
    expect(items, isNotNull);
    expect(items!.length, equals(3));
    expect(items[0].id, equals('zikr_1'));
  });

  test('isCompleted returns false by default', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);
    expect(notifier.isCompleted('zikr_1'), isFalse);
  });

  test('markCompleted sets item as completed', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);
    await notifier.markCompleted('zikr_1');
    expect(notifier.isCompleted('zikr_1'), isTrue);
  });

  test('markCompleted calls setStatus on repository', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);
    await notifier.markCompleted('zikr_1');
    expect(mockAzkarRepo.getStatus('zikr_1'), equals(repo.ZikrStatus.done));
  });

  test('markCompletedBatch marks all ids done in one write', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);
    await notifier.markCompletedBatch(['zikr_1', 'zikr_2', 'zikr_3']);
    expect(notifier.isCompleted('zikr_1'), isTrue);
    expect(notifier.isCompleted('zikr_2'), isTrue);
    expect(notifier.isCompleted('zikr_3'), isTrue);
    expect(mockAzkarRepo.getStatus('zikr_1'), equals(repo.ZikrStatus.done));
    expect(mockAzkarRepo.getStatus('zikr_3'), equals(repo.ZikrStatus.done));
    final stats = notifier.periodStats(PrayerPeriod.morningAzkar);
    expect(stats['done'], equals(2));
  });

  test('completeCount sets the exact target and completion status', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);

    await notifier.completeCount('zikr_1', 33);

    expect(notifier.getCount('zikr_1', 33), equals(33));
    expect(notifier.isCompleted('zikr_1'), isTrue);
    expect(mockAzkarRepo.getStatus('zikr_1'), equals(repo.ZikrStatus.done));
  });

  test('partial counts survive a provider rebuild via the prefs mirror',
      () async {
    SharedPreferences.setMockInitialValues({});
    container.dispose();

    container = ProviderContainer(overrides: [
      azkarRepositoryProvider.overrideWith((ref) async => mockAzkarRepo),
      tasbihDaoProvider.overrideWithValue(mockTasbihDao),
    ]);
    container.listen(azkarProvider, (_, __) {});
    await container.read(azkarProvider.future);
    final first = container.read(azkarProvider.notifier);
    await first.incrementCount('zikr_1', 3);
    await first.incrementCount('zikr_1', 3);
    expect(first.getCount('zikr_1', 3), equals(2));
    container.dispose();

    // Fresh container = fresh notifier; the in-memory map is gone, but the
    // SharedPreferences mirror must restore 2/3.
    container = ProviderContainer(overrides: [
      azkarRepositoryProvider.overrideWith((ref) async => mockAzkarRepo),
      tasbihDaoProvider.overrideWithValue(mockTasbihDao),
    ]);
    container.listen(azkarProvider, (_, __) {});
    await container.read(azkarProvider.future);
    expect(container.read(azkarProvider.notifier).getCount('zikr_1', 3),
        equals(2));
  });

  test('resetProgress removes completion status', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);
    await notifier.markCompleted('zikr_1');
    expect(notifier.isCompleted('zikr_1'), isTrue);
    await notifier.resetProgress('zikr_1');
    expect(notifier.isCompleted('zikr_1'), isFalse);
  });

  test('periodStats returns correct counts for a period', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);
    final stats = notifier.periodStats(PrayerPeriod.morningAzkar);
    expect(stats['total'], equals(2));
    expect(stats['done'], equals(0));
  });

  test('periodStats reflects completed items', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);
    await notifier.markCompleted('zikr_1');
    final stats = notifier.periodStats(PrayerPeriod.morningAzkar);
    expect(stats['done'], equals(1));
    expect(stats['total'], equals(2));
  });

  test('periodStats for evening period returns correct counts', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);
    final stats = notifier.periodStats(PrayerPeriod.eveningAzkar);
    expect(stats['total'], equals(1));
    expect(stats['done'], equals(0));
  });

  test('a pre-load 0/0 stat is not memoized forever', () async {
    // Cold start: nothing parsed yet, the repository resolves after a gap.
    // The home summary asks for stats on its very first frame, before the
    // provider's future completes; that reading used to be cached as 0/0 and
    // the ring stayed empty for the whole session.
    AzkarData.resetTestData();
    container.dispose();
    container = ProviderContainer(overrides: [
      azkarRepositoryProvider.overrideWith((ref) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return mockAzkarRepo;
      }),
      tasbihDaoProvider.overrideWithValue(mockTasbihDao),
    ]);
    container.listen(azkarProvider, (_, __) {});

    final notifier = container.read(azkarProvider.notifier);
    final early = notifier.periodStats(PrayerPeriod.morningAzkar);
    expect(early['total'], equals(0));

    await container.read(azkarProvider.future);
    expect(AzkarData.allAzkar, isNotEmpty);
    final late = notifier.periodStats(PrayerPeriod.morningAzkar);
    expect(late['total'],
        equals(AzkarData.getByPeriod(PrayerPeriod.morningAzkar).length));
    expect(late['total'], greaterThan(0));
  });

  test('completions reload when the calendar day changes', () async {
    await container.read(azkarProvider.future);
    final notifier = container.read(azkarProvider.notifier);
    await notifier.markCompleted('zikr_1');
    expect(notifier.isCompleted('zikr_1'), isTrue);
    expect(notifier.periodStats(PrayerPeriod.morningAzkar)['done'], equals(1));

    Azkar.nowOverride = () => DateTime.now().add(const Duration(days: 1));
    await mockAzkarRepo.setMockStatus('zikr_1', repo.ZikrStatus.pending);
    await mockAzkarRepo.setMockStatus('zikr_2', repo.ZikrStatus.done);

    expect(notifier.isCompleted('zikr_1'), isFalse);
    expect(notifier.isCompleted('zikr_2'), isTrue);
    expect(notifier.periodStats(PrayerPeriod.morningAzkar)['done'], equals(1));
  });

  group('GeneralAzkar', () {
    test('build returns empty list by default', () async {
      final state = await container.read(generalAzkarProvider.future);
      expect(state.length, equals(0));
    });

    test('addZikr appends a new general zikr', () async {
      final notifier = container.read(generalAzkarProvider.notifier);
      final before = (await container.read(generalAzkarProvider.future)).length;
      await notifier.addZikr('سُبْحَانَ اللَّهِ');
      final state = await container.read(generalAzkarProvider.future);
      expect(state.length, equals(before + 1));
      expect(state.last.arabicText, equals('سُبْحَانَ اللَّهِ'));
    });

    test('increment increases currentCount', () async {
      final notifier = container.read(generalAzkarProvider.notifier);
      await notifier.addZikr('اللَّهُ أَكْبَرُ');
      final id = (await container.read(generalAzkarProvider.future)).first.id;
      await notifier.increment(id);
      expect(
          (await container.read(generalAzkarProvider.future))
              .first
              .currentCount,
          equals(1));
    });

    test('reset sets currentCount to zero', () async {
      final notifier = container.read(generalAzkarProvider.notifier);
      await notifier.addZikr('الْحَمْدُ لِلَّهِ');
      final id = (await container.read(generalAzkarProvider.future)).first.id;
      await notifier.increment(id);
      await notifier.increment(id);
      expect(
          (await container.read(generalAzkarProvider.future))
              .first
              .currentCount,
          equals(2));
      await notifier.reset(id);
      expect(
          (await container.read(generalAzkarProvider.future))
              .first
              .currentCount,
          equals(0));
    });

    test('resetAll resets all counts', () async {
      final notifier = container.read(generalAzkarProvider.notifier);
      await notifier.addZikr('zikr_a');
      await notifier.addZikr('zikr_b');
      final ids = (await container.read(generalAzkarProvider.future))
          .map((z) => z.id)
          .toList();
      await notifier.increment(ids[0]);
      await notifier.increment(ids[0]);
      await notifier.increment(ids[1]);
      await notifier.resetAll();
      for (final z in await container.read(generalAzkarProvider.future)) {
        expect(z.currentCount, equals(0));
      }
    });

    test('removeZikr removes a zikr by id', () async {
      final notifier = container.read(generalAzkarProvider.notifier);
      await notifier.addZikr('zikr_to_remove');
      final before = (await container.read(generalAzkarProvider.future)).length;
      final id = (await container.read(generalAzkarProvider.future)).last.id;
      await notifier.removeZikr(id);
      final after = await container.read(generalAzkarProvider.future);
      expect(after.length, equals(before - 1));
      expect(after.any((z) => z.id == id), isFalse);
    });

    test('toggleEnabled toggles isEnabled', () async {
      final notifier = container.read(generalAzkarProvider.notifier);
      await notifier.addZikr('zikr');
      final id = (await container.read(generalAzkarProvider.future)).first.id;
      expect(
          (await container.read(generalAzkarProvider.future)).first.isEnabled,
          isTrue);
      await notifier.toggleEnabled(id);
      expect(
          (await container.read(generalAzkarProvider.future)).first.isEnabled,
          isFalse);
    });

    test('updateTarget changes targetCount', () async {
      final notifier = container.read(generalAzkarProvider.notifier);
      await notifier.addZikr('zikr');
      final id = (await container.read(generalAzkarProvider.future)).first.id;
      await notifier.updateTarget(id, 500);
      expect(
          (await container.read(generalAzkarProvider.future)).first.targetCount,
          equals(500));
    });
  });
}
