import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';

class NumberedCard extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  final int total;
  final Color accentColor;
  final Color? boxColor;

  const NumberedCard({
    super.key,
    required this.number,
    required this.title,
    required this.body,
    required this.total,
    this.accentColor = const Color(0xFF1565C0),
    this.boxColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final color = boxColor ?? accentColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w800,
                    color: dsContentColor(context, color),
                  ),
                ),
              ),
            ),
            if (number < total)
              Container(
                  width: 2, height: 20, color: color.withValues(alpha: 0.15)),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: t.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  title,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: color.withValues(alpha: 0.1)),
                const SizedBox(height: 8),
                SelectableText(
                  body,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: t.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
