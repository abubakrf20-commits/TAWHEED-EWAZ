import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The countdown ring: a soft glowing disc behind the progress ring with the
/// remaining time and the current status underneath it.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.progress,
    required this.timeText,
    required this.statusLabel,
    required this.accent,
    required this.isDark,
  });

  /// 0..1 remaining fraction shown by the progress ring.
  final double progress;
  final String timeText;
  final String statusLabel;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 252,
      height: 252,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Flat accent halo behind the ring (the flat pass dropped the
          // radial glow).
          Container(
            width: 252,
            height: 252,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: isDark ? 0.08 : 0.05),
            ),
          ),
          SizedBox(
            width: 232,
            height: 232,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              color: accent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeText,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 56),
                  fontWeight: FontWeight.w800,
                  color: TimeThemeKit.of(context).palette.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                  letterSpacing: 2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
