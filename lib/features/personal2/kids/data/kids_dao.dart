import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/personal2/data/personal2_tables.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// A child (or a student's parent-facing sibling concept) as stored.
class KidRecord {
  const KidRecord({
    required this.id,
    required this.name,
    this.birthYear,
    required this.colorKey,
    required this.createdAt,
    required this.archived,
  });

  final String id;
  final String name;
  final int? birthYear;
  final String colorKey;
  final DateTime createdAt;
  final bool archived;

  /// Age in whole years, or null when the birth year is unknown.
  ///
  /// Deliberately derived, never stored: a stored age would be wrong every
  /// birthday until something rewrote it.
  int? ageAt(DateTime now) {
    final y = birthYear;
    if (y == null) return null;
    final age = now.year - y;
    return age < 0 ? null : age;
  }
}

/// A logged habit or prayer for one day.
class KidLogRecord {
  const KidLogRecord({
    required this.id,
    required this.kidId,
    required this.dayKey,
    required this.date,
    this.habitId,
    this.prayerKey,
    required this.status,
    required this.stars,
    required this.late,
    required this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String kidId;
  final String dayKey;
  final DateTime date;
  final String? habitId;
  final String? prayerKey;
  final KidLogStatus status;
  final int stars;
  final bool late;
  final DateTime createdAt;
  final DateTime? decidedAt;

  KidPrayer? get prayer => KidPrayerX.fromKey(prayerKey);
}

/// A reward definition.
class RewardRecord {
  const RewardRecord({
    required this.id,
    this.kidId,
    required this.title,
    required this.iconKey,
    required this.costStars,
    this.weeklyLimit,
    required this.active,
    required this.sort,
    this.templateKey,
  });

  final String id;
  final String? kidId;
  final String title;
  final String iconKey;
  final int costStars;
  final int? weeklyLimit;
  final bool active;
  final int sort;
  final String? templateKey;
}

/// A pending or decided reward request.
class RewardRequestRecord {
  const RewardRequestRecord({
    required this.id,
    required this.kidId,
    required this.rewardId,
    required this.status,
    required this.stars,
    required this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String kidId;
  final String rewardId;
  final RewardRequestStatus status;
  final int stars;
  final DateTime createdAt;
  final DateTime? decidedAt;
}

/// The tool's settings row (single row, id = 'kids').
class KidSettingsRecord {
  const KidSettingsRecord({
    this.dayStartMinutes = 0,
    this.showSiblingComparison = false,
    this.parentPinEnabled = false,
    this.eveningSummaryEnabled = false,
    this.eveningSummaryMinutes = 1200,
    this.approvalsNudgeEnabled = false,
    this.quietStartMinutes = 1320,
    this.quietEndMinutes = 420,
  });

  final int dayStartMinutes;
  final bool showSiblingComparison;
  final bool parentPinEnabled;
  final bool eveningSummaryEnabled;

  /// Minutes after midnight, default 20:00 (1200).
  final int eveningSummaryMinutes;
  final bool approvalsNudgeEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  KidSettingsRecord copyWith({
    int? dayStartMinutes,
    bool? showSiblingComparison,
    bool? parentPinEnabled,
    bool? eveningSummaryEnabled,
    int? eveningSummaryMinutes,
    bool? approvalsNudgeEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) =>
      KidSettingsRecord(
        dayStartMinutes: dayStartMinutes ?? this.dayStartMinutes,
        showSiblingComparison:
            showSiblingComparison ?? this.showSiblingComparison,
        parentPinEnabled: parentPinEnabled ?? this.parentPinEnabled,
        eveningSummaryEnabled:
            eveningSummaryEnabled ?? this.eveningSummaryEnabled,
        eveningSummaryMinutes:
            eveningSummaryMinutes ?? this.eveningSummaryMinutes,
        approvalsNudgeEnabled:
            approvalsNudgeEnabled ?? this.approvalsNudgeEnabled,
        quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
        quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      );
}

/// Raw-SQL access to the kids tables.
///
/// Every method swallow-and-logs, the same contract as [CareDao]: a single
/// broken row must never blank a screen. Writes that can legitimately fail
/// (a duplicate log, an already-approved request) return a result rather than
/// throwing, because those are user-visible outcomes, not crashes.
class KidsDao {
  KidsDao(this.db);

  final AppDatabase db;

  static const String settingsId = 'kids';


  static DateTime? _date(Object? v) {
    final ms = v as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static DateTime _dateRequired(Object? v) =>
      _date(v) ?? DateTime.fromMillisecondsSinceEpoch(0);

  static String _dedupeKey({
    required String kidId,
    required String dayKey,
    String? habitId,
    String? prayerKey,
  }) =>
      '$kidId|$dayKey|${habitId ?? ''}|${prayerKey ?? ''}';

  // ── Children ─────────────────────────────────────────────────────────

  Future<List<KidRecord>> kids({bool includeArchived = false}) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kid} '
        '${includeArchived ? '' : 'WHERE archived = 0 '}'
        'ORDER BY created_at ASC',
      ).get();
      return [
        for (final r in rows)
          KidRecord(
            id: r.read<String>('id'),
            name: r.read<String>('name'),
            birthYear: r.readNullable<int>('birth_year'),
            colorKey: r.read<String>('color_key'),
            createdAt: _dateRequired(r.read<int>('created_at')),
            archived: r.read<int>('archived') == 1,
          ),
      ];
    } catch (e) {
      AppLogger.warning('KidsDao', 'kids read failed: $e');
      return const [];
    }
  }

  Future<bool> upsertKid({
    required String id,
    required String name,
    int? birthYear,
    required String colorKey,
  }) async {
    try {
      final existing = await db.customSelect(
        'SELECT id FROM ${Personal2Tables.kid} WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (existing.isEmpty) {
        await db.customStatement(
          'INSERT INTO ${Personal2Tables.kid} '
          '(id, name, birth_year, color_key, created_at, archived) '
          'VALUES (?, ?, ?, ?, ?, 0)',
          [
            id,
            name,
            birthYear,
            colorKey,
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
      } else {
        await db.customStatement(
          'UPDATE ${Personal2Tables.kid} SET name = ?, birth_year = ?, '
          'color_key = ? WHERE id = ?',
          [
            name,
            birthYear,
            colorKey,
            id,
          ],
        );
      }
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'kid upsert failed: $e');
      return false;
    }
  }

  /// Archives a child and every row they own, in one transaction.
  ///
  /// Archive is the default removal because a child's star history is also the
  /// parent's record of the year. [deleteEverything] is the explicit opt-in.
  Future<bool> archiveKid(String kidId) async {
    try {
      await db.transaction(() async {
        await db.customStatement(
          'UPDATE ${Personal2Tables.kid} SET archived = 1 WHERE id = ?',
          [kidId],
        );
        await db.customStatement(
          'UPDATE ${Personal2Tables.kidHabit} SET active = 0 WHERE kid_id = ?',
          [kidId],
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'kid archive failed: $e');
      return false;
    }
  }

  /// The brief's hard privacy requirement: a per-child «delete everything».
  ///
  /// Deletes only this child's rows plus the reward definitions addressed to
  /// them. Rewards with `kid_id IS NULL` are account-wide shared templates and
  /// stay, so removing one child never empties a sibling's shop.
  Future<bool> deleteEverythingForKid(String kidId) async {
    try {
      await db.transaction(() async {
        for (final table in [
          Personal2Tables.kidLog,
          Personal2Tables.kidStarTxn,
          Personal2Tables.kidRewardRequest,
          Personal2Tables.kidHabit,
          Personal2Tables.kidPrayerConfig,
        ]) {
          await db.customStatement(
            'DELETE FROM $table WHERE kid_id = ?',
            [kidId],
          );
        }
        await db.customStatement(
          'DELETE FROM ${Personal2Tables.kidReward} WHERE kid_id = ?',
          [kidId],
        );
        await db.customStatement(
          'DELETE FROM ${Personal2Tables.kid} WHERE id = ?',
          [kidId],
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'kid delete failed: $e');
      return false;
    }
  }

  // ── Habits ───────────────────────────────────────────────────────────

  Future<List<HabitSpec>> habits(String kidId, {bool onlyActive = false}) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidHabit} WHERE kid_id = ? '
        '${onlyActive ? 'AND active = 1 ' : ''}ORDER BY sort ASC, title ASC',
        variables: [Variable.withString(kidId)],
      ).get();
      return [
        for (final r in rows)
          HabitSpec(
            id: r.read<String>('id'),
            title: r.read<String>('title'),
            stars: r.read<int>('stars'),
            schedule: HabitSchedule.fromWire(r.read<String>('schedule_type')),
            weekdayMask: r.read<int>('weekday_mask'),
            startDate: _date(r.readNullable<int>('start_date')),
            endDate: _date(r.readNullable<int>('end_date')),
            requiresApproval: r.read<int>('requires_approval') == 1,
            active: r.read<int>('active') == 1,
            sort: r.read<int>('sort'),
            iconKey: r.read<String>('icon_key'),
            templateKey: r.readNullable<String>('template_key'),
          ),
      ];
    } catch (e) {
      AppLogger.warning('KidsDao', 'habits read failed: $e');
      return const [];
    }
  }

  Future<bool> saveHabit({
    required String id,
    required String kidId,
    required String title,
    required int stars,
    required HabitSchedule schedule,
    int weekdayMask = 0x7F,
    DateTime? startDate,
    DateTime? endDate,
    bool requiresApproval = false,
    bool active = true,
    int sort = 0,
    String iconKey = 'star',
    String? templateKey,
  }) async {
    try {
      await db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.kidHabit} '
        '(id, kid_id, template_key, title, icon_key, stars, schedule_type, '
        'weekday_mask, start_date, end_date, requires_approval, active, sort) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          kidId,
          templateKey,
          title,
          iconKey,
          stars.clamp(1, 5),
          schedule.wire,
          weekdayMask,
          startDate?.millisecondsSinceEpoch,
          endDate?.millisecondsSinceEpoch,
          requiresApproval ? 1 : 0,
          active ? 1 : 0,
          sort,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'habit save failed: $e');
      return false;
    }
  }

  Future<bool> setHabitActive(String habitId, bool active) async {
    try {
      await db.customStatement(
        'UPDATE ${Personal2Tables.kidHabit} SET active = ? WHERE id = ?',
        [active ? 1 : 0, habitId],
      );
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'habit active failed: $e');
      return false;
    }
  }

