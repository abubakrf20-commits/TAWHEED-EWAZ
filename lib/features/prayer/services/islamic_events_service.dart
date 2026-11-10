import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';

class CalendarEvent {
  const CalendarEvent({required this.title, required this.date});
  final String title;
  final String date;
}

/// Computes upcoming Islamic (hijri) events and maps them to [CalendarEvent]
/// items the home-screen Calendar widget can render.
class IslamicEventsService {
  const IslamicEventsService._();

  // Fixed hijri dates (month, day) for well-known Islamic occasions.
  static const List<_HijriEvent> _events = [
    _HijriEvent(1, 1, 'رأس السنة الهجرية'),
    _HijriEvent(3, 12, 'مولد النبی ﷺ'),
    _HijriEvent(7, 27, 'الإسراء والمعراج'),
    _HijriEvent(8, 15, 'لیلة النصف من شعبان'),
    _HijriEvent(9, 1, 'بداية شهر رمضان'),
    _HijriEvent(10, 1, 'عید الفطر'),
    _HijriEvent(12, 9, 'یوم عرفة'),
    _HijriEvent(12, 10, 'عید الأضحی'),
  ];

  /// Returns the next upcoming events within [daysAhead] days, each paired
  /// with the concrete Gregorian [DateTime] on which it falls. Used by the
  /// notification layer to schedule reminders a few days before each event.
  /// [offset] matches the user-configured hijri offset used elsewhere.
  static List<IslamicEventOccurrence> upcomingWithDates(
      {int daysAhead = 60, int offset = 0}) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final result = <IslamicEventOccurrence>[];
    for (var d = 0; d <= daysAhead; d++) {
      final date = base.add(Duration(days: d));
      final hijri = HijriUtils.hijriFromGreg(date.year, date.month, date.day,
          offset: offset);
      for (final e in _events) {
        if (e.month == hijri.month && e.day == hijri.day) {
          result.add(IslamicEventOccurrence(title: e.title, date: date));
        }
      }
    }
    return result;
  }

  /// Returns the next [limit] upcoming events within [daysAhead] days,
  /// each labelled with its Shamsi (Persian) date. [offset] matches the
  /// user-configured hijri offset used elsewhere for date display.
  static List<CalendarEvent> upcoming(
      {int daysAhead = 75, int limit = 3, int offset = 0}) {
    final now = DateTime.now();
    final result = <CalendarEvent>[];
    for (var d = 0; d <= daysAhead && result.length < limit; d++) {
      final date = now.add(Duration(days: d));
      final hijri = HijriUtils.hijriFromGreg(date.year, date.month, date.day,
          offset: offset);
      for (final e in _events) {
        if (e.month == hijri.month && e.day == hijri.day) {
          final jalali = Jalali.fromDateTime(date);
          final label = d == 0
              ? 'امروز'
              : d == 1
                  ? 'فردا'
                  : '${jalali.day} ${DateConstants.persianMonths[jalali.month - 1]}';
          result.add(CalendarEvent(title: e.title, date: label));
        }
      }
    }
    return result;
  }
}

class _HijriEvent {
  const _HijriEvent(this.month, this.day, this.title);
  final int month;
  final int day;
  final String title;
}

/// A concrete occurrence of an Islamic (hijri) event on a specific Gregorian
/// date. Unlike [CalendarEvent] (which carries a display label), this holds a
/// real [DateTime] so notifications can be scheduled relative to it.
class IslamicEventOccurrence {
  const IslamicEventOccurrence({required this.title, required this.date});
  final String title;
  final DateTime date;
}
