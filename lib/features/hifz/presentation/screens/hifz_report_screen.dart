import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/domain/hifz_helpers.dart';
import 'package:tawheeed/features/hifz/domain/hifz_report.dart';
import 'package:tawheeed/features/hifz/presentation/widgets/hifz_report_pdf.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// `#RRGGBB` → Color. A restored backup (or a hand-edited row) can carry a
/// value that is not a hex colour; `int.parse` threw inside build and took
/// the whole screen down, so an unreadable value falls back to the module
/// accent instead.
Color _hex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', '0xFF'));
  return value == null ? TopicHues.hifz : Color(value);
}

/// Light, print-friendly palette used by the report layout.
const Color _paper = Color(0xFFFDFBF7);
const Color _ink = Color(0xFF263238);
const Color _inkMuted = Color(0xFF78909C);

class HifzReportScreen extends StatefulWidget {
  const HifzReportScreen({
    super.key,
    required this.hafiz,
    required this.lessons,
    required this.reviews,
  });

  final HafizModel hafiz;
  final List<HifzLessonModel> lessons;
  final List<HifzReviewModel> reviews;

  @override
  State<HifzReportScreen> createState() => _HifzReportScreenState();
}

class _HifzReportScreenState extends State<HifzReportScreen> {
  HifzReportMode _mode = HifzReportMode.month;
  late int _jy;
  late int _jm;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = Jalali.now();
    _jy = now.year;
    _jm = now.month;
  }

  String get _periodLabel => _mode == HifzReportMode.month
      ? '${DateConstants.persianMonths[_jm - 1]} ${en(_jy)}'
      : 'سال ${en(_jy)}';

  DateTime _monthStart() => Jalali(_jy, _jm).toDateTime();

  DateTime _nextMonthStart() => Jalali(
        _jm == 12 ? _jy + 1 : _jy,
        _jm == 12 ? 1 : _jm + 1,
      ).toDateTime();

  void _nav(int delta) {
    setState(() {
      if (_mode == HifzReportMode.month) {
        final j = Jalali(_jy, _jm).addMonths(delta);
        _jy = j.year;
        _jm = j.month;
      } else {
        _jy += delta;
      }
    });
  }

  ({
    HifzPeriodReport? month,
    HifzYearReport? year,
    Map<int, int>? pagesByDay,
    int? dayCount
  }) _reports() {
    if (_mode == HifzReportMode.month) {
      final start = _monthStart();
      final end = _nextMonthStart();
      return (
        month: buildPeriodReport(
            lessons: widget.lessons,
            reviews: widget.reviews,
            start: start,
            end: end),
        year: null,
        pagesByDay: pagesByDayInMonth(
            lessons: widget.lessons, monthStart: start, monthEnd: end),
        dayCount: Jalali(_jy, _jm).monthLength,
      );
    }
    final yearEnd = Jalali(_jy + 1).toDateTime();
    return (
      month: null,
      year: buildYearReport(
        lessons: widget.lessons,
        reviews: widget.reviews,
        jYear: _jy,
        monthStarts: [
          for (var m = 1; m <= 12; m++) Jalali(_jy, m).toDateTime()
        ],
        yearEnd: yearEnd,
      ),
      pagesByDay: null,
      dayCount: null,
    );
  }

  HifzReportLayout _buildLayout() {
    final accent = _hex(widget.hafiz.colorHex);
    final r = _reports();
    return HifzReportLayout(
      hafiz: widget.hafiz,
      accent: accent,
      periodLabel: _periodLabel,
      mode: _mode,
      monthReport: r.month,
      yearReport: r.year,
      pagesByDay: r.pagesByDay,
      dayCount: r.dayCount,
    );
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final r = _reports();
      final bytes = await buildHifzReportPdf(
        hafiz: widget.hafiz,
        periodLabel: _periodLabel,
        monthReport: r.month,
        yearReport: r.year,
        pagesByDay: r.pagesByDay,
        dayCount: r.dayCount,
      );
      await shareHifzReportPdf(
        bytes: bytes,
        fileName:
            'hifz_report_${widget.hafiz.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        text: 'گزارش حفظ قرآن — ${widget.hafiz.name} ($_periodLabel)',
      );
    } catch (e) {
      AppLogger.warning('hifz_report_screen', 'error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ساخت PDF گزارش ممکن نشد؛ دوباره تلاش کنید.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: SectionAppBar(
            title: 'گزارش حفظ قرآن',
            actions: [
              IconButton(
                tooltip: 'استخراج و اشتراک‌گذاری (قابل چاپ)',
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.ios_share),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    SegmentedButton<HifzReportMode>(
                      segments: const [
                        ButtonSegment(
                            value: HifzReportMode.month, label: Text('ماهانه')),
                        ButtonSegment(
                            value: HifzReportMode.year, label: Text('سالانه')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'قبلی',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _nav(-1),
                    ),
                    Text(_periodLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      tooltip: 'بعدی',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _nav(1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  // The system-bar inset rides on top of the page's own
                  // bottom padding, so the last row scrolls above the
                  // 3-button bar and nothing is added where there is none.
                  padding: EdgeInsets.fromLTRB(12, 4, 12,
                      32 + MediaQuery.paddingOf(context).bottom),
                  child: _buildLayout(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The report itself — a light, paper-like layout shared by the on-screen
/// view and the exported (printable) image.
class HifzReportLayout extends StatelessWidget {
  const HifzReportLayout({
    super.key,
    required this.hafiz,
    required this.accent,
    required this.periodLabel,
    required this.mode,
    this.monthReport,
    this.pagesByDay,
    this.dayCount,
    this.yearReport,
  });

  final HafizModel hafiz;
  final Color accent;
  final String periodLabel;
  final HifzReportMode mode;
  final HifzPeriodReport? monthReport;
  final Map<int, int>? pagesByDay;
  final int? dayCount;
  final HifzYearReport? yearReport;

  @override
  Widget build(BuildContext context) {
    final report =
        mode == HifzReportMode.month ? monthReport! : yearReport!.total;
    return Container(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _inkMuted.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReportHeader(hafiz: hafiz, accent: accent, period: periodLabel),
          const SizedBox(height: 14),
          _StatRow(report: report, accent: accent),
          const SizedBox(height: 14),
          _QualitySection(report: report, accent: accent),
          const SizedBox(height: 14),
          _ProgressSection(report: report, accent: accent),
          const SizedBox(height: 14),
          if (mode == HifzReportMode.month)
            _DayGrid(
              accent: accent,
              pagesByDay: pagesByDay ?? const {},
              dayCount: dayCount ?? 30,
            )
          else ...[
            _YearBars(year: yearReport!, accent: accent),
            const SizedBox(height: 18),
            _CumulativeTrendChart(
              year: yearReport!,
              accent: accent,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'تولید شده در ${_generatedAt()}',
            textAlign: TextAlign.center,
            style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 11)),
          ),
        ],
      ),
    );
  }

  String _generatedAt() {
    final j = Jalali.now();
    return '${en(j.day)} ${DateConstants.persianMonths[j.month - 1]} ${en(j.year)}';
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader(
      {required this.hafiz, required this.accent, required this.period});
  final HafizModel hafiz;
  final Color accent;
  final String period;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: accent,
          child: Text(
            hafiz.name.isEmpty ? '؟' : hafiz.name.characters.first,
            style: TextStyle(
                color: Colors.white, fontSize: AppTheme.scaledFontSize(context, 17), fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('گزارش حفظ قرآن',
                style: TextStyle(
                    color: _ink, fontSize: AppTheme.scaledFontSize(context, 17), fontWeight: FontWeight.bold)),
            Text('${hafiz.name} — $period',
                style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 13))),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('﴿حفظ﴾',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.report, required this.accent});
  final HifzPeriodReport report;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatCard(
                accent: accent,
                icon: Icons.menu_book,
                value: '${en(report.lessonPages)} صفحه',
                label: 'حفظ جدید',
                sub: '${en(report.lessonCount)} درس')),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                accent: accent,
                icon: Icons.history_edu,
                value: en(report.sabaqCount),
                label: 'سبق')),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                accent: accent,
                icon: Icons.auto_stories,
                value: en(report.murajaahCount),
                label: 'مراجعه')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.accent,
      required this.icon,
      required this.value,
      required this.label,
      this.sub});
  final Color accent;
  final IconData icon;
  final String value;
  final String label;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: _ink, fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 16))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 11))),
          if (sub != null)
            Text(sub!, style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 10))),
        ],
      ),
    );
  }
}

