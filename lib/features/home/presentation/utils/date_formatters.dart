import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

class DateFormatters {
  DateFormatters._();

  static List<String> get persianMonths => DateConstants.persianMonths;
  static List<String> get gregorianMonths => DateConstants.gregorianMonths;
  static List<String> get hijriMonths => DateConstants.hijriMonths;

  static const List<String> weekDays = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه\u200cشنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  /// One date reading, with **each number isolated separately**.
  ///
  /// A date in Persian UI is read right-to-left: day, month, year. That is the
  /// order the logical string already has, and the RTL paragraph keeps it.
  /// Wrapping the WHOLE string in an LTR isolate would instead pin it
  /// left-to-right and put the year where the day belongs — the exact
  /// regression the audit's first draft had to be corrected for.
  ///
  /// Isolating each digit run (the same convention as
  /// [NumberFormat.fraction]) keeps the paragraph's direction while making
  /// it impossible for bidi to fuse the two numbers into one run or swap
  /// them when the surrounding text or locale changes.
  static String _date(String month, int day, int year) =>
      '${NumberFormat.ltrIsolated('$day')} '
      '$month ${NumberFormat.ltrIsolated('$year')}';

  static String formatShamsi(int day, int month, int year) =>
      _date(persianMonths[month - 1], day, year);

  static String formatGregorian(int day, int month, int year) =>
      _date(gregorianMonths[month - 1], day, year);

  static String formatHijri(int day, int month, int year) =>
      _date(hijriMonths[month - 1], day, year);

  static String formatToday() {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);
    return formatShamsi(jalali.day, jalali.month, jalali.year);
  }
}
