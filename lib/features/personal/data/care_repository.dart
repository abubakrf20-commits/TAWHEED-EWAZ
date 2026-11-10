import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Storage contract for the personal-tools care engine. Kept abstract so the
/// UI tests can run against an in-memory fake and so a later platform (iOS)
/// can supply its own store without touching the engine.
abstract class CareRepository {
  Future<CareSnapshot> load();

  Future<void> saveAsset(CareAsset asset);
  Future<void> deleteAsset(String id);

  Future<void> saveTask(CareTask task);
  Future<void> deleteTask(String id);

  Future<void> addReading(OdometerReading reading);
  Future<void> addFuel(FuelLog log);

  /// Completion writes records and the tasks' new `lastDone*` atomically.
  Future<void> applyCompletion({
    required List<CareRecord> records,
    required List<CareTask> tasks,
  });

  /// Undo of [applyCompletion]: removes the records and restores the task
  /// snapshots taken before the completion.
  Future<void> undoCompletion({
    required List<String> recordIds,
    required List<CareTask> tasks,
  });

  Future<void> deleteRecord(String id);

  /// Edits an existing record (date / km / cost / note / attachments).
  Future<void> saveRecord(CareRecord record);

  Future<void> saveBill(Bill bill);
  Future<void> deleteBill(String id);
  Future<void> savePayment(BillPayment payment);
  Future<void> deletePayment(String id);

  Future<void> saveWarranty(Warranty warranty);
  Future<void> deleteWarranty(String id);

  Future<void> saveSubscription(Subscription subscription);
  Future<void> deleteSubscription(String id);

  // ── habits ────────────────────────────────────────────────────
  Future<void> saveHabit(CareHabit habit);
  Future<void> deleteHabit(String id);
  Future<void> saveHabitCompletion(CareHabitCompletion completion);
  Future<void> deleteHabitCompletion(String id);
  Future<void> saveReward(CareReward reward);
  Future<void> deleteReward(String id);
  Future<void> redeemReward(String id);
}

