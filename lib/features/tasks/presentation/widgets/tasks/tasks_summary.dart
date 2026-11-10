import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart'
    show dsContentColor;
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_common.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';

class TasksSummary extends StatelessWidget {
  final List<TaskModel> tasks;
  final double progress;
  final int pendingCount;
  final int doneCount;

  const TasksSummary({
    super.key,
    required this.tasks,
    required this.progress,
    required this.pendingCount,
    required this.doneCount,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final pct = (progress * 100).round();
    final accent = tasksAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final error = isDark ? AppTheme.darkError : AppTheme.lightError;

    final now = DateTime.now();
    // Rolled recurring tasks keep their last completion stamp while pending,
    // so counting them keeps the «امروز» stat honest for daily habits too.
    final doneToday = tasks
        .where((t) =>
            t.completedAt != null &&
            (t.isCompleted || t.hasRecurrence) &&
            isToday(t.completedAt!))
        .length;
    final dueToday = tasks
        .where(
            (t) => !t.isCompleted && t.dueDate != null && isToday(t.dueDate!))
        .length;
    final overdue = tasks
        .where((t) =>
            !t.isCompleted &&
            t.dueDate != null &&
            t.dueDate!.isBefore(DateTime(now.year, now.month, now.day)))
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconChip(icon: Icons.task_alt, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'پیشرفت کارها',
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
                  '$pct%',
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
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: t.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? success : accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TaskStat(
                  icon: Icons.check_circle,
                  label: 'امروز',
                  value: '$doneToday',
                  color: success),
              const SizedBox(width: 6),
              TaskStat(
                  icon: Icons.schedule,
                  label: 'در انتظار',
                  value: '$dueToday',
                  color: warning),
              const SizedBox(width: 6),
              TaskStat(
                  icon: Icons.event_busy,
                  label: 'موعد گذشته',
                  value: '$overdue',
                  color: error),
            ],
          ),
        ],
      ),
    );
  }
}

class TaskStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const TaskStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w800,
                  color: dsContentColor(context, color),
                )),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 9.5),
                  color: t.textMuted,
                )),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Section labels
// ══════════════════════════════════════════════════════════════
