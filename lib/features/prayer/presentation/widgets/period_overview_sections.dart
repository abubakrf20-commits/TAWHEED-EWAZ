part of 'period_widgets.dart';

/// حالت بارداری: با فعال‌شدن، پیش‌بینی چرخه متوقف و یک کارت وضعیت ویژه نشان
/// داده می‌شود.
class PeriodPregnancySection extends ConsumerStatefulWidget {
  final Period notifier;
  const PeriodPregnancySection({super.key, required this.notifier});

  @override
  ConsumerState<PeriodPregnancySection> createState() =>
      _PeriodPregnancySectionState();
}

class _PeriodPregnancySectionState
    extends ConsumerState<PeriodPregnancySection> {
  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final state = ref.watch(periodProvider).value ?? const PeriodState();
    final isPregnant = state.isPregnant;
    final due = state.pregnancyDueDate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.pregnant_woman,
                size: 20, color: isPregnant ? periodAccent : t.textMuted),
            const SizedBox(width: 8),
            Expanded(
                child: Text('حالت بارداری',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary))),
            Switch(
              value: isPregnant,
              activeTrackColor: periodAccent,
              onChanged: (v) => widget.notifier.setPregnant(v),
            ),
          ]),
          if (isPregnant) ...[
            const SizedBox(height: 4),
            Text(
              'در حالت بارداری، پیش‌بینی چرخه متوقف می‌شود و وضعیت امروز به‌صورت «بارداری» نمایش داده می‌شود.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: t.textMuted,
                  height: 1.5),
            ),
            if (due != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تاریخ تخمینی زایمان',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: t.textMuted)),
                  Text(
                      '${Jalali.fromDateTime(due).year}/${Jalali.fromDateTime(due).month}/${Jalali.fromDateTime(due).day}',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => widget.notifier.setPregnancyDueDate(null),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('حذف تاریخ زایمان'),
              ),
            ],
            if (due == null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(Icons.event_outlined, size: 16),
                label: const Text('انتخاب تاریخ تخمینی زایمان'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final today = DateTime.now();
    final picked = await ShamsiDatePicker.show(context, initialDate: today);
    if (picked == null || !mounted) return;
    await widget.notifier.setPregnancyDueDate(picked);
  }
}

