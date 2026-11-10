import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

class ZikrCard extends ConsumerWidget {
  final ZikrItem zikr;
  final int index;
  final bool isCompleted;
  final VoidCallback? onToggle;

  const ZikrCard({
    super.key,
    required this.zikr,
    required this.index,
    this.isCompleted = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final warning = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final isDone = isCompleted;
    // Display settings from «فونت و نمایش» — the same three the duas list
    // already honors.
    final showArabicText = ref.watch(showArabicTextProvider);
    final showDaleel = ref.watch(showDaleelProvider);
    final arabicFontSize = ref.watch(largeArabicFontProvider) ? 22.0 : 18.0;

    return Semantics(
      label: zikr.repeatCount > 1
          ? '${zikr.title} - ${zikr.repeatCount} بار'
          : zikr.title,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDone
              ? AppTheme.doneColor.withValues(alpha: 0.06)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone
                ? AppTheme.doneColor.withValues(alpha: 0.25)
                : isDark
                    ? t.surfaceMuted
                    : t.surfaceMuted.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onToggle != null)
                    Semantics(
                      button: true,
                      label: 'ذکر: ${zikr.title}',
                      child: GestureDetector(
                        onTap: onToggle,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppTheme.doneColor
                                : t.primary
                                    .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            isDone ? Icons.check : Icons.check_circle_outline,
                            size: 22,
                            color: isDone
                                ? Colors.white
                                : t.primary,
                          ),
                        ),
                      ),
                    ),
                  if (onToggle != null) const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      zikr.title,
                      style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 15),
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? t.textMuted
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ],
              ),
              if (showArabicText && zikr.arabicText.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? t.surfaceMuted.withValues(alpha: 0.5)
                        : t.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    zikr.arabicText,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:
                          AppTheme.scaledFontSize(context, arabicFontSize),
                      height: 2.0,
                      color: isDone
                          ? t.textMuted
                          : isDark
                              ? t.outline
                              : const Color(0xFF2C2C2C),
                    ),
                  ),
                ),
              ],
              if (zikr.translation.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  zikr.translation,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    height: 1.8,
                    color: isDone
                        ? t.textMuted
                        : isDark
                            ? t.textMuted
                            : t.textPrimary,
                  ),
                ),
              ],
              if (showDaleel && zikr.daleel.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.star_outline,
                          size: 16, color: t.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          zikr.daleel,
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            height: 1.7,
                            color: t.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 13, color: t.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      zikr.source,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: t.textMuted),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy,
                        size: 16, color: t.textMuted),
                    tooltip: 'کپی متن ذکر',
                    onPressed: () {
                      final text =
                          '${zikr.title}\n${zikr.arabicText}\n${zikr.translation}${zikr.daleel.isNotEmpty ? '\n${zikr.daleel}' : ''}\n${zikr.source}';
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('کپی شد'),
                          duration: Duration(seconds: 1)));
                    },
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  if (zikr.repeatCount > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: warning
                                .withValues(alpha: 0.5),
                            width: 0.5),
                      ),
                      child: Text(
                        '× ${zikr.repeatCount}',
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              if (!isDone && onToggle != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onToggle,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            t.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: t.primary
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 18, color: t.primary),
                          const SizedBox(width: 6),
                          Text('انجام دادم',
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 13),
                                  color: t.primary,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
