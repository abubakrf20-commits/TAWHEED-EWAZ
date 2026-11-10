import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/utils/time_formatters.dart';
import 'package:tawheeed/features/home/presentation/widgets/dashed_border_painter.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/features/home/presentation/widgets/home_tokens.dart';
import 'package:tawheeed/features/prayer/domain/home_day_model.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/friday_prayer_label.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// ═══════════════════════════════════════════════════════════════
/// PrayerTimesCard — the redesigned home's prayer-times card.
///
/// Header (shared SectionHeader): «اوقات شرعی» + the period chip
/// (اشراق و صبح … — bug #7: the sunrise→dhuhr stretch shows the period
/// NAME, never a fake «اکنون») + n/5 LTR + share. Under it six
/// SINGLE-LINE rows (bug #9: no secondary text at all): 36dp duotone
/// tile · name · time · 21dp check circle. **Each row sits in a faint box,
/// and the open window's box turns solid gold** (2026-10-14 user request:
/// «هر نماز در بوکسی کمرنگ که وقتی وقتش شد پررنگ‌تر بشود»). The
/// five-segment completion
/// line was removed per the user's request (2026-10-13) — the header now
/// sits directly over the rows, and a closed unlogged window wears the
/// RED dash, never a done-tick (2026-10-13: «علامت _ باشد نه تیک انجام»;
/// still tappable to log late).
///
/// Row states come from [homeDayState] — the same snapshot the hero
/// counts with, so «اکنون»/«بعدی» can never disagree with the countdown.
/// Every row is one tap target (toggle/persistence as before, now with a
/// light haptic); sunrise is never «اکنون»/«بعدی» — it is not a prayer
/// window, only its duha checkbox.
/// ═══════════════════════════════════════════════════════════════
class PrayerTimesCard extends ConsumerWidget {
  const PrayerTimesCard({super.key, this.highlightKey, this.nowOverride});

  /// Prayer row to highlight after a notification tap (english key).
  final String? highlightKey;

  /// Clock seam: "now" a widget test cannot otherwise pin.
  @visibleForTesting
  final DateTime? nowOverride;

  static String _nameOf(PrayerId id) => switch (id) {
        PrayerId.fajr => 'اذان صبح',
        PrayerId.sunrise => 'طلوع آفتاب',
        PrayerId.dhuhr => 'اذان ظهر',
        PrayerId.asr => 'اذان عصر',
        PrayerId.maghrib => 'اذان مغرب',
        PrayerId.isha => 'اذان عشاء',
      };

  static IconData _iconOf(PrayerId id) => switch (id) {
        PrayerId.fajr => Icons.nightlight_round,
        PrayerId.sunrise => Icons.wb_sunny_outlined,
        PrayerId.dhuhr => Icons.light_mode,
        PrayerId.asr => Icons.cloud_outlined,
        PrayerId.maghrib => Icons.wb_twilight,
        PrayerId.isha => Icons.dark_mode,
      };

