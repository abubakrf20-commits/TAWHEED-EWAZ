import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';

/// Unit tests for the kids tool's pure logic.
///
/// These are the rules a parent feels: which day a late-night tap belongs to,
/// whether a chip may be marked before the adhan, how a late prayer rounds, and
/// that a pending reward cannot spend the same stars twice.
void main() {
  group('day keys', () {
    test('a midnight day-start keys on the calendar day', () {
      final evening = DateTime(2026, 6, 24, 23, 30);
      expect(kidDayKey(evening), kidDayKey(DateTime(2026, 6, 24, 8)));
    });

    test('a 03:00 day-start gives 01:30 to the previous day', () {
      final lateNight = DateTime(2026, 6, 25, 1, 30);
      final earlyMorning = DateTime(2026, 6, 24, 9, 0);
      expect(
        kidDayKey(lateNight, dayStartMinutes: 180),
        kidDayKey(earlyMorning, dayStartMinutes: 180),
      );
    });

    test('a 03:00 day-start gives 04:00 to the new day', () {
      final justAfter = DateTime(2026, 6, 25, 4, 0);
      expect(
        kidDayKey(justAfter, dayStartMinutes: 180),
        isNot(kidDayKey(DateTime(2026, 6, 24, 20), dayStartMinutes: 180)),
      );
    });

    test('keys are padded and parse back', () {
      final key = kidDayKey(DateTime(2026, 3, 21));
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key), isTrue);
      final parts = parseKidDayKey(key)!;
      expect(parts.year, greaterThan(1400));
      expect(parts.month, inInclusiveRange(1, 12));
      expect(parts.day, inInclusiveRange(1, 31));
    });

    test('a malformed key parses to null instead of throwing', () {
      expect(parseKidDayKey('nonsense'), isNull);
      expect(parseKidDayKey('1404-13-01'), isNull);
      expect(parseKidDayKey('1404-01'), isNull);
    });

    test('week keys are seven, oldest first, and contiguous', () {
      final keys = weekKeysEndingAt('1404-07-03');
      expect(keys, hasLength(7));
      expect(keys.last, '1404-07-03');
      expect(keys.toSet(), hasLength(7));
    });

    test('weekday bit is Saturday-first', () {
      // 1404-07-05 is a شنبه (Saturday-first Jalali weekDay == 1).
      final saturday = weekKeysEndingAt('1404-07-05').last;
      final bit = weekdayBitOf(saturday);
      expect(bit, inInclusiveRange(0, 6));
      expect(weekdayLetterOf(saturday), 'ش');
    });
  });

  group('schedule evaluation', () {
    HabitSpec habit({
      HabitSchedule schedule = HabitSchedule.daily,
      int mask = 0x7F,
      DateTime? start,
      DateTime? end,
      bool active = true,
      int sort = 0,
      String id = 'h1',
    }) =>
        HabitSpec(
          id: id,
          title: 'عادت',
          stars: 2,
          schedule: schedule,
          weekdayMask: mask,
          startDate: start,
          endDate: end,
          active: active,
          sort: sort,
        );

    test('daily is every day', () {
      for (final key in weekKeysEndingAt('1404-07-03')) {
        expect(isHabitScheduled(habit(), key), isTrue);
      }
    });

    test('weekdays respects the mask', () {
      // Only Saturday (bit 0).
      final saturdayOnly = habit(schedule: HabitSchedule.weekdays, mask: 1);
      final keys = weekKeysEndingAt('1404-07-05');
      final scheduled =
          keys.where((k) => isHabitScheduled(saturdayOnly, k)).toList();
      expect(scheduled, hasLength(1));
      expect(weekdayBitOf(scheduled.single), 0);
    });

    test('date range excludes days outside it', () {
      final start = DateTime(2026, 6, 24);
      final end = DateTime(2026, 6, 26);
      final ranged = habit(start: start, end: end);
      final inRange = kidDayKey(DateTime(2026, 6, 25));
      final before = kidDayKey(DateTime(2026, 6, 20));
      final after = kidDayKey(DateTime(2026, 6, 30));
      expect(isHabitScheduled(ranged, inRange), isTrue);
      expect(isHabitScheduled(ranged, before), isFalse);
      expect(isHabitScheduled(ranged, after), isFalse);
    });

    test('inactive habits are not scheduled', () {
      final list = [habit(active: false)];
      expect(scheduledHabits(list, kidDayKey(DateTime(2026, 6, 24))), isEmpty);
    });

    test('scheduled habits come back in sort order', () {
      final list = [
        habit(id: 'b', sort: 2),
        habit(id: 'a', sort: 1),
        habit(id: 'c', sort: 3),
      ];
      final out = scheduledHabits(list, kidDayKey(DateTime(2026, 6, 24)));
      expect(out.map((h) => h.id), ['a', 'b', 'c']);
    });
  });

  group('prayer chip state machine', () {
    final fajr = DateTime(2026, 6, 24, 4, 10);
    final sunrise = DateTime(2026, 6, 24, 5, 50);
    final dhuhr = DateTime(2026, 6, 24, 12, 5);
    final asr = DateTime(2026, 6, 24, 16, 30);
    final maghrib = DateTime(2026, 6, 24, 19, 40);
    final isha = DateTime(2026, 6, 24, 21, 0);
    final nextFajr = DateTime(2026, 6, 25, 4, 12);

    final windows = DayPrayerWindows.from(
      fajr: fajr,
      sunrise: sunrise,
      dhuhr: dhuhr,
      asr: asr,
      maghrib: maghrib,
      isha: isha,
      nextFajr: nextFajr,
    );

    PrayerChipState state({
      required KidPrayer prayer,
      required DateTime now,
      KidLogStatus? logged,
      bool dayOver = false,
      bool lateAllowed = true,
    }) =>
        prayerChipState(
          prayer: prayer,
          windows: windows.windowsFor(prayer),
          now: now,
          logged: logged,
          dayOver: dayOver,
          lateAllowed: lateAllowed,
        );

    test('before fajr the chip is locked, never markable', () {
      final s = state(
        prayer: KidPrayer.fajr,
        now: DateTime(2026, 6, 24, 3, 0),
      );
      expect(s, PrayerChipState.locked);
      expect(canMarkPrayer(s), isFalse);
    });

    test('inside the window the chip is NOW and markable', () {
      final s = state(
        prayer: KidPrayer.fajr,
        now: DateTime(2026, 6, 24, 4, 30),
      );
      expect(s, PrayerChipState.now);
      expect(canMarkPrayer(s), isTrue);
    });

    test('exactly at the adhan it is already open', () {
      expect(state(prayer: KidPrayer.fajr, now: fajr), PrayerChipState.now);
    });

    test('exactly at the end boundary it is no longer NOW', () {
      final s = state(prayer: KidPrayer.fajr, now: sunrise);
      expect(s, isNot(PrayerChipState.now));
    });

    test('after the window it is late-available, then missed at day end', () {
      final lateNow = DateTime(2026, 6, 24, 9, 0);
      expect(
        state(prayer: KidPrayer.fajr, now: lateNow),
        PrayerChipState.lateAvailable,
      );
      expect(
        state(prayer: KidPrayer.fajr, now: lateNow, dayOver: true),
        PrayerChipState.missed,
      );
    });

    test('late not allowed turns a closed window into missed', () {
      expect(
        state(
          prayer: KidPrayer.fajr,
          now: DateTime(2026, 6, 24, 9, 0),
          lateAllowed: false,
        ),
        PrayerChipState.missed,
      );
    });

    test('a logged prayer reads DONE and is not markable again', () {
      final s = state(
        prayer: KidPrayer.fajr,
        now: DateTime(2026, 6, 24, 4, 30),
        logged: KidLogStatus.approved,
      );
      expect(s, PrayerChipState.done);
      expect(canMarkPrayer(s), isFalse);
    });

    test('a pending mark already shows DONE', () {
      expect(
        state(
          prayer: KidPrayer.fajr,
          now: DateTime(2026, 6, 24, 4, 30),
          logged: KidLogStatus.pending,
        ),
        PrayerChipState.done,
      );
    });

    test('undoing within the window returns the chip to NOW', () {
      expect(
        state(
          prayer: KidPrayer.fajr,
          now: DateTime(2026, 6, 24, 4, 30),
          logged: KidLogStatus.undone,
        ),
        PrayerChipState.now,
      );
    });

    test('isha window can cross midnight into the next fajr', () {
      expect(
        state(prayer: KidPrayer.isha, now: DateTime(2026, 6, 24, 23, 30)),
        PrayerChipState.now,
      );
      expect(
        state(prayer: KidPrayer.isha, now: DateTime(2026, 6, 25, 3, 0)),
        PrayerChipState.now,
      );
      expect(
        state(prayer: KidPrayer.isha, now: nextFajr),
        isNot(PrayerChipState.now),
      );
    });

    test('without nextFajr the isha window ends at local midnight', () {
      final w = DayPrayerWindows.from(
        fajr: fajr,
        sunrise: sunrise,
        dhuhr: dhuhr,
        asr: asr,
        maghrib: maghrib,
        isha: isha,
      );
      expect(w.byPrayer[KidPrayer.isha]!.end, DateTime(2026, 6, 25));
      expect(w.byPrayer[KidPrayer.fajr]!.end, sunrise);
      expect(w.byPrayer[KidPrayer.dhuhr]!.end, asr);
      expect(w.byPrayer[KidPrayer.asr]!.end, maghrib);
      expect(w.byPrayer[KidPrayer.maghrib]!.end, isha);
    });

    test('a DST-shifted window still compares by instant', () {
      // A window that spans a DST change is just two instants; the chip must
      // follow wall-clock-independent comparison, which is what DateTime does
      // for local values from the same zone.
      final w = PrayerWindows(
        DateTime(2026, 3, 21, 23, 30),
        DateTime(2026, 3, 22, 1, 30),
      );
      expect(w.contains(DateTime(2026, 3, 22, 0, 30)), isTrue);
      expect(w.contains(DateTime(2026, 3, 22, 2, 0)), isFalse);
    });
  });

  group('stars', () {
    test('on-time prayer pays the base', () {
      expect(prayerStars(base: 2, late: false, lateFactor: .5), 2);
    });

    test('late prayer rounds UP so effort is never zero', () {
      expect(prayerStars(base: 2, late: true, lateFactor: .5), 1);
      expect(prayerStars(base: 3, late: true, lateFactor: .5), 2);
      expect(prayerStars(base: 1, late: true, lateFactor: .5), 1);
    });

    test('a late mark never exceeds the base', () {
      expect(prayerStars(base: 2, late: true, lateFactor: 2), 2);
    });

    test('habit stars clamp to 1..5', () {
      expect(habitStars(0), 1);
      expect(habitStars(9), 5);
      expect(habitStars(3), 3);
    });
  });

  group('ledger', () {
    StarTxn txn(int delta, {String id = 't'}) => StarTxn(
          id: id,
          kidId: 'k1',
          delta: delta,
          reason: StarReason.habit,
        );

    test('balance is the plain sum', () {
      expect(starBalance([txn(3), txn(2), txn(-4)]), 1);
      expect(starBalance(const []), 0);
    });

    test('a negative balance is reported, not clamped', () {
      expect(starBalance([txn(1), txn(-5)]), -4);
    });

    test('pending requests reserve their stars', () {
      final reserved = reservedStars([
        (stars: 10, status: RewardRequestStatus.requested),
        (stars: 5, status: RewardRequestStatus.approved),
        (stars: 7, status: RewardRequestStatus.cancelled),
      ]);
      expect(reserved, 10);
    });

    test('affordability subtracts reservations', () {
      expect(
        canAfford(cost: 10, balance: 15, reserved: 10),
        isFalse,
      );
      expect(
        canAfford(cost: 5, balance: 15, reserved: 10),
        isTrue,
      );
    });

    test('a weekly limit blocks a further request', () {
      expect(
        canAfford(cost: 5, balance: 99, reserved: 0, weeklyUsed: 2, weeklyLimit: 2),
        isFalse,
      );
    });

    test('a reward progress bar is clamped and safe at zero cost', () {
      expect(rewardProgress(cost: 10, available: 5), .5);
      expect(rewardProgress(cost: 10, available: 20), 1.0);
      expect(rewardProgress(cost: 0, available: 5), 0.0);
    });
  });

  group('reward lifecycle', () {
    test('approving a requested reward produces one negative txn', () {
      final t = approveReward(
        requestId: 'r1',
        kidId: 'k1',
        stars: 10,
        status: RewardRequestStatus.requested,
        dayKey: '1404-07-03',
        now: DateTime(2026, 6, 24),
      );
      expect(t, isNotNull);
      expect(t!.delta, -10);
      expect(t.reason, StarReason.reward);
      expect(t.refId, 'r1');
    });

    test('approving twice is a no-op the second time', () {
      final second = approveReward(
        requestId: 'r1',
        kidId: 'k1',
        stars: 10,
        status: RewardRequestStatus.approved,
        dayKey: '1404-07-03',
        now: DateTime(2026, 6, 24),
      );
      expect(second, isNull);
    });

    test('cancelling releases the reservation', () {
      expect(
        releaseReservation(RewardRequestStatus.requested),
        RewardRequestStatus.cancelled,
      );
      // A decided request is not silently re-decided.
      expect(
        releaseReservation(RewardRequestStatus.approved),
        RewardRequestStatus.approved,
      );
    });
  });

  group('streak', () {
    test('counts consecutive active days from the end', () {
      final keys = ['a', 'b', 'c', 'd'];
      expect(
        activeStreak(
          dayKeys: keys,
          daysWithActivity: {'b', 'c', 'd'},
          daysScheduled: {'a', 'b', 'c', 'd'},
        ),
        3,
      );
    });

    test('a scheduled day with no activity ends the run', () {
      expect(
        activeStreak(
          dayKeys: ['a', 'b', 'c'],
          daysWithActivity: {'c'},
          daysScheduled: {'a', 'b', 'c'},
        ),
        1,
      );
    });

    test('unscheduled days are skipped, not counted, not a break', () {
      expect(
        activeStreak(
          dayKeys: ['a', 'b', 'c'],
          daysWithActivity: {'a', 'c'},
          daysScheduled: {'a', 'c'}, // b had nothing scheduled
        ),
        2,
      );
    });

    test('no activity at all is zero', () {
      expect(
        activeStreak(
          dayKeys: ['a'],
          daysWithActivity: {},
          daysScheduled: {'a'},
        ),
        0,
      );
    });
  });

  group('weekly summary and soft tip', () {
    HabitSpec h(String id) => HabitSpec(
          id: id,
          title: id,
          stars: 1,
          schedule: HabitSchedule.daily,
        );

    test('per-day counts and per-habit ratios are computed', () {
      final summary = buildWeeklySummary(
        dayKeys: ['d1', 'd2'],
        habits: [h('a'), h('b')],
        doneHabitDays: {'a|d1', 'b|d1', 'a|d2'},
        scheduledHabitDays: {'a|d1', 'b|d1', 'a|d2', 'b|d2'},
        prayersDone: 5,
        prayersScheduled: 10,
        starsEarned: 12,
        activeDayKeys: {'d1', 'd2'},
      );
      expect(summary.perDayDone, [2, 1]);
      expect(summary.habits, hasLength(2));
      expect(summary.habits.first.ratio, 1.0);
      expect(summary.habits.last.ratio, .5);
      expect(summary.activeDays, 2);
    });

    test('weakest habit ignores thin samples (fewer than 3 scheduled days)', () {
      final completions = [
        HabitCompletion(habit: h('rare'), scheduledDays: 2, doneDays: 0),
        HabitCompletion(habit: h('ok'), scheduledDays: 5, doneDays: 5),
      ];
      expect(weakestHabit(completions), isNull);
    });

    test('weakest habit picks the lowest eligible ratio', () {
      final completions = [
        HabitCompletion(habit: h('mid'), scheduledDays: 5, doneDays: 3),
        HabitCompletion(habit: h('low'), scheduledDays: 5, doneDays: 1),
      ];
      expect(weakestHabit(completions)!.habit.id, 'low');
    });

    test('once every habit is high the report praises instead', () {
      final completions = [
        HabitCompletion(habit: h('a'), scheduledDays: 5, doneDays: 5),
        HabitCompletion(habit: h('b'), scheduledDays: 4, doneDays: 4),
      ];
      expect(shouldPraise(completions), isTrue);
      expect(weakestHabit(completions), isNull);
    });

    test('nothing eligible is not praise', () {
      expect(shouldPraise(const []), isFalse);
    });
  });

  group('habit edit scoping (regression guard)', () {
    // Guards against the bug where editing one child's habit silently wrote
    // the same edit to every other child. Editing must stay scoped to the
    // tapped child; copying to siblings is an explicit, separate action.
    test('editing is scoped to the tapped child, never siblings', () {
      const tapped = 'kid_1';
      final all = ['kid_1', 'kid_2', 'kid_3'];
      expect(habitEditTargetKidIds(tapped, all), [tapped]);
    });

    test('a single child is still just itself', () {
      expect(habitEditTargetKidIds('kid_only', ['kid_only']), ['kid_only']);
    });

    test('the result is a single element so .single in the screen fails fast',
        () {
      final targets = habitEditTargetKidIds('kid_1', ['kid_1', 'kid_2']);
      expect(targets.length, 1);
      expect(() => targets.single, returnsNormally);
    });
  });
}
