/// Storage contract + Drift implementation for «دفتر مالی».
///
/// Mirrors the stage-1 care repository: an abstract surface (so widget tests
/// run on an in-memory fake) and a raw-SQL implementation over the tables in
/// `finance_tables.dart`. Dates go through the same `yyyy-MM-dd` helpers as
/// stage 1 — one storage format for every personal tool.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show QueryRow;

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/data/care_repository.dart'
    show careDateFromStore, careDateToStore;
import 'package:tawheeed/features/personal/finance/finance_engine.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

abstract class FinanceRepository {
  Future<FinanceSnapshot> load();

  Future<void> savePlan(InstallmentPlan plan);
  Future<void> deletePlan(String planId);

  Future<void> saveObligation(Obligation obligation);
  Future<void> saveObligations(List<Obligation> obligations);

  /// Deletes the plan's rows that are still unpaid; paid history stays.
  Future<void> deletePlanUnpaid(String planId);

  Future<void> deleteObligation(String id);

  Future<void> savePerson(Person person);
  Future<void> deletePerson(String id);

  Future<void> saveEntry(DebtEntry entry);
  Future<void> deleteEntry(String id);

  Future<void> savePayment(DebtPayment payment);
  Future<void> deletePayment(String id);
}

String _jsonList(List<String> values) => jsonEncode(values);

List<String> _readJsonList(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<String>().toList();
  } catch (e) {
    AppLogger.warning('FinanceRepository', 'bad attachment list: $e');
    return const [];
  }
}

class DriftFinanceRepository implements FinanceRepository {
  DriftFinanceRepository(this._db);

  final AppDatabase _db;

  @override
  Future<FinanceSnapshot> load() async {
    final plans = await _db
        .customSelect('SELECT * FROM finance_plan ORDER BY created_at ASC')
        .get();
    final obligations = await _db
        .customSelect('SELECT * FROM finance_obligation ORDER BY due_date ASC')
        .get();
    final persons = await _db
        .customSelect('SELECT * FROM finance_person ORDER BY created_at ASC')
        .get();
    final entries = await _db
        .customSelect(
            'SELECT * FROM finance_debt_entry ORDER BY created_date DESC')
        .get();
    final payments = await _db
        .customSelect('SELECT * FROM finance_debt_payment ORDER BY date ASC')
        .get();

    return FinanceSnapshot(
      plans: plans.map(_planFromRow).toList(),
      obligations: obligations.map(_obligationFromRow).toList(),
      persons: persons.map(_personFromRow).toList(),
      entries: entries.map(_entryFromRow).toList(),
      payments: payments.map(_paymentFromRow).toList(),
    );
  }

  // ── plans ───────────────────────────────────────────────────────────

  @override
  Future<void> savePlan(InstallmentPlan plan) async {
    await _db.customStatement(
      '''
      INSERT INTO finance_plan
        (id, title, kind, counterparty, first_due_date, count, amount,
         interval_months, total_amount, note, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        kind = excluded.kind,
        counterparty = excluded.counterparty,
        first_due_date = excluded.first_due_date,
        count = excluded.count,
        amount = excluded.amount,
        interval_months = excluded.interval_months,
        total_amount = excluded.total_amount,
        note = excluded.note
      ''',
      [
        plan.id,
        plan.title,
        plan.kind.key,
        plan.counterparty,
        careDateToStore(plan.firstDueDate),
        plan.count,
        plan.amount,
        plan.intervalMonths,
        plan.totalAmount,
        plan.note,
        careDateToStore(plan.createdAt),
      ],
    );
  }

  @override
  Future<void> deletePlan(String planId) async {
    await _db.customStatement('DELETE FROM finance_plan WHERE id = ?', [planId]);
  }

  @override
  Future<void> deletePlanUnpaid(String planId) async {
    await _db.customStatement(
      "DELETE FROM finance_obligation WHERE plan_id = ? AND status != 'paid'",
      [planId],
    );
  }

  // ── obligations ─────────────────────────────────────────────────────

