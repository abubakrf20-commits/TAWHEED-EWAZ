import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Start/pause + reset controls under the ring.
class TimerControls extends StatelessWidget {
  const TimerControls({
    super.key,
    required this.running,
    required this.accent,
    required this.onPlayPause,
    required this.onReset,
  });

  final bool running;
  final Color accent;
  final VoidCallback onPlayPause;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = TimeThemeKit.of(context).palette.textPrimary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Primary play/pause button: filled circle in the accent color.
        Material(
          color: accent,
          shape: const CircleBorder(),
          elevation: isDark ? 0 : 3,
          shadowColor: accent.withValues(alpha: 0.5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPlayPause,
            child: Tooltip(
              message: running ? 'توقف' : 'شروع',
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  running ? Icons.pause : Icons.play_arrow,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 22),
        // Secondary reset button.
        Material(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onReset,
            child: Tooltip(
              message: 'بازنشانی',
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Icon(
                  Icons.refresh,
                  size: 24,
                  color: onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
