/// Pure finance rules for «دفتر مالی»: Jalali month arithmetic, installment
/// plans, the 30-day / 6-month totals, the timeline buckets, debt balances and
/// the polite reminder text.
///
/// No Flutter, no database and no clock: every function takes `now`, so the
/// tests pin behaviour instead of racing the wall clock.
///
/// **No fiqh, no interest.** Amounts are what the user typed; nothing here
/// derives a rate, a ruling or a penalty.
library;

import 'dart:convert';

import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

import 'package:tawheeed/features/personal/finance/finance_models.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

// ─── dates ──────────────────────────────────────────────────────────────

DateTime financeDay(DateTime d) => DateTime(d.year, d.month, d.day);

int financeDaysBetween(DateTime from, DateTime to) =>
    financeDay(to).difference(financeDay(from)).inDays;

/// Adds [months] Jalali months to [date], keeping the day of the month.
///
/// A Jalali month is 29–31 days, so 31 فروردین + 1 month is 31 اردیبهشت, and
/// in a 31-day month after a 30-day one the day is simply kept. When the target
/// month is SHORTER the day is clamped to that month's last day (31 دی + 1
/// month → 30 بهمن), never rolled into the next month.
DateTime financeAddJalaliMonths(DateTime date, int months) {
  final j = Jalali.fromDateTime(date);
  final zeroBased = (j.year * 12) + (j.month - 1) + months;
  final year = zeroBased ~/ 12;
  final month = (zeroBased % 12) + 1;
  final monthLength = Jalali(year, month).monthLength;
  final day = j.day > monthLength ? monthLength : j.day;
  final g = Jalali(year, month, day).toDateTime();
  return DateTime(g.year, g.month, g.day);
}

/// `1404/07/10` → `1404/07/10` (zero-padded Persian-year short form).
String financeJalaliDate(DateTime date) {
  final j = Jalali.fromDateTime(date);
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/'
      '${j.day.toString().padLeft(2, '0')}';
}

/// First day of the Jalali month [date] falls in.
DateTime financeMonthStart(DateTime date) {
  final j = Jalali.fromDateTime(date);
  final g = Jalali(j.year, j.month).toDateTime();
  return DateTime(g.year, g.month, g.day);
}

/// First day of the NEXT Jalali month (an exclusive upper bound).
DateTime financeNextMonthStart(DateTime date) {
  final j = Jalali.fromDateTime(date);
  final next = financeAddJalaliMonths(Jalali(j.year, j.month).toDateTime(), 1);
  return financeMonthStart(next);
}

// ─── installment plans ──────────────────────────────────────────────────

/// The rows a plan generates, in order: due date, installment number, and the
/// plan's own amount. Ids come from [idFactory] so a test can pin them.
List<Obligation> financePlanObligations(
  InstallmentPlan plan, {
  required String Function(int index) idFactory,
  DateTime? createdAt,
}) {
  final created = createdAt ?? financeDay(DateTime.now());
  final step = plan.intervalMonths < 1 ? 1 : plan.intervalMonths;
  final rows = <Obligation>[];
  for (var i = 0; i < plan.count; i++) {
    rows.add(Obligation(
      id: idFactory(i),
      kind: plan.kind,
      direction: ObligationDirection.pay,
      title: plan.title,
      counterparty: plan.counterparty,
      amount: plan.amount,
      dueDate: financeAddJalaliMonths(plan.firstDueDate, i * step),
      planId: plan.id,
      installmentNo: i + 1,
      remindBeforeDays: plan.kind.defaultRemindBeforeDays,
      createdAt: created,
    ));
  }
  return rows;
}

/// How many of a plan's rows are already settled — the plan card's «۳ از ۱۲».
int financePlanPaidCount(FinanceSnapshot snapshot, String planId) =>
    snapshot.obligationsOfPlan(planId).where((o) => o.isPaid).length;

// ─── totals ─────────────────────────────────────────────────────────────

