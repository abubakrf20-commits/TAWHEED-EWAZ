import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart';
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/worship/domain/evaluation_stats_compute.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';
import 'package:tawheeed/features/worship/presentation/utils/report_tier_colors.dart';
import 'package:tawheeed/features/worship/presentation/utils/worship_colors.dart';
import 'package:tawheeed/features/worship/presentation/widgets/evaluation_report_card.dart';
import 'package:tawheeed/features/worship/presentation/widgets/evaluation_reset_dialog.dart';
import 'package:tawheeed/shared/services/share_widget_as_image.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class EvaluationStatsWidget extends ConsumerStatefulWidget {
  const EvaluationStatsWidget({super.key});

  @override
  ConsumerState<EvaluationStatsWidget> createState() =>
      _EvaluationStatsWidgetState();
}

class _EvaluationStatsWidgetState extends ConsumerState<EvaluationStatsWidget> {
  int _tab = 0;
  int _monthOffset = 0;

  int _azkarVersion = 0;
  String _azkarFutureKey = '';
  Future<Map<PrayerPeriod, int>>? _azkarFuture;

  @override
  Widget build(BuildContext context) {
    final evalAsync = ref.watch(evaluationProvider);
    final ptAsync = ref.watch(prayerTrackerProvider);
    ref.watch(periodProvider);
    _azkarVersion = ref.watch(azkarVersionProvider);
    ref.watch(accentPresetProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, DsSpacing.page, DsSpacing.page, 24),
      children: [
        SegmentedTabs(
          tabs: const [
            SegmentedTab(label: 'روزانه', icon: Icons.today),
            SegmentedTab(label: 'هفتگی', icon: Icons.view_week),
            SegmentedTab(label: 'ماهانه', icon: Icons.calendar_month),
          ],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: DsSpacing.page),
        if (evalAsync.value == null || ptAsync.value == null)
          // First load (or a hard error with no cached value): never render
          // the tabs against null data — show an explicit state instead.
          if (evalAsync.hasError || ptAsync.hasError)
            _buildErrorCard(context)
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
        else ...[
          if (_tab == 0) _buildDaily(evalAsync, ptAsync),
          if (_tab == 1) _buildWeekly(evalAsync, ptAsync),
          if (_tab == 2) _buildMonthly(evalAsync, ptAsync),
        ],
      ],
    );
  }

  /// Error card with retry for the evaluation tab when providers fail
  /// before producing any value.
  ///
  /// The old copy said «اتصال و حافظه دستگاه را بررسی کنید» — advice about the
  /// network for a read that never touches it. The evaluation is assembled from
  /// the app's own Drift tables, so sending the reader to check Wi-Fi sent them
  /// to fix the wrong thing while their actual worship records sat there intact.
  Widget _buildErrorCard(BuildContext context) {
    return FailureView(
      id: 'evaluation_load',
      title: 'بارگذاری ارزیابی ممکن نشد',
      detail:
          'ارزیابی از ثبت‌های خودِ برنامه ساخته می‌شود و اینترنت لازم ندارد؛ '
          'عبادت‌هایی که ثبت کرده‌اید پاک نشده‌اند.',
      onRetry: () {
        ref.invalidate(evaluationProvider);
        ref.invalidate(prayerTrackerProvider);
      },
    );
  }

  /// Asks, then wipes exactly the tab's own range.
  ///
  /// The old single reset sat in the page header and erased everything — yet
  /// left the prayer/adhkar/tasbih records the score is derived from standing,
  /// so the score re-derived itself before the reader's eyes and «the reset
  /// does nothing» was the honest reading of it. Now each tab resets only its
  /// own slice (user decision, 2026-11-05) and the slice is a FULL wipe —
  /// see [Evaluation.resetRange] for what leaves the DB.
  Future<void> _confirmReset(
    BuildContext context, {
    required EvaluationResetScope scope,
    required DateTime start,
    required DateTime end,
    required String rangeLabel,
  }) async {
    final notifier = ref.read(evaluationProvider.notifier);
    final impact = notifier.resetImpactForRange(start, end);
    final confirmed = await confirmEvaluationReset(
      context,
      scope: scope,
      rangeLabel: rangeLabel,
      days: impact.days,
      points: impact.points,
      bestStreak: impact.bestStreak,
    );
    if (!confirmed || !context.mounted) return;

    final backupPath = await notifier.resetRange(start, end);
    if (!context.mounted) return;
    if (backupPath == null) {
      // Says what did not happen, not just that something failed: the reader's
      // next question is whether their history is gone, and the answer is no.
      AppSnackBar.error(
        context,
        'ریست انجام نشد و ارزیابی این بازه سر جایش است.',
        onRetry: () => _confirmReset(
          context,
          scope: scope,
          start: start,
          end: end,
          rangeLabel: rangeLabel,
        ),
      );
      return;
    }
    // The reset wrote a backup first (user request, 2026-11-05), so the
    // confirmation carries a real undo — six seconds, then the snapshot ages
    // out of the snackbar (the file itself stays, pruned at five backups).
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
            'ارزیابی ${switch (scope) {
              EvaluationResetScope.daily => 'امروز',
              EvaluationResetScope.weekly => 'هفتگی',
              EvaluationResetScope.monthly => 'این ماه',
            }} پاک شد؛ شمارش از نو شروع می‌شود.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () async {
            final ok = await ref
                .read(evaluationProvider.notifier)
                .restoreFromBackup(backupPath);
            if (!mounted) return;
            AppSnackBar.show(
              this.context,
              ok
                  ? 'ارزیابی این بازه برگردانده شد.'
                  : 'بازگردانی ممکن نشد؛ نسخهٔ پشتیبان معتبر نیست.',
            );
          },
        ),
      ));
  }

  Widget _buildDaily(
    AsyncValue<EvaluationState> evalAsync,
    AsyncValue<PrayerTrackerState> ptAsync,
  ) {
    final evalState = evalAsync.value;
    final ptState = ptAsync.value;

    if (evalState == null || ptState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = evalState.worshipItems;
    final worshipDone = items.where((w) => w.done).length;
    final worshipTotal = items.length;
    final fastingItem = items.where((w) => w.id == 'fasting').firstOrNull;
    final fastingDone = fastingItem?.done ?? false;

    // During hayz/نفاس prayers & fasting aren't obligatory — they are shown
    // as «معاف» (exempt), never as if the user had completed them.
    // watch() so the flag refreshes when a period record is added/ends.
    ref.watch(periodProvider);
    final inPeriodToday =
        ref.read(periodProvider.notifier).isDateInPeriod(DateTime.now());

    final fardhDone = ptState.fardStatuses.values
        .where((s) => s == PrayerStatus.done || s == PrayerStatus.qada)
        .length;

    final sunnahDone = ptState.sunnahStatuses.values.where((v) => v).length +
        (ptState.duhaStatus ? 1 : 0);

    final azkarNotifier = ref.read(azkarProvider.notifier);
    final morningStats = azkarNotifier.periodStats(PrayerPeriod.morningAzkar);
    final eveningStats = azkarNotifier.periodStats(PrayerPeriod.eveningAzkar);
    final nightStats = azkarNotifier.periodStats(PrayerPeriod.night);

    final tasbihModels = ref.read(tasbihProvider).value;
    final dailyTasbihTarget =
        tasbihModels?.fold(0, (int sum, m) => sum + m.targetCount) ?? 0;

    final rings = [
      _RingData(
          label: 'فرض',
          done: fardhDone,
          total: 5,
          hue: PrayerHues.fajr,
          exempt: inPeriodToday),
      _RingData(
          label: 'رواتب و وتر',
          done: sunnahDone,
          total: 7,
          hue: PrayerHues.sunrise,
          exempt: inPeriodToday),
      if (fastingItem != null)
        _RingData(
            label: 'روزه',
            done: fastingDone ? 1 : 0,
            total: 1,
            hue: TopicHues.fasting,
            exempt: inPeriodToday),
      _RingData(
          label: 'طاعات',
          done: worshipDone,
          total: worshipTotal,
          hue: TopicHues.worshipChecklist,
          accent: _worshipBlend(items)),
      _RingData(
          label: 'اذکار صبح',
          done: morningStats['done'] ?? 0,
          total: morningStats['total'] ?? 0,
          hue: TopicHues.zakat),
      _RingData(
          label: 'اذکار شام',
          done: eveningStats['done'] ?? 0,
          total: eveningStats['total'] ?? 0,
          hue: PrayerHues.maghrib),
      _RingData(
          label: 'اذکار خواب',
          done: nightStats['done'] ?? 0,
          total: nightStats['total'] ?? 0,
          hue: TopicHues.moon),
      _RingData(
          label: 'تسبیح',
          done: evalState.totalDailyTasbih,
          total: dailyTasbihTarget,
          hue: SectionHues.tasbih),
    ];

    // Unified points-based score (same metric as the checklist screen).
    // maxScore includes prayer points so the امتیاز ring stays consistent.
    final notifier = ref.read(evaluationProvider.notifier);
    final score = evalState.dailyScore;
    final maxScore = notifier.dailyMaxScore;

    // Where the ceiling comes from. Zero-valued parts are dropped rather than
    // printed as «+ 0», so a user who turned a source off is not told they can
    // still earn from it.
    final parts = <String>[
      if (notifier.worshipDailyMax > 0) '${notifier.worshipDailyMax} طاعت',
      if (notifier.prayerDailyMax > 0) '${notifier.prayerDailyMax} نماز',
      if (notifier.adhkarDailyMax > 0) '${notifier.adhkarDailyMax} اذکار',
      if (notifier.tasbihDailyMax > 0) '${notifier.tasbihDailyMax} تسبیح',
    ];

    return Column(
      children: [
        _ScoreHero(
          score: score,
          maxScore: maxScore,
          label: 'امتیاز امروز',
          caption: parts.isEmpty ? null : 'سقف روز: ${parts.join(' + ')}',
        ),
        const SizedBox(height: DsSpacing.gap),
        _StreakCard(
          current: evalState.currentStreak,
          best: evalState.bestStreak,
        ),
        const SizedBox(height: DsSpacing.page),
        const SectionHeader(title: 'جزئیات امروز'),
        _buildRingGrid(rings),
        // Per-zikr tasbih breakdown — the detail behind the «تسبیح» ring.
        // Shows today's count vs each zikr's own target.
        if (tasbihModels?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: DsSpacing.gap),
            child: _TasbihDetailCard(
              models: tasbihModels!,
              todayCounts: evalState.tasbihTodayPerZikr,
            ),
          ),
        _ResetAction(
          tooltip: 'ریست ارزیابی روزانه',
          label: 'ریست ارزیابی امروز',
          onPressed: () => _confirmReset(
            context,
            scope: EvaluationResetScope.daily,
            start: DateTime.now(),
            end: DateTime.now(),
            rangeLabel: 'امروز',
          ),
        ),
      ],
    );
  }

  Widget _buildWeekly(
    AsyncValue<EvaluationState> evalAsync,
    AsyncValue<PrayerTrackerState> ptAsync,
  ) {
    final evalNotifier = ref.read(evaluationProvider.notifier);
    final ptNotifier = ref.read(prayerTrackerProvider.notifier);
    final azkarItems = AzkarData.allAzkar;
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 6));

    final activeDays = evalNotifier.weeklyActiveDays;

    final startKey = dateKeyOf(weekStart);
    final endKey = dateKeyOf(now);

    final prayerCounts = ptNotifier.countPrayersInRange(startKey, endKey);
    final periodDays = evalNotifier.periodDaysInRange(startKey, endKey);

    final fastingCount = evalNotifier.countFastingInRange(startKey, endKey);

    final worshipCount = evalNotifier.countWorshipDoneInRange(startKey, endKey);
    final currentItems =
        evalAsync.value?.worshipItems.where((w) => w.id != 'fasting') ??
            const <WorshipItem>[];
    final currentItemCount = currentItems.length;
    final worshipTotal = currentItemCount * 7;

    final tasbihModels = ref.read(tasbihProvider).value;
    final dailyTasbihTarget =
        tasbihModels?.fold(0, (int sum, m) => sum + m.targetCount) ?? 0;
    final weeklyTasbihTarget = dailyTasbihTarget * 7;

    final azkarFuture = _memoizedAzkarFuture(
      key: 'week|$_azkarVersion',
      startKey: startKey,
      endKey: endKey,
    );

    return FutureBuilder<Map<PrayerPeriod, int>>(
      future: azkarFuture,
      builder: (context, snapshot) {
        // Until the query resolves, the three azkar rings carry an unknown
        // reading — a failed query must never paint them as zeros.
        final azkarKnown = snapshot.hasData;
        final azkarStats = snapshot.data ?? const <PrayerPeriod, int>{};
        final morningDone =
            azkarKnown ? (azkarStats[PrayerPeriod.morningAzkar] ?? 0) : null;
        final eveningDone =
            azkarKnown ? (azkarStats[PrayerPeriod.eveningAzkar] ?? 0) : null;
        final nightDone =
            azkarKnown ? (azkarStats[PrayerPeriod.night] ?? 0) : null;
        final morningTotal =
            _totalForPeriod(azkarItems, PrayerPeriod.morningAzkar);
        final eveningTotal =
            _totalForPeriod(azkarItems, PrayerPeriod.eveningAzkar);
        final nightTotal = _totalForPeriod(azkarItems, PrayerPeriod.night);

        final tasbih7 = evalNotifier.tasbihCountForLast7Days();
        // Hayz days shrink the obligation totals (they were never due) rather
        // than being added to «done» — nothing is shown as done unless the
        // user actually recorded it.
        final fardhTotal7 = (35 - periodDays * 5).clamp(0, 35);
        final sunnahTotal7 = (49 - periodDays * 7).clamp(0, 49);
        final fastingTotal7 = (7 - periodDays).clamp(0, 7);
        final rings = [
          _RingData(
              label: 'فرض',
              done: prayerCounts.fardh,
              total: fardhTotal7,
              hue: PrayerHues.fajr),
          _RingData(
              label: 'رواتب و وتر',
              done: prayerCounts.sunnah + prayerCounts.duha,
              total: sunnahTotal7,
              hue: PrayerHues.sunrise),
          _RingData(
              label: 'روزه',
              done: fastingCount,
              total: fastingTotal7,
              hue: TopicHues.fasting),
          _RingData(
              label: 'طاعات',
              done: worshipCount,
              total: worshipTotal,
              hue: TopicHues.worshipChecklist,
              accent: _worshipBlend(evalAsync.value?.worshipItems ?? const [])),
          _RingData(
              label: 'اذکار صبح',
              done: morningDone,
              total: morningTotal * 7,
              hue: TopicHues.zakat),
          _RingData(
              label: 'اذکار شام',
              done: eveningDone,
              total: eveningTotal * 7,
              hue: PrayerHues.maghrib),
          _RingData(
              label: 'اذکار خواب',
              done: nightDone,
              total: nightTotal * 7,
              hue: TopicHues.moon),
          _RingData(
              label: 'تسبیح',
              done: tasbih7,
              total: weeklyTasbihTarget,
              hue: SectionHues.tasbih),
        ];

        // Unified points-based score for the week.
        final score = evalNotifier.weeklyPoints();
        final maxScore = 7 * evalNotifier.dailyMaxScore;

        final t = TimeThemeKit.of(context).palette;
        return Column(
          children: [
            _ScoreHero(
              score: score,
              maxScore: maxScore,
              label: 'امتیاز هفته',
              // The week is a trailing window of seven days that have all
              // already happened, so 7 × the daily ceiling is a reachable
              // maximum — unlike the month below, which has to drop the days
              // still to come.
              caption: '۷ روز گذشته · سقف هر روز '
                  '${evalNotifier.dailyMaxScore}',
            ),
            const SizedBox(height: DsSpacing.gap),
            _CompactSummaryRow(
              items: [
                _CompactItem(
                    icon: Icons.calendar_today,
                    label: 'روزهای فعال',
                    value: '$activeDays',
                    color: t.tertiary),
                _CompactItem(
                    icon: Icons.mosque,
                    label: 'فرض',
                    value: '${prayerCounts.fardh}/$fardhTotal7',
                    color: t.primary),
                if (periodDays > 0)
                  _CompactItem(
                      icon: Icons.water_drop_outlined,
                      label: 'معاف (حیض)',
                      value: '$periodDays روز',
                      color: dsContentColor(context, TopicHues.period)),
              ],
            ),
            const SizedBox(height: DsSpacing.page),
            const SectionHeader(title: 'جزئیات هفته'),
            _buildRingGrid(rings),
            if (snapshot.hasError) _buildAzkarRetry(),
            const SizedBox(height: DsSpacing.gap),
            _WeeklyScoreChart(scores: evalNotifier.weeklyScores),
            _ResetAction(
              tooltip: 'ریست ارزیابی هفتگی',
              label: 'ریست ارزیابی هفتگی',
              onPressed: () => _confirmReset(
                context,
                scope: EvaluationResetScope.weekly,
                start: weekStart,
                end: now,
                rangeLabel: '۷ روز گذشته',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthly(
    AsyncValue<EvaluationState> evalAsync,
    AsyncValue<PrayerTrackerState> ptAsync,
  ) {
    final evalNotifier = ref.read(evaluationProvider.notifier);
    final ptNotifier = ref.read(prayerTrackerProvider.notifier);
    final azkarItems = AzkarData.allAzkar;

    final now = DateTime.now();
    final nowJ = evalNotifier.toJalali(now);
    // The stepper and the month picker speak Jalali months (_jalaliToOffset),
    // so the window must be a Jalali month too. Scoring the Gregorian month
    // while labelling it «فروردین» mixed two Persian months' days together and
    // made ±1 step repeat or skip one.
    final anchorJ = Jalali(nowJ.year, nowJ.month).add(months: _monthOffset);
    final monthDays = [
      for (var d = 1; d <= anchorJ.monthLength; d++)
        Jalali(anchorJ.year, anchorJ.month, d).toDateTime()
    ];
    final daysInMonth = monthDays.length;
    final monthStart = dateKeyOf(monthDays.first);
    final monthEnd = dateKeyOf(monthDays.last);

    final scores = [
      for (final d in monthDays) evalNotifier.getScoreForDate(d) ?? 0
    ];
    final activeDays = scores.where((s) => s > 0).length;

    final prayerCounts = ptNotifier.countPrayersInRange(monthStart, monthEnd);
    final periodDays = evalNotifier.periodDaysInRange(monthStart, monthEnd);
    final fastingCount = evalNotifier.countFastingInRange(monthStart, monthEnd);
    final worshipCount =
        evalNotifier.countWorshipDoneInRange(monthStart, monthEnd);
    final currentItems =
        evalAsync.value?.worshipItems.where((w) => w.id != 'fasting') ??
            const <WorshipItem>[];
    final currentItemCount = currentItems.length;
    final worshipTotal = currentItemCount * daysInMonth;

    final monthLabel =
        '${DateConstants.persianMonths[anchorJ.month - 1]} ${anchorJ.year}';

    final tasbihModels = ref.read(tasbihProvider).value;
    final dailyTasbihTarget =
        tasbihModels?.fold(0, (int sum, m) => sum + m.targetCount) ?? 0;
    final monthlyTasbihTarget = dailyTasbihTarget * daysInMonth;

    final azkarFuture = _memoizedAzkarFuture(
      key: 'month|$_monthOffset|$_azkarVersion',
      startKey: monthStart,
      endKey: monthEnd,
    );

    return FutureBuilder<Map<PrayerPeriod, int>>(
      future: azkarFuture,
      builder: (context, snapshot) {
        // Same unknown-not-zero rule as the weekly view.
        final azkarKnown = snapshot.hasData;
        final azkarStats = snapshot.data ?? const <PrayerPeriod, int>{};
        final morningDone =
            azkarKnown ? (azkarStats[PrayerPeriod.morningAzkar] ?? 0) : null;
        final eveningDone =
            azkarKnown ? (azkarStats[PrayerPeriod.eveningAzkar] ?? 0) : null;
        final nightDone =
            azkarKnown ? (azkarStats[PrayerPeriod.night] ?? 0) : null;
        final morningTotal =
            _totalForPeriod(azkarItems, PrayerPeriod.morningAzkar);
        final eveningTotal =
            _totalForPeriod(azkarItems, PrayerPeriod.eveningAzkar);
        final nightTotal = _totalForPeriod(azkarItems, PrayerPeriod.night);

        final tasbihMonth =
            monthDays.fold(0, (s, d) => s + evalNotifier.tasbihCountForDay(d));
        // Hayz days shrink the obligation totals instead of being counted as
        // done — see the weekly view for the same rule.
        final fardhTotalMonth =
            (5 * daysInMonth - periodDays * 5).clamp(0, 5 * daysInMonth);
        final sunnahTotalMonth =
            (7 * daysInMonth - periodDays * 7).clamp(0, 7 * daysInMonth);
        final fastingTotalMonth =
            (daysInMonth - periodDays).clamp(0, daysInMonth);
        final rings = [
          _RingData(
              label: 'فرض',
              done: prayerCounts.fardh,
              total: fardhTotalMonth,
              hue: PrayerHues.fajr),
          _RingData(
              label: 'رواتب و وتر',
              done: prayerCounts.sunnah + prayerCounts.duha,
              total: sunnahTotalMonth,
              hue: PrayerHues.sunrise),
          _RingData(
              label: 'روزه',
              done: fastingCount,
              total: fastingTotalMonth,
              hue: TopicHues.fasting),
          _RingData(
              label: 'طاعات',
              done: worshipCount,
              total: worshipTotal,
              hue: TopicHues.worshipChecklist,
              accent: _worshipBlend(evalAsync.value?.worshipItems ?? const [])),
          _RingData(
              label: 'اذکار صبح',
              done: morningDone,
              total: morningTotal * daysInMonth,
              hue: TopicHues.zakat),
          _RingData(
              label: 'اذکار شام',
              done: eveningDone,
              total: eveningTotal * daysInMonth,
              hue: PrayerHues.maghrib),
          _RingData(
              label: 'اذکار خواب',
              done: nightDone,
              total: nightTotal * daysInMonth,
              hue: TopicHues.moon),
          _RingData(
              label: 'تسبیح',
              done: tasbihMonth,
              total: monthlyTasbihTarget,
              hue: SectionHues.tasbih),
        ];

        // Unified points-based score for the selected month.
        final score = scores.fold(0, (a, b) => a + b);
        // The ring and the verdict must answer to the same denominator. The
        // chip below already judges the month on the days it could still
        // reach (`performanceRatingForDays`); the ring used to divide by all
        // 30, so on the 9th it read 4 % while the chip beside it said «خوب».
        // Days after today are not a ceiling the user failed to reach.
        final todayMidnight = DateTime(now.year, now.month, now.day);
        final elapsedDays =
            monthDays.where((d) => !d.isAfter(todayMidnight)).length;
        // A month entirely in the future has no elapsed day; it is rated on
        // its own length rather than dividing by zero.
        final reachableDays = elapsedDays == 0 ? daysInMonth : elapsedDays;
        final maxScore = evalNotifier.dailyMaxScore * reachableDays;

        final overallTasbih = evalAsync.value?.totalLifetimeTasbih ?? 0;

        final t = TimeThemeKit.of(context).palette;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMonthSelector(monthLabel),
                ),
                const SizedBox(width: DsSpacing.gap),
                IconButton.filled(
                  tooltip: 'اشتراک‌گذاری گزارش',
                  style: IconButton.styleFrom(backgroundColor: t.tertiary),
                  onPressed: () => _shareMonthlyReport(
                    monthLabel: monthLabel,
                    score: score,
                    maxScore: maxScore,
                    // Audit 8.17: rate the BROWSED month (its own elapsed
                    // days), not the live one — browsing a past month used
                    // to show the current month's rating.
                    rating: evalNotifier.performanceRatingForDays(monthDays),
                    activeDays: activeDays,
                    totalDays: scores.length,
                    streak: evalAsync.value?.currentStreak ?? 0,
                    prayerFardh: prayerCounts.fardh,
                    prayerFardhTotal: fardhTotalMonth,
                    sunnahDone: prayerCounts.sunnah + prayerCounts.duha,
                    sunnahTotal: sunnahTotalMonth,
                    fastingDone: fastingCount,
                    fastingTotal: fastingTotalMonth,
                    worshipDone: worshipCount,
                    worshipTotal: worshipTotal,
                    morningDone: morningDone,
                    morningTotal: morningTotal * daysInMonth,
                    eveningDone: eveningDone,
                    eveningTotal: eveningTotal * daysInMonth,
                    nightDone: nightDone,
                    nightTotal: nightTotal * daysInMonth,
                    tasbihDone: tasbihMonth,
                    tasbihTotal: monthlyTasbihTarget,
                  ),
                  icon: Icon(Icons.ios_share, size: 20, color: t.heroBottom),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.page),
            _ScoreHero(
              score: score,
              maxScore: maxScore,
              label: 'امتیاز ماه',
              // Same verdict as the share report: the month is judged on the
              // days it can still reach, not on a calendar the user has not
              // lived through yet.
              rating: evalNotifier.performanceRatingForDays(monthDays),
              caption: reachableDays == daysInMonth
                  ? '$daysInMonth روز · سقف هر روز ${evalNotifier.dailyMaxScore}'
                  : '$reachableDays روز گذشته از $daysInMonth · '
                      'سقف هر روز ${evalNotifier.dailyMaxScore}',
            ),
            const SizedBox(height: DsSpacing.gap),
            _CompactSummaryRow(
              items: [
                _CompactItem(
                    icon: Icons.calendar_today,
                    label: 'روزهای فعال',
                    value: '$activeDays/${scores.length}',
                    color: t.tertiary),
                _CompactItem(
                    icon: Icons.mosque,
                    label: 'فرض',
                    value: '${prayerCounts.fardh}/$fardhTotalMonth',
                    color: t.primary),
                if (periodDays > 0)
                  _CompactItem(
                      icon: Icons.water_drop_outlined,
                      label: 'معاف (حیض)',
                      value: '$periodDays روز',
                      color: dsContentColor(context, TopicHues.period)),
              ],
            ),
            const SizedBox(height: DsSpacing.gap),
            _MonthlyHeatmap(
              jalaliYear: anchorJ.year,
              jalaliMonth: anchorJ.month,
              notifier: evalNotifier,
            ),
            const SizedBox(height: DsSpacing.gap),
            _MonthlyScoreChart(scores: scores),
            const SizedBox(height: DsSpacing.page),
            const SectionHeader(title: 'جزئیات ماه'),
            _buildRingGrid(rings),
            if (snapshot.hasError) _buildAzkarRetry(),
            const SizedBox(height: DsSpacing.gap),
            _OverallTasbihCard(total: overallTasbih),
            _ResetAction(
              tooltip: 'ریست ارزیابی ماهانه',
              label: 'ریست ارزیابی ماه',
              onPressed: () => _confirmReset(
                context,
                scope: EvaluationResetScope.monthly,
                start: monthDays.first,
                end: monthDays.last,
                rangeLabel: monthLabel,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareMonthlyReport({
    required String monthLabel,
    required int score,
    required int maxScore,
    required String rating,
    required int activeDays,
    required int totalDays,
    required int streak,
    required int prayerFardh,
    required int prayerFardhTotal,
    required int sunnahDone,
    required int sunnahTotal,
    required int fastingDone,
    required int fastingTotal,
    required int worshipDone,
    required int worshipTotal,
    required int? morningDone,
    required int morningTotal,
    required int? eveningDone,
    required int eveningTotal,
    required int? nightDone,
    required int nightTotal,
    required int tasbihDone,
    required int tasbihTotal,
  }) async {
    final card = EvaluationReportCard(
      monthLabel: monthLabel,
      score: score,
      maxScore: maxScore,
      rating: rating,
      activeDays: activeDays,
      totalDays: totalDays,
      streak: streak,
      rows: [
        ReportProgressRow('فرض', prayerFardh, prayerFardhTotal),
        ReportProgressRow('رواتب و وتر', sunnahDone, sunnahTotal),
        ReportProgressRow('روزه', fastingDone, fastingTotal),
        ReportProgressRow('طاعات', worshipDone, worshipTotal),
        ReportProgressRow('اذکار صبح', morningDone, morningTotal),
        ReportProgressRow('اذکار شام', eveningDone, eveningTotal),
        ReportProgressRow('اذکار خواب', nightDone, nightTotal),
        ReportProgressRow('تسبیح', tasbihDone, tasbihTotal),
      ],
    );
    final text = 'گزارش عملکرد ماهانه $monthLabel\n'
        'امتیاز: $score/$maxScore | ارزیابی: $rating | روزهای فعال: $activeDays/$totalDays';
    try {
      await shareWidgetAsImage(
        context,
        child: card,
        fileName: 'evaluation_report.png',
        text: text,
      );
    } catch (e) {
      AppLogger.warning('evaluation_stats_widget', 'error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ساخت تصویر گزارش ممکن نشد؛ دوباره تلاش کنید.')),
        );
      }
    }
  }

  void _retryAzkar() {
    setState(() {
      // Clearing the memo forces the next build to re-run the query instead of
      // replaying the failed future.
      _azkarFuture = null;
      _azkarFutureKey = '';
    });
  }

  Widget _buildAzkarRetry() {
    // One row, not a bare text button: the failure is a *section* of this
    // screen, and the panel says so in place of the numbers it could not
    // compute.
    return FailureView(
      id: 'evaluation_azkar_stats',
      title: 'آمار اذکار خوانده نشد',
      detail: 'اذکار ثبت‌شده پاک نشده‌اند؛ فقط شمارش این بازه انجام نشد.',
      onRetry: _retryAzkar,
      layout: FailureLayout.inline,
    );
  }

  /// Caches the azkar-range query future per (tab/month/azkar-version) so
  /// rebuilds don't fire a fresh DB query every frame.
  Future<Map<PrayerPeriod, int>> _memoizedAzkarFuture({
    required String key,
    required String startKey,
    required String endKey,
  }) {
    if (_azkarFuture == null || key != _azkarFutureKey) {
      _azkarFutureKey = key;
      _azkarFuture = _loadAzkarStats(AzkarData.allAzkar, startKey, endKey);
    }
    return _azkarFuture!;
  }

  Future<Map<PrayerPeriod, int>> _loadAzkarStats(
    List<ZikrItem> allItems,
    String startKey,
    String endKey,
  ) async {
    final dao = ref.read(azkarStatusDaoProvider);
    final records = await dao.getStatusesForDateRange(startKey, endKey);
    final done = records.where((r) => r.statusIndex == 1).toList();

    final periodMap = <String, PrayerPeriod>{};
    for (final item in allItems) {
      periodMap[item.id] = item.period;
    }

    final counts = <PrayerPeriod, int>{};
    for (final r in done) {
      final period = periodMap[r.id];
      if (period == PrayerPeriod.morningAzkar) {
        counts[PrayerPeriod.morningAzkar] =
            (counts[PrayerPeriod.morningAzkar] ?? 0) + 1;
      } else if (period == PrayerPeriod.eveningAzkar) {
        counts[PrayerPeriod.eveningAzkar] =
            (counts[PrayerPeriod.eveningAzkar] ?? 0) + 1;
      } else if (period == PrayerPeriod.night) {
        counts[PrayerPeriod.night] = (counts[PrayerPeriod.night] ?? 0) + 1;
      }
    }
    return counts;
  }

  int _totalForPeriod(List<ZikrItem> allItems, PrayerPeriod period) {
    return allItems.where((z) => z.period == period).length;
  }

  /// Blends the colors of today's completed worship items into a single
  /// accent for the «طاعات» ring, so the report mirrors the checklist's
  /// palette. Null when nothing is done (keeps the item's own hue).
  Color? _worshipBlend(List<WorshipItem> items) {
    final colors = items
        .where((w) => w.done)
        .map((w) => WorshipColors.forItem(w.id, w.icon))
        .toList();
    return colors.isEmpty ? null : WorshipColors.blend(colors);
  }

  Widget _buildMonthSelector(String label) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      radius: 16,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_right, color: t.tertiary),
            tooltip: 'ماه بعد',
            onPressed: () => setState(() => _monthOffset++),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showMonthYearPicker(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month, size: 17, color: t.tertiary),
                    const SizedBox(width: 8),
                    // The label is the only child that grows with the text
                    // scale; capping it at the Row level (the SectionHeader
                    // recipe) keeps the month readable instead of pushing the
                    // arrow glyph past the card at 320dp × scale 1.8.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 14.5),
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 20, color: t.tertiary),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_left, color: t.tertiary),
            tooltip: 'ماه قبل',
            onPressed: () => setState(() {
              if (_monthOffset > -12) _monthOffset--;
            }),
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker(BuildContext context) {
    final now = DateTime.now();
    final nowJ = ref.read(evaluationProvider.notifier).toJalali(now);
    // Step Jalali months directly — the offset is a Jalali month delta.
    final jalali = Jalali(nowJ.year, nowJ.month).add(months: _monthOffset);
    final monthNames = DateConstants.persianMonths;

    int tempYear = jalali.year;
    int tempMonth = jalali.month;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final t = TimeThemeKit.of(context).palette;
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: AppCard(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: t.tertiary),
                          tooltip: 'سال قبل',
                          onPressed: () => setSheetState(() => tempYear--),
                        ),
                        Text(
                          '$tempYear',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 18),
                            fontWeight: FontWeight.w700,
                            color: dsContentColor(context, AppPalette.goldDark),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: t.tertiary),
                          tooltip: 'سال بعد',
                          onPressed: () => setSheetState(() => tempYear++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (i) {
                        final selected = (i + 1) == tempMonth;
                        return GestureDetector(
                          onTap: () {
                            tempMonth = i + 1;
                            final monthOffset =
                                _jalaliToOffset(tempYear, tempMonth);
                            Navigator.pop(ctx);
                            setState(() => _monthOffset = monthOffset);
                          },
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 72) / 3,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? t.tertiary : t.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: selected
                                  ? Border.all(color: t.tertiarySoft, width: 2)
                                  : null,
                            ),
                            child: Text(
                              monthNames[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected ? t.heroBottom : t.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _jalaliToOffset(int jalaliYear, int jalaliMonth) {
    final now = DateTime.now();
    final currentJalali = ref.read(evaluationProvider.notifier).toJalali(now);
    return (jalaliYear - currentJalali.year) * 12 +
        (jalaliMonth - currentJalali.month);
  }

  Widget _buildRingGrid(List<_RingData> rings) {
    final rows = <TableRow>[];
    for (var i = 0; i < rings.length; i += 4) {
      final chunk = rings.sublist(i, math.min(i + 4, rings.length));
      rows.add(TableRow(
        children: [
          for (final r in chunk) _RingCell(data: r),
          for (var k = chunk.length; k < 4; k++) const SizedBox(height: 86),
        ],
      ));
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Table(children: rows),
    );
  }
}

/// The report's hero card: the phase-gradient shell, the score inside the kit
/// ring (`RingView`, the same component the detail grid below uses) and the
/// encouraging tier chip under the dial, centred on the card.
class _ScoreHero extends StatelessWidget {
  const _ScoreHero({
    required this.score,
    required this.maxScore,
    required this.label,
    this.rating,
    this.caption,
  });

  final int score;
  final int maxScore;
  final String label;

  /// The verdict shown in the chip. Callers that score a *span* (a month that
  /// is still in progress) pass the elapsed-days rating so the chip and the
  /// share report read the same word for the same month.
  final String? rating;

  /// What the denominator is, in words.
  ///
  /// A ring that says «۱۲ / ۴۵» has answered «how much» and not «out of
  /// what»: the 45 is the sum of the checklist, the five prayers, the two
  /// adhkar periods and the tasbih target, and it moves whenever the user
  /// hides an item or edits its points. The caption is one line of that
  /// account, so a number that changes has a visible reason.
  final String? caption;

  /// The dial is the card's hero, so its size is a property of the card, not of
  /// the screen: one fixed circle with the score inside it.
  static const double _ringSize = 132;
  static const double _stroke = 8;

  @override
  Widget build(BuildContext context) {
    final fraction = maxScore > 0 ? score / maxScore : 0.0;
    final tier = rating ?? EvaluationStatsCompute.ratingForFraction(fraction);
    final scoreText = NumberFormat.formatPlain(score.toDouble());
    final maxText = NumberFormat.formatPlain(maxScore.toDouble());
    return HeroCardShell(
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w600,
                color: AppPalette.cream.withValues(alpha: .85),
              ),
            ),
          ),
          const SizedBox(height: 8),
          RingView(
            progress: fraction,
            size: _ringSize,
            strokeWidth: _stroke,
            color: AppPalette.heroGold,
            // The hero-surface track the home hero ring uses too: white at 20 %,
            // so the unfilled part reads as the same object, not as a border.
            trackColor: Colors.white.withValues(alpha: .20),
            semanticLabel: '$label، $scoreText از $maxText',
            // The number rides inside the stroke, and scaleDown keeps it there
            // at 1.3 text scale and on a four-digit monthly score. Two lines:
            // the score above, the day's target under it — the same reading
            // the detail grid's rings use.
            child: SizedBox(
              width: _ringSize - _stroke * 2 - 14,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        scoreText,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 36),
                          fontWeight: FontWeight.w800,
                          color: AppPalette.heroGold,
                          height: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        '/ $maxText',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                          color: AppPalette.heroGold.withValues(alpha: .55),
                          height: 1.4,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // The verdict reads under the dial, centred on the card — the user
          // asked for it in the middle, not against a corner. Align loosens
          // the width to the column, and that is the bound `_TierChip`'s
          // FittedBox needs at 1.3 text scale. (`Alignment.center` is Align's
          // own default; being explicit here trips avoid_redundant_argument_values.)
          Align(
            child: _TierChip(tier: tier),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                caption!,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10.5),
                  fontWeight: FontWeight.w500,
                  color: AppPalette.cream.withValues(alpha: .62),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small solid pill for the hero card. Spec §REPORT: soft coral for «needs
/// effort», gold for «good», emerald for «excellent» — the wording stays the
/// scorer's, only the color speaks.
class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final fill = ReportTierColors.chipFill(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(11),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          tier,
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11.5),
            fontWeight: FontWeight.w700,
            color: ReportTierColors.chipInk(tier, t),
          ),
        ),
      ),
    );
  }
}

