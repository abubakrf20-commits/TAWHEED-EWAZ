import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class GenderToggle extends StatelessWidget {
  final bool isMale;
  final ValueChanged<bool> onChanged;

  const GenderToggle(
      {super.key, required this.isMale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => onChanged(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isMale ? TopicHues.inheritance : Colors.transparent,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(6)),
              ),
              child: Text('مرد',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w700,
                      color: isMale
                          ? Colors.white
                          : TimeThemeKit.of(context).palette.textMuted)),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: !isMale ? TopicHues.inheritance : Colors.transparent,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(6)),
              ),
              child: Text('زن',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w700,
                      color: !isMale
                          ? Colors.white
                          : TimeThemeKit.of(context).palette.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}
