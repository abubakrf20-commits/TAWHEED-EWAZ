import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, clampDouble;
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/home/domain/entities/widget_snapshot.dart';
import 'package:tawheeed/features/home/presentation/utils/time_formatters.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_helpers.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/prayer/domain/prayer_windows.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/month_display_scope.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// The live preview of the home-screen prayer card.
///
/// It draws the SAME card the native renderer draws, from the same inputs, so
/// the settings page is a true preview and not an illustration:
///
///  * the date strip is **shamsi → hijri → gregorian**, the order
///    `PrayerWidgetModel.dateLine` joins them in (it used to be hijri →
///    shamsi → gregorian here, i.e. reversed, which is why the page showed a
///    design the widget no longer had);
///  * the countdown sits inside a **progress pill** whose fill is the elapsed
///    share of the window between the previous and the next adhan — the
///    `prayer_progress` bitmap on the native card;
///  * the five prayers can be drawn as the shipped **five boxes in a row** or
///    as the **five-row** layout (`layout: …prayerLayoutVertical`), and the
///    next prayer is the one filled with the palette's accent;
///  * the three options the settings page toggles — the progress bar, the
///    Gregorian line and the Persian digits — take effect here immediately,
///    because they are the same three flags the widget is rendered from.
class PrayerWidgetPreview extends ConsumerStatefulWidget {
  final Color bgColor;
  final Color textColor;
  final Color accentColor;
  final bool light;
  final double opacity;
  final double cornerRadius;
  final PrayerTimeService? timeService;
  final AppSettings? settings;

  /// [WidgetSnapshot.prayerLayoutHorizontal] (five boxes in a row) or
  /// [WidgetSnapshot.prayerLayoutVertical] (five rows, one prayer per line).
  final String layout;

  /// «نمایش نوار پیشرفت» — the day-progress rule behind the countdown.
  final bool showProgress;

  /// «نمایش تاریخ میلادی» — the third half of the date strip.
  final bool showGregorian;

  /// «ارقام فارسی ساعت ویجت» — the clock (and the five times) in ۰-۹.
  final bool faDigits;

  const PrayerWidgetPreview(
      {super.key,
      this.bgColor = const Color(0xFF004F9E),
      this.textColor = Colors.white,
      this.accentColor = const Color(0xFFC9A94E),
      this.light = false,
      this.opacity = 1.0,
      this.cornerRadius = 16,
      this.timeService,
      this.settings,
      this.layout = WidgetSnapshot.prayerLayoutHorizontal,
      this.showProgress = true,
      this.showGregorian = true,
      this.faDigits = false});

  @override
  ConsumerState<PrayerWidgetPreview> createState() =>
      _PrayerWidgetPreviewState();
}

