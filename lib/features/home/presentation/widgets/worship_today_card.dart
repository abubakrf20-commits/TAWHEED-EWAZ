import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Today's worship checklist at a glance (طاعات روزانه) as ONE row, in the
/// reminders-row language: a percent [RingView] up front, a single-line
/// title + subtitle, and a chevron — the whole row opens the full checklist
/// screen, where managing (add/delete) lives. Nothing else shows here
/// (2026-10-15 user request: «فقط در یک سطر باشد، نمی‌خواهم همه‌چیز ظاهر
/// باشد»). The «روز پیوسته» streak stat is gone (2026-10-13 user request).
///
/// Loading never renders a false «۰ از ۰» (that reads as an empty day and
/// contradicts the checklist); errors get a retry instead of silence.
class WorshipTodayCard extends ConsumerWidget {
  const WorshipTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(evaluationProvider);
    final state = async.value;
    // «هنوز بارگذاری نشده» و «بارگذاری شکست خورد» must not render as
    // «۰ از ۰» — that reads as an empty day and contradicts the checklist.
    if (state == null) {
      return async.isLoading
          ? const _WorshipTodayPlaceholder()
          : _WorshipTodayFailed(
              onRetry: () => ref.invalidate(evaluationProvider));
    }
    final items = state.worshipItems;
    final done = items.where((i) => i.done).length;
    final total = items.length;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final allDone = total > 0 && done >= total;
    final accent = allDone ? AppPalette.emerald : SectionHues.evaluation;

    return AppCard(
      borderColor: accent.withValues(alpha: 0.25),
      onTap: () => context.push(RouteNames.worshipChecklist),
      child: Row(
        children: [
          RingView(
            progress: progress,
            size: 40,
            strokeWidth: 4.5,
            color: accent,
            trackColor: accent.withValues(alpha: 0.20),
            semanticLabel: 'طاعات روزانه، $done از $total',
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                NumberFormat.ltrIsolated('${(progress * 100).round()}٪'),
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: dsContentColor(context, accent),
                  fontFamily: AppTheme.fontFamily,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'طاعات روزانه',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color:
                        TimeThemeKit.of(context).palette.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${NumberFormat.fraction(done, total)} • امتیاز ${NumberFormat.ltrIsolated('${state.dailyScore}')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color:
                        TimeThemeKit.of(context).palette.textMuted,
                    fontFamily: AppTheme.fontFamily,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left,
              size: 22, color: TimeThemeKit.of(context).palette.textMuted),
        ],
      ),
    );
  }
}

/// Loading placeholder — one-row skeleton, no false «۰ از ۰».
class _WorshipTodayPlaceholder extends StatelessWidget {
  const _WorshipTodayPlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final box = t.outline.withValues(alpha: .45);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: box,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 13,
              decoration: BoxDecoration(
                color: box,
                borderRadius: BorderRadius.circular(6.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Load failure — the shared panel, not a hand-rolled row.
///
/// This used to be its own «sentence + TextButton» pair. It was honest, but it
/// was the ninth shape of the same failure: no stable key, so no test could
/// assert it without matching the Persian prose, so nothing guarded it.
class _WorshipTodayFailed extends StatelessWidget {
  const _WorshipTodayFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const accent = SectionHues.evaluation;
    return AppCard(
      borderColor: accent.withValues(alpha: 0.25),
      child: FailureView(
        id: 'home_worship_today',
        title: 'طاعات امروز باز نشد',
        detail: 'تیک‌های امروز پاک نشده‌اند؛ فقط خواندنشان ناموفق بود.',
        layout: FailureLayout.inline,
        onRetry: onRetry,
      ),
    );
  }
}


