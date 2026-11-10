import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/services/kid_evening_summary.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Loaded state for one child's day. Immutable so a rebuild is a value compare,
/// not a deep walk through lists.
class KidDayState {
  const KidDayState({
    required this.kid,
    required this.settings,
    required this.dayKey,
    required this.now,
    required this.habits,
    required this.logs,
    required this.balance,
    required this.reserved,
    required this.prayerConfig,
    required this.rewards,
    required this.requests,
  });

  final KidRecord kid;
  final KidSettingsRecord settings;
  final String dayKey;
  final DateTime now;
  final List<HabitSpec> habits;
  final List<KidLogRecord> logs;
  final int balance;
  final int reserved;
  final ({Set<KidPrayer> enabled, int starsPerPrayer, bool lateAllowed, double lateFactor, bool requiresApproval}) prayerConfig;
  final List<RewardRecord> rewards;
  final List<RewardRequestRecord> requests;

  /// The day's scheduled habits.
  List<HabitSpec> get scheduled => scheduledHabits(habits, dayKey);

  /// Log rows for one habit today (at most one by the dedupe index).
  KidLogRecord? logForHabit(String habitId) {
    for (final l in logs) {
      if (l.habitId == habitId) return l;
    }
    return null;
  }

  /// Log row for one prayer today.
  KidLogRecord? logForPrayer(KidPrayer prayer) {
    for (final l in logs) {
      if (l.prayerKey == prayer.key) return l;
    }
    return null;
  }

  /// Habits completed today (any status that counts as done).
  int get habitsDone {
    var done = 0;
    for (final h in scheduled) {
      if (_isDone(logForHabit(h.id)?.status)) done++;
    }
    return done;
  }

  /// Prayers completed today.
  int get prayersDone {
    var done = 0;
    for (final p in prayerConfig.enabled) {
      if (_isDone(logForPrayer(p)?.status)) done++;
    }
    return done;
  }

  /// A log counts as done when it is approved or waiting for approval — the
  /// child has marked it either way, which is what the child-facing tile says.
  static bool _isDone(KidLogStatus? status) =>
      status == KidLogStatus.approved || status == KidLogStatus.pending;

  int get prayersScheduled => prayerConfig.enabled.length;

  int get spendable => availableStars(balance: balance, reserved: reserved);
}

/// The home screen's read model: every child with their ring/today numbers.
class KidsHomeState {
  const KidsHomeState({
    required this.children,
    required this.settings,
    required this.now,
    required this.todayTotals,
    required this.pendingApprovals,
    required this.pendingRequests,
  });

  final List<KidRecord> children;
  final KidSettingsRecord settings;
  final DateTime now;

  /// Per-child (habitsDone, habitsScheduled, prayersDone, prayersScheduled).
  final Map<String, (int, int, int, int)> todayTotals;

  /// All children's logs awaiting a parent decision.
  final List<KidLogRecord> pendingApprovals;

  /// All children's reward requests awaiting approval.
  final List<RewardRequestRecord> pendingRequests;

  /// Count shown on the home shortcut.
  int get approvalCount => pendingApprovals.length + pendingRequests.length;

  /// Household summary for the hero: done habits across every child.
  (int done, int total) get householdHabits {
    var done = 0;
    var total = 0;
    for (final t in todayTotals.values) {
      done += t.$1;
      total += t.$2;
    }
    return (done, total);
  }

  (int done, int total) get householdPrayers {
    var done = 0;
    var total = 0;
    for (final t in todayTotals.values) {
      done += t.$3;
      total += t.$4;
    }
    return (done, total);
  }
}

/// Reads the whole kids home in one pass.
///
/// One `FutureProvider` rather than a provider per child: the home screen needs
/// cross-child totals, and a family has a handful of children, so a single
/// read is cheaper than N providers each re-querying the same tables.
final kidsHomeProvider = FutureProvider<KidsHomeState>((ref) async {
  final dao = ref.read(kidsDaoProvider);
  final settings = await dao.settings();
  final children = await dao.kids();
  final now = DateTime.now();
  final dayKey = kidDayKey(now, dayStartMinutes: settings.dayStartMinutes);

  final totals = <String, (int, int, int, int)>{};
  for (final child in children) {
    final habits = scheduledHabits(await dao.habits(child.id), dayKey);
    final logs = await dao.logsForDay(child.id, dayKey);
    final prayers = await dao.prayerConfig(child.id);

    var habitsDone = 0;
    for (final h in habits) {
      final status = logs
          .where((l) => l.habitId == h.id)
          .map((l) => l.status)
          .firstOrNull;
      if (status == KidLogStatus.approved || status == KidLogStatus.pending) {
        habitsDone++;
      }
    }
    var prayersDone = 0;
    for (final p in prayers.enabled) {
      final status = logs
          .where((l) => l.prayerKey == p.key)
          .map((l) => l.status)
          .firstOrNull;
      if (status == KidLogStatus.approved || status == KidLogStatus.pending) {
        prayersDone++;
      }
    }
    totals[child.id] = (habitsDone, habits.length, prayersDone, prayers.enabled.length);
  }

  return KidsHomeState(
    children: children,
    settings: settings,
    now: now,
    todayTotals: totals,
    pendingApprovals: await dao.pendingApprovals(),
    pendingRequests: await dao.pendingRewardRequests(),
  );
});

