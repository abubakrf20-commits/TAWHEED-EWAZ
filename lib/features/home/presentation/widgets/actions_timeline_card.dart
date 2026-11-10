import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/adhkar.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart' as data;
import 'package:tawheeed/features/home/presentation/utils/time_formatters.dart';
import 'package:tawheeed/features/home/presentation/widgets/adhkar_category_page.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/prayer/domain/home_day_model.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';

/// One node of the actions timeline: a fixed-width column whose chip
/// always shows the adhkar category, its window start time and its state.
class _NodeData {
  final String title;
  final IconData icon;
  final Color accent;

  /// Seconds line: a window start time ([isTime]) or the static anchor text.
  final String secondary;
  final bool isTime;

  /// The chip wears the «اکنون» look (gold border, warm ground).
  final bool chipNow;
  final bool isPast;

  /// Only the actual current node (never the ride-along) shows the pill.
  final bool showTag;

  /// Progress through the current window (0..1), for the progress marker
  /// on the current node (item 20f). Null when the node has no window.
  final double? progress;

  const _NodeData({
    required this.title,
    required this.icon,
    required this.accent,
    required this.secondary,
    required this.isTime,
    required this.chipNow,
    required this.isPast,
    required this.showTag,
    this.progress,
  });
}

/// ═══════════════════════════════════════════════════════════════
/// ActionsTimelineCard — the redesigned home's actions timeline (7/9).
///
/// Ten fixed-width nodes (the nine [azkarTimelineWindows] categories plus
/// the ride-along «بعد از نماز»): an «اکنون» pill above the rail sits only
/// on the current node, the dot rail runs gold up to it, and each chip
/// carries a duotone tile, the category name and its window START time —
/// no remaining-time, no 122dp of dead space (bug #3). Data comes from the
/// same [azkarTimelineWindows]/[azkarActiveIndices] the domain tests pin;
/// before today's fajr the day is yesterday's cycle so the night node stays
/// current. Tapping a node pushes [AdhkarCategoryPage] (empty category →
/// the azkar tab callback, as before).
/// ═══════════════════════════════════════════════════════════════
class ActionsTimelineCard extends ConsumerStatefulWidget {
  const ActionsTimelineCard(
      {super.key, this.nowOverride, this.onNavigateToAzkar});

  /// Clock seam: "now" a widget test cannot otherwise pin.
  @visibleForTesting
  final DateTime? nowOverride;

  final VoidCallback? onNavigateToAzkar;

  @override
  ConsumerState<ActionsTimelineCard> createState() =>
      _ActionsTimelineCardState();
}

class _ActionsTimelineCardState extends ConsumerState<ActionsTimelineCard> {
  static const List<({String title, IconData icon, PrayerPeriod period})>
      _categories = [
    (title: 'فضائل فجر', icon: Icons.alarm, period: PrayerPeriod.fajr),
    (
      title: 'اذکار صبح',
      icon: Icons.wb_twilight,
      period: PrayerPeriod.morningAzkar
    ),
    (title: 'ضحی', icon: Icons.wb_sunny_outlined, period: PrayerPeriod.shorouq),
    (title: 'فضائل ظهر', icon: Icons.light_mode, period: PrayerPeriod.duhr),
    (title: 'فضائل عصر', icon: Icons.cloud_outlined, period: PrayerPeriod.asr),
    (title: 'فضائل مغرب', icon: Icons.sunny, period: PrayerPeriod.maghrib),
    (
      title: 'اذکار شب',
      icon: Icons.nights_stay,
      period: PrayerPeriod.eveningAzkar
    ),
    (
      title: 'فضائل عشاء',
      icon: Icons.dark_mode_outlined,
      period: PrayerPeriod.isha
    ),
    (title: 'اذکار خواب', icon: Icons.bedtime, period: PrayerPeriod.night),
    (
      title: 'بعد از نماز',
      icon: Icons.checklist,
      period: PrayerPeriod.postPrayer
    ),
  ];

  static const List<String> _anchors = [
    'بعد از اذان صبح',
    'صبح',
    'پیش از ظهر',
    'بعد از اذان ظهر',
    'بعد از اذان عصر',
    'بعد از اذان مغرب',
    'شب',
    'بعد از اذان عشاء',
    'پیش از خواب',
    'بعد هر نماز',
  ];

  static const double _nodeWidth = 78;
  static const double _itemExtent = _nodeWidth + 6;

