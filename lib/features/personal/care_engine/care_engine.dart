/// Care-engine math — pure Dart, fully unit-tested.
///
/// Everything here is a function of stored rows and "now"; nothing reads the
/// clock itself, so a test can pin any date (and a Jalali month boundary) and
/// get a deterministic answer.
library;

import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Where a seasonal task stands relative to its Jalali window.
enum SeasonalState { notSeasonal, before, inWindow, missed, doneThisYear }

/// The full computed state of one task at a given moment.
class CareStatus {
  const CareStatus({
    required this.task,
    required this.level,
    required this.progress,
    required this.seasonal,
    this.daysRemaining,
    this.kmRemaining,
    this.dueDate,
    this.dueKm,
    this.limitedByDistance = false,
    this.predictedDueDate,
    this.windowStart,
    this.windowEnd,
  });

  final CareTask task;
  final CareStatusLevel level;

  /// 0..∞ — the largest applicable fraction of the interval consumed.
  final double progress;
  final SeasonalState seasonal;
  final int? daysRemaining;
  final int? kmRemaining;
  final DateTime? dueDate;
  final int? dueKm;

  /// True when distance is the dimension that pushes [progress] hardest (the
  /// «limiting» one named in the remaining text).
  final bool limitedByDistance;

  /// Only for distance-driven tasks with enough odometer history.
  final DateTime? predictedDueDate;

  /// The Jalali window's start/end for the cycle this status describes.
  final DateTime? windowStart;
  final DateTime? windowEnd;

  bool get isOverdue => level == CareStatusLevel.overdue;
  bool get needsAttention =>
      level == CareStatusLevel.near ||
      level == CareStatusLevel.urgent ||
      level == CareStatusLevel.overdue;

  /// «۸۰۰ km یا ۲۰ روز» — the limiting dimension first. Latin digits per the
  /// product standard, comma-grouped kilometres.
  String get remainingText {
    if (seasonal == SeasonalState.inWindow) {
      final days = daysRemaining ?? 0;
      return days <= 0 ? 'پنجره بسته می‌شود' : '$days روز تا پایان پنجره';
    }
    if (seasonal == SeasonalState.missed) return 'پنجره گذشته';
    if (seasonal == SeasonalState.before) {
      final days = daysRemaining ?? 0;
      return days <= 0 ? 'پنجره آغاز شده' : '$days روز تا پنجره';
    }
    final km = kmRemaining;
    final days = daysRemaining;
    final kmText =
        km == null ? null : '${NumberFormat.formatPlain(km.toDouble())} km';
    final dayText = days == null ? null : '$days روز';
    if (kmText != null && dayText != null) {
      return limitedByDistance ? '$kmText یا $dayText' : '$dayText یا $kmText';
    }
    return kmText ?? dayText ?? '—';
  }
}

/// Persian label for a status level.
String careLevelLabel(CareStatusLevel level) => switch (level) {
      CareStatusLevel.good => 'خوب',
      CareStatusLevel.near => 'نزدیک',
      CareStatusLevel.urgent => 'فوری',
      CareStatusLevel.overdue => 'دیر',
    };

