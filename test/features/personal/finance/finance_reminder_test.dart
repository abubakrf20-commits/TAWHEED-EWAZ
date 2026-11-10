import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/features/personal/finance/finance_reminder_planner.dart';

DateTime jd(int year, int month, int day) {
  final d = Jalali(year, month, day).toDateTime();
  return DateTime(d.year, d.month, d.day);
}

Obligation obl({
  String id = 'o1',
  required DateTime due,
  int remindBefore = 3,
  double amount = 1000000,
  ObligationKind kind = ObligationKind.cheque,
  ObligationStatus status = ObligationStatus.pending,
  ObligationDirection direction = ObligationDirection.pay,
  String title = 'چک اجاره',
}) =>
    Obligation(
      id: id,
      kind: kind,
      direction: direction,
      title: title,
      amount: amount,
      dueDate: due,
      remindBeforeDays: remindBefore,
      status: status,
      createdAt: jd(1404, 1, 1),
    );

void main() {
  const planner = FinanceReminderPlanner();
  final now = jd(1404, 7, 10);
  const settings = FinanceReminderSettings();

  List<FinanceReminderEvent> plan(
    List<Obligation> rows, {
    FinanceReminderSettings s = settings,
    DateTime? at,
  }) =>
      planner.plan(
        snapshot: FinanceSnapshot(obligations: rows),
        settings: s,
        now: at ?? now,
      );

  test('a reminder lands remindBeforeDays before the due date', () {
    final events = plan([obl(due: jd(1404, 7, 20))]);
    // three days before, on the day, and one late nudge the day after
    expect(events.length, 3);
    final first = Jalali.fromDateTime(events.first.at);
    expect((first.month, first.day, events.first.at.hour), (7, 17, 9));
    final due = Jalali.fromDateTime(events[1].at);
    expect((due.month, due.day), (7, 20));
    final late = Jalali.fromDateTime(events.last.at);
    expect((late.month, late.day), (7, 21));
  });

  test('preferred hour is applied', () {
    final events = plan(
      [obl(due: jd(1404, 7, 20))],
      s: const FinanceReminderSettings(hour: 18),
    );
    expect(events.every((e) => e.at.hour == 18), isTrue);
  });

  test('quiet hours push the reminder to the end of the window', () {
    final events = plan(
      [obl(due: jd(1404, 7, 20))],
      s: const FinanceReminderSettings(hour: 23),
    );
    expect(events.every((e) => e.at.hour == 7), isTrue);
  });

  test('the due day itself always has a reminder', () {
    final events = plan([obl(due: jd(1404, 7, 15), remindBefore: 0)]);
    expect(events.any((e) => e.payload == 'finance_obligation_o1'), isTrue);
  });

  test('an overdue row gets exactly one late reminder (the next day)', () {
    final events = plan([obl(due: jd(1404, 7, 9), remindBefore: 0)]);
    // the due-day slot is already past; only today's late nudge remains
    expect(events.length, 1);
    final at = Jalali.fromDateTime(events.single.at);
    expect((at.month, at.day), (7, 10));
    expect(events.single.body.contains('گذشته'), isTrue);
  });

  test('everything on a day is one grouped notification', () {
    final events = plan([
      obl(id: 'a', due: jd(1404, 7, 20), amount: 100),
      obl(id: 'b', due: jd(1404, 7, 20), amount: 200),
    ]);
    expect(events.length, 3); // before-day, due-day, late nudge
    final grouped = events.where((e) => e.isGroup).toList();
    expect(grouped.length, 3);
    expect(grouped.first.payload.startsWith('finance_day_'), isTrue);
    expect(grouped.first.items.length, 2);
  });

  test('single-row payload points at that obligation', () {
    final events = plan([obl(id: 'zz', due: jd(1404, 7, 20))]);
    expect(
      events.map((e) => e.payload).toSet(),
      {'finance_obligation_zz'},
    );
  });

  test('nothing beyond the horizon is scheduled', () {
    final events = plan([obl(due: jd(1404, 9, 20), remindBefore: 0)]);
    expect(events, isEmpty);
  });

  test('paid and cancelled rows are ignored', () {
    expect(
      plan([
        obl(due: jd(1404, 7, 20), status: ObligationStatus.paid),
        obl(due: jd(1404, 7, 21), status: ObligationStatus.cancelled),
      ]),
      isEmpty,
    );
  });

  test('past reminder times are not scheduled', () {
    // due today, before-window three days ago: only the ones in the future.
    final events = plan([
      obl(due: jd(1404, 7, 10)),
    ]);
    expect(events.every((e) => e.at.isAfter(now)), isTrue);
  });

  test('disabled settings produce nothing', () {
    expect(
      plan(
        [obl(due: jd(1404, 7, 20))],
        s: const FinanceReminderSettings(enabled: false),
      ),
      isEmpty,
    );
  });

  test('the amount appears in the body with the currency unit', () {
    final events = plan(
      [obl(due: jd(1404, 7, 20), amount: 2500000, remindBefore: 0)],
    );
    expect(events.first.body.contains('تومان'), isTrue);
    expect(events.first.body.contains('2,500,000'), isTrue);
  });
}
