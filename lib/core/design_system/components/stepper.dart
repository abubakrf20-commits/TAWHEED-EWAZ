import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// [-] value [+] row for discrete counts (repetitions, minutes, pages…).
/// Buttons keep a 48dp touch target; the value clamps to [min]/[max] and
/// buttons dim at the bounds.
class ValueStepper extends StatelessWidget {
  const ValueStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.valueLabel,
    this.color,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;
  final int step;

  /// Replaces the plain number (e.g. «۳۰ دقیقه»); caller formats digits.
  final String? valueLabel;

  /// Chip hue; defaults to the live phase primary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final hue = color ?? p.primary;
    final canDown = onChanged != null && value > min;
    final canUp = onChanged != null && value < max;

    void bump(int delta) {
      HapticFeedback.selectionClick();
      onChanged?.call((value + delta).clamp(min, max));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove_rounded,
          color: hue,
          enabled: canDown,
          semanticLabel: 'کاهش',
          onTap: () => bump(-step),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 56),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          margin: const EdgeInsets.symmetric(horizontal: DsSpacing.rowGap),
          decoration: BoxDecoration(
            color: hue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hue.withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: Text(
            valueLabel ?? value.toString(),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w700,
              color: dsContentColor(context, hue),
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          color: hue,
          enabled: canUp,
          semanticLabel: 'افزایش',
          onTap: () => bump(step),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.outline),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 18,
                color: enabled ? color : p.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