  // Line metrics are allocated exactly: explicit `height` in the styles and
  // matching SizedBoxes, so the scaled-font matrix can never overflow.
  // (2026-10-12 polish: tag row 16→14, rail 12→10, chip tile 28→24 and the
  // card's top/bottom air cut — the user asked for a much tighter band.)
  static double _nameH(BuildContext context) =>
      AppTheme.scaledFontSize(context, 11) * 1.35;
  static double _timeH(BuildContext context) =>
      AppTheme.scaledFontSize(context, 9.5) * 1.35;
  static double _tagH(BuildContext context) =>
      AppTheme.scaledFontSize(context, 9) * 1.3 + 2;
  static double _nodeH(BuildContext context) =>
      // Chip height includes its widest border (the current node's 1.2×2),
      // so past/upcoming chips leave 1.4dp slack instead of overflowing.
      _tagH(context) +
      2 +
      10 +
      4 +
      2 +
      1 +
      2.4 +
      24 +
      1 +
      _nameH(context) +
      1 +
      _timeH(context) +
      2;

  final ScrollController _scroll = ScrollController();
  int _lastCentered = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final times = ref.watch(prayerTimesProvider);
    // Rebuild when an adhkar completion toggles (stat-driven visuals live on
    // the category page; this card only needs the version bump).
    ref.watch(azkarVersionProvider);
    final use12 = ref.watch(use12HourProvider);

    // One derivation closure for both the rebuild key and the builder —
    // the key must never disagree with what renders (phase-2 minute-tick
    // contract: a tick whose key is unchanged repaints nothing).
    ({int current, bool postPrayerNow, List<AzkarWindow> windows}) deriveAt(
        DateTime now) {
      final schedule =
          times.value == null ? null : PrayerSchedule.fromToday(times.value!);

      // Before today's fajr the shar'i day is yesterday's cycle.
      final preFajr = schedule != null && now.isBefore(schedule.today.fajr);
      final day = schedule == null
          ? null
          : (preFajr ? schedule.yesterday : schedule.today);
      final nextFajr = schedule == null
          ? null
          : (preFajr ? schedule.today.fajr : schedule.tomorrow.fajr);

      final windows = (day == null || nextFajr == null)
          ? const <AzkarWindow>[]
          : azkarTimelineWindows(day: day, nextFajr: nextFajr);
      final active = day == null || nextFajr == null
          ? azkarFallbackIndices(now.hour)
          : azkarActiveIndices(
              day: day, nextFajr: nextFajr, now: now, fallbackHour: now.hour);

      // Current node: the latest window that has started. With no usable
      // schedule the fallback indices stand in (always hold a 0..8 node).
      var current = -1;
      for (final w in windows) {
        if (!w.start.isAfter(now)) current = w.index;
      }
      if (windows.isEmpty) {
        for (final i in active) {
          if (i < 9 && i > current) current = i;
        }
      }
      return (
        current: current,
        postPrayerNow: active.contains(9),
        windows: windows
      );
    }

