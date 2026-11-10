import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tawheeed/core/design_system/components/icon_tile.dart';
import 'package:tawheeed/core/design_system/components/settings_tokens.dart';
import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Shared settings kit (Design 1 / Design A). Every settings page builds
/// from these — no one-off styles.
///
/// Performance contract (weak phones): no BackdropFilter/blur, no
/// large-blur shadows, no Opacity/saveLayer; flat alphas only. Font sizes go
/// through `AppTheme.scaledFontSize` so the type-scale guard stays green.

// ───────────────────────── App bar ─────────────────────────

/// Side padding for kit rows living inside an [AppCard] (which pads zero).
/// Shared by every settings surface — was copy-pasted as a private `_row()`
/// in six files (about_screen.dart keeps its own copy: that file is owned
/// by a parallel session).
Widget settingsRow(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: child,
    );

/// One app bar spec for ALL settings pages: back arrow at the start side
/// (auto-mirrored in RTL), centered 16/500 ink title, optional trailing.
class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SettingsAppBar({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget? trailing;

  /// Overrides the default [BackButton]. A page that can be reached as the
  /// FIRST route (a debug build, or a host that launches straight into it)
  /// has nothing to pop; such a page must still be able to leave, so it
  /// passes a handler that falls back to the shell.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: t.primary,
      leading: onBack == null
          ? const BackButton()
          : IconButton(
              icon: const BackButtonIcon(),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
            ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 16),
          fontWeight: FontWeight.w500,
          color: t.textPrimary,
        ),
      ),
      actions: [if (trailing != null) trailing!],
    );
  }
}

// ───────────────────────── Switch ─────────────────────────

/// Standard settings switch: 42x24, ON = emerald track + white thumb,
/// OFF = sand track + white thumb. RTL mirroring comes free from the
/// directional alignment. Null [onChanged] renders the disabled state.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final enabled = onChanged != null;
    // ON keeps the fixed semantic green; OFF follows the palette's hairline
    // tone — the old sand constant was a light-only truth that glowed cream
    // on dark pages.
    final track = value ? SettingsTokens.switchOn : p.outline;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              }
            : null,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: enabled ? track : track.withValues(alpha: 0.45),
              ),
              alignment: value
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Value chip ─────────────────────────

/// Current-value chip: 11sp semibold on the palette's soft gold, radius 9.
/// The text is caller-formatted (already LTR-isolated where needed).
class SettingsValueChip extends StatelessWidget {
  const SettingsValueChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.tertiarySoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 11),
          fontWeight: FontWeight.w600,
          color: dsContentColor(context, p.tertiary),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ───────────────────────── Stepper ─────────────────────────

/// Compact stepper: LTR-isolated 30h pill (fill + hairline border), "−" and
/// "+" zones with >= 44dp hit areas around slim 17px glyphs, value 13/500
/// (min width 34, signed as "+2"/"−5"/"0" via [NumberFormat.formatSigned]),
/// unit label outside the pill (10sp muted). Long-press repeats with
/// acceleration, bounds disable their side, every step haptics.
///
/// Style knobs are opt-in so every existing page keeps this recipe's exact
/// look: the «اذان و اقامه» card (the one wider stepper surface) raises the
/// pill to 36h on the card fill with the accent border, and may let the pill
/// stretch to fill its layout cell via [expand].
class SettingsStepper extends StatefulWidget {
  const SettingsStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.signed = false,
    this.unit,
    this.color,
    this.semanticLabel,
    this.valueLabel,
    this.height = 30,
    this.radius = 15,
    this.glyphSize = 17,
    this.valueFontSize = 13,
    this.fillColor,
    this.borderColor,
    this.borderWidth = 0.5,
    this.expand = false,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;
  final int step;
  final bool signed;
  final String? unit;
  final Color? color;
  final String? semanticLabel;

  /// Replaces the plain number (e.g. an LTR "100٪"); caller formats digits.
  final String? valueLabel;