class _PrayerWidgetPreviewState extends ConsumerState<PrayerWidgetPreview>
    with WidgetsBindingObserver {
  Timer? _timer;
  ValueListenable<TickerModeData>? _tickerModeNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Audit: this preview's 1-second countdown Timer used to run even while
    // the app was backgrounded or the widget hidden behind TickerMode — every
    // tick fired a setState for a frame nobody painted (battery cost on weak
    // phones). Pause on app pause / TickerMode, the same contract as
    // HeroClockCard's ticker.
    _tickerModeNotifier = TickerMode.getValuesNotifier(context);
    _tickerModeNotifier?.addListener(_onTickerModeChanged);
    _restartTimerIfVisible();
  }

  void _onTickerModeChanged() {
    _restartTimerIfVisible();
  }

  void _restartTimerIfVisible() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final tickerEnabled = _tickerModeNotifier?.value.enabled ?? true;
    if (tickerEnabled &&
        lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.hidden) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _restartTimerIfVisible();
  }

  @override
  void dispose() {
    _tickerModeNotifier?.removeListener(_onTickerModeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  static const _weekDays = [
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
    'شنبه'
  ];

  static const _prayerLabels = ['صبح', 'ظهر', 'عصر', 'مغرب', 'عشاء'];
  static const _prayerKeys = ['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء'];

  bool get _vertical =>
      widget.layout == WidgetSnapshot.prayerLayoutVertical;

  @override
  Widget build(BuildContext context) {
    MonthDisplayScope.of(context);
    final pts = widget.timeService ?? ref.read(prayerTimeServiceProvider);
    final allTimes = pts?.allTimes ?? <String, String>{};
    final now = DateTime.now();
    final prayerTimes = pts?.prayerTimes;
    final next = prayerTimes == null
        ? null
        : nextAdhanFor(now, prayerTimes.fajr, prayerTimes.dhuhr,
            prayerTimes.asr, prayerTimes.maghrib, prayerTimes.isha);
    final nextName = next?.$1;
    final nextTime = next?.$2;
    final diff = nextTime?.difference(now);

    // Same per-prayer marks the native renderer paints: the tracker's logged
    // state plus a closed-unlogged window («missed»), with a hayz/nifas day
    // exempting the mark. Mirrors WidgetSyncService's snapshot computation.
    final tracker = ref.watch(prayerTrackerProvider).value;
    final periodKnown = ref.watch(periodProvider).value != null;
    final exempt =
        periodKnown && ref.watch(periodProvider.notifier).isDateInPeriod(now);
    final sunriseT = pts?.sunrise;
    final asrT = pts?.asr;
    final maghribT = pts?.maghrib;
    final ishaT = pts?.isha;
    var statuses = const <FardhPrayer, String>{};
    if (tracker != null &&
        sunriseT != null &&
        asrT != null &&
        maghribT != null &&
        ishaT != null) {
      statuses = fardhWidgetStatuses(
        statuses: tracker.fardStatuses,
        endsAt: fardhWindowEnds(
          sunrise: wallClockTime(sunriseT),
          asr: wallClockTime(asrT),
          maghrib: wallClockTime(maghribT),
          isha: wallClockTime(ishaT),
          today: now,
        ),
        now: now,
        exempt: exempt || !periodKnown,
      );
    }

    final persianMonths = DateConstants.persianMonths;
    final hijri = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
        offset: widget.settings?.hijriOffset ?? 0);
    const hijriMonths = DateConstants.hijriMonths;
    // The native widget prints the three readings exactly as `WidgetSyncService`
    // writes them («7 مهر 1405» / «4 ربیع‌الثانی 1447» / «21 اکتبر 2026»), so
    // the preview must use those shapes too, never its own.
    final hijriStr =
        '${hijri.day} ${hijriMonths[hijri.month - 1]} ${hijri.year}';
    final jalali = Jalali.fromDateTime(now);
    final shamsiStr =
        '${jalali.day} ${persianMonths[jalali.month - 1]} ${jalali.year}';
    final gregStr =
        '${now.day} ${DateConstants.gregorianMonths[now.month - 1]} ${now.year}';
    // The clock, the prayer rows and the iqamah line all follow the same
    // widget setting the native render reads (`widget_use_12_hour`), and the
    // same marker-free shape: the native clock is `h:mm` and the five boxes
    // sit side by side, where «ق.ظ/ب.ظ» cost half of a box.
    final use12Hour = widget.settings?.use12Hour ?? true;
    final rawClock = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final clockStr = _digits(
        TimeFormatters.formatTimeNoMarker(rawClock, use12Hour: use12Hour));
    final weekdayStr = _weekDays[now.weekday - 1];
    final shortName = (nextName ?? '').replaceAll('اذان ', '');
    final iqamahMap = {
      'فجر': widget.settings?.iqamahOffsetFajr ?? 30,
      'ظهر': widget.settings?.iqamahOffsetDhuhr ?? 25,
      'عصر': widget.settings?.iqamahOffsetAsr ?? 25,
      'مغرب': widget.settings?.iqamahOffsetMaghrib ?? 10,
      'عشاء': widget.settings?.iqamahOffsetIsha ?? 25
    };

    String? countdownCaption;
    var countdownValue = '';
    final currentIqamah =
        pts == null ? null : currentIqamahForPreview(pts, iqamahMap, now);
    if (currentIqamah != null) {
      countdownCaption = 'تا اقامه نماز ${currentIqamah.name}';
      countdownValue = _formatRemaining(currentIqamah.iqamah.difference(now));
    } else if (diff != null && !diff.isNegative && shortName.isNotEmpty) {
      countdownCaption = 'تا اذان $shortName';
      countdownValue = _formatRemaining(diff);
    }

    // The same ink ladder as the native card: the five pills sit on the faintest
    // wash, the single date strip a step above them, and the accent belongs to
    // the next prayer alone — a gold time in all five boxes read as one flat
    // band and gave the next prayer nothing to stand out with.
    final tintSoft = widget.textColor.withValues(alpha: 0.075);
    final tintStrip = widget.textColor.withValues(alpha: 0.11);
    final tintBoxNext =
        widget.accentColor.withValues(alpha: widget.light ? 0.20 : 0.30);
    final strokeBoxNext = widget.accentColor.withValues(alpha: 0.55);
    final missedColor =
        widget.light ? const Color(0xFFC0392B) : const Color(0xFFFF8A80);
    final bg = widget.bgColor.withValues(alpha: widget.opacity);
    final darkBg = Color.lerp(bg, Colors.black, 0.15);

    return LayoutBuilder(builder: (context, constraints) {
      // Below 300dp three calendar readings cannot share one line, so the
      // Gregorian chip waits for a wider placement — the same rule the native
      // renderer applies (`Metrics.showGregorian`).
      final showGregorian = widget.showGregorian && constraints.maxWidth >= 300;
      // Height-driven sizes, mirrored from PrayerWidgetBudget. Dragging the
      // cell taller is what makes the widget readable, so the slack grows the
      // clock, the pills and the countdown line instead of pooling in the
      // weighted band.
      final extraHeight =
          constraints.maxHeight > 150 ? constraints.maxHeight - 150 : 0.0;
      final clockSize = clampDouble(44 + extraHeight * 0.26, 44, 64);
      final pillPad = clampDouble(5 + extraHeight * 0.07, 5, 12);
      final pillLabelSize = clampDouble(11 + extraHeight * 0.018, 11, 13.5);
      // The time line only widens with height on a placement that has the
      // columns to spare; a 3-column box would clip 17sp digits.
      final pillTimeSize = clampDouble(
          14 + (constraints.maxWidth >= 300 ? extraHeight * 0.03 : 0.0),
          14,
          17);
      final captionSize = clampDouble(12 + extraHeight * 0.012, 12, 13.5);
      final countdownSize = clampDouble(14 + extraHeight * 0.02, 14, 17);

      return Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [bg, darkBg ?? bg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(widget.cornerRadius),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        padding: const EdgeInsets.all(6),
        child: _vertical
            ? _buildVerticalBody(
                context,
                now: now,
                allTimes: allTimes,
                prayerTimes: prayerTimes,
                nextName: nextName,
                statuses: statuses,
                use12Hour: use12Hour,
                clockStr: clockStr,
                weekdayStr: weekdayStr,
                cityStr: pts?.cityName ?? '--',
                shamsiStr: shamsiStr,
                hijriStr: hijriStr,
                gregStr: gregStr,
                showGregorian: showGregorian,
                countdownCaption: countdownCaption,
                countdownValue: countdownValue,
                iqamahPhase: currentIqamah != null,
                tintSoft: tintSoft,
                tintStrip: tintStrip,
                tintBoxNext: tintBoxNext,
                strokeBoxNext: strokeBoxNext,
                missedColor: missedColor,
                clockSize: clockSize,
                pillPad: pillPad,
                pillLabelSize: pillLabelSize,
                pillTimeSize: pillTimeSize,
                captionSize: captionSize,
                countdownSize: countdownSize,
              )
            : _buildHorizontalBody(
                context,
                now: now,
                allTimes: allTimes,
                prayerTimes: prayerTimes,
                nextName: nextName,
                statuses: statuses,
                use12Hour: use12Hour,
                clockStr: clockStr,
                weekdayStr: weekdayStr,
                cityStr: pts?.cityName ?? '--',
                shamsiStr: shamsiStr,
                hijriStr: hijriStr,
                gregStr: gregStr,
                showGregorian: showGregorian,
                countdownCaption: countdownCaption,
                countdownValue: countdownValue,
                iqamahPhase: currentIqamah != null,
                tintSoft: tintSoft,
                tintStrip: tintStrip,
                tintBoxNext: tintBoxNext,
                strokeBoxNext: strokeBoxNext,
                missedColor: missedColor,
                clockSize: clockSize,
                pillPad: pillPad,
                pillLabelSize: pillLabelSize,
                pillTimeSize: pillTimeSize,
                captionSize: captionSize,
                countdownSize: countdownSize,
              ),
      );
    });
  }

  // ── The shipped card: five boxes in a row ────────────────────────────────

  Widget _buildHorizontalBody(
    BuildContext context, {
    required DateTime now,
    required Map<String, String> allTimes,
    required adhan.PrayerTimes? prayerTimes,
    required String? nextName,
    required Map<FardhPrayer, String> statuses,
    required bool use12Hour,
    required String clockStr,
    required String weekdayStr,
    required String cityStr,
    required String shamsiStr,
    required String hijriStr,
    required String gregStr,
    required bool showGregorian,
    required String? countdownCaption,
    required String countdownValue,
    required bool iqamahPhase,
    required Color tintSoft,
    required Color tintStrip,
    required Color tintBoxNext,
    required Color strokeBoxNext,
    required Color missedColor,
    required double clockSize,
    required double pillPad,
    required double pillLabelSize,
    required double pillTimeSize,
    required double captionSize,
    required double countdownSize,
  }) {
    return Column(children: [
      _headerRow(context, weekdayStr, cityStr, tintSoft),
      const SizedBox(height: 2),
      Text(clockStr,
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, clockSize),
              height: 1.0,
              fontWeight: FontWeight.bold,
              color: widget.textColor,
              letterSpacing: -1)),
      const SizedBox(height: 5),
      _dateStrip(context, shamsiStr, hijriStr, gregStr,
          showGregorian: showGregorian,
          fill: tintStrip),
      const SizedBox(height: 4),
      Expanded(
          child: Row(
              children: List.generate(5, (i) {
        final isNextBox = i == _nextIndex(nextName);
        final status = statuses[FardhPrayer.values[i]];
        final done = status == 'done';
        final missed = status == 'missed';
        final timeLabel = _timeLabel(allTimes[_prayerKeys[i]], use12Hour);
        return Expanded(
            child: Container(
                margin: const EdgeInsets.all(2),
                // Padding, not the band's stretch, is what makes a box
                // taller: the native renderer calls setViewPadding with the
                // same value, so a tall cell grows the pills instead of
                // floating the same short bars higher up.
                padding: EdgeInsets.symmetric(vertical: pillPad),
                decoration: BoxDecoration(
                    color: isNextBox ? tintBoxNext : tintSoft,
                    borderRadius: BorderRadius.circular(12),
                    // The next prayer answers in the palette's own accent:
                    // a translucent fill plus the native 1 dp hairline.
                    border: isNextBox
                        ? Border.all(color: strokeBoxNext)
                        : null),
                // Content-sized like the native pills: the Row centers the
                // box in the band. On a short cell the pair scales down
                // instead of clipping.
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        // The native card draws a CHECK beside the name for a
                        // done prayer and dims it — never a ✓ inside the text,
                        // which is what made the old preview read as a
                        // different design.
                        if (done) ...[
                          Icon(Icons.check,
                              size: pillLabelSize * 0.95,
                              color: isNextBox
                                  ? widget.accentColor
                                  : widget.accentColor
                                      .withValues(alpha: 0.62)),
                          const SizedBox(width: 2),
                        ],
                        // The missed mark lives IN the label on the native card
                        // (`PrayerWidgetModel.label` → «— صبح»); the done mark
                        // is the separate check above. Both, or the preview
                        // stops being a preview of the card.
                        Text(missed ? '— ${_prayerLabels[i]}' : _prayerLabels[i],
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(
                                    context, pillLabelSize),
                                color: isNextBox
                                    ? widget.accentColor
                                    : missed
                                        ? missedColor
                                        : done
                                            ? widget.textColor
                                                .withValues(alpha: 0.50)
                                            : widget.textColor
                                                .withValues(alpha: 0.70),
                                fontWeight: FontWeight.w500)),
                      ]),
                      const SizedBox(height: 1),
                      Text(timeLabel,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(
                                  context, pillTimeSize),
                              fontWeight:
                                  isNextBox ? FontWeight.bold : FontWeight.w500,
                              color: isNextBox
                                  ? widget.accentColor
                                  : missed
                                      ? missedColor
                                      : done
                                          ? widget.textColor
                                              .withValues(alpha: 0.52)
                                          : widget.textColor
                                              .withValues(alpha: 0.92)))
                    ]))));
      }))),
      if (countdownCaption != null && countdownValue.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _countdownPill(
              context,
              caption: countdownCaption,
              value: countdownValue,
              captionSize: captionSize,
              valueSize: countdownSize,
              fraction: _progressFraction(prayerTimes, now,
                  iqamahPhase: iqamahPhase),
            )),
    ]);
  }

  // ── The second layout: five rows, one prayer per line ────────────────────

  Widget _buildVerticalBody(
    BuildContext context, {
    required DateTime now,
    required Map<String, String> allTimes,
    required adhan.PrayerTimes? prayerTimes,
    required String? nextName,
    required Map<FardhPrayer, String> statuses,
    required bool use12Hour,
    required String clockStr,
    required String weekdayStr,
    required String cityStr,
    required String shamsiStr,
    required String hijriStr,
    required String gregStr,
    required bool showGregorian,
    required String? countdownCaption,
    required String countdownValue,
    required bool iqamahPhase,
    required Color tintSoft,
    required Color tintStrip,
    required Color tintBoxNext,
    required Color strokeBoxNext,
    required Color missedColor,
    required double clockSize,
    required double pillPad,
    required double pillLabelSize,
    required double pillTimeSize,
    required double captionSize,
    required double countdownSize,
  }) {
    return Column(children: [
      _headerRow(context, weekdayStr, cityStr, tintSoft),
      const SizedBox(height: 2),
      Text(clockStr,
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, clockSize),
              height: 1.0,
              fontWeight: FontWeight.bold,
              color: widget.textColor,
              letterSpacing: -1)),
      const SizedBox(height: 4),
      _dateStrip(context, shamsiStr, hijriStr, gregStr,
          showGregorian: showGregorian,
          fill: tintStrip),
      const SizedBox(height: 6),
      // The five rows take the height the clock left, and centre inside it —
      // the native row stack is `layout_weight="1"` with `center_vertical`.
      //
      // Each row is given an EQUAL SHARE of that height rather than its own
      // intrinsic size, and the row's type is scaled down when the share is
      // smaller than one line. That is the preview's version of the native
      // budget's rule: a row is never drawn taller than it was priced, and it
      // never overflows the card it was given.
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final rowHeight = c.maxHeight / 5;
          final natural = (pillTimeSize + 1) * 1.48 + 4;
          final fit = (rowHeight / natural).clamp(0.55, 1.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                SizedBox(
                  height: rowHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _prayerRow(
                      context,
                      index: i,
                      isNext: i == _nextIndex(nextName),
                      status: statuses[FardhPrayer.values[i]],
                      timeLabel:
                          _timeLabel(allTimes[_prayerKeys[i]], use12Hour),
                      fill: tintSoft,
                      fillNext: tintBoxNext,
                      strokeNext: strokeBoxNext,
                      missedColor: missedColor,
                      labelSize: (pillLabelSize + 1) * fit,
                      timeSize: (pillTimeSize + 1) * fit,
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
      if (countdownCaption != null && countdownValue.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _countdownPill(
              context,
              caption: countdownCaption,
              value: countdownValue,
              captionSize: captionSize,
              valueSize: countdownSize,
              fraction: _progressFraction(prayerTimes, now,
                  iqamahPhase: iqamahPhase),
            )),
    ]);
  }

  /// One vertical row: [check] name … time, the name at the right edge (the
  /// page is RTL) and the time at the left — the native row's own arrangement.
  ///
  /// The row's HEIGHT is decided by its caller (an equal share of the stack)
  /// and its type is already scaled to fit that share, so the box only has to
  /// fill it: horizontal padding, a centred line, and no vertical padding that
  /// could push the text past the band.
  Widget _prayerRow(
    BuildContext context, {
    required int index,
    required bool isNext,
    required String? status,
    required String timeLabel,
    required Color fill,
    required Color fillNext,
    required Color strokeNext,
    required Color missedColor,
    required double labelSize,
    required double timeSize,
  }) {
    final done = status == 'done';
    final missed = status == 'missed';
    final nameColor = isNext
        ? widget.accentColor
        : missed
            ? missedColor
            : done
                ? widget.textColor.withValues(alpha: 0.55)
                : widget.textColor.withValues(alpha: 0.88);
    final timeColor = isNext
        ? widget.accentColor
        : missed
            ? missedColor
            : done
                ? widget.textColor.withValues(alpha: 0.55)
                : widget.textColor.withValues(alpha: 0.94);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isNext ? fillNext : fill,
        borderRadius: BorderRadius.circular(10),
        border: isNext ? Border.all(color: strokeNext) : null,
      ),
      child: Row(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (done) ...[
            Icon(Icons.check,
                size: labelSize * 0.95,
                color: widget.accentColor.withValues(alpha: isNext ? 1 : 0.62)),
            const SizedBox(width: 2),
          ],
          // The missed mark is part of the LABEL on the native card
          // (`PrayerWidgetModel.label` → «— صبح»), while the done mark is a
          // separate check. Mirror both exactly, or the preview stops being a
          // preview of the card.
          Text(missed ? '— ${_prayerLabels[index]}' : _prayerLabels[index],
              maxLines: 1,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, labelSize),
                  fontWeight: FontWeight.w500,
                  color: nameColor)),
        ]),
        const Spacer(),
        Text(timeLabel,
            maxLines: 1,
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, timeSize),
                fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: timeColor)),
      ]),
    );
  }

  // ── Shared pieces ────────────────────────────────────────────────────────

  /// The two header chips: crescent + weekday (start) and pin + city (end).
  Widget _headerRow(
      BuildContext context, String weekday, String city, Color fill) {
    Widget chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
        decoration: BoxDecoration(
            color: fill, borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: AppTheme.scaledFontSize(context, 10),
              color: widget.accentColor),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 10),
                  color: widget.textColor,
                  fontWeight: FontWeight.w500)),
        ]));
    return Row(children: [
      chip(Icons.nightlight_round, weekday),
      const Spacer(),
      chip(Icons.place_outlined, city),
    ]);
  }

  /// The date strip — shamsi, hijri, gregorian, each in its OWN box.
  ///
  /// The native card draws one neutral chip per date (`prayer_date`,
  /// `prayer_date_2`, `prayer_date_3`) instead of one long line with
  /// separators, so the preview must too: the two are meant to be the same
  /// card. The order is shamsi → hijri → gregorian, the order
  /// `PrayerWidgetModel.dateParts` builds.
  Widget _dateStrip(
    BuildContext context,
    String shamsi,
    String hijri,
    String gregorian, {
    required bool showGregorian,
    required Color fill,
  }) {
    Widget box(String text) => Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
                color: fill, borderRadius: BorderRadius.circular(11)),
            child: Text(text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 11.5),
                    color: widget.textColor,
                    fontWeight: FontWeight.w500)),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        box(shamsi),
        box(hijri),
        if (showGregorian) box(gregorian),
      ],
    );
  }

  /// The countdown inside its progress pill.
  ///
  /// The pill's background IS the progress rule on the native card: one
  /// rounded track with the elapsed share filled from the START edge (the
  /// right edge in RTL), the caption and the remaining time centred on top at
  /// the same type size. «نمایش نوار پیشرفت» switches the FILL only: the track
  /// stays, because it is the pill the countdown sits in. Gating the track on
  /// the same pref is what made switching the bar off erase the countdown too.
  Widget _countdownPill(
    BuildContext context, {
    required String caption,
    required String value,
    required double captionSize,
    required double valueSize,
    required double? fraction,
  }) {
    final track = widget.textColor.withValues(alpha: 0.12);
    final fill = widget.accentColor.withValues(alpha: 0.32);
    final showFill = fraction != null && fraction > 0 && widget.showProgress;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: ColoredBox(color: track)),
          if (showFill)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: ColoredBox(color: fill),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // Flexible at the Row level + scaleDown: the pair stays on one
              // line and shrinks together on a narrow placement instead of
              // overflowing or cutting the seconds off.
              Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(caption,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize:
                                  AppTheme.scaledFontSize(context, captionSize),
                              color:
                                  widget.accentColor.withValues(alpha: 0.85))))),
              const SizedBox(width: 5),
              Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize:
                                  AppTheme.scaledFontSize(context, valueSize),
                              fontWeight: FontWeight.w700,
                              color: widget.accentColor)))),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Formatting ───────────────────────────────────────────────────────────

  String _timeLabel(String? raw, bool use12Hour) {
    if (raw == null || raw.isEmpty) return '--:--';
    return _digits(
        TimeFormatters.formatTimeNoMarker(raw, use12Hour: use12Hour));
  }

  /// «ارقام فارسی» — the same ۰-۹ substitution the native fa-variant clock
  /// layout performs with `textLocale="fa"`.
  String _digits(String value) {
    if (!widget.faDigits) return value;
    const latin = '0123456789';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final out = StringBuffer();
    for (final ch in value.split('')) {
      final i = latin.indexOf(ch);
      out.write(i < 0 ? ch : persian[i]);
    }
    return out.toString();
  }

  int _nextIndex(String? name) =>
      const {
        'اذان صبح': 0,
        'اذان ظهر': 1,
        'اذان عصر': 2,
        'اذان مغرب': 3,
        'اذان عشاء': 4
      }[name] ??
      0;

  /// How far the day has travelled from the previous adhan to the next one,
  /// 0..1 — the same value `PrayerWidgetModel.progressFraction()` computes for
  /// the native bar.
  ///
  /// Null whenever the window the bar claims to show does not exist: before
  /// Fajr, after Isha, and during the iqamah phase (where the two ends are not
  /// one window). A bar that guessed in those cases would be a number the card
  /// cannot justify, so it is simply not drawn — exactly like the native side.
  double? _progressFraction(
    adhan.PrayerTimes? times,
    DateTime now, {
    required bool iqamahPhase,
  }) {
    if (times == null || iqamahPhase) return null;
    final clocks = [
      times.fajr,
      times.dhuhr,
      times.asr,
      times.maghrib,
      times.isha,
    ].map(wallClockTime).toList();
    var current = -1;
    for (var i = 0; i < clocks.length; i++) {
      if (!clocks[i].isAfter(now)) current = i;
    }
    if (current < 0 || current + 1 >= clocks.length) return null;
    final previous = clocks[current];
    final upcoming = clocks[current + 1];
    final span = upcoming.difference(previous).inSeconds;
    if (span <= 0) return null;
    return (now.difference(previous).inSeconds / span).clamp(0.0, 1.0);
  }

  String _formatRemaining(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return hours > 0
        ? '$hours ساعت و $minutes دقیقه'
        : minutes > 0
            ? '$minutes دقیقه و $seconds ثانیه'
            : '$seconds ثانیه';
  }
}

