import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:tawheeed/features/goals/domain/goal_query.dart';
import 'package:tawheeed/features/goals/domain/goal_source_link.dart';
import 'package:tawheeed/features/goals/presentation/providers/goals_provider.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_dates.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/shared/widgets/async_screen.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

/// جزئیات هدف + ثبت پیشرفت روزانه.
class GoalDetailScreen extends ConsumerStatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final goalValue = ref.watch(goalDetailProvider(widget.goalId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: goalValue.value?.title ?? 'هدف',
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'ویرایش هدف',
            onPressed: goalValue.value == null
                ? null
                : () =>
                    context.push(RouteNames.goalEditor, extra: goalValue.value),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'حذف هدف',
            onPressed: goalValue.value == null
                ? null
                : () => _delete(context, ref, goalValue.value!),
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncScreen<GoalTableData?>(
          asyncValue: goalValue,
          onRetry: () => ref.invalidate(goalDetailProvider(widget.goalId)),
          // A goal id that is gone for good is a different case from a failed
          // read, and deserves different words than the generic error screen.
          error: (context, error, stack, retry) => FailureView(
            id: 'goal_load',
            title: 'این هدف خوانده نشد',
            detail: 'اینکه باز نشد به معنی حذف‌شدنش نیست؛ ثبت‌های پیشرفت '
                'همان‌جا هستند.',
            onRetry: retry,
            layout: FailureLayout.page,
            error: error,
          ),
          data: (goal) => goal == null
              // Gone for good, not broken: an empty state, because there is
              // nothing to retry and nothing went wrong just now.
              ? const AppEmptyState(
                  icon: Icons.flag_outlined,
                  message: 'این هدف دیگر وجود ندارد',
                  subtitle: 'ممکن است حذف شده باشد.',
                )
              : _GoalBody(goal: goal),
        ),
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, GoalTableData g) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف این هدف؟'),
        content: const Text('هدف و تمام ثبت‌های پیشرفت آن حذف می‌شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            // The theme's error colour, not a hardcoded red: the old
            // `Colors.redAccent` ignored light/dark mode entirely.
            style: FilledButton.styleFrom(
              backgroundColor: danger,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    // The messenger and container are captured before the pop: the restore
    // fires from a SnackBar action once this screen is gone, and a `context`
    // /`ref` read after unmount throws. A ProviderContainer lives as long as
    // the app, so it is safe to hold onto.
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    // One statement: the foreign key's ON DELETE CASCADE takes the goal's
    // progress rows with it. The old two-step sequence (children, then
    // parent) could be interrupted between the two DELETEs and leave orphans
    // that no sweep cleaned up. Goes through the provider, not the
    // repository, so the pending reminder is cancelled with the row.
    final snapshot = await deleteGoalWithSnapshot(ref, g);
    if (context.mounted) Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('هدف حذف شد'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () => restoreGoal(container, snapshot),
        ),
      ));
  }
}

/// The goal's contents, behind a provider for the lifetime total.
///
/// The total is fetched separately from the goal row, and the old code read
/// it as `.value ?? 0` — so a failed SUM rendered as 0 and the screen
/// cheerfully showed «۰ از ۳۰» for a goal with ten logged entries. A wrong
/// number presented as fact is worse than a visible error, so this waits for
/// the query instead of inventing a value.
class _GoalBody extends ConsumerStatefulWidget {
  final GoalTableData goal;
  const _GoalBody({required this.goal});

  @override
  ConsumerState<_GoalBody> createState() => _GoalBodyState();
}

class _GoalBodyState extends ConsumerState<_GoalBody> {
  /// Own the amount controller at State level: a controller created inside
  /// build() was re-created on every rebuild (leaking the old one and wiping
  /// whatever the user had typed mid-entry).
  final _amountCtrl = TextEditingController();
  bool _adding = false;

  /// Day the next entry is recorded against. Null means «today».
  DateTime? _entryDate;

  static const accent = TopicHues.goals;