CareStatusLevel careLevelFor(double progress) {
  if (progress > 1.0) return CareStatusLevel.overdue;
  if (progress >= 0.9) return CareStatusLevel.urgent;
  if (progress >= 0.65) return CareStatusLevel.near;
  return CareStatusLevel.good;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysBetween(DateTime from, DateTime to) =>
    _day(to).difference(_day(from)).inDays;

/// Jalali year/month/day of a Gregorian date.
({int year, int month, int day}) jalaliParts(DateTime date) {
  final j = Jalali.fromDateTime(date);
  return (year: j.year, month: j.month, day: j.day);
}

DateTime _fromJalali(int year, int month, int day) {
  final j = Jalali(year, month, day.clamp(1, 31));
  return DateTime(j.toDateTime().year, j.toDateTime().month, j.toDateTime().day);
}

int jalaliMonthLength(int year, int month) => Jalali(year, month).monthLength;

/// The start/end of [window] in the Jalali year of [date].
({DateTime start, DateTime end}) careWindowDates(
    CareWindow window, DateTime date) {
  final year = jalaliParts(date).year;
  final start = _fromJalali(
      year, window.startMonth, window.startDay);
  final end = _fromJalali(
      year, window.endMonth, window.endDay);
  // A window that wraps the new year (e.g. 12/20 → 1/10) ends next year.
  if (!end.isAfter(start)) {
    final next = _fromJalali(
        year + 1, window.endMonth, window.endDay);
    return (start: start, end: next);
  }
  return (start: start, end: end);
}

bool _isInside(DateTime date, DateTime start, DateTime end) {
  final d = _day(date);
  return !d.isBefore(start) && !d.isAfter(end);
}

/// Status of [task] at [now].
///
/// * time fraction = elapsed days / interval days (from the last completion,
///   else from `firstDueDate − interval`, else from creation);
/// * distance fraction = (current km − last-done km) / interval km;
/// * combined tasks take the LARGER of the two, so neither dimension can hide
///   behind the other.
CareStatus careStatusOf(
  CareTask task,
  DateTime now, {
  int? currentKm,
  List<OdometerReading> readings = const [],
}) {
  if (task.window != null) {
    return _seasonalStatus(task, now, currentKm);
  }

  double progress = 0;
  int? daysRemaining;
  DateTime? dueDate;
  int? kmRemaining;
  int? dueKm;
  var timeFraction = -1.0;
  var kmFraction = -1.0;

  if (task.scheduleType.usesTime && (task.intervalDays ?? 0) > 0) {
    final interval = task.intervalDays!;
    DateTime start;
    if (task.lastDoneDate != null) {
      start = _day(task.lastDoneDate!);
    } else if (task.firstDueDate != null) {
      start = _day(task.firstDueDate!).subtract(Duration(days: interval));
    } else {
      start = _day(task.createdAt);
    }
    dueDate = start.add(Duration(days: interval));
    final elapsed = _daysBetween(start, now);
    timeFraction = elapsed / interval;
    daysRemaining = _daysBetween(now, dueDate);
  }

  if (task.scheduleType.usesDistance &&
      (task.intervalKm ?? 0) > 0 &&
      currentKm != null) {
    final interval = task.intervalKm!;
    final startKm = task.lastDoneKm ??
        (task.firstDueKm != null ? task.firstDueKm! - interval : currentKm);
    dueKm = startKm + interval;
    kmRemaining = dueKm - currentKm;
    kmFraction = (currentKm - startKm) / interval;
  }

  final limitedByDistance = kmFraction > timeFraction;
  progress = [timeFraction, kmFraction].reduce((a, b) => a > b ? a : b);
  if (progress < 0) progress = 0;
  final level = careLevelFor(progress);

  // Distance-only tasks show a predicted date when the odometer history
  // supports one, so «800 km» is not the only thing the user sees.
  DateTime? predicted;
  if (task.scheduleType.usesDistance && kmRemaining != null) {
    predicted = carePredictedDueDate(
      task,
      now,
      currentKm: currentKm,
      readings: readings,
    );
  }

  return CareStatus(
    task: task,
    level: level,
    progress: progress.toDouble(),
    seasonal: SeasonalState.notSeasonal,
    daysRemaining: daysRemaining,
    kmRemaining: kmRemaining,
    dueDate: dueDate,
    dueKm: dueKm,
    limitedByDistance: limitedByDistance,
    predictedDueDate: predicted,
  );
}

CareStatus _seasonalStatus(CareTask task, DateTime now, int? currentKm) {
  final window = task.window!;
  final nowYear = jalaliParts(now).year;
  final thisYear = careWindowDates(
      window, _fromJalali(nowYear, 1, 1));

  final doneDate = task.lastDoneDate == null ? null : _day(task.lastDoneDate!);
  final doneThisYear =
      doneDate != null && _isInside(doneDate, thisYear.start, thisYear.end);

  if (doneThisYear) {
    final next = careWindowDates(window, _fromJalali(nowYear + 1, 1, 1));
    final days = _daysBetween(now, next.start);
    return CareStatus(
      task: task,
      level: careLevelFor(0),
      progress: 0,
      seasonal: SeasonalState.before,
      daysRemaining: days,
      dueDate: next.start,
      windowStart: next.start,
      windowEnd: next.end,
    );
  }

  final inside = _isInside(now, thisYear.start, thisYear.end);
  if (inside) {
    final total = _daysBetween(thisYear.start, thisYear.end) + 1;
    final elapsed = _daysBetween(thisYear.start, now);
    final progress = total <= 0 ? 1.0 : elapsed / total;
    final remaining = _daysBetween(now, thisYear.end);
    final level = careLevelFor(0.65 + progress * 0.35);
    return CareStatus(
      task: task,
      level: level,
      progress: progress,
      seasonal: SeasonalState.inWindow,
      daysRemaining: remaining,
      dueDate: thisYear.start,
      windowStart: thisYear.start,
      windowEnd: thisYear.end,
    );
  }

  if (now.isBefore(thisYear.start)) {
    final days = _daysBetween(now, thisYear.start);
    final near = days <= task.remindBeforeDays;
    return CareStatus(
      task: task,
      level: near ? CareStatusLevel.near : CareStatusLevel.good,
      progress: near ? 0.7 : 0.0,
      seasonal: SeasonalState.before,
      daysRemaining: days,
      dueDate: thisYear.start,
      windowStart: thisYear.start,
      windowEnd: thisYear.end,
    );
  }

  // Past the window and not done in it.
  return CareStatus(
    task: task,
    level: CareStatusLevel.overdue,
    progress: 1.1,
    seasonal: SeasonalState.missed,
    daysRemaining: _daysBetween(now, thisYear.end),
    dueDate: thisYear.start,
    windowStart: thisYear.start,
    windowEnd: thisYear.end,
  );
}

/// Predicted due date from the average daily km of the last 60 days.
///
/// Returns null unless at least two readings span seven days or more — one
/// reading (or two on the same day) says nothing about pace, and guessing a
/// date would be worse than showing the km remaining alone.
DateTime? carePredictedDueDate(
  CareTask task,
  DateTime now, {
  int? currentKm,
  required List<OdometerReading> readings,
}) {
  // Computed here rather than through `careStatusOf`, which itself asks for a
  // prediction when the task is distance-driven — calling it would recurse.
  if (!task.scheduleType.usesDistance || (task.intervalKm ?? 0) <= 0) {
    return null;
  }
  if (currentKm == null) return null;
  final startKm = task.lastDoneKm ??
      (task.firstDueKm != null ? task.firstDueKm! - task.intervalKm! : currentKm);
  final kmRemaining = startKm + task.intervalKm! - currentKm;
  if (kmRemaining <= 0) return null;

  final cutoff = _day(now).subtract(const Duration(days: 60));
  final recent = readings
      .where((r) => !_day(r.date).isBefore(cutoff))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (recent.length < 2) return null;
  final first = recent.first;
  final last = recent.last;
  final spanDays = _daysBetween(first.date, last.date);
  if (spanDays < 7) return null;
  final kmSpan = last.km - first.km;
  if (kmSpan <= 0) return null;
  final perDay = kmSpan / spanDays;
  if (perDay <= 0) return null;
  final days = (kmRemaining / perDay).ceil();
  return _day(now).add(Duration(days: days));
}

/// Fuel consumption in l/100 km from consecutive FULL-tank logs.
///
/// Standard method: between two full tanks the litres burned are every fill
/// after the first up to and including the second, divided by that distance.
/// Returns null when fewer than two full tanks exist (or the odometer never
/// advances) — the UI hides the stat in that case.
double? careFuelConsumption(List<FuelLog> logs) {
  final full = logs.where((f) => f.fullTank).toList()
    ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));
  if (full.length < 2) return null;
  final all = List<FuelLog>.from(logs)
    ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));

  var totalLiters = 0.0;
  var totalKm = 0;
  for (var i = 1; i < full.length; i++) {
    final from = full[i - 1];
    final to = full[i];
    final distance = to.odometerKm - from.odometerKm;
    if (distance <= 0) continue;
    var liters = 0.0;
    for (final log in all) {
      if (log.odometerKm > from.odometerKm &&
          log.odometerKm <= to.odometerKm) {
        liters += log.liters;
      }
    }
    if (liters <= 0) continue;
    totalLiters += liters;
    totalKm += distance;
  }
  if (totalKm <= 0 || totalLiters <= 0) return null;
  return totalLiters / totalKm * 100;
}