/// Obligations that count toward a total: unsettled, not cancelled.
Iterable<Obligation> financeActive(
  FinanceSnapshot snapshot, {
  ObligationDirection? direction,
}) =>
    snapshot.obligations.where((o) =>
        o.status.isActive &&
        (direction == null || o.direction == direction));

/// Sum of what must be PAID in the next [days] days (day 0 = today).
///
/// Rows already past their date are included: an overdue cheque is still owed
/// today. They are also reported separately by [financeOverdueTotal], so the
/// hero can say «۳ مورد عقبافتاده» without double-counting in the bar.
double financePayableWithin(
  FinanceSnapshot snapshot,
  DateTime now, {
  int days = 30,
  ObligationDirection direction = ObligationDirection.pay,
}) {
  final end = financeDay(now).add(Duration(days: days));
  var total = 0.0;
  for (final o in financeActive(snapshot, direction: direction)) {
    final due = financeDay(o.dueDate);
    if (due.isAfter(end)) continue;
    total += o.amount;
  }
  return total;
}

/// Share of the next-30-days payable per kind, for the hero's segmented bar.
/// Zero-total kinds are omitted so the legend never shows a 0 % row.
Map<ObligationKind, double> financeKindBreakdown(
  FinanceSnapshot snapshot,
  DateTime now, {
  int days = 30,
}) {
  final end = financeDay(now).add(Duration(days: days));
  final sums = <ObligationKind, double>{};
  for (final o in financeActive(
    snapshot,
    direction: ObligationDirection.pay,
  )) {
    if (financeDay(o.dueDate).isAfter(end)) continue;
    sums[o.kind] = (sums[o.kind] ?? 0) + o.amount;
  }
  return sums;
}

/// `true` when anything payable is already past its day.
bool financeHasOverdue(FinanceSnapshot snapshot, DateTime now) =>
    financeActive(snapshot, direction: ObligationDirection.pay)
        .any((o) => financeDay(o.dueDate).isBefore(financeDay(now)));

double financeOverdueTotal(FinanceSnapshot snapshot, DateTime now) {
  final today = financeDay(now);
  var total = 0.0;
  for (final o in financeActive(snapshot, direction: ObligationDirection.pay)) {
    if (financeDay(o.dueDate).isBefore(today)) total += o.amount;
  }
  return total;
}

/// The next [months] Jalali months (the current one first) with the payable
/// total that falls inside each, for the 6-bar preview.
class FinanceMonthTotal {
  const FinanceMonthTotal({
    required this.year,
    required this.month,
    required this.total,
    required this.count,
  });

  final int year;
  final int month;
  final double total;
  final int count;
}

List<FinanceMonthTotal> financeMonthlyTotals(
  FinanceSnapshot snapshot,
  DateTime now, {
  int months = 6,
}) {
  final result = <FinanceMonthTotal>[];
  // Whole calendar months, not «30 days from today» buckets: a month total
  // that started mid-month would disagree with the timeline and with the
  // bar's own label.
  var start = financeMonthStart(now);
  for (var i = 0; i < months; i++) {
    final j = Jalali.fromDateTime(start);
    final next = financeNextMonthStart(start);
    var total = 0.0;
    var count = 0;
    for (final o in financeActive(
      snapshot,
      direction: ObligationDirection.pay,
    )) {
      final due = financeDay(o.dueDate);
      if (due.isBefore(start) || !due.isBefore(next)) {
        continue;
      }
      total += o.amount;
      count++;
    }
    result.add(FinanceMonthTotal(
      year: j.year,
      month: j.month,
      total: total,
      count: count,
    ));
    start = next;
  }
  return result;
}

// ─── timeline ───────────────────────────────────────────────────────────

enum FinanceBucket {
  overdue('عقب‌افتاده'),
  today('امروز'),
  thisWeek('این هفته'),
  nextWeek('هفتهٔ بعد'),
  thisMonth('این ماه'),
  later('بعدی‌ها');

  const FinanceBucket(this.labelFa);

  final String labelFa;
}

