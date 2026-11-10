/// Pure domain logic for «دفتر عادت کودک».
///
/// Everything here is plain Dart with no Flutter, no database and no clock
/// reads: the day boundary, schedule evaluation, star maths, the prayer chip
/// state machine, streak/weekly aggregation and the soft-tip selection all
/// take their inputs as arguments. That is what makes the brief's test list
/// possible without a device or a widget pump.
///
/// CONTENT RULE: nothing in this file contains Quran text, tajweed rulings or
/// fiqh. The prayer tie-in reads the app's existing schedule and reports
/// states; it makes no claim about the validity of a prayer.
library;

import 'package:shamsi_date/shamsi_date.dart';

/// The five prayers a child can log. `sunrise` is deliberately absent — it has
/// no adhan and nothing to mark.
enum KidPrayer { fajr, dhuhr, asr, maghrib, isha }

extension KidPrayerX on KidPrayer {
  /// Wire key stored in `p2_kid_log.prayer_key`.
  String get key => name;

  String get titleFa => switch (this) {
        KidPrayer.fajr => 'صبح',
        KidPrayer.dhuhr => 'ظهر',
        KidPrayer.asr => 'عصر',
        KidPrayer.maghrib => 'مغرب',
        KidPrayer.isha => 'عشاء',
      };

  /// Position in the day, used for chip ordering and the enabled bitmask.
  int get index5 => KidPrayer.values.indexOf(this);

  static KidPrayer? fromKey(String? key) {
    for (final p in KidPrayer.values) {
      if (p.key == key) return p;
    }
    return null;
  }
}

/// How a habit repeats.
enum HabitSchedule {
  daily('daily'),
  weekdays('weekdays'),
  oneTime('one_time');

  const HabitSchedule(this.wire);
  final String wire;

  static HabitSchedule fromWire(String? value) {
    for (final s in HabitSchedule.values) {
      if (s.wire == value) return s;
    }
    return HabitSchedule.daily;
  }
}

/// `p2_kid_log.status`.
enum KidLogStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  undone('undone');

  const KidLogStatus(this.wire);
  final String wire;

  static KidLogStatus fromWire(String? value) {
    for (final s in KidLogStatus.values) {
      if (s.wire == value) return s;
    }
    return KidLogStatus.approved;
  }
}

/// `p2_kid_star_txn.reason`.
enum StarReason {
  habit('habit'),
  prayer('prayer'),
  reward('reward'),
  adjust('adjust'),
  bonus('bonus');

  const StarReason(this.wire);
  final String wire;

  static StarReason fromWire(String? value) {
    for (final s in StarReason.values) {
      if (s.wire == value) return s;
    }
    return StarReason.adjust;
  }
}

/// `p2_kid_reward_request.status`.
enum RewardRequestStatus {
  requested('requested'),
  approved('approved'),
  rejected('rejected'),
  fulfilled('fulfilled'),
  cancelled('cancelled');

  const RewardRequestStatus(this.wire);
  final String wire;

  static RewardRequestStatus fromWire(String? value) {
    for (final s in RewardRequestStatus.values) {
      if (s.wire == value) return s;
    }
    return RewardRequestStatus.requested;
  }

  /// A pending request holds its stars (reservation).
  bool get reservesStars => this == RewardRequestStatus.requested;
}

/// One habit as the scheduler sees it — a projection of `p2_kid_habit`.
class HabitSpec {
  const HabitSpec({
    required this.id,
    required this.title,
    required this.stars,
    required this.schedule,
    this.weekdayMask = 0x7F,
    this.startDate,
    this.endDate,
    this.requiresApproval = false,
    this.active = true,
    this.sort = 0,
    this.iconKey = 'star',
    this.templateKey,
  });

  final String id;
  final String title;

  /// 1..5
  final int stars;
  final HabitSchedule schedule;

  /// Bit 0 = Saturday … bit 6 = Friday.
  final int weekdayMask;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool requiresApproval;
  final bool active;
  final int sort;
  final String iconKey;
  final String? templateKey;
}

/// ═══════════════════════════════════════════════════════════════════
/// DAY KEYS — the app's "a day starts at [dayStart] minutes past midnight"
/// rule, expressed as a text key so a log row is stable across time zones
/// and DST.
/// ═══════════════════════════════════════════════════════════════════

