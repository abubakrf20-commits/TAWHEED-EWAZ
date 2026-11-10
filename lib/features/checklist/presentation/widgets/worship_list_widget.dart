import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';
import 'package:tawheeed/features/worship/presentation/utils/worship_colors.dart';
import 'package:tawheeed/features/worship/presentation/widgets/worship_item_dialogs.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The daily worship checklist card.
///
/// A thin progress strip sits on top, followed by the worship items — each one
/// a tappable row with an animated check indicator and a points badge. A
/// long-press hides/deletes an item; the footer button adds a new one.
class WorshipListWidget extends StatefulWidget {
  const WorshipListWidget({super.key});

  @override
  State<WorshipListWidget> createState() => _WorshipListWidgetState();
}

class _WorshipListWidgetState extends State<WorshipListWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(evaluationProvider).value;
        final notifier = ref.read(evaluationProvider.notifier);
        final items = state?.worshipItems ?? [];
        final done = items.where((i) => i.done).length;
        final total = items.length;
        final fraction = total == 0 ? 0.0 : done / total;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final t = TimeThemeKit.of(context).palette;
        final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
        final allDone = total > 0 && done == total;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
                color: t.outline.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusLarge)),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 4,
                  backgroundColor:
                      t.primary.withValues(alpha: 0.08),
                  color: allDone
                      ? success
                      : t.tertiary,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => _WorshipTile(
                    item: item,
                    onTap: () => notifier.toggleWorship(item.id),
                    onLongPress: () =>
                        showDeleteWorshipItemDialog(context, notifier, item),
                    isExcluded: notifier.isWorshipExcluded(item.id),
                    onExclude: () => notifier.toggleExcludeWorship(item.id),
                  )),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      showAddWorshipItemDialog(context, notifier),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text('افزودن طاعت جدید',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 12))),
                  style: TextButton.styleFrom(
                      foregroundColor: t.primary),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

class _WorshipTile extends StatelessWidget {
  final WorshipItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isExcluded;
  final VoidCallback? onExclude;

  const _WorshipTile(
      {required this.item,
      required this.onTap,
      required this.onLongPress,
      this.isExcluded = false,
      this.onExclude});

  @override
  Widget build(BuildContext context) {
    // Each worship has its own content-matched color (see WorshipColors);
    // checking it flips to the success green as the done state.
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final itemColor = WorshipColors.forItem(item.id, item.icon);
    final accent = item.done ? success : itemColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: item.done
              ? success.withValues(alpha: 0.06)
              : t.surfaceMuted.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.done
                ? success.withValues(alpha: 0.25)
                : t.outline.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.done
                        ? success.withValues(alpha: 0.14)
                        : accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: item.done ? FontWeight.w500 : FontWeight.w600,
                      color: item.done
                          ? t.textMuted
                          : t.textPrimary,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                      decorationColor: t.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (item.points > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: item.done ? 0.14 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${item.points}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: item.done
                      ? Icon(Icons.check_circle,
                          key: const ValueKey('check'),
                          size: 22,
                          color: success)
                      : Icon(Icons.radio_button_unchecked,
                          key: const ValueKey('uncheck'),
                          size: 22,
                          color: t.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
