import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/kids/data/kids_dao.dart';
import 'package:tawheeed/features/personal2/kids/domain/kid_logic.dart';
import 'package:tawheeed/features/personal2/kids/presentation/providers/kids_providers.dart';
import 'package:tawheeed/features/personal2/shared/mini_charts.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';
import 'package:tawheeed/features/personal2/shared/report_renderer.dart';
import 'package:tawheeed/features/tools/shared/pdf_report_util.dart';
import 'package:tawheeed/shared/services/share_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';

/// «گزارش هفتگی» — the 7-day chart, stat chips, per-habit bars, the rule-based
/// soft tip, and image/PDF export.
///
/// The tip is chosen by [weakestHabit] from the pure layer: the lowest
/// completion with at least three scheduled days, or a praise line when every
/// habit is high. No AI, and never a comparison between siblings unless the
/// parent explicitly turned it on.
class KidsReportScreen extends ConsumerStatefulWidget {
  const KidsReportScreen({super.key});

  @override
  ConsumerState<KidsReportScreen> createState() => _KidsReportScreenState();
}

class _KidsReportScreenState extends ConsumerState<KidsReportScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _sharing = false;

  /// 7 (weekly) or 30 (monthly); the endpoint of both is today.
  int _days = 7;

  String get _periodLabel => _days == 7 ? 'هفتگی' : 'ماهانه';
  String get _rangeLabel => _days == 7 ? 'هفت روز گذشته' : 'سی روز گذشته';

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(kidsHomeProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SectionAppBar(
          title: 'گزارش $_periodLabel',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'بازگشت',
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: home.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FailureView(
              id: 'kids_report_load',
              title: 'گزارش باز نشد',
              detail: 'ثبت‌های قبلی پاک نشده‌اند؛ فقط خواندنشان ناموفق بود.',
              onRetry: () => ref.invalidate(kidsHomeProvider),
              layout: FailureLayout.page,
              error: e,
            ),
            data: (data) => data.children.isEmpty
                ? const AppEmptyState(
                    icon: Icons.child_care_outlined,
                    message: 'فرزندی ثبت نشده',
                    subtitle: 'گزارش وقتی ساخته می‌شود که دست‌کم یک فرزند '
                        'در دفتر کودک ثبت شده باشد.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpacing.page, 12, DsSpacing.page, 40),
                    children: [
                      _PeriodSwitch(
                        days: _days,
                        onChanged: (days) => setState(() => _days = days),
                      ),
                      if (data.children.length > 1) ...[
                        const SizedBox(height: 4),
                        _ComparisonToggle(data: data),
                      ],
                      const SizedBox(height: 12),
                      RepaintBoundary(
                        key: _captureKey,
                        child: Column(
                          children: [
                            for (final child in data.children)
                              _reportCard(context, child, data),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _sharing
                                  ? null
                                  : () => _shareImage(data.children.first.name),
                              icon: const Icon(Icons.image_rounded, size: 18),
                              label: const Text('اشتراک تصویر'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _sharing
                                  ? null
                                  : () => _sharePdf(data.children.first.name),
                              icon: const Icon(Icons.picture_as_pdf_rounded,
                                  size: 18),
                              label: const Text('PDF'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context, KidRecord child, KidsHomeState data) {
    final weekly = ref.watch(_days == 7
        ? kidWeeklyProvider(child.id)
        : kidMonthlyProvider(child.id));
    final t = TimeThemeKit.of(context).palette;
    final color = KidColors.of(child.colorKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: weekly.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => FailureView(
            id: 'kid_weekly_${child.id}',
            title: 'گزارش هفتهٔ این فرزند خوانده نشد',
            onRetry: () => ref.invalidate(kidWeeklyProvider(child.id)),
            layout: FailureLayout.inline,
            error: e,
          ),
          data: (summary) {
            if (summary == null) return const Text('—');
            final weakest = weakestHabit(summary.habits);
            final praise = shouldPraise(summary.habits);
            // A week reads as weekday initials; a month reads as day numbers,
            // because 30 identical letters say nothing at a glance.
            final labels = [
              for (final key in summary.dayKeys)
                _days == 7 ? weekdayLetterOf(key) : _dayNumberOf(key),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  child.name,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _rangeLabel,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                MiniColumnChart(
                  values: summary.perDayDone,
                  labels: labels,
                  color: color,
                  semanticSummary:
                      'نمودار $_days روز؛ مجموع ${summary.perDayDone.fold<int>(0, (a, b) => a + b)} کار انجام‌شده',
                ),
                if (_days == 30) ...[
                  const SizedBox(height: 12),
                  _HeatmapStrip(values: summary.perDayDone, color: color),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statChip(
                      context,
                      Icons.mosque_rounded,
                      'نماز ${summary.prayersDone} از ${summary.prayersScheduled}',
                      color,
                    ),
                    _statChip(
                      context,
                      Icons.star_rounded,
                      '${summary.starsEarned} ستاره',
                      Personal2Colors.kidsStars,
                    ),
                    _statChip(
                      context,
                      Icons.event_available_rounded,
                      '${summary.activeDays} روز فعال',
                      DsStatus.success(context),
                    ),
                  ],
                ),
                if (summary.habits.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'هر عادت',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MiniBars(
                    color: color,
                    items: [
                      for (final c in summary.habits)
                        MiniBarItem(
                          label: c.habit.title,
                          value: c.doneDays.toDouble(),
                          max: c.scheduledDays.toDouble(),
                        ),
                    ],
                  ),
                ],
                if (praise || weakest != null) ...[
                  const SizedBox(height: 10),
                  _tipCard(context, color, weakest, praise),
                ],
                // Sibling comparison is OFF by default and only ever shown when
                // the parent turned it on (kid_settings).
                if (data.settings.showSiblingComparison &&
                    data.children.length > 1) ...[
                  const SizedBox(height: 12),
                  _comparison(context, data, child),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statChip(BuildContext context, IconData icon, String text, Color color) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// The brief's soft tip: never shaming, never a rule, always a suggestion.
  Widget _tipCard(
    BuildContext context,
    Color color,
    HabitCompletion? weakest,
    bool praise,
  ) {
    final t = TimeThemeKit.of(context).palette;
    final text = praise
        ? 'این ${_days == 7 ? 'هفته' : 'ماه'} همهٔ عادت‌ها خوب پیش رفته. آفرین به او!'
        : 'نکته: «${weakest!.habit.title}» کمتر انجام شده؛ شاید زمان یا جایزهٔ '
            'مناسب‌تری لازم باشد.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                height: 1.7,
                color: t.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparison(BuildContext context, KidsHomeState data, KidRecord child) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مقایسهٔ خانگی (فقط چون خودتان روشن کرده‌اید)',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: t.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          for (final other in data.children)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      other.name,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${data.todayTotals[other.id]?.$1 ?? 0} از '
                    '${data.todayTotals[other.id]?.$2 ?? 0}',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: t.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Sharing ──────────────────────────────────────────────────────────

  Future<void> _shareImage(String childName) async {
    setState(() => _sharing = true);
    try {
      // pixelRatio <= 2 per the report renderer's cap.
      final bytes = await ReportRenderer.capturePng(_captureKey);
      if (bytes == null) {
        if (mounted) {
          ShareService.showImageFailure(context);
        }
        return;
      }
      await ReportRenderer.shareImage(
        bytes,
        fileName: 'kids-report-$_days-day.png',
        text: 'گزارش $_periodLabel $childName\n${ShareService.channelBlock}',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _sharePdf(String childName) async {
    setState(() => _sharing = true);
    try {
      final body = <pw.Widget>[];
      for (final child in ref.read(kidsHomeProvider).value?.children ?? const <KidRecord>[]) {
        final summary = await ref.read(
            (_days == 7 ? kidWeeklyProvider(child.id) : kidMonthlyProvider(child.id))
                .future);
        if (summary == null) continue;
        body.add(pw.Text(
          child.name,
          textDirection: pw.TextDirection.rtl,
          style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ));
        body.add(pdfRow(
          'نماز',
          '${summary.prayersDone} از ${summary.prayersScheduled}',
          PdfColor.fromInt(Personal2Colors.kids.toARGB32()),
        ));
        body.add(pdfRow(
          'ستاره',
          '${summary.starsEarned}',
          PdfColor.fromInt(Personal2Colors.kids.toARGB32()),
        ));
        body.add(pdfRow(
          'روز فعال',
          '${summary.activeDays}',
          PdfColor.fromInt(Personal2Colors.kids.toARGB32()),
        ));
        for (final c in summary.habits) {
          body.add(pdfRow(
            c.habit.title,
            '${c.doneDays} از ${c.scheduledDays}',
            PdfColor.fromInt(Personal2Colors.kids.toARGB32()),
          ));
        }
        body.add(pw.SizedBox(height: 10));
      }

      final Uint8List pdf = await ReportRenderer.buildPdf(
        title: 'گزارش $_periodLabel — دفتر عادت کودک',
        subtitle: _rangeLabel,
        accent: Personal2Colors.kids,
        body: body,
      );
      await ReportRenderer.sharePdf(
        pdf,
        fileName: 'kids-report-$_days-day.pdf',
        subject: 'گزارش $_periodLabel $childName',
      );
    } catch (e) {
      AppLogger.warning('kids_report', 'build/share report pdf failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ساخت PDF گزارش ممکن نشد؛ دوباره تلاش کنید.',
              style: TextStyle(fontFamily: AppTheme.fontFamily),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

/// «14» از «1405-08-14» — the monthly chart's tick.
String _dayNumberOf(String dayKey) {
  final parts = dayKey.split('-');
  if (parts.length != 3) return '';
  final day = int.tryParse(parts[2]);
  return day == null ? '' : '$day';
}

/// Opt-in sibling comparison. The brief keeps it off by default (comparing
/// children can shame rather than encourage); the parent turns it on here,
/// in the only screen that renders the comparison.
class _ComparisonToggle extends ConsumerWidget {
  const _ComparisonToggle({required this.data});

  final KidsHomeState data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TimeThemeKit.of(context).palette;
    final on = data.settings.showSiblingComparison;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeThumbColor: Personal2Colors.kids,
        secondary: Icon(
          Icons.people_outline_rounded,
          size: 18,
          color: t.textMuted,
        ),
        title: Text(
          'مقایسهٔ فرزندان',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: t.textPrimary,
          ),
        ),
        subtitle: Text(
          'به طور پیشفرض خاموش است؛ مقایسه فقط با انتخاب شما نمایش داده می‌شود.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            color: t.textMuted,
          ),
        ),
        value: on,
        onChanged: (value) async {
          await ref.read(kidsDaoProvider).saveSettings(
                data.settings.copyWith(showSiblingComparison: value),
              );
          ref.invalidate(kidsHomeProvider);
        },
      ),
    );
  }
}

/// The report's two windows. Weekly is the default because it is the one a
/// parent acts on during the week; the month exists to see past a flat week.
class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Row(
      children: [
        for (final option in const [7, 30]) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: days == option
                      ? Personal2Colors.kids.withValues(alpha: .14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: days == option
                        ? Personal2Colors.kids.withValues(alpha: .45)
                        : t.divider,
                    width: .5,
                  ),
                ),
                child: Text(
                  option == 7 ? 'هفت روز' : 'سی روز',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight:
                        days == option ? FontWeight.w700 : FontWeight.w500,
                    color: days == option
                        ? Personal2Colors.kids
                        : t.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          if (option != 30) const SizedBox(width: 8),
        ],
      ],
    );
  }
}


/// «نقشهٔ حرارتی تقویم» — the month's per-day done counts as a calendar grid.
/// Only shown on the 30-day view, where a column chart stops reading well.
class _HeatmapStrip extends StatelessWidget {
  const _HeatmapStrip({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    var max = 0;
    for (final v in values) {
      if (v > max) max = v;
    }
    return Semantics(
      label: 'نقشهٔ حرارتی $max فعالیت بیشینه در ${values.length} روز',
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final v in values)
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: v <= 0 || max <= 0
                    ? t.surfaceAlt
                    : color.withValues(alpha: .25 + .65 * (v / max)),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
        ],
      ),
    );
  }
}