/// Sum of care records + fuel in the Jalali year that contains [now].
double careYearCost(
  List<CareRecord> records,
  List<FuelLog> fuelLogs,
  DateTime now,
) {
  final year = jalaliParts(now).year;
  var sum = 0.0;
  for (final r in records) {
    if (jalaliParts(r.date).year == year) sum += r.cost ?? 0;
  }
  for (final f in fuelLogs) {
    if (jalaliParts(f.date).year == year) sum += f.cost;
  }
  return sum;
}

// ─── Bills ────────────────────────────────────────────────────────────────

/// A bill period: its stable key, its due date, and whether it has been paid.
class BillPeriod {
  const BillPeriod({
    required this.key,
    required this.dueDate,
    required this.paid,
    this.payment,
  });

  final String key;
  final DateTime dueDate;
  final bool paid;
  final BillPayment? payment;

  BillPeriod copyWith({BillPayment? payment}) => BillPeriod(
        key: key,
        dueDate: dueDate,
        paid: payment != null,
        payment: payment ?? this.payment,
      );
}

int _clampDay(int year, int month, int day) =>
    day.clamp(1, jalaliMonthLength(year, month));

/// The period containing [date] (or the next one), keyed by Jalali month.
BillPeriod careBillPeriod(Bill bill, DateTime date) {
  final parts = jalaliParts(date);
  switch (bill.recurrence) {
    case BillRecurrence.monthly:
      final day = _clampDay(parts.year, parts.month, bill.dueDay);
      return BillPeriod(
        key: '${parts.year}-${parts.month.toString().padLeft(2, '0')}',
        dueDate: _fromJalali(parts.year, parts.month, day),
        paid: false,
      );
    case BillRecurrence.bimonthly:
      final anchor = bill.firstDueDate ?? bill.createdAt;
      final anchorParts = jalaliParts(anchor);
      // Months as a linear axis so the covering pair is found arithmetically
      // instead of by walking (a decade-old anchor would otherwise loop).
      final anchorIndex = anchorParts.year * 12 + (anchorParts.month - 1);
      final dateIndex = parts.year * 12 + (parts.month - 1);
      final steps = (dateIndex - anchorIndex) ~/ 2;
      final pairIndex = anchorIndex + steps * 2;
      final year = pairIndex ~/ 12;
      final dueMonth = pairIndex % 12 + 1;
      final dueDay = _clampDay(year, dueMonth, bill.dueDay);
      return BillPeriod(
        key: '$year-${dueMonth.toString().padLeft(2, '0')}/b',
        dueDate: _fromJalali(year, dueMonth, dueDay),
        paid: false,
      );
    case BillRecurrence.custom:
      final anchor = _day(bill.firstDueDate ?? bill.createdAt);
      final days = (bill.customDays ?? 30).clamp(1, 3650);
      final elapsed = _daysBetween(anchor, date);
      final index = elapsed < 0 ? 0 : elapsed ~/ days;
      final due = anchor.add(Duration(days: index * days + bill.dueDay - 1));
      return BillPeriod(
        key: 'd$index',
        dueDate: due,
        paid: false,
      );
  }
}