/// Household streak: consecutive days (ending today) on which at least one
/// child logged something, skipping days when nothing was scheduled at all.
/// Powers the «رشتهٔ روزها» chip on the home hero — a small, cheerful visual
/// built from the pure [activeStreak] logic, with no extra schema or state.
final kidsHouseholdStreakProvider = FutureProvider<int>((ref) async {
  final home = await ref.watch(kidsHomeProvider.future);
  if (home.children.isEmpty) return 0;
  final dao = ref.read(kidsDaoProvider);
  final keys = weekKeysEndingAt(
    kidDayKey(home.now, dayStartMinutes: home.settings.dayStartMinutes),
    days: 30,
  );
  if (keys.isEmpty) return 0;

  final daysWithActivity = <String>{};
  final daysScheduled = <String>{};
  for (final child in home.children) {
    final habits = await dao.habits(child.id);
    final prayers = await dao.prayerConfig(child.id);
    final logs = await dao.logsInRange(child.id, keys.first, keys.last);
    for (final key in keys) {
      if (prayers.enabled.isNotEmpty ||
          habits.any((h) => isHabitScheduled(h, key))) {
        daysScheduled.add(key);
      }
    }
    for (final log in logs) {
      if (log.status == KidLogStatus.approved ||
          log.status == KidLogStatus.pending) {
        daysWithActivity.add(log.dayKey);
      }
    }
  }
  return activeStreak(
    dayKeys: keys,
    daysWithActivity: daysWithActivity,
    daysScheduled: daysScheduled,
  );
});

/// One child's day, for child mode and the setup screens.
final kidDayProvider =
    FutureProvider.family<KidDayState?, String>((ref, kidId) async {
  final dao = ref.read(kidsDaoProvider);
  final settings = await dao.settings();
  final now = DateTime.now();
  final dayKey = kidDayKey(now, dayStartMinutes: settings.dayStartMinutes);

  final kids = await dao.kids(includeArchived: true);
  final kid = kids.where((k) => k.id == kidId).firstOrNull;
  if (kid == null) return null;

  final rewards = await dao.rewardsFor(kidId);
  return KidDayState(
    kid: kid,
    settings: settings,
    dayKey: dayKey,
    now: now,
    habits: await dao.habits(kidId),
    logs: await dao.logsForDay(kidId, dayKey),
    balance: await dao.balance(kidId),
    reserved: await dao.reserved(kidId),
    prayerConfig: await dao.prayerConfig(kidId),
    rewards: rewards,
    requests: await dao.rewardRequests(kidId),
  );
});

/// One child's habit definitions.
///
/// A log row stores only its `habit_id`, so any screen that lists logs — the
/// approval queue above all — has to resolve the id to the habit's title. This
/// is the one place that read lives.
final kidHabitsProvider = FutureProvider.family<List<HabitSpec>, String>(
  (ref, kidId) => ref.read(kidsDaoProvider).habits(kidId),
);

/// The kids tool's settings row (editable from the tool's own settings sheet).
final kidSettingsProvider = FutureProvider<KidSettingsRecord>(
  (ref) => ref.read(kidsDaoProvider).settings(),
);

/// Weekly summary for one child, built from the pure aggregator.
/// «هفت روز» — the report screen's default window.
final kidWeeklyProvider =
    FutureProvider.family<WeeklySummary?, String>((ref, kidId) async {
  final dao = ref.read(kidsDaoProvider);
  final settings = await dao.settings();
  final now = DateTime.now();
  final today = kidDayKey(now, dayStartMinutes: settings.dayStartMinutes);
  return kidSummaryForDays(
    dao: dao,
    kidId: kidId,
    days: 7,
    today: today,
  );
});