/// The Jalali day key for [instant] under [dayStartMinutes].
///
/// A day-start of 03:00 means 01:30 belongs to YESTERDAY — that is what makes
/// «وضعیت امروز» still show yesterday's evening for a parent who opens the app
/// after midnight.
///
/// Output format: `1404-07-03` (ASCII digits, zero-padded), matching the
/// project's Latin-digit standard.
String kidDayKey(DateTime instant, {int dayStartMinutes = 0}) {
  final shifted = instant.subtract(Duration(minutes: dayStartMinutes));
  final j = Jalali.fromDateTime(shifted);
  final y = j.year.toString().padLeft(4, '0');
  final m = j.month.toString().padLeft(2, '0');
  final d = j.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses a `yyyy-mm-dd` kids day key back to its Jalali parts.
/// Returns null for a malformed key (a hand-edited backup, say).
({int year, int month, int day})? parseKidDayKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return (year: y, month: m, day: d);
}

/// The local midnight that opens [dayKey] under [dayStartMinutes].
///
/// Used to write `p2_kid_log.date` (the epoch-ms column queries index on) from
/// a key, so the key and the timestamp can never disagree.
DateTime kidDayStart(String dayKey, {int dayStartMinutes = 0}) {
  final parts = parseKidDayKey(dayKey);
  if (parts == null) return DateTime.now();
  final g = Jalali(parts.year, parts.month, parts.day).toDateTime();
  return DateTime(g.year, g.month, g.day).add(Duration(minutes: dayStartMinutes));
}

/// The seven keys of the week containing [dayKey], **oldest first**.
///
/// Uses Jalali `weekDay` (1 = شنبه … 7 = جمعه — Saturday-first), so the list
/// is the Persian week, not the ISO one.
List<String> weekKeysEndingAt(String dayKey, {int days = 7}) {
  final parts = parseKidDayKey(dayKey);
  if (parts == null) return const [];
  final j = Jalali(parts.year, parts.month, parts.day);
  final out = <String>[];
  for (var back = days - 1; back >= 0; back--) {
    final d = j.addDays(-back);
    out.add('${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}');
  }
  return out;
}

/// 0-based weekday of [dayKey] where 0 = Saturday … 6 = Friday — the bit
/// position used by [HabitSpec.weekdayMask].
int weekdayBitOf(String dayKey) {
  final parts = parseKidDayKey(dayKey);
  if (parts == null) return 0;
  // Jalali.weekDay is 1=Sat..7=Fri.
  return Jalali(parts.year, parts.month, parts.day).weekDay - 1;
}

/// Weekday letter used on the weekly chart: ش ی د س چ پ ج.
String weekdayLetterOf(String dayKey) {
  const letters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
  return letters[weekdayBitOf(dayKey).clamp(0, 6)];
}

// ═══════════════════════════════════════════════════════════════════
// SCHEDULE EVALUATION
// ═══════════════════════════════════════════════════════════════════

/// Whether [habit] is scheduled on [dayKey].
///
/// Active is checked separately by the caller when it wants to show an
/// inactive habit's history; [isHabitScheduled] answers only "does the
/// schedule say today".
bool isHabitScheduled(HabitSpec habit, String dayKey) {
  final parts = parseKidDayKey(dayKey);
  if (parts == null) return false;
  final day = Jalali(parts.year, parts.month, parts.day).toDateTime();
  final dayOnly = DateTime(day.year, day.month, day.day);

  final start = habit.startDate;
  if (start != null) {
    final s = DateTime(start.year, start.month, start.day);
    if (dayOnly.isBefore(s)) return false;
  }
  final end = habit.endDate;
  if (end != null) {
    final e = DateTime(end.year, end.month, end.day);
    if (dayOnly.isAfter(e)) return false;
  }

  return switch (habit.schedule) {
    HabitSchedule.daily => true,
    HabitSchedule.weekdays => (habit.weekdayMask & (1 << weekdayBitOf(dayKey))) != 0,
    HabitSchedule.oneTime => true,
  };
}

/// Every habit the child is expected to do on [dayKey], in display order.
List<HabitSpec> scheduledHabits(List<HabitSpec> habits, String dayKey) {
  final out = [
    for (final h in habits)
      if (h.active && isHabitScheduled(h, dayKey)) h,
  ];
  out.sort((a, b) => a.sort.compareTo(b.sort));
  return out;
}

// ═══════════════════════════════════════════════════════════════════
// PRAYER CHIP STATE MACHINE
// ═══════════════════════════════════════════════════════════════════