/// The first unpaid period at or after [date], with its payment attached.
BillPeriod careNextUnpaidBillPeriod(
  Bill bill,
  DateTime date,
  List<BillPayment> payments,
) {
  final byKey = {for (final p in payments) p.periodKey: p};
  var cursor = date;
  for (var guard = 0; guard < 24; guard++) {
    final period = careBillPeriod(bill, cursor);
    final payment = byKey[period.key];
    if (payment == null) return period;
    // Advance to the START of the next period, not merely past this one's due
    // date: once the due day has passed, `careBillPeriod` keeps answering with
    // the same month/pair, so a due-date cursor would spin on the same paid key
    // and the guard would return the paid period as if it were unpaid.
    cursor = _nextBillCursor(bill, cursor, period);
  }
  return careBillPeriod(bill, date);
}

/// The first day of the period after [period] for a [bill] at [cursor].
DateTime _nextBillCursor(Bill bill, DateTime cursor, BillPeriod period) {
  switch (bill.recurrence) {
    case BillRecurrence.monthly:
      final parts = jalaliParts(cursor);
      final nextIndex = parts.year * 12 + parts.month;
      return _fromJalali(nextIndex ~/ 12, nextIndex % 12 + 1, 1);
    case BillRecurrence.bimonthly:
      // The key carries the pair's first month: `1404-03/b` → `1404-05/b`.
      final pair = period.key.split('/b').first.split('-');
      final year = int.tryParse(pair[0]);
      final month = pair.length > 1 ? int.tryParse(pair[1]) : null;
      if (year == null || month == null) {
        return period.dueDate.add(const Duration(days: 1));
      }
      final nextIndex = year * 12 + (month - 1) + 2;
      return _fromJalali(nextIndex ~/ 12, nextIndex % 12 + 1, 1);
    case BillRecurrence.custom:
      final days = (bill.customDays ?? 30).clamp(1, 3650);
      return _day(period.dueDate).add(Duration(days: days));
  }
}