  // ── Prayer config ────────────────────────────────────────────────────

  Future<({Set<KidPrayer> enabled, int starsPerPrayer, bool lateAllowed, double lateFactor, bool requiresApproval})>
      prayerConfig(String kidId) async {
    const fallback = (
      enabled: {KidPrayer.fajr, KidPrayer.dhuhr, KidPrayer.asr, KidPrayer.maghrib, KidPrayer.isha},
      starsPerPrayer: 2,
      lateAllowed: true,
      lateFactor: .5,
      requiresApproval: false,
    );
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidPrayerConfig} WHERE kid_id = ?',
        variables: [Variable.withString(kidId)],
      ).get();
      if (rows.isEmpty) return fallback;
      final r = rows.first;
      final mask = r.read<String>('enabled_prayers');
      final enabled = <KidPrayer>{};
      for (final p in KidPrayer.values) {
        final i = p.index5;
        if (i < mask.length && mask[i] == '1') enabled.add(p);
      }
      return (
        enabled: enabled,
        starsPerPrayer: r.read<int>('stars_per_prayer').clamp(1, 5),
        lateAllowed: r.read<int>('late_allowed') == 1,
        lateFactor: r.read<double>('late_stars_factor').clamp(0.0, 1.0),
        requiresApproval: r.read<int>('requires_approval') == 1,
      );
    } catch (e) {
      AppLogger.warning('KidsDao', 'prayer config read failed: $e');
      return fallback;
    }
  }

  Future<bool> savePrayerConfig({
    required String kidId,
    required Set<KidPrayer> enabled,
    required int starsPerPrayer,
    required bool lateAllowed,
    required double lateFactor,
    required bool requiresApproval,
  }) async {
    try {
      final mask = [
        for (final p in KidPrayer.values) enabled.contains(p) ? '1' : '0',
      ].join();
      await db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.kidPrayerConfig} '
        '(kid_id, enabled_prayers, stars_per_prayer, late_allowed, '
        'late_stars_factor, requires_approval) VALUES (?, ?, ?, ?, ?, ?)',
        [
          kidId,
          mask,
          starsPerPrayer.clamp(1, 5),
          lateAllowed ? 1 : 0,
          lateFactor,
          requiresApproval ? 1 : 0,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'prayer config save failed: $e');
      return false;
    }
  }

  // ── Logs ─────────────────────────────────────────────────────────────

  Future<List<KidLogRecord>> logsForDay(String kidId, String dayKey) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidLog} '
        'WHERE kid_id = ? AND day_key = ? ORDER BY created_at ASC',
        variables: [Variable.withString(kidId), Variable.withString(dayKey)],
      ).get();
      return [for (final r in rows) _log(r)];
    } catch (e) {
      AppLogger.warning('KidsDao', 'logs read failed: $e');
      return const [];
    }
  }

  Future<List<KidLogRecord>> logsInRange(
    String kidId,
    String fromDayKey,
    String toDayKey,
  ) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidLog} '
        'WHERE kid_id = ? AND day_key >= ? AND day_key <= ? '
        'ORDER BY day_key ASC, created_at ASC',
        variables: [Variable.withString(kidId), Variable.withString(fromDayKey), Variable.withString(toDayKey)],
      ).get();
      return [for (final r in rows) _log(r)];
    } catch (e) {
      AppLogger.warning('KidsDao', 'range read failed: $e');
      return const [];
    }
  }

  /// Pending logs awaiting a parent decision, across every child.
  Future<List<KidLogRecord>> pendingApprovals() async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidLog} '
        "WHERE status = 'pending' ORDER BY created_at ASC",
      ).get();
      return [for (final r in rows) _log(r)];
    } catch (e) {
      AppLogger.warning('KidsDao', 'approvals read failed: $e');
      return const [];
    }
  }

  /// Marks a habit or prayer, idempotently.
  ///
  /// Returns the existing row's status when the same thing was already logged
  /// for that day — the UNIQUE `dedupe_key` index is the last line of defence,
  /// but this check gives the UI a friendlier answer than a constraint error.
  Future<({bool ok, bool alreadyLogged, KidLogStatus? status})> markLog({
    required String kidId,
    required String dayKey,
    required DateTime date,
    String? habitId,
    String? prayerKey,
    required int stars,
    required bool late,
    required bool requiresApproval,
  }) async {
    final dedupe = _dedupeKey(
      kidId: kidId,
      dayKey: dayKey,
      habitId: habitId,
      prayerKey: prayerKey,
    );
    try {
      final existing = await db.customSelect(
        'SELECT status FROM ${Personal2Tables.kidLog} WHERE dedupe_key = ?',
        variables: [Variable.withString(dedupe)],
      ).get();
      if (existing.isNotEmpty) {
        return (
          ok: false,
          alreadyLogged: true,
          status: KidLogStatus.fromWire(existing.first.read<String>('status')),
        );
      }
      final status = requiresApproval
          ? KidLogStatus.pending.wire
          : KidLogStatus.approved.wire;
      final id =
          'log_${DateTime.now().microsecondsSinceEpoch}_${dedupe.hashCode.abs()}';
      await db.transaction(() async {
        await db.customStatement(
          'INSERT INTO ${Personal2Tables.kidLog} '
          '(id, kid_id, day_key, date, habit_id, prayer_key, dedupe_key, '
          'status, stars, late, created_at, decided_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            id,
            kidId,
            dayKey,
            date.millisecondsSinceEpoch,
            habitId,
            prayerKey,
            dedupe,
            status,
            stars,
            late ? 1 : 0,
            DateTime.now().millisecondsSinceEpoch,
            requiresApproval
                ? null
                : DateTime.now().millisecondsSinceEpoch,
          ],
        );
        // Stars are credited only when the log is already approved; a pending
        // log credits nothing until the parent decides.
        if (!requiresApproval) {
          await _insertStarTxn(
            kidId: kidId,
            dayKey: dayKey,
            date: date,
            delta: stars,
            reason: (prayerKey != null ? StarReason.prayer : StarReason.habit)
                .wire,
            refId: id,
            note: '',
          );
        }
      });
      return (ok: true, alreadyLogged: false, status: null);
    } catch (e) {
      AppLogger.warning('KidsDao', 'mark failed: $e');
      return (ok: false, alreadyLogged: false, status: null);
    }
  }

  /// Undoes a mark within the undo window. Credits are never negative:
  /// removing the log also removes the ledger row it created, so the balance
  /// is exactly what it was.
  Future<bool> undoLog(String logId) async {
    try {
      await db.transaction(() async {
        final rows = await db.customSelect(
          'SELECT * FROM ${Personal2Tables.kidLog} WHERE id = ?',
          variables: [Variable.withString(logId)],
        ).get();
        if (rows.isEmpty) return;
        final r = rows.first;
        final status = KidLogStatus.fromWire(r.read<String>('status'));
        if (status == KidLogStatus.approved) {
          await db.customStatement(
            'DELETE FROM ${Personal2Tables.kidStarTxn} WHERE ref_id = ?',
            [logId],
          );
        }
        // A pending log has no ledger row; deleting the log releases it.
        await db.customStatement(
          'DELETE FROM ${Personal2Tables.kidLog} WHERE id = ?',
          [logId],
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'undo failed: $e');
      return false;
    }
  }

  /// Approves or rejects a pending log.
  ///
  /// Approval credits the log's stars exactly once: the ledger insert is keyed
  /// on the log id, and the UPDATE is guarded by `status = 'pending'`, so two
  /// taps produce one credit.
  Future<bool> decideLog({
    required String logId,
    required bool approve,
  }) async {
    try {
      return await db.transaction(() async {
        final rows = await db.customSelect(
          'SELECT * FROM ${Personal2Tables.kidLog} WHERE id = ?',
          variables: [Variable.withString(logId)],
        ).get();
        if (rows.isEmpty) return false;
        final r = rows.first;
        if (r.read<String>('status') != KidLogStatus.pending.wire) {
          return false; // already decided; no second credit
        }
        final kidId = r.read<String>('kid_id');
        final dayKey = r.read<String>('day_key');
        final stars = r.read<int>('stars');
        final habitId = r.readNullable<String>('habit_id');
        final prayerKey = r.readNullable<String>('prayer_key');
        final date = _dateRequired(r.read<int>('date'));

        await db.customStatement(
          'UPDATE ${Personal2Tables.kidLog} SET status = ?, decided_at = ? '
          'WHERE id = ? AND status = ?',
          [
            approve
                ? KidLogStatus.approved.wire
                : KidLogStatus.rejected.wire,
            DateTime.now().millisecondsSinceEpoch,
            logId,
            KidLogStatus.pending.wire,
          ],
        );
        if (!approve) return true;
        await _insertStarTxn(
          kidId: kidId,
          dayKey: dayKey,
          date: date,
          delta: stars,
          reason:
              (prayerKey != null ? StarReason.prayer : StarReason.habit).wire,
          refId: logId,
          note: habitId ?? prayerKey ?? '',
        );
        return true;
      });
    } catch (e) {
      AppLogger.warning('KidsDao', 'decide failed: $e');
      return false;
    }
  }

  // ── Star ledger ──────────────────────────────────────────────────────

  Future<List<StarTxn>> starTxns(String kidId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidStarTxn} '
        'WHERE kid_id = ? ORDER BY date ASC, created_at ASC',
        variables: [Variable.withString(kidId)],
      ).get();
      return [
        for (final r in rows)
          StarTxn(
            id: r.read<String>('id'),
            kidId: r.read<String>('kid_id'),
            delta: r.read<int>('delta'),
            reason: StarReason.fromWire(r.read<String>('reason')),
            refId: r.readNullable<String>('ref_id'),
            dayKey: r.read<String>('day_key'),
            date: _date(r.readNullable<int>('date')),
          ),
      ];
    } catch (e) {
      AppLogger.warning('KidsDao', 'ledger read failed: $e');
      return const [];
    }
  }

  /// A parent's manual correction. Requires a note by contract (the UI
  /// enforces it); the ledger stays append-only.
  Future<bool> adjustStars({
    required String kidId,
    required int delta,
    required String note,
    required String dayKey,
  }) async {
    if (delta == 0) return false;
    try {
      await _insertStarTxn(
        kidId: kidId,
        dayKey: dayKey,
        date: DateTime.now(),
        delta: delta,
        reason: StarReason.adjust.wire,
        refId: null,
        note: note,
      );
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'adjust failed: $e');
      return false;
    }
  }

  /// Ledger ids must stay unique even when two credits land in the same tick:
  /// `DateTime.now()` is millisecond-grained on Windows and the insert below is
  /// `OR IGNORE`, so an id collision would silently swallow a star
  /// (`«تأیید همه»` approved two habits and only one was credited).
  static int _txnSeq = 0;

  Future<void> _insertStarTxn({
    required String kidId,
    required String dayKey,
    required DateTime date,
    required int delta,
    required String reason,
    required String? refId,
    required String note,
  }) async {
    final id =
        'txn_${DateTime.now().microsecondsSinceEpoch}_${_txnSeq++}';
    await db.customStatement(
      'INSERT OR IGNORE INTO ${Personal2Tables.kidStarTxn} '
      '(id, kid_id, day_key, date, delta, reason, ref_id, note, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        kidId,
        dayKey,
        date.millisecondsSinceEpoch,
        delta,
        reason,
        refId,
        note,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  // ── Rewards ──────────────────────────────────────────────────────────

  /// Rewards visible to [kidId]: their own plus every account-wide one.
  Future<List<RewardRecord>> rewardsFor(String kidId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidReward} '
        'WHERE active = 1 AND (kid_id IS NULL OR kid_id = ?) '
        'ORDER BY sort ASC, cost_stars ASC',
        variables: [Variable.withString(kidId)],
      ).get();
      return [for (final r in rows) _reward(r)];
    } catch (e) {
      AppLogger.warning('KidsDao', 'rewards read failed: $e');
      return const [];
    }
  }

  Future<bool> saveReward({
    required String id,
    String? kidId,
    required String title,
    required int costStars,
    String iconKey = 'gift',
    int? weeklyLimit,
    int sort = 0,
    String? templateKey,
  }) async {
    if (costStars <= 0) return false;
    try {
      await db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.kidReward} '
        '(id, kid_id, template_key, title, icon_key, cost_stars, '
        'weekly_limit, active, sort) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)',
        [
          id,
          kidId,
          templateKey,
          title,
          iconKey,
          costStars,
          weeklyLimit,
          sort,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'reward save failed: $e');
      return false;
    }
  }

  Future<List<RewardRequestRecord>> rewardRequests(String kidId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidRewardRequest} '
        'WHERE kid_id = ? ORDER BY created_at DESC',
        variables: [Variable.withString(kidId)],
      ).get();
      return [
        for (final r in rows)
          RewardRequestRecord(
            id: r.read<String>('id'),
            kidId: r.read<String>('kid_id'),
            rewardId: r.read<String>('reward_id'),
            status:
                RewardRequestStatus.fromWire(r.read<String>('status')),
            stars: r.read<int>('stars'),
            createdAt: _dateRequired(r.read<int>('created_at')),
            decidedAt: _date(r.readNullable<int>('decided_at')),
          ),
      ];
    } catch (e) {
      AppLogger.warning('KidsDao', 'requests read failed: $e');
      return const [];
    }
  }

  Future<List<RewardRequestRecord>> pendingRewardRequests() async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidRewardRequest} '
        "WHERE status = 'requested' ORDER BY created_at ASC",
      ).get();
      return [
        for (final r in rows)
          RewardRequestRecord(
            id: r.read<String>('id'),
            kidId: r.read<String>('kid_id'),
            rewardId: r.read<String>('reward_id'),
            status: RewardRequestStatus.fromWire(r.read<String>('status')),
            stars: r.read<int>('stars'),
            createdAt: _dateRequired(r.read<int>('created_at')),
            decidedAt: _date(r.readNullable<int>('decided_at')),
          ),
      ];
    } catch (e) {
      AppLogger.warning('KidsDao', 'pending requests read failed: $e');
      return const [];
    }
  }

  /// Requests a reward, reserving its stars. Returns the new request id.
  ///
  /// Re-checks affordability inside the transaction, so a request that raced
  /// another cannot overdraw the balance.
  Future<({String? id, String? error})> requestReward({
    required String kidId,
    required String rewardId,
    required int costStars,
    required String dayKey,
    int? weeklyLimit,
  }) async {
    if (costStars <= 0) return (id: null, error: 'invalid_cost');
    try {
      final id = 'req_${DateTime.now().microsecondsSinceEpoch}';
      var failure = '';
      await db.transaction(() async {
        final balance = await _balanceInTxn(kidId);
        final reserved = await _reservedInTxn(kidId);
        if (availableStars(balance: balance, reserved: reserved) < costStars) {
          failure = 'insufficient';
          return;
        }
        // A reward can cap how often it may be claimed in a rolling week.
        // Rejected and cancelled requests must not consume the allowance.
        if (weeklyLimit != null && weeklyLimit > 0) {
          final since = DateTime.now()
              .subtract(const Duration(days: 7))
              .millisecondsSinceEpoch;
          final rows = await db
              .customSelect(
                'SELECT COUNT(*) AS c FROM ${Personal2Tables.kidRewardRequest} '
                'WHERE kid_id = ? AND reward_id = ? AND created_at >= ? '
                "AND status IN ('requested', 'approved', 'fulfilled')",
                variables: [
                  Variable.withString(kidId),
                  Variable.withString(rewardId),
                  Variable.withInt(since),
                ],
              )
              .get();
          final used = rows.isEmpty ? 0 : rows.first.read<int>('c');
          if (used >= weeklyLimit) {
            failure = 'weekly_limit';
            return;
          }
        }
        await db.customStatement(
          'INSERT INTO ${Personal2Tables.kidRewardRequest} '
          '(id, kid_id, reward_id, status, stars, created_at) '
          "VALUES (?, ?, ?, 'requested', ?, ?)",
          [
            id,
            kidId,
            rewardId,
            costStars,
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
      });
      if (failure.isNotEmpty) return (id: null, error: failure);
      return (id: id, error: null);
    } catch (e) {
      AppLogger.warning('KidsDao', 'request failed: $e');
      return (id: null, error: 'failed');
    }
  }

  /// Approves a request and spends the stars, idempotently.
  Future<bool> decideRewardRequest({
    required String requestId,
    required bool approve,
  }) async {
    try {
      return await db.transaction(() async {
        final rows = await db.customSelect(
          'SELECT * FROM ${Personal2Tables.kidRewardRequest} WHERE id = ?',
          variables: [Variable.withString(requestId)],
        ).get();
        if (rows.isEmpty) return false;
        final r = rows.first;
        final status =
            RewardRequestStatus.fromWire(r.read<String>('status'));
        if (status != RewardRequestStatus.requested) return false;

        final kidId = r.read<String>('kid_id');
        final stars = r.read<int>('stars');
        final dayKey = kidDayKey(DateTime.now());

        final txn = approveReward(
          requestId: requestId,
          kidId: kidId,
          stars: stars,
          status: status,
          dayKey: dayKey,
          now: DateTime.now(),
        );

        if (!approve) {
          await db.customStatement(
            'UPDATE ${Personal2Tables.kidRewardRequest} '
            'SET status = ?, decided_at = ? WHERE id = ?',
            [
              RewardRequestStatus.rejected.wire,
              DateTime.now().millisecondsSinceEpoch,
              requestId,
            ],
          );
          return true;
        }

        await db.customStatement(
          'UPDATE ${Personal2Tables.kidRewardRequest} '
          'SET status = ?, decided_at = ? WHERE id = ?',
          [
            RewardRequestStatus.approved.wire,
            DateTime.now().millisecondsSinceEpoch,
            requestId,
          ],
        );
        if (txn != null) {
          await _insertStarTxn(
            kidId: txn.kidId,
            dayKey: txn.dayKey,
            date: txn.date ?? DateTime.now(),
            delta: txn.delta,
            reason: txn.reason.wire,
            refId: txn.refId,
            note: '',
          );
        }
        return true;
      });
    } catch (e) {
      AppLogger.warning('KidsDao', 'reward decide failed: $e');
      return false;
    }
  }

  /// Cancels a pending request (releases the reservation).
  Future<bool> cancelRewardRequest(String requestId) async {
    try {
      await db.customStatement(
        'UPDATE ${Personal2Tables.kidRewardRequest} SET status = ?, '
        'decided_at = ? WHERE id = ? AND status = ?',
        [
          
              releaseReservation(RewardRequestStatus.requested).wire,
          DateTime.now().millisecondsSinceEpoch,
          requestId,
          RewardRequestStatus.requested.wire,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'cancel request failed: $e');
      return false;
    }
  }

  // ── Settings ─────────────────────────────────────────────────────────

  Future<KidSettingsRecord> settings() async {
    const fallback = KidSettingsRecord();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Personal2Tables.kidSettings} WHERE id = ?',
        variables: [Variable.withString(settingsId)],
      ).get();
      if (rows.isEmpty) return fallback;
      final r = rows.first;
      return KidSettingsRecord(
        dayStartMinutes: r.read<int>('day_start_minutes').clamp(0, 1439),
        showSiblingComparison: r.read<int>('show_sibling_comparison') == 1,
        parentPinEnabled: r.read<int>('parent_pin_enabled') == 1,
        eveningSummaryEnabled: r.read<int>('evening_summary_enabled') == 1,
        eveningSummaryMinutes: r.read<int>('evening_summary_minutes'),
        approvalsNudgeEnabled: r.read<int>('approvals_nudge_enabled') == 1,
        quietStartMinutes: r.read<int>('quiet_start_minutes'),
        quietEndMinutes: r.read<int>('quiet_end_minutes'),
      );
    } catch (e) {
      AppLogger.warning('KidsDao', 'settings read failed: $e');
      return fallback;
    }
  }

  Future<bool> saveSettings(KidSettingsRecord s) async {
    try {
      await db.customStatement(
        'INSERT OR REPLACE INTO ${Personal2Tables.kidSettings} '
        '(id, day_start_minutes, show_sibling_comparison, parent_pin_enabled, '
        'evening_summary_enabled, evening_summary_minutes, '
        'approvals_nudge_enabled, quiet_start_minutes, quiet_end_minutes) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          settingsId,
          s.dayStartMinutes,
          s.showSiblingComparison ? 1 : 0,
          s.parentPinEnabled ? 1 : 0,
          s.eveningSummaryEnabled ? 1 : 0,
          s.eveningSummaryMinutes,
          s.approvalsNudgeEnabled ? 1 : 0,
          s.quietStartMinutes,
          s.quietEndMinutes,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('KidsDao', 'settings save failed: $e');
      return false;
    }
  }

  // ── Aggregate helpers (one query each, indexed) ──────────────────────

  Future<int> balance(String kidId) async {
    try {
      final rows = await db.customSelect(
        'SELECT COALESCE(SUM(delta), 0) AS total FROM '
        '${Personal2Tables.kidStarTxn} WHERE kid_id = ?',
        variables: [Variable.withString(kidId)],
      ).get();
      return rows.first.read<int>('total');
    } catch (e) {
      AppLogger.warning('KidsDao', 'balance read failed: $e');
      return 0;
    }
  }

  Future<int> _balanceInTxn(String kidId) async {
    final rows = await db.customSelect(
      'SELECT COALESCE(SUM(delta), 0) AS total FROM '
      '${Personal2Tables.kidStarTxn} WHERE kid_id = ?',
      variables: [Variable.withString(kidId)],
    ).get();
    return rows.first.read<int>('total');
  }

  Future<int> reserved(String kidId) async {
    try {
      final rows = await db.customSelect(
        'SELECT COALESCE(SUM(stars), 0) AS total FROM '
        '${Personal2Tables.kidRewardRequest} '
        "WHERE kid_id = ? AND status = 'requested'",
        variables: [Variable.withString(kidId)],
      ).get();
      return rows.first.read<int>('total');
    } catch (e) {
      AppLogger.warning('KidsDao', 'reserved read failed: $e');
      return 0;
    }
  }

  Future<int> _reservedInTxn(String kidId) async {
    final rows = await db.customSelect(
      'SELECT COALESCE(SUM(stars), 0) AS total FROM '
      '${Personal2Tables.kidRewardRequest} '
      "WHERE kid_id = ? AND status = 'requested'",
      variables: [Variable.withString(kidId)],
    ).get();
    return rows.first.read<int>('total');
  }

  /// Stars credited to a child inside a day range (for the weekly tile).
  Future<int> starsEarnedBetween(
    String kidId,
    String fromDayKey,
    String toDayKey,
  ) async {
    try {
      final rows = await db.customSelect(
        'SELECT COALESCE(SUM(delta), 0) AS total FROM '
        '${Personal2Tables.kidStarTxn} '
        'WHERE kid_id = ? AND day_key >= ? AND day_key <= ? AND delta > 0',
        variables: [Variable.withString(kidId), Variable.withString(fromDayKey), Variable.withString(toDayKey)],
      ).get();
      return rows.first.read<int>('total');
    } catch (e) {
      AppLogger.warning('KidsDao', 'stars range read failed: $e');
      return 0;
    }
  }

  // ── Row mappers ──────────────────────────────────────────────────────

  static KidLogRecord _log(dynamic r) => KidLogRecord(
        id: r.read<String>('id'),
        kidId: r.read<String>('kid_id'),
        dayKey: r.read<String>('day_key'),
        date: _dateRequired(r.read<int>('date')),
        habitId: r.readNullable<String>('habit_id'),
        prayerKey: r.readNullable<String>('prayer_key'),
        status: KidLogStatus.fromWire(r.read<String>('status')),
        stars: r.read<int>('stars'),
        late: r.read<int>('late') == 1,
        createdAt: _dateRequired(r.read<int>('created_at')),
        decidedAt: _date(r.readNullable<int>('decided_at')),
      );

  static RewardRecord _reward(dynamic r) => RewardRecord(
        id: r.read<String>('id'),
        kidId: r.readNullable<String>('kid_id'),
        title: r.read<String>('title'),
        iconKey: r.read<String>('icon_key'),
        costStars: r.read<int>('cost_stars'),
        weeklyLimit: r.readNullable<int>('weekly_limit'),
        active: r.read<int>('active') == 1,
        sort: r.read<int>('sort'),
        templateKey: r.readNullable<String>('template_key'),
      );
}

final kidsDaoProvider = Provider<KidsDao>(
  (ref) => KidsDao(ref.read(appDatabaseProvider)),
);
