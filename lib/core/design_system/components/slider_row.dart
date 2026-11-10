import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Label + value pill above a slider, with a ring thumb: white fill and a
/// colored stroke, so the handle reads on both light and dark palettes.
class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.color,
    this.valueLabel,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;

  /// Track/thumb hue; defaults to the live phase primary.
  final Color? color;

  /// Display text for the value pill; defaults to the integer value.
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final hue = color ?? p.primary;
    final enabled = onChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: p.textSecondary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: hue.withValues(alpha: enabled ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                valueLabel ?? value.round().toString(),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? dsContentColor(context, hue)
                      : p.textMuted,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: enabled ? hue : hue.withValues(alpha: 0.25),
            inactiveTrackColor: hue.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            overlayColor: hue.withValues(alpha: 0.12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            thumbShape: _RingThumbShape(hue: hue, radius: 10),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Semantics(
            // The visible label sits in the row header, outside Slider's own
            // semantics node — merge it in so the slider announces itself.
            label: label,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// White disc with a colored ring — the spec's slider handle.
class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape({required this.hue, required this.radius});

  final Color hue;
  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.square(radius * 2);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final enabled = enableAnimation.value;
    final ring = Color.lerp(hue.withValues(alpha: 0.4), hue, enabled) ?? hue;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}
