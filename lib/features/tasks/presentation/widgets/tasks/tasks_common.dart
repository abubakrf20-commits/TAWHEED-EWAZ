import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

enum TaskFilter { all, today, thisWeek, highPriority, completed }

/// Tasks identity color — indigo (kanban board feel).
Color get tasksAccent => TopicHues.tasks;

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime d) => isSameDay(d, DateTime.now());

class SectionLabel extends StatelessWidget {
  final String title;
  final int count;
  final Color accent;
  const SectionLabel(
      {super.key,
      required this.title,
      required this.count,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12.5),
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

class CollapsibleHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  const CollapsibleHeader({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SectionLabel(
                title: title,
                count: count,
                accent: tasksAccent.withValues(alpha: 0.55)),
            const Spacer(),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more,
                size: 20,
                color: t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FILTER CHIP — indigo identity
// ══════════════════════════════════════════════════════════════

class IconChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  const IconChip({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const GradientButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: TextStyle(fontFamily: AppTheme.fontFamily)),
      style: FilledButton.styleFrom(
        backgroundColor: tasksAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
