import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// Row check control: 22–26px circle with an accent-tinted border; done =
/// emerald fill + white check; [missed] = amber-red ring with a minus (the
/// window passed and it was never logged). Promoted from the home prayer
/// rows so every screen's rows read the same.
class CheckCircle extends StatelessWidget {
  const CheckCircle({
    super.key,
    required this.checked,
    required this.color,
    this.missed = false,
    this.size = 26,
  });

  final bool checked;

  /// The row's accent — tints the empty circle's border.
  final Color color;
  final bool missed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final missColor = (isDark ? AppTheme.darkError : AppTheme.lightError)
        .withValues(alpha: 0.75);
    return Semantics(
      // Rows pair this control with a prayer name, so the state alone is the
      // missing announcement (TalkBack otherwise hears nothing).
      label: checked ? 'انجام شد' : (missed ? 'از دست رفته' : 'انجام نشده'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // The done fill is the theme's success green, shaded toward black for
          // the gradient's second stop — one source, not a second hard-coded
          // Material green.
          gradient: checked
              ? LinearGradient(
                  colors: [
                    AppTheme.success,
                    mix(AppTheme.success, Colors.black, 0.22),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: checked ? null : Colors.transparent,
          border: Border.all(
            color: checked
                ? AppTheme.success
                : missed
                    ? missColor
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.25)),
            width: checked ? 0 : (missed ? 2 : 1.5),
          ),
        ),
        child: checked
            ? Icon(Icons.check_rounded, size: size * .62, color: Colors.white)
            : (missed
                ? Icon(Icons.remove_rounded,
                    size: size * .54, color: missColor)
                : null),
      ),
    );
  }
}