/// صدور گزارش PDF از تاریخچهٔ پریودی.
class PeriodReportSection extends ConsumerWidget {
  final Period notifier;
  const PeriodReportSection({super.key, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf_outlined, size: 20, color: periodAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text('گزارش PDF',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: periodAccent),
            onPressed: () async {
              try {
                await buildAndSharePeriodReport(notifier,
                    hijriOffset: ref.watch(hijriOffsetProvider));
              } catch (e) {
                AppLogger.warning('period_widgets', 'error: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('ساخت گزارش ممکن نشد؛ دوباره تلاش کنید.'),
                      duration: Duration(seconds: 3)));
                }
              }
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('صدور و اشتراک'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  STATS SECTION
// ══════════════════════════════════════════════════════════════════════════

class PeriodStatsSection extends StatelessWidget {
  final Period notifier;
  const PeriodStatsSection({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final stats = notifier.cycleStats();
    if (stats == null) {
      return AppEmptyState(
        icon: Icons.insights_outlined,
        message: 'آمار چرخه هنوز شکل نگرفته',
        subtitle: 'پس از ثبت چند دوره، طول و نظم چرخه اینجا محاسبه می‌شود.',
        accent: periodAccent,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final gold = periodAccent;
    final regularityLabel = periodRegularityLabel(stats.regularity);
    final gaps = notifier.recentCycleGaps();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.outline),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.insights, size: 20, color: gold),
            const SizedBox(width: 8),
            Expanded(
                child: Text('آمار سیکل',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary))),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCell(context, 'سیکل میانگین',
                  '${_num(stats.averageCycle.round())} روز'),
              _statCell(context, 'پریود میانگین',
                  '${_num(stats.averagePeriod.round())} روز'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statCell(
                  context,
                  'کوتاه‌ترین',
                  stats.shortestCycle != null
                      ? '${_num(stats.shortestCycle!)} روز'
                      : '—'),
              _statCell(
                  context,
                  'بلندترین',
                  stats.longestCycle != null
                      ? '${_num(stats.longestCycle!)} روز'
                      : '—'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.autorenew,
                  size: 16,
                  color: stats.regularity == null
                      ? t.textMuted
                      : stats.regularity! >= 0.6
                          ? (isDark
                              ? AppTheme.darkSuccess
                              : AppTheme.lightSuccess)
                          : (isDark
                              ? AppTheme.darkError
                              : AppTheme.lightError)),
              const SizedBox(width: 6),
              Text('انتظام سیکل: $regularityLabel',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary)),
            ],
          ),
          if (gaps.length >= 2) ...[
            const SizedBox(height: 14),
            Text('روند فاصلهٔ چرخه‌های اخیر',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: t.textMuted)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  minY: (gaps.reduce((a, b) => a < b ? a : b) - 3).toDouble(),
                  maxY: (gaps.reduce((a, b) => a > b ? a : b) + 3).toDouble(),
                  gridData: const FlGridData(drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i >= 0 && i < gaps.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_num(gaps.length - i),
                                  style: TextStyle(
                                      fontSize:
                                          AppTheme.scaledFontSize(context, 9))),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      // Chronological: oldest → newest left→right.
                      spots: [
                        for (var i = 0; i < gaps.length; i++)
                          FlSpot(i.toDouble(),
                              gaps[gaps.length - 1 - i].toDouble()),
                      ],
                      color: gold,
                      barWidth: 2.5,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'هر نقطه فاصلهٔ روزه بین دو دورهٔ متوالی است (جدیدترین سمت راست).',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: t.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCell(BuildContext context, String label, String value) {
    final t = TimeThemeKit.of(context).palette;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    color: t.textMuted)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: periodAccentStrong)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  CALENDAR SECTION
// ══════════════════════════════════════════════════════════════════════════

class PeriodCalendarSection extends StatelessWidget {
  final Period notifier;
  final int selectedMonth, selectedYear;
  final Function(int month, int year) onMonthChanged;

  const PeriodCalendarSection(
      {super.key,
      required this.notifier,
      required this.selectedMonth,
      required this.selectedYear,
      required this.onMonthChanged});

  static const _weekDays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final gold = periodAccent;
    final monthData = notifier.getMonthData(selectedYear, selectedMonth);
    final daysInMonth = Jalali(selectedYear, selectedMonth).monthLength;
    final startOffset = Jalali(selectedYear, selectedMonth).weekDay;
    final jToday = Jalali.fromDateTime(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.outline),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Month header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: gold),
                tooltip: 'ماه قبل',
                onPressed: () {
                  if (selectedMonth == 1) {
                    onMonthChanged(12, selectedYear - 1);
                  } else {
                    onMonthChanged(selectedMonth - 1, selectedYear);
                  }
                },
              ),
              Text(
                '${DateConstants.persianMonths[selectedMonth - 1]} $selectedYear',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: gold),
                tooltip: 'ماه بعد',
                onPressed: () {
                  if (selectedMonth == 12) {
                    onMonthChanged(1, selectedYear + 1);
                  } else {
                    onMonthChanged(selectedMonth + 1, selectedYear);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Weekday headers
          Row(
            children: _weekDays
                .map((d) => Expanded(
                      child: Center(
                          child: Text(d,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 12),
                                  fontWeight: FontWeight.w600,
                                  color: t.textMuted))),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          ...List.generate((daysInMonth + startOffset + 6) ~/ 7, (row) {
            return Row(
              children: List.generate(7, (col) {
                final idx = row * 7 + col - (startOffset - 1);
                if (idx < 1 || idx > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 36));
                }

                final status = monthData[idx];
                final isToday = idx == jToday.day &&
                    selectedMonth == jToday.month &&
                    selectedYear == jToday.year;

                Color? bgColor;
                Color? textColor;
                Color? borderColor;

                final isPeriod = status == PeriodStatus.period;
                final isNifas = status == PeriodStatus.nifas;
                final isIstihadha = status == PeriodStatus.istihadha;
                final isPredicted = status == PeriodStatus.predictedPeriod;
                // Fertile days reuse the predictedClean slot from
                // getMonthData; drawn as a hollow teal ring (visually
                // distinct from the red period family).
                final isFertile = status == PeriodStatus.predictedClean;
                final fertileColor = t.secondary;
                const nifasColor = Color(0xFF6A1B9A);
                const istihadhaColor = AppTheme.warning;
                if (isPeriod) {
                  bgColor = periodAccentDeep.withValues(alpha: 0.18);
                  textColor = isDark ? periodAccentLight : periodAccentDeep;
                  borderColor = periodAccentDeep.withValues(alpha: 0.45);
                } else if (isNifas) {
                  bgColor = nifasColor.withValues(alpha: 0.16);
                  textColor = nifasColor;
                  borderColor = nifasColor.withValues(alpha: 0.45);
                } else if (isIstihadha) {
                  bgColor = istihadhaColor.withValues(alpha: 0.14);
                  textColor = istihadhaColor;
                  borderColor = istihadhaColor.withValues(alpha: 0.45);
                } else if (isPredicted) {
                  bgColor =
                      periodAccentDeep.withValues(alpha: isDark ? 0.20 : 0.12);
                  textColor = periodAccentLight;
                  borderColor = periodAccentLight.withValues(alpha: 0.45);
                } else if (isFertile) {
                  textColor = fertileColor;
                  borderColor = fertileColor.withValues(alpha: 0.55);
                } else if (isToday) {
                  bgColor = gold.withValues(alpha: 0.15);
                  textColor = gold;
                }

                final showMarkerBorder = isPeriod ||
                    isNifas ||
                    isIstihadha ||
                    isPredicted ||
                    isFertile;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final gregDate =
                          Jalali(selectedYear, selectedMonth, idx).toDateTime();
                      _showDayActions(context, gregDate);
                    },
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: gold.withValues(alpha: 0.4))
                            : (showMarkerBorder
                                ? Border.all(color: borderColor!)
                                : null),
                      ),
                      child: Center(
                        child: Text(
                          '$idx',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w500,
                              color: textColor ?? t.textPrimary),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),

          // Legend
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              _legendDot(context, periodAccentDeep, 'حیض'),
              _legendDot(context, const Color(0xFF6A1B9A), 'نفاس'),
              _legendDot(context, AppTheme.warning, 'استحاضه'),
              _legendDot(context, periodAccent, 'پیش‌بینی'),
              _legendDot(context, t.secondary, 'باروری'),
              _legendDot(context, gold, 'امروز'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: color)),
      ],
    );
  }

  /// Short status label for a calendar day, shown in the day sheet so a
  /// colored tile explains itself (recorded period / next period / fertile).
  void _showDayActions(BuildContext context, DateTime date) =>
      showPeriodDayActions(context, notifier, date);
}
