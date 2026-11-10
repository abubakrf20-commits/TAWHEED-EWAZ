import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/goals/domain/goal_query.dart';
import 'package:tawheeed/features/goals/domain/goal_templates.dart';
import 'package:tawheeed/features/goals/presentation/providers/goals_provider.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_dates.dart';
import 'package:tawheeed/features/goals/presentation/widgets/goal_list_toolbar.dart';
import 'package:tawheeed/shared/widgets/async_screen.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/shared/widgets/skeleton_loading.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «هدف‌گذاری» — list of goals with progress ring hints, plus an archive
/// toggle that surfaces archived (بایگانی‌شده) goals.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final onPrimary = dsOnAccent(context);
    const accent = TopicHues.goals;
    final goals = ref.watch(goalsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'هدف‌گذاری',
        actions: [
          IconButton(
            key: const ValueKey('goals_templates'),
            tooltip: 'قالب آماده',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => _showTemplatesSheet(context),
          ),
          IconButton(
            key: const ValueKey('goals_archive_toggle'),
            tooltip: 'نمایش بایگانی',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => _showArchivedSheet(context, ref, accent),
          ),
        ],
      ),
      floatingActionButton: InsetFab(
        inset: MediaQuery.paddingOf(context).bottom,
        child: FloatingActionButton(
          tooltip: 'افزودن هدف',
          backgroundColor: t.primary,
          foregroundColor: onPrimary,
          onPressed: () => context.push(RouteNames.goalEditor),
          child: const Icon(Icons.add),
        ),
      ),
      body: SafeArea(
        // Reading `.value` and rendering a spinner when it is null made a
        // failed query indistinguishable from a slow one: the user got a
        // spinner forever and no error. AsyncScreen gives the three states
        // real names, and retry re-runs the query.
        //
        // The toolbar lives inside _GoalList, so the "no goals yet"
        // illustration is only shown when nothing is filtered away — an empty
        // result set from a search is a different state and gets its own
        // message.
        child: AsyncScreen<List<GoalTableData>>(
          asyncValue: goals,
          onRetry: () => ref.invalidate(goalsProvider),
          data: (list) =>
              list.isEmpty && ref.read(goalListOptionsProvider).isEmpty
                  ? _empty(context, accent)
                  : const _GoalList(),
        ),
      ),
    );
  }

  /// Bottom sheet listing archived goals with a restore action.
  Future<void> _showArchivedSheet(
      BuildContext context, WidgetRef ref, Color accent) async {
    // Its own provider, not a re-filter of the visible list: the visible
    // query filters archived rows out in SQL, so the sheet was always empty.
    final t = TimeThemeKit.of(context).palette;
    final archived = await ref.read(archivedGoalsProvider.future);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      builder: (ctx) => SafeArea(
        child: archived.isEmpty
            ? AppEmptyState(
                icon: Icons.inventory_2_outlined,
                message: 'چیزی در بایگانی نیست',
                accent: accent,
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 16, DsSpacing.page, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'اهداف بایگانی‌شده',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                  for (final g in archived)
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(g.title),
                      subtitle: g.deadline.isNotEmpty
                          ? Text('مهلت: ${goalFaDate(g.deadline)}')
                          : null,
                      trailing: TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _restoreGoal(context, ref, g);
                        },
                        child: const Text('بازگردانی'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  /// «قالب آماده» — five ready-made goals, each one tap from a filled-in
  /// editor. Opens the editor with the template as `extra`; nothing is saved
  /// until the user presses ذخیره, so a template never creates a row behind
  /// the user's back.
  void _showTemplatesSheet(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    const accent = TopicHues.goals;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding:
              const EdgeInsets.fromLTRB(DsSpacing.page, 16, DsSpacing.page, 24),
          children: [
            Text(
              'قالب آماده',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 15),
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'یک قالب را انتخاب کنید، عنوانش را دلخواه عوض کنید و ذخیره کنید.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            for (final tpl in goalTemplates)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child:
                      const Icon(Icons.flag_outlined, size: 18, color: accent),
                ),
                title: Text(
                  tpl.title,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                subtitle: tpl.description.isEmpty
                    ? null
                    : Text(
                        tpl.description,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textMuted,
                        ),
                      ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(RouteNames.goalEditor, extra: tpl);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreGoal(
      BuildContext context, WidgetRef ref, GoalTableData g) async {
    await setGoalArchived(ref, g.id, false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${g.title}» بازگردانی شد.')),
      );
    }
  }

  Widget _empty(BuildContext context, Color accent) {
    return AppEmptyState(
      icon: Icons.flag_outlined,
      message: 'هدفی ثبت نشده',
      subtitle: 'یک هدف مثل «حفظ 30 جزء» یا «مطالعه روزانه» را تعیین کنید و '
          'پیشرفت روزانه ثبت کنید.',
      accent: accent,
    );
  }
}

class _GoalList extends ConsumerWidget {
  const _GoalList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One provider for the rows, the totals, the streaks AND the current
    // search/filter/sort — so a keystroke re-sorts the in-memory list without
    // a database round trip, and the cards cannot disagree with the order.
    final entries = ref.watch(goalListEntriesProvider);
    final totalGoals = ref.watch(goalsProvider).value?.length ?? 0;

    return AsyncScreen<List<GoalListEntry>>(
      asyncValue: entries,
      onRetry: () => ref.invalidate(goalListEntriesProvider),
      loading: ListView(
        padding:
            const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 90),
        children: const [
          GoalListToolbar(totalGoals: 0),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SkeletonCard(height: 74),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SkeletonCard(height: 74),
          ),
        ],
      ),
      data: (list) {
        if (list.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.page, 12, DsSpacing.page, 90),
            children: [
              GoalListToolbar(totalGoals: totalGoals),
              const SizedBox(height: 24),
              _noMatches(context, ref, totalGoals),
            ],
          );
        }
        return ListView.builder(
          padding:
              const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 90),
          itemCount: list.length + 1,
          itemBuilder: (context, i) {
            // Row 0 is the toolbar; it scrolls with the list so the cards get
            // the full height on a small screen.
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GoalListToolbar(totalGoals: totalGoals),
              );
            }
            final entry = list[i - 1];
            return _GoalCard(
              entry: entry,
              onTap: () =>
                  context.push(RouteNames.goalDetailPath(entry.goal.id)),
            );
          },
        );
      },
    );
  }

  /// Shown when the goals exist but the active filters hide all of them.
  ///
  /// The unfiltered-empty case never reaches here — the parent renders
  /// «هدفی ثبت نشده» for that — so this is always the "your search matched
  /// nothing" case, and saying otherwise to someone with eleven goals is
  /// actively misleading.
  Widget _noMatches(BuildContext context, WidgetRef ref, int totalGoals) {
    const accent = TopicHues.goals;

    return AppEmptyState(
      icon: Icons.search_off,
      message: 'چیزی با این فیلترها پیدا نشد',
      subtitle: totalGoals == 0
          ? 'هنوز هدفی ثبت نکرده‌اید.'
          : '${NumberFormat.en(totalGoals)} هدف وجود دارد که با این فیلترها پنهان شده است.',
      accent: accent,
      action: OutlinedButton(
        onPressed: () => ref.read(goalListOptionsProvider.notifier).clear(),
        child: const Text('پاک کردن فیلترها'),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final GoalListEntry entry;
  final VoidCallback onTap;
  const _GoalCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    const accent = TopicHues.goals;
    final goal = entry.goal;
    final total = entry.total;
    final pct = entry.fraction;
    final daysToDeadline = goalDaysUntil(goal.deadline);
    final overdue = daysToDeadline != null && daysToDeadline < 0;
    final soon = !overdue &&
        daysToDeadline != null &&
        daysToDeadline > 0 &&
        daysToDeadline <= 7;
    final pace = _paceHint(goal.targetNumber, total, daysToDeadline);
    final done = entry.isComplete;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        borderColor: overdue || (daysToDeadline != null && daysToDeadline == 0)
            ? danger.withValues(alpha: 0.5)
            : soon
                ? warn.withValues(alpha: 0.5)
                : accent.withValues(alpha: 0.25),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 4,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    color: accent,
                  ),
                  Text(
                    '${NumberFormat.en((pct * 100).round())}٪',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: dsContentColor(context, accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  if (goal.targetNumber > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${NumberFormat.ltrIsolated(NumberFormat.grouped(total))} از ${NumberFormat.ltrIsolated(NumberFormat.grouped(goal.targetNumber))}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                  if (!goal.isActive) ...[
                    const SizedBox(height: 4),
                    Text(
                      'غیرفعال',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                  // Streak, priority and completion sit on one row so a
                  // long title cannot push them off the card, and so the
                  // three signals are comparable at a glance.
                  if (done ||
                      entry.streak.current > 0 ||
                      goal.priority > 0 ||
                      goal.dailyTarget > 0 ||
                      goal.remindEnabled ||
                      goal.linkedId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (done)
                          _tagChip(
                            context,
                            label: 'تکمیل‌شده',
                            icon: Icons.check_circle,
                            color: success,
                          ),
                        if (entry.streak.current > 0)
                          _tagChip(
                            context,
                            label: entry.streak.isActiveToday
                                ? '${NumberFormat.en(entry.streak.current)} روز پیاپی'
                                : 'پرکسیت از دیروز',
                            icon: Icons.local_fire_department,
                            color: warn,
                          ),
                        if (goal.dailyTarget > 0)
                          _tagChip(
                            context,
                            label:
                                'روزانه ${NumberFormat.grouped(goal.dailyTarget)}',
                            icon: Icons.bolt,
                            color: accent,
                          ),
                        if (goal.priority > 0)
                          _tagChip(
                            context,
                            label: goalPriorityLabel(goal.priority),
                            icon: Icons.flag,
                            color: accent,
                          ),
                        if (goal.remindEnabled)
                          _tagChip(
                            context,
                            label: 'یادآوری',
                            icon: Icons.notifications_active,
                            color: accent,
                          ),
                        if (goal.linkedId.isNotEmpty)
                          _tagChip(
                            context,
                            label: goalCategoryLabel(goal.category),
                            icon: Icons.link,
                            color: accent,
                          ),
                      ],
                    ),
                  ],
                  if (goal.deadline.isNotEmpty && daysToDeadline != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _deadlineChip(context, daysToDeadline),
                        if (pace != null) _paceChip(context, pace),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Quick log — the whole point of the card: one tap records
            // today without opening the detail screen.
            if (goal.isActive && (goal.targetType == 'boolean' || !done))
              _quickLog(context, ref, goal),
            Icon(Icons.chevron_left, color: t.textMuted),
          ],
        ),
      ),
    );
  }

  /// Boolean goals get a today-check toggle; count/minute goals add one tap's
  /// worth of progress — the daily target when set, else one unit.
  Widget _quickLog(BuildContext context, WidgetRef ref, GoalTableData goal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    const accent = TopicHues.goals;
    if (goal.targetType == 'boolean') {
      final doneToday = ref.watch(goalTodayProvider(goal.id)).value;
      if (doneToday == null) {
        // Unknown is not «not done»: a tap here would log a second completion
        // for a goal that may already be checked today.
        return IconButton(
          key: ValueKey('goal_quick_${goal.id}'),
          tooltip: 'در حال بارگذاری…',
          visualDensity: VisualDensity.compact,
          onPressed: null,
          icon: const Icon(Icons.check_circle_outline),
        );
      }
      return IconButton(
        key: ValueKey('goal_quick_${goal.id}'),
        tooltip: doneToday ? 'لغو ثبت امروز' : 'انجام شد',
        visualDensity: VisualDensity.compact,
        onPressed: () => toggleBooleanToday(ref, goal, doneToday: doneToday),
        icon: Icon(
          doneToday ? Icons.check_circle : Icons.check_circle_outline,
          color: doneToday ? success : accent,
        ),
      );
    }
    final amount = goal.dailyTarget > 0 ? goal.dailyTarget : 1;
    return IconButton(
      key: ValueKey('goal_quick_${goal.id}'),
      tooltip: 'ثبت $amount',
      visualDensity: VisualDensity.compact,
      onPressed: () => addGoalProgress(ref, goal.id, amount),
      icon: const Icon(Icons.add_circle_outline, color: accent),
    );
  }

  /// Small neutral pill used for streak, priority, daily target and the other
  /// at-a-glance signals. Deliberately not tappable: they are labels, and a
  /// pill that looks interactive but does nothing is worse than plain text.
  Widget _tagChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10.5),
              fontWeight: FontWeight.w600,
              color: dsContentColor(context, color),
            ),
          ),
        ],
      ),
    );
  }

  /// Colored days-left pill: red when overdue/today, amber within a week,
  /// green otherwise.
  Widget _deadlineChip(BuildContext context, int days) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final warn = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final overdue = days < 0;
    final today = days == 0;
    final soon = !overdue && !today && days <= 7;
    final color = overdue || today
        ? danger
        : soon
            ? warn
            : success;
    final label = overdue
        ? '${NumberFormat.en(-days)} روز از مهلت گذشته'
        : today
            ? 'مهلت امروز است'
            : '${NumberFormat.en(days)} روز تا پایان هدف';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            overdue ? Icons.error_outline : Icons.schedule,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                fontWeight: FontWeight.w700,
                color: dsContentColor(context, color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Daily pace hint: how much per remaining day finishes the goal on time.
  /// Null when there is no numeric target, the deadline passed, the goal is
  /// already met, or the pace is trivially small (less than once per two days).
  String? _paceHint(int target, int total, int? days) {
    if (target <= 0 || days == null || days <= 0) return null;
    final remaining = target - total;
    if (remaining <= 0) return null;
    final perDay = remaining / days;
    if (perDay < 0.5) return null;
    final shown = perDay >= 2
        ? NumberFormat.grouped(perDay.ceil())
        : (perDay * 10).round() / 10;
    return 'روزانه $shown در روز لازم';
  }

  Widget _paceChip(BuildContext context, String hint) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: TopicHues.goals.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hint,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 11),
          fontWeight: FontWeight.w600,
          color: t.textMuted,
        ),
      ),
    );
  }
}
