import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_collection_kit.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_palette.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_session_controller.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

/// «فهرست» — the section's familiar list, refined.
///
/// Every card keeps the anatomy the section always had (completion control,
/// number, title, Arabic block, translation, virtue, source, share/copy) and
/// gains the two things the mode spec asked for: a counter pill with a «+»
/// button for counted adhkar, and a completed state drawn with a green
/// hairline instead of an opacity widget.
class DhikrListView extends StatelessWidget {
  const DhikrListView({
    super.key,
    required this.controller,
    required this.tone,
    required this.showArabic,
    required this.arabicSize,
    required this.highlightQuery,
    required this.onShare,
    required this.haptics,
    required this.onCompleteCurrent,
    this.itemScrollController,
  });

  final DhikrSessionController controller;
  final DhikrTone tone;
  final bool showArabic;
  final double arabicSize;
  final String highlightQuery;
  final void Function(ZikrItem item) onShare;

  /// «لرزش هنگام شمارش و تکمیل».
  final bool haptics;

  /// Called ONCE, when an action on this card actually finished a dhikr.
  ///
  /// The list has no advance button of its own, so this is how a finished card
  /// stops leaving the reader parked on it — the page owns the single cursor
  /// move, the same one the other two modes ask for.
  final VoidCallback onCompleteCurrent;

  /// Exact index jumps (search focus, «refocus the current item»): a plain
  /// [ScrollController] can only approximate a position, and landing 24 cards
  /// off is exactly what the focus jump exists to avoid.
  final ItemScrollController? itemScrollController;

  @override
  Widget build(BuildContext context) {
    final items = controller.items;
    return ScrollablePositionedList.builder(
      itemScrollController: itemScrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RepaintBoundary(
            child: DhikrListCard(
              // The historical key shape stays: it is what the scroll/focus
              // guards identify a card by.
              key: ValueKey('${item.id}_${controller.isDone(index)}'),
              item: item,
              index: index,
              tone: tone,
              count: controller.countOf(index),
              target: controller.targetAt(index),
              isDone: controller.isDone(index),
              showArabic: showArabic,
              arabicSize: arabicSize,
              highlightQuery: highlightQuery,
              onIncrement: () {
                if (haptics) HapticFeedback.lightImpact();
                final finished = controller.tap(index);
                if (!finished) return;
                if (haptics) HapticFeedback.mediumImpact();
                onCompleteCurrent();
              },
              onToggle: () {
                if (haptics) HapticFeedback.lightImpact();
                if (controller.setDone(index, !controller.isDone(index))) {
                  onCompleteCurrent();
                }
              },
              onComplete: () {
                if (haptics) HapticFeedback.mediumImpact();
                if (controller.complete(index)) onCompleteCurrent();
              },
              onShare: () => onShare(item),
            ),
          ),
        );
      },
    );
  }
}

/// One dhikr card in list mode.
class DhikrListCard extends StatelessWidget {
  const DhikrListCard({
    super.key,
    required this.item,
    required this.index,
    required this.tone,
    required this.count,
    required this.target,
    required this.isDone,
    required this.showArabic,
    required this.arabicSize,
    required this.highlightQuery,
    required this.onIncrement,
    required this.onToggle,
    required this.onComplete,
    required this.onShare,
  });

  final ZikrItem item;
  final int index;
  final DhikrTone tone;
  final int count;
  final int target;
  final bool isDone;
  final bool showArabic;
  final double arabicSize;
  final String highlightQuery;
  final VoidCallback onIncrement;
  final VoidCallback onToggle;
  final VoidCallback onComplete;
  final VoidCallback onShare;

  bool get _counted => target > 1;