/// «سی روز» — the monthly variant. Same roll-up, longer window: the chart
/// becomes a daily strip and the per-habit bars compare a month of scheduled
/// days, which is what a parent reads when the weekly numbers were flat.
final kidMonthlyProvider =
    FutureProvider.family<WeeklySummary?, String>((ref, kidId) async {
  final dao = ref.read(kidsDaoProvider);
  final settings = await dao.settings();
  final now = DateTime.now();
  final today = kidDayKey(now, dayStartMinutes: settings.dayStartMinutes);
  return kidSummaryForDays(
    dao: dao,
    kidId: kidId,
    days: 30,
    today: today,
  );
});

/// The roll-up for the [days] ending at [today] (inclusive).
///
/// Exposed so a test can pin the window instead of reading the clock.
Future<WeeklySummary?> kidSummaryForDays({
  required KidsDao dao,
  required String kidId,
  required int days,
  required String today,
}) async {
  final weekKeys = weekKeysEndingAt(today, days: days);
  if (weekKeys.isEmpty) return null;

  final habits = await dao.habits(kidId);
  final logs = await dao.logsInRange(kidId, weekKeys.first, weekKeys.last);
  final prayers = await dao.prayerConfig(kidId);

  final doneHabitDays = <String>{};
  final scheduledHabitDays = <String>{};
  final activeDays = <String>{};
  var prayersDone = 0;
  var prayersScheduled = 0;

  for (final key in weekKeys) {
    for (final h in habits) {
      if (!isHabitScheduled(h, key)) continue;
      scheduledHabitDays.add('${h.id}|$key');
    }
    if (prayers.enabled.isNotEmpty) {
      prayersScheduled += prayers.enabled.length;
    }
  }

  for (final log in logs) {
    if (log.status != KidLogStatus.approved && log.status != KidLogStatus.pending) {
      continue;
    }
    activeDays.add(log.dayKey);
    if (log.habitId != null) doneHabitDays.add('${log.habitId}|${log.dayKey}');
    if (log.prayerKey != null) prayersDone++;
  }

  final summary = buildWeeklySummary(
    dayKeys: weekKeys,
    habits: habits,
    doneHabitDays: doneHabitDays,
    scheduledHabitDays: scheduledHabitDays,
    prayersDone: prayersDone,
    prayersScheduled: prayersScheduled,
    starsEarned: await dao.starsEarnedBetween(
      kidId,
      weekKeys.first,
      weekKeys.last,
    ),
    activeDayKeys: activeDays,
  );
  return summary;
}

/// The evening nudge's scheduler, overridable in tests.
final kidEveningSummaryServiceProvider = Provider<KidEveningSummaryService>(
  (ref) => KidEveningSummaryService(),
);

/// Keeps the kids reminder queue in step with the settings row.
///
/// A provider rather than a screen call so it re-runs when the day's counts
/// change (a habit ticked at 19:00 must reach tonight's summary text) and when
/// the settings sheet saves a new hour. Scheduling happens through
/// [SoftNotifier], so failure is logged there and never blanks the page.
final kidEveningSyncProvider = FutureProvider<void>((ref) async {
  final home = await ref.watch(kidsHomeProvider.future);
  final dao = ref.read(kidsDaoProvider);
  final service = ref.read(kidEveningSummaryServiceProvider);
  final now = DateTime.now();
  final today = kidDayKeyOf(now);
  for (final child in home.children) {
    final totals = home.todayTotals[child.id];
    final done = totals == null ? 0 : totals.$1 + totals.$3;
    final scheduled = totals == null ? 0 : totals.$2 + totals.$4;
    final stars = await dao.starsEarnedBetween(child.id, today, today);
    await service.sync(
      settings: home.settings,
      kidName: child.name,
      done: done,
      total: scheduled,
      stars: stars,
      now: now,
    );
  }
});

/// Cached copy of the parent's chosen "kid mode keeps the screen awake" flag.
///
/// Read directly from prefs in the app's existing style rather than through a
/// settings row: it is a device preference, not a record about the child.
const String kidKeepAwakePrefKey = 'personal2.kids.keep_awake';

final kidKeepAwakeProvider = FutureProvider<bool>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kidKeepAwakePrefKey) ?? false;
  } catch (e) {
    // Falling back to «off» is right — a child's session must not be held
    // awake because a preference could not be read — but the fallback is
    // invisible, so the failure has to reach the log or it never happened.
    AppLogger.warning('kid_keep_awake', 'prefs read failed: $e');
    return false;
  }
});

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