/// What a prayer chip shows.
///
/// LOCKED    — before that prayer's adhan today.
/// NOW       — inside the window [adhan, end).
/// DONE      — marked (self-report, optionally approved).
/// LATE_AVAILABLE — window closed, day not over, late marking allowed.
/// MISSED    — the day is over and it was never marked.
enum PrayerChipState { locked, now, done, lateAvailable, missed }

/// The prayer windows for one day, as absolute instants.
///
/// Built from the app's own schedule provider — this object never computes
/// prayer times itself. The boundaries are the brief's fallback definitions,
/// which are also what `phaseForSchedule` in `clock_providers.dart` uses:
/// Fajr→sunrise, Dhuhr→Asr, Asr→Maghrib, Maghrib→Isha,
/// Isha→next Fajr (or local midnight, whichever the caller passes).
class PrayerWindows {
  const PrayerWindows(this.adhan, this.end);

  final DateTime adhan;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is PrayerWindows && other.adhan == adhan && other.end == end;

  @override
  int get hashCode => Object.hash(adhan, end);

  /// True while `adhan <= now < end`.
  bool contains(DateTime now) => !now.isBefore(adhan) && now.isBefore(end);
}

/// All five windows for one day.
class DayPrayerWindows {
  const DayPrayerWindows(this.byPrayer);

  final Map<KidPrayer, PrayerWindows> byPrayer;

  PrayerWindows windowsFor(KidPrayer p) =>
      byPrayer[p] ??
      PrayerWindows(
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Builds the five windows from a day's adhan instants.
  ///
  /// [nextFajr] is tomorrow's fajr adhan; when null the Isha window ends at
  /// local midnight, which is the brief's allowed alternative.
  factory DayPrayerWindows.from({
    required DateTime fajr,
    required DateTime sunrise,
    required DateTime dhuhr,
    required DateTime asr,
    required DateTime maghrib,
    required DateTime isha,
    DateTime? nextFajr,
  }) {
    final midnight = DateTime(isha.year, isha.month, isha.day)
        .add(const Duration(days: 1));
    return DayPrayerWindows({
      KidPrayer.fajr: PrayerWindows(fajr, sunrise),
      KidPrayer.dhuhr: PrayerWindows(dhuhr, asr),
      KidPrayer.asr: PrayerWindows(asr, maghrib),
      KidPrayer.maghrib: PrayerWindows(maghrib, isha),
      KidPrayer.isha: PrayerWindows(isha, nextFajr ?? midnight),
    });
  }
}

/// The state of one prayer chip at [now].
///
/// [dayEndedWindows] must be the windows for the day the chip belongs to; the
/// caller decides which day that is (usually the kids day key's day, which can
/// differ from the calendar day when `dayStart > 0`).
///
/// A logged row always wins over the clock: once the child marks a prayer the
/// chip says DONE, including after midnight, because undoing is a deliberate
/// act rather than a timeout.
PrayerChipState prayerChipState({
  required KidPrayer prayer,
  required PrayerWindows windows,
  required DateTime now,
  required KidLogStatus? logged,
  required bool dayOver,
  required bool lateAllowed,
}) {
  // Past-the-window fallback, shared by the "not logged" and "undone" paths.
  PrayerChipState closedOrLate() {
    if (windows.contains(now)) return PrayerChipState.now;
    if (now.isBefore(windows.adhan)) return PrayerChipState.locked;
    if (dayOver) return PrayerChipState.missed;
    return lateAllowed ? PrayerChipState.lateAvailable : PrayerChipState.missed;
  }

  final status = logged;
  if (status == null) return closedOrLate();

  switch (status) {
    case KidLogStatus.approved:
    case KidLogStatus.pending:
      // A pending row is already "done" from the child's point of view; the
      // parent's approval decides stars, not the tile.
      return PrayerChipState.done;
    case KidLogStatus.undone:
    case KidLogStatus.rejected:
      // Undone/rejected frees the chip again, but only within the rules that
      // still apply — a rejected mark does not resurrect a missed day.
      return closedOrLate();
  }
}

/// Whether a prayer may be marked right now (NOW or LATE_AVAILABLE).
bool canMarkPrayer(PrayerChipState state) =>
    state == PrayerChipState.now || state == PrayerChipState.lateAvailable;

/// Stars credited for a prayer log.
///
/// A late mark is worth `factor` of the on-time value, rounded UP so a child
/// who did the thing still gets at least one star (a 2-star prayer at 0.5 → 1).
int prayerStars({
  required int base,
  required bool late,
  required double lateFactor,
}) {
  if (!late) return base;
  final raw = base * lateFactor;
  return raw.ceil().clamp(1, base);
}

/// Stars credited for a habit log (habits have no late concept).
int habitStars(int stars) => stars.clamp(1, 5);

// ═══════════════════════════════════════════════════════════════════
// STAR LEDGER — balance, reservations, streaks
// ═══════════════════════════════════════════════════════════════════

/// A minimal row of the star ledger.
class StarTxn {
  const StarTxn({
    required this.id,
    required this.kidId,
    required this.delta,
    required this.reason,
    this.refId,
    this.dayKey = '',
    this.date,
  });