  List<InlineSpan> _spans(BuildContext context, String text, TextStyle? style) {
    if (highlightQuery.trim().isEmpty) {
      return [TextSpan(text: text, style: style)];
    }
    return TextHighlight.spans(
      text,
      highlightQuery,
      baseStyle: style,
      highlightStyle: TextHighlight.defaultHighlightStyle(context, base: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDone ? tone.success.withValues(alpha: 0.45) : tone.border,
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_counted)
                // The pill and its «+» must give way on a 320dp card at a 1.3
                // text scale, where the title, the badge and two icon buttons
                // already fill the row.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _CountedControl(
                      tone: tone,
                      count: count,
                      target: target,
                      done: isDone,
                      onIncrement: onIncrement,
                      onComplete: onComplete,
                    ),
                  ),
                )
              else
                _CompletionCircle(
                  tone: tone,
                  done: isDone,
                  onTap: onToggle,
                ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.gold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  NumberFormat.ltrIsolated('${index + 1}'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w700,
                    color: AppColors.strongAccent(context, tone.gold),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: _spans(
                      context,
                      item.title,
                      TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? AppColors.textMuted(context)
                            : AppColors.strongAccent(context, tone.gold),
                      ),
                    ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(width: 6),
              DhikrIconButton(
                icon: Icons.copy_outlined,
                tone: tone,
                tooltip: 'کپی متن',
                onPressed: () => copyDhikr(context, item),
              ),
              const SizedBox(width: 6),
              DhikrIconButton(
                icon: Icons.share_outlined,
                tone: tone,
                tooltip: 'اشتراک‌گذاری',
                onPressed: onShare,
              ),
            ],
          ),
          if (showArabic && item.arabicText.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            DhikrArabicBox(
              item: item,
              tone: tone,
              scaled: arabicSize,
              muted: isDone,
            ),
          ],
          if (item.translation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: _spans(
                  context,
                  item.translation,
                  TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    height: 1.95,
                    color: isDone
                        ? AppColors.textMuted(context)
                        : AppColors.textSecondary(context),
                  ),
                ),
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
          if (item.virtue.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            DhikrNoteChip(
              text: item.virtue,
              tone: tone,
              size: AppTheme.scaledFontSize(context, 12),
            ),
          ],
          if (item.source.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            DhikrSourceChip(
              text: item.source,
              tone: tone,
              size: AppTheme.scaledFontSize(context, 11),
            ),
          ],
        ],
      ),
    );
  }
}

/// The 30dp circle for a dhikr said once.
class _CompletionCircle extends StatelessWidget {
  const _CompletionCircle({
    required this.tone,
    required this.done,
    required this.onTap,
  });

  final DhikrTone tone;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'لغو انجام' : 'انجام شد',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? tone.success : Colors.transparent,
            border: Border.all(
              color: done ? tone.success : DhikrPalette.hairline,
              width: 1.5,
            ),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// The counted dhikr's control: «2/3» pill, a navy «+», and «تکمیل» once the
/// reader would rather tick it off than tap through the remaining repeats.
class _CountedControl extends StatelessWidget {
  const _CountedControl({
    required this.tone,
    required this.count,
    required this.target,
    required this.done,
    required this.onIncrement,
    required this.onComplete,
  });

  final DhikrTone tone;
  final int count;
  final int target;
  final bool done;
  final VoidCallback onIncrement;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tone.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 14, color: tone.success),
            const SizedBox(width: 3),
            Text(
              NumberFormat.fraction(target, target),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10.5),
                fontWeight: FontWeight.w700,
                color: tone.success,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'شمارنده، ${NumberFormat.fraction(count, target)}',
          child: GestureDetector(
            onTap: onComplete,
            onLongPress: onComplete,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: DhikrPalette.goldTint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                NumberFormat.fraction(count, target),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10.5),
                  fontWeight: FontWeight.w700,
                  color: AppColors.strongAccent(context, tone.gold),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Semantics(
          button: true,
          label: 'یک بار افزودن',
          child: Material(
            color: DhikrPalette.navy,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onIncrement,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(Icons.add_rounded,
                    size: 19, color: DhikrPalette.cream),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
