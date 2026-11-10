import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class ApplicationSection extends StatelessWidget {
  final String application;
  const ApplicationSection({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    if (application.isEmpty) return const SizedBox.shrink();

    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: success.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: success),
              const SizedBox(width: 6),
              Text('کاربرد عملی',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(application,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  height: 1.6,
                  color: t.textMuted)),
        ],
      ),
    );
  }
}
