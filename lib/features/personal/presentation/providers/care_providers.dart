import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_template_overrides.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';
import 'package:tawheeed/features/personal/data/care_repository.dart';
import 'package:tawheeed/features/personal/services/care_reminder_scheduler.dart';
import 'package:tawheeed/features/personal/services/care_settings.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Swap point for tests (in-memory repository) and for a future platform.
final careRepositoryProvider = Provider<CareRepository>((ref) {
  return DriftCareRepository(ref.watch(appDatabaseProvider));
});

/// The user's edits to the suggested defaults, stored in
/// `p2_template_override` under the `care_template` kind.
final careTemplateOverridesProvider = Provider<CareTemplateOverrideStore>(
  (ref) => CareTemplateOverrides(ref.watch(appDatabaseProvider)),
);

/// The bundled defaults (`assets/data/care_templates.json`) with the user's
/// overrides already applied. The asset stays the suggestion; an edit is a row,
/// never a rewrite of the bundle.
final careTemplatesProvider = FutureProvider<CareTemplates>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/data/care_templates.json');
    final base = CareTemplates.parse(raw);
    final overrides = await ref.read(careTemplateOverridesProvider).load();
    return applyCareTemplateOverrides(base, overrides);
  } catch (e) {
    AppLogger.warning('CareTemplates', 'bundle read failed: $e');
    return const CareTemplates(
        carDefaults: [], homeDefaults: [], seasonPacks: []);
  }
});

final careRemindersProvider = Provider<CareReminders>(
  (ref) => const CareReminderScheduler(),
);

final careSettingsProvider = FutureProvider<CareReminderSettings>(
  (ref) => CareSettingsStore.load(),
);

/// Which car / home the page is showing. A single selection is enough for the
/// common case; several assets get a chips row that writes these.
final selectedCarProvider = StateProvider<String?>((ref) => null);
final selectedHomeProvider = StateProvider<String?>((ref) => null);

/// The undo bundle returned by [CareStore.completeTasks].
class CareCompletionResult {
  const CareCompletionResult({
    required this.records,
    required this.previousTasks,
  });

  final List<CareRecord> records;
  final List<CareTask> previousTasks;
}

/// The single store the two tool pages watch. Every mutation persists first and
/// only then republishes the snapshot, so the UI never shows an edit the
/// database rejected.
class CareStore extends AsyncNotifier<CareSnapshot> {
  CareRepository get _repo => ref.read(careRepositoryProvider);
  static final Random _rng = Random();

