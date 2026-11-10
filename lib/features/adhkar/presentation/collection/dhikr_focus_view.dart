import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/ring.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_collection_kit.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_palette.dart';
import 'package:tawheeed/features/adhkar/presentation/collection/dhikr_session_controller.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// «تمرکز» — one dhikr at a time with a big ring to count on.
///
/// Nothing here decides policy: the ring taps go to the controller through
/// [onTapRing], a held ring registers the whole target through [onCompleteAll],
/// undo through [onUndo], skipping through [onSkip], and both swipes reuse
/// [onPrevious] / [onNext] — the same two doors the pills offer, so a gesture
/// can never step the cursor somewhere the buttons would not. The page owns the
/// haptics and the auto-advance delay, so all three modes behave the same way
/// when the last repetition lands.
class DhikrFocusView extends StatelessWidget {
  const DhikrFocusView({
    super.key,
    required this.controller,
    required this.tone,
    required this.showArabic,
    required this.arabicSize,
    required this.autoAdvance,
    required this.onShare,
    required this.onTapRing,
    required this.onCompleteAll,
    required this.onUndo,
    required this.onSkip,
    required this.onPrevious,
    required this.onNext,
    required this.onRevisitSkipped,
    required this.onRestart,
  });

  final DhikrSessionController controller;
  final DhikrTone tone;
  final bool showArabic;
  final double arabicSize;
  final bool autoAdvance;
  final void Function(ZikrItem item) onShare;
  final VoidCallback onTapRing;

  /// Registers every remaining repetition at once — the one tick a dhikr of
  /// «صد بار» needs, and the reason a held ring is not just a faster tap.
  final VoidCallback onCompleteAll;
  final VoidCallback onUndo;
  final VoidCallback onSkip;
  final VoidCallback onPrevious;

  /// Used when «رفتن خودکار» is off: the finished item waits for a tap.
  final VoidCallback onNext;
  final VoidCallback onRevisitSkipped;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    if (controller.isComplete) {
      return _CompletionCard(
        tone: tone,
        done: controller.doneCount,
        skipped: controller.skippedCount,
        hasSkipped: controller.skippedIndexes.isNotEmpty,
        onRestart: onRestart,
        onRevisitSkipped: onRevisitSkipped,
      );
    }

    final index = controller.currentIndex;
    final item = controller.items[index];
    final target = controller.targetAt(index);
    final count = controller.countOf(index);
    final pct = controller.progress;

