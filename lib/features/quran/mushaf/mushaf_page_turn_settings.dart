import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_page_turn.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';

/// «افکت ورق‌زدن» — the reading-settings section that picks the turn.
///
/// It lives in its own file because the sheet is already long: the section owns
/// the three cards, their thumbnails, the preview and the two switches, and the
/// reader only supplies the current values and the callbacks that persist them.
class MushafPageTurnSection extends StatelessWidget {
  const MushafPageTurnSection({
    super.key,
    required this.palette,
    required this.selected,
    required this.speed,
    required this.haptic,
    required this.reduceMotion,
    required this.onSelected,
    required this.onSpeed,
    required this.onHaptic,
  });

  final MushafPalette palette;
  final MushafPageTurn selected;
  final MushafTurnSpeed speed;
  final bool haptic;

  /// The system asks for reduced motion: the cards stay visible (the reader's
  /// choice is kept) but disabled, and the note explains why.
  final bool reduceMotion;

  final ValueChanged<MushafPageTurn> onSelected;
  final ValueChanged<MushafTurnSpeed> onSpeed;
  final ValueChanged<bool> onHaptic;

  static const double cardHeight = 72;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: AppTheme.scaledFontSize(context, 12),
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('افکت ورق‌زدن',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w700,
                color: palette.surfaceMuted,
              )),
        ),
        Row(
          children: [
            for (var i = 0; i < MushafPageTurn.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _TurnCard(
                  palette: palette,
                  turn: MushafPageTurn.values[i],
                  selected: selected == MushafPageTurn.values[i],
                  enabled: !reduceMotion,
                  textStyle: textStyle,
                  onTap: () => onSelected(MushafPageTurn.values[i]),
                ),
              ),
            ],
          ],
        ),
        if (reduceMotion)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'با فعال بودن کاهش حرکت سیستم، افکت ساده استفاده می‌شود.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10.5),
                color: palette.surfaceMuted,
              ),
            ),
          ),
        const SizedBox(height: 10),
        _PreviewBar(
          palette: palette,
          turn: selected,
          speed: speed,
          enabled: !reduceMotion,
          previewLabelStyle: textStyle,
        ),
        const SizedBox(height: 10),
        _SpeedPicker(
          palette: palette,
          speed: speed,
          onChanged: onSpeed,
        ),
        _HapticSwitch(
          palette: palette,
          value: haptic,
          onChanged: onHaptic,
        ),
      ],
    );
  }
}

/// One of the three turns: a thumbnail of the page shape and its name.
class _TurnCard extends StatelessWidget {
  const _TurnCard({
    required this.palette,
    required this.turn,
    required this.selected,
    required this.enabled,
    required this.textStyle,
    required this.onTap,
  });

  final MushafPalette palette;
  final MushafPageTurn turn;
  final bool selected;
  final bool enabled;
  final TextStyle textStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? palette.chrome : palette.surface;
    final ink = selected ? palette.onChrome : palette.surfaceText;
    return Opacity(
      // Reduced motion keeps the card readable but unmistakably inert.
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            height: MushafPageTurnSection.cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? palette.accent.withValues(alpha: 0.65)
                    : palette.border,
                width: selected ? 1 : 0.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 34,
                  height: 26,
                  child: CustomPaint(
                    painter: MushafTurnThumbPainter(
                      turn: turn,
                      ink: ink,
                      paper: selected ? palette.chrome : palette.surface,
                      accent: selected ? palette.accent : palette.surfaceMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  turn.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tiny page shapes on the cards: flat sheet, curved leaf, rolled edge.
class MushafTurnThumbPainter extends CustomPainter {
  const MushafTurnThumbPainter({
    required this.turn,
    required this.ink,
    required this.paper,
    required this.accent,
  });

  final MushafPageTurn turn;
  final Color ink;
  final Color paper;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ink.withValues(alpha: 0.55);
    final fill = Paint()..color = paper;

    Rect page(Rect r) => r;
    switch (turn) {
      case MushafPageTurn.plain:
        final back = page(Rect.fromLTWH(0, 4, size.width * 0.66, size.height));
        final front = page(
            Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.66, size.height));
        canvas.drawRect(back, fill);
        canvas.drawRect(back, outline);
        canvas.drawRect(front, fill);
        canvas.drawRect(front, outline);
      case MushafPageTurn.bookFlip:
        final leaf = Path()
          ..moveTo(size.width, 0)
          ..cubicTo(size.width * 0.55, size.height * 0.08, size.width * 0.2,
              size.height * 0.42, 0, size.height)
          ..lineTo(0, size.height * 0.2)
          ..cubicTo(size.width * 0.4, size.height * 0.1, size.width * 0.7, 0,
              size.width, 0)
          ..close();
        canvas.drawPath(leaf, fill);
        canvas.drawPath(leaf, outline);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), outline);
    }
  }

  @override
  bool shouldRepaint(MushafTurnThumbPainter old) =>
      old.turn != turn ||
      old.ink != ink ||
      old.paper != paper ||
      old.accent != accent;
}

