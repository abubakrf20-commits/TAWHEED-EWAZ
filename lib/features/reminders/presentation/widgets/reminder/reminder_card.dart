import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/reminders/data/models/reminder_model.dart';
import 'package:tawheeed/features/reminders/domain/entities/reminder_model.dart'
    as rm;
import 'package:tawheeed/features/reminders/presentation/utils/reminder_colors.dart';
import 'package:tawheeed/features/reminders/presentation/widgets/reminder/action_btn.dart';

class ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback onToggle, onEdit, onDelete;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = ReminderColors.accent;
    final isEnabled = reminder.isEnabled;
    final isToday = isEnabled && reminder.matchesToday();
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isEnabled
              ? accent.withValues(alpha: isDark ? 0.4 : 0.25)
              : t.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row: icon + title + status badges + switch
                  Row(
                    children: [
                      Icon(
                        reminder.useSound
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        size: 20,
                        color: isEnabled ? accent : t.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reminder.title,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 15),
                            fontWeight: FontWeight.w700,
                            color: isEnabled ? t.textPrimary : t.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isToday) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            'امروز',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 10),
                              fontWeight: FontWeight.w700,
                              color: dsContentColor(context, accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Switch(
                        value: isEnabled,
                        onChanged: (_) => onToggle(),
                        activeThumbColor: accent,
                        activeTrackColor:
                            accent.withValues(alpha: isDark ? 0.5 : 0.3),
                        inactiveThumbColor: t.textMuted,
                      ),
                    ],
                  ),
                  // Time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        reminder.timeString,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 24),
                          fontWeight: FontWeight.w800,
                          color: isEnabled
                              ? dsContentColor(context, accent)
                              : t.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          rm.recurrenceKindFa(
                              specificDate: reminder.specificDate),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: isEnabled ? t.textSecondary : t.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Repeat / date + advance pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (reminder.specificDate != null)
                        _MetaPill(
                          icon: Icons.calendar_today,
                          text: jalaliYmdPadded(reminder.specificDate!),
                          color: isToday ? accent : t.textMuted,
                        )
                      else
                        _MetaPill(
                          icon: Icons.repeat,
                          text: reminder.repeatSummary,
                          color: t.textMuted,
                        ),
                      if (reminder.advanceMinutes > 0)
                        _MetaPill(
                          icon: Icons.alarm,
                          text: '${reminder.advanceMinutes} دقیقه زودتر',
                          color: t.textMuted,
                        ),
                      if (!isEnabled)
                        _MetaPill(
                          icon: Icons.pause_circle_outline,
                          text: 'غیرفعال',
                          color: t.textMuted,
                        ),
                    ],
                  ),
                  if (reminder.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      reminder.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: t.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      ActionBtn(Icons.edit_outlined,
                          tooltip: 'ویرایش یادآور', onPressed: onEdit),
                      ActionBtn(Icons.delete_outline,
                          tooltip: 'حذف یادآور', onPressed: onDelete),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Edge accent bar (enabled → orange, disabled → muted)
          Container(
            width: 4,
            color: isEnabled
                ? accent
                : (isToday ? success : t.outline.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MetaPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10.5),
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
