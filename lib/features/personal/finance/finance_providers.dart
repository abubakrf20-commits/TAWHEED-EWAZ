import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/personal/finance/finance_engine.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_planner.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_scheduler.dart';
import 'package:tawheeed/features/personal/finance/finance_repository.dart';
import 'package:tawheeed/features/personal/finance/finance_settings.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Swap point for tests (in-memory repository) and for a later platform.
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return DriftFinanceRepository(ref.watch(appDatabaseProvider));
});

final financeRemindersProvider = Provider<FinanceReminders>(
  (ref) => const FinanceReminderScheduler(),
);

final financeSettingsProvider = FutureProvider<FinanceReminderSettings>(
  (ref) => FinanceSettingsStore.load(),
);

/// The polite-reminder templates (`assets/data/debt_message_templates.json`).
final debtTemplatesProvider =
    FutureProvider<List<DebtMessageTemplate>>((ref) async {
  try {
    final raw =
        await rootBundle.loadString('assets/data/debt_message_templates.json');
    return parseDebtTemplates(raw);
  } catch (e) {
    AppLogger.warning('DebtMessage', 'bundle read failed: $e');
    return const [];
  }
});

/// Which finance tab is showing; kept in a provider so a rebuild (adding a
/// cheque, coming back from a person page) does not bounce the user back to
/// the first tab.
final financeTabProvider = StateProvider<int>((ref) => 0);

/// Filters for the obligations timeline.
class FinanceFilter {
  const FinanceFilter({
    this.query = '',
    this.kinds = const {},
    this.includePaid = false,
  });

  final String query;

  /// Empty = every kind.
  final Set<ObligationKind> kinds;
  final bool includePaid;

  FinanceFilter copyWith({
    String? query,
    Set<ObligationKind>? kinds,
    bool? includePaid,
  }) =>
      FinanceFilter(
        query: query ?? this.query,
        kinds: kinds ?? this.kinds,
        includePaid: includePaid ?? this.includePaid,
      );
}

final financeFilterProvider =
    StateProvider<FinanceFilter>((ref) => const FinanceFilter());

/// The bundle an undo restores: the obligation as it was before the edit.
class FinanceUndo {
  const FinanceUndo({required this.previous, required this.wasInserted});

  final Obligation previous;

  /// True when the completion also created the row (never for stage 2 — kept
  /// so a future «quick add + pay» cannot silently leave an orphan).
  final bool wasInserted;
}

/// The single store the finance page watches. Persist first, republish second:
/// the UI never shows a row the database rejected.
class FinanceStore extends AsyncNotifier<FinanceSnapshot> {
  FinanceRepository get _repo => ref.read(financeRepositoryProvider);
  static final Random _rng = Random();

