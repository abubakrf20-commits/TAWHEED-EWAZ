import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/pomodoro_constants.dart';

/// Stepper with − / value / + used for the custom countdown time.
class StepButton extends StatelessWidget {
  const StepButton({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
    required this.color,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final mutedColor = t.textMuted;
    final textColor = t.textPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: mutedColor,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontFamily: AppTheme.fontFamily)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed:
                  enabled && value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: color,
              visualDensity: VisualDensity.compact,
              tooltip: '$label — کاهش',
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTheme.scaledFontSize(context, 17),
                ),
              ),
            ),
            IconButton(
              onPressed:
                  enabled && value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
              color: color,
              visualDensity: VisualDensity.compact,
              tooltip: '$label — افزایش',
            ),
          ],
        ),
      ],
    );
  }
}

/// Controls above the ring in «پومودور» mode: phase pill, session dots,
/// focus-type chips and the completed-session counter.
class ClassicTimerHeader extends StatelessWidget {
  const ClassicTimerHeader({
    super.key,
    required this.phaseLabel,
    required this.phase,
    required this.focusType,
    required this.running,
    required this.completedSessions,
    required this.sessionsInCycle,
    required this.sessionsBeforeLongBreak,
    required this.onFocusTypeChanged,
    required this.onFreshCycle,
  });

  final String phaseLabel;
  final PomodoroPhase phase;
  final String focusType;
  final bool running;
  final int completedSessions;
  final int sessionsInCycle;
  final int sessionsBeforeLongBreak;
  final ValueChanged<String> onFocusTypeChanged;

  /// «شروع سیکل تازه» — the long break belongs to four *consecutive* sessions,
  /// so a reader who stopped after two and came back after lunch (or the next
  /// morning) needs a way to begin the run again instead of meeting a 15-minute
  /// break at the third session.
  final VoidCallback onFreshCycle;

