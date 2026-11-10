part of 'period_widgets.dart';

class PeriodStatusCard extends StatelessWidget {
  final Period notifier;
  const PeriodStatusCard({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final prediction = notifier.predict();
    final todayStatus = notifier.getTodayStatus();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (prediction == null && todayStatus['status'] == 'unknown') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: t.outline),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 40, color: t.textMuted),
            const SizedBox(height: 12),
            Text(
              'هنوز اطلاعاتی ثبت نشده',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 15),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'تاریخ شروع دوره را ثبت کنید تا وضعیت شما نمایش داده شود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: t.textMuted),
            ),
          ],
        ),
      );
    }

    final status = todayStatus['status'] as String? ?? 'unknown';
    final isBleeding = status == 'haid' ||
        status == 'nifas' ||
        status == 'istihadha' ||
        status == 'ghusl';
    final statusColor = isBleeding
        ? periodAccentDeep
        : (isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess);
    final statusText = switch (status) {
      'haid' => 'حیض',
      'nifas' => 'نفاس',
      'istihadha' => 'استحاضه',
      'ghusl' => 'روز غسل',
      'predicted' => 'احتمال حیض',
      'irregular' => 'چرخهٔ نامنظم',
      'pregnant' => 'بارداری',
      'tahir' => 'طهر (پاک)',
      _ => 'نامشخص',
    };

    final today = DateTime.now();
    final activeRecord = notifier.findRecordForDate(today);
    final inActiveRecord = activeRecord != null && activeRecord.isActive;
    int? dayInActive;
    if (activeRecord != null && activeRecord.isActive) {
      dayInActive = DateTime(today.year, today.month, today.day)
              .difference(DateTime(activeRecord.startDate.year,
                  activeRecord.startDate.month, activeRecord.startDate.day))
              .inDays +
          1;
    }
    final showStartQuick = !inActiveRecord && status == 'predicted';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? [
                  periodAccentDeep,
                  Color.lerp(TopicHues.period, Colors.black, 0.62) ??
                      TopicHues.period
                ]
              : [
                  periodAccent,
                  periodAccentLight,
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: statusOnGradient, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(statusText,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: statusOnGradient)),
                  ],
                ),
              ),
              const Spacer(),
              if (prediction != null)
                Text(
                  'روز ${prediction.currentDayInCycle} از ${prediction.totalCycleDays}',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: statusOnGradientMuted),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Main message
          Text(
            todayStatus['message'],
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 14),
                color: statusOnGradient,
                height: 1.5),
          ),
          const SizedBox(height: 16),

          // Quick info rows
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusOnGradient.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // شرعی: نماز در حیض/نفاس ساقط و قضا ندارد؛ روزه ساقط ولی قضا دارد
                _infoRow(
                    context,
                    'نماز',
                    todayStatus['canPray']
                        ? 'واجب است'
                        : 'ساقط است (قضا ندارد)'),
                Divider(
                    height: 16, color: statusOnGradient.withValues(alpha: 0.2)),
                _infoRow(
                    context,
                    'روزه',
                    todayStatus['canFast']
                        ? 'واجب است'
                        : 'ساقط است (قضا: فقط روزهٔ رمضان)'),
                if (todayStatus['needsGhusl'] == true) ...[
                  Divider(
                      height: 16,
                      color: statusOnGradient.withValues(alpha: 0.2)),
                  _infoRow(context, 'غسل', 'بر شما واجب است'),
                ],
                if (dayInActive != null) ...[
                  Divider(
                      height: 16,
                      color: statusOnGradient.withValues(alpha: 0.2)),
                  _infoRow(context, 'دورهٔ جاری', 'روز ${_num(dayInActive)}'),
                ],
                if (prediction != null) ...[
                  Divider(
                      height: 16,
                      color: statusOnGradient.withValues(alpha: 0.2)),
                  _infoRow(context, 'تا شروع دورهٔ بعدی',
                      '${_num(prediction.daysUntilNextPeriod)} روز'),
                ],
              ],
            ),
          ),

          // Quick actions: one-tap start/end for today.
          if (inActiveRecord || showStartQuick) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: statusOnGradient.withValues(alpha: 0.18),
                  foregroundColor: statusOnGradient,
                ),
                onPressed: () async {
                  if (inActiveRecord) {
                    await notifier.endPeriod(today);
                  } else {
                    final ok = await notifier.startPeriod(today);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'این روز قبلاً ثبت شده است؛ ثبت جدید انجام نشد.'),
                        duration: Duration(seconds: 3),
                      ));
                    }
                  }
                },
                icon: Icon(inActiveRecord ? Icons.stop : Icons.play_arrow,
                    size: 18),
                label:
                    Text(inActiveRecord ? 'ثبت پایان امروز' : 'ثبت شروع امروز'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: statusOnGradientMuted)),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 13),
            fontWeight: FontWeight.w600,
            color: statusOnGradient,
          ),
        ),
      ],
    );
  }
}