class _CompactItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _CompactItem(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
}

class _CompactSummaryRow extends StatelessWidget {
  final List<_CompactItem> items;
  const _CompactSummaryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final item in items)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 18, color: item.color),
                const SizedBox(height: 5),
                Text(item.value,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14.5),
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary)),
                Text(item.label,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        color: t.textMuted)),
              ],
            ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int current;
  final int best;
  const _StreakCard({required this.current, required this.best});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _streakStat(context, Icons.local_fire_department,
                'زنجیره فعلی', '$current روز', t.tertiary),
          ),
          Container(width: 1, height: 32, color: t.outline),
          Expanded(
            child: _streakStat(context, Icons.emoji_events, 'بهترین زنجیره',
                '$best روز', SectionHues.evaluation),
          ),
        ],
      ),
    );
  }

  Widget _streakStat(BuildContext context, IconData icon, String label,
      String value, Color color) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 8),
        // Flexible at the Row level so the pair is bounded, and scaleDown so a
        // long label shrinks instead of losing its word — at 320dp under 1.3
        // text scale «بهترین زنجیره» overflowed this row by 35px.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The per-tab reset entry: a quiet, centered text button at the bottom of the
/// tab it belongs to. Deliberately not an AppCard or a filled button — the
/// destructive weight lives in the confirmation dialog, not in tempting the
/// reader's thumb at the end of a scroll.
class _ResetAction extends StatelessWidget {
  const _ResetAction({required this.tooltip, required this.label, this.onPressed});

