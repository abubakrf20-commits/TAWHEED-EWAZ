import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';

/// Full-text reader for one of the book's front-matter sections
/// (مقدمه‌های حصن المسلم) — same unified cream card as the detail screen.
class HesnIntroReaderScreen extends StatelessWidget {
  final HesnSection section;
  const HesnIntroReaderScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B1F2A) : const Color(0xFFFDF6EC);
    final border =
        isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFE3D6BE);
    final divider =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFEADFC9);
    final chipBg =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0E6D2);
    final chipText = isDark ? Colors.white : const Color(0xFF5A4632);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'مقدمات کتاب'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border, width: 1.4),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: divider, width: 1.2),
                      ),
                      child: Text(
                        '📖 ${section.title}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w800,
                          color: chipText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  section.body.trim(),
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    height: 2.0,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : const Color(0xFF2A2A2A),
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
