import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/widgets/dashed_border_painter.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/prayer/domain/rawatib_model.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// ═══════════════════════════════════════════════════════════════
/// The rawatib card (home/final-v3, step 5/9 — bug #4; 3×2 grid per the
/// 2026-10-12 user request, re-ordered 2026-10-13 for the day run).
///
/// THREE lines of TWO boxes each (RTL): the RIGHT column reads the day in
/// order — راتب فجر / راتب ظهر قبل / راتب ظهر بعد — and the LEFT column runs
/// راتب مغرب / راتب عشاء / وتر. Each box carries the prayer-like duotone
/// glyph in its own hue. Relevance comes from [rawatibWindows] — one table
/// shared by the suggested styling, the «پیشنهاد این وقت: …» header text and
/// the past marks. Tapping a box toggles the tracker (same persistence path
/// as before, now with a light haptic). The n/6 counter counts only the six
/// boxes shown — the duha checkbox lives on the prayer card, and the old
/// «+ ۱ مورد دیگر» footer is gone (2026-10-13 user request).
/// ═══════════════════════════════════════════════════════════════
class RawatibCard extends ConsumerWidget {
  const RawatibCard({super.key, this.nowOverride});

  /// Clock seam: "now" a widget test cannot otherwise pin.
  @visibleForTesting
  final DateTime? nowOverride;

  /// Same display content as the old chips — title + rakat detail.
  static ({String title, String detail}) _textOf(SunnahPrayer id) =>
      switch (id) {
        SunnahPrayer.fajrRawatib => (
            title: 'راتبه فجر',
            detail: '2 رکعت · قبل'
          ),
        SunnahPrayer.dhuhrRawatibBefore => (
            title: 'راتبه ظهر',
            detail: '4 رکعت · قبل',
          ),
        SunnahPrayer.dhuhrRawatibAfter => (
            title: 'راتبه ظهر',
            detail: '2 رکعت · بعد',
          ),
        SunnahPrayer.maghribRawatib => (
            title: 'راتبه مغرب',
            detail: '2 رکعت · بعد',
          ),
        SunnahPrayer.ishaRawatib => (
            title: 'راتبه عشاء',
            detail: '2 رکعت · بعد',
          ),
        SunnahPrayer.witr => (title: 'وتر', detail: '3 رکعت · بعد از عشاء'),
      };

  static Color _accentOf(SunnahPrayer id) => switch (id) {
        SunnahPrayer.fajrRawatib => HomeColors.fajr,
        SunnahPrayer.dhuhrRawatibBefore => HomeColors.dhuhr,
        SunnahPrayer.dhuhrRawatibAfter => HomeColors.dhuhr,
        SunnahPrayer.maghribRawatib => HomeColors.maghrib,
        SunnahPrayer.ishaRawatib => HomeColors.isha,
        SunnahPrayer.witr => HomeColors.witr,
      };

