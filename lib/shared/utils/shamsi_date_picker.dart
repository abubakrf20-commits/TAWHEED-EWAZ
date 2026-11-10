import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/constants/date_constants.dart';

class ShamsiDatePicker {
  ShamsiDatePicker._();

  /// [maxYearOffset] extends the pickable years beyond the current Jalali
  /// year (expiry dates like passports need +10).
  ///
  /// [earliestDate] and [latestDate] bound the *day* selection. They exist for
  /// back-dating: a goal entry can only be logged for a day that has already
  /// happened, and without a lower bound the year dropdown would happily offer
  /// a century ago.
  ///
  /// [title] is the line above the month row — what the Material date picker
  /// called `helpText`. A pick whose meaning is not obvious from its button
  /// («تاریخ رسیدن به نصاب») passes one, so the dialog still says what it asks.
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    int maxYearOffset = 1,
    DateTime? earliestDate,
    DateTime? latestDate,
    String? title,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => _ShamsiDatePickerDialog(
        initialDate: initialDate,
        maxYearOffset: maxYearOffset,
        earliestDate: earliestDate,
        latestDate: latestDate,
        title: title,
      ),
    );
  }
}

class _ShamsiDatePickerDialog extends StatefulWidget {
  const _ShamsiDatePickerDialog({
    this.initialDate,
    this.maxYearOffset = 1,
    this.earliestDate,
    this.latestDate,
    this.title,
  });

  final DateTime? initialDate;

  /// Extra selectable years beyond the current Jalali year.
  final int maxYearOffset;

  final DateTime? earliestDate;
  final DateTime? latestDate;
  final String? title;

  @override
  State<_ShamsiDatePickerDialog> createState() =>
      _ShamsiDatePickerDialogState();
}

class _ShamsiDatePickerDialogState extends State<_ShamsiDatePickerDialog> {
  late int _selYear;
  late int _selMonth;
  late int _selDay;
  late int _viewYear;
  late int _viewMonth;

  @override
  void initState() {
    super.initState();
    final base = _clampToRange(widget.initialDate ?? DateTime.now());
    final j = Jalali.fromDateTime(base);
    _selYear = j.year;
    _selMonth = j.month;
    _selDay = j.day;
    _viewYear = j.year;
    _viewMonth = j.month;
  }

  /// Midnight of [d], so a date range compares on days and not on the time of
  /// day the caller happened to pass.
  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? get _min => widget.earliestDate;
  DateTime? get _max => widget.latestDate;

  /// Pulls [d] into `[earliestDate, latestDate]`.
  DateTime _clampToRange(DateTime d) {
    var out = _dayOf(d);
    if (_max != null && out.isAfter(_dayOf(_max!))) out = _dayOf(_max!);
    if (_min != null && out.isBefore(_dayOf(_min!))) out = _dayOf(_min!);
    return out;
  }

  /// The picked date, or null when it falls outside the allowed range.
  DateTime? get _selectedOrNull {
    final j = Jalali(_selYear, _selMonth, _selDay).toDateTime();
    if (_max != null && _dayOf(j).isAfter(_dayOf(_max!))) return null;
    if (_min != null && _dayOf(j).isBefore(_dayOf(_min!))) return null;
    return j;
  }

  int get _minYear {
    final floor = _min == null
        ? Jalali.fromDateTime(DateTime.now()).year - 100
        : Jalali.fromDateTime(_min!).year;
    // Jalali years are 355/356 days apart, so a `latestDate` in early January
    // can sit in the same Jalali year as one in late December of the year
    // before; expanding the view range by one year either way keeps the
    // dropdown from hiding a reachable day.
    return floor - 1;
  }

  int get _maxYear {
    final ceil = _max == null
        ? Jalali.fromDateTime(DateTime.now()).year + widget.maxYearOffset
        : Jalali.fromDateTime(_max!).year;
    return ceil + 1;
  }

  void _shiftMonth(int delta) {
    setState(() {
      var m = _viewMonth + delta;
      var y = _viewYear;
      if (m < 1) {
        m = 12;
        y--;
      } else if (m > 12) {
        m = 1;
        y++;
      }
      _viewMonth = m;
      _viewYear = y.clamp(_minYear, _maxYear);
    });
  }