/// A bill period's status band, relative to its due date.
CareStatusLevel careBillLevel(DateTime dueDate, DateTime now) {
  final days = _daysBetween(now, dueDate);
  if (days < 0) return CareStatusLevel.overdue;
  if (days <= 3) return CareStatusLevel.urgent;
  if (days <= 7) return CareStatusLevel.near;
  return CareStatusLevel.good;
}

/// Last [count] paid periods of a bill, oldest first (the consumption bars).
List<BillPayment> careRecentBillPayments(
  Bill bill,
  List<BillPayment> payments, {
  int count = 6,
}) {
  final own = payments.where((p) => p.billId == bill.id).toList()
    ..sort((a, b) => a.paidDate.compareTo(b.paidDate));
  if (own.length <= count) return own;
  return own.sublist(own.length - count);
}

/// Monthly total for a subscription list (yearly items divided by 12).
double careSubscriptionsMonthlyTotal(List<Subscription> subscriptions) {
  var sum = 0.0;
  for (final s in subscriptions) {
    if (!s.active) continue;
    sum += s.monthlyAmount;
  }
  return sum;
}

/// Days until a warranty expires; negative once expired.
int careWarrantyDaysLeft(Warranty warranty, DateTime now) =>
    _daysBetween(now, warranty.expiryDate);

/// Expiry computed from purchase date + months (editable afterwards).
DateTime careWarrantyExpiry(DateTime purchaseDate, int months) {
  final j = Jalali.fromDateTime(purchaseDate);
  final total = j.month + months;
  final year = j.year + (total - 1) ~/ 12;
  final month = (total - 1) % 12 + 1;
  final day = j.day.clamp(1, jalaliMonthLength(year, month));
  return _fromJalali(year, month, day);
}

// ─── Due items (reminders / future UI) ────────────────────────────────────

/// One upcoming thing a reminder can announce.
class CareDueItem {
  const CareDueItem({
    required this.assetId,
    required this.kind,
    required this.title,
    required this.dueDate,
    required this.remindDate,
    required this.category,
    required this.level,
    required this.payload,
    this.taskId,
    this.amount,
  });

  final String assetId;
  final CareAssetKind kind;
  final String title;
  final String? taskId;
  final DateTime dueDate;
  /// The day the reminder should be shown (due date minus the lead time).
  final DateTime remindDate;
  /// `service | bills | warranty | subscriptions` — what the per-category
  /// reminder switches key on.
  final String category;
  final CareStatusLevel level;
  final String payload;
  final double? amount;
}

/// The pure provider interface the spec asks for. No UI consumes it in this
/// stage; the reminder scheduler and later stages do.
abstract class DueItemsProvider {
  List<CareDueItem> upcoming({
    required CareSnapshot snapshot,
    required DateTime now,
    Duration horizon = const Duration(days: 30),
  });
}

/// Default implementation across cars and homes.
class CareDueItemsProvider implements DueItemsProvider {
  const CareDueItemsProvider();

