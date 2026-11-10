import 'package:shamsi_date/shamsi_date.dart';

/// Single source for Jalali (Shamsi) date labels used across features.
///
/// All shapes use Latin (ASCII) digits — the product standard:
///  * [jalaliLabelFa]   — `1404/7/3` unpadded (hifz lists)
///  * [jalaliYmdPadded] — `1404/07/03` zero-padded (reminder cards)
///  * [jalaliYmdShort]  — `1404/7/3` unpadded (expenses/tasks/suggestions)
///  * [jalaliDayMonth]  — `03/07/1404` dd/mm/yyyy (اطلاعات من ISO dates)

/// `1404/7/3` — Latin digits, day/month/year, unpadded.
String jalaliLabelFa(DateTime date) {
  final j = Jalali.fromDateTime(date);
  return '${j.day}/${j.month}/${j.year}';
}

/// `1404/07/03` — Latin digits, day/month/year, zero-padded.
String jalaliYmdPadded(DateTime date) {
  final j = Jalali.fromDateTime(date);
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/'
      '${j.day.toString().padLeft(2, '0')}';
}

/// `1404/7/3` — Latin digits, day/month/year, unpadded.
String jalaliYmdShort(Jalali j) => '${j.year}/${j.month}/${j.day}';

/// The «اطلاعات من» screens store picked dates as Gregorian `yyyy-MM-dd`
/// ISO strings (that is what the date pickers return), but every owner of
/// those dates reads and thinks in the Jalali calendar. Display must
/// convert; forgetting to do so showed users raw Gregorian digits like
/// `06/10/2026` under Persian labels.
///
/// Unparseable values (free-text legacy rows) pass through unchanged.
String jalaliDayMonth(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final j = Jalali.fromDateTime(d);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(j.day)}/${two(j.month)}/${j.year}';
}
