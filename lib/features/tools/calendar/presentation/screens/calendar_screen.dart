import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_widgets.dart';
import 'package:tawheeed/features/tools/calendar/presentation/providers/day_journal_provider.dart';
import 'package:tawheeed/features/tools/calendar/data/day_journal_service.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  /// Freezes «today» for the golden/widget tests: the grid marks today, the
  /// hero shows it and the countdown counts to it, so a run that reads the
  /// wall clock can never drift.
  @visibleForTesting
  final DateTime? nowOverride;

  const CalendarScreen({super.key, this.nowOverride});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late int _jBaseYear;
  late int _jBaseMonth;

  /// The page's whole selection, published as one value.
  ///
  /// It is a [ValueNotifier] rather than `setState` fields so a day tap
  /// repaints only the widgets that print the selected day — before this, one
  /// tap rebuilt the entire page, the 30-cell grid included (563 element
  /// rebuilds, measured).
  late final ValueNotifier<CalendarSelection> _selection;

  int _hijriOffset = 0;

  // Memoized per-day events keyed by "yyyy-MM-dd"; avoids recomputing hijri
  // conversion + occasion lookups for every grid cell on each build.
  final Map<String, List<String>> _eventCache = {};

  // The countdown and the month list are keyed on what they actually depend
  // on (today + the hijri offset, the base month + the offset), so rebuilding
  // the page for a journal/evaluation change does not re-scan 180 days.
  String? _nextOccasionKey;
  ({String label, int days})? _nextOccasionCache;
  String? _monthEventsKey;
  List<CalendarMonthEvent>? _monthEventsCache;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _now;
    final j = Jalali.fromDateTime(now);
    _jBaseYear = j.year;
    _jBaseMonth = j.month;
    try {
      _hijriOffset = ref.read(hijriOffsetProvider);
    } catch (e) {
      AppLogger.warning(
          'Failed to read hijriOffset in calendar initState', e.toString());
    }
    _selection = ValueNotifier(_selectionFor(j.year, j.month, j.day));
    // React to hijri offset changes while this screen is alive.
    ref.listenManual(hijriOffsetProvider, (prev, next) {
      if (prev != next && mounted) {
        _hijriOffset = next;
        _clearMemo();
        setState(() {});
        final sel = _selection.value;
        _selection.value = _selectionFor(sel.jYear, sel.jMonth, sel.jDay);
      }
    });
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _clearMemo() {
    _eventCache.clear();
    _nextOccasionKey = null;
    _monthEventsKey = null;
  }

  /// Converts one Jalali day into the three readings the page shows. This is
  /// the single conversion point: the header, the summary and the journal all
  /// read its result.
  CalendarSelection _selectionFor(int jYear, int jMonth, int jDay) {
    final g = Jalali(jYear, jMonth, jDay).toDateTime();
    final h =
        HijriUtils.hijriFromGreg(g.year, g.month, g.day, offset: _hijriOffset);
    return CalendarSelection(
      jYear: jYear,
      jMonth: jMonth,
      jDay: jDay,
      hYear: h.year,
      hMonth: h.month,
      hDay: h.day,
      gYear: g.year,
      gMonth: g.month,
      gDay: g.day,
      events: List.unmodifiable(_eventsForDay(g)),
    );
  }

  void _selectDay(int day) {
    final maxDay = Jalali(_jBaseYear, _jBaseMonth).monthLength;
    final d = day.clamp(1, maxDay);
    final next = _selectionFor(_jBaseYear, _jBaseMonth, d);
    // Tapping the day that is already selected used to rebuild the page twice.
    if (_selection.value.isDay(next.date)) return;
    _selection.value = next;
  }

  /// Moves the page to another Jalali month/day in one state change and one
  /// publish — the grid rebuilds because the month really changed, which is
  /// the only case that needs it.
  void _changeMonth(int jYear, int jMonth, int jDay) {
    final maxDay = Jalali(jYear, jMonth).monthLength;
    final d = jDay.clamp(1, maxDay);
    _clearMemo();
    setState(() {
      _jBaseYear = jYear;
      _jBaseMonth = jMonth;
    });
    _selection.value = _selectionFor(jYear, jMonth, d);
  }

  void _prevMonth() {
    var y = _jBaseYear;
    var m = _jBaseMonth - 1;
    if (m < 1) {
      m = 12;
      y--;
    }
    _changeMonth(y, m, 1);
  }

  void _nextMonth() {
    var y = _jBaseYear;
    var m = _jBaseMonth + 1;
    if (m > 12) {
      m = 1;
      y++;
    }
    _changeMonth(y, m, 1);
  }

  void _goToToday() {
    final j = Jalali.fromDateTime(_now);
    _changeMonth(j.year, j.month, j.day);
  }

  /// Opens the date converter for the day the page is showing — the same
  /// router push the AppBar action used to make (a raw `Navigator.push` would
  /// leave the ambient branch and paint a black page).
  void _openConverter() {
    final sel = _selection.value;
    context.push(
      RouteNames.dateConverter,
      extra: (sel.gYear, sel.gMonth, sel.gDay),
    );
  }

  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => JalaliMonthPickerSheet(
        initialYear: _jBaseYear,
        initialMonth: _jBaseMonth,
        onSelected: (year, month) => _changeDate('jalali', year, month, 1),
      ),
    );
  }

  void _changeDate(String type, int year, int month, int day) {
    try {
      if (type == 'jalali') {
        final m = month.clamp(1, 12);
        final maxDay = Jalali(year, m).monthLength;
        _changeMonth(year, m, day.clamp(1, maxDay));
      } else if (type == 'hijri') {
        final m = month.clamp(1, 12);
        final maxDay = HijriUtils.hijriMonthLength(m, year: year);
        final g = HijriUtils.hijriToGreg(year, m, day.clamp(1, maxDay),
            offset: _hijriOffset);
        final j = Jalali.fromDateTime(g);
        _changeMonth(j.year, j.month, j.day);
      } else {
        final m = month.clamp(1, 12);
        final maxDay = DateTime(year, m + 1, 0).day;
        final d = DateTime(year, m, day.clamp(1, maxDay));
        final j = Jalali.fromDateTime(d);
        _changeMonth(j.year, j.month, j.day);
      }
    } catch (e) {
      AppLogger.warning('calendar_screen', '_changeDate error: $e');
      // A failed month/day jump used to leave the grid on the old month with
      // no signal at all.
      AppSnackBar.error(context, 'پریدن به آن تاریخ ممکن نشد.');
    }
  }

  List<String> _eventsForDay(DateTime gDate) {
    final key = '${gDate.year}-${gDate.month}-${gDate.day}';
    final cached = _eventCache[key];
    if (cached != null) return cached;
    final result = <String>[];
    final h = HijriUtils.hijriFromGreg(gDate.year, gDate.month, gDate.day,
        offset: _hijriOffset);
    for (final o in occasionsForDay(CalendarKind.hijri, h.month, h.day)) {
      result.add(o.label);
    }
    // ایام البیض — با همان شمارهٔ روزی که در خانهٔ تقویم چاپ میشود (جدولی + آفست کاربر)
    if (HijriUtils.isAyamAlBidh(gDate, offset: _hijriOffset)) {
      result.add('ایام البیض (روزه مستحب)');
    }
    final weekday = gDate.weekday;
    if (weekday == 1) result.add('روزه دوشنبه (مستحب)');
    if (weekday == 4) result.add('روزه پنجشنبه (مستحب)');
    _eventCache[key] = result;
    return result;
  }

  List<CalendarMonthEvent> _monthEvents() {
    final key = '$_jBaseYear-$_jBaseMonth|$_hijriOffset';
    final cached = _monthEventsCache;
    if (cached != null && _monthEventsKey == key) return cached;
    final events = <CalendarMonthEvent>[];
    final maxDay = Jalali(_jBaseYear, _jBaseMonth).monthLength;
    for (int d = 1; d <= maxDay; d++) {
      final g = Jalali(_jBaseYear, _jBaseMonth, d).toDateTime();
      for (final label in _eventsForDay(g)) {
        // Attach the exact hijri day for that calendar date.
        final dayHijri = HijriUtils.hijriFromGreg(g.year, g.month, g.day,
            offset: _hijriOffset);
        events.add(CalendarMonthEvent(
            hijriDay: dayHijri.day, gregorianDate: g, label: label));
      }
    }
    events.sort((a, b) => a.gregorianDate.compareTo(b.gregorianDate));
    _monthEventsKey = key;
    _monthEventsCache = events;
    return events;
  }

  ({String label, int days})? _nextOccasion() {
    final now = _now;
    final key = '${now.year}-${now.month}-${now.day}|$_hijriOffset';
    if (_nextOccasionKey == key) return _nextOccasionCache;
    // Calendar-day arithmetic from midnight, like the month grid
    // (`Jalali(...).toDateTime()`): `now.add(Duration(days: i))` carried the
    // wall-clock time, so a DST shift could move the tested date ±1 day.
    final today = DateTime(now.year, now.month, now.day);
    ({String label, int days})? found;
    for (int i = 0; i <= 180; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      final h = HijriUtils.hijriFromGreg(d.year, d.month, d.day,
          offset: _hijriOffset);
      final occs = occasionsForDay(CalendarKind.hijri, h.month, h.day);
      if (occs.isNotEmpty) {
        found = (label: occs.first.label, days: i);
        break;
      }
      // Same fast-day sources as the month list: the countdown should also
      // surface the upcoming Ayyam al-Beed, not only dated occasions.
      if (HijriUtils.isAyamAlBidh(d, offset: _hijriOffset)) {
        found = (label: 'ایام البیض (روزه مستحب)', days: i);
        break;
      }
    }
    _nextOccasionKey = key;
    _nextOccasionCache = found;
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    ref.watch(evaluationProvider);
    final evalService = ref.read(evaluationProvider.notifier);
    // Days that have recorded tasks/memories (journal dot on the cell).
    final journalKeys =
        ref.watch(dayJournalProvider).value?.keys.toSet() ?? const {};

    final baseJalali = Jalali(_jBaseYear, _jBaseMonth);
    final daysInMonth = baseJalali.monthLength;
    final startOffset = weekdaySlot(baseJalali.toDateTime());

    final cells = <CalendarCellData>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const CalendarCellData.empty());
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final g = Jalali(_jBaseYear, _jBaseMonth, d).toDateTime();
      final h = HijriUtils.hijriFromGreg(g.year, g.month, g.day,
          offset: _hijriOffset);
      final isToday =
          g.year == now.year && g.month == now.month && g.day == now.day;
      cells.add(CalendarCellData(
        day: d,
        hijriDay: h.day,
        gregorianDay: g.day,
        isToday: isToday,
        hasEvent: _eventsForDay(g).isNotEmpty,
        hasWorship: (evalService.getScoreForDate(g) ?? 0) > 0,
        hasJournal: journalKeys.contains(DayJournalService.dateKey(g)),
        gregorianDate: g,
      ));
    }

    final nextOcc = _nextOccasion();

    final todayJ = Jalali.fromDateTime(now);
    final todayH = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
        offset: _hijriOffset);
    final todayWeekday = weekdayName(now);

    return SectionShell.list(
      title: 'تقویم',
      // No AppBar: the slim page header rides the ListView (user request,
      // 2026-10-14), so it scrolls away with the month grid. The page gutter
      // lives on the list, which is why the header's own inset is vertical.
      headerPadding: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.page),
      actions: [
        PageAction(
          icon: Icons.swap_horiz_rounded,
          tooltip: 'مبدل تاریخ',
          onPressed: _openConverter,
        ),
      ],
      children: [
        // The selection blocks listen on their own: a day tap repaints these
        // three and the two grid cells whose flag flipped, never the page.
        ValueListenableBuilder<CalendarSelection>(
          valueListenable: _selection,
          builder: (context, sel, _) => CalendarMonthHeader(
            shamsiMonthName: DateConstants.persianMonths[_jBaseMonth - 1],
            shamsiYear: _jBaseYear,
            shamsiDay: sel.jDay,
            shamsiMonthNum: sel.jMonth,
            hijriMonthName: DateConstants.hijriMonths[sel.hMonth - 1],
            hijriYear: sel.hYear,
            hijriDay: sel.hDay,
            hijriMonthNum: sel.hMonth,
            gregorianMonthName: DateConstants.gregorianMonths[sel.gMonth - 1],
            gregorianYear: sel.gYear,
            gregorianDay: sel.gDay,
            gregorianMonthNum: sel.gMonth,
            todayWeekday: todayWeekday,
            todayTitle:
                '${todayJ.day} ${DateConstants.persianMonths[todayJ.month - 1]} ${todayJ.year}',
            todaySubtitle:
                '${todayH.day} ${DateConstants.hijriMonths[todayH.month - 1]} ${todayH.year}  ·  ${now.day} ${DateConstants.gregorianMonths[now.month - 1]} ${now.year}',
            nextOccasionLabel: nextOcc?.label,
            nextOccasionDays: nextOcc?.days,
            onPrev: _prevMonth,
            onNext: _nextMonth,
            onToday: _goToToday,
            onPick: _openMonthPicker,
          ),
        ),
        const SizedBox(height: 8),
        CalendarMonthGrid(
          cells: cells,
          selection: _selection,
          onSelect: _selectDay,
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<CalendarSelection>(
          valueListenable: _selection,
          builder: (context, sel, _) => SelectedDateSummary(
            date: sel.date,
            dayName: weekdayName(sel.date),
            events: sel.events,
            isToday: sel.isDay(now),
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<CalendarSelection>(
          valueListenable: _selection,
          builder: (context, sel, _) => DayJournalSection(
            dateKey: DayJournalService.dateKey(sel.date),
            dayLabel:
                '${sel.jDay} ${DateConstants.persianMonths[sel.jMonth - 1]} ${sel.jYear}',
          ),
        ),
        const SizedBox(height: 12),
        MonthlyEventsSection(
          events: _monthEvents(),
          now: now,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
