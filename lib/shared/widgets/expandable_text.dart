import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// متن بلند: در حالت جمع‌شده تا [maxLines] خط با ellipsis نشان داده می‌شود و
/// با یک کلیک (یا لمس خطِ «بیشتر») کامل باز می‌شود. اگر متن کوتاه باشد بدون
/// هیچ کلیکی همان‌طور کامل رندر می‌شود.
///
/// بین چند بخش برنامه (پیشنهادها و پیام‌های مدیریت) مشترک است تا رفتار یکسان
/// بمانند.
class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text,
      {super.key, required this.maxLines, this.style, this.textAlign});

  final String text;
  final int maxLines;
  final TextStyle? style;

  /// Alignment of the text lines (the tasbih dhikr title is centered).
  /// Null keeps the default start alignment everywhere else.
  final TextAlign? textAlign;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _overflows(context, style, constraints.maxWidth);
        if (!overflows) {
          return Text(widget.text, style: style, textAlign: widget.textAlign);
        }
        return InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.text,
                  style: style,
                  textAlign: widget.textAlign,
                  maxLines: _expanded ? null : widget.maxLines,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: t.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _expanded ? 'بستن' : 'بیشتر',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w700,
                            color: t.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _overflows(BuildContext context, TextStyle style, double maxWidth) {
    if (widget.text.trim().isEmpty) return false;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: widget.maxLines,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}