  IconData get _phaseIcon => switch (phase) {
        PomodoroPhase.focus => Icons.self_improvement,
        PomodoroPhase.shortBreak => Icons.free_breakfast_outlined,
        PomodoroPhase.longBreak => Icons.hotel_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = t.textMuted;
    final accent =
        phase == PomodoroPhase.focus ? pomodoroAccent : Colors.green.shade600;

    return Column(
      children: [
        // Phase pill.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_phaseIcon, size: 17, color: accent),
              const SizedBox(width: 7),
              Text(
                phaseLabel,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.bold,
                  color: accent,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // نوع تمرکز (ثبت‌شده در تاریخچه)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final type in focusTypes)
              ChoiceChip(
                label: Text(type),
                selected: focusType == type,
                selectedColor: focusTypeColor(type).withValues(alpha: 0.18),
                avatar: focusType == type
                    ? null
                    : Icon(
                        Icons.circle,
                        size: 9,
                        color: focusTypeColor(type).withValues(alpha: 0.5),
                      ),
                labelStyle: TextStyle(
                  color: focusType == type ? focusTypeColor(type) : mutedColor,
                  fontWeight:
                      focusType == type ? FontWeight.bold : FontWeight.normal,
                  fontFamily: AppTheme.fontFamily,
                ),
                side: BorderSide(
                  color: focusType == type
                      ? focusTypeColor(type).withValues(alpha: 0.55)
                      : Colors.transparent,
                ),
                onSelected: running ? null : (_) => onFocusTypeChanged(type),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // دایره‌های پیشرفت چرخه.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < sessionsBeforeLongBreak; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  i < sessionsInCycle ? Icons.circle : Icons.circle_outlined,
                  size: 11,
                  color: i < sessionsInCycle
                      ? accent
                      : mutedColor.withValues(alpha: 0.35),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // Only offered while a cycle is actually underway: at zero the button
        // would be a no-op on a page that already sits at the first session.
        if (sessionsInCycle > 0)
          TextButton.icon(
            onPressed: onFreshCycle,
            icon: const Icon(Icons.restart_alt, size: 17),
            label: Text(
              'شروع سیکل تازه',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: mutedColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.done_all_rounded,
                  size: 16, color: accent.withValues(alpha: 0.85)),
              const SizedBox(width: 7),
              Text(
                'جلسات تکمیل‌شده: $completedSessions',
                style: TextStyle(
                  color: t.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Controls above the ring in «شمارش معکوس» mode: ready presets, custom
/// minutes/seconds steppers and the race options card.
class CountdownTimerHeader extends StatelessWidget {
  const CountdownTimerHeader({
    super.key,
    required this.running,
    required this.cdMinutes,
    required this.cdSeconds,
    required this.cdRounds,
    required this.cdStartBeep,
    required this.cdKeepAwake,
    required this.onPresetSelected,
    required this.onMinutesChanged,
    required this.onSecondsChanged,
    required this.onRoundsChanged,
    required this.onStartBeepChanged,
    required this.onKeepAwakeChanged,
  });

  final bool running;
  final int cdMinutes;
  final int cdSeconds;
  final int cdRounds;
  final bool cdStartBeep;
  final bool cdKeepAwake;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<int> onMinutesChanged;
  final ValueChanged<int> onSecondsChanged;
  final ValueChanged<int> onRoundsChanged;
  final ValueChanged<bool> onStartBeepChanged;
  final ValueChanged<bool> onKeepAwakeChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 18, color: countdownAccent),
            const SizedBox(width: 7),
            Text(
              'مسابقه و شمارش معکوس',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 17),
                fontWeight: FontWeight.bold,
                color: countdownAccent,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // زمان‌های آماده
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final mins in cdPresets)
              ChoiceChip(
                label: Text('$mins دقیقه'),
                selected: cdSeconds == 0 && cdMinutes == mins,
                selectedColor: countdownAccent.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  color: cdSeconds == 0 && cdMinutes == mins
                      ? countdownAccent
                      : mutedColor,
                  fontWeight: cdSeconds == 0 && cdMinutes == mins
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontFamily: AppTheme.fontFamily,
                ),
                side: BorderSide(
                  color: cdSeconds == 0 && cdMinutes == mins
                      ? countdownAccent.withValues(alpha: 0.55)
                      : Colors.transparent,
                ),
                onSelected: running ? null : (_) => onPresetSelected(mins),
              ),
          ],
        ),
        const SizedBox(height: 14),
        // زمان دلخواه
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StepButton(
              label: 'دقیقه',
              value: cdMinutes,
              min: 0,
              max: 120,
              enabled: !running,
              onChanged: onMinutesChanged,
              color: countdownAccent,
            ),
            const SizedBox(width: 12),
            Text(':', style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 21), color: mutedColor)),
            const SizedBox(width: 12),
            StepButton(
              label: 'ثانیه',
              value: cdSeconds,
              min: 0,
              max: 59,
              enabled: !running,
              onChanged: onSecondsChanged,
              color: countdownAccent,
            ),
          ],
        ),
        const SizedBox(height: 14),
        // امکانات پیشرفته
        // Kept as a Material (not AppCard): the SwitchListTiles inside need a
        // Material ancestor — AppCard's plain DecoratedBox path trips the
        // framework's "ListTile ink may be invisible" assertion.
        Material(
          color: t.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: t.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded,
                        size: 16, color: countdownAccent),
                    const SizedBox(width: 7),
                    Text(
                      'تنظیمات مسابقه',
                      style: TextStyle(
                        color: textColor,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.bold,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.repeat, size: 18, color: countdownAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تعداد دور (برای چند نفر / چند مرحله)',
                        style: TextStyle(color: textColor, fontSize: AppTheme.scaledFontSize(context, 13)),
                      ),
                    ),
                    IconButton(
                      onPressed: running || cdRounds <= 1
                          ? null
                          : () => onRoundsChanged(cdRounds - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: mutedColor,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'کاهش دوره‌ها',
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$cdRounds',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: countdownAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTheme.scaledFontSize(context, 16),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: running || cdRounds >= 10
                          ? null
                          : () => onRoundsChanged(cdRounds + 1),
                      icon: const Icon(Icons.add_circle_outline),
                      color: mutedColor,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'افزایش دوره‌ها',
                    ),
                  ],
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: countdownAccent,
                  title: Text('بوق شروع (آماده‌باش 3-2-1)',
                      style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13))),
                  value: cdStartBeep,
                  onChanged: onStartBeepChanged,
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: countdownAccent,
                  title: Text('روشن نگه داشتن صفحه هنگام اجرا',
                      style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 13))),
                  value: cdKeepAwake,
                  onChanged: onKeepAwakeChanged,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