  final String tooltip;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.page),
      child: Center(
        child: Tooltip(
          message: tooltip,
          child: TextButton.icon(
            onPressed: onPressed,
            icon: Icon(Icons.restart_alt, size: 18, color: danger),
            label: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w600,
                color: danger,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingData {
  const _RingData({
    required this.label,
    required this.done,
    required this.total,
    required this.hue,
    this.accent,
    this.exempt = false,
  });

  final String label;

  /// Null when the reading is not known yet (the query is still running or
  /// failed) — rendered as «—» instead of a fabricated zero.
  final int? done;
  final int total;

  /// Identity hue of the measured domain (fardh, fasting, tasbih, …).
  final Color hue;

  /// Optional accent override (e.g. the blended worship colors for «طاعات»).
  final Color? accent;

  /// Hayz/نفاس exemption: the item is not obligatory today, so the ring
  /// shows «معاف» instead of pretending the user completed it.
  final bool exempt;
}

class _RingCell extends StatelessWidget {
  const _RingCell({required this.data});

  final _RingData data;

  double _numberSize(BuildContext context, int value) {
    final digits = value.toString().length;
    if (digits <= 2) return AppTheme.scaledFontSize(context, 16);
    if (digits <= 3) return AppTheme.scaledFontSize(context, 13.5);
    if (digits <= 4) return AppTheme.scaledFontSize(context, 11.5);
    if (digits <= 5) return AppTheme.scaledFontSize(context, 10);
    return AppTheme.scaledFontSize(context, 8.5);
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final done = data.done;
    final hasTotal = data.total > 0;
    final single = hasTotal && data.total == 1;
    final complete =
        !data.exempt && hasTotal && done != null && done >= data.total;
    final fraction =
        hasTotal && done != null ? (done / data.total).clamp(0.0, 1.0) : 0.0;
    final hue = data.accent ?? data.hue;
    // A ring with nothing to fill yet (no goal at all, an unknown reading, or
    // a single binary goal not yet met) gets a dashed track — «optional», not
    // «failed zero».
    final dashed =
        !data.exempt && (done == null || !hasTotal || (single && !complete));
    final labelColor = complete
        ? dsContentColor(context, AppPalette.emerald)
        : data.exempt
            ? dsContentColor(context, t.tertiary)
            : t.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RingView(
            progress: data.exempt ? 1 : fraction,
            size: 56,
            strokeWidth: 6,
            color: data.exempt ? t.tertiary : hue,
            trackColor: hue.withValues(alpha: .14),
            dashedTrack: dashed,
            semanticLabel: data.exempt
                ? '${data.label}: معاف'
                : done == null
                    ? '${data.label}: در دسترس نیست'
                    : '${data.label}: ${NumberFormat.formatPlain(done.toDouble())} از ${NumberFormat.formatPlain(data.total.toDouble())}',
            child: _center(context, hasTotal, single, complete, hue, t),
          ),
          const SizedBox(height: 5),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _center(BuildContext context, bool hasTotal, bool single,
      bool complete, Color hue, AppPalette t) {
    if (data.exempt) {
      return Text(
        'معاف',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          fontWeight: FontWeight.w800,
          color: dsContentColor(context, t.tertiary),
          height: 1,
        ),
      );
    }
    final done = data.done;
    if (done == null) {
      return Text(
        '—',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 14),
          fontWeight: FontWeight.w800,
          color: t.textMuted,
          height: 1,
        ),
      );
    }
    if (single) {
      return Icon(
        complete ? Icons.check_rounded : Icons.radio_button_unchecked,
        size: 22,
        color: complete
            ? dsContentColor(context, AppPalette.emerald)
            : hue.withValues(alpha: .4),
      );
    }
    if (!hasTotal) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            NumberFormat.formatPlain(done.toDouble()),
            maxLines: 1,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: _numberSize(context, done),
              fontWeight: FontWeight.w800,
              color: dsContentColor(context, hue),
              height: 1,
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          NumberFormat.formatPlain(done.toDouble()),
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: _numberSize(context, done),
            fontWeight: FontWeight.w800,
            color: dsContentColor(context, hue),
            height: 1,
          ),
        ),
        Text(
          '/${NumberFormat.formatPlain(data.total.toDouble())}',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 8.5),
            fontWeight: FontWeight.w600,
            color: t.textMuted,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// The week's score series as bars (index 0 of [scores] is today; the chart
/// reads chronologically).
class _WeeklyScoreChart extends StatelessWidget {
  const _WeeklyScoreChart({required this.scores});

  final List<int> scores;

  static const _weekdayLetters = ['د', 'س', 'چ', 'پ', 'ج', 'ش', 'ی'];

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final chrono = scores.reversed.toList();
    if (chrono.isEmpty) return const SizedBox.shrink();
    final maxScore = chrono.fold(0, math.max);
    final maxY = maxScore <= 0 ? 1.0 : maxScore * 1.2;
    final today = DateTime.now();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: t.tertiary),
              const SizedBox(width: 6),
              Text(
                'نمودار امتیاز هفته',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.9,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= chrono.length) {
                          return const SizedBox.shrink();
                        }
                        final day = today
                            .subtract(Duration(days: chrono.length - 1 - i));
                        final isToday = i == chrono.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _weekdayLetters[day.weekday - 1],
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 9.5),
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w500,
                              color: isToday ? t.tertiary : t.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => t.heroBottom,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      NumberFormat.formatPlain(rod.toY),
                      TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: AppPalette.cream,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (final (i, v) in chrono.indexed)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: v.toDouble(),
                          width: 14,
                          borderRadius: BorderRadius.circular(5),
                          color:
                              i == chrono.length - 1 ? t.heroTop : t.tertiary,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The selected Jalali month's daily score series as a line (day 1..N).