  @override
  Future<void> saveObligation(Obligation o) => saveObligations([o]);

  @override
  Future<void> saveObligations(List<Obligation> obligations) async {
    if (obligations.isEmpty) return;
    await _db.transaction(() async {
      for (final o in obligations) {
        await _db.customStatement(
          '''
          INSERT INTO finance_obligation
            (id, kind, direction, title, counterparty, amount, due_date,
             status, paid_date, paid_amount, plan_id, installment_no,
             cheque_number, bank_name, note, remind_before_days,
             attachment_paths, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            kind = excluded.kind,
            direction = excluded.direction,
            title = excluded.title,
            counterparty = excluded.counterparty,
            amount = excluded.amount,
            due_date = excluded.due_date,
            status = excluded.status,
            paid_date = excluded.paid_date,
            paid_amount = excluded.paid_amount,
            plan_id = excluded.plan_id,
            installment_no = excluded.installment_no,
            cheque_number = excluded.cheque_number,
            bank_name = excluded.bank_name,
            note = excluded.note,
            remind_before_days = excluded.remind_before_days,
            attachment_paths = excluded.attachment_paths
          ''',
          [
            o.id,
            o.kind.key,
            o.direction.key,
            o.title,
            o.counterparty,
            o.amount,
            careDateToStore(o.dueDate),
            o.status.key,
            o.paidDate == null ? null : careDateToStore(o.paidDate!),
            o.paidAmount,
            o.planId,
            o.installmentNo,
            o.chequeNumber,
            o.bankName,
            o.note,
            o.remindBeforeDays,
            _jsonList(o.attachmentPaths),
            careDateToStore(o.createdAt),
          ],
        );
      }
    });
  }

  @override
  Future<void> deleteObligation(String id) async {
    await _db.customStatement(
        'DELETE FROM finance_obligation WHERE id = ?', [id]);
  }

  // ── people & ledger ─────────────────────────────────────────────────

  @override
  Future<void> savePerson(Person person) async {
    await _db.customStatement(
      '''
      INSERT INTO finance_person (id, name, phone, note, created_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        phone = excluded.phone,
        note = excluded.note
      ''',
      [
        person.id,
        person.name,
        person.phone,
        person.note,
        careDateToStore(person.createdAt),
      ],
    );
  }

  @override
  Future<void> deletePerson(String id) async {
    await _db.transaction(() async {
      // Payments first: they reference entries, not the person.
      await _db.customStatement(
        'DELETE FROM finance_debt_payment WHERE entry_id IN '
        '(SELECT id FROM finance_debt_entry WHERE person_id = ?)',
        [id],
      );
      await _db.customStatement(
          'DELETE FROM finance_debt_entry WHERE person_id = ?', [id]);
      await _db.customStatement('DELETE FROM finance_person WHERE id = ?', [id]);
    });
  }

  @override
  Future<void> saveEntry(DebtEntry entry) async {
    await _db.customStatement(
      '''
      INSERT INTO finance_debt_entry
        (id, person_id, direction, amount, created_date, due_date, note,
         witness_note, closed)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        direction = excluded.direction,
        amount = excluded.amount,
        due_date = excluded.due_date,
        note = excluded.note,
        witness_note = excluded.witness_note,
        closed = excluded.closed
      ''',
      [
        entry.id,
        entry.personId,
        entry.direction.key,
        entry.amount,
        careDateToStore(entry.createdDate),
        entry.dueDate == null ? null : careDateToStore(entry.dueDate!),
        entry.note,
        entry.witnessNote,
        entry.closed ? 1 : 0,
      ],
    );
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _db.transaction(() async {
      await _db.customStatement(
          'DELETE FROM finance_debt_payment WHERE entry_id = ?', [id]);
      await _db.customStatement(
          'DELETE FROM finance_debt_entry WHERE id = ?', [id]);
    });
  }