/// «پیش‌نمایش» — plays the chosen turn once on two paper thumbnails.
///
/// No mushaf is rendered here: the preview draws paper sheets, so it costs
/// nothing and can never disagree with the glyph layer.
class _PreviewBar extends StatefulWidget {
  const _PreviewBar({
    required this.palette,
    required this.turn,
    required this.speed,
    required this.enabled,
    required this.previewLabelStyle,
  });

  final MushafPalette palette;
  final MushafPageTurn turn;
  final MushafTurnSpeed speed;
  final bool enabled;
  final TextStyle previewLabelStyle;

  @override
  State<_PreviewBar> createState() => _PreviewBarState();
}

class _PreviewBarState extends State<_PreviewBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.speed.millis),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PreviewBar old) {
    super.didUpdateWidget(old);
    _c.duration = Duration(milliseconds: widget.speed.millis);
    if (old.turn != widget.turn && _c.isAnimating) {
      _c.forward(from: 0);
    }
  }

  void _play() {
    if (!widget.enabled) return;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          height: 44,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: MushafTurnPreviewPainter(
                turn: widget.turn,
                progress: _c.value,
                palette: widget.palette,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // The pill, not a filled button: it is a demonstration, not a save.
        // Flexible at the ROW level: a Row hands its children unbounded width,
        // and the button's own padding cannot size against infinity.
        Flexible(
          child: OutlinedButton.icon(
            onPressed: widget.enabled ? _play : null,
            icon: Icon(Icons.play_arrow_rounded,
                size: 18, color: widget.palette.accent),
            label: Text('پیش‌نمایش',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.previewLabelStyle
                    .copyWith(color: widget.palette.surfaceText)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(color: widget.palette.border),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The preview's two sheets, drawn with the very angles the reader will see.
class MushafTurnPreviewPainter extends CustomPainter {
  const MushafTurnPreviewPainter({
    required this.turn,
    required this.progress,
    required this.palette,
  });

  final MushafPageTurn turn;
  final double progress;
  final MushafPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final under = Rect.fromLTWH(2, 4, size.width - 8, size.height - 8);
    canvas.drawRRect(RRect.fromRectAndRadius(under, const Radius.circular(3)),
        Paint()..color = palette.surface);
    canvas.drawRRect(
        RRect.fromRectAndRadius(under, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = palette.border);

    final p = progress.clamp(0.0, 1.0);
    if (turn == MushafPageTurn.plain || p == 0 || p == 1) {
      return;
    }
    const strips = 5;
    final angles = mushafTurnStripAngles(mode: turn, p: p, strips: strips);
    final stripW = under.width / strips;
    canvas.save();
    canvas.clipRect(under);
    canvas.translate(under.right, under.top);
    final perspective = Matrix4.identity()..setEntry(3, 2, kMushafTurnCamera);
    for (var k = 0; k < strips; k++) {
      final a = angles[k];
      final dest = Rect.fromLTWH(-stripW, 0, stripW, under.height);
      canvas.save();
      canvas.transform(perspective.storage);
      canvas.transform((Matrix4.identity()..rotateY(-a)).storage);
      final back = a > math.pi / 2 && a < 3 * math.pi / 2;
      canvas.drawRect(
        dest,
        Paint()
          ..color = back ? mushafLeafBackOn(palette.surface) : palette.surface,
      );
      final shade = math.min(0.5, math.sin(a).abs() * 0.5);
      if (shade > 0.002) {
        canvas.drawRect(
            dest, Paint()..color = palette.chrome.withValues(alpha: shade));
      }
      canvas.restore();
      canvas.translate(-stripW, 0);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MushafTurnPreviewPainter old) =>
      old.turn != turn || old.progress != progress || old.palette != palette;
}

/// «سرعت» — three segments, the shared pill shape.
class _SpeedPicker extends StatelessWidget {
  const _SpeedPicker({
    required this.palette,
    required this.speed,
    required this.onChanged,
  });

  final MushafPalette palette;
  final MushafTurnSpeed speed;
  final ValueChanged<MushafTurnSpeed> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('سرعت',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11.5),
                  color: palette.surfaceMuted,
                )),
          ),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.border, width: 0.5),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                for (final s in MushafTurnSpeed.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(s),
                      child: Container(
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              speed == s ? palette.chrome : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          s.label,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11.5),
                            fontWeight: FontWeight.w600,
                            color: speed == s
                                ? palette.onChrome
                                : palette.surfaceText,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «لرزش ملایم هنگام ورق‌زدن».
class _HapticSwitch extends StatelessWidget {
  const _HapticSwitch({
    required this.palette,
    required this.value,
    required this.onChanged,
  });

  final MushafPalette palette;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      activeTrackColor: palette.accent,
      title: Text('لرزش ملایم هنگام ورق‌زدن',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11.5),
            color: palette.surfaceText,
          )),
    );
  }
}
