import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/yaqeen/data/yaqeen_content.dart';

/// کارت درس در فهرست‌ها (نتایج جستجو و صفحهٔ مسیر).
class YaqeenLessonTile extends StatelessWidget {
  final YaqeenLesson lesson;
  final bool read;
  final String? subtitle;
  final VoidCallback onTap;

  const YaqeenLessonTile({
    super.key,
    required this.lesson,
    required this.read,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    const accent = TopicHues.yaqeen;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: read
              ? success.withValues(alpha: 0.15)
              : accent.withValues(alpha: 0.12),
          child: Icon(
            read ? Icons.check : Icons.menu_book_outlined,
            size: 18,
            color: read ? success : accent,
          ),
        ),
        title: Text(
          lesson.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: AppTheme.scaledFontSize(context, 13),
            decoration: read ? TextDecoration.lineThrough : null,
            color: read ? t.textMuted : null,
          ),
        ),
        subtitle: Text(
          subtitle ?? lesson.excerpt,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 11)),
        ),
        trailing: Icon(Icons.chevron_left, size: 20, color: t.textMuted),
      ),
    );
  }
}