  GoalTableData get goal => widget.goal;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncScreen<int>(
      asyncValue: ref.watch(goalTotalProvider(goal.id)),
      onRetry: () => ref.invalidate(goalTotalProvider(goal.id)),
      data: (total) => ListView(
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 40),
        children: [
          _headerCard(context, goal, total),
          const SizedBox(height: 16),
          _deadlinePanel(context, goal, total),
          const SizedBox(height: 16),
          _summaryPanel(context, goal, total),
          const SizedBox(height: 16),
          _sourceLinkCard(context, goal.id),
          const SizedBox(height: 16),
          _progressChart(context, goal.id),
          const SizedBox(height: 16),
          goal.targetType == 'boolean'
              ? _booleanToggle(context, goal)
              : _addEntry(context, goal.id),
          const SizedBox(height: 16),
          _history(context, goal.id),
        ],
      ),
    );
  }

  Widget _headerCard(BuildContext context, GoalTableData g, int total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final t = TimeThemeKit.of(context).palette;
    final pct =
        g.targetNumber <= 0 ? 0.0 : (total / g.targetNumber).clamp(0.0, 1.0);
    final remaining = g.targetNumber - total;
    final daysToDeadline = goalDaysUntil(g.deadline);

    return AppCard(
      padding: const EdgeInsets.all(16),
      color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
      borderColor: accent.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (g.description.isNotEmpty) ...[
            Text(
              g.description,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 10,
                        backgroundColor: accent.withValues(alpha: 0.15),
                        color: accent,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Text(
                g.targetNumber <= 0
                    ? '${NumberFormat.en(total)} ثبت'
                    : '${NumberFormat.en((pct * 100).round())}٪',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w700,
                  color: dsContentColor(context, accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(context, 'مجموع', NumberFormat.grouped(total)),
              if (g.targetNumber > 0) ...[
                _stat(context, 'باقی‌مانده',
                    remaining > 0 ? NumberFormat.grouped(remaining) : '0 ✅'),
              ],
              if (g.deadline.isNotEmpty)
                _stat(
                  context,
                  'مهلت',
                  goalFaDate(g.deadline),
                  valueColor: (daysToDeadline != null && daysToDeadline < 0)
                      ? danger
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// «روند تا پایان» — days left, required daily pace, last logged day and a
  /// projected finish date when the recent daily average holds. Hidden when
  /// the goal has no deadline.
  Widget _deadlinePanel(BuildContext context, GoalTableData g, int total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final daysToDeadline = goalDaysUntil(g.deadline);
    if (g.deadline.isEmpty || daysToDeadline == null) {
      return const SizedBox.shrink();
    }
    final overdue = daysToDeadline < 0;
    final today = daysToDeadline == 0;
    final color = overdue || today
        ? danger
        : daysToDeadline <= 7
            ? warn
            : success;

    final target = g.targetNumber;
    final remaining = target - total;
    final perDay = (target > 0 && daysToDeadline > 0 && remaining > 0)
        ? remaining / daysToDeadline
        : null;

    // Recent 7-day average for the projection. The day→amount map is built
    // once by the DAO; this used to be the first of three separate copies of
    // the same loop over the raw progress rows.
    final byDay = ref.watch(goalProgressProvider(g.id)).value ?? const {};
    final last7 = <int>[];
    for (var i = 0; i < 7; i++) {
      last7.add(byDay[goalIsoOf(
            DateTime.now().subtract(Duration(days: i)),
          )] ??
          0);
    }
    final avg7 = last7.fold<int>(0, (a, b) => a + b) / 7;
    final lastLogged = byDay.keys
        .where((d) => d != goalTodayIso())
        .fold<String?>(null, (a, b) => a == null || b.compareTo(a) > 0 ? b : a);
    final projected = (avg7 > 0 && target > 0 && remaining > 0 && !overdue)
        ? goalIsoOf(
            DateTime.now().add(Duration(days: (remaining / avg7).ceil())),
          )
        : null;
    final deadline = goalParseIso(g.deadline);
    final projectedLate = projected != null &&
        deadline != null &&
        goalParseIso(projected)!.isAfter(deadline);

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                overdue
                    ? Icons.error_outline
                    : today
                        ? Icons.today
                        : Icons.schedule,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  overdue
                      ? '${NumberFormat.en(-daysToDeadline)} روز از مهلت گذشته'
                      : today
                          ? 'مهلت امروز است'
                          : '${NumberFormat.en(daysToDeadline)} روز تا پایان هدف',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _stat(context, 'شروع',
                    g.startDate.isEmpty ? '—' : goalFaDate(g.startDate)),
              ),
              Expanded(
                child: _stat(context, 'مهلت', goalFaDate(g.deadline),
                    valueColor: color),
              ),
              if (perDay != null)
                Expanded(
                  child: _stat(
                      context,
                      'سرعت لازم',
                      perDay >= 2
                          ? '${NumberFormat.grouped(perDay.ceil())} در روز'
                          : '${(perDay * 10).round() / 10} در روز'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (lastLogged != null)
                Expanded(
                  child: _stat(context, 'آخرین ثبت', goalFaDate(lastLogged)),
                ),
              if (projected != null)
                Expanded(
                  child: _stat(context, 'پیش‌بینی پایان', goalFaDate(projected),
                      valueColor: projectedLate ? danger : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value,
      {Color? valueColor}) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: t.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: valueColor ?? t.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// «انجام / نشد» — a boolean goal gets a single-day toggle instead of a
  /// numeric entry field: tapping it records (or undoes) today's completion.
  Widget _booleanToggle(BuildContext context, GoalTableData g) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final t = TimeThemeKit.of(context).palette;
    final doneToday = ref.watch(goalTodayProvider(g.id)).value;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: doneToday == true
          ? success.withValues(alpha: 0.4)
          : accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'وضعیت امروز',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              // Unknown is not «not done»: a tap here would log a second
              // completion for a day that may already be checked.
              onPressed: doneToday == null
                  ? null
                  : () => _toggleBooleanToday(g, doneToday),
              style: FilledButton.styleFrom(
                backgroundColor: doneToday == true ? success : accent,
              ),
              icon: Icon(doneToday == true
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked),
              label: Text(
                doneToday == null
                    ? 'در حال بارگذاری…'
                    : doneToday
                        ? 'امروز انجام شد ✅'
                        : 'ثبت انجام امروز',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBooleanToday(GoalTableData g, bool doneToday) async {
    // The write, the id scheme and the invalidation all live in the provider
    // layer now. The widget used to scan the goal's entire history and delete
    // EVERY positive entry for today — so undoing a check-off also destroyed
    // any numeric entry logged the same day.
    await toggleBooleanToday(ref, g, doneToday: doneToday);
  }

  Widget _progressChart(BuildContext context, String goalId) {
    final t = TimeThemeKit.of(context).palette;
    final async = ref.watch(goalProgressProvider(goalId));

    // `.value` is null while loading AND after a failed query, so the chart
    // used to print «هنوز پیشرفتی ثبت نشده» over a goal with hundreds of
    // entries — the same mistake the total above this card was already fixed
    // for. Loading and failure each say their own thing now.
    if (async.isLoading && !async.hasValue) {
      return AppCard(
        padding: const EdgeInsets.all(14),
        borderColor: accent.withValues(alpha: 0.2),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'در حال خواندن پیشرفت…',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    if (async.hasError && !async.hasValue) {
      // The panel brings its own surface, so it replaces the AppCard rather
      // than nesting inside one.
      return FailureView(
        id: 'goal_progress_load',
        title: 'خواندن پیشرفت ناموفق بود',
        detail: 'ثبت‌های شما پاک نشده‌اند؛ فقط محاسبهٔ پیشرفت انجام نشد.',
        onRetry: () => ref.invalidate(goalProgressProvider(goalId)),
      );
    }

    final progress = async.requireValue;
    if (progress.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(14),
        borderColor: accent.withValues(alpha: 0.2),
        child: Text(
          'هنوز پیشرفتی ثبت نشده.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textMuted,
          ),
        ),
      );
    }
    // Last 14 days small bar mini-chart. The provider already returns
    // day→amount, so this no longer rebuilds the map by hand — that loop was
    // duplicated in three panels on this same screen.
    final days = progress.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final last = days.length > 14 ? days.sublist(days.length - 14) : days;
    final maxVal = last.map((e) => e.value).fold(1, (m, v) => v > m ? v : m);

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'پیشرفت 14 روز اخیر',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in last)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 12 + 30 * (d.value / maxVal),
                          decoration: const BoxDecoration(
                            color: accent,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goalFaShort(d.key),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 8),
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Streak, daily target, average pace and completion in one card.
  ///
  /// The numbers a user actually judges a goal by were scattered across the
  /// header, the deadline panel and the chart. This pulls them together and
  /// states completion explicitly — the progress bar reaching 100% is easy to
  /// miss, and «تمام شد» is the thing people want to know.
  Widget _summaryPanel(BuildContext context, GoalTableData g, int total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final t = TimeThemeKit.of(context).palette;
    final byDay = ref.watch(goalProgressProvider(g.id)).value;
    final streak = ref.watch(goalStreakProvider(g.id)).value;
    final days = byDay?.length ?? 0;
    final avg = days == 0 ? 0.0 : total / days;
    final remaining = g.targetNumber - total;
    final daysLeft = goalDaysUntil(g.deadline);
    final required = daysLeft != null && daysLeft > 0 && remaining > 0
        ? (remaining / daysLeft)
        : null;
    final done = g.targetNumber > 0 ? total >= g.targetNumber : total > 0;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor:
          done ? success.withValues(alpha: 0.4) : accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.verified : Icons.insights,
                size: 16,
                color: done ? success : accent,
              ),
              const SizedBox(width: 6),
              Text(
                done ? 'این هدف تکمیل شده است' : 'خلاصهٔ پیشرفت',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: done ? success : t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Two per row, wrapping instead of one four-up Row: four stat columns
          // overflow the width of a small phone — and of the test viewport —
          // and a clipped number is worse than a slightly taller card.
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final itemWidth = (constraints.maxWidth - gap) / 2;
              final stats = <(String, String)>[
                (
                  'پیوستگی',
                  streak == null
                      ? '—'
                      : '${NumberFormat.en(streak.current)} روز'
                ),
                (
                  'بهترین پیوستگی',
                  streak == null ? '—' : '${NumberFormat.en(streak.best)} روز'
                ),
                (
                  'میانگین روزانه',
                  days == 0 ? '—' : NumberFormat.formatPlain(avg)
                ),
                if (required != null)
                  ('نیاز روزانه', NumberFormat.formatPlain(required)),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final s in stats)
                    SizedBox(
                        width: itemWidth, child: _stat(context, s.$1, s.$2)),
                ],
              );
            },
          ),
          if (g.dailyTarget > 0 || g.remindEnabled) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (g.dailyTarget > 0)
                  _metaChip(
                    context,
                    'هدف روزانه: ${NumberFormat.grouped(g.dailyTarget)}',
                    Icons.bolt,
                  ),
                if (g.remindEnabled && g.remindAt.isNotEmpty)
                  _metaChip(
                      context, 'یادآوری روزانه: ${g.remindAt}', Icons.alarm),
                if (g.priority > 0)
                  _metaChip(context, 'اولویت: ${goalPriorityLabel(g.priority)}',
                      Icons.flag),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(BuildContext context, String label, IconData icon) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Read-only view of whatever this goal is linked to.
  ///
  /// Renders nothing at all when the goal has no link, so the card does not
  /// become permanent empty furniture on every goal. When the source row was
  /// deleted, it says so and offers to clear the link — a dangling id shown as
  /// a blank space reads as data loss, and the goal is otherwise fine.
  Widget _sourceLinkCard(BuildContext context, String goalId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final t = TimeThemeKit.of(context).palette;
    final async = ref.watch(goalSourceLinkProvider(goalId));
    final snap = async.value;
    if (snap == null) return const SizedBox.shrink();
    final warn = snap.missing;
    final tint = warn ? danger : accent;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: tint.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(warn ? Icons.link_off : Icons.link, size: 16, color: tint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kGoalLinkTypeLabels[snap.type] ?? snap.type,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
              ),
              if (warn)
                TextButton(
                  onPressed: () => _unlinkSource(context, goalId),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'حذف اتصال',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: t.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            snap.title.isEmpty ? '—' : snap.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            snap.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: t.textMuted,
            ),
          ),
          // Only drawn when the source actually reports a ratio. A note has
          // none, and a 0% bar for it would be a fabricated number.
          if (snap.fraction != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: snap.fraction,
                minHeight: 5,
                backgroundColor: tint.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(tint),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'این اطلاعات فقط نمایش داده می‌شود و از این صفحه تغییر نمی‌کند.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Clears a link whose target no longer exists.
  Future<void> _unlinkSource(BuildContext context, String goalId) async {
    await ref.read(goalRepositoryProvider).clearSourceLink(goalId);
    invalidateGoal(ref, goalId);
  }

  Widget _addEntry(BuildContext context, String goalId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ثبت پیشرفت امروز',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [LatinGroupingFormatter()],
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'مقدار (مثلاً 1 جز)',
                    hintStyle: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textMuted,
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) {
                    _addEntryNow(goalId);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Back-dating. The old entry card hardcoded today, so a forgotten
              // entry could only be faked by logging it today — which quietly
              // corrupted the streak and the daily averages.
              Expanded(
                child: _dateButton(context, goalId),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _adding ? null : () => _addEntryNow(goalId),
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: const Text('+'),
              ),
            ],
          ),
          if (goalId.isNotEmpty)
            // A FutureBuilder over a one-shot repository read: it re-issued the
            // query on every rebuild and never re-fired when the data changed.
            // The provider is invalidated with the rest of the goal's queries,
            // so this line just reflects it.
            Builder(builder: (context) {
              final todayCount =
                  ref.watch(goalTodayCountProvider(goalId)).value ?? 0;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  todayCount == 0
                      ? 'امروز هنوز ثبت نشده'
                      : 'امروز ${NumberFormat.grouped(todayCount)}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: success,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// The day the next entry will be recorded against.
  ///
  /// Held as state rather than derived from "today" so a back-dated entry
  /// stays on the chosen day while the user types the amount — losing the
  /// selection between the two taps is how a back-fill silently lands on the
  /// wrong date.
  Widget _dateButton(BuildContext context, String goalId) {
    final t = TimeThemeKit.of(context).palette;
    final isToday = _entryDate == null;
    final date = _entryDate ?? DateTime.now();
    return OutlinedButton(
      onPressed: () => _pickEntryDate(context),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 44),
        side:
            BorderSide(color: isToday ? accent.withValues(alpha: 0.3) : accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isToday ? Icons.today : Icons.event_busy,
            size: 14,
            color: isToday ? t.textMuted : accent,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isToday ? 'امروز' : goalFaDate(goalIsoOf(date)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: isToday ? FontWeight.w400 : FontWeight.w700,
                color: isToday ? t.textMuted : accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickEntryDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await ShamsiDatePicker.show(
      context,
      initialDate: _entryDate ?? now,
      // Back-filling a forgotten day, not planning ahead: a future entry would
      // let a streak be extended before it is earned.
      earliestDate: DateTime(now.year - 5),
      latestDate: now,
    );
    if (picked == null || !mounted) return;
    // Resolving to midnight drops the time component so re-picking today
    // compares equal and resets the button to its «today» state.
    final day = DateTime(picked.year, picked.month, picked.day);
    final today = DateTime(now.year, now.month, now.day);
    setState(() => _entryDate = day == today ? null : day);
  }

  Future<void> _addEntryNow(String goalId) async {
    // Normalize Persian/Arabic digits so «12» from a Persian keyboard parses.
    final amount = NumberFormat.parse(_amountCtrl.text.trim()).toInt();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مقدار معتبر وارد کنید.')));
      return;
    }
    setState(() => _adding = true);
    try {
      await addGoalProgress(ref, goalId, amount,
          date: _entryDate == null ? null : goalIsoOf(_entryDate!));
      _amountCtrl.clear();
      // Reset to today so the next entry does not silently keep the previous
      // back-fill date.
      if (mounted && _entryDate != null) {
        setState(() => _entryDate = null);
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// The log, one row per entry, each editable and deletable.
  ///
  /// Was a list of per-day sums with no way to act on them: a mistyped amount
  /// could only be removed by deleting the row and typing it again, losing the
  /// original timestamp. Grouping by day keeps the list readable while the
  /// per-entry actions stay reachable.
  Widget _history(BuildContext context, String goalId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final t = TimeThemeKit.of(context).palette;
    final entries = ref.watch(goalEntriesProvider(goalId)).value;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    // Group in Dart: the query returns rows already ordered by day desc, and
    // a LinkedHashMap preserves that while collecting the days.
    final byDay = <String, List<GoalProgressTableData>>{};
    for (final e in entries) {
      (byDay[e.date] ??= <GoalProgressTableData>[]).add(e);
    }
    final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'تاریخچه',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Text(
                '${NumberFormat.en(entries.length)} ثبت',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final day in dayKeys) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      goalFaDate(day),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w700,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '+${NumberFormat.grouped((byDay[day] ?? const <GoalProgressTableData>[]).fold<int>(0, (s, e) => s + e.amount))}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w700,
                      color: success,
                    ),
                  ),
                ],
              ),
            ),
            for (final e in (byDay[day] ?? const <GoalProgressTableData>[]))
              _entryRow(context, goalId, e,
                  showTime:
                      (byDay[day] ?? const <GoalProgressTableData>[]).length >
                          1),
            const Divider(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _entryRow(BuildContext context, String goalId, GoalProgressTableData e,
      {required bool showTime}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '+${NumberFormat.grouped(e.amount)}',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
          ),
          // `createdAt` is non-nullable, so the timestamp is always available.
          // It is only rendered when the day has more than one entry —
          // otherwise the day heading above already identifies it and the
          // column is just noise.
          if (showTime)
            Text(
              '${e.createdAt.hour.toString().padLeft(2, '0')}:'
              '${e.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: t.textMuted,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 17),
            tooltip: 'ویرایش مقدار',
            visualDensity: VisualDensity.compact,
            onPressed: () => _editEntry(context, goalId, e),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            tooltip: 'حذف ثبت',
            visualDensity: VisualDensity.compact,
            color: danger,
            onPressed: () => _deleteEntry(context, goalId, e),
          ),
        ],
      ),
    );
  }

  /// Correct a mistyped amount in place, keeping the original date and id.
  Future<void> _editEntry(
      BuildContext context, String goalId, GoalProgressTableData e) async {
    final ctrl = TextEditingController(text: NumberFormat.grouped(e.amount));
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ویرایش مقدار'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: const [LatinGroupingFormatter()],
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(labelText: 'مقدار'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              NumberFormat.parse(ctrl.text.trim()).toInt(),
            ),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result <= 0 || !mounted) return;
    await updateGoalProgress(ref, goalId, e.id, result);
  }

  /// Ask first: the row is the only record of that unit, and there is no undo.
  Future<void> _deleteEntry(
      BuildContext context, String goalId, GoalProgressTableData e) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف ثبت'),
        content:
            Text('${NumberFormat.grouped(e.amount)} از «${goalFaDate(e.date)}» '
                'حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await deleteGoalProgress(ref, goalId, e.id);
  }
}