class _MonthlyScoreChart extends StatelessWidget {
  const _MonthlyScoreChart({required this.scores});

  final List<int> scores;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    if (scores.isEmpty) return const SizedBox.shrink();
    final maxScore = scores.fold(0, math.max);
    final maxY = maxScore <= 0 ? 1.0 : maxScore * 1.15;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 16, color: t.tertiary),
              const SizedBox(width: 6),
              Text(
                'نمودار امتیاز ماه',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.9,
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                minX: 0,
                maxX: (scores.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final day = v.toInt() + 1;
                        if (day < 1 || day > scores.length) {
                          return const SizedBox.shrink();
                        }
                        if (day != 1 && day % 5 != 0 && day != scores.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            NumberFormat.formatPlain(day.toDouble()),
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 9),
                              color: t.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => t.heroBottom,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          NumberFormat.formatPlain(s.y),
                          TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w700,
                            color: AppPalette.cream,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (final (i, v) in scores.indexed)
                        FlSpot(i.toDouble(), v.toDouble())
                    ],
                    isCurved: true,
                    curveSmoothness: .25,
                    preventCurveOverShooting: true,
                    barWidth: 2.4,
                    color: t.tertiary,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: t.tertiary.withValues(alpha: .12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily breakdown of every tasbih zikr (today's count vs its own target),
/// shown in the daily view of the ارزیابی tab so the tasbih statistics stay
/// in one place alongside the azkar rings.
class _TasbihDetailCard extends StatelessWidget {
  final List<TasbihModel> models;

  /// Today's per-zikr tap counts (date-keyed rows), so «جزئیات تسبیح امروز»
  /// shows the current day's numbers even before the session counter resets.
  final Map<String, int> todayCounts;
  const _TasbihDetailCard({required this.models, this.todayCounts = const {}});

  int _todayCount(TasbihModel m) => todayCounts[m.id] ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final complete =
        models.where((m) => _todayCount(m) >= m.targetCount).length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat, size: 17, color: t.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'جزئیات تسبیح امروز',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Text(
                '${NumberFormat.ltrIsolated('$complete')} از '
                '${NumberFormat.ltrIsolated('${models.length}')} کامل',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: dsContentColor(context, AppPalette.goldDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final m in models)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ZikrRow(model: m, count: _todayCount(m)),
            ),
        ],
      ),
    );
  }
}