/// نمودار شدت خونریزی در 30 روز اخیر: میله‌ها شدت جریان (کم/متوسط/زیاد) را
/// نشان می‌دهند؛ رنگ میله نوع دوره (حیض/نفاس/استحاضه) را مشخص می‌کند.
class PeriodChartSection extends StatelessWidget {
  final Period notifier;
  const PeriodChartSection({super.key, required this.notifier});

  static const int _days = 30;
  static const Color _hayzColor = TopicHues.period;
  static const Color _nifasColor = Color(0xFF6A1B9A);
  static const Color _istihadhaColor = AppTheme.warning;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final state = notifier.currentSnapshot;
    if (state == null || state.records.isEmpty) {
      return AppEmptyState(
        icon: Icons.show_chart,
        message: 'نموداری برای نمایش نیست',
        subtitle: 'با ثبت اولین دوره، نمودار 30 روز اخیر اینجا ترسیم می‌شود.',
        accent: periodAccent,
      );
    }

    final today = _dateOnlyLocal(DateTime.now());
    final start = today.subtract(const Duration(days: _days - 1));

    final rods = <(double, Color)>[];
    var hasAny = false;
    for (var i = 0; i < _days; i++) {
      final date = start.add(Duration(days: i));
      final record = notifier.findRecordForDate(date);
      double height = 0;
      Color color = _hayzColor;
      if (record != null) {
        hasAny = true;
        switch (record.type) {
          case PeriodRecordType.nifas:
            color = _nifasColor;
          case PeriodRecordType.istihadha:
            color = _istihadhaColor;
          case PeriodRecordType.hayz:
            break;
        }
        final flow = record.flowValue;
        height = switch (flow) {
          PeriodFlow.light => 1,
          PeriodFlow.heavy => 3,
          PeriodFlow.medium => 2,
          // No flow recorded → no bar (a fake «متوسط» would mislead).
          null => 0,
        };
      }
      rods.add((height, color));
    }
    if (!hasAny) return const SizedBox.shrink();

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
            Icon(Icons.bar_chart, size: 20, color: periodAccent),
            const SizedBox(width: 8),
            Expanded(
                child: Text('نمودار شدت خونریزی — 30 روز اخیر',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary))),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 3,
                minY: 0,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 8,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i % 7 == 0 && i >= 0 && i < _days) {
                              final j = Jalali.fromDateTime(
                                  start.add(Duration(days: i)));
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${j.day}',
                                    style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 8))),
                              );
                            }
                            return const SizedBox();
                          })),
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            if (v == 1) {
                              return Text('کم',
                                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 8)));
                            }
                            if (v == 2) {
                              return Text('متوسط',
                                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 8)));
                            }
                            if (v == 3) {
                              return Text('زیاد',
                                  style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 8)));
                            }
                            return Text('',
                                style: TextStyle(fontSize: AppTheme.scaledFontSize(context, 8)));
                          })),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
                gridData: const FlGridData(
                    drawVerticalLine: false, horizontalInterval: 1),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final i = group.x.toInt();
                      final date = start.add(Duration(days: i));
                      final j = Jalali.fromDateTime(date);
                      final record = notifier.findRecordForDate(date);
                      String? kind;
                      if (record != null) {
                        kind = record.type == PeriodRecordType.nifas
                            ? 'نفاس'
                            : record.type == PeriodRecordType.istihadha
                                ? 'استحاضه'
                                : 'حیض';
                      }
                      final level = switch (rod.toY) {
                        1 => 'کم',
                        2 => 'متوسط',
                        3 => 'زیاد',
                        _ => null,
                      };
                      return BarTooltipItem(
                        '${j.day}/${j.month}${kind != null ? '\n$kind' : ''}${level != null ? '\nشدت: $level' : ''}',
                        TextStyle(color: Colors.white, fontSize: AppTheme.scaledFontSize(context, 11)),
                      );
                    },
                  ),
                ),
                barGroups: List.generate(
                  _days,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                          toY: rods[i].$1, color: rods[i].$2, width: 5),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              _chartDot(context, _hayzColor, 'حیض'),
              _chartDot(context, _nifasColor, 'نفاس'),
              _chartDot(context, _istihadhaColor, 'استحاضه'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartDot(BuildContext context, Color color, String label) {
    final t = TimeThemeKit.of(context).palette;
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
                color: t.textMuted)),
      ],
    );
  }

  static DateTime _dateOnlyLocal(DateTime d) =>
      DateTime(d.year, d.month, d.day);
}