  /// پس از پرش به ماه/سال دلخواه، روز را به اول ماه می‌بریم تا تأیید
  /// بدون کلیک‌های اضافی ممکن باشد.
  void _jumpToMonth() {
    _selDay = 1;
    _selMonth = _viewMonth;
    _selYear = _viewYear;
  }

  void _jumpToToday() {
    final j = Jalali.fromDateTime(DateTime.now());
    setState(() {
      _selYear = j.year;
      _selMonth = j.month;
      _selDay = j.day;
      _viewYear = j.year;
      _viewMonth = j.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TimeThemeKit.of(context).palette;
    final gold = isDark ? t.primary : t.tertiary;
    final goldStrong = dsContentColor(context, gold);
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final jFirst = Jalali(_viewYear, _viewMonth);
    final daysInMonth = jFirst.monthLength;
    final startWeekday = jFirst.weekDay;
    final jToday = Jalali.fromDateTime(DateTime.now());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w600,
                  color: t.textMuted,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'ماه قبل',
                  onPressed: () => _shiftMonth(-1),
                ),
                Text(
                  '${DateConstants.persianMonths[_viewMonth - 1]} $_viewYear',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'ماه بعد',
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
            // پرش سریع به سال/ماه دلخواه (بدون کلیک‌های پشت‌سرهم)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _viewMonth,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: gold.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            DateConstants.persianMonths[m - 1],
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (m) {
                      if (m == null) return;
                      setState(() {
                        _viewMonth = m;
                        _jumpToMonth();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _viewYear,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: gold.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      for (var y = _minYear; y <= _maxYear; y++)
                        DropdownMenuItem(
                          value: y,
                          child: Text(
                            '$y',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              color: t.textPrimary,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (y) {
                      if (y == null) return;
                      setState(() {
                        _viewYear = y;
                        _jumpToMonth();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _jumpToToday,
                  icon: Icon(Icons.today, size: 16, color: goldStrong),
                  label: Text(
                    'امروز',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w700,
                      color: goldStrong,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: List.generate(7, (i) {
                  const labels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
                  return Expanded(
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: i == 6
                              ? danger
                              : t.textMuted,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              ...List.generate((daysInMonth + startWeekday + 6) ~/ 7, (row) {
                return Row(
                  children: List.generate(7, (col) {
                    final dayNum = row * 7 + col - startWeekday + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 40));
                    }
                    final isSelected = dayNum == _selDay &&
                        _viewMonth == _selMonth &&
                        _viewYear == _selYear;
                    final isToday = dayNum == jToday.day &&
                        _viewMonth == jToday.month &&
                        _viewYear == jToday.year;
                    // Days outside [earliestDate, latestDate] are shown greyed
                    // out rather than hidden, so the month still reads as a
                    // real month instead of having holes in it.
                    final candidate = _dayOf(
                        Jalali(_viewYear, _viewMonth, dayNum).toDateTime());
                    final enabled =
                        (_min == null || !candidate.isBefore(_dayOf(_min!))) &&
                            (_max == null || !candidate.isAfter(_dayOf(_max!)));
                    return Expanded(
                      child: GestureDetector(
                        onTap: enabled
                            ? () {
                                setState(() {
                                  _selDay = dayNum;
                                  _selMonth = _viewMonth;
                                  _selYear = _viewYear;
                                });
                              }
                            : null,
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? goldStrong
                                : (isToday
                                    ? gold.withValues(alpha: 0.12)
                                    : null),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: AppTheme.scaledFontSize(context, 13),
                                fontWeight: isSelected || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: !enabled
                                    ? t.textMuted
                                        .withValues(alpha: 0.4)
                                    : isSelected
                                        ? Colors.white
                                        : (isToday
                                            ? goldStrong
                                            : t.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_selYear/${_selMonth.toString().padLeft(2, '0')}/${_selDay.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w700,
                    color: goldStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'لغو',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: t.textMuted,
              ),
            ),
          ),
          TextButton(
            // Confirming an out-of-range date used to hand the caller a value
            // it had just been told was not allowed; null closes the dialog
            // without a result, which the callers already handle.
            onPressed: _selectedOrNull == null
                ? null
                : () => Navigator.pop(context, _selectedOrNull),
            child: Text(
              'تأیید',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: goldStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