  final String id;
  final String kidId;

  /// Positive credit, negative redemption/adjustment.
  final int delta;
  final StarReason reason;
  final String? refId;
  final String dayKey;
  final DateTime? date;
}

/// The balance: every ledger delta summed. Never clamped — a negative balance
/// is a data bug worth surfacing, not something to hide behind a floor.
int starBalance(Iterable<StarTxn> txns) {
  var total = 0;
  for (final t in txns) {
    total += t.delta;
  }
  return total;
}

/// Stars held by reward requests that are still pending.
///
/// The brief's "stars are reserved while a request is pending": the parent sees
/// `available = balance - reserved` so two requests cannot both spend the same
/// stars.
int reservedStars(Iterable<({int stars, RewardRequestStatus status})> requests) {
  var total = 0;
  for (final r in requests) {
    if (r.status.reservesStars) total += r.stars;
  }
  return total;
}

/// Spendable stars.
int availableStars({
  required int balance,
  required int reserved,
}) =>
    balance - reserved;

/// Whether [cost] stars can be requested right now.
bool canAfford({
  required int cost,
  required int balance,
  required int reserved,
  int weeklyUsed = 0,
  int? weeklyLimit,
}) {
  if (cost <= 0) return false;
  final limit = weeklyLimit;
  if (limit != null && weeklyUsed >= limit) return false;
  return availableStars(balance: balance, reserved: reserved) >= cost;
}

/// Consecutive days with at least one approved habit or prayer, ending at
/// [dayKeys]'s last entry.
///
/// A day with nothing scheduled counts as neither a win nor a break: a child
/// whose only habit runs on school days should not lose their streak on
/// Friday. It is skipped, not counted.
int activeStreak({
  required List<String> dayKeys,
  required Set<String> daysWithActivity,
  required Set<String> daysScheduled,
}) {
  var streak = 0;
  for (var i = dayKeys.length - 1; i >= 0; i--) {
    final key = dayKeys[i];
    if (daysWithActivity.contains(key)) {
      streak++;
      continue;
    }
    if (!daysScheduled.contains(key)) continue; // nothing to do that day
    break; // a scheduled day with no activity ends the run
  }
  return streak;
}

// ═══════════════════════════════════════════════════════════════════
// WEEKLY AGGREGATES & SOFT TIP
// ═══════════════════════════════════════════════════════════════════

/// One habit's completion over a period.
class HabitCompletion {
  const HabitCompletion({
    required this.habit,
    required this.scheduledDays,
    required this.doneDays,
  });

  final HabitSpec habit;
  final int scheduledDays;
  final int doneDays;

  /// 0..1, or 0 when nothing was scheduled.
  double get ratio => scheduledDays == 0 ? 0 : doneDays / scheduledDays;
}

/// Weekly roll-up for one child.
class WeeklySummary {
  const WeeklySummary({
    required this.dayKeys,
    required this.perDayDone,
    required this.habits,
    required this.prayersDone,
    required this.prayersScheduled,
    required this.starsEarned,
    required this.activeDays,
  });

  final List<String> dayKeys;

  /// Done counts per day key, oldest first — the column chart's input.
  final List<int> perDayDone;
  final List<HabitCompletion> habits;
  final int prayersDone;
  final int prayersScheduled;
  final int starsEarned;