class _ZikrRow extends StatelessWidget {
  final TasbihModel model;
  final int count;
  const _ZikrRow({required this.model, this.count = 0});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final fraction = model.targetCount > 0
        ? (count / model.targetCount).clamp(0.0, 1.0)
        : 0.0;
    final done = count >= model.targetCount;
    final barColor = done ? AppPalette.emerald : t.tertiary;
    final inkColor = done
        ? dsContentColor(context, AppPalette.emerald)
        : dsContentColor(context, AppPalette.goldDark);
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            model.targetDhikr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11.5),
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: t.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 84,
          child: Text(
            '${NumberFormat.ltrIsolated(NumberFormat.formatPlain(count.toDouble()))} از '
            '${NumberFormat.ltrIsolated(NumberFormat.formatPlain(model.targetCount.toDouble()))}',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              fontWeight: FontWeight.w700,
              color: inkColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverallTasbihCard extends StatelessWidget {
  final int total;
  const _OverallTasbihCard({required this.total});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: Row(
        children: [
          IconTile(icon: Icons.repeat, color: t.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آمار کلی تسبیح',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'مجموع كل ذكرهای گفته شده',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 10.5),
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.formatPlain(total.toDouble()),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 20),
              fontWeight: FontWeight.w800,
              color: dsContentColor(context, AppPalette.goldDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyHeatmap extends StatelessWidget {
  final int jalaliYear;
  final int jalaliMonth;
  final Evaluation notifier;
  const _MonthlyHeatmap(
      {required this.jalaliYear,
      required this.jalaliMonth,
      required this.notifier});

  static const _cols = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    // A Jalali month laid out on the Gregorian weekdays those days actually
    // fall on. Printing Jalali numbers over Gregorian buckets used to make the
    // labels run past the month length and restart mid-grid.
    final monthDays = [
      for (var day = 1;
          day <= Jalali(jalaliYear, jalaliMonth).monthLength;
          day++)
        Jalali(jalaliYear, jalaliMonth, day).toDateTime()
    ];
    final daysInMonth = monthDays.length;
    final maxScore = notifier.dailyMaxScore;
    final nowJ = Jalali.fromDateTime(DateTime.now());
    final isCurrent = jalaliYear == nowJ.year && jalaliMonth == nowJ.month;

    final cells = <Widget>[];
    final firstDow = monthDays.first.weekday;
    final lead = (firstDow + 1) % 7;
    for (int k = 0; k < lead; k++) {
      cells.add(const Spacer());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final score = notifier.getScoreForDate(monthDays[day - 1]) ?? 0;
      final fraction = maxScore > 0 ? (score / maxScore) : 0.0;
      cells.add(_dayCell(
          day, fraction, score > 0, isCurrent && day == nowJ.day, context));
    }
    while (cells.length % 7 != 0) {
      cells.add(const Spacer());
    }

    final rows = <Widget>[];
    for (int r = 0; r < cells.length; r += 7) {
      rows.add(Row(children: cells.sublist(r, r + 7)));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_month, size: 16, color: t.tertiary),
              const SizedBox(width: 6),
              Text('مرور فعالیت ماه',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary)),
              const Spacer(),
              _legendDot(context, t.tertiary.withValues(alpha: .25)),
              _legendDot(context, t.tertiary.withValues(alpha: .55)),
              _legendDot(context, t.tertiary),
              const SizedBox(width: 4),
              Text('کم ← زیاد',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 9.5),
                      color: t.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _cols
                .map((c) => Expanded(
                      child: Text(c,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w600,
                              color: t.textSecondary)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _dayCell(int day, double fraction, bool active, bool isToday,
      BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final cellBg = active
        ? Color.lerp(
                t.card, t.tertiary, 0.25 + 0.75 * fraction.clamp(0.0, 1.0)) ??
            t.card
        : t.surfaceMuted;
    final lightText = active && fraction > 0.55;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: cellBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isToday
                    ? t.tertiary
                    : active
                        ? t.tertiary.withValues(alpha: .6)
                        : t.outline,
                width: isToday ? 1.6 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text('$day',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 9.5),
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: lightText ? AppPalette.cream : t.textPrimary)),
          ),
        ),
      ),
    );
  }
}
