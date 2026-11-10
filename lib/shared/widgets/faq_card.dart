import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/theme/theme.dart';

class FaqCard extends StatefulWidget {
  final int number;
  final String question;
  final String answer;
  final int total;
  final Color accentColor;

  const FaqCard({
    super.key,
    required this.number,
    required this.question,
    required this.answer,
    required this.total,
    this.accentColor = const Color(0xFF1565C0),
  });

  @override
  State<FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final color = widget.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? color.withValues(alpha: 0.3)
              : (t.outline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${widget.number}',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.question,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: t.textMuted,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: double.infinity,
                      height: 1,
                      color: color.withValues(alpha: 0.1)),
                  const SizedBox(height: 10),
                  SelectableText(
                    widget.answer,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      height: 1.65,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
