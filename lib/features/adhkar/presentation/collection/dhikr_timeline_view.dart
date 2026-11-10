import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_collection_kit.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_palette.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_session_controller.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «تایم‌لاین» — the collection as one line of the day.
///
/// The rail runs down the START edge (the right on an RTL screen), the finished
/// part of it in the success green, and the item being said is the only full
/// card: everything below it is a one-line title. Tapping a collapsed row
/// makes it the current item, so the reader can go back to a finished dhikr
/// without leaving the mode.
class DhikrTimelineView extends StatelessWidget {
  const DhikrTimelineView({
    super.key,
    required this.controller,
    required this.tone,
    required this.showArabic,
    required this.arabicSize,
    required this.onShare,
    required this.onCompleteCurrent,
    required this.haptics,
    this.scrollController,
  });

  final DhikrSessionController controller;
  final DhikrTone tone;
  final bool showArabic;
  final double arabicSize;
  final void Function(ZikrItem item) onShare;
  final VoidCallback onCompleteCurrent;
  final bool haptics;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final items = controller.items;
    final current = controller.currentIndex;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DhikrProgressCard(
              tone: tone,
              done: controller.doneCount,
              total: controller.length,
              compact: true,
            ),
          );
        }
        final i = index - 1;
        final state = controller.isDone(i)
            ? _TimelineState.done
            : (i == current
                ? _TimelineState.current
                : (controller.isSkipped(i)
                    ? _TimelineState.skipped
                    : _TimelineState.upcoming));
        return RepaintBoundary(
          child: _TimelineRow(
            key: ValueKey('dhikr-tl-${items[i].id}'),
            index: i,
            item: items[i],
            state: state,
            tone: tone,
            showArabic: showArabic,
            arabicSize: arabicSize,
            count: controller.countOf(i),
            target: controller.targetAt(i),
            isLast: i == items.length - 1,
            onGoTo: () => controller.goTo(i),
            onIncrement: () {
              if (haptics) HapticFeedback.lightImpact();
              final finished = controller.tap(i);
              if (finished) {
                if (haptics) HapticFeedback.mediumImpact();
                onCompleteCurrent();
              }
            },
            onComplete: () {
              if (haptics) HapticFeedback.mediumImpact();
              if (controller.complete(i)) onCompleteCurrent();
            },
            onShare: () => onShare(items[i]),
          ),
        );
      },
    );
  }
}

enum _TimelineState { done, current, upcoming, skipped }

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    super.key,
    required this.index,
    required this.item,
    required this.state,
    required this.tone,
    required this.showArabic,
    required this.arabicSize,
    required this.count,
    required this.target,
    required this.isLast,
    required this.onGoTo,
    required this.onIncrement,
    required this.onComplete,
    required this.onShare,
  });

  final int index;
  final ZikrItem item;
  final _TimelineState state;
  final DhikrTone tone;
  final bool showArabic;
  final double arabicSize;
  final int count;
  final int target;
  final bool isLast;
  final VoidCallback onGoTo;
  final VoidCallback onIncrement;
  final VoidCallback onComplete;
  final void Function() onShare;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(
            state: state,
            tone: tone,
            index: index,
            isLast: isLast,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: switch (state) {
                _TimelineState.current => _CurrentCard(
                    item: item,
                    tone: tone,
                    showArabic: showArabic,
                    arabicSize: arabicSize,
                    count: count,
                    target: target,
                    onIncrement: onIncrement,
                    onComplete: onComplete,
                    onShare: onShare,
                  ),
                _TimelineState.done => _CollapsedRow(
                    title: item.title,
                    tone: tone,
                    muted: true,
                    trailing: 'انجام شد',
                    trailingColor: tone.success,
                    onTap: onGoTo,
                  ),
                _TimelineState.skipped => _CollapsedRow(
                    title: item.title,
                    tone: tone,
                    muted: true,
                    trailing: 'رد شده',
                    trailingColor: AppColors.textMuted(context),
                    onTap: onGoTo,
                  ),
                _TimelineState.upcoming => _CollapsedRow(
                    title: item.title,
                    tone: tone,
                    muted: false,
                    trailing: null,
                    trailingColor: null,
                    onTap: onGoTo,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The rail: a 2dp line with the node for this row sitting on it.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.state,
    required this.tone,
    required this.index,
    required this.isLast,
  });

  final _TimelineState state;
  final DhikrTone tone;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final idle = DhikrPalette.railIdle.withValues(alpha: tone.isDark ? .35 : 1);
    final passed = state == _TimelineState.done;
    return SizedBox(
      width: 34,
      child: Column(
        children: [
          Container(width: 2, height: 6, color: index == 0 ? idle : (passed ? tone.success : idle)),
          _Node(state: state, tone: tone, index: index),
          Expanded(
            child: Container(
              width: 2,
              color: isLast
                  ? Colors.transparent
                  : (state == _TimelineState.done ? tone.success : idle),
            ),
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.state,
    required this.tone,
    required this.index,
  });

  final _TimelineState state;
  final DhikrTone tone;
  final int index;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.ltrIsolated('${index + 1}');
    return switch (state) {
      _TimelineState.done => Semantics(
          label: 'انجام شد',
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: tone.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
          ),
        ),
      _TimelineState.current => Semantics(
          label: 'ذکر فعلی',
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DhikrPalette.goldTint,
              shape: BoxShape.circle,
              border: Border.all(color: tone.gold, width: 2.5),
            ),
            child: Text(
              number,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                fontWeight: FontWeight.w800,
                color: AppColors.strongAccent(context, tone.gold),
              ),
            ),
          ),
        ),
      _TimelineState.skipped => Semantics(
          label: 'رد شده',
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.card,
              border: Border.all(
                color: tone.isDark
                    ? Colors.white24
                    : AppColors.textMuted(context),
                width: 1.2,
              ),
            ),
            child: Text(
              number,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 8),
                color: AppColors.textMuted(context),
              ),
            ),
          ),
        ),
      _TimelineState.upcoming => Semantics(
          label: 'در انتظار',
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.card,
              shape: BoxShape.circle,
              border: Border.all(color: DhikrPalette.railIdle, width: 1.5),
            ),
            child: Text(
              number,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 8),
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted(context),
              ),
            ),
          ),
        ),
    };
  }
}