  @override
  Future<void> savePayment(DebtPayment payment) async {
    await _db.customStatement(
      '''
      INSERT INTO finance_debt_payment (id, entry_id, date, amount, note)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        date = excluded.date,
        amount = excluded.amount,
        note = excluded.note
      ''',
      [
        payment.id,
        payment.entryId,
        careDateToStore(payment.date),
        payment.amount,
        payment.note,
      ],
    );
  }

  @override
  Future<void> deletePayment(String id) async {
    await _db.customStatement(
        'DELETE FROM finance_debt_payment WHERE id = ?', [id]);
  }

  // ── row mappers ─────────────────────────────────────────────────────

  InstallmentPlan _planFromRow(QueryRow row) {
    final r = row;
    return InstallmentPlan(
      id: r.read<String>('id'),
      title: r.read<String>('title'),
      kind: ObligationKind.fromKey(r.read<String>('kind')),
      counterparty: r.read<String>('counterparty'),
      firstDueDate: careDateFromStore(r.read<String>('first_due_date')) ??
          financeDay(DateTime.now()),
      count: r.read<int>('count'),
      amount: financeReadAmount(r.read<double?>('amount')),
      intervalMonths: r.read<int>('interval_months'),
      totalAmount: r.read<double?>('total_amount'),
      note: r.read<String>('note'),
      createdAt: careDateFromStore(r.read<String>('created_at')) ??
          financeDay(DateTime.now()),
    );
  }

  Obligation _obligationFromRow(QueryRow row) {
    final r = row;
    return Obligation(
      id: r.read<String>('id'),
      kind: ObligationKind.fromKey(r.read<String>('kind')),
      direction: ObligationDirection.fromKey(r.read<String>('direction')),
      title: r.read<String>('title'),
      counterparty: r.read<String>('counterparty'),
      amount: financeReadAmount(r.read<double?>('amount')),
      dueDate: careDateFromStore(r.read<String>('due_date')) ??
          financeDay(DateTime.now()),
      status: ObligationStatus.fromKey(r.read<String>('status')),
      paidDate: careDateFromStore(r.read<String?>('paid_date')),
      paidAmount: r.read<double?>('paid_amount'),
      planId: r.read<String?>('plan_id'),
      installmentNo: r.read<int?>('installment_no'),
      chequeNumber: r.read<String>('cheque_number'),
      bankName: r.read<String>('bank_name'),
      note: r.read<String>('note'),
      remindBeforeDays: r.read<int>('remind_before_days'),
      attachmentPaths: _readJsonList(r.read<String>('attachment_paths')),
      createdAt: careDateFromStore(r.read<String>('created_at')) ??
          financeDay(DateTime.now()),
    );
  }

  Person _personFromRow(QueryRow row) {
    final r = row;
    return Person(
      id: r.read<String>('id'),
      name: r.read<String>('name'),
      phone: r.read<String>('phone'),
      note: r.read<String>('note'),
      createdAt: careDateFromStore(r.read<String>('created_at')) ??
          financeDay(DateTime.now()),
    );
  }

  DebtEntry _entryFromRow(QueryRow row) {
    final r = row;
    return DebtEntry(
      id: r.read<String>('id'),
      personId: r.read<String>('person_id'),
      direction: DebtDirection.fromKey(r.read<String>('direction')),
      amount: financeReadAmount(r.read<double?>('amount')),
      createdDate: careDateFromStore(r.read<String>('created_date')) ??
          financeDay(DateTime.now()),
      dueDate: careDateFromStore(r.read<String?>('due_date')),
      note: r.read<String>('note'),
      witnessNote: r.read<String>('witness_note'),
      closed: (r.read<int>('closed')) != 0,
    );
  }

  DebtPayment _paymentFromRow(QueryRow row) {
    final r = row;
    return DebtPayment(
      id: r.read<String>('id'),
      entryId: r.read<String>('entry_id'),
      date: careDateFromStore(r.read<String>('date')) ??
          financeDay(DateTime.now()),
      amount: financeReadAmount(r.read<double?>('amount')),
      note: r.read<String>('note'),
    );
  }
}