  /// One prayer-like glyph per box, in the same hue as the prayer-times
  /// rows — the two «راتبه ظهر» boxes share the dhuhr sun.
  static IconData _iconOf(SunnahPrayer id) => switch (id) {
        SunnahPrayer.fajrRawatib => Icons.nightlight_round,
        SunnahPrayer.dhuhrRawatibBefore => Icons.light_mode,
        SunnahPrayer.dhuhrRawatibAfter => Icons.light_mode,
        SunnahPrayer.maghribRawatib => Icons.wb_twilight,
        SunnahPrayer.ishaRawatib => Icons.dark_mode,
        SunnahPrayer.witr => Icons.star_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final times = ref.watch(prayerTimesProvider).value;
    final tracker = ref.watch(prayerTrackerProvider.select((s) => s.value));
    final notifier = ref.read(prayerTrackerProvider.notifier);

    final checked = tracker?.sunnahStatuses ?? const <SunnahPrayer, bool>{};

    // One derivation closure for both the rebuild key and the builder —
    // the key must never disagree with what renders (phase-2 minute-tick
    // contract: a tick whose key is unchanged repaints nothing).
    Map<SunnahPrayer, RawatibState> statesAt(DateTime now) {
      final spans =
          times == null ? null : _spans(PrayerSchedule.fromToday(times));
      final states = <SunnahPrayer, RawatibState>{};
      spans?.forEach((id, span) {
        states[id] = rawatibStateAt(
          span: span,
          now: now,
          checked: checked[id] ?? false,
        );
      });
      if (spans == null) {
        for (final id in SunnahPrayer.values) {
          states[id] = RawatibState.upcoming;
        }
      }
      return states;
    }

    SunnahPrayer? suggestedOf(Map<SunnahPrayer, RawatibState> states) {
      for (final id in SunnahPrayer.values) {
        if (states[id] == RawatibState.suggested) return id;
      }
      return null;
    }

    return QuantizedRebuild<String>(
      listenable: ref.watch(clockTickerProvider).minute,
      keyOf: (tick) {
        final now = nowOverride ?? tick;
        final states = statesAt(now);
        return '${SunnahPrayer.values.map((id) => (states[id] ?? RawatibState.upcoming).index).join()}'
            '|${suggestedOf(states)?.name ?? ''}';
      },
      builder: (context, tick) {
        final now = nowOverride ?? tick;
        final states = statesAt(now);
        final suggested = suggestedOf(states);

        final doneCount =
            SunnahPrayer.values.where((p) => checked[p] ?? false).length;
        final total = SunnahPrayer.values.length; // the six boxes shown

        // The user's layout: THREE lines, TWO rawatibs each. In RTL
        // children[0] is the RIGHT cell, so the right column reads the day in
        // order — فجر، ظهر قبل، ظهر بعد — and the left column runs مغرب،
        // عشاء، وتر (2026-10-13 re-order: the old zigzag made the leading
        // column skip ظهر قبل). IntrinsicHeight: the card Column offers
        // unbounded height, which CrossAxisAlignment.stretch would pass on as
        // h=Infinity; it also keeps the two boxes of a line equal to the
        // taller one.
        const grid = <List<SunnahPrayer>>[
          [SunnahPrayer.fajrRawatib, SunnahPrayer.maghribRawatib],
          [SunnahPrayer.dhuhrRawatibBefore, SunnahPrayer.ishaRawatib],
          [SunnahPrayer.dhuhrRawatibAfter, SunnahPrayer.witr],
        ];

        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SectionHeader(
                  title: 'رواتب (سنن مؤکده)',
                  // «—» while the tracker has not resolved: an empty
                  // `checked` map is indistinguishable from «nothing done»,
                  // and the header used to claim «۰/۶» on the first frame.
                  count: tracker == null
                      ? '—'
                      : NumberFormat.ltrIsolated('$doneCount/$total'),
                  trailing: suggested == null
                      ? null
                      : Text(
                          'پیشنهاد این وقت: ${_textOf(suggested).title}',
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: TimeThemeKit.of(context).palette.textMuted,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  children: [
                    for (var r = 0; r < grid.length; r++)
                      Padding(
                        padding: EdgeInsets.only(bottom: r < 2 ? 6 : 0),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var c = 0; c < grid[r].length; c++) ...[
                                if (c > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: _RawatibBox(
                                    key: ValueKey('rawatib_${grid[r][c].name}'),
                                    id: grid[r][c],
                                    state:
                                        states[grid[r][c]] ??
                                            RawatibState.upcoming,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      notifier.toggleSunnah(grid[r][c]);
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Map<SunnahPrayer, RawatibSpan> _spans(PrayerSchedule s) =>
      rawatibWindows(
        fajr: s.today.fajr,
        sunrise: s.today.sunrise,
        dhuhr: s.today.dhuhr,
        asr: s.today.asr,
        maghrib: s.today.maghrib,
        isha: s.today.isha,
        tomorrowFajr: s.tomorrow.fajr,
      );
}

class _RawatibBox extends StatelessWidget {
  const _RawatibBox({
    super.key,
    required this.id,
    required this.state,
    required this.onTap,
  });

  final SunnahPrayer id;
  final RawatibState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RawatibCard._accentOf(id);
    final text = RawatibCard._textOf(id);
    final done = state == RawatibState.done;
    final suggested = state == RawatibState.suggested;
    final past = state == RawatibState.past;

    Widget box = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: suggested
            ? accent.withValues(alpha: 0.12)
            : past
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : HomeColors.rawatibPastBg)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppTheme.parchment.withValues(alpha: 0.85)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 15,
            color: done
                ? HomeColors.done
                : suggested
                    ? accent
                    : t.textMuted.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          DuotoneIconTile(
              accent: accent, icon: RawatibCard._iconOf(id), size: 26),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The title never truncates — it scales down inside the
                // half-width cell; only the detail line ellipsizes.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    text.title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w500,
                      color: done
                          ? HomeColors.done
                          : suggested
                              ? (Color.lerp(accent, Colors.black, 0.35) ??
                                  accent)
                              : t.textSecondary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
                Text(
                  text.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 9.5),
                    color: t.textMuted,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (past) {
      box = CustomPaint(
        foregroundPainter: DashedRRectPainter(
          color: HomeColors.faintBorder(isDark, alpha: 0.85),
          radius: 12,
        ),
        child: box,
      );
    }

    return Semantics(
      button: true,
      enabled: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: box,
      ),
    );
  }
}