  @override
  Future<CareSnapshot> build() => _repo.load();

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(9999)}';

  Future<CareSnapshot> _reload() async {
    final snapshot = await _repo.load();
    state = AsyncData(snapshot);
    _syncReminders(snapshot);
    return snapshot;
  }

  void _syncReminders(CareSnapshot snapshot) {
    unawaited(
      ref.read(careRemindersProvider).sync(snapshot).catchError((Object e) {
        AppLogger.warning('CareStore', 'reminder sync failed: $e');
      }),
    );
  }

  /// Re-runs the scheduler after a settings change.
  Future<void> refreshReminders() async {
    final snapshot = state.value;
    if (snapshot == null) return;
    await ref.read(careRemindersProvider).sync(
          snapshot,
          settings: await CareSettingsStore.load(),
        );
  }

  // ── assets & tasks ────────────────────────────────────────────────

  Future<CareAsset> addCar({
    required String name,
    required String make,
    required String model,
    String color = '',
    String plate = '',
    String fuelType = 'petrol',
    required List<CareTemplate> templates,
    DateTime? firstDueDate,
    int? firstDueKm,
    int? odometerKm,
  }) async {
    final now = DateTime.now();
    final asset = CareAsset(
      id: _id('car'),
      kind: CareAssetKind.car,
      name: name.trim().isEmpty ? 'خودرو' : name.trim(),
      meta: {
        'make': make.trim(),
        'model': model.trim(),
        'color': color.trim(),
        'plate': plate.trim(),
        'fuelType': fuelType,
        'odometerUnit': 'km',
      },
      createdAt: now,
    );
    await _repo.saveAsset(asset);
    for (final template in templates) {
      await _repo.saveTask(template.toTask(
        id: _id('task'),
        assetId: asset.id,
        now: now,
      ).copyWith(firstDueDate: firstDueDate, firstDueKm: firstDueKm));
    }
    if (odometerKm != null && odometerKm > 0) {
      await _repo.addReading(OdometerReading(
        id: _id('odo'),
        assetId: asset.id,
        date: now,
        km: odometerKm,
      ));
    }
    await _reload();
    ref.read(selectedCarProvider.notifier).state = asset.id;
    return asset;
  }

  Future<CareAsset> addHome({
    required String name,
    required List<CareTemplate> templates,
    DateTime? firstDueDate,
  }) async {
    final now = DateTime.now();
    final asset = CareAsset(
      id: _id('home'),
      kind: CareAssetKind.home,
      name: name.trim().isEmpty ? 'خانه' : name.trim(),
      meta: {'nickname': name.trim()},
      createdAt: now,
    );
    await _repo.saveAsset(asset);
    for (final template in templates) {
      await _repo.saveTask(template.toTask(
        id: _id('task'),
        assetId: asset.id,
        now: now,
      ).copyWith(firstDueDate: firstDueDate));
    }
    await _reload();
    ref.read(selectedHomeProvider.notifier).state = asset.id;
    return asset;
  }

  Future<void> updateAsset(CareAsset asset) async {
    await _repo.saveAsset(asset);
    await _reload();
  }

  Future<void> deleteAsset(String assetId) async {
    await _repo.deleteAsset(assetId);
    await _reload();
  }

  /// Adds a season pack's tasks that the asset does not already have.
  Future<int> addSeasonPack(String assetId, CareSeasonPack pack) async {
    final templates = await ref.read(careTemplatesProvider.future);
    final snapshot = state.value;
    if (snapshot == null) return 0;
    final existing = snapshot
        .tasksOf(assetId)
        .map((t) => t.templateKey)
        .where((k) => k.isNotEmpty)
        .toSet();
    var added = 0;
    for (final key in pack.templateKeys) {
      if (existing.contains(key)) continue;
      final template = templates.byKey(key);
      if (template == null) continue;
      await _repo.saveTask(template.toTask(
        id: _id('task'),
        assetId: assetId,
        now: DateTime.now(),
      ));
      added++;
    }
    await _reload();
    return added;
  }

  Future<void> addTemplateTask(String assetId, CareTemplate template) async {
    await _repo.saveTask(template.toTask(
      id: _id('task'),
      assetId: assetId,
      now: DateTime.now(),
    ));
    await _reload();
  }

  Future<void> saveTask(CareTask task) async {
    await _repo.saveTask(task);
    await _reload();
  }

  Future<void> deleteTask(String taskId) async {
    await _repo.deleteTask(taskId);
    await _reload();
  }

  // ── odometer & fuel ───────────────────────────────────────────────

  Future<void> logOdometer(String assetId, int km, DateTime date) async {
    final before = state.value;
    await _repo.addReading(OdometerReading(
      id: _id('odo'),
      assetId: assetId,
      date: date,
      km: km,
    ));
    final snapshot = await _reload();
    // A new reading can cross a task's km threshold — the one case that must
    // notify immediately rather than at the next daily sync.
    if (before == null) return;
    for (final task in snapshot.tasksOf(assetId)) {
      if (!task.scheduleType.usesDistance || !task.active) continue;
      final previous = careStatusOf(
        task,
        DateTime.now(),
        currentKm: before.currentKm(assetId),
        readings: before.readingsOf(assetId),
      ).kmRemaining;
      final current = careStatusOf(
        task,
        DateTime.now(),
        currentKm: km,
        readings: snapshot.readingsOf(assetId),
      ).kmRemaining;
      if (previous == null || current == null) continue;
      if (previous > task.remindBeforeKm && current <= task.remindBeforeKm) {
        await ref.read(careRemindersProvider).notifyThresholdCrossed(
              title: 'یادآوری: ${task.title}',
              body: '${task.remindBeforeKm} کیلومتر تا سرویس «${task.title}» مانده است.',
              payload: 'care_car_task_${task.id}',
            );
      }
    }
  }

  Future<void> addFuel(FuelLog log) async {
    await _repo.addFuel(log);
    await _reload();
  }

  String newId(String prefix) => _id(prefix);

  // ── completion & undo ─────────────────────────────────────────────

  /// Completes [taskIds] in one pass. The cost/note/attachments land on the
  /// first record only, so a three-task service is not counted three times in
  /// «هزینهٔ امسال».
  Future<CareCompletionResult?> completeTasks({
    required String assetId,
    required List<String> taskIds,
    required DateTime date,
    int? odometerKm,
    double? cost,
    String note = '',
    List<String> attachmentPaths = const [],
  }) async {
    final snapshot = state.value;
    if (snapshot == null) return null;
    final records = <CareRecord>[];
    final previous = <CareTask>[];
    final updated = <CareTask>[];

    final byId = {for (final t in snapshot.tasks) t.id: t};
    for (var i = 0; i < taskIds.length; i++) {
      final task = byId[taskIds[i]];
      // A task deleted in another window between the tap and this write is
      // skipped, never guessed at.
      if (task == null) continue;
      previous.add(task);
      final doneKm = odometerKm ?? task.lastDoneKm;
      final next = task.copyWith(
        lastDoneDate: date,
        lastDoneKm: doneKm,
      );
      updated.add(next);
      records.add(CareRecord(
        id: _id('rec'),
        assetId: assetId,
        taskId: task.id,
        title: task.title,
        date: date,
        odometerKm: odometerKm,
        cost: i == 0 ? cost : null,
        note: i == 0 ? note : '',
        attachmentPaths: i == 0 ? attachmentPaths : const [],
      ));
    }

    if (records.isEmpty) return null;
    await _repo.applyCompletion(records: records, tasks: updated);
    // A completion at a higher odometer is also an odometer reading.
    if (odometerKm != null && odometerKm > (snapshot.currentKm(assetId) ?? 0)) {
      await _repo.addReading(OdometerReading(
        id: _id('odo'),
        assetId: assetId,
        date: date,
        km: odometerKm,
      ));
    }
    await _reload();
    AppLogger.info('CareStore',
        'completed ${records.length} tasks for $assetId on $date');
    return CareCompletionResult(records: records, previousTasks: previous);
  }

  Future<void> undoCompletion(CareCompletionResult result) async {
    await _repo.undoCompletion(
      recordIds: result.records.map((r) => r.id).toList(),
      tasks: result.previousTasks,
    );
    // Attachment files are pruned by the UI layer, which owns the store; the
    // store only removes the rows.
    await _reload();
  }

  Future<void> deleteRecord(String recordId) async {
    await _repo.deleteRecord(recordId);
    await _reload();
  }

  Future<void> saveRecord(CareRecord record) async {
    await _repo.saveRecord(record);
    await _reload();
  }

  // ── bills ─────────────────────────────────────────────────────────

  Future<void> saveBill(Bill bill, {bool isNew = false}) async {
    await _repo.saveBill(bill);
    await _reload();
  }

  String billId() => _id('bill');

  Future<void> deleteBill(String billId) async {
    await _repo.deleteBill(billId);
    await _reload();
  }

  Future<void> payBill({
    required Bill bill,
    required String periodKey,
    required DateTime paidDate,
    double? amount,
    String note = '',
  }) async {
    await _repo.savePayment(BillPayment(
      id: _id('pay'),
      billId: bill.id,
      periodKey: periodKey,
      paidDate: paidDate,
      amount: amount ?? bill.expectedAmount,
      note: note,
    ));
    await _reload();
  }

  Future<void> deletePayment(String paymentId) async {
    await _repo.deletePayment(paymentId);
    await _reload();
  }

  // ── warranties & subscriptions ────────────────────────────────────

  Future<void> saveWarranty(Warranty warranty) async {
    await _repo.saveWarranty(warranty);
    await _reload();
  }

  String warrantyId() => _id('war');

  Future<void> deleteWarranty(String id) async {
    await _repo.deleteWarranty(id);
    await _reload();
  }

  Future<void> saveSubscription(Subscription subscription) async {
    await _repo.saveSubscription(subscription);
    await _reload();
  }

  String subscriptionId() => _id('sub');

  Future<void> deleteSubscription(String id) async {
    await _repo.deleteSubscription(id);
    await _reload();
  }

  Future<void> saveHabit(CareHabit h) async {
    await _repo.saveHabit(h);
    await _reload();
  }

  Future<void> deleteHabit(String id) async {
    await _repo.deleteHabit(id);
    await _reload();
  }

  Future<void> saveHabitCompletion(CareHabitCompletion c) async {
    await _repo.saveHabitCompletion(c);
    await _reload();
  }

  Future<void> deleteHabitCompletion(String id) async {
    await _repo.deleteHabitCompletion(id);
    await _reload();
  }

  Future<void> saveReward(CareReward r) async {
    await _repo.saveReward(r);
    await _reload();
  }

  Future<void> deleteReward(String id) async {
    await _repo.deleteReward(id);
    await _reload();
  }

  Future<void> redeemReward(String id) async {
    await _repo.redeemReward(id);
    await _reload();
  }
}

