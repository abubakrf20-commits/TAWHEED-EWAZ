/// Streak arithmetic for a goal, kept out of the widget and the database so
/// it can be reasoned about (and tested) on its own.
///
/// A "streak" here is consecutive calendar days that carry a *positive* entry,
/// counted backwards from today. Two decisions worth stating, because both are
/// the kind of thing a user notices and disagrees with:
///
///  * A streak survives a day that has not been logged *yet*. If the last
///    positive entry was yesterday, the streak is still live — it reads as 1,
///    not 0. Resetting it at midnight would mean opening the app before
///    logging anything showed a broken streak, when in fact the day is not
///    over. [isActiveToday] tells the UI which of the two it is, so the card
///    can say «پرکسیت از دیروز» instead of implying today is already done.
///  * A zero entry is a break, like a day with no entry at all. Only positive
///    amounts count as activity, and since the streak is a run of active days,
///    a day that recorded nothing ends it. (An earlier draft promised zeros
///    would be neutral; honouring that needs a second day set to tell "logged
///    zero" apart from "never logged", and the distinction buys nothing a
///    user would thank us for — deliberately recording "0 minutes" is a
///    statement that nothing happened that day.)
library;

import 'package:tawheeed/features/goals/presentation/utils/goal_dates.dart';

/// How a streak was measured.
class GoalStreak {
  /// Consecutive active days ending today or yesterday.
  final int current;

  /// Longest run of consecutive active days ever recorded.
  final int best;

  /// Whether today itself carries a positive entry.
  ///
  /// False while the streak is still live only because yesterday ended it, so
  /// the UI must not imply today is done.
  final bool isActiveToday;

  const GoalStreak({
    required this.current,
    required this.best,
    this.isActiveToday = false,
  });

  static const empty = GoalStreak(current: 0, best: 0);

  bool get hasStreak => current > 0;

  @override
  bool operator ==(Object other) =>
      other is GoalStreak &&
      other.current == current &&
      other.best == best &&
      other.isActiveToday == isActiveToday;

  @override
  int get hashCode => Object.hash(current, best, isActiveToday);

  @override
  String toString() =>
      'GoalStreak(current: $current, best: $best, isActiveToday: $isActiveToday)';
}

/// Compute the current and best streak from the goal's active days.
///
/// [activeDays] is the set of `yyyy-MM-dd` keys that carry a positive entry.
/// Unparseable keys are ignored rather than throwing: a corrupt row must not
/// take the whole screen down, and it cannot legitimately extend a streak.
///
/// [today] is injectable so the arithmetic is testable without depending on
/// what day the suite happens to run.
GoalStreak goalStreakFrom(
  Iterable<String> activeDays, {
  required DateTime today,
}) {
  final days = <String>{
    for (final d in activeDays)
      if (goalParseIso(d) != null) d,
  };
  if (days.isEmpty) return GoalStreak.empty;

  // The best streak only needs the sorted keys — it is a run-length scan.
  final sorted = days.toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final prev = goalParseIso(sorted[i - 1])!;
    final cur = goalParseIso(sorted[i])!;
    // Calendar days, not 24-hour spans — see `goalDaysBetween`.
    final gap = goalDaysBetween(prev, cur);
    // `gap` of 1 is consecutive. Anything larger starts a new run; a gap of 0
    // or negative is impossible for distinct sorted keys, but treating it as
    // consecutive would let a duplicate inflate the run.
    if (gap == 1) {
      run++;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }

  // The current streak is the run that reaches today (or yesterday, so an
  // unlogged today does not read as a broken streak).
  final todayKey = goalIsoOf(today);
  final activeToday = days.contains(todayKey);
  var current = 0;
  var cursor = DateTime(today.year, today.month, today.day);
  if (!activeToday) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (days.contains(goalIsoOf(cursor))) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return GoalStreak(
    current: current,
    best: best < current ? current : best,
    isActiveToday: activeToday,
  );
}
