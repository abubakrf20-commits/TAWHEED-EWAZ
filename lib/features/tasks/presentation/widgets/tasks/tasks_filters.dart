import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tasks/presentation/widgets/tasks/tasks_common.dart';

class TaskFilterChip extends StatelessWidget {
  final String label;
  final TaskFilter filter;
  final IconData icon;
  final TaskFilter current;
  final ValueChanged<TaskFilter> onChanged;

  const TaskFilterChip({
    super.key,
    required this.label,
    required this.filter,
    required this.icon,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = current == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(filter),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? tasksAccent
                : (isDark
                    ? t.surfaceAlt
                    : tasksAccent.withValues(alpha: 0.10)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? tasksAccent : t.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color:
                    selected ? Colors.white : t.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAG FILTER CHIP + GROUP-BY-TAG TOGGLE
// ══════════════════════════════════════════════════════════════
class TagFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const TagFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color
                : (isDark
                    ? t.surfaceAlt
                    : color.withValues(alpha: 0.10)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.label : Icons.label_outline,
                size: 15,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupByTagChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const GroupByTagChip({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = tasksAccent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.15)
                : (isDark
                    ? t.surfaceAlt
                    : color.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? color
                  : t.outline.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active
                    ? Icons.dashboard_customize
                    : Icons.dashboard_customize_outlined,
                size: 15,
                color: active ? color : t.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'گروه‌بندی برچسب',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? color : t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TASK TILE — kanban card with priority bar + status chips
// ══════════════════════════════════════════════════════════════