class _QualitySection extends StatelessWidget {
  const _QualitySection({required this.report, required this.accent});
  final HifzPeriodReport report;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _inkMuted.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
              child:
                  _QualityColumn(label: 'کیفیت سبق', q: report.sabaqQuality)),
          Container(
              width: 1, height: 40, color: _inkMuted.withValues(alpha: 0.2)),
          Expanded(
              child: _QualityColumn(
                  label: 'کیفیت مراجعه', q: report.murajaahQuality)),
        ],
      ),
    );
  }
}

class _QualityColumn extends StatelessWidget {
  const _QualityColumn({required this.label, required this.q});
  final String label;
  final QualityCounts q;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: _ink, fontWeight: FontWeight.w600, fontSize: AppTheme.scaledFontSize(context, 12))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _QualityChip(
                color: AppTheme.success,
                count: q.excellent,
                label: 'عالی'),
            _QualityChip(
                color: const Color(0xFFF9A825),
                count: q.medium,
                label: 'متوسط'),
            _QualityChip(
                color: const Color(0xFFE53935), count: q.weak, label: 'ضعیف'),
          ],
        ),
      ],
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip(
      {required this.color, required this.count, required this.label});
  final Color color;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 4),
          Text('$label ${en(count)}',
              style: TextStyle(
                  color: color, fontSize: AppTheme.scaledFontSize(context, 11), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.report, required this.accent});
  final HifzPeriodReport report;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final pct = (report.progressFraction * 100).round();
    final growth = report.lessonPages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('کل حفظ تا پایان این دوره:',
                style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 12))),
            const SizedBox(width: 6),
            Text('${en(report.cumulativePages)} از ${en(604)} صفحه',
                style: TextStyle(
                    color: _ink, fontWeight: FontWeight.bold, fontSize: AppTheme.scaledFontSize(context, 13))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('+${en(growth)} در این دوره',
                  style: TextStyle(
                      color: accent,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: report.progressFraction,
            minHeight: 12,
            backgroundColor: _inkMuted.withValues(alpha: 0.15),
            color: accent,
          ),
        ),
        const SizedBox(height: 4),
        Text('${en(pct)}٪ از کل قرآن',
            style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 11))),
      ],
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid(
      {required this.accent, required this.pagesByDay, required this.dayCount});
  final Color accent;
  final Map<int, int> pagesByDay;
  final int dayCount;

  Color _cellColor(int pages) {
    if (pages <= 0) return const Color(0xFFECEFF1);
    if (pages == 1) return accent.withValues(alpha: 0.25);
    if (pages == 2) return accent.withValues(alpha: 0.55);
    return accent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('توزیع روزانهٔ حفظ',
            style: TextStyle(
                color: _ink, fontWeight: FontWeight.w600, fontSize: AppTheme.scaledFontSize(context, 12))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= dayCount; d++)
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: _cellColor(pagesByDay[d] ?? 0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(en(d),
                        style: TextStyle(
                            color:
                                (pagesByDay[d] ?? 0) >= 3 ? Colors.white : _ink,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w600)),
                    if ((pagesByDay[d] ?? 0) > 0)
                      Text(en(pagesByDay[d] ?? 0),
                          style: TextStyle(
                              color: (pagesByDay[d] ?? 0) >= 3
                                  ? Colors.white70
                                  : _inkMuted,
                              fontSize: AppTheme.scaledFontSize(context, 9))),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const _LegendItem(color: Color(0xFFECEFF1), label: '0'),
            _LegendItem(color: accent.withValues(alpha: 0.25), label: '1'),
            _LegendItem(color: accent.withValues(alpha: 0.55), label: '2'),
            _LegendItem(color: accent, label: '3+'),
            const SizedBox(width: 4),
            Text('صفحه در روز',
                style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 10))),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 10))),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _YearBars extends StatelessWidget {
  const _YearBars({required this.year, required this.accent});
  final HifzYearReport year;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    var maxPages = 1;
    for (final m in year.months) {
      if (m.report.lessonPages > maxPages) maxPages = m.report.lessonPages;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('به تفکیک ماه',
            style: TextStyle(
                color: _ink, fontWeight: FontWeight.w600, fontSize: AppTheme.scaledFontSize(context, 12))),
        const SizedBox(height: 8),
        for (final m in year.months)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    DateConstants.persianMonths[m.jMonth - 1],
                    style: TextStyle(color: _ink, fontSize: AppTheme.scaledFontSize(context, 11)),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 16,
                      color: _inkMuted.withValues(alpha: 0.12),
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: m.report.lessonPages == 0
                            ? 0
                            : (m.report.lessonPages / maxPages)
                                .clamp(0.02, 1.0),
                        child: Container(color: accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: Text(
                    '${en(m.report.lessonPages)} صفحه · س ${en(m.report.sabaqCount)} · م ${en(m.report.murajaahCount)}',
                    style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 10)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 12-month cumulative growth line (روند تجمعی سالانه).
class _CumulativeTrendChart extends StatelessWidget {
  const _CumulativeTrendChart({required this.year, required this.accent});

  final HifzYearReport year;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final trend = year.inYearCumulativeTrend;
    final maxValue = trend.isEmpty ? 0 : trend.reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('روند رشد صفحات تجمعی',
                style: TextStyle(
                    color: _ink, fontWeight: FontWeight.w600, fontSize: AppTheme.scaledFontSize(context, 12))),
            const Spacer(),
            Text(
              'مجموع: ${en(maxValue)} صفحه',
              style: TextStyle(color: _inkMuted, fontSize: AppTheme.scaledFontSize(context, 11)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: SizedBox(
            height: 150,
            // CustomPaint paints no semantics of its own — the chart needs an
            // explicit spoken label.
            child: Semantics(
              label: 'نمودار میله‌ای روند رشد صفحات تجمعی در طول سال',
              child: CustomPaint(
                painter: _TrendPainter(
                  values: trend,
                  accent: accent,
                  monthNames: [
                    for (final m in year.months)
                      DateConstants.persianMonths[m.jMonth - 1],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.accent,
    required this.monthNames,
  });

  final List<int> values;
  final Color accent;
  final List<String> monthNames;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelH = 22.0;
    const padL = 8.0;
    const padR = 8.0;
    final chartH = size.height - labelH;
    if (chartH <= 0) return;

    final maxValue = values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 31);
    final stepX = (size.width - padL - padR) / (values.length - 1);

    double yFor(int v) => chartH - 6 - (chartH - 12) * (v / maxValue);

    // Horizontal grid lines + faint labels (0, half, max).
    final gridPaint = Paint()
      ..color = _inkMuted.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = chartH - 6 - (chartH - 12) * f;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
      final label = (maxValue * f).round();
      _drawLabel(canvas, en(label), Offset(1, y - 6), _inkMuted, fontSize: 8);
    }

    // Area fill under the line.
    final areaPath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = padL + i * stepX;
      final y = yFor(values[i]);
      if (i == 0) {
        areaPath.moveTo(x, chartH - 6);
        areaPath.lineTo(x, y);
      } else {
        areaPath.lineTo(x, y);
      }
    }
    areaPath.lineTo(padL + (values.length - 1) * stepX, chartH - 6);
    areaPath.close();
    // Flat fill — the growth line and its dots carry the reading, the area
    // stays one flat tint in the section's approved language.
    canvas.drawPath(
      areaPath,
      Paint()..color = accent.withValues(alpha: 0.12),
    );

    // The line itself.
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = padL + i * stepX;
      final y = yFor(values[i]);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // Dots + month labels under each point.
    for (var i = 0; i < values.length; i++) {
      final x = padL + i * stepX;
      final y = yFor(values[i]);
      canvas.drawCircle(Offset(x, y), 3.2, Paint()..color = accent);
      canvas.drawCircle(
        Offset(x, y),
        3.2,
        Paint()
          ..color = _paper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // Month name (short) below.
      final name = i < monthNames.length ? monthNames[i] : '';
      final short = name.length <= 4 ? name : name.substring(0, 4);
      _drawLabel(canvas, short, Offset(x, chartH + 4), _inkMuted,
          fontSize: 8, center: true);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color,
      {double fontSize = 9, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: fontSize, fontFamily: 'Vazirmatn')),
      textDirection: TextDirection.rtl,
    )..layout();
    final dx = center ? offset.dx - tp.width / 2 : offset.dx;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.accent != accent;
}