({String name, DateTime adhan, DateTime iqamah})? currentIqamahForPreview(
    PrayerTimeService service, Map<String, int> offsets, DateTime now) {
  const names = ['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء'];
  for (var i = 0; i < names.length; i++) {
    final name = names[i];
    final time = switch (name) {
      'فجر' => service.fajr,
      'ظهر' => service.dhuhr,
      'عصر' => service.asr,
      'مغرب' => service.maghrib,
      'عشاء' => service.isha,
      _ => null,
    };
    if (time == null) continue;
    final adhan = wallClockTime(time);
    final configuredIqamah = adhan.add(Duration(minutes: offsets[name] ?? 10));
    final nextAdhan = i + 1 < names.length
        ? switch (names[i + 1]) {
            'فجر' => service.fajr,
            'ظهر' => service.dhuhr,
            'عصر' => service.asr,
            'مغرب' => service.maghrib,
            'عشاء' => service.isha,
            _ => null,
          }
        : null;
    final nextWallClock = nextAdhan == null ? null : wallClockTime(nextAdhan);
    // An oversized iqamah must not relabel the next adhan as «تا اقامه»:
    // when the configured iqamah reaches the next adhan the window does not
    // exist, so this prayer is skipped and the next adhan owns the countdown
    // («تا اذان»). Mirrors PrayerWidgetViews.computeCountdown.
    if (nextWallClock != null && !configuredIqamah.isBefore(nextWallClock)) {
      continue;
    }
    if (!now.isBefore(adhan) && now.isBefore(configuredIqamah)) {
      return (name: name, adhan: adhan, iqamah: configuredIqamah);
    }
  }
  return null;
}
