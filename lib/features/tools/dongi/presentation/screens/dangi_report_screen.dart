import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_categories.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_member_summary.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_report.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';
import 'package:tawheeed/features/tools/dongi/presentation/dangi_colors.dart';
import 'package:tawheeed/features/tools/dongi/presentation/providers/dangi_provider.dart';

enum _ReportTab {
  date('تفکیک تاریخ', Icons.calendar_month_outlined),
  category('تفکیک دسته', Icons.pie_chart_outline),
  members('تفکیک اعضا', Icons.people_alt_outlined);

  const _ReportTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Report / history of a group's expenses, grouped by date, by category or by
/// member, so everything can be reviewed before settlement.
class DangiReportScreen extends ConsumerStatefulWidget {
  const DangiReportScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<DangiReportScreen> createState() => _DangiReportScreenState();
}

class _DangiReportScreenState extends ConsumerState<DangiReportScreen> {
  _ReportTab _tab = _ReportTab.date;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dangiProvider);
    final group = state.groups.where((g) => g.id == widget.groupId).firstOrNull;
    final members = state.membersOf(widget.groupId);
    final expenses = state.spendingsOf(widget.groupId);
    final report = buildDangiExpenseReport(expenses);
    final accent = _accentOf(group);
    final summaries =
        buildDangiMemberSummaries(members: members, expenses: expenses);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SectionAppBar(title: 'گزارش و تاریخچهٔ هزینه‌ها'),
        body: Column(
          children: [
            _SummaryHeader(
              total: report.total,
              count: report.count,
              accent: accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.page, 4, DsSpacing.page, 4),
              child: SegmentedButton<_ReportTab>(
                segments: [
                  for (final t in _ReportTab.values)
                    ButtonSegment(
                      value: t,
                      label: Text(t.label),
                      icon: Icon(t.icon, size: 18),
                    ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: expenses.isEmpty
                  ? AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'هزینه‌ای ثبت نشده',
                      subtitle:
                          'پس از ثبت هزینه‌ها، گزارش آن‌ها اینجا نمایش داده می‌شود.',
                      accent: accent,
                    )
                  : switch (_tab) {
                      _ReportTab.category =>
                        _CategoryView(report: report, accent: accent),
                      _ReportTab.members =>
                        _MemberView(summaries: summaries, accent: accent),
                      _ReportTab.date => _DateView(
                          report: report,
                          members: members,
                          accent: accent,
                        ),
                    },
            ),
          ],
        ),
      ),
    );
  }

  Color _accentOf(DangiGroupModel? group) {
    if (group == null) return TimeThemeKit.of(context).palette.primary;
    try {
      return Color(
          int.parse('FF${group.colorHex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      AppLogger.warning('dangi_report_screen', 'operation failed');
      return TimeThemeKit.of(context).palette.primary;
    }
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.total,
    required this.count,
    required this.accent,
  });

  final double total;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(DsSpacing.page, 12, DsSpacing.page, 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مجموع هزینه‌ها',
                  style: TextStyle(
                    color: TimeThemeKit.of(context).palette.textMuted,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  faMoney(total),
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 19),
                    fontWeight: FontWeight.bold,
                    color: TimeThemeKit.of(context).palette.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${en(count)} هزینه',
            style: TextStyle(
              color: accent,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w600,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateView extends StatelessWidget {
  const _DateView({
    required this.report,
    required this.members,
    required this.accent,
  });

  final DangiExpenseReport report;
  final List<DangiMemberModel> members;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 20),
      itemCount: report.byDate.length,
      itemBuilder: (context, i) {
        final day = report.byDate[i];
        return _DaySection(
          group: day,
          members: members,
          accent: accent,
        );
      },
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.group,
    required this.members,
    required this.accent,
  });

  final DangiDateGroup group;
  final List<DangiMemberModel> members;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final muted = TimeThemeKit.of(context).palette.textMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dangiDateLabelWithWeekday(group.date),
                  style: TextStyle(
                    color: accent,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
              Text(
                faMoney(group.subtotal),
                style: TextStyle(
                  color: muted,
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          radius: 12,
          borderColor: muted.withValues(alpha: 0.15),
          child: Column(
            children: [
              for (var j = 0; j < group.expenses.length; j++) ...[
                if (j > 0)
                  Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: muted.withValues(alpha: 0.1),
                  ),
                _ExpenseRow(
                  expense: group.expenses[j],
                  payerName: members
                          .where((m) => m.id == group.expenses[j].payerId)
                          .firstOrNull
                          ?.name ??
                      '—',
                  memberNames: {
                    for (final m in members) m.id: m.name,
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.payerName,
    this.memberNames = const {},
  });

  final DangiExpenseModel expense;
  final String payerName;
  final Map<String, String> memberNames;

  /// «علی: 200 · رضا: 300» — the per-member consumed amounts of this expense.
  String get _consumersLabel {
    final parts = <String>[];
    expense.consumers.forEach((id, amt) {
      parts.add('${memberNames[id] ?? id}: ${faMoney(amt)}');
    });
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final cat = DangiExpenseCategory.fromId(expense.category);
    final catColor = categoryColor(cat);
    final muted = TimeThemeKit.of(context).palette.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(categoryIcon(cat), size: 18, color: catColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: TimeThemeKit.of(context).palette.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'پرداخت‌کننده: $payerName · ${cat.label}',
                  style: TextStyle(
                    color: muted,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                if (expense.consumers.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _consumersLabel,
                    style: TextStyle(
                      color: catColor,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            faMoney(expense.amount),
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: TimeThemeKit.of(context).palette.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberView extends StatelessWidget {
  const _MemberView({required this.summaries, required this.accent});

  final List<DangiMemberSummary> summaries;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final muted = TimeThemeKit.of(context).palette.textMuted;
    final maxPaid = summaries.isEmpty ? 0.0 : summaries.first.paid;
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 20),
      children: [
        for (final s in summaries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              radius: 12,
              borderColor: muted.withValues(alpha: 0.15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: accent.withValues(alpha: 0.15),
                        child: Text(
                          s.member.name.isEmpty
                              ? '؟'
                              : s.member.name.characters.first,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.scaledFontSize(context, 13),
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.member.name,
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            color: TimeThemeKit.of(context).palette.textPrimary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                      Text(
                        'مصرف: ${faMoney(s.consumed)}',
                        style: TextStyle(
                          color: muted,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          label: 'پرداختی',
                          value: faMoney(s.paid),
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStat(
                          label: 'مصرف',
                          value: faMoney(s.consumed),
                          color: const Color(0xFF455A64),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStat(
                          label: 'مانده',
                          value: s.net.abs() < 0.005
                              ? '0'
                              : '${s.net > 0 ? '+' : '−'}${faMoney(s.net.abs())}',
                          color: s.net >= -0.005
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value:
                          maxPaid <= 0 ? 0 : (s.paid / maxPaid).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: muted.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted = TimeThemeKit.of(context).palette.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: muted,
              fontSize: AppTheme.scaledFontSize(context, 10),
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w800,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryView extends StatelessWidget {
  const _CategoryView({required this.report, required this.accent});

  final DangiExpenseReport report;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final muted = TimeThemeKit.of(context).palette.textMuted;
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 8, DsSpacing.page, 20),
      children: [
        for (final c in report.byCategory)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              radius: 12,
              borderColor: muted.withValues(alpha: 0.15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              categoryColor(c.category).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          categoryIcon(c.category),
                          size: 20,
                          color: categoryColor(c.category),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.category.label,
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            color: TimeThemeKit.of(context).palette.textPrimary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                      Text(
                        '${en(c.expenses.length)} مورد',
                        style: TextStyle(
                          color: muted,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        faMoney(c.total),
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.bold,
                          color: TimeThemeKit.of(context).palette.textPrimary,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: report.maxCategoryTotal == 0
                          ? 0
                          : (c.total / report.maxCategoryTotal).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: muted.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(
                        categoryColor(c.category),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