  static String _englishKeyOf(PrayerId id) => switch (id) {
        PrayerId.fajr => 'fajr',
        PrayerId.sunrise => 'sunrise',
        PrayerId.dhuhr => 'dhuhr',
        PrayerId.asr => 'asr',
        PrayerId.maghrib => 'maghrib',
        PrayerId.isha => 'isha',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final times = ref.watch(prayerTimesProvider);
    if (times.hasError && !times.hasValue) {
      return _ErrorCard(
        error: times.error ?? 'unknown',
        stackTrace: times.stackTrace,
        onRetry: () => ref.invalidate(prayerTimesProvider),
      );
    }
    final clock = ref.watch(prayerClockProvider);
    if (clock == null) return const _LoadingRows();

    final t = TimeThemeKit.of(context).palette;
    final tracker = ref.watch(
      prayerTrackerProvider.select((s) => s.value),
    );
    final use12 = ref.watch(use12HourProvider);

    final periodLoaded = ref.watch(periodProvider).value != null;

    // One derivation closure for both the rebuild key and the builder — the
    // key must never disagree with what renders (phase-2 minute-tick
    // contract: a tick whose key is unchanged repaints nothing; provider
    // content like the tracker flows through parent rebuilds).
    HomeDayState dayStateOf(DateTime now) {
      final prayerTimes = times.value!;
      final schedule = PrayerSchedule.fromToday(prayerTimes);
      // Live path: the shared snapshot the hero counts with. Pinned-now
      // path (tests): the same pure engine at the pinned instant.
      final snap =
          nowOverride == null ? clock.value : computeSnapshot(schedule, now);
      return homeDayState(
        schedule,
        now,
        snap,
        fardStatuses: tracker?.fardStatuses ?? const {},
        sunriseDone: tracker?.duhaStatus ?? false,
        exempt: periodLoaded &&
            ref.read(periodProvider.notifier).isDateInPeriod(now),
      );
    }

    return QuantizedRebuild<String>(
      listenable: ref.watch(clockTickerProvider).minute,
      keyOf: (tick) {
        final now = nowOverride ?? tick;
        final dayState = dayStateOf(now);
        return '${dayState.periodLabel}|'
            '${dayState.rows.map((r) => r.state.index).join()}|'
            '${dayState.rows.map((r) => fridayPrayerLabel(_nameOf(r.id), now)).join()}';
      },
      builder: (context, tick) {
        final now = nowOverride ?? tick;
        final dayState = dayStateOf(now);

        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SectionHeader(
                  title: 'اوقات شرعی',
                  count: dayState.periodLabel,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        // «—» until the tracker resolves: the rows' circles
                        // are drawn from the same snapshot, so an unresolved
                        // read used to read as «you have logged nothing».
                        tracker == null
                            ? '—'
                            : NumberFormat.ltrIsolated(
                                '${dayState.doneFardhCount}/5'),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: t.textMuted,
                          fontFamily: AppTheme.fontFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        icon: Icon(Icons.share_outlined,
                            size: 18, color: t.textMuted),
                        tooltip: 'اشتراک‌گذاری اوقات شرعی',
                        onPressed: () =>
                            context.push(RouteNames.prayerTimesShare),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
              ),
              // The hayz note itself moved under «دسترسی سریع» (home_tab): the
              // card keeps only what the rows need — `dayState.exempt`, so a
              // closed unlogged window on a period day wears no red dash.
              // The repository's location failure never used to reach the UI,
              // so a fallback calculation looked exactly like a fresh one.
              ValueListenableBuilder<String>(
                valueListenable: ref.watch(prayerLocationNoticeProvider),
                builder: (context, notice, _) => notice.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: _LocationNoticeRow(
                          onRetry: () => ref
                              .read(prayerTimesProvider.notifier)
                              .reload(forceRefresh: true),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: [
                    for (final row in dayState.rows)
                      _PrayerRowTile(
                        row: row,
                        name: fridayPrayerLabel(_nameOf(row.id), now),
                        icon: _iconOf(row.id),
                        highlighted: highlightKey == _englishKeyOf(row.id),
                        use12: use12,
                        toggler: ref.read(prayerTrackerProvider.notifier),
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
}

/// One single-line prayer row (~46dp): duotone tile · name · badges ·
/// time · check circle. The whole row is the toggle target. The row is a
/// faint box by default; [active] — an open window or a notification-tap
/// highlight — swaps it for the solid-gold open-window box, and a closed
/// upcoming window keeps its dashed gold outline over the faint fill.
class _PrayerRowTile extends StatelessWidget {
  const _PrayerRowTile({
    required this.row,
    required this.name,
    required this.icon,
    required this.highlighted,
    required this.use12,
    required this.toggler,
  });

  final PrayerRow row;
  final String name;
  final IconData icon;

  /// Notification-tap highlight: the open-window visual without the
  /// «اکنون» badge (only an actually-open window may wear it).
  final bool highlighted;
  final bool use12;
  final PrayerTracker toggler;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final accent = HomeColors.prayerRow(row.id);
    final isNow = row.state == PrayerRowState.now;
    final isNext = row.state == PrayerRowState.next;
    final isDone = row.state == PrayerRowState.done;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The open-window visual: an actually-open window, or the notification
    // tap's highlight for one that is closed.
    final active = isNow || highlighted;

    final hh = row.time.hour.toString().padLeft(2, '0');
    final mm = row.time.minute.toString().padLeft(2, '0');
    final timeText = TimeFormatters.formatTime('$hh:$mm', use12Hour: use12);

    // Every row is a faint box (the 2026-10-14 request: «هر نماز در بوکسی
    // کمرنگ»), and the open window's box turns solid gold. The faint recipe is
    // the rawatib card's: white @6 % on the dark card, parchment @85 % on the
    // light one. The «اکنون»/highlighted gradient is unchanged on light — it
    // is the «پررنگتر» state the request asks for — and the dark card wears
    // the gold wash instead of the light creams (2026-10-17 report).
    final decoration = active
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                HomeColors.nowRowStart(isDark),
                HomeColors.nowRowEnd(isDark),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HomeColors.goldLine),
          )
        : BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppTheme.parchment.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          );

    Widget content = Container(
      key: ValueKey('prayer-row-${row.id.name}'),
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: decoration,
      child: Row(
        children: [
          DuotoneIconTile(accent: accent, icon: icon, size: 36),
          const SizedBox(width: 10),
          Expanded(
            // Scale-down, never truncate: the name + state badge shrink
            // together only when the row is squeezed (320dp, big text);
            // at normal widths nothing scales.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w500,
                      color: isDone ? t.textMuted : t.textPrimary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  if (isNow) ...[
                    const SizedBox(width: 6),
                    const _RowBadge(
                      text: 'اکنون',
                      fill: AppPalette.heroGold,
                      textColor: AppTheme.espresso,
                    ),
                  ],
                  if (isNext) ...[
                    const SizedBox(width: 6),
                    _RowBadge(
                      text: 'بعدی',
                      textColor: HomeColors.nowRowTime(isDark),
                      fill: const Color(0x24E8C277),
                      borderColor: const Color(0x45E8C277),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            timeText,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 13.5),
              fontWeight: isNow ? FontWeight.w500 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isNow ? HomeColors.nowRowTime(isDark) : t.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: row.state == PrayerRowState.missed
                ? 'از وقت گذشته — برای ثبت لمس کنید'
                : (row.id == PrayerId.sunrise ? 'ثبت نماز ضحی' : 'ثبت نماز'),
            child: _CheckCircle(state: row.state),
          ),
        ],
      ),
    );

    if (isNext) {
      // NEXT: 1dp dashed gold border, radius 14.
      content = CustomPaint(
        painter: const DashedRRectPainter(color: HomeColors.goldLine),
        child: content,
      );
    }

    final VoidCallback toggled = switch (row.id) {
      PrayerId.sunrise => toggler.toggleDuha,
      PrayerId.fajr => () => toggler.toggleStatus(FardhPrayer.fajr),
      PrayerId.dhuhr => () => toggler.toggleStatus(FardhPrayer.dhuhr),
      PrayerId.asr => () => toggler.toggleStatus(FardhPrayer.asr),
      PrayerId.maghrib => () => toggler.toggleStatus(FardhPrayer.maghrib),
      PrayerId.isha => () => toggler.toggleStatus(FardhPrayer.isha),
    };

    // Audit P-03: a bare GestureDetector publishes no semantics at all, so
    // TalkBack could neither identify nor toggle any of the six prayer rows.
    // One labelled, togglable button node replaces the whole silent subtree.
    void onToggle() {
      HapticFeedback.selectionClick();
      toggled();
    }
    final stateLabel = switch (row.state) {
      PrayerRowState.done => 'انجام شده',
      PrayerRowState.missed => 'از وقت گذشته',
      PrayerRowState.now => 'وقت اکنون',
      PrayerRowState.next => 'وقت بعدی',
      PrayerRowState.upcoming => 'هنوز نرسیده',
    };
    final prayerLabel =
        row.id == PrayerId.sunrise ? 'نماز ضحی' : 'نماز $name';

    return Semantics(
      container: true,
      button: true,
      toggled: isDone,
      label: '$prayerLabel، ساعت $timeText، $stateLabel',
      hint: 'برای تغییر وضعیت دو بار ضربه بزنید',
      onTap: onToggle,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Small state pill («اکنون» / «بعدی») beside the row name — both wear a
/// real box so the two states read at a glance: اکنون solid gold, بعدی a
/// gold-tinted outline on the card.
class _RowBadge extends StatelessWidget {
  const _RowBadge({
    required this.text,
    required this.textColor,
    this.fill = Colors.transparent,
    this.borderColor,
  });

  final String text;
  final Color textColor;
  final Color fill;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: .8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppTheme.scaledFontSize(context, 9),
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: textColor,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

/// 21dp check circle: done = green fill + white check, missed = red fill +
/// white dash (2026-10-13: «علامت _ باشد نه تیک انجام» — a missed prayer is
/// not a done one, so it wears a dash, and the row stays tappable to log
/// it late), else hollow in a muted accent.
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.state});

  final PrayerRowState state;

  @override
  Widget build(BuildContext context) {
    final checked = state == PrayerRowState.done;
    final missed = state == PrayerRowState.missed;
    return SizedBox(
      width: 21,
      height: 21,
      child: checked || missed
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? HomeColors.done : HomeColors.missed,
              ),
              child: checked
                  ? Icon(Icons.check_rounded,
                      size: 13, color: Colors.white.withValues(alpha: .95))
                  : Icon(Icons.remove_rounded,
                      size: 13, color: Colors.white.withValues(alpha: .95)),
            )
          : CustomPaint(
              painter: _HollowCirclePainter(
                color: AppTheme.warmSand.withValues(alpha: .55),
              ),
            ),
    );
  }
}

class _HollowCirclePainter extends CustomPainter {
  const _HollowCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_HollowCirclePainter old) => old.color != color;
}

/// Dashed rounded-rect border (the «بعدی» row) — shared with the rawatib
/// card's past boxes (`dashed_border_painter.dart`).

/// Loading state — the prayer times have not landed yet. It says what is
/// happening instead of showing bare skeleton boxes, and past [_retryAfter]
/// it offers the retry, so the card can never sit on a skeleton indefinitely.
/// No repeating animation controller.
class _LoadingRows extends ConsumerStatefulWidget {
  const _LoadingRows();

  @override
  ConsumerState<_LoadingRows> createState() => _LoadingRowsState();
}

class _LoadingRowsState extends ConsumerState<_LoadingRows> {
  /// Past the platform bounds (5 s + 5 s) and the GPS attempts (12 s + 8 s) the
  /// wait is no longer normal — a wedged fix or an open permission dialog — so
  /// the card stops pretending it is about to finish.
  static const Duration _retryAfter = Duration(seconds: 12);

  Timer? _timer;
  bool _slow = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_retryAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await ref.read(prayerTimesProvider.notifier).reload(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final box = t.outline.withValues(alpha: .45);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'اوقات شرعی'),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 18, color: t.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _slow
                          ? 'محاسبهٔ اوقات شرعی طول کشید.'
                          : 'در حال محاسبهٔ اوقات شرعی…',
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: box,
                        borderRadius: BorderRadius.circular(11.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 13,
                        decoration: BoxDecoration(
                          color: box,
                          borderRadius: BorderRadius.circular(6.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 48,
                      height: 13,
                      decoration: BoxDecoration(
                        color: box,
                        borderRadius: BorderRadius.circular(6.5),
                      ),
                    ),
                  ],
                ),
              ),
            if (_slow)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_retrying ? 'در حال تلاش…' : 'تلاش دوباره'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The location failure the repository used to keep to itself: the card still
/// shows fallback times, so it must say they are not from a fresh fix and
/// offer the retry that clears the row.
class _LocationNoticeRow extends StatelessWidget {
  const _LocationNoticeRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final warn = AppColors.warning(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warn.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_rounded, size: 16, color: warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'موقعیت مکانی به‌روز نشد؛ اوقات نمایش‌داده‌شده ممکن است دقیق نباشد.',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11.5),
                height: 1.45,
                color: warn,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: warn,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'تلاش دوباره',
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatefulWidget {
  const _ErrorCard({
    required this.error,
    required this.stackTrace,
    required this.onRetry,
  });

  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  @override
  void initState() {
    super.initState();
    // #151: the technical failure belongs in the log, never on screen —
    // a raw exception string is meaningless to the reader.
    AppLogger.error('home.prayerTimesCard', widget.error, widget.stackTrace);
  }

  @override
  Widget build(BuildContext context) {
    // The panel replaces the hand-built card this used to be — same words,
    // same retry, but the one surface the rest of the app now draws failures
    // with. The technical detail stays in the log (see initState) and reaches
    // the screen in debug builds only.
    return FailureView(
      id: 'prayer_times_home',
      title: 'اوقات شرعی در دسترس نیست',
      detail: 'این کارت نتوانست اوقات امروز را بخواند؛ با تلاش دوباره از نو '
          'خوانده می‌شود.',
      onRetry: widget.onRetry,
      // No `error:` here on purpose: initState already logs it, and this card's
      // contract (#151) is that the exception never appears on screen — not
      // even as a debug block, because a test asserts exactly that.
    );
  }
}
