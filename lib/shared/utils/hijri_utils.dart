class HijriUtils {
  static const _hijriEpoch = 1948440;

  static int gregToJd(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  static DateTime jdToGreg(int jd) {
    var l = jd + 68569;
    final n = (4 * l) ~/ 146097;
    l = l - ((146097 * n + 3) ~/ 4);
    final i = (4000 * (l + 1)) ~/ 1461001;
    l = l - ((1461 * i) ~/ 4) + 31;
    final j = (80 * l) ~/ 2447;
    final d = l - ((2447 * j) ~/ 80);
    l = j ~/ 11;
    final m = j + 2 - 12 * l;
    final y = 100 * (n - 49) + i + l;
    return DateTime(y, m, d);
  }

  /// Tabular Islamic month length: odd months have 30 days, the rest 29.
  /// Dhu al-Hijjah (12) has 30 days in a leap year and 29 in a common year;
  /// when [year] is omitted the leap assumption is kept for compatibility.
  static bool isHijriLeapYear(int year) {
    final q = (11 * year + 3) ~/ 30;
    final prev = (11 * (year - 1) + 3) ~/ 30;
    return q > prev;
  }

  static int hijriMonthLength(int month, {int? year}) {
    if (month == 12 && year != null && !isHijriLeapYear(year)) return 29;
    return (month % 2 == 1 || month == 12) ? 30 : 29;
  }

  static int hijriToJd(int year, int month, int day) {
    final n = month - 1;
    final pairs = n ~/ 2;
    final extra = n % 2 == 1 ? 30 : 0;
    return (day - 1) +
        (59 * pairs + extra) +
        (year - 1) * 354 +
        ((11 * year + 3) ~/ 30) +
        _hijriEpoch;
  }

  static int _hijriYearStart(int year) {
    return (year - 1) * 354 + ((11 * year + 3) ~/ 30) + _hijriEpoch;
  }

  static int findHijriYear(int jd) {
    int year = ((jd - _hijriEpoch) / 354).floor() + 1;
    if (year < 1) year = 1;
    while (_hijriYearStart(year + 1) <= jd) {
      year++;
    }
    while (_hijriYearStart(year) > jd) {
      year--;
    }
    return year;
  }

  static int hijriYearFromGreg(int gYear, int gMonth, int gDay) {
    final jd = gregToJd(gYear, gMonth, gDay);
    return findHijriYear(jd);
  }

  static int _hijriDayOfYear(int jd, int year) {
    return jd - _hijriYearStart(year) + 1;
  }

  static int hijriMonthFromJd(int jd, int year) {
    final doy = _hijriDayOfYear(jd, year);
    int remaining = doy;
    for (int i = 1; i <= 12; i++) {
      // Pass the year so Dhu al-Hijjah is 29 days in common years;
      // otherwise the year's last day maps to a non-existent 30 Dhul-Hijjah.
      final days = hijriMonthLength(i, year: year);
      if (remaining <= days) return i;
      remaining -= days;
    }
    return 12;
  }

  static int hijriDayFromGreg(int gYear, int gMonth, int gDay) {
    final jd = gregToJd(gYear, gMonth, gDay);
    final year = findHijriYear(jd);
    return hijriDayOfMonthFromJd(jd, year);
  }

  static int hijriDayOfMonthFromJd(int jd, int year) {
    final doy = _hijriDayOfYear(jd, year);
    int remaining = doy;
    for (int i = 1; i <= 12; i++) {
      final days = hijriMonthLength(i, year: year);
      if (remaining <= days) return remaining;
      remaining -= days;
    }
    return remaining;
  }

  static ({int year, int month, int day}) hijriFromGreg(
    int gYear,
    int gMonth,
    int gDay, {
    int offset = 0,
  }) {
    final jd = gregToJd(gYear, gMonth, gDay) + offset;
    final year = findHijriYear(jd);
    final month = hijriMonthFromJd(jd, year);
    final day = hijriDayOfMonthFromJd(jd, year);
    return (year: year, month: month, day: day);
  }

  /// Converts a hijri date to Gregorian. Pass the same [offset] used by
  /// [hijriFromGreg] so the two functions are exact inverses of each other
  /// (without it, round-tripping drifts by `offset` days).
  static DateTime hijriToGreg(int year, int month, int day, {int offset = 0}) {
    return jdToGreg(hijriToJd(year, month, day) - offset);
  }

  /// ایام البیض — روزهای ۱۳، ۱۴ و ۱۵ هر ماه قمری.
  ///
  /// WHY: defined off the Hijri day the calendar grid actually displays
  /// ([hijriFromGreg] with the user's [hijriOffset]), not the raw
  /// astronomical lunar age — so a cell marked bidh can never disagree with
  /// the date printed in that same cell.
  static bool isAyamAlBidh(DateTime date, {int offset = 0}) {
    final day =
        hijriFromGreg(date.year, date.month, date.day, offset: offset).day;
    return day >= 13 && day <= 15;
  }
}