class _CollapsedRow extends StatelessWidget {
  const _CollapsedRow({
    required this.title,
    required this.tone,
    required this.muted,
    required this.trailing,
    required this.trailingColor,
    required this.onTap,
  });

  final String title;
  final DhikrTone tone;
  final bool muted;
  final String? trailing;
  final Color? trailingColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tone.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tone.border, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    color: muted
                        ? AppColors.textMuted(context)
                        : AppColors.textSecondary(context),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (trailingColor ?? tone.gold).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trailing!,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w600,
                      color: trailingColor,
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

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({
    required this.item,
    required this.tone,
    required this.showArabic,
    required this.arabicSize,
    required this.count,
    required this.target,
    required this.onIncrement,
    required this.onComplete,
    required this.onShare,
  });

  final ZikrItem item;
  final DhikrTone tone;
  final bool showArabic;
  final double arabicSize;
  final int count;
  final int target;
  final VoidCallback onIncrement;
  final VoidCallback onComplete;
  final void Function() onShare;

  @override
  Widget build(BuildContext context) {
    final counted = target > 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tone.gold.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.title,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13.5),
              fontWeight: FontWeight.w700,
              color: AppColors.strongAccent(context, tone.gold),
            ),
          ),
          if (showArabic && item.arabicText.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            DhikrArabicBox(item: item, tone: tone, scaled: arabicSize),
          ],
          if (item.translation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.translation,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                height: 1.95,
                color: AppColors.textSecondary(context),
              ),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: counted
                      ? 'یک بار افزودن، ${NumberFormat.fraction(count, target)}'
                          ' · $kDhikrHoldToRegister'
                      : 'خواندم و بعدی',
                  child: Material(
                    color: DhikrPalette.navy,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: counted ? onIncrement : onComplete,
                      onLongPress: counted ? onComplete : null,
                      child: SizedBox(
                        height: 42,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded,
                                size: 17, color: DhikrPalette.cream),
                            const SizedBox(width: 6),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  counted
                                      ? '+1  (${NumberFormat.fraction(count, target)})'
                                      : 'خواندم · برو بعدی',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w600,
                                    color: DhikrPalette.cream,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DhikrIconButton(
                icon: Icons.share_outlined,
                tone: tone,
                tooltip: 'اشتراک‌گذاری',
                size: 42,
                onPressed: onShare,
              ),
              const SizedBox(width: 8),
              DhikrIconButton(
                icon: Icons.copy_outlined,
                tone: tone,
                tooltip: 'کپی متن',
                size: 42,
                onPressed: () => copyDhikr(context, item),
              ),
            ],
          ),
          if (counted) ...[
            const SizedBox(height: 8),
            Text(
              kDhikrHoldToRegister,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 10.5),
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
