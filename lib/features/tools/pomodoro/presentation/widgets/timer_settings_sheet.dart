import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/tools/pomodoro/presentation/pomodoro_constants.dart';

/// Result model returned by [TimerSettingsSheet].
class TimerSettings {
  const TimerSettings({
    required this.focus,
    required this.shortBreak,
    required this.longBreak,
    required this.sessions,
  });

  final int focus;
  final int shortBreak;
  final int longBreak;
  final int sessions;
}

class TimerSettingsSheet extends StatefulWidget {
  const TimerSettingsSheet({
    super.key,
    required this.focus,
    required this.shortBreak,
    required this.longBreak,
    required this.sessions,
  });

  final int focus;
  final int shortBreak;
  final int longBreak;
  final int sessions;

  @override
  State<TimerSettingsSheet> createState() => _TimerSettingsSheetState();
}

class _TimerSettingsSheetState extends State<TimerSettingsSheet> {
  late int _focus;
  late int _shortBreak;
  late int _longBreak;
  late int _sessions;

  @override
  void initState() {
    super.initState();
    _focus = widget.focus;
    _shortBreak = widget.shortBreak;
    _longBreak = widget.longBreak;
    _sessions = widget.sessions;
  }

  @override
  Widget build(BuildContext context) {
    final mutedColor = TimeThemeKit.of(context).palette.textMuted;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: pomodoroAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      color: pomodoroAccent, size: 21),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تنظیمات تایمر',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 17),
                            fontWeight: FontWeight.bold,
                            color: pomodoroAccent,
                            fontFamily: AppTheme.fontFamily)),
                    const SizedBox(height: 2),
                    Text('مدت هر بخش و چرخهٔ استراحت‌ها را تعیین کنید',
                        style: TextStyle(color: mutedColor, fontSize: AppTheme.scaledFontSize(context, 12))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            TimerDurationRow(
              label: 'تمرکز (دقیقه)',
              value: _focus,
              onChanged: (v) => setState(() => _focus = v),
            ),
            TimerDurationRow(
              label: 'استراحت کوتاه (دقیقه)',
              value: _shortBreak,
              onChanged: (v) => setState(() => _shortBreak = v),
            ),
            TimerDurationRow(
              label: 'استراحت طولانی (دقیقه)',
              value: _longBreak,
              onChanged: (v) => setState(() => _longBreak = v),
            ),
            TimerDurationRow(
              label: 'جلسات تا استراحت طولانی',
              value: _sessions,
              min: 2,
              max: 8,
              onChanged: (v) => setState(() => _sessions = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: pomodoroAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(context).pop(TimerSettings(
                  focus: _focus,
                  shortBreak: _shortBreak,
                  longBreak: _longBreak,
                  sessions: _sessions,
                )),
                child: const Text('ذخیره'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimerDurationRow extends StatelessWidget {
  const TimerDurationRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 90,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final textColor = t.textPrimary;
    final mutedColor = t.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: textColor,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontFamily: AppTheme.fontFamily)),
            ),
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: mutedColor,
              visualDensity: VisualDensity.compact,
              tooltip: '$label — کاهش',
            ),
            SizedBox(
              width: 34,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pomodoroAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTheme.scaledFontSize(context, 16),
                ),
              ),
            ),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
              color: mutedColor,
              visualDensity: VisualDensity.compact,
              tooltip: '$label — افزایش',
            ),
          ],
        ),
      ),
    );
  }
}