  /// Days with at least one log.
  final int activeDays;
}

/// Builds the weekly roll-up. All inputs are already-computed facts, so this
/// stays pure and the tests can hand in hand-written weeks.
WeeklySummary buildWeeklySummary({
  required List<String> dayKeys,
  required List<HabitSpec> habits,
  required Set<String> doneHabitDays, // 'habitId|dayKey'
  required Set<String> scheduledHabitDays, // 'habitId|dayKey'
  required int prayersDone,
  required int prayersScheduled,
  required int starsEarned,
  required Set<String> activeDayKeys,
}) {
  final perDay = <int>[];
  for (final key in dayKeys) {
    var count = 0;
    for (final h in habits) {
      if (doneHabitDays.contains('${h.id}|$key')) count++;
    }
    perDay.add(count);
  }

  final completions = <HabitCompletion>[];
  for (final h in habits) {
    var scheduled = 0;
    var done = 0;
    for (final key in dayKeys) {
      if (scheduledHabitDays.contains('${h.id}|$key')) scheduled++;
      if (doneHabitDays.contains('${h.id}|$key')) done++;
    }
    if (scheduled == 0) continue;
    completions.add(HabitCompletion(
      habit: h,
      scheduledDays: scheduled,
      doneDays: done,
    ));
  }

  return WeeklySummary(
    dayKeys: dayKeys,
    perDayDone: perDay,
    habits: completions,
    prayersDone: prayersDone,
    prayersScheduled: prayersScheduled,
    starsEarned: starsEarned,
    activeDays: activeDayKeys.length,
  );
}

/// Picks the habit to mention in the report's tip.
///
/// Rules from the brief: the LOWEST completion with at least 3 scheduled days;
/// if every habit is high, return null so the caller prints warm praise
/// instead. Never returns a habit with nothing scheduled — telling a parent
/// "«قرآن» کم انجام شده" when it was never scheduled is the kind of shaming
/// the brief rules out.
HabitCompletion? weakestHabit(
  List<HabitCompletion> habits, {
  int minScheduledDays = 3,
  double highThreshold = .8,
}) {
  HabitCompletion? worst;
  for (final c in habits) {
    if (c.scheduledDays < minScheduledDays) continue;
    if (c.ratio >= highThreshold) continue;
    if (worst == null || c.ratio < worst.ratio) worst = c;
  }
  return worst;
}

/// True when the weekly report should lead with praise.
bool shouldPraise(List<HabitCompletion> habits, {double highThreshold = .8}) {
  final eligible = habits.where((c) => c.scheduledDays >= 3).toList();
  if (eligible.isEmpty) return false;
  return eligible.every((c) => c.ratio >= highThreshold);
}

// ═══════════════════════════════════════════════════════════════════
// REWARD REQUEST LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

/// The ledger effect of approving a reward request.
///
/// Returns the transaction to insert, or null when the request is not in a
/// state that can be approved. Idempotency is enforced twice: here (status
/// must be `requested`) and in the database (a UNIQUE index on
/// `(reason, ref_id)`), so a double tap cannot spend twice.
StarTxn? approveReward({
  required String requestId,
  required String kidId,
  required int stars,
  required RewardRequestStatus status,
  required String dayKey,
  required DateTime now,
}) {
  if (status != RewardRequestStatus.requested) return null;
  return StarTxn(
    id: 'txn_$requestId',
    kidId: kidId,
    delta: -stars.abs(),
    reason: StarReason.reward,
    refId: requestId,
    dayKey: dayKey,
    date: now,
  );
}

/// The status a cancelled or rejected request moves to, and whether the
/// reservation is released (it always is — that is what "reservation"
/// means: stars are held, not spent).
RewardRequestStatus releaseReservation(RewardRequestStatus status) =>
    status == RewardRequestStatus.requested
        ? RewardRequestStatus.cancelled
        : status;

/// Completion ratio 0..1 for a progress bar, guarding a zero cost.
double rewardProgress({required int cost, required int available}) {
  if (cost <= 0) return 0;
  return (available / cost).clamp(0.0, 1.0);
}


/// Children an edit to [kidId]'s habit is written to.
///
/// Editing is always scoped to the child whose habit was tapped: each child
/// keeps their own habit row and completion history. Copying an edit to siblings
/// is a separate, explicit action (the copy-to-all control on the habit row in
/// the habits list), never an implicit side effect of editing. Returning only
/// [kidId] is what makes that guarantee testable and central — the screen reads
/// this list and fails fast if it ever grows beyond one.
List<String> habitEditTargetKidIds(String kidId, List<String> allKidIds) {
  return <String>[kidId];
}