  /// Pill geometry (all default to the kit's shipped look).
  final double height;
  final double radius;
  final double glyphSize;
  final double valueFontSize;

  /// Defaults to the palette's [AppPalette.surfaceAlt].
  final Color? fillColor;

  /// Defaults to the palette's [AppPalette.outline].
  final Color? borderColor;
  final double borderWidth;

  /// Stretch the pill to fill the parent's width (for fixed layout cells).
  /// The extra width lands in the value slot, which keeps its 34 min width.
  final bool expand;

  @override
  State<SettingsStepper> createState() => _SettingsStepperState();
}

class _SettingsStepperState extends State<SettingsStepper> {
  Timer? _delayTimer;
  Timer? _repeatTimer;
  int _repeatMs = 250;
  int _repeatDir = 0;

  @override
  void dispose() {
    _delayTimer?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  bool get _enabled => widget.onChanged != null;

  void _step(int dir, {bool haptic = true}) {
    final next =
        (widget.value + dir * widget.step).clamp(widget.min, widget.max);
    if (next == widget.value) return;
    if (haptic) HapticFeedback.selectionClick();
    widget.onChanged?.call(next);
  }

  void _startRepeat(int dir) {
    if (!_enabled) return;
    _stopRepeat();
    _repeatDir = dir;
    _repeatMs = 250;
    _delayTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _step(dir, haptic: false);
      _scheduleTick();
    });
  }

  void _scheduleTick() {
    _repeatTimer?.cancel();
    _repeatTimer = Timer(Duration(milliseconds: _repeatMs), () {
      if (!mounted) return;
      _step(_repeatDir, haptic: false);
      _repeatMs = (_repeatMs * 0.8).round().clamp(60, 250);
      _scheduleTick();
    });
  }

  void _stopRepeat() {
    _delayTimer?.cancel();
    _repeatTimer?.cancel();
    _delayTimer = null;
    _repeatTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final hue = widget.color ?? p.primary;
    final canDown = _enabled && widget.value > widget.min;
    final canUp = _enabled && widget.value < widget.max;
    final display = widget.valueLabel ??
        (widget.signed
            ? NumberFormat.formatSigned(widget.value)
            : '${widget.value}');

    Widget zone({
      required IconData icon,
      required bool enabled,
      required VoidCallback onTap,
      required VoidCallback onRepeat,
      required String semantic,
    }) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: enabled ? onTap : null,
        onLongPressStart: enabled ? (_) => onRepeat() : null,
        onLongPressEnd: (_) => _stopRepeat(),
        onLongPressCancel: _stopRepeat,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              icon,
              size: widget.glyphSize,
              color: enabled
                  ? dsContentColor(context, hue)
                  : p.textMuted.withValues(alpha: 0.45),
            ),
          ),
        ),
      );
    }

    Widget valueSlot() {
      final text = Text(
        display,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, widget.valueFontSize),
          fontWeight: FontWeight.w500,
          color: dsContentColor(context, hue),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      // The value is a LOOSE minWidth-34 slot (never a tight width): wide
      // values — e.g. a «۳۰ دقیقه» row — grow the pill exactly as they did
      // before the knobs. `expand` stretches the same slot to its cell.
      return Container(
        constraints: const BoxConstraints(minWidth: 34),
        alignment: Alignment.center,
        child: text,
      );
    }

    Widget pillBody() => Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.fillColor ?? p.surfaceAlt,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: widget.borderColor ?? p.outline,
              width: widget.borderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              zone(
                icon: Icons.remove_rounded,
                enabled: canDown,
                onTap: () => _step(-1),
                onRepeat: () => _startRepeat(-1),
                semantic: 'decrease',
              ),
              valueSlot(),
              zone(
                icon: Icons.add_rounded,
                enabled: canUp,
                onTap: () => _step(1),
                onRepeat: () => _startRepeat(1),
                semantic: 'increase',
              ),
            ],
          ),
        );

    return Semantics(
      label: widget.semanticLabel,
      value: display,
      increasedValue: '${widget.value + widget.step}',
      decreasedValue: '${widget.value - widget.step}',
      onIncrease: canUp ? () => _step(1) : null,
      onDecrease: canDown ? () => _step(-1) : null,
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: widget.expand ? Expanded(child: pillBody()) : pillBody(),
          ),
          if (widget.unit != null) ...[
            const SizedBox(width: 4),
            Text(
              widget.unit!,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10),
                color: p.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Slider row ─────────────────────────

/// Slider row: duotone tile + title + LTR value chip, then a 6dp track
/// (pale line, solid gold fill) with an 18dp white thumb wearing a dark
/// border. No tick dots. [onChanged] fires live for the UI; [onSettled]
/// fires once per gesture for persistence.
class SettingsSliderRow extends StatelessWidget {
  const SettingsSliderRow({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.valueText,
    required this.value,
    required this.onChanged,
    this.onSettled,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String valueText;
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onSettled;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final enabled = onChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconTile(icon: icon, color: accent, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w500,
                  color: p.textPrimary,
                ),
              ),
            ),
            SettingsValueChip(text: valueText),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            inactiveTrackColor: p.surfaceAlt,
            // The active track, the touch ring and the thumb border all read
            // the row's IDENTITY accent — the old heroGold hard-wire drowned
            // three differently-coloured sliders (tasbih / alerts / adhan)
            // into one gold.
            activeTrackColor: accent,
            thumbColor: Colors.white,
            overlayColor: accent.withValues(alpha: 0.12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            thumbShape: const _BorderThumbShape(),
            trackShape: const _FlatTrackShape(),
            tickMarkShape: const _NoTickMarks(),
          ),
          child: Semantics(
            label: title,
            value: valueText,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onSettled : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Solid gold active track over the pale line (flat settings language).
class _FlatTrackShape extends SliderTrackShape {
  const _FlatTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 6;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackLeft = offset.dx;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final radius = Radius.circular(rect.height / 2);
    final canvas = context.canvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = sliderTheme.inactiveTrackColor!,
    );
    final active = Rect.fromLTRB(
      textDirection == TextDirection.rtl ? thumbCenter.dx : rect.left,
      rect.top,
      textDirection == TextDirection.rtl ? rect.right : thumbCenter.dx,
      rect.bottom,
    );
    if (active.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(active, radius),
        Paint()..color = sliderTheme.activeTrackColor!,
      );
    }
  }
}

