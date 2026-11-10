import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/data/care_repository.dart';
import 'package:tawheeed/features/personal/data/care_tables.dart';

CareAsset asset({String id = 'a1', CareAssetKind kind = CareAssetKind.car}) =>
    CareAsset(
      id: id,
      kind: kind,
      name: 'پژو ۲۰۶',
      meta: const {'make': 'پژو', 'model': '206', 'color': 'سفید', 'plate': '۱۲ ب ۳۴۵'},
      createdAt: DateTime(2025, 4),
    );

CareTask task({String id = 't1'}) => CareTask(
      id: id,
      assetId: 'a1',
      title: 'روغن موتور',
      templateKey: 'engine_oil',
      categoryKey: 'general',
      iconKey: 'oil',
      scheduleType: CareScheduleType.both,
      intervalDays: 180,
      intervalKm: 5000,
      lastDoneDate: DateTime(2025, 4),
      lastDoneKm: 20000,
      notes: 'با فیلتر',
      createdAt: DateTime(2025, 4),
    );

void main() {
  late AppDatabase db;
  late DriftCareRepository repo;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    repo = DriftCareRepository(db);
  });

  tearDown(() => db.close());

  test('a fresh database has every care table', () async {
    final rows = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'care_%'")
        .get();
    // Pinned against the one list the backup/restore round trip also uses, so a
    // new care table can never be created without being backed up.
    expect(
      rows.map((r) => r.read<String>('name')).toSet(),
      CareTables.tableNames.where((t) => t.startsWith('care_')).toSet(),
    );
  });

  test('an empty database loads an empty snapshot', () async {
    final snapshot = await repo.load();
    expect(snapshot.assets, isEmpty);
    expect(snapshot.tasks, isEmpty);
    expect(snapshot.records, isEmpty);
  });

  test('an asset round-trips with its meta json', () async {
    await repo.saveAsset(asset());
    final loaded = (await repo.load()).assets.single;
    expect(loaded.kind, CareAssetKind.car);
    expect(loaded.metaText('make'), 'پژو');
    expect(loaded.plate, '۱۲ ب ۳۴۵');
    expect(loaded.createdAt, DateTime(2025, 4));
    expect(loaded.displayName, 'پژو 206 · سفید');
  });

  test('a task round-trips every schedule field', () async {
    await repo.saveAsset(asset());
    await repo.saveTask(task());
    final loaded = (await repo.load()).tasks.single;
    expect(loaded.scheduleType, CareScheduleType.both);
    expect(loaded.intervalDays, 180);
    expect(loaded.intervalKm, 5000);
    expect(loaded.lastDoneDate, DateTime(2025, 4));
    expect(loaded.lastDoneKm, 20000);
    expect(loaded.notes, 'با فیلتر');
    expect(loaded.active, isTrue);
  });

  test('a seasonal window survives storage', () async {
    await repo.saveAsset(asset(kind: CareAssetKind.home));
    await repo.saveTask(CareTask(
      id: 's1',
      assetId: 'a1',
      title: 'دودکش',
      categoryKey: 'seasonal',
      iconKey: 'chimney',
      scheduleType: CareScheduleType.time,
      intervalDays: 365,
      window: const CareWindow(
          startMonth: 8, startDay: 1, endMonth: 9, endDay: 30),
      createdAt: DateTime(2025, 4),
    ));
    final loaded = (await repo.load()).tasks.single;
    expect(loaded.window?.startMonth, 8);
    expect(loaded.window?.endDay, 30);
    expect(loaded.isSeasonal, isTrue);
  });

  test('completion writes the record and the task together', () async {
    await repo.saveAsset(asset());
    await repo.saveTask(task());
    final done = task().copyWith(lastDoneDate: DateTime(2025, 6), lastDoneKm: 25000);

    await repo.applyCompletion(
      records: [
        CareRecord(
          id: 'r1',
          assetId: 'a1',
          taskId: 't1',
          title: 'روغن موتور',
          date: DateTime(2025, 6),
          odometerKm: 25000,
          cost: 850000,
          note: 'تعویض شد',
          attachmentPaths: const ['app_data/attachments/care/car/a1/r1.jpg'],
        ),
      ],
      tasks: [done],
    );

    final snapshot = await repo.load();
    expect(snapshot.tasks.single.lastDoneDate, DateTime(2025, 6));
    expect(snapshot.tasks.single.lastDoneKm, 25000);
    final record = snapshot.records.single;
    expect(record.title, 'روغن موتور');
    expect(record.cost, 850000);
    expect(record.attachmentPaths.single, endsWith('r1.jpg'));
  });

  test('undo removes the records and restores the task snapshot', () async {
    await repo.saveAsset(asset());
    await repo.saveTask(task());
    await repo.applyCompletion(
      records: [
        CareRecord(
            id: 'r1',
            assetId: 'a1',
            taskId: 't1',
            date: DateTime(2025, 6),
            odometerKm: 25000),
      ],
      tasks: [task().copyWith(lastDoneDate: DateTime(2025, 6), lastDoneKm: 25000)],
    );

    await repo.undoCompletion(recordIds: ['r1'], tasks: [task()]);

    final snapshot = await repo.load();
    expect(snapshot.records, isEmpty);
    expect(snapshot.tasks.single.lastDoneDate, DateTime(2025, 4));
    expect(snapshot.tasks.single.lastDoneKm, 20000);
  });

  test('odometer and fuel logs load in date order', () async {
    await repo.saveAsset(asset());
    await repo.addReading(OdometerReading(
        id: 'o2', assetId: 'a1', date: DateTime(2025, 5), km: 21000));
    await repo.addReading(OdometerReading(
        id: 'o1', assetId: 'a1', date: DateTime(2025, 4), km: 20000));
    await repo.addFuel(FuelLog(
      id: 'f1',
      assetId: 'a1',
      date: DateTime(2025, 5),
      liters: 40,
      odometerKm: 21000,
      totalCost: 120000,
      fullTank: false,
    ));

    final snapshot = await repo.load();
    expect(snapshot.readings.map((r) => r.id), ['o1', 'o2']);
    expect(snapshot.currentKm('a1'), 21000);
    expect(snapshot.fuelLogs.single.fullTank, isFalse);
    expect(snapshot.fuelLogs.single.cost, 120000);
  });

  test('bills, payments, warranties and subscriptions round-trip', () async {
    await repo.saveAsset(asset(kind: CareAssetKind.home));
    await repo.saveBill(Bill(
      id: 'b1',
      assetId: 'a1',
      type: 'electricity',
      title: 'برق',
      recurrence: BillRecurrence.bimonthly,
      dueDay: 10,
      firstDueDate: DateTime(2025, 4, 10),
      expectedAmount: 250000,
      createdAt: DateTime(2025, 4),
    ));
    await repo.savePayment(BillPayment(
      id: 'p1',
      billId: 'b1',
      periodKey: '2025-04/b',
      paidDate: DateTime(2025, 4, 9),
      amount: 240000,
      note: 'آنلاین',
    ));
    await repo.saveWarranty(Warranty(
      id: 'w1',
      assetId: 'a1',
      itemName: 'یخچال',
      purchaseDate: DateTime(2025, 4),
      months: 24,
      expiryDate: DateTime(2027, 4),
      store: 'فروشگاه',
      serial: 'SN-1',
      receiptPaths: const ['app_data/attachments/care/home/a1/r.jpg'],
    ));
    await repo.saveSubscription(Subscription(
      id: 's1',
      name: 'اینترنت',
      amount: 300000,
      period: SubscriptionPeriod.monthly,
      nextChargeDate: DateTime(2025, 5),
      category: 'internet',
    ));

    final snapshot = await repo.load();
    final bill = snapshot.bills.single;
    expect(bill.recurrence, BillRecurrence.bimonthly);
    expect(bill.expectedAmount, 250000);
    expect(snapshot.payments.single.periodKey, '2025-04/b');
    expect(snapshot.warranties.single.serial, 'SN-1');
    expect(snapshot.warranties.single.receiptPaths, hasLength(1));
    expect(snapshot.subscriptions.single.name, 'اینترنت');
  });

  test('deleting an asset removes its dependent rows', () async {
    await repo.saveAsset(asset());
    await repo.saveTask(task());
    await repo.addReading(OdometerReading(
        id: 'o1', assetId: 'a1', date: DateTime(2025, 4), km: 20000));
    await repo.saveRecord(CareRecord(
        id: 'r1', assetId: 'a1', date: DateTime(2025, 4)));
    await repo.saveWarranty(Warranty(
      id: 'w1',
      assetId: 'a1',
      itemName: 'لاستیک',
      purchaseDate: DateTime(2025, 4),
      months: 12,
      expiryDate: DateTime(2026, 4),
    ));

    await repo.deleteAsset('a1');

    final snapshot = await repo.load();
    expect(snapshot.assets, isEmpty);
    expect(snapshot.tasks, isEmpty);
    expect(snapshot.readings, isEmpty);
    expect(snapshot.records, isEmpty);
    expect(snapshot.warranties, isEmpty);
  });

  test('deleting a bill removes its payments', () async {
    await repo.saveAsset(asset(kind: CareAssetKind.home));
    await repo.saveBill(Bill(
      id: 'b1',
      assetId: 'a1',
      type: 'water',
      title: 'آب',
      recurrence: BillRecurrence.monthly,
      dueDay: 5,
      createdAt: DateTime(2025, 4),
    ));
    await repo.savePayment(BillPayment(
        id: 'p1', billId: 'b1', periodKey: '2025-04', paidDate: DateTime(2025, 4, 4)));

    await repo.deleteBill('b1');

    final snapshot = await repo.load();
    expect(snapshot.bills, isEmpty);
    expect(snapshot.payments, isEmpty);
  });

  test('dates are stored as yyyy-MM-dd calendar days', () async {
    final row = await db
        .customSelect('SELECT ? AS d', variables: [
          Variable.withString(careDateToStore(DateTime(2025, 4, 5)))
        ])
        .getSingle();
    expect(row.read<String>('d'), '2025-04-05');
    expect(careDateFromStore('2025-04-05'), DateTime(2025, 4, 5));
    expect(careDateFromStore(null), isNull);
    expect(careDateFromStore('garbage'), isNull);
  });
}
