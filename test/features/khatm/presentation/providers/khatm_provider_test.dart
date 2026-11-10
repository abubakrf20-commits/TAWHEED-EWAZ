import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/khatm/data/daos/khatm_dao.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/presentation/providers/khatm_provider.dart';
import '../../../../core/database/mock_daos.dart';

void main() {
  late ProviderContainer container;
  late MockKhatmDao mockDao;

  setUp(() {
    mockDao = MockKhatmDao();
    container = ProviderContainer(overrides: [
      khatmDaoProvider.overrideWithValue(mockDao),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  Future<KhatmModel?> readKhatm() async {
    final notifier = container.read(khatmProvider.notifier);
    await notifier.build();
    final state = container.read(khatmProvider);
    return state.asData?.value;
  }

  test('build returns null when DAO has no khatms', () async {
    final khatm = await readKhatm();
    expect(khatm, isNull);
  });

  test('build returns first incomplete khatm', () async {
    final completed = KhatmTableData(
      id: '1',
      title: 'Completed',
      startDate: DateTime(2024),
      targetDays: 30,
      pagesRead: '[]',
      dailyRead: '{}',
      isCompleted: true,
      participantNames: '[]',
      participantAssignedJuzs: '[]',
    );
    final incomplete = KhatmTableData(
      id: '2',
      title: 'Active',
      startDate: DateTime(2024, 6),
      targetDays: 30,
      pagesRead: '[]',
      dailyRead: '{}',
      isCompleted: false,
      participantNames: '[]',
      participantAssignedJuzs: '[]',
    );
    await mockDao.upsertKhatm(completed);
    await mockDao.upsertKhatm(incomplete);
    container = ProviderContainer(overrides: [
      khatmDaoProvider.overrideWithValue(mockDao),
    ]);
    final khatm = await readKhatm();
    expect(khatm, isNotNull);
    expect(khatm!.title, equals('Active'));
    expect(khatm.isCompleted, isFalse);
  });

  test('build returns last khatm when all are completed', () async {
    final first = KhatmTableData(
      id: '1',
      title: 'First',
      startDate: DateTime(2024),
      targetDays: 30,
      pagesRead: '[]',
      dailyRead: '{}',
      isCompleted: true,
      participantNames: '[]',
      participantAssignedJuzs: '[]',
    );
    final last = KhatmTableData(
      id: '2',
      title: 'Last',
      startDate: DateTime(2024, 6),
      targetDays: 30,
      pagesRead: '[]',
      dailyRead: '{}',
      isCompleted: true,
      participantNames: '[]',
      participantAssignedJuzs: '[]',
    );
    await mockDao.upsertKhatm(first);
    await mockDao.upsertKhatm(last);
    container = ProviderContainer(overrides: [
      khatmDaoProvider.overrideWithValue(mockDao),
    ]);
    final khatm = await readKhatm();
    expect(khatm, isNotNull);
    expect(khatm!.title, equals('Last'));
  });

  test('startNew creates a new khatm', () async {
    await readKhatm();
    final notifier = container.read(khatmProvider.notifier);
    await notifier.startNew(title: 'My Khatm', targetDays: 30);
    final khatm = await readKhatm();
    expect(khatm, isNotNull);
    expect(khatm!.title, equals('My Khatm'));
    expect(khatm.targetDays, equals(30));
    expect(khatm.startDate, isNotNull);
  });

  test('startNew creates a khatm with participants', () async {
    await readKhatm();
    final notifier = container.read(khatmProvider.notifier);
    await notifier.startNew(
      title: 'Group Khatm',
      targetDays: 10,
      participantNames: ['Ali', 'Mohammad'],
      participantAssignedJuzs: [1, 2],
    );
    final khatm = await readKhatm();
    expect(khatm!.participantNames, equals(['Ali', 'Mohammad']));
    expect(khatm.participantAssignedJuzs, equals([1, 2]));
  });

  test('markPageRange marks pages as read', () async {
    await readKhatm();
    final notifier = container.read(khatmProvider.notifier);
    await notifier.startNew(title: 'Test', targetDays: 30);
    await notifier.markPageRange(1, 5);
    final khatm = await readKhatm();
    if (khatm == null) {
      fail('khatm should not be null');
    }
    expect(khatm.readPages, equals(5));
    expect(khatm.pagesRead[0], isTrue);
    expect(khatm.pagesRead[4], isTrue);
    expect(khatm.pagesRead[5], isFalse);
  });

  test('markPageRange completes khatm when all pages read', () async {
    await readKhatm();
    final notifier = container.read(khatmProvider.notifier);
    await notifier.startNew(title: 'Test', targetDays: 1);
    await notifier.markPageRange(1, 604);
    final all = await mockDao.getAllKhatms();
    expect(all, isNotEmpty);
    final row = all.last;
    expect(row.isCompleted, isTrue);
    expect(row.endDate, isNotNull);
  });

  test('hasActive returns true when an active khatm exists', () async {
    await readKhatm();
    final notifier = container.read(khatmProvider.notifier);
    await notifier.startNew(title: 'Active', targetDays: 30);
    await readKhatm();
    expect(container.read(khatmProvider.notifier).hasActive, isTrue);
  });

  test('delete removes khatm and sets state to null if current', () async {
    await readKhatm();
    final notifier = container.read(khatmProvider.notifier);
    await notifier.startNew(title: 'To Delete', targetDays: 30);
    await readKhatm();
    final khatm = container.read(khatmProvider).asData?.value;
    if (khatm == null) {
      fail('khatm should not be null');
    }
    final id = khatm.id;
    await notifier.delete(id);
    final deleted = await readKhatm();
    expect(deleted, isNull);
  });

  test('history returns all khatms sorted by startDate descending', () async {
    final earlier = KhatmTableData(
      id: '1',
      title: 'Older',
      startDate: DateTime(2024),
      targetDays: 30,
      pagesRead: '[]',
      dailyRead: '{}',
      isCompleted: true,
      participantNames: '[]',
      participantAssignedJuzs: '[]',
    );
    final later = KhatmTableData(
      id: '2',
      title: 'Newer',
      startDate: DateTime(2024, 6),
      targetDays: 30,
      pagesRead: '[]',
      dailyRead: '{}',
      isCompleted: false,
      participantNames: '[]',
      participantAssignedJuzs: '[]',
    );
    await mockDao.upsertKhatm(earlier);
    await mockDao.upsertKhatm(later);
    container = ProviderContainer(overrides: [
      khatmDaoProvider.overrideWithValue(mockDao),
    ]);
    await readKhatm();
    final notifier = container.read(khatmProvider.notifier);
    final history = await notifier.allKhatms;
    expect(history.length, equals(2));
    expect(history[0].title, equals('Newer'));
  });
}