/// 18dp white thumb with a 3dp ring in the slider's accent.
class _BorderThumbShape extends SliderComponentShape {
  const _BorderThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(18);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required Size sizeWithOverflow,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double textScaleFactor,
    required double value,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = sliderTheme.activeTrackColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

/// Discrete sliders snap via [divisions] but paint no tick dots.
class _NoTickMarks extends SliderTickMarkShape {
  const _NoTickMarks();

  @override
  Size getPreferredSize(
          {required SliderThemeData sliderTheme, required bool isEnabled}) =>
      Size.zero;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required bool isEnabled,
    required TextDirection textDirection,
  }) {
    // Intentionally blank — snapping without dots.
  }
}

// ───────────────────────── Segmented ─────────────────────────

/// One option of a [SettingsSegmented] row.
class SettingsSegment<T> {
  const SettingsSegment({required this.label, this.icon, required this.value});

  final String label;
  final IconData? icon;
  final T value;
}

/// Three-(or-N-)segment control: pale container, selected segment a solid
/// dark pill with a gold icon and cream label, others muted.
class SettingsSegmented<T> extends StatelessWidget {
  const SettingsSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SettingsSegment<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: p.outline, width: 0.5),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _SegmentButton(
                label: option.label,
                icon: option.icon,
                selected: option.value == value,
                onTap: () {
                  if (option.value == value) return;
                  HapticFeedback.selectionClick();
                  onChanged(option.value);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Flat selected pill in the palette's own strong tone — the fixed
            // brown constant painted a brown pill on every theme.
            color: selected ? p.primaryStrong : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  // Selected ink comes from dsOnAccent: primaryStrong is a
                  // dark pill in the light palettes and a light one in the
                  // dark palettes, so the fixed gold icon/cream label could
                  // not follow the theme.
                  color: selected ? dsOnAccent(context) : p.textMuted,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? dsOnAccent(context) : p.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Warning card ─────────────────────────

/// Permission/info notice: solid pale-gold fill, gold hairline, duotone amber
/// tile, 12sp/1.7 text and a full-width outline action button. Pass [accent]
/// for a success/info tone (same shape, tinted identity) instead of forking
/// a one-off notice box.
class WarningCard extends StatelessWidget {
  const WarningCard({
    super.key,
    required this.text,
    this.icon = Icons.warning_amber_rounded,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  final String text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tint override; defaults to the gold notice identity.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = accent ?? AppPalette.goldDark;
    // Default stays byte-identical (const chipFill); the accent path tints.
    final lightStart =
        Color.lerp(Colors.white, tint, 0.22) ?? SettingsTokens.chipFill;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Flat fill: the light-mode ramp is gone — one solid tone, the default
        // chip gold or the accent tint (settings language).
        color: isDark
            ? tint.withValues(alpha: 0.14)
            : (accent == null ? SettingsTokens.chipFill : lightStart),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon, color: tint, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    height: 1.7,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onAction!();
                },
                style: OutlinedButton.styleFrom(
                  // The card surface, not raw white — the fixed white button
                  // sat on the dark card like a light patch in dark themes.
                  backgroundColor: p.card,
                  side: BorderSide(color: tint.withValues(alpha: 0.60)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: dsContentColor(context, tint),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Search field ─────────────────────────

/// White search field with a clear button: white, hairline border,
/// radius 16, 9dp vertical padding, search icon, «جستجو در تنظیمات».
class SettingsSearchField extends StatefulWidget {
  const SettingsSearchField({
    super.key,
    required this.onChanged,
    this.onSubmitted,
    this.controller,
    this.focusNode,
    this.autofocus = false,
  });

  final ValueChanged<String> onChanged;

  /// The keyboard's own «جستجو» key. Without it that key did nothing: the
  /// field kept focus and the results only caught up after the debounce, which
  /// reads as a dead button. The caller decides whether to apply the query
  /// immediately and dismiss the keyboard.
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<SettingsSearchField> createState() => _SettingsSearchFieldState();
}

class _SettingsSearchFieldState extends State<SettingsSearchField> {
  TextEditingController? _ownedController;
  FocusNode? _ownedFocus;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  @override
  void dispose() {
    _ownedController?.dispose();
    _ownedFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? p.surfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.outline, width: 0.5),
      ),
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'جستجو در تنظیمات',
              hintStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: p.textMuted,
              ),
              prefixIcon:
                  Icon(Icons.search_rounded, size: 20, color: p.textMuted),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: p.textMuted),
                      tooltip: 'پاک کردن جستجو',
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged('');
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              isDense: true,
            ),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 14),
              color: p.textPrimary,
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Debounced writer ─────────────────────────

/// Coalesces rapid writes (slider drags, stepper bursts) into one trailing
/// write carrying the LAST value — the page updates live from state while
/// persistence/side effects fire once. Never loses the last value: [flush]
/// runs it synchronously (call from dispose).
class DebouncedWriter {
  DebouncedWriter({required this.delay});

  final Duration delay;
  Timer? _timer;
  Future<void> Function()? _pending;

  void schedule(Future<void> Function() write) {
    _pending = write;
    _timer?.cancel();
    _timer = Timer(delay, () {
      final pending = _pending;
      _pending = null;
      pending?.call();
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    final pending = _pending;
    _pending = null;
    if (pending != null) await pending();
  }

  void dispose() {
    _timer?.cancel();
    _pending = null;
  }
}