final careStoreProvider =
    AsyncNotifierProvider<CareStore, CareSnapshot>(CareStore.new);

/// Upcoming due items across both tools (the spec's pure provider, exposed).
final careDueItemsProvider = Provider<List<CareDueItem>>((ref) {
  final snapshot = ref.watch(careStoreProvider).value;
  if (snapshot == null) return const [];
  return const CareDueItemsProvider().upcoming(
    snapshot: snapshot,
    now: DateTime.now(),
  );
});

/// All habits for the selected kid. If [kidId] is null, returns all habits.
final careHabitsProvider = Provider.family<List<CareHabit>, String?>((ref, kidId) {
  final snapshot = ref.watch(careStoreProvider).value;
  if (snapshot == null) return const [];
  if (kidId == null) return snapshot.habits;
  return snapshot.habitsOf(kidId);
});

/// Completions for a specific habit.
final careHabitCompletionsProvider = Provider.family<List<CareHabitCompletion>, String>((ref, habitId) {
  final snapshot = ref.watch(careStoreProvider).value;
  if (snapshot == null) return const [];
  return snapshot.completionsOf(habitId);
});

/// All rewards for a specific kid (unredeemed).
final careRewardsProvider = Provider.family<List<CareReward>, String>((ref, kidId) {
  final snapshot = ref.watch(careStoreProvider).value;
  if (snapshot == null) return const [];
  return snapshot.rewardsOf(kidId);
});

/// Computed snapshot for a kid: habits + total points.
final kidSnapshotProvider = Provider.family<KidSnapshot, String>((ref, kidId) {
  final snapshot = ref.watch(careStoreProvider).value;
  if (snapshot == null) {
    return KidSnapshot(kidId: kidId, kidName: '', kidAvatar: '', totalPoints: 0);
  }
  final habits = snapshot.habitsOf(kidId);
  final completions = snapshot.habitCompletions;
  final totalPoints = completions.fold<int>(0, (s, c) => s + c.count);
  return KidSnapshot(
    kidId: kidId,
    kidName: '', // will be filled by UI layer from settings
    kidAvatar: '',
    totalPoints: totalPoints,
    habits: habits,
  );
});
