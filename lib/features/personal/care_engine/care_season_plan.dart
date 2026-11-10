/// Where a season pack («آماده‌سازی زمستان») stands, and what it is missing.
///
/// The pack banner used to pick a pack by a hardcoded month table and then
/// count *every* template key it contained — including the two that carry no
/// window — so it offered «۴ مورد» even after all four were scheduled, and it
/// was offered in Tir because the table said «تابستان» rather than because a
/// window said so. This file derives the answer from the windows themselves.
library;

import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/care_engine/care_templates.dart';

/// The three states a pack can be in. `missed` is this year's window; the pack
/// is still worth offering, because its tasks then target next year.
enum CareSeasonState { before, inWindow, missed }

class CareSeasonPlan {
  const CareSeasonPlan({
    required this.pack,
    required this.state,
    required this.total,
    required this.missing,
    this.windowStart,
    this.windowEnd,
    this.daysUntilStart,
    this.daysRemaining,
    this.nextWindowStart,
  });

  final CareSeasonPack pack;
  final CareSeasonState state;

  /// Templates in the pack that exist in the bundle (unknown keys are dropped
  /// by the parser already; this is the count the banner may promise).
  final int total;

  /// Pack templates that have no live task on this asset — the only ones an
  /// «افزودن» may create.
  final List<CareTemplate> missing;

  /// The union of the pack's windows for the cycle this plan describes.
  final DateTime? windowStart;
  final DateTime? windowEnd;

  /// Only for [CareSeasonState.before].
  final int? daysUntilStart;

  /// Only for [CareSeasonState.inWindow]; 0 means today is the last day.
  final int? daysRemaining;

  /// Only for [CareSeasonState.missed] — when the pack comes round again.
  final DateTime? nextWindowStart;

  int get scheduled => total - missing.length;
  bool get isComplete => missing.isEmpty;
  bool get hasWindow => windowStart != null && windowEnd != null;

  /// «در پنجره — ۱۲ روز باقی» / «۱۸ روز تا پنجره» / «پنجرهٔ امسال گذشت».
  String get statusLabel {
    switch (state) {
      case CareSeasonState.inWindow:
        final days = daysRemaining ?? 0;
        return days <= 0 ? 'امروز آخرین روز پنجره' : 'در پنجره — $days روز باقی';
      case CareSeasonState.before:
        final days = daysUntilStart ?? 0;
        return days <= 0 ? 'پنجره باز شده' : '$days روز تا پنجره';
      case CareSeasonState.missed:
        return 'پنجرهٔ امسال گذشت';
    }
  }

  /// The button label, or null when there is nothing to add.
  String? get actionLabel {
    if (missing.isEmpty) return null;
    if (state == CareSeasonState.missed) {
      return 'افزودن برای فصل بعد (${missing.length})';
    }
    return 'افزودن ${missing.length} مورد';
  }
}

/// The pack's union window in the Jalali year of [anchor], widened to include
/// every template window it holds. A window that wraps the new year ends in
/// the following year, and the union follows the same rule.
({DateTime start, DateTime end})? careSeasonWindow(
  CareSeasonPack pack,
  CareTemplates templates,
  DateTime anchor,
) {
  final year = jalaliParts(anchor).year;
  final yearStart = Jalali(year, 1, 1).toDateTime();
  DateTime? start;
  DateTime? end;
  for (final key in pack.templateKeys) {
    final window = templates.byKey(key)?.window;
    if (window == null) continue;
    final dates = careWindowDates(window, yearStart);
    if (start == null || dates.start.isBefore(start)) start = dates.start;
    if (end == null || dates.end.isAfter(end)) end = dates.end;
  }
  if (start == null || end == null) return null;
  return (start: start, end: end);
}

/// The plan for [pack] on an asset whose live tasks are [tasks], at [now].
///
/// Returns null only when the pack has no template left in the bundle, i.e.
/// when there is nothing it could ever add.
CareSeasonPlan? careSeasonPlanFor({
  required CareSeasonPack pack,
  required CareTemplates templates,
  required Iterable<CareTask> tasks,
  required DateTime now,
}) {
  final packTemplates = <CareTemplate>[];
  for (final key in pack.templateKeys) {
    final template = templates.byKey(key);
    if (template != null) packTemplates.add(template);
  }
  if (packTemplates.isEmpty) return null;

  final live = tasks.where((t) => t.active).map((t) => t.templateKey).toSet();
  final missing =
      packTemplates.where((t) => !live.contains(t.key)).toList(growable: false);
  final today = DateTime(now.year, now.month, now.day);

  final window = careSeasonWindow(pack, templates, now);
  if (window == null) {
    // A pack made only of unscheduled-by-date items (e.g. «کپسول آتش‌نشانی»)
    // has no window to stand in; it is always offerable.
    return CareSeasonPlan(
      pack: pack,
      state: CareSeasonState.before,
      total: packTemplates.length,
      missing: missing,
    );
  }

  if (today.isAfter(window.end)) {
    final nextYear = Jalali(jalaliParts(now).year + 1, 1, 1).toDateTime();
    final next = careSeasonWindow(pack, templates, nextYear);
    return CareSeasonPlan(
      pack: pack,
      state: CareSeasonState.missed,
      total: packTemplates.length,
      missing: missing,
      windowStart: window.start,
      windowEnd: window.end,
      nextWindowStart: next?.start,
    );
  }

  if (today.isBefore(window.start)) {
    return CareSeasonPlan(
      pack: pack,
      state: CareSeasonState.before,
      total: packTemplates.length,
      missing: missing,
      windowStart: window.start,
      windowEnd: window.end,
      daysUntilStart: window.start.difference(today).inDays,
    );
  }

  return CareSeasonPlan(
    pack: pack,
    state: CareSeasonState.inWindow,
    total: packTemplates.length,
    missing: missing,
    windowStart: window.start,
    windowEnd: window.end,
    daysRemaining: window.end.difference(today).inDays,
  );
}

/// The pack worth showing first: one that is open, else the next one to open,
/// else the one whose window just closed (still offerable for next year).
CareSeasonPlan? careNextSeasonPlan({
  required CareTemplates templates,
  required Iterable<CareTask> tasks,
  required DateTime now,
}) {
  CareSeasonPlan? best;
  for (final pack in templates.seasonPacks) {
    final plan = careSeasonPlanFor(
      pack: pack,
      templates: templates,
      tasks: tasks,
      now: now,
    );
    if (plan == null) continue;
    if (plan.state == CareSeasonState.inWindow) {
      // An open pack with something left to add beats an open complete one.
      if (best == null ||
          best.state != CareSeasonState.inWindow ||
          (best.isComplete && !plan.isComplete)) {
        best = plan;
      }
    } else if (plan.state == CareSeasonState.before) {
      final bestDays = best?.daysUntilStart ?? 1 << 30;
      if (best == null ||
          best.state == CareSeasonState.missed ||
          (best.state == CareSeasonState.before &&
              (plan.daysUntilStart ?? 0) < bestDays)) {
        best = plan;
      }
    } else if (best == null) {
      best = plan;
    }
  }
  return best;
}