    return QuantizedRebuild<({int current, bool postPrayerNow})>(
      listenable: ref.watch(clockTickerProvider).minute,
      keyOf: (tick) {
        final d = deriveAt(widget.nowOverride ?? tick);
        return (current: d.current, postPrayerNow: d.postPrayerNow);
      },
      builder: (context, tick) {
        final now = widget.nowOverride ?? tick;
        final d = deriveAt(now);
        final current = d.current;
        final postPrayerNow = d.postPrayerNow;
        final windows = d.windows;

        if (current >= 0 && current != _lastCentered) {
          _lastCentered = current;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _centerOn(current));
        }

        final nodes = <_NodeData>[];
        for (var i = 0; i < _categories.length; i++) {
          final cat = _categories[i];
          if (i == 9) {
            // Post-prayer rides along: it wears the current look while a
            // prayer window is open, but never the «اکنون» pill.
            nodes.add(_NodeData(
              title: cat.title,
              icon: cat.icon,
              accent: _accentOf(cat.period),
              secondary: _anchors[i],
              isTime: false,
              chipNow: postPrayerNow,
              isPast: false,
              showTag: false,
            ));
            continue;
          }
          AzkarWindow? w;
          for (final x in windows) {
            if (x.index == i) w = x;
          }
          nodes.add(_NodeData(
            title: cat.title,
            icon: cat.icon,
            accent: _accentOf(cat.period),
            secondary: w == null ? _anchors[i] : _timeText(w.start, use12),
            isTime: w != null,
            chipNow: i == current,
            isPast: i < current,
            showTag: i == current,
            progress: w == null ? null : _progress(now, w.start, w.end),
          ));
        }

        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SectionHeader(
                  title: 'تایم‌لاین اعمال',
                  margin: const EdgeInsets.only(bottom: 6),
                  trailing: Text(
                    'مناسب این وقت',
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      color: TimeThemeKit.of(context).palette.textMuted,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ),
              RepaintBoundary(
                child: SizedBox(
                  height: _nodeH(context),
                  child: ListView.builder(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemExtent: _itemExtent,
                    itemCount: nodes.length,
                    itemBuilder: (context, i) => Center(
                      child: _TimelineNode(
                        key: ValueKey('timeline_node_$i'),
                        data: nodes[i],
                        linePast: i <= current,
                        onTap: () => _open(_categories[i]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  void _centerOn(int index) {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final target = (index * _itemExtent + _nodeWidth / 2 - viewport / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
  }

  void _open(({String title, IconData icon, PrayerPeriod period}) category) {
    final items = data.AzkarData.getByPeriod(category.period);
    if (items.isEmpty) {
      widget.onNavigateToAzkar?.call();
      return;
    }
    context.push(
      RouteNames.azkarCategory,
      extra: AdhkarCategoryArgs(
        title: category.title,
        period: category.period,
        items: items,
      ),
    );
  }

  /// Progress (0..1) of now through the start->end window, clamped.
  static double _progress(DateTime now, DateTime start, DateTime end) {
    final span = end.difference(start).inMilliseconds.toDouble();
    if (span <= 0) return 0.0;
    return (now.difference(start).inMilliseconds.toDouble() / span)
        .clamp(0.0, 1.0);
  }

  static Color _accentOf(PrayerPeriod period) => switch (period) {
        PrayerPeriod.fajr => HomeColors.fajr,
        PrayerPeriod.morningAzkar => HomeColors.dhuhr,
        PrayerPeriod.shorouq => HomeColors.sunrise,
        PrayerPeriod.duhr => HomeColors.dhuhr,
        PrayerPeriod.asr => HomeColors.asr,
        PrayerPeriod.maghrib => HomeColors.maghrib,
        PrayerPeriod.eveningAzkar => HomeColors.isha,
        PrayerPeriod.isha => HomeColors.isha,
        PrayerPeriod.night => HomeColors.witr,
        PrayerPeriod.postPrayer => HomeColors.done,
      };

  static String _timeText(DateTime t, bool use12) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return TimeFormatters.formatTime('$hh:$mm', use12Hour: use12);
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    super.key,
    required this.data,
    required this.linePast,
    required this.onTap,
  });

  final _NodeData data;
  final bool linePast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipColor = data.chipNow
        ? HomeColors.nowRowStart(isDark)
        : data.isPast
            ? (isDark
                ? Colors.white.withValues(alpha: .05)
                : HomeColors.timelinePastBg.withValues(alpha: .80))
            : (isDark
                ? Colors.white.withValues(alpha: .03)
                : HomeColors.timelineUpcomingBg);
    final borderColor = data.chipNow
        ? HomeColors.goldLine
        : (isDark
            ? Colors.white.withValues(alpha: .08)
            : HomeColors.timelineUpcomingBorder);
    final lineColor =
        linePast ? HomeColors.timelineLine : HomeColors.timelineUpcomingBorder;
    final nameColor = data.chipNow
        ? HomeColors.nowRowTime(isDark)
        : data.isPast
            ? t.textMuted
            : t.textSecondary;

    return Semantics(
      button: true,
      label: '${data.title}، ${data.secondary}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 78,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _ActionsTimelineCardState._tagH(context),
                child: data.showTag
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppPalette.heroGold,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'اکنون',
                            style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 9),
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.espresso,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 10,
                width: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(height: 2, color: lineColor),
                    if (data.chipNow)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HomeColors.goldLine.withValues(alpha: .22),
                        ),
                      ),
                    if (data.chipNow && data.progress != null)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          value: data.progress!,
                          strokeWidth: 2.5,
                          strokeCap: StrokeCap.round,
                          backgroundColor: HomeColors.goldLine.withValues(alpha: 0.22),
                          valueColor: AlwaysStoppedAnimation<Color>(data.accent),
                        ),
                      )
                    else
                      Container(
                        width: data.chipNow ? 11 : 9,
                        height: data.chipNow ? 11 : 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Past/current dots sit solid on the gold line;
                          // upcoming is a hollow ring so the pale line stays
                          // readable through it (no white punch-out border).
                          color: data.isPast || data.chipNow
                              ? HomeColors.goldLine
                              : null,
                          border: data.isPast || data.chipNow
                              ? null
                              : Border.all(
                                  color: HomeColors.faintBorder(isDark),
                                  width: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 78,
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: borderColor, width: data.chipNow ? 1.2 : 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DuotoneIconTile(
                        accent: data.accent, icon: data.icon, size: 24),
                    const SizedBox(height: 1),
                    SizedBox(
                      height: _ActionsTimelineCardState._nameH(context),
                      child: Center(
                        child: Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: nameColor,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    SizedBox(
                      height: _ActionsTimelineCardState._timeH(context),
                      child: Center(
                        child: Text(
                          data.secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: data.isTime
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 9.5),
                            height: 1.35,
                            fontFeatures: data.isTime
                                ? const [FontFeature.tabularFigures()]
                                : null,
                            color: t.textMuted,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
