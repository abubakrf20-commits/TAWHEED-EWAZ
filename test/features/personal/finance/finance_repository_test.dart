import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/finance/finance_engine.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_repository.dart';
import 'package:tawheeed/features/tools/calculator/data/units/local_unit.dart';
import 'package:tawheeed/features/tools/calculator/data/units/local_units_repository.dart';

DateTime day(int y, int m, int d) => DateTime(y, m, d);

Obligation cheque({String id = 'o1'}) => Obligation(
      id: id,
      kind: ObligationKind.cheque,
      direction: ObligationDirection.pay,
      title: 'چک اجاره',
      amount: 5000000,
      dueDate: day(2025, 10, 1),
      chequeNumber: '۱۲۳۴۵',
      bankName: 'ملت',
      counterparty: 'مالک',
      remindBeforeDays: 7,
      attachmentPaths: const ['app_data/attachments/care/a.jpg'],
      createdAt: day(2025, 9, 1),
    );

void main() {
  late AppDatabase db;
  late DriftFinanceRepository repo;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    repo = DriftFinanceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('obligations', () {
    test('round-trips every field', () async {
      await repo.saveObligation(cheque());
      final snapshot = await repo.load();
      final row = snapshot.obligations.single;
      expect(row.title, 'چک اجاره');
      expect(row.amount, 5000000);
      expect(row.dueDate, day(2025, 10, 1));
      expect(row.chequeNumber, '۱۲۳۴۵');
      expect(row.bankName, 'ملت');
      expect(row.remindBeforeDays, 7);
      expect(row.attachmentPaths, ['app_data/attachments/care/a.jpg']);
      expect(row.status, ObligationStatus.pending);
    });

    test('saving the same id updates instead of duplicating', () async {
      await repo.saveObligation(cheque());
      await repo.saveObligation(cheque().copyWith(
        title: 'چک دوم',
        status: ObligationStatus.paid,
        paidDate: day(2025, 10, 2),
        paidAmount: 4900000,
      ));
      final snapshot = await repo.load();
      expect(snapshot.obligations.length, 1);
      expect(snapshot.obligations.single.title, 'چک دوم');
      expect(snapshot.obligations.single.paidAmount, 4900000);
    });

    test('a batch save is atomic and ordered by due date', () async {
      await repo.saveObligations([
        cheque(id: 'b').copyWith(dueDate: day(2025, 11, 1)),
        cheque(id: 'a').copyWith(dueDate: day(2025, 10, 5)),
      ]);
      final snapshot = await repo.load();
      expect(snapshot.obligations.map((o) => o.id).toList(), ['a', 'b']);
    });

    test('delete removes the row', () async {
      await repo.saveObligation(cheque());
      await repo.deleteObligation('o1');
      expect((await repo.load()).obligations, isEmpty);
    });
  });

  group('plans', () {
    InstallmentPlan plan({String id = 'p1'}) => InstallmentPlan(
          id: id,
          title: 'وام مسکن',
          kind: ObligationKind.loan,
          firstDueDate: day(2025, 5, 1),
          count: 3,
          amount: 2000000,
          counterparty: 'بانک',
          totalAmount: 6000000,
          createdAt: day(2025, 4, 1),
        );

    test('round-trips and keeps the display-only total', () async {
      await repo.savePlan(plan());
      final saved = (await repo.load()).plans.single;
      expect(saved.title, 'وام مسکن');
      expect(saved.totalAmount, 6000000);
      expect(saved.intervalMonths, 1);
      expect(saved.plannedTotal, 6000000);
    });

    test('deletePlanUnpaid keeps paid rows', () async {
      await repo.savePlan(plan());
      final rows = financePlanObligations(
        plan(),
        idFactory: (i) => 'r$i',
        createdAt: day(2025, 4, 1),
      );
      await repo.saveObligations([
        rows[0].copyWith(status: ObligationStatus.paid),
        rows[1],
      ]);
      await repo.deletePlanUnpaid('p1');
      final snapshot = await repo.load();
      expect(snapshot.obligations.single.id, 'r0');
      expect(snapshot.obligations.single.isPaid, isTrue);
    });

    test('deleting the plan row leaves its history', () async {
      await repo.savePlan(plan());
      await repo.saveObligation(cheque().copyWith(planId: 'p1'));
      await repo.deletePlan('p1');
      final snapshot = await repo.load();
      expect(snapshot.plans, isEmpty);
      expect(snapshot.obligations.length, 1);
    });
  });

  group('debt ledger', () {
    Person person({String id = 'p1'}) =>
        Person(id: id, name: 'علی', createdAt: day(2025, 1, 1));

    DebtEntry entry({String id = 'e1', String personId = 'p1'}) => DebtEntry(
          id: id,
          personId: personId,
          direction: DebtDirection.owedToMe,
          amount: 1000000,
          createdDate: day(2025, 2, 1),
          dueDate: day(2025, 3, 1),
          note: 'قرض',
          witnessNote: 'حسن',
        );

    test('person, entry and payment round-trip', () async {
      await repo.savePerson(person());
      await repo.saveEntry(entry());
      await repo.savePayment(DebtPayment(
        id: 'pay1',
        entryId: 'e1',
        date: day(2025, 2, 10),
        amount: 400000,
        note: 'قسط اول',
      ));
      final snapshot = await repo.load();
      expect(snapshot.persons.single.name, 'علی');
      expect(snapshot.entries.single.dueDate, day(2025, 3, 1));
      expect(snapshot.entries.single.witnessNote, 'حسن');
      expect(snapshot.payments.single.amount, 400000);
      expect(debtRemaining(snapshot.entries.single, snapshot.payments), 600000);
    });

    test('closing an entry persists', () async {
      await repo.savePerson(person());
      await repo.saveEntry(entry());
      await repo.saveEntry(entry().copyWith(closed: true));
      expect((await repo.load()).entries.single.closed, isTrue);
    });

    test('deleting a person removes their entries and payments', () async {
      await repo.savePerson(person());
      await repo.saveEntry(entry());
      await repo.savePayment(DebtPayment(
        id: 'pay1',
        entryId: 'e1',
        date: day(2025, 2, 10),
        amount: 100,
      ));
      await repo.deletePerson('p1');
      final snapshot = await repo.load();
      expect(snapshot.persons, isEmpty);
      expect(snapshot.entries, isEmpty);
      expect(snapshot.payments, isEmpty);
    });

    test('deleting an entry removes its payments', () async {
      await repo.saveEntry(entry());
      await repo.savePayment(DebtPayment(
        id: 'pay1',
        entryId: 'e1',
        date: day(2025, 2, 10),
        amount: 100,
      ));
      await repo.deleteEntry('e1');
      final snapshot = await repo.load();
      expect(snapshot.entries, isEmpty);
      expect(snapshot.payments, isEmpty);
    });
  });

  group('local unit overrides', () {
    late DriftLocalUnitsRepository units;

    setUp(() {
      units = DriftLocalUnitsRepository(db);
    });

    test('saves, updates and deletes a base value', () async {
      const man = LocalUnit(
        id: 'man_tabriz',
        name: 'من (تبریز)',
        factor: 3100,
        baseUnit: 'گرم',
        isUserEdited: true,
      );
      await units.save(man);
      expect((await units.load()).single.factor, 3100);

      await units.save(man.copyWith(factor: 3200));
      expect((await units.load()).single.factor, 3200);

      await units.delete('man_tabriz');
      expect(await units.load(), isEmpty);
    });

    test('reset clears every row', () async {
      await units.save(const LocalUnit(
        id: 'a',
        name: 'ذرع',
        factor: 1.04,
        baseUnit: 'متر',
        isUserEdited: true,
      ));
      await units.save(const LocalUnit(
        id: 'b',
        name: 'گز',
        factor: 1.0,
        baseUnit: 'متر',
        isUserEdited: true,
      ));
      await units.resetToDefaults();
      expect(await units.load(), isEmpty);
    });
  });
}
