import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show dsContentColor;
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tasks/data/daos/task_aux_dao.dart';
import 'package:tawheeed/features/tasks/domain/task_week_stats.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/tasks/presentation/providers/task_provider.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_common.dart';

/// «آمار هفتگی» — completions of the current Iranian week (شنبه…جمعه).
///
/// Read from the completion log rather than the task rows, so recurring
/// duties count on every occurrence (a daily adhkar ticked five times shows
/// five) instead of once.
class TasksWeeklyStats extends ConsumerStatefulWidget {
  const TasksWeeklyStats({super.key});

  @override
  ConsumerState<TasksWeeklyStats> createState() => _TasksWeeklyStatsState();
}

class _TasksWeeklyStatsState extends ConsumerState<TasksWeeklyStats> {
  List<int> _counts = List<int>.filled(7, 0);

  /// The week's completions could not be read; the caption says so instead of
  /// claiming the week was empty.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    List<DateTime> completions = const [];
    var failed = false;
    try {
      completions = await ref
          .read(taskAuxDaoProvider)
          .completionsSince(taskWeekStart(now));
    } catch (e) {
      // Best-effort for the CHART, but not for the sentence under it: the
      // caption used to read «این هفته هنوز کاری تیک نخورده» after a failed
      // read, which is a factual claim about the reader's week.
      AppLogger.warning('tasks_weekly_stats', 'week load failed: $e');
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _counts = weeklyCompletionCounts(completions, now);
      _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    // Completing/un-completing (or undoing a delete) refreshes the chart.
    ref.listen(taskListProvider, (_, __) => _load());

    final accent = tasksAccent;
    final total = _counts.fold<int>(0, (s, c) => s + c);
    final maxCount = _counts.fold<int>(0, (m, c) => c > m ? c : m);
    final todayIndex = taskWeekIndex(DateTime.now());

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconChip(icon: Icons.insights, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'آمار هفتگی',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Text(
                  '$total تیک‌زده',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: dsContentColor(context, accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Rendered from the start (zeros) — no spinner: an animated
          // placeholder would never settle in widget tests and flashes in
          // production; the DAO answer just fills the bars in.
          SizedBox(
            height: 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: TaskDayBar(
                      label: taskWeekdayShortFa[i],
                      count: _counts[i],
                      maxCount: maxCount,
                      accent: accent,
                      isToday: i == todayIndex,
                    ),
                  ),
              ],
            ),
          ),
          if (total == 0) ...[
            const SizedBox(height: 6),
            Text(
              _failed
                  ? 'آمار این هفته خوانده نشد'
                  : 'این هفته هنوز کاری تیک نخورده',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 10.5),
                color: t.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One weekday column: count on top (when non-zero), bar, weekday letter.
class TaskDayBar extends StatelessWidget {
  const TaskDayBar({
    super.key,
    required this.label,
    required this.count,
    required this.maxCount,
    required this.accent,
    required this.isToday,
  });

  final String label;
  final int count;
  final int maxCount;
  final Color accent;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;
    final height = count == 0 ? 3.0 : 6 + (ratio * 22);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (count > 0)
          Text(
            '$count',
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 9),
              fontWeight: FontWeight.w800,
              color: dsContentColor(context, accent),
            ),
          ),
        const SizedBox(height: 2),
        Container(
          width: 16,
          height: height,
          decoration: BoxDecoration(
            color: count == 0
                ? t.textMuted.withValues(alpha: 0.25)
                : accent.withValues(alpha: isToday ? 1.0 : 0.55),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 9.5),
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            color: isToday ? accent : t.textMuted,
          ),
        ),
      ],
    );
  }
}
