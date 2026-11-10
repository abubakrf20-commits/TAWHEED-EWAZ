import 'package:flutter/material.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_common.dart';
import 'package:tawheeed/features/tasks/presentation/providers/task_provider.dart';
import 'package:tawheeed/features/tasks/presentation/providers/subtask_provider.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_dialog.dart';
import 'package:tawheeed/features/tasks/domain/task_recurrence.dart';

class TaskTile extends ConsumerWidget {
  final String taskId;
  const TaskTile({super.key, required this.taskId});

  Color _priorityColor(int priority) {
    switch (priority) {
      case 3:
        return const Color(0xFFE53935);
      case 2:
        return const Color(0xFFFB8C00);
      case 1:
        return const Color(0xFFFDD835);
      default:
        return const Color(0xFFBDBDBD);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskByIdProvider(taskId));
    if (task == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final pc = _priorityColor(task.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: task.isCompleted
              ? t.outline.withValues(alpha: 0.4)
              : tasksAccent.withValues(alpha: 0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Priority color bar on the leading (right in RTL) edge
          Container(
            width: 4,
            color: task.isCompleted
                ? t.outline.withValues(alpha: 0.3)
                : pc,
          ),
          Expanded(
            child: InkWell(
              onTap: () => _showTaskDialog(context, task: task),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    TaskCheck(
                      value: task.isCompleted,
                      color: tasksAccent,
                      onChanged: (_) => ref
                          .read(taskListProvider.notifier)
                          .toggleTask(task.id),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (task.priority > 0) ...[
                                Icon(Icons.flag, size: 14, color: pc),
                                const SizedBox(width: 5),
                              ],
                              Expanded(
                                child: Text(
                                  task.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 14),
                                    fontWeight: FontWeight.w700,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: task.isCompleted
                                        ? t.textMuted
                                        : t.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_hasMeta(task)) ...[
                            const SizedBox(height: 6),
                            TaskMeta(task: task, isDark: isDark),
                          ],
                          if (task.description != null &&
                              task.description!.trim().isNotEmpty)
                            _ExpandableDescription(
                              text: task.description!.trim(),
                              muted: task.isCompleted,
                            ),
                          _SubtaskProgress(taskId: taskId),
                          _StreakPill(taskId: taskId),
                          if (task.tags.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: task.tags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tasksAccent.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 10),
                                      color: tasksAccent,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasMeta(TaskModel task) {
    return task.dueDate != null ||
        (task.isCompleted && task.completedAt != null) ||
        task.priority > 0 ||
        task.tags.isNotEmpty;
  }

  void _showTaskDialog(BuildContext context, {TaskModel? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskDialog(existingTask: task),
    );
  }
}

class TaskMeta extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  const TaskMeta({super.key, required this.task, required this.isDark});

  static String _relativeDue(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;
    if (diff == 0) return 'امروز';
    if (diff == -1) return 'دیروز';
    if (diff == 1) return 'فردا';
    if (diff > 1 && diff <= 7) return '$diff روز مانده';
    if (diff < -1 && diff >= -7) return '${-diff} روز پیش';
    final j = Jalali.fromDateTime(due);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  static String _absolute(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final due = task.dueDate;
    final isOverdue = due != null &&
        !task.isCompleted &&
        DateTime(due.year, due.month, due.day).isBefore(todayStart);
    final isDueToday = due != null && !task.isCompleted && isToday(due);
    final items = <Widget>[];

    if (isOverdue) {
      items.add(MetaPill(
        icon: Icons.error_outline,
        text: 'موعد گذشته',
        color: Theme.of(context).colorScheme.error,
      ));
    }
    if (task.dueDate != null) {
      final j = Jalali.fromDateTime(task.dueDate!);
      items.add(MetaPill(
        icon: Icons.event_outlined,
        text: _relativeDue(task.dueDate!),
        color: isDueToday
            ? tasksAccent
            : isOverdue
                ? Theme.of(context).colorScheme.error
                : t.textMuted,
        fullDate: jalaliYmdShort(j),
      ));
    }
    final recLabel = TaskRecurrence.label(task.recurringType);
    if (task.hasRecurrence && recLabel != null) {
      // Weekly duties anchored on a weekday read as «هر چهارشنبه».
      final weeklyDay =
          task.recurringType == TaskRecurrence.weekly && task.dueDate != null
              ? TaskRecurrence.weekdayNameFa(task.dueDate!)
              : null;
      items.add(MetaPill(
        icon: Icons.repeat,
        text: weeklyDay != null ? 'هر $weeklyDay' : 'تکرار $recLabel',
        color: tasksAccent,
      ));
    }
    // A rolled recurring task keeps [completedAt] as its last-completion stamp
    // so the user sees today's instance was done even though it re-opened.
    if (task.hasRecurrence && task.completedAt != null) {
      items.add(MetaPill(
        icon: Icons.done_all,
        text: 'آخرین انجام: ${_shortDate(task.completedAt!)}',
        color: success,
      ));
    }
    if (task.remindEnabled && task.remindAt != null) {
      items.add(MetaPill(
        icon: Icons.notifications_active,
        text: 'یادآوری ${task.remindAt}',
        color: isOverdue
            ? Theme.of(context).colorScheme.error
            : t.textMuted,
      ));
    }
    if (task.isCompleted && task.completedAt != null) {
      items.add(MetaPill(
        icon: Icons.done_all,
        text: _absolute(task.completedAt!),
        color: success,
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items,
    );
  }

  static String _shortDate(DateTime d) {
    final j = Jalali.fromDateTime(d);
    if (isToday(d)) return 'امروز';
    return '${j.day}/${j.month}';
  }
}

class MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? fullDate;
  final Color color;
  const MetaPill({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.fullDate,
  });

  @override
  Widget build(BuildContext context) {
    final label = fullDate != null && text == fullDate
        ? text
        : '$text${fullDate != null ? ' • $fullDate' : ''}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Task notes («ملاحظات»): long text is clamped to two lines with a
/// «نمایش بیشتر / بستن» toggle so cards stay compact.
class _ExpandableDescription extends StatefulWidget {
  final String text;
  final bool muted;
  const _ExpandableDescription({required this.text, required this.muted});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;
  static const _truncateAt = 120;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final long = widget.text.length > _truncateAt;
    final showAll = _expanded || !long;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          widget.text,
          maxLines: showAll ? null : 2,
          overflow: showAll ? null : TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            height: 1.7,
            color: widget.muted
                ? t.textMuted
                : t.textSecondary,
          ),
        ),
        if (long)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _expanded ? 'بستن' : 'نمایش بیشتر',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: tasksAccent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Subtask progress bar («2 از 5») shown when a task has checklist items.
class _SubtaskProgress extends ConsumerWidget {
  final String taskId;
  const _SubtaskProgress({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final subs = ref.watch(subtaskListProvider(taskId));
    if (subs.isEmpty) return const SizedBox.shrink();
    final (done, total) = SubtaskList.progressOf(subs);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 6,
                backgroundColor:
                    t.outline.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(tasksAccent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$done از $total',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              fontWeight: FontWeight.w700,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak badge («زنجیره 5 روز») for duties done repeatedly.
class _StreakPill extends ConsumerWidget {
  final String taskId;
  const _StreakPill({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(taskStreakProvider(taskId));
    return streakAsync.when(
      data: (s) {
        if (s.streak < 2) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: MetaPill(
            icon: Icons.local_fire_department,
            text: 'زنجیره ${s.streak} ${s.unit}',
            color: const Color(0xFFEF6C00),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class TaskCheck extends StatelessWidget {
  final bool value;
  final Color color;
  final ValueChanged<bool?> onChanged;
  const TaskCheck({
    super.key,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    // The visual box stays 24 dp (the tile's compact look), but the tap area
    // is the 48 dp accessibility minimum. It replaces the 10 dp gap that used
    // to follow the box, so the row grows by only the padding it absorbs.
    return Semantics(
      button: true,
      checked: value,
      label: value ? 'لغو انجام کار' : 'علامت‌گذاری به‌عنوان انجام‌شده',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: value ? color : t.outline,
                  width: value ? 0 : 1.6,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DIALOG — modal bottom sheet (khatm-style header)
// ══════════════════════════════════════════════════════════════
