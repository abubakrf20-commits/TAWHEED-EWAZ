import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/personal/finance/finance_engine.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';

DateTime jd(int year, int month, int day) {
  final d = Jalali(year, month, day).toDateTime();
  return DateTime(d.year, d.month, d.day);
}

Obligation obl({
  String id = 'o1',
  ObligationKind kind = ObligationKind.cheque,
  ObligationDirection direction = ObligationDirection.pay,
  double amount = 1000000,
  required DateTime due,
  ObligationStatus status = ObligationStatus.pending,
  String title = 'چک',
  String counterparty = '',
}) =>
    Obligation(
      id: id,
      kind: kind,
      direction: direction,
      title: title,
      amount: amount,
      dueDate: due,
      status: status,
      counterparty: counterparty,
      createdAt: jd(1404, 1, 1),
    );

void main() {
  group('Jalali month arithmetic', () {
    test('keeps the day of month across a normal month', () {
      expect(financeAddJalaliMonths(jd(1404, 1, 15), 1), jd(1404, 2, 15));
    });

    test('31 اردیبهشت + 1 month keeps 31 (خرداد is 31 days)', () {
      expect(financeAddJalaliMonths(jd(1404, 2, 31), 1), jd(1404, 3, 31));
    });

    test('31 شهریور + 1 month clamps to 30 مهر', () {
      expect(financeAddJalaliMonths(jd(1404, 6, 31), 1), jd(1404, 7, 30));
    });

    test('30 اسفند in a non-leap year + 1 month is 30 فروردین', () {
      expect(financeAddJalaliMonths(jd(1403, 12, 30), 1), jd(1404, 1, 30));
    });

    test('30 اسفند in a leap year + 12 months clamps in the next year', () {
      // 1403 is a leap year; 1404 is not, so اسفند has 29 days.
      expect(financeAddJalaliMonths(jd(1403, 12, 30), 12), jd(1404, 12, 29));
    });

    test('crossing the year boundary', () {
      expect(financeAddJalaliMonths(jd(1404, 12, 5), 3), jd(1405, 3, 5));
    });

    test('a twelve-month plan stays on the same day every year', () {
      var date = jd(1404, 5, 12);
      for (var i = 0; i < 5; i++) {
        date = financeAddJalaliMonths(date, 12);
      }
      expect(Jalali.fromDateTime(date).day, 12);
      expect(Jalali.fromDateTime(date).month, 5);
      expect(Jalali.fromDateTime(date).year, 1409);
    });
  });

  group('plan generation', () {
    InstallmentPlan plan({
      DateTime? first,
      int count = 4,
      int interval = 1,
      double amount = 500000,
    }) =>
        InstallmentPlan(
          id: 'p1',
          title: 'وام',
          kind: ObligationKind.loan,
          firstDueDate: first ?? jd(1404, 1, 31),
          count: count,
          amount: amount,
          intervalMonths: interval,
          createdAt: jd(1404, 1, 1),
        );

    test('creates exactly count rows, numbered from 1', () {
      final rows = financePlanObligations(
        plan(),
        idFactory: (i) => 'r$i',
        createdAt: jd(1404, 1, 1),
      );
      expect(rows.length, 4);
      expect(rows.map((r) => r.installmentNo).toList(), [1, 2, 3, 4]);
      expect(rows.map((r) => r.id).toList(), ['r0', 'r1', 'r2', 'r3']);
    });

    test('due dates step by Jalali months and clamp short months', () {
      final rows = financePlanObligations(
        plan(),
        idFactory: (i) => 'r$i',
        createdAt: jd(1404, 1, 1),
      );
      expect(rows[0].dueDate, jd(1404, 1, 31));
      expect(rows[1].dueDate, jd(1404, 2, 31));
      expect(rows[2].dueDate, jd(1404, 3, 31));
      expect(rows[3].dueDate, jd(1404, 4, 31)); // تیر is a 31-day month
    });

    test('every row pays, carries the plan id and the plan amount', () {
      final rows = financePlanObligations(
        plan(),
        idFactory: (i) => 'r$i',
        createdAt: jd(1404, 1, 1),
      );
      for (final row in rows) {
        expect(row.direction, ObligationDirection.pay);
        expect(row.planId, 'p1');
        expect(row.amount, 500000);
      }
    });

    test('a 2-month interval skips every other month', () {
      final rows = financePlanObligations(
        plan(first: jd(1404, 1, 10), count: 3, interval: 2),
        idFactory: (i) => 'r$i',
        createdAt: jd(1404, 1, 1),
      );
      expect(rows.map((r) => r.dueDate).toList(),
          [jd(1404, 1, 10), jd(1404, 3, 10), jd(1404, 5, 10)]);
    });
  });

  group('30-day totals', () {
    final now = jd(1404, 7, 10);

    FinanceSnapshot snap(List<Obligation> rows) =>
        FinanceSnapshot(obligations: rows);

    test('counts what is due inside the window, including overdue', () {
      final snapshot = snap([
        obl(id: 'a', amount: 100, due: jd(1404, 7, 5)), // overdue
        obl(id: 'b', amount: 200, due: jd(1404, 7, 12)),
        obl(id: 'c', amount: 400, due: jd(1404, 8, 20)), // outside 30 days
      ]);
      expect(financePayableWithin(snapshot, now), 300);
    });

    test('paid and cancelled rows never count', () {
      final snapshot = snap([
        obl(id: 'a', amount: 100, due: jd(1404, 7, 12)),
        obl(
          id: 'b',
          amount: 900,
          due: jd(1404, 7, 12),
          status: ObligationStatus.paid,
        ),
        obl(
          id: 'c',
          amount: 900,
          due: jd(1404, 7, 12),
          status: ObligationStatus.cancelled,
        ),
      ]);
      expect(financePayableWithin(snapshot, now), 100);
    });

    test('postponed rows still count', () {
      final snapshot = snap([
        obl(
          id: 'a',
          amount: 700,
          due: jd(1404, 7, 20),
          status: ObligationStatus.postponed,
        ),
      ]);
      expect(financePayableWithin(snapshot, now), 700);
    });

    test('receivables are separated from payables', () {
      final snapshot = snap([
        obl(id: 'a', amount: 100, due: jd(1404, 7, 12)),
        obl(
          id: 'b',
          amount: 250,
          due: jd(1404, 7, 12),
          direction: ObligationDirection.receive,
        ),
      ]);
      expect(financePayableWithin(snapshot, now), 100);
      expect(
        financePayableWithin(
          snapshot,
          now,
          direction: ObligationDirection.receive,
        ),
        250,
      );
    });

    test('overdue detection and total', () {
      final snapshot = snap([
        obl(id: 'a', amount: 100, due: jd(1404, 7, 9)),
        obl(id: 'b', amount: 200, due: jd(1404, 7, 10)), // today, not overdue
        obl(id: 'c', amount: 300, due: jd(1404, 7, 11)),
      ]);
      expect(financeHasOverdue(snapshot, now), isTrue);
      expect(financeOverdueTotal(snapshot, now), 100);
    });

    test('kind breakdown groups by kind and drops empty kinds', () {
      final snapshot = snap([
        obl(id: 'a', amount: 100, due: jd(1404, 7, 12)),
        obl(id: 'b', amount: 50, due: jd(1404, 7, 13)),
        obl(
            id: 'c',
            kind: ObligationKind.installment,
            amount: 30,
            due: jd(1404, 7, 14)),
      ]);
      final breakdown = financeKindBreakdown(snapshot, now);
      expect(breakdown[ObligationKind.cheque], 150);
      expect(breakdown[ObligationKind.installment], 30);
      expect(breakdown.containsKey(ObligationKind.loan), isFalse);
    });
  });

  group('six-month preview', () {
    final now = jd(1404, 7, 10);

    test('starts from the current Jalali month and has six entries', () {
      final months = financeMonthlyTotals(
        FinanceSnapshot(obligations: [
          obl(id: 'a', amount: 100, due: jd(1404, 7, 20)),
          obl(id: 'b', amount: 200, due: jd(1404, 8, 2)),
          obl(id: 'c', amount: 300, due: jd(1404, 9, 15)),
        ]),
        now,
      );
      expect(months.length, 6);
      expect(months.first.month, 7);
      expect(months.first.total, 100);
      expect(months[1].total, 200);
      expect(months[2].total, 300);
      expect(months[3].total, 0);
    });

    test('counts rows per month', () {
      final months = financeMonthlyTotals(
        FinanceSnapshot(obligations: [
          obl(id: 'a', amount: 100, due: jd(1404, 7, 20)),
          obl(id: 'b', amount: 100, due: jd(1404, 7, 25)),
        ]),
        now,
      );
      expect(months.first.count, 2);
    });
  });

  group('timeline buckets', () {
    final now = jd(1404, 7, 10);

    test('overdue before today', () {
      expect(financeBucketFor(jd(1404, 7, 9), now), FinanceBucket.overdue);
    });

    test('today', () {
      expect(financeBucketFor(jd(1404, 7, 10), now), FinanceBucket.today);
    });

    test('this week is the next seven days', () {
      expect(financeBucketFor(jd(1404, 7, 17), now), FinanceBucket.thisWeek);
    });

    test('next week is days 8 to 14', () {
      expect(financeBucketFor(jd(1404, 7, 18), now), FinanceBucket.nextWeek);
      expect(financeBucketFor(jd(1404, 7, 24), now), FinanceBucket.nextWeek);
    });

    test('the rest of the month is thisMonth', () {
      expect(financeBucketFor(jd(1404, 7, 25), now), FinanceBucket.thisMonth);
    });

    test('next month is later', () {
      expect(financeBucketFor(jd(1404, 8, 2), now), FinanceBucket.later);
    });

    test('timeline groups only active rows, overdue first and sorted', () {
      final grouped = financeTimeline([
        obl(id: 'late', due: jd(1404, 7, 1), amount: 10),
        obl(id: 'soon', due: jd(1404, 7, 11), amount: 10),
        obl(id: 'today', due: jd(1404, 7, 10), amount: 10),
        obl(id: 'paid', due: jd(1404, 7, 12), status: ObligationStatus.paid),
      ], now);
      expect(grouped.keys.toList(),
          [FinanceBucket.overdue, FinanceBucket.today, FinanceBucket.thisWeek]);
      expect(grouped[FinanceBucket.overdue]!.single.id, 'late');
    });

    test('days until is negative when late', () {
      expect(financeDaysUntil(jd(1404, 7, 8), now), -2);
      expect(financeDaysUntil(jd(1404, 7, 14), now), 4);
    });
  });

  group('debt ledger', () {
    Person person(String id) => Person(id: id, name: id, createdAt: jd(1404, 1, 1));

    DebtEntry entry({
      String id = 'e1',
      String personId = 'p1',
      DebtDirection direction = DebtDirection.owedToMe,
      double amount = 1000000,
      DateTime? due,
      bool closed = false,
    }) =>
        DebtEntry(
          id: id,
          personId: personId,
          direction: direction,
          amount: amount,
          createdDate: jd(1404, 1, 1),
          dueDate: due,
          closed: closed,
        );

    DebtPayment payment(String entryId, double amount, {String id = 'x'}) =>
        DebtPayment(
          id: id,
          entryId: entryId,
          date: jd(1404, 2, 1),
          amount: amount,
        );

    test('remaining is amount minus payments', () {
      expect(debtRemaining(entry(), [payment('e1', 400000)]), 600000);
    });

    test('overpayment never yields a negative remainder', () {
      expect(debtRemaining(entry(), [payment('e1', 1500000)]), 0);
    });

    test('settled when payments cover the amount', () {
      expect(debtIsSettled(entry(), [payment('e1', 1000000)]), isTrue);
      expect(debtIsSettled(entry(), [payment('e1', 999999)]), isFalse);
    });

    test('a manual close marks it settled without payments', () {
      expect(debtIsSettled(entry(closed: true), const []), isTrue);
    });

    test('person net nets both directions and skips settled rows', () {
      final snapshot = FinanceSnapshot(
        persons: [person('p1')],
        entries: [
          entry(id: 'a', amount: 1000),
          entry(id: 'b', amount: 400, direction: DebtDirection.iOwe),
          entry(id: 'c', amount: 5000, closed: true),
        ],
      );
      expect(debtPersonNet(snapshot, 'p1'), 600);
    });

    test('partial payments move the net', () {
      final snapshot = FinanceSnapshot(
        persons: [person('p1')],
        entries: [entry(id: 'a', amount: 1000)],
        payments: [payment('a', 300)],
      );
      expect(debtPersonNet(snapshot, 'p1'), 700);
    });

    test('overall totals split by direction', () {
      final snapshot = FinanceSnapshot(
        entries: [
          entry(id: 'a', amount: 1000),
          entry(id: 'b', amount: 400, direction: DebtDirection.iOwe),
        ],
        payments: [payment('a', 250)],
      );
      final totals = debtTotals(snapshot);
      expect(totals.owedToMe, 750);
      expect(totals.iOwe, 400);
      expect(totals.net, 350);
      expect(totals.openEntries, 2);
    });

    test('overdue needs a due date and money still open', () {
      final now = jd(1404, 7, 10);
      expect(debtIsOverdue(entry(due: jd(1404, 7, 1)), const [], now), isTrue);
      expect(debtIsOverdue(entry(due: jd(1404, 7, 20)), const [], now), isFalse);
      expect(debtIsOverdue(entry(), const [], now), isFalse);
      expect(
        debtIsOverdue(
            entry(due: jd(1404, 7, 1)), [payment('e1', 1000000)], now),
        isFalse,
      );
    });
  });

  group('polite reminder text', () {
    const template = DebtMessageTemplate(
      id: 't',
      title: 'مؤدبانه',
      body: 'سلام {name}، مبلغ {amount} تا {date}. — {me}',
    );

    test('fills every placeholder', () {
      final text = buildDebtMessage(
        template,
        personName: 'علی',
        amountText: '۱٬۲۰۰٬۰۰۰ تومان',
        dateText: '۱۴۰۴/۰۷/۱۰',
        myName: 'رضا',
      );
      expect(text, 'سلام علی، مبلغ ۱٬۲۰۰٬۰۰۰ تومان تا ۱۴۰۴/۰۷/۱۰. — رضا');
    });

    test('an empty name degrades to a neutral address', () {
      final text = buildDebtMessage(
        template,
        personName: '   ',
        amountText: '۱۰۰',
      );
      expect(text.contains('دوست عزیز'), isTrue);
    });

    test('an unknown placeholder is left visible, never dropped', () {
      const custom = DebtMessageTemplate(
        id: 'x',
        title: 'x',
        body: '{name} {unknown}',
      );
      expect(buildDebtMessage(custom, personName: 'سارا', amountText: '۱'),
          'سارا {unknown}');
    });

    test('parsing a malformed file yields an empty list, not a throw', () {
      expect(parseDebtTemplates('not json'), isEmpty);
      expect(parseDebtTemplates('{"templates": []}'), isEmpty);
    });

    test('parsing skips entries without a body', () {
      final parsed = parseDebtTemplates(
        '{"templates":[{"id":"a","title":"t","body":"سلام {name}"},'
        '{"id":"b","title":"t"}]}',
      );
      expect(parsed.length, 1);
      expect(parsed.single.id, 'a');
    });
  });
}