/// Which timeline group an obligation belongs to.
///
/// Boundaries are day-based, not week-number based: «این هفته» is the next
/// seven days from today, «هفتهٔ بعد» the seven after that, «این ماه» the rest
/// of the current Jalali month, and everything else is «بعدی‌ها».
FinanceBucket financeBucketFor(DateTime dueDate, DateTime now) {
  final today = financeDay(now);
  final due = financeDay(dueDate);
  if (due.isBefore(today)) return FinanceBucket.overdue;
  final diff = due.difference(today).inDays;
  if (diff == 0) return FinanceBucket.today;
  if (diff <= 7) return FinanceBucket.thisWeek;
  if (diff <= 14) return FinanceBucket.nextWeek;
  if (due.isBefore(financeNextMonthStart(today))) {
    return FinanceBucket.thisMonth;
  }
  return FinanceBucket.later;
}

/// The groups the timeline renders, in the spec's order (overdue first), each
/// already sorted by due date. Empty groups are dropped.
Map<FinanceBucket, List<Obligation>> financeTimeline(
  List<Obligation> obligations,
  DateTime now,
) {
  final grouped = <FinanceBucket, List<Obligation>>{};
  for (final o in obligations) {
    if (!o.status.isActive) continue;
    grouped.putIfAbsent(financeBucketFor(o.dueDate, now), () => []).add(o);
  }
  for (final list in grouped.values) {
    list.sort((a, b) {
      final byDate = a.dueDate.compareTo(b.dueDate);
      if (byDate != 0) return byDate;
      return a.title.compareTo(b.title);
    });
  }
  return {
    for (final b in FinanceBucket.values)
      if (grouped[b] case final list?) b: list,
  };
}

/// Positive = days left, negative = days late, 0 = today.
int financeDaysUntil(DateTime dueDate, DateTime now) =>
    financeDay(dueDate).difference(financeDay(now)).inDays;

// ─── debt ledger ────────────────────────────────────────────────────────

double debtPaymentsTotal(List<DebtPayment> payments) {
  var sum = 0.0;
  for (final p in payments) {
    sum += p.amount;
  }
  return sum;
}

/// What is still open on [entry]: the amount minus every recorded payment.
/// Never negative — an overpayment leaves 0, not a credit line.
double debtRemaining(DebtEntry entry, List<DebtPayment> payments) {
  final remaining = entry.amount - debtPaymentsTotal(payments);
  return remaining < 0 ? 0 : remaining;
}

/// Settled when the payments cover the amount. The stored `closed` flag only
/// carries a manual close, so `closed || remaining == 0` is the UI's answer.
bool debtIsSettled(DebtEntry entry, List<DebtPayment> payments) =>
    entry.closed || debtRemaining(entry, payments) <= 0;

/// Net position for one person: what they owe me minus what I owe them.
/// Settled entries drop out, so a fully paid relationship reads 0.
double debtPersonNet(FinanceSnapshot snapshot, String personId) {
  var net = 0.0;
  for (final e in snapshot.entriesOfPerson(personId)) {
    final payments = snapshot.paymentsOf(e.id);
    if (debtIsSettled(e, payments)) continue;
    final remaining = debtRemaining(e, payments);
    net += e.direction == DebtDirection.owedToMe ? remaining : -remaining;
  }
  return net;
}

class DebtTotals {
  const DebtTotals({
    required this.owedToMe,
    required this.iOwe,
    required this.openEntries,
  });

  final double owedToMe;
  final double iOwe;
  final int openEntries;

  double get net => owedToMe - iOwe;
}

/// Overall ledger totals, split by direction; settled rows never count.
DebtTotals debtTotals(FinanceSnapshot snapshot) {
  var owedToMe = 0.0;
  var iOwe = 0.0;
  var open = 0;
  for (final e in snapshot.entries) {
    final payments = snapshot.paymentsOf(e.id);
    if (debtIsSettled(e, payments)) continue;
    final remaining = debtRemaining(e, payments);
    if (e.direction == DebtDirection.owedToMe) {
      owedToMe += remaining;
    } else {
      iOwe += remaining;
    }
    open++;
  }
  return DebtTotals(owedToMe: owedToMe, iOwe: iOwe, openEntries: open);
}

