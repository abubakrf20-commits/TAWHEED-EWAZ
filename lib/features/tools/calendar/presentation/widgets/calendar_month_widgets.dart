import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_models.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_style.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_day_journal.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

// ══════════════════════════════════════════════════════════════
//  MONTH HEADER — hero date card with countdown
// ══════════════════════════════════════════════════════════════

/// The page's hero: the selected day in the Jalali calendar as the headline,
/// with the Hijri and Gregorian readings as the kit's dot chips under it, the
/// month stepper on both sides, «today» in the middle and the next occasion
/// counted down at the bottom.
///
/// The chips and the pills are kit widgets, so the hero of this page is made
/// of the same parts as the hero of home.
class CalendarMonthHeader extends ConsumerWidget {
  final String shamsiMonthName, hijriMonthName, gregorianMonthName;
  final int shamsiYear, hijriYear, gregorianYear;
  final int shamsiDay, hijriDay, gregorianDay;
  final int shamsiMonthNum, hijriMonthNum, gregorianMonthNum;
  final String todayWeekday, todayTitle, todaySubtitle;
  final String? nextOccasionLabel;
  final int? nextOccasionDays;
  final VoidCallback onPrev, onNext, onToday;
  final VoidCallback onPick;

  const CalendarMonthHeader({
    super.key,
    required this.shamsiMonthName,
    required this.shamsiYear,
    required this.shamsiDay,
    required this.shamsiMonthNum,
    required this.hijriMonthName,
    required this.hijriYear,
    required this.hijriDay,
    required this.hijriMonthNum,
    required this.gregorianMonthName,
    required this.gregorianYear,
    required this.gregorianDay,
    required this.gregorianMonthNum,
    required this.todayWeekday,
    required this.todayTitle,
    required this.todaySubtitle,
    this.nextOccasionLabel,
    this.nextOccasionDays,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onPick,
  });