String careDateToStore(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime? careDateFromStore(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _jsonList(List<String> values) => jsonEncode(values);

List<String> _readJsonList(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<String>().toList();
  } catch (e) {
    AppLogger.warning('CareRepository', 'bad attachment list: $e');
    return const [];
  }
}

Map<String, dynamic> _readMeta(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (e) {
    AppLogger.warning('CareRepository', 'bad meta json: $e');
  }
  return const {};
}

/// Drift-backed implementation over the raw-SQL tables in `care_tables.dart`.
class DriftCareRepository implements CareRepository {
  DriftCareRepository(this._db);

  final AppDatabase _db;

  @override
  Future<CareSnapshot> load() async {
    final assets = await _db
        .customSelect('SELECT * FROM care_asset ORDER BY created_at ASC')
        .get();
    final tasks = await _db
        .customSelect('SELECT * FROM care_task ORDER BY created_at ASC')
        .get();
    final records = await _db
        .customSelect('SELECT * FROM care_record ORDER BY date DESC')
        .get();
    final readings = await _db
        .customSelect(
            'SELECT * FROM care_odometer_reading ORDER BY date ASC')
        .get();
    final fuel = await _db
        .customSelect('SELECT * FROM care_fuel_log ORDER BY date ASC')
        .get();
    final bills = await _db
        .customSelect('SELECT * FROM care_bill ORDER BY created_at ASC')
        .get();
    final payments = await _db
        .customSelect('SELECT * FROM care_bill_payment ORDER BY paid_date ASC')
        .get();
    final warranties = await _db
        .customSelect('SELECT * FROM care_warranty ORDER BY expiry_date ASC')
        .get();
    final subscriptions = await _db
        .customSelect(
            'SELECT * FROM care_subscription ORDER BY next_charge_date ASC')
        .get();
    final habits = await _db
        .customSelect('SELECT * FROM care_habit ORDER BY created_at ASC')
        .get();
    final completions = await _db
        .customSelect('SELECT * FROM habit_completion ORDER BY date ASC')
        .get();
    // care_reward carries no timestamp of its own (only `redeemed_at`), so it
    // is listed in the order the rows were written.
    final rewards = await _db
        .customSelect('SELECT * FROM care_reward ORDER BY rowid ASC')
        .get();

    return CareSnapshot(
      assets: assets.map(_asset).toList(),
      tasks: tasks.map(_task).toList(),
      records: records.map(_record).toList(),
      readings: readings.map(_reading).toList(),
      fuelLogs: fuel.map(_fuel).toList(),
      bills: bills.map(_bill).toList(),
      payments: payments.map(_payment).toList(),
      warranties: warranties.map(_warranty).toList(),
      subscriptions: subscriptions.map(_subscription).toList(),
      habits: habits.map(_habit).toList(),
      habitCompletions: completions.map(_habitCompletion).toList(),
      rewards: rewards.map(_reward).toList(),
    );
  }

  // ── rows → models ────────────────────────────────────────────────
  CareAsset _asset(QueryRow r) => CareAsset(
        id: r.read<String>('id'),
        kind: CareAssetKind.fromKey(r.read<String>('kind')),
        name: r.read<String>('name'),
        meta: _readMeta(r.read<String>('meta')),
        archived: r.read<int>('archived') != 0,
        createdAt: careDateFromStore(r.read<String>('created_at'))!,
      );

  CareTask _task(QueryRow r) {
    final sm = r.readNullable<int>('window_start_month');
    final em = r.readNullable<int>('window_end_month');
    final window = (sm != null && em != null)
        ? CareWindow(
            startMonth: sm,
            startDay: r.readNullable<int>('window_start_day') ?? 1,
            endMonth: em,
            endDay: r.readNullable<int>('window_end_day') ?? 1,
          )
        : null;
    return CareTask(
      id: r.read<String>('id'),
      assetId: r.read<String>('asset_id'),
      title: r.read<String>('title'),
      templateKey: r.read<String>('template_key'),
      categoryKey: r.read<String>('category_key'),
      iconKey: r.read<String>('icon_key'),
      scheduleType: CareScheduleType.fromKey(r.read<String>('schedule_type')),
      intervalDays: r.readNullable<int>('interval_days'),
      intervalKm: r.readNullable<int>('interval_km'),
      window: window,
      lastDoneDate: careDateFromStore(r.readNullable<String>('last_done_date')),
      lastDoneKm: r.readNullable<int>('last_done_km'),
      firstDueDate: careDateFromStore(r.readNullable<String>('first_due_date')),
      firstDueKm: r.readNullable<int>('first_due_km'),
      remindBeforeDays: r.read<int>('remind_before_days'),
      remindBeforeKm: r.read<int>('remind_before_km'),
      notes: r.read<String>('notes'),
      active: r.read<int>('active') != 0,
      createdAt: careDateFromStore(r.read<String>('created_at'))!,
    );
  }

  CareRecord _record(QueryRow r) => CareRecord(
        id: r.read<String>('id'),
        assetId: r.read<String>('asset_id'),
        taskId: r.readNullable<String>('task_id'),
        title: r.read<String>('title'),
        date: careDateFromStore(r.read<String>('date'))!,
        odometerKm: r.readNullable<int>('odometer_km'),
        cost: r.readNullable<double>('cost'),
        note: r.read<String>('note'),
        attachmentPaths: _readJsonList(r.read<String>('attachment_paths')),
      );

  OdometerReading _reading(QueryRow r) => OdometerReading(
        id: r.read<String>('id'),
        assetId: r.read<String>('asset_id'),
        date: careDateFromStore(r.read<String>('date'))!,
        km: r.read<int>('km'),
      );

  FuelLog _fuel(QueryRow r) => FuelLog(
        id: r.read<String>('id'),
        assetId: r.read<String>('asset_id'),
        date: careDateFromStore(r.read<String>('date'))!,
        liters: r.read<double>('liters'),
        pricePerLiter: r.readNullable<double>('price_per_liter'),
        totalCost: r.readNullable<double>('total_cost'),
        odometerKm: r.read<int>('odometer_km'),
        fullTank: r.read<int>('full_tank') != 0,
      );

  Bill _bill(QueryRow r) => Bill(
        id: r.read<String>('id'),
        assetId: r.read<String>('asset_id'),
        type: r.read<String>('type'),
        title: r.read<String>('title'),
        recurrence: BillRecurrence.fromKey(r.read<String>('recurrence')),
        dueDay: r.read<int>('due_day'),
        customDays: r.readNullable<int>('custom_days'),
        firstDueDate: careDateFromStore(r.readNullable<String>('first_due_date')),
        expectedAmount: r.readNullable<double>('expected_amount'),
        active: r.read<int>('active') != 0,
        createdAt: careDateFromStore(r.read<String>('created_at'))!,
        attachmentPaths: _readJsonList(r.read<String>('attachment_paths')),
      );

  BillPayment _payment(QueryRow r) => BillPayment(
        id: r.read<String>('id'),
        billId: r.read<String>('bill_id'),
        periodKey: r.read<String>('period_key'),
        paidDate: careDateFromStore(r.read<String>('paid_date'))!,
        amount: r.readNullable<double>('amount'),
        note: r.read<String>('note'),
      );

  Warranty _warranty(QueryRow r) => Warranty(
        id: r.read<String>('id'),
        assetId: r.read<String>('asset_id'),
        itemName: r.read<String>('item_name'),
        store: r.read<String>('store'),
        serial: r.read<String>('serial'),
        purchaseDate:
            careDateFromStore(r.read<String>('purchase_date'))!,
        months: r.read<int>('months'),
        expiryDate: careDateFromStore(r.read<String>('expiry_date'))!,
        receiptPaths: _readJsonList(r.read<String>('receipt_paths')),
        notes: r.read<String>('notes'),
      );

  Subscription _subscription(QueryRow r) => Subscription(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        amount: r.read<double>('amount'),
        period: SubscriptionPeriod.fromKey(r.read<String>('period')),
        nextChargeDate:
            careDateFromStore(r.read<String>('next_charge_date'))!,
        category: r.read<String>('category'),
        active: r.read<int>('active') != 0,
      );

  CareHabit _habit(QueryRow r) => CareHabit(
        id: r.read<String>('id'),
        kidId: r.read<String>('kid_id'),
        title: r.read<String>('title'),
        iconKey: r.read<String>('icon_key'),
        colorHex: r.read<String>('color_hex'),
        targetCount: r.read<int>('target_count'),
        unit: r.read<String>('unit'),
        startDate: careDateFromStore(r.readNullable<String>('start_date')),
        endDate: careDateFromStore(r.readNullable<String>('end_date')),
        createdAt: careDateFromStore(r.readNullable<String>('created_at')),
        active: r.read<int>('active') != 0,
      );

  CareHabitCompletion _habitCompletion(QueryRow r) => CareHabitCompletion(
        id: r.read<String>('id'),
        habitId: r.read<String>('habit_id'),
        date: careDateFromStore(r.read<String>('date'))!,
        count: r.read<int>('count'),
        notes: r.read<String>('notes'),
        createdAt: careDateFromStore(r.readNullable<String>('created_at')),
      );

  CareReward _reward(QueryRow r) => CareReward(
        id: r.read<String>('id'),
        kidId: r.read<String>('kid_id'),
        title: r.read<String>('title'),
        iconKey: r.read<String>('icon_key'),
        costPoints: r.read<int>('cost_points'),
        description: r.read<String>('description'),
        redeemedAt: careDateFromStore(r.readNullable<String>('redeemed_at')),
      );

  // ── writes ──────────────────────────────────────────────────────
  @override
  Future<void> saveAsset(CareAsset a) => _db.customStatement(
        'INSERT OR REPLACE INTO care_asset '
        '(id, kind, name, meta, archived, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          a.id,
          a.kind.key,
          a.name,
          jsonEncode(a.meta),
          a.archived ? 1 : 0,
          careDateToStore(a.createdAt),
        ],
      );

  @override
  Future<void> deleteAsset(String id) => _db.transaction(() async {
        await _db.customStatement(
            'DELETE FROM care_task WHERE asset_id = ?', [id]);
        await _db.customStatement(
            'DELETE FROM care_record WHERE asset_id = ?', [id]);
        await _db.customStatement(
            'DELETE FROM care_odometer_reading WHERE asset_id = ?', [id]);
        await _db.customStatement(
            'DELETE FROM care_fuel_log WHERE asset_id = ?', [id]);
        await _db.customStatement(
            'DELETE FROM care_bill WHERE asset_id = ?', [id]);
        await _db.customStatement(
            'DELETE FROM care_warranty WHERE asset_id = ?', [id]);
        await _db.customStatement('DELETE FROM care_asset WHERE id = ?', [id]);
      });

  @override
  Future<void> saveTask(CareTask t) => _db.customStatement(
        'INSERT OR REPLACE INTO care_task ('
        'id, asset_id, title, template_key, category_key, icon_key, '
        'schedule_type, interval_days, interval_km, window_start_month, '
        'window_start_day, window_end_month, window_end_day, last_done_date, '
        'last_done_km, first_due_date, first_due_km, remind_before_days, '
        'remind_before_km, notes, active, created_at'
        ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          t.id,
          t.assetId,
          t.title,
          t.templateKey,
          t.categoryKey,
          t.iconKey,
          t.scheduleType.key,
          t.intervalDays,
          t.intervalKm,
          t.window?.startMonth,
          t.window?.startDay,
          t.window?.endMonth,
          t.window?.endDay,
          t.lastDoneDate == null ? null : careDateToStore(t.lastDoneDate!),
          t.lastDoneKm,
          t.firstDueDate == null ? null : careDateToStore(t.firstDueDate!),
          t.firstDueKm,
          t.remindBeforeDays,
          t.remindBeforeKm,
          t.notes,
          t.active ? 1 : 0,
          careDateToStore(t.createdAt),
        ],
      );

  @override
  Future<void> deleteTask(String id) =>
      _db.customStatement('DELETE FROM care_task WHERE id = ?', [id]);

  @override
  Future<void> addReading(OdometerReading r) => _db.customStatement(
        'INSERT OR REPLACE INTO care_odometer_reading '
        '(id, asset_id, date, km) VALUES (?, ?, ?, ?)',
        [r.id, r.assetId, careDateToStore(r.date), r.km],
      );

  @override
  Future<void> addFuel(FuelLog f) => _db.customStatement(
        'INSERT OR REPLACE INTO care_fuel_log ('
        'id, asset_id, date, liters, price_per_liter, total_cost, '
        'odometer_km, full_tank) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          f.id,
          f.assetId,
          careDateToStore(f.date),
          f.liters,
          f.pricePerLiter,
          f.totalCost,
          f.odometerKm,
          f.fullTank ? 1 : 0,
        ],
      );

  @override
  Future<void> applyCompletion({
    required List<CareRecord> records,
    required List<CareTask> tasks,
  }) =>
      _db.transaction(() async {
        for (final r in records) {
          await _insertRecord(r);
        }
        for (final t in tasks) {
          await saveTask(t);
        }
      });

  @override
  Future<void> undoCompletion({
    required List<String> recordIds,
    required List<CareTask> tasks,
  }) =>
      _db.transaction(() async {
        for (final id in recordIds) {
          await _db.customStatement(
              'DELETE FROM care_record WHERE id = ?', [id]);
        }
        for (final t in tasks) {
          await saveTask(t);
        }
      });

  Future<void> _insertRecord(CareRecord r) => _db.customStatement(
        'INSERT OR REPLACE INTO care_record ('
        'id, asset_id, task_id, title, date, odometer_km, cost, note, '
        'attachment_paths) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          r.id,
          r.assetId,
          r.taskId,
          r.title,
          careDateToStore(r.date),
          r.odometerKm,
          r.cost,
          r.note,
          _jsonList(r.attachmentPaths),
        ],
      );

  @override
  Future<void> saveRecord(CareRecord record) => _insertRecord(record);

  @override
  Future<void> deleteRecord(String id) =>
      _db.customStatement('DELETE FROM care_record WHERE id = ?', [id]);

  @override
  Future<void> saveBill(Bill b) => _db.customStatement(
        'INSERT OR REPLACE INTO care_bill ('
        'id, asset_id, type, title, recurrence, due_day, custom_days, '
        'first_due_date, expected_amount, active, created_at, attachment_paths'
        ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          b.id,
          b.assetId,
          b.type,
          b.title,
          b.recurrence.key,
          b.dueDay,
          b.customDays,
          b.firstDueDate == null ? null : careDateToStore(b.firstDueDate!),
          b.expectedAmount,
          b.active ? 1 : 0,
          careDateToStore(b.createdAt),
          _jsonList(b.attachmentPaths),
        ],
      );

  @override
  Future<void> deleteBill(String id) => _db.transaction(() async {
        await _db.customStatement(
            'DELETE FROM care_bill_payment WHERE bill_id = ?', [id]);
        await _db.customStatement('DELETE FROM care_bill WHERE id = ?', [id]);
      });

  @override
  Future<void> savePayment(BillPayment p) => _db.customStatement(
        'INSERT OR REPLACE INTO care_bill_payment ('
        'id, bill_id, period_key, paid_date, amount, note) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          p.id,
          p.billId,
          p.periodKey,
          careDateToStore(p.paidDate),
          p.amount,
          p.note,
        ],
      );

  @override
  Future<void> deletePayment(String id) => _db.customStatement(
      'DELETE FROM care_bill_payment WHERE id = ?', [id]);

  @override
  Future<void> saveWarranty(Warranty w) => _db.customStatement(
        'INSERT OR REPLACE INTO care_warranty ('
        'id, asset_id, item_name, store, serial, purchase_date, months, '
        'expiry_date, receipt_paths, notes) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          w.id,
          w.assetId,
          w.itemName,
          w.store,
          w.serial,
          careDateToStore(w.purchaseDate),
          w.months,
          careDateToStore(w.expiryDate),
          _jsonList(w.receiptPaths),
          w.notes,
        ],
      );

  @override
  Future<void> deleteWarranty(String id) => _db.customStatement(
      'DELETE FROM care_warranty WHERE id = ?', [id]);

  @override
  Future<void> saveSubscription(Subscription s) => _db.customStatement(
        'INSERT OR REPLACE INTO care_subscription ('
        'id, name, amount, period, next_charge_date, category, active) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          s.id,
          s.name,
          s.amount,
          s.period.key,
          careDateToStore(s.nextChargeDate),
          s.category,
          s.active ? 1 : 0,
        ],
      );

  @override
  Future<void> deleteSubscription(String id) => _db.customStatement(
      'DELETE FROM care_subscription WHERE id = ?', [id]);

  @override
  Future<void> saveHabit(CareHabit h) => _db.customStatement(
        'INSERT OR REPLACE INTO care_habit ('
        'id, kid_id, title, icon_key, color_hex, target_count, unit, '
        'start_date, end_date, active, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          h.id,
          h.kidId,
          h.title,
          h.iconKey,
          h.colorHex,
          h.targetCount,
          h.unit,
          h.startDate == null ? null : careDateToStore(h.startDate!),
          h.endDate == null ? null : careDateToStore(h.endDate!),
          h.active ? 1 : 0,
          h.createdAt == null ? null : careDateToStore(h.createdAt!),
        ],
      );

  @override
  Future<void> deleteHabit(String id) => _db.customStatement(
      'DELETE FROM care_habit WHERE id = ?', [id]);

  @override
  Future<void> saveHabitCompletion(CareHabitCompletion c) =>
      _db.customStatement(
        'INSERT OR REPLACE INTO habit_completion ('
        'id, habit_id, date, count, notes, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          c.id,
          c.habitId,
          careDateToStore(c.date),
          c.count,
          c.notes,
          c.createdAt == null ? null : careDateToStore(c.createdAt!),
        ],
      );

  @override
  Future<void> deleteHabitCompletion(String id) =>
      _db.customStatement('DELETE FROM habit_completion WHERE id = ?', [id]);

  @override
  Future<void> saveReward(CareReward r) => _db.customStatement(
        'INSERT OR REPLACE INTO care_reward ('
        'id, kid_id, title, icon_key, cost_points, description, redeemed_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          r.id,
          r.kidId,
          r.title,
          r.iconKey,
          r.costPoints,
          r.description,
          r.redeemedAt == null ? null : careDateToStore(r.redeemedAt!),
        ],
      );

  @override
  Future<void> deleteReward(String id) =>
      _db.customStatement('DELETE FROM care_reward WHERE id = ?', [id]);

  @override
  Future<void> redeemReward(String id) =>
      _db.customStatement(
        'UPDATE care_reward SET redeemed_at = ? WHERE id = ?',
        [careDateToStore(DateTime.now()), id],
      );
}