/// Entries with a due date already behind today and money still open.
bool debtIsOverdue(
  DebtEntry entry,
  List<DebtPayment> payments,
  DateTime now,
) {
  final due = entry.dueDate;
  if (due == null) return false;
  if (debtIsSettled(entry, payments)) return false;
  return financeDay(due).isBefore(financeDay(now));
}

// ─── polite reminder text ───────────────────────────────────────────────

/// One editable Persian template, loaded from
/// `assets/data/debt_message_templates.json`.
class DebtMessageTemplate {
  const DebtMessageTemplate({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;

  /// Placeholders: `{name}` `{amount}` `{date}` `{me}`.
  final String body;

  static DebtMessageTemplate? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final body = raw['body'];
    if (id is! String || title is! String || body is! String) return null;
    if (id.isEmpty || body.isEmpty) return null;
    return DebtMessageTemplate(id: id, title: title, body: body);
  }
}

/// Fills a template. Unknown placeholders are left untouched so a typo shows
/// up in the preview instead of silently vanishing.
String buildDebtMessage(
  DebtMessageTemplate template, {
  required String personName,
  required String amountText,
  String dateText = '',
  String myName = '',
}) {
  var body = template.body;
  body = body.replaceAll('{name}', personName.trim().isEmpty
      ? 'دوست عزیز'
      : personName.trim());
  body = body.replaceAll('{amount}', amountText);
  body = body.replaceAll('{date}', dateText);
  body = body.replaceAll('{me}', myName.trim());
  return body.trim();
}

/// Parses the bundled templates. Never throws: an unreadable file yields an
/// empty list and the sheet falls back to «بدون قالب».
List<DebtMessageTemplate> parseDebtTemplates(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) return const [];
    final list = decoded['templates'];
    if (list is! List) return const [];
    final out = <DebtMessageTemplate>[];
    for (final raw in list) {
      final parsed = DebtMessageTemplate.tryParse(raw);
      if (parsed != null) out.add(parsed);
    }
    return out;
  } catch (e) {
    AppLogger.warning('DebtMessage', 'template file unreadable: $e');
    return const [];
  }
}

/// Builds a plain-Persian text summary for sharing: the upcoming obligations
/// grouped by timeline bucket, plus the debt ledger's net position.
///
/// Pure (no Flutter, no I/O) so a test can pin it; the UI only hands the result
/// to the system share sheet — the app never sends a message on its own.
String financeSummaryText(
  FinanceSnapshot snapshot,
  DateTime now,
  String unit, {
  String dateText = '',
}) {
  final buffer = StringBuffer();
  buffer.writeln('خلاصهٔ دفتر مالی${dateText.isEmpty ? '' : ' — $dateText'}');
  buffer.writeln('');
  final grouped = financeTimeline(snapshot.obligations, now);
  if (grouped.isEmpty) {
    buffer.writeln('تعهدی در جریان نیست.');
  } else {
    for (final entry in grouped.entries) {
      final payable = entry.value.fold<double>(
        0,
        (sum, o) =>
            sum + (o.direction == ObligationDirection.pay ? o.amount : 0),
      );
      buffer.writeln('• ${entry.key.labelFa}: ${entry.value.length} مورد — '
          '${NumberFormat.formatMoney(payable, unit)}');
    }
  }
  buffer.writeln('');
  final totals = debtTotals(snapshot);
  if (totals.openEntries > 0) {
    buffer.writeln('دَین و طلب:');
    buffer.writeln('طلب من: ${NumberFormat.formatMoney(totals.owedToMe, unit)}');
    buffer.writeln('بدهی من: ${NumberFormat.formatMoney(totals.iOwe, unit)}');
    buffer.writeln('خالص: ${NumberFormat.formatMoney(totals.net, unit)}');
  }
  return buffer.toString().trim();
}