    return Column(
      children: [
        _FocusBar(
          tone: tone,
          controller: controller,
          index: index,
          percent: pct,
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              // RTL: the reader's «next» is a left-to-right swipe. The screen
              // edges are left alone so the system back gesture keeps working.
              final v = details.primaryVelocity ?? 0;
              if (v.abs() < 260) return;
              if (v > 0) {
                onNext();
              } else if (index > 0) {
                onPrevious();
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tone.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: tone.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.title,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w700,
                          color: AppColors.strongAccent(context, tone.gold),
                        ),
                      ),
                      if (showArabic && item.arabicText.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        DhikrArabicBox(
                          item: item,
                          tone: tone,
                          scaled: arabicSize,
                        ),
                      ],
                      if (item.translation.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
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
                ),
                const SizedBox(height: 14),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CounterRing(
                        tone: tone,
                        count: count,
                        target: target,
                        onTap: onTapRing,
                        onLongPress: target > 1 ? onCompleteAll : null,
                      ),
                      const SizedBox(width: 10),
                      // Appears after the first repetition only, so an
                      // untouched dhikr has no dead control.
                      if (count > 0)
                        DhikrIconButton(
                          icon: Icons.remove_rounded,
                          tone: tone,
                          tooltip: 'یک بار کم کردن',
                          size: 36,
                          onPressed: onUndo,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    autoAdvance
                        ? 'با رسیدن به تعداد، خودکار به ذکر بعدی می‌رود'
                        : 'پس از رسیدن به تعداد، ذکر بعدی را خودتان شروع می‌کنید',
                    if (target > 1) kDhikrHoldToRegister,
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: controller.isDone(index)
                    ? _BottomPill(
                        label: 'بعدی',
                        tone: tone,
                        icon: Icons.chevron_left,
                        onTap: onNext,
                      )
                    : _BottomPill(
                        label: 'قبلی',
                        tone: tone,
                        icon: Icons.chevron_right,
                        onTap: index > 0 ? onPrevious : null,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BottomPill(
                  label: 'رد کردن',
                  tone: tone,
                  icon: Icons.skip_next_rounded,
                  onTap: onSkip,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BottomPill(
                  label: 'اشتراک',
                  tone: tone,
                  icon: Icons.share_outlined,
                  onTap: () => onShare(item),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The segmented bar plus «مورد 3 از 11» on one line.
class _FocusBar extends StatelessWidget {
  const _FocusBar({
    required this.tone,
    required this.controller,
    required this.index,
    required this.percent,
  });

  final DhikrTone tone;
  final DhikrSessionController controller;
  final int index;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final segments = [
      for (var i = 0; i < controller.length; i++)
        controller.isDone(i)
            ? 2
            : (i == index
                ? 1
                : (controller.isSkipped(i) ? 3 : 0)),
    ];
    Color colorOf(int state) => switch (state) {
          2 => tone.success,
          1 => tone.gold,
          3 => AppColors.textMuted(context),
          _ => DhikrPalette.segmentIdle,
        };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          if (segments.length <= 24)
            RepaintBoundary(
              child: Row(
                children: [
                  for (var i = 0; i < segments.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: colorOf(segments[i]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Row(
                  children: [
                    Expanded(
                      flex: (percent * 1000).round().clamp(0, 1000),
                      child: Container(height: 5, color: tone.success),
                    ),
                    Expanded(
                      flex: 1000 - (percent * 1000).round().clamp(0, 1000),
                      child: Container(
                          height: 5, color: DhikrPalette.segmentIdle),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'مورد ${NumberFormat.ltrIsolated('${index + 1}')} از '
                '${NumberFormat.ltrIsolated('${controller.length}')}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: AppColors.textMuted(context),
                ),
              ),
              const Spacer(),
              Text(
                '${NumberFormat.ltrIsolated('${(percent * 100).round()}')}% '
                'این بخش',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: AppColors.textMuted(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 150dp counter, on the app's kit ring. The whole disc is the hit area: a
/// tap adds one repetition, a hold registers the remaining ones — the one tick
/// the reader of a «صد بار» dhikr asked for instead of a hundred taps.
class _CounterRing extends StatelessWidget {
  const _CounterRing({
    required this.tone,
    required this.count,
    required this.target,
    required this.onTap,
    required this.onLongPress,
  });

  final DhikrTone tone;
  final int count;
  final int target;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final done = count >= target;
    final progress = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: target > 1
          ? 'ذکر ${NumberFormat.ltrIsolated('$count')} از '
              '${NumberFormat.ltrIsolated('$target')}، برای افزودن یک بار لمس '
              'کنید${onLongPress == null || done ? '' : '، $kDhikrHoldToRegister'}'
          : 'برای ثبت این ذکر لمس کنید',
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: done ? null : onTap,
          onLongPress: done ? null : onLongPress,
          child: RingView(
            size: 150,
            strokeWidth: 10,
            progress: done ? 1 : progress,
            color: done ? tone.success : tone.gold,
            trackColor: DhikrPalette.ringTrack,
            child: Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: tone.card,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done)
                    Icon(Icons.check_rounded, size: 40, color: tone.success)
                  else
                    Text(
                      NumberFormat.ltrIsolated('$count'),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 46),
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                        color: tone.ink,
                      ),
                    ),
                  Text(
                    done
                        ? 'تکمیل شد'
                        : (target > 1
                            ? 'از ${NumberFormat.ltrIsolated('$target')}'
                            : 'لمس کنید تا ثبت شود'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 10.5),
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPill extends StatelessWidget {
  const _BottomPill({
    required this.label,
    required this.tone,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final DhikrTone tone;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: tone.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tone.border, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: enabled
                    ? AppColors.textSecondary(context)
                    : AppColors.textMuted(context).withValues(alpha: 0.5),
              ),
              const SizedBox(width: 3),
              // Three pills share a 320dp row; at a 1.3 text scale «اشتراک»
              // alone outruns its third, so the label scales down rather than
              // pushing a yellow-black stripe across the card.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AppColors.textSecondary(context)
                          : AppColors.textMuted(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gentle end-of-collection card.
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.tone,
    required this.done,
    required this.skipped,
    required this.hasSkipped,
    required this.onRestart,
    required this.onRevisitSkipped,
  });

  final DhikrTone tone;
  final int done;
  final int skipped;
  final bool hasSkipped;
  final VoidCallback onRestart;
  final VoidCallback onRevisitSkipped;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tone.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 38, color: tone.success),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'ماشاءالله، این بخش تمام شد',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 15),
            fontWeight: FontWeight.w700,
            color: tone.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${NumberFormat.ltrIsolated('$done')} ذکر کامل شد'
          '${skipped > 0 ? ' · ${NumberFormat.ltrIsolated('$skipped')} ذکر رد شد' : ''}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: AppColors.textMuted(context),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onRestart,
          style: FilledButton.styleFrom(
            backgroundColor: DhikrPalette.navy,
            foregroundColor: DhikrPalette.cream,
            minimumSize: const Size.fromHeight(46),
          ),
          child: const Text('شروع دوباره'),
        ),
        if (hasSkipped) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onRevisitSkipped,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: const Text('رفتن به رد شده‌ها'),
          ),
        ],
      ],
    );
  }
}
