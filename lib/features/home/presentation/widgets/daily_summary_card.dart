import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/adhkar.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_stats_provider.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// ═══════════════════════════════════════════════════════════════
/// The daily summary card (home/final-v3, step 6/9 — bug #5).
///
/// Four 62dp rings — نماز 0/5, رواتب 0/7, اذکار 0/49, تسبیح 0/هدف — over one
/// shared ring painter. A zero ring is no longer a pale ghost: the track is
/// the accent at 20% and a start dot marks where the sweep begins, the
/// centre carries the stat's icon instead of a percentage. Data sources are
/// the app's own: fardh done+qada, sunnahs + duha, the three daily adhkar
/// periods, and the tasbih daily total against the day's summed targets.
/// ═══════════════════════════════════════════════════════════════
class DailySummaryCard extends ConsumerWidget {
  const DailySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Three async sources, four rings. Each one is read as an `AsyncValue` and
    // only trusted once it has a value — see [_RingStat.done].
    final trackerAsync = ref.watch(prayerTrackerProvider);
    // Watch the full provider, not only the version counter: the counter is an
    // int that stays 0 across the loading → data transition, so Riverpod's
    // equality check would drop the rebuild and the ring would keep the 0/0
    // it painted on the first frame.
    final azkarAsync = ref.watch(azkarProvider);
    final tasbihAsync = ref.watch(tasbihStatsProvider);
    final azkarNotifier = ref.read(azkarProvider.notifier);

    final tracker = trackerAsync.value;
    final fardStatuses = tracker?.fardStatuses;
    final sunnahStatuses = tracker?.sunnahStatuses;
    final duhaStatus = tracker?.duhaStatus;

    // Qada (قضا) counts as performed — the app-wide daily-total convention.
    // Null — not zero — while the tracker has not resolved.
    final int? donePrayers = fardStatuses == null
        ? null
        : FardhPrayer.values
            .where((p) =>
                (fardStatuses[p] ?? PrayerStatus.pending) ==
                    PrayerStatus.done ||
                (fardStatuses[p] ?? PrayerStatus.pending) ==
                    PrayerStatus.qada)
            .length;
    final int? doneSunnah =
        (sunnahStatuses == null || duhaStatus == null)
            ? null
            : SunnahPrayer.values
                    .where((p) => sunnahStatuses[p] == true)
                    .length +
                (duhaStatus ? 1 : 0);

    // Only the daily-cadence adhkar belong in "today"; the per-prayer
    // fadhail categories attach to each prayer occurrence (unchanged rule).
    const dailyAzkarPeriods = [
      PrayerPeriod.morningAzkar,
      PrayerPeriod.eveningAzkar,
      PrayerPeriod.postPrayer,
    ];
    var doneAzkar = 0;
    var totalAzkar = 0;
    final azkarReady = azkarAsync.value != null;
    if (azkarReady) {
      for (final period in dailyAzkarPeriods) {
        final stats = azkarNotifier.periodStats(period);
        doneAzkar += stats['done'] ?? 0;
        totalAzkar += stats['total'] ?? 0;
      }
    }

    // Unknown is not zero: until the tasbih stats resolve (or if they fail),
    // the ring keeps a dash instead of claiming «0/0».
    final tasbih = tasbihAsync.value;

    // Which reads actually failed (as opposed to still running). A dash on a
    // ring is honest but mute; this is the sentence that explains it.
    final failedSources = <String>[
      if (trackerAsync.hasError && !trackerAsync.hasValue) 'ثبت نمازها',
      if (azkarAsync.hasError && !azkarAsync.hasValue) 'اذکار',
      if (tasbihAsync.hasError && !tasbihAsync.hasValue) 'تسبیح',
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'خلاصه امروز'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            // Expanded cells: four fixed-width rings would overflow the row
            // at 320dp / text scale 1.3, where the scaled counter is wider
            // than the 62dp ring.
            child: Row(
              children: [
                Expanded(
                  child: _RingStat(
                    label: 'نماز',
                    done: donePrayers,
                    total: 5,
                    color: HomeColors.ringPrayer,
                    icon: Icons.mosque_rounded,
                  ),
                ),
                Expanded(
                  child: _RingStat(
                    label: 'رواتب',
                    done: doneSunnah,
                    total: 7,
                    color: HomeColors.ringRawatib,
                    icon: Icons.repeat_rounded,
                  ),
                ),
                Expanded(
                  child: _RingStat(
                    label: 'اذکار',
                    done: azkarReady ? doneAzkar : null,
                    total: totalAzkar,
                    color: HomeColors.ringAdhkar,
                    icon: Icons.self_improvement_rounded,
                  ),
                ),
                Expanded(
                  child: _RingStat(
                    label: 'تسبیح',
                    done: tasbih?.todayTotal,
                    total: tasbih?.sumTargets ?? 0,
                    color: HomeColors.ringTasbih,
                    icon: Icons.all_inclusive_rounded,
                  ),
                ),
              ],
            ),
          ),
          // A dash is honest but mute. When a read actually failed, say which
          // one and offer the retry — four silent «—» rings are the same
          // «خطایی که چیزی نمی‌گوید» the rest of the app no longer ships.
          if (failedSources.isNotEmpty)
            FailureView(
              id: 'home_daily_summary',
              title: '${failedSources.join(' و ')} خوانده نشد',
              detail: 'حلقه‌های این کارت تا وقتی خواندن موفق نشود عدد نشان '
                  'نمی‌دهند؛ چیزی پاک نشده است.',
              layout: FailureLayout.inline,
              onRetry: () {
                if (trackerAsync.hasError) ref.invalidate(prayerTrackerProvider);
                if (azkarAsync.hasError) ref.invalidate(azkarProvider);
                if (tasbihAsync.hasError) ref.invalidate(tasbihStatsProvider);
              },
            ),
        ],
      ),
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({
    required this.label,
    required this.done,
    required this.total,
    required this.color,
    required this.icon,
  });

  final String label;

  /// Null while the reading is unknown — the counter reads «—», never «0».
  final int? done;
  final int total;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final done = this.done;
    final progress = done == null || total <= 0
        ? 0.0
        : (done / total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: RingView(
            progress: progress,
            size: 62,
            strokeWidth: 6,
            color: color,
            trackColor: color.withValues(alpha: 0.20),
            startDot: true,
            semanticLabel: done == null
                ? '$label، در دسترس نیست'
                : '$label، $done از $total',
            child: Icon(
              icon,
              size: 18,
              // The mockup's centre-icon mix: the accent, slightly
              // darkened so it reads on the pale track.
              color: Color.lerp(color, Colors.black, 0.10) ?? color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 11.5),
            fontWeight: FontWeight.w500,
            color: t.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        Text(
          done == null ? '—' : NumberFormat.ltrIsolated('$done/$total'),
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 11),
            color: t.textMuted,
            fontFamily: AppTheme.fontFamily,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