  @override
  Future<FinanceSnapshot> build() => _repo.load();

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(9999)}';

  String get _unit => CurrencyStore.calculators.current.unit;

  Future<FinanceSnapshot> _reload() async {
    final snapshot = await _repo.load();
    state = AsyncData(snapshot);
    _syncReminders(snapshot);
    return snapshot;
  }

  void _syncReminders(FinanceSnapshot snapshot) {
    unawaited(
      ref
          .read(financeRemindersProvider)
          .sync(snapshot, currencyUnit: _unit)
          .catchError((Object e) {
        AppLogger.warning('FinanceStore', 'reminder sync failed: $e');
      }),
    );
  }

  Future<void> refreshReminders() async {
    final snapshot = state.value;
    if (snapshot == null) return;
    await ref.read(financeRemindersProvider).sync(
          snapshot,
          settings: await FinanceSettingsStore.load(),
          currencyUnit: _unit,
        );
  }

  // ── obligations ─────────────────────────────────────────────────────

  Future<Obligation> addObligation({
    required ObligationKind kind,
    required ObligationDirection direction,
    required String title,
    required double amount,
    required DateTime dueDate,
    String counterparty = '',
    String chequeNumber = '',
    String bankName = '',
    String note = '',
    int? remindBeforeDays,
    List<String> attachmentPaths = const [],
  }) async {
    final obligation = Obligation(
      id: _id('obl'),
      kind: kind,
      direction: direction,
      title: title.trim().isEmpty ? kind.labelFa : title.trim(),
      counterparty: counterparty.trim(),
      amount: amount,
      dueDate: financeDay(dueDate),
      chequeNumber: chequeNumber.trim(),
      bankName: bankName.trim(),
      note: note.trim(),
      remindBeforeDays: remindBeforeDays ?? kind.defaultRemindBeforeDays,
      attachmentPaths: attachmentPaths,
      createdAt: financeDay(DateTime.now()),
    );
    await _repo.saveObligation(obligation);
    await _reload();
    return obligation;
  }

  Future<void> updateObligation(Obligation obligation) async {
    await _repo.saveObligation(obligation);
    await _reload();
  }

  Future<void> deleteObligation(String id) async {
    await _repo.deleteObligation(id);
    await _reload();
  }

  /// Marks paid with the actual date and amount, returning what to undo.
  Future<FinanceUndo?> markPaid(
    Obligation obligation, {
    DateTime? paidDate,
    double? paidAmount,
    String note = '',
  }) async {
    final updated = obligation.copyWith(
      status: ObligationStatus.paid,
      paidDate: financeDay(paidDate ?? DateTime.now()),
      paidAmount: paidAmount ?? obligation.amount,
      note: note.trim().isEmpty ? obligation.note : note.trim(),
    );
    await _repo.saveObligation(updated);
    await _reload();
    return FinanceUndo(previous: obligation, wasInserted: false);
  }

  Future<void> undoPaid(FinanceUndo undo) async {
    await _repo.saveObligation(undo.previous);
    await _reload();
  }

  /// Moves a due date and remembers it as postponed.
  Future<FinanceUndo> postpone(Obligation obligation, DateTime newDate) async {
    final updated = obligation.copyWith(
      dueDate: financeDay(newDate),
      status: ObligationStatus.postponed,
    );
    await _repo.saveObligation(updated);
    await _reload();
    return FinanceUndo(previous: obligation, wasInserted: false);
  }

  Future<void> cancel(Obligation obligation) async {
    await _repo.saveObligation(
        obligation.copyWith(status: ObligationStatus.cancelled));
    await _reload();
  }

  // ── plans ───────────────────────────────────────────────────────────

  /// Creates the plan AND its rows in one go. The rows keep the Jalali day of
  /// [firstDueDate]; a short month clamps to its last day.
  Future<InstallmentPlan> addPlan({
    required String title,
    required ObligationKind kind,
    required DateTime firstDueDate,
    required int count,
    required double amount,
    int intervalMonths = 1,
    String counterparty = '',
    double? totalAmount,
    String note = '',
  }) async {
    final plan = InstallmentPlan(
      id: _id('plan'),
      title: title.trim().isEmpty ? kind.labelFa : title.trim(),
      kind: kind,
      counterparty: counterparty.trim(),
      firstDueDate: financeDay(firstDueDate),
      count: count,
      amount: amount,
      intervalMonths: intervalMonths < 1 ? 1 : intervalMonths,
      totalAmount: totalAmount,
      note: note.trim(),
      createdAt: financeDay(DateTime.now()),
    );
    await _repo.savePlan(plan);
    final rows = financePlanObligations(
      plan,
      idFactory: (_) => _id('obl'),
      createdAt: financeDay(DateTime.now()),
    );
    await _repo.saveObligations(rows);
    await _reload();
    return plan;
  }

  /// Rewrites the plan's FUTURE unpaid rows. Paid rows and rows before
  /// [now] are history and never change.
  Future<void> updatePlan(InstallmentPlan plan) async {
    await _repo.savePlan(plan);
    final snapshot = state.value;
    if (snapshot != null) {
      final today = financeDay(DateTime.now());
      final future = snapshot
          .obligationsOfPlan(plan.id)
          .where((o) => !o.isPaid && !o.dueDate.isBefore(today))
          .toList();
      final regenerated = <Obligation>[];
      final step = plan.intervalMonths < 1 ? 1 : plan.intervalMonths;
      for (final row in future) {
        final index = (row.installmentNo ?? 1) - 1;
        regenerated.add(row.copyWith(
          title: plan.title,
          counterparty: plan.counterparty,
          amount: plan.amount,
          note: plan.note,
          dueDate: financeAddJalaliMonths(plan.firstDueDate, index * step),
        ));
      }
      if (regenerated.isNotEmpty) {
        await _repo.saveObligations(regenerated);
      }

      // Raising `count` used to edit existing rows and silently stop there:
      // the extra instalments the user asked for never appeared. Generate the
      // plan's full schedule and append only the numbers not already stored,
      // so paid rows, postponed rows and historic rows all keep their ids.
      final existingNumbers = snapshot
          .obligationsOfPlan(plan.id)
          .map((o) => o.installmentNo)
          .whereType<int>()
          .toSet();
      final missing = financePlanObligations(
        plan,
        idFactory: (_) => _id('obl'),
        createdAt: financeDay(DateTime.now()),
      ).where((o) => !existingNumbers.contains(o.installmentNo)).toList();
      if (missing.isNotEmpty) {
        await _repo.saveObligations(missing);
      }
    }
    await _reload();
  }

  /// Removes the plan and, when [deleteUnpaid] is set, the rows it still owes.
  Future<void> deletePlan(String planId, {required bool deleteUnpaid}) async {
    if (deleteUnpaid) await _repo.deletePlanUnpaid(planId);
    await _repo.deletePlan(planId);
    await _reload();
  }

  // ── debt ledger ─────────────────────────────────────────────────────

  Future<Person> addPerson({
    required String name,
    String phone = '',
    String note = '',
  }) async {
    final person = Person(
      id: _id('person'),
      name: name.trim(),
      phone: phone.trim(),
      note: note.trim(),
      createdAt: financeDay(DateTime.now()),
    );
    await _repo.savePerson(person);
    await _reload();
    return person;
  }

  Future<void> updatePerson(Person person) async {
    await _repo.savePerson(person);
    await _reload();
  }

  Future<void> deletePerson(String id) async {
    await _repo.deletePerson(id);
    await _reload();
  }

  Future<DebtEntry> addEntry({
    required String personId,
    required DebtDirection direction,
    required double amount,
    DateTime? dueDate,
    String note = '',
    String witnessNote = '',
  }) async {
    final entry = DebtEntry(
      id: _id('debt'),
      personId: personId,
      direction: direction,
      amount: amount,
      createdDate: financeDay(DateTime.now()),
      dueDate: dueDate == null ? null : financeDay(dueDate),
      note: note.trim(),
      witnessNote: witnessNote.trim(),
    );
    await _repo.saveEntry(entry);
    await _reload();
    return entry;
  }

  Future<void> updateEntry(DebtEntry entry) async {
    await _repo.saveEntry(entry);
    await _reload();
  }

  Future<void> deleteEntry(String id) async {
    await _repo.deleteEntry(id);
    await _reload();
  }

  /// Records a payment. A payment that clears the amount closes the entry, so
  /// the list can show «تسویه‌شده» without a second tap.
  Future<DebtPayment> addPayment({
    required DebtEntry entry,
    required double amount,
    DateTime? date,
    String note = '',
  }) async {
    final payment = DebtPayment(
      id: _id('pay'),
      entryId: entry.id,
      date: financeDay(date ?? DateTime.now()),
      amount: amount,
      note: note.trim(),
    );
    await _repo.savePayment(payment);
    final snapshot = state.value;
    if (snapshot != null) {
      final remaining =
          debtRemaining(entry, [...snapshot.paymentsOf(entry.id), payment]);
      if (remaining <= 0 && !entry.closed) {
        await _repo.saveEntry(entry.copyWith(closed: true));
      }
    }
    await _reload();
    return payment;
  }

  Future<void> deletePayment(String id) async {
    await _repo.deletePayment(id);
    await _reload();
  }

  /// Re-opens a settled entry after an edit.
  Future<void> reopen(DebtEntry entry) async {
    await _repo.saveEntry(entry.copyWith(closed: false));
    await _reload();
  }
}

final financeStoreProvider =
    AsyncNotifierProvider<FinanceStore, FinanceSnapshot>(FinanceStore.new);