  @override
  List<CareDueItem> upcoming({
    required CareSnapshot snapshot,
    required DateTime now,
    Duration horizon = const Duration(days: 30),
  }) {
    final end = _day(now).add(horizon);
    final items = <CareDueItem>[];

    for (final asset in snapshot.assets.where((a) => !a.archived)) {
      final currentKm = snapshot.currentKm(asset.id);
      for (final task in snapshot.tasksOf(asset.id)) {
        if (!task.active) continue;
        final status = careStatusOf(
          task,
          now,
          currentKm: currentKm,
          readings: snapshot.readingsOf(asset.id),
        );
        final due = status.predictedDueDate ?? status.dueDate;
        if (due == null) continue;
        final remindAt = status.seasonal == SeasonalState.inWindow
            ? due
            : due.subtract(Duration(days: task.remindBeforeDays));
        if (remindAt.isAfter(end)) continue;
        items.add(CareDueItem(
          assetId: asset.id,
          kind: asset.kind,
          title: task.title,
          taskId: task.id,
          dueDate: due,
          remindDate: remindAt,
          category: 'service',
          level: status.level,
          payload: 'care_${asset.kind.key}_task_${task.id}',
        ));
      }

      for (final bill in snapshot.billsOf(asset.id).where((b) => b.active)) {
        final period = careNextUnpaidBillPeriod(
          bill,
          now,
          snapshot.paymentsOf(bill.id),
        );
        final remindAt = period.dueDate.subtract(const Duration(days: 3));
        if (period.dueDate.isAfter(end) && remindAt.isAfter(end)) continue;
        items.add(CareDueItem(
          assetId: asset.id,
          kind: asset.kind,
          title: bill.title,
          dueDate: period.dueDate,
          remindDate: remindAt,
          category: 'bills',
          amount: bill.expectedAmount,
          level: careBillLevel(period.dueDate, now),
          payload: 'care_${asset.kind.key}_bill_${bill.id}',
        ));
      }

      for (final w in snapshot.warrantiesOf(asset.id)) {
        final days = careWarrantyDaysLeft(w, now);
        if (days < 0 || days > 60) continue;
        items.add(CareDueItem(
          assetId: asset.id,
          kind: asset.kind,
          title: w.itemName,
          dueDate: w.expiryDate,
          remindDate: w.expiryDate.subtract(
              Duration(days: days > 30 ? 60 : 30)),
          category: 'warranty',
          level: days <= 30 ? CareStatusLevel.urgent : CareStatusLevel.near,
          payload: 'care_${asset.kind.key}_warranty_${w.id}',
        ));
      }
    }

    for (final s in snapshot.subscriptions.where((s) => s.active)) {
      final remindAt = s.nextChargeDate.subtract(const Duration(days: 2));
      if (remindAt.isAfter(end)) continue;
      items.add(CareDueItem(
        assetId: '',
        kind: CareAssetKind.home,
        title: s.name,
        dueDate: s.nextChargeDate,
        remindDate: remindAt,
        category: 'subscriptions',
        amount: s.amount,
        level: careBillLevel(s.nextChargeDate, now),
        payload: 'care_home_subscription_${s.id}',
      ));
    }

    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items;
  }
}

/// Computes the status of one habit at [now].
CareHabitStatus careHabitStatus(
  CareHabit habit,
  List<CareHabitCompletion> completions,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final doneDates = completions
      .where((c) => !c.date.isAfter(today))
      .map((c) => DateTime(c.date.year, c.date.month, c.date.day))
      .toSet()
      .toList();

  final totalDone = completions.fold<int>(0, (s, c) => s + c.count);
  final progress = computeProgress(completions, habit.targetCount);
  final streak = computeStreakDays(doneDates, now);
  final lastDone = doneDates.isNotEmpty
      ? doneDates.reduce((a, b) => a.isAfter(b) ? a : b)
      : null;

  return CareHabitStatus(
    habit: habit,
    totalDone: totalDone,
    streakDays: streak,
    progress: progress,
    lastDoneDate: lastDone,
  );
}

/// Weekly completion counts for the last [weeks] days.
List<int> habitWeeklyCounts(
  List<CareHabitCompletion> completions,
  DateTime now,
) {
  final counts = <int>[];
  final today = DateTime(now.year, now.month, now.day);
  for (int i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final dayStart = DateTime(day.year, day.month, day.day);
    final count = completions.fold<int>(
      0,
      (s, c) {
        final cd = DateTime(c.date.year, c.date.month, c.date.day);
        return s + (cd == dayStart ? c.count : 0);
      },
    );
    counts.add(count);
  }
  return counts;
}

/// Monthly completion counts for the last [months] months.
List<int> habitMonthlyCounts(
  List<CareHabitCompletion> completions,
  DateTime now, {
    int months = 6,
  }) {
  final counts = <int>[];
  for (int i = months - 1; i >= 0; i--) {
    final year = now.year;
    final monthIndex = now.month - i;
    final mYear = monthIndex > 0 ? year : year - 1;
    final mMonth = monthIndex > 0 ? monthIndex : 12 + monthIndex;
    final monthStart = DateTime(mYear, mMonth);
    final monthEnd = DateTime(mYear, mMonth + 1);
    final count = completions.fold<int>(
      0,
      (s, c) {
        final cd = c.date;
        return s + (cd.isAfter(monthStart) && cd.isBefore(monthEnd) ? c.count : 0);
      },
    );
    counts.add(count);
  }
  return counts;
}

/// Total points earned from completions.
int totalPointsFromCompletions(List<CareHabitCompletion> completions) {
  return completions.fold<int>(0, (s, c) => s + c.count);
}
