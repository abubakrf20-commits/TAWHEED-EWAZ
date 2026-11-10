import 'package:tawheeed/core/utils/jalali_format.dart';
import 'package:tawheeed/shared/utils/date_key.dart';

/// The single date vocabulary of the goals feature.
///
/// Two storage rules, one display rule:
///
///  * **Stored** as a zero-padded Gregorian `yyyy-MM-dd`. Not a cultural
///    choice so much as a mechanical one: the `date` column is both the
///    sort key of the progress queries and the equality key of
///    `progressOn`, and a zero-padded Gregorian string is the one form that
///    sorts correctly as a plain string. The app's other tables key dates
///    the same way (`dateKeyOf` in `shared/utils/date_key.dart`).
///  * **Displayed** as Jalali, because the reader thinks in the Jalali
///    calendar. Goals used to render `2026/9/28` — the one section in the
///    app that ignored `jalali_format.dart` — which made «تا پایان ماه»
///    resolve to the wrong month.
///
/// Digits stay Latin: `jalali_format.dart` states that as the product
/// standard, so switching calendars does not change how numbers look.

/// `yyyy-MM-dd` for today.
String goalTodayIso() => dateKeyOf(DateTime.now());

/// `yyyy-MM-dd` for [date]. The only writer of date strings in this feature.
String goalIsoOf(DateTime date) => dateKeyOf(date);

/// Parse a stored `yyyy-MM-dd` key, or null when it is blank or malformed.
///
/// Returns null rather than throwing so a corrupt row can never crash a
/// screen; callers treat null as «no date».
DateTime? goalParseIso(String iso) {
  if (iso.isEmpty) return null;
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

/// True when [iso] is a well-formed `yyyy-MM-dd` key.
///
/// Checked on write so a malformed date can never reach the table, where it
/// would sort into the wrong position in the history and be invisible to
/// `progressOn` — the failure mode of having no format constraint.
bool goalIsoLooksValid(String iso) {
  if (iso.isEmpty) return true;
  // The shape is part of the contract, not a style preference: `progressOn`
  // matches the day by exact string equality and `progressByDay` orders the
  // chart lexicographically, so an unpadded `2026-9-1` would be a different
  // key from `2026-09-01` for the same day — a silently lost entry.
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso)) return false;
  final d = goalParseIso(iso);
  if (d == null) return false;
  // Reject overflow like 2026-02-31, which int.parse would happily accept.
  return d.year == int.parse(iso.substring(0, 4)) &&
      d.month == int.parse(iso.substring(5, 7)) &&
      d.day == int.parse(iso.substring(8, 10));
}

/// Calendar days between two dates, ignoring the time of day and DST.
///
/// WHY not `difference().inDays`: across a daylight-saving change the span
/// between two local midnights is 23 or 25 hours, and `inDays` truncates 23 to
/// 0. A deadline one day away then read «امروز», an overdue goal turned red a
/// day early, and a streak dropped a day early — all only for users in a zone
/// that shifts its clocks. Both ends are lifted to UTC, where every day is
/// exactly 24 hours.
int goalDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Whole days from today until the stored [iso] key; null when unset or
/// unparseable. Negative when the day is in the past.
int? goalDaysUntil(String iso) {
  final due = goalParseIso(iso);
  if (due == null) return null;
  return goalDaysBetween(DateTime.now(), due);
}

/// `1404/7/6` — Jalali, Latin digits, unpadded.
String goalFaDate(String iso) {
  final d = goalParseIso(iso);
  if (d == null) return iso;
  return jalaliLabelFa(d);
}

/// `7/6` — Jalali day/month for dense chart axes.
String goalFaShort(String iso) {
  final d = goalParseIso(iso);
  if (d == null) return iso;
  final j = jalaliLabelFa(d).split('/');
  return '${j[1]}/${j[0]}';
}

/// «۳ روز مانده» style wording for the deadline suffix on a date tile.
String goalDaysLeftLabel(String iso) {
  final days = goalDaysUntil(iso);
  if (days == null) return '';
  if (days < 0) return ' (${days.abs()} روز گذشته)';
  if (days == 0) return ' (امروز)';
  return ' ($days روز مانده)';
}

/// Days-ago keys, newest first — the window the 14-day chart draws.
List<String> goalRecentDays(int count) {
  final now = DateTime.now();
  return List.generate(
      count,
      (i) => goalIsoOf(now.subtract(
            Duration(days: count - 1 - i),
          )));
}