  String get _countdownText {
    final label = nextOccasionLabel;
    final days = nextOccasionDays;
    if (label == null || days == null) return '';
    if (days == 0) return 'امروز: $label';
    if (days == 1) return 'فردا: $label';
    return '$days روز تا $label';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lite = ref.watch(liteModeProvider).value ?? false;
    final t = TimeThemeKit.of(context).palette;
    final hasCountdown = nextOccasionLabel != null && nextOccasionDays != null;
    const ink = AppPalette.cream;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: HeroCardShell(
        lite: lite,
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: ink),
                  tooltip: 'ماه قبل',
                  onPressed: onPrev,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        // «9 مهر (7) 1405» — month name and its number, the
                        // number in an LTR isolate so the parentheses cannot
                        // mirror in the RTL line.
                        '$shamsiDay $shamsiMonthName '
                        '${NumberFormat.ltrIsolated('($shamsiMonthNum)')} '
                        '$shamsiYear',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 21),
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // The two other readings of the same day. Plain centred
                      // Text, not chips: this is a vertical Column, where
                      // Flexible would cap the height (unbounded here) instead
                      // of the width, and the kit chips cannot ellipsize.
                      const SizedBox(height: 4),
                      Text(
                        '$hijriDay $hijriMonthName '
                        '${NumberFormat.ltrIsolated('($hijriMonthNum)')} '
                        '$hijriYear',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w600,
                          color: ink.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$gregorianDay $gregorianMonthName '
                        '${NumberFormat.ltrIsolated('($gregorianMonthNum)')} '
                        '$gregorianYear',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w500,
                          color: ink.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: ink),
                  tooltip: 'ماه بعد',
                  onPressed: onNext,
                ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onToday,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppPalette.heroGold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.my_location_rounded,
                          size: 17, color: t.heroBottom),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'امروز · $todayWeekday $todayTitle',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            todaySubtitle,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 10),
                              fontWeight: FontWeight.w500,
                              color: ink.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: onPick,
                    behavior: HitTestBehavior.opaque,
                    child: const OutlineChip(
                      text: 'پرش',
                      icon: Icons.date_range_rounded,
                    ),
                  ),
                ),
                if (hasCountdown) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: GlassChip(
                      icon: Icons.timer_outlined,
                      text: _countdownText,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  CALENDAR DAY CELL — Jalali day, status tint, underlines and dots
// ══════════════════════════════════════════════════════════════

class CalendarDayCell extends StatelessWidget {
  final CalendarCellData cell;

  /// Whether this cell is the page's selected day. It is passed in from the
  /// grid rather than stored in [CalendarCellData]: a tap changes it, and a
  /// model that carried it forced every cell to be rebuilt for every tap.
  final bool selected;
  final VoidCallback onTap;

  const CalendarDayCell({
    super.key,
    required this.cell,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final err = isDark ? AppTheme.darkError : AppTheme.lightError;
    final gold = t.tertiary;
    final isFriday = cell.gregorianDate?.weekday == DateTime.friday;

    final hasGradient = cell.isToday;
    // Every day sits in a pale box; worship/selected tints layer over it,
    // and today keeps its gradient hero treatment.
    Color? fill = t.surfaceAlt;
    if (!hasGradient && cell.hasWorship) {
      // A raw hue at a flat alpha, like every other kit fill — the lifted
      // emerald belongs to text, not to a tint.
      fill = CalendarHues.fasting.withValues(alpha: isDark ? 0.16 : 0.10);
    } else if (!hasGradient && selected) {
      fill = t.primary.withValues(alpha: 0.08);
    }
    final border = selected
        ? Border.all(
            color: hasGradient
                ? AppPalette.heroGold.withValues(alpha: 0.85)
                : t.primary,
            width: 1.2)
        : null;

    final Color numColor;
    if (cell.isToday) {
      numColor = AppPalette.heroGold;
    } else if (isFriday) {
      numColor = err;
    } else {
      numColor = t.textPrimary;
    }

    return SizedBox(
      // 43 = 38px visual tile + 2.5px margin on each side (spec cell size).
      height: 43,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: fill,
            gradient: hasGradient
                ? LinearGradient(
                    colors: [t.heroTop, t.heroBottom],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '${cell.day}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 15.5),
                    fontWeight: FontWeight.w700,
                    color: numColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              // Worship recorded: short gold underline.
              if (cell.hasWorship)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 3.5,
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: hasGradient ? AppPalette.heroGold : gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              // Occasion: the Hijri calendar's own dot, the hue the selected-day
              // box prints its Hijri row with.
              if (cell.hasEvent)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: hasGradient
                          ? Colors.white.withValues(alpha: 0.9)
                          : CalendarHues.hijri,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              // Journal (tasks/memories) recorded: gold dot.
              if (cell.hasJournal)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: hasGradient
                          ? Colors.white.withValues(alpha: 0.9)
                          : gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  MONTH GRID — weekday head, the day table and its legend
// ══════════════════════════════════════════════════════════════

/// The month card.
///
/// The selection arrives as a [ValueListenable] instead of living in each
/// [CalendarCellData], so a tap repaints the two cells whose flag actually
/// flipped and nothing else. Baking the flag into the models meant the page had
/// to rebuild the whole grid for one tap (563 element rebuilds, measured).
class CalendarMonthGrid extends StatelessWidget {
  final List<CalendarCellData> cells;
  final ValueListenable<CalendarSelection> selection;
  final ValueChanged<int> onSelect;

  const CalendarMonthGrid({
    super.key,
    required this.cells,
    required this.selection,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: Column(
        children: [
          _weekdayHeader(context, t),
          const SizedBox(height: 4),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (var row = 0; row * 7 < cells.length; row++)
                TableRow(
                  children: List.generate(7, (col) {
                    final idx = row * 7 + col;
                    if (idx >= cells.length) {
                      return const SizedBox(height: 43);
                    }
                    final cell = cells[idx];
                    if (cell.day == 0) {
                      return const SizedBox(height: 43);
                    }
                    return _SelectableDayCell(
                      cell: cell,
                      selection: selection,
                      onTap: () => onSelect(cell.day),
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _legend(context, t),
        ],
      ),
    );
  }
}

/// One day that rebuilds only when its own selected flag flips.
class _SelectableDayCell extends StatefulWidget {
  final CalendarCellData cell;
  final ValueListenable<CalendarSelection> selection;
  final VoidCallback onTap;

  const _SelectableDayCell({
    required this.cell,
    required this.selection,
    required this.onTap,
  });

  @override
  State<_SelectableDayCell> createState() => _SelectableDayCellState();
}

class _SelectableDayCellState extends State<_SelectableDayCell> {
  late bool _selected = _isSelected;

  bool get _isSelected {
    final g = widget.cell.gregorianDate;
    return g != null && widget.selection.value.isDay(g);
  }

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_selectionChanged);
  }

  @override
  void didUpdateWidget(_SelectableDayCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      oldWidget.selection.removeListener(_selectionChanged);
      widget.selection.addListener(_selectionChanged);
    }
    // A new month's models can already carry a different state, and the frame
    // is rebuilding anyway — adopt it without marking this element dirty.
    _selected = _isSelected;
  }

  @override
  void dispose() {
    widget.selection.removeListener(_selectionChanged);
    super.dispose();
  }

  void _selectionChanged() {
    final next = _isSelected;
    if (!mounted || next == _selected) return;
    setState(() => _selected = next);
  }

  @override
  Widget build(BuildContext context) {
    return CalendarDayCell(
      cell: widget.cell,
      selected: _selected,
      onTap: widget.onTap,
    );
  }
}

Widget _weekdayHeader(BuildContext context, AppPalette t) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Row(
    children: List.generate(7, (i) {
      final isFriday = i == 6;
      return Expanded(
        child: Center(
          child: Text(
            kWeekdayLetters[i],
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w700,
              color: isFriday
                  ? (isDark ? AppTheme.darkError : AppTheme.lightError)
                  : t.textMuted,
            ),
          ),
        ),
      );
    }),
  );
}

// Legend swatches mirror the cell states defined in CalendarDayCell — same
// hue, same alpha, or the key would describe a different grid than it sits
// over.
Widget _legend(BuildContext context, AppPalette t) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  Widget item(Widget swatch, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              fontWeight: FontWeight.w600,
              color: t.textMuted,
            ),
          ),
        ],
      );

  return Wrap(
    spacing: 12,
    runSpacing: 6,
    alignment: WrapAlignment.center,
    children: [
      item(
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [t.heroTop, t.heroBottom]),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        'امروز',
      ),
      item(
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: CalendarHues.fasting.withValues(alpha: isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: const Alignment(0, 0.55),
            child: Container(
              width: 7,
              height: 2,
              decoration: BoxDecoration(
                color: t.tertiary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
        'عبادت ثبت‌شده',
      ),
      item(
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: CalendarHues.hijri,
            shape: BoxShape.circle,
          ),
        ),
        'مناسبت',
      ),
      item(
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: t.tertiary,
            shape: BoxShape.circle,
          ),
        ),
        'کار/یادداشت',
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  SELECTED DATE SUMMARY — the tapped day in all three calendars
// ══════════════════════════════════════════════════════════════

/// The box under the grid. The hero above already prints the selected day in
/// all three calendars, so this box carries only what the hero cannot: the
/// day's occasions, its worship score and its fasting control. The weekday
/// name heads it, with the «امروز» badge when the selection is today.
///
/// It also carries the converter entry, which is the one thing this page needs
/// twice. The page header rides the list (by request), so its actions scroll
/// away with the month — after a scroll there was no way to reach the
/// converter without going back up. The earlier version of this button pushed
/// the screen with a raw `Navigator.push`, which left the transparent
/// `Scaffold` without an `AmbientBackground` ancestor and painted a black page;
/// [onOpenConverter] now comes from the screen and goes through `context.push`,
/// so the route supplies the background.
class SelectedDateSummary extends StatelessWidget {
  final DateTime date;
  final String dayName;
  final List<String> events;

  /// Whether the selected day is the real today — the grid marks it, and
  /// without this the box read identically for today and for any other date.
  final bool isToday;

  const SelectedDateSummary({
    super.key,
    required this.date,
    required this.dayName,
    required this.events,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: dayName,
            trailing: isToday ? const BadgeChip(text: 'امروز') : null,
          ),
          if (events.isNotEmpty)
            for (var i = 0; i < events.length; i++)
              Padding(
                padding: EdgeInsets.only(
                    bottom: i == events.length - 1 ? 0 : DsSpacing.rowGap),
                child: _OccasionChip(label: events[i]),
              ),
          if (events.isNotEmpty) const SizedBox(height: 12),
          WorshipDayIndicator(date: date),
          const SizedBox(height: 8),
          FastingToggle(date: date),
        ],
      ),
    );
  }
}

/// An occasion of the selected day, drawn from the same table as the month
/// list — the box and the grid can no longer print one event in two hues.
class _OccasionChip extends StatelessWidget {
  const _OccasionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = CalendarOccasionStyle.of(label);
    final ink = dsContentColor(context, style.hue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: style.hue.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(style.icon, size: 16, color: ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
