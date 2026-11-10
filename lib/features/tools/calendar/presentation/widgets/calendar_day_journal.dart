import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';
import 'package:tawheeed/features/tools/calendar/domain/day_journal_entry.dart';
import 'package:tawheeed/features/tools/calendar/presentation/providers/day_journal_provider.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_style.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';

/// Fasting / task-done ink: the kit's own content-colour rule (lift on dark,
/// deepen on light) instead of a local emerald lift.
Color _emeraldInk(BuildContext context) =>
    dsContentColor(context, CalendarHues.fasting);

// ══════════════════════════════════════════════════════════════
//  WORSHIP DAY INDICATOR
// ══════════════════════════════════════════════════════════════

class WorshipDayIndicator extends ConsumerWidget {
  final DateTime date;
  const WorshipDayIndicator({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch, not just read: with only the notifier this chip kept a stale (or
    // missing) score until something else rebuilt the tab — see FastingToggle.
    ref.watch(evaluationProvider);
    final evalService = ref.read(evaluationProvider.notifier);
    final score = evalService.getScoreForDate(date);
    if (score == null || score <= 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emerald = _emeraldInk(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emerald.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: emerald),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'طاعات: $score امتیاز',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: emerald,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  FASTING TOGGLE
// ══════════════════════════════════════════════════════════════

class FastingToggle extends ConsumerWidget {
  final DateTime date;
  const FastingToggle({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(evaluationProvider);
    final evalService = ref.read(evaluationProvider.notifier);
    final isFasting = evalService.isWorshipDoneOnDate('fasting', date);
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emerald = _emeraldInk(context);

    return GestureDetector(
      onTap: () => evalService.toggleWorshipForDate('fasting', date),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: isFasting
              ? emerald.withValues(alpha: isDark ? 0.16 : 0.10)
              : t.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFasting ? emerald.withValues(alpha: 0.4) : t.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isFasting
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isFasting ? emerald : t.textMuted,
            ),
            const SizedBox(width: 10),
            Text(
              'روزه این روز',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: isFasting ? emerald : t.textSecondary,
              ),
            ),
            const Spacer(),
            if (isFasting)
              Text(
                'ثبت شد',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: emerald,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DAY JOURNAL — «کارها و یادداشت‌های این روز» (per-date tasks & notes)
// ══════════════════════════════════════════════════════════════

class DayJournalSection extends ConsumerStatefulWidget {
  /// Gregorian date key (`YYYY-MM-DD`) of the selected calendar day.
  final String dateKey;

  /// Short human label of the selected day (e.g. «13 شهریور 1405»).
  final String dayLabel;

  const DayJournalSection({
    super.key,
    required this.dateKey,
    required this.dayLabel,
  });

  @override
  ConsumerState<DayJournalSection> createState() => _DayJournalSectionState();
}

class _DayJournalSectionState extends ConsumerState<DayJournalSection> {
  final _controller = TextEditingController();
  DayJournalKind _kind = DayJournalKind.task;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final added = await ref
        .read(dayJournalProvider.notifier)
        .add(widget.dateKey, _kind, text);
    if (!mounted) return;
    if (!added) {
      // The journal had not loaded (or its load failed) — clearing the field
      // here used to discard what the user just typed with no feedback.
      AppSnackBar.error(context, 'یادداشت ثبت نشد؛ دوباره تلاش کنید.');
      return;
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final emerald = _emeraldInk(context);
    final journal = ref.watch(dayJournalProvider);
    final entries = journal.value?[widget.dateKey] ?? const [];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'کارها و یادداشت‌های این روز',
            count: '${entries.length}',
          ),
          Row(
            children: [
              _KindChip(
                label: 'کار',
                icon: Icons.checklist_rounded,
                selected: _kind == DayJournalKind.task,
                color: emerald,
                onTap: () => setState(() => _kind = DayJournalKind.task),
              ),
              const SizedBox(width: 8),
              _KindChip(
                label: 'یادداشت',
                icon: Icons.auto_stories_rounded,
                selected: _kind == DayJournalKind.memory,
                color: t.tertiary,
                onTap: () => setState(() => _kind = DayJournalKind.memory),
              ),
              const Spacer(),
              // The journal card is long once a day has several entries, so it
              // keeps its own date anchor instead of relying on the box above.
              // Flexible + ellipsis: as a plain Text it would overflow the row,
              // and SectionHeader's own trailing would squash the title.
              Flexible(
                child: Text(
                  widget.dayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: t.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 13),
                  ),
                  decoration: InputDecoration(
                    hintText: _kind == DayJournalKind.task
                        ? 'کار امروز را بنویسید…'
                        : 'یادداشت امروز را بنویسید…',
                    hintStyle: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: t.textMuted,
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _add,
                style: IconButton.styleFrom(backgroundColor: t.tertiary),
                icon: Icon(Icons.add_rounded, size: 22, color: t.heroBottom),
                tooltip: 'ثبت',
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.gap),
          if (journal.isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (journal.hasError)
            FailureView(
              id: 'calendar_journal',
              title: 'ثبت یا بارگذاری یادداشت ممکن نشد',
              onRetry: () => ref.invalidate(dayJournalProvider),
              layout: FailureLayout.inline,
            )
          else if (entries.isEmpty)
            Text(
              'برای این روز چیزی ثبت نشده است.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                color: t.textMuted,
              ),
            )
          else
            ...entries.map((e) => _JournalRow(
                  entry: e,
                  onToggle: e.kind == DayJournalKind.task
                      ? () => ref
                          .read(dayJournalProvider.notifier)
                          .toggleDone(widget.dateKey, e.id)
                      : null,
                  onDelete: () => ref
                      .read(dayJournalProvider.notifier)
                      .remove(widget.dateKey, e.id),
                )),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _KindChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : t.textMuted.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? color : t.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: selected ? color : t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalRow extends StatefulWidget {
  final DayJournalEntry entry;
  final VoidCallback? onToggle;
  final VoidCallback onDelete;

  const _JournalRow({
    required this.entry,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<_JournalRow> createState() => _JournalRowState();
}

class _JournalRowState extends State<_JournalRow> {
  bool _expanded = false;
  static const _truncateAt = 140;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final onToggle = widget.onToggle;
    final onDelete = widget.onDelete;
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emerald = _emeraldInk(context);
    final isTask = entry.kind == DayJournalKind.task;
    final color = isTask ? emerald : t.tertiary;
    final bgColor =
        isDark ? color.withValues(alpha: 0.10) : color.withValues(alpha: 0.06);
    final long = entry.text.length > _truncateAt;
    final showAll = _expanded || !long;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.rowGap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTask)
              GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                // A bare 20px icon is not a tappable target; the box keeps the
                // row compact while the hit area reaches 32x40.
                child: SizedBox(
                  width: 32,
                  height: 40,
                  child: Center(
                    child: Icon(
                      entry.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: entry.done ? emerald : t.textMuted,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: 32,
                height: 40,
                child: Center(
                    child: Icon(Icons.auto_stories_rounded,
                        size: 17, color: color)),
              ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.text,
                    textDirection: TextDirection.rtl,
                    maxLines: showAll ? null : 3,
                    overflow: showAll ? null : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13),
                      height: 1.7,
                      color: entry.done ? t.textMuted : t.textPrimary,
                      decoration:
                          entry.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (long)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _expanded ? 'بستن' : 'نمایش بیشتر',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'حذف یادداشت',
              child: GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                // Deleting is destructive; the 17px glyph alone was a target
                // roughly a third of the minimum touch size.
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: t.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
