import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal_info/domain/repositories/personal_info_repository.dart';
import 'package:tawheeed/features/personal_info/services/insurance_expiry_sync.dart';

class _FakeRepo implements PersonalInfoRepository {
  final Map<String, ExpiryItemTableData> expiryById = {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<ExpiryItemTableData?> getExpiryItem(String id) async => expiryById[id];

  @override
  Future<List<ExpiryItemTableData>> getExpiryItems(
          {bool includeArchived = false}) async =>
      expiryById.values.toList();

  @override
  Future<void> upsertExpiryItem(ExpiryItemTableCompanion entry) async {
    expiryById[entry.id.value] = ExpiryItemTableData(
      id: entry.id.value,
      category: entry.category.value,
      title: entry.title.value,
      startDate: entry.startDate.value,
      dueDate: entry.dueDate.value,
      notes: entry.notes.value,
      remindEnabled: entry.remindEnabled.value,
      remindDaysBefore: entry.remindDaysBefore.value,
      lastRemindedDate: entry.lastRemindedDate.value,
      isArchived: entry.isArchived.value,
      createdAt: entry.createdAt.value,
      updatedAt: entry.updatedAt.value,
    );
  }

  @override
  Future<void> deleteExpiryItem(String id) async {
    expiryById.remove(id);
  }
}

ExpiryItemTableData _item(String id, String title, String dueDate,
    {bool remindEnabled = false}) {
  final now = DateTime.now();
  return ExpiryItemTableData(
    id: id,
    category: 'expiry_warning',
    title: title,
    startDate: '',
    dueDate: dueDate,
    notes: '',
    remindEnabled: remindEnabled,
    remindDaysBefore: 0,
    lastRemindedDate: '',
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('sync creates a linked expiry item for a policy with an end date',
      () async {
    final repo = _FakeRepo();
    await InsuranceExpirySync.sync(
      repo: repo,
      insuranceId: 'ins-1',
      title: 'بیمه تکمیلی درمان',
      expiryDate: '2027-03-01',
    );

    final item = repo.expiryById['insurance_ins-1'];
    expect(item, isNotNull);
    expect(item!.title, 'انقضای بیمه: بیمه تکمیلی درمان');
    expect(item.dueDate, '2027-03-01');
    expect(item.category, 'expiry_warning');
  });

  test('sync updates the linked item without wiping user reminders', () async {
    final repo = _FakeRepo();
    repo.expiryById['insurance_ins-1'] = _item(
      'insurance_ins-1',
      'انقضای بیمه: بیمه تکمیلی درمان',
      '2027-03-01',
      remindEnabled: true,
    );

    await InsuranceExpirySync.sync(
      repo: repo,
      insuranceId: 'ins-1',
      title: 'بیمه تکمیلی درمان',
      expiryDate: '2027-06-15',
    );

    final item = repo.expiryById['insurance_ins-1']!;
    expect(item.dueDate, '2027-06-15');
    expect(item.remindEnabled, isTrue,
        reason: 'the user turned the reminder on; editing the policy must not '
            'silently switch it off');
  });

  test('sync with an empty end date removes the linked item', () async {
    final repo = _FakeRepo();
    repo.expiryById['insurance_ins-1'] =
        _item('insurance_ins-1', 'انقضای بیمه: X', '2027-03-01');

    await InsuranceExpirySync.sync(
      repo: repo,
      insuranceId: 'ins-1',
      title: 'بیمه X',
      expiryDate: '',
    );

    expect(repo.expiryById.containsKey('insurance_ins-1'), isFalse);
  });

  test('remove deletes the linked item and is a no-op when absent', () async {
    final repo = _FakeRepo();
    repo.expiryById['insurance_ins-1'] =
        _item('insurance_ins-1', 'انقضای بیمه: X', '2027-03-01');

    await InsuranceExpirySync.remove(repo, 'ins-1');
    expect(repo.expiryById.containsKey('insurance_ins-1'), isFalse);

    await InsuranceExpirySync.remove(repo, 'ins-2');
    expect(repo.expiryById, isEmpty);
  });
}
