import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/prayer/services/islamic_events_service.dart';

const _knownTitles = [
  'رأس السنة الهجرية',
  'مولد النبی ﷺ',
  'الإسراء والمعراج',
  'لیلة النصف من شعبان',
  'بداية شهر رمضان',
  'عید الفطر',
  'یوم عرفة',
  'عید الأضحی',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IslamicEventsService.upcomingWithDates', () {
    test('never empty within 300 days (Eid al-Adha always occurs)', () {
      final events = IslamicEventsService.upcomingWithDates(daysAhead: 300);
      expect(events, isNotEmpty);
    });

    test('every title is a known Islamic occasion', () {
      final events = IslamicEventsService.upcomingWithDates(daysAhead: 300);
      for (final e in events) {
        expect(_knownTitles, contains(e.title));
      }
    });

    test('every occurrence falls inside the requested window', () {
      final base = DateTime.now();
      final today = DateTime(base.year, base.month, base.day);
      final events =
          IslamicEventsService.upcomingWithDates(daysAhead: 300, offset: 5);
      expect(events, isNotEmpty);
      for (final e in events) {
        final diff = e.date.difference(today).inDays;
        expect(diff, greaterThanOrEqualTo(0));
        expect(diff, lessThanOrEqualTo(300));
      }
    });

    test('offset shifts the hijri calendar by one day', () {
      // A 300-day window contains exactly one Eid al-Adha (hijri recurrence
      // is ~354 Gregorian days), so firstWhere is unambiguous for any start.
      final e0 = IslamicEventsService.upcomingWithDates(daysAhead: 300)
          .firstWhere((e) => e.title == 'عید الأضحی');
      final e1 =
          IslamicEventsService.upcomingWithDates(daysAhead: 300, offset: 1)
              .firstWhere((e) => e.title == 'عید الأضحی');
      expect((e0.date.difference(e1.date).inDays).abs(), 1);
    });
  });

  group('IslamicEventsService.upcoming', () {
    test('limit caps the number of returned events', () {
      final events = IslamicEventsService.upcoming(daysAhead: 365, limit: 2);
      expect(events.length, 2);
    });

    test('labels are today/tomorrow or a Shamsi date', () {
      final events = IslamicEventsService.upcoming(daysAhead: 365, limit: 100);
      expect(events, isNotEmpty);
      final monthRe = RegExp(
          r'^\d{1,2} (فروردین|اردیبهشت|خرداد|تیر|مرداد|شهریور|مهر|آبان|آذر|دی|بهمن|اسفند)$');
      for (final e in events) {
        expect(_knownTitles, contains(e.title));
        expect(
            e.date == 'امروز' || e.date == 'فردا' || monthRe.hasMatch(e.date),
            isTrue,
            reason: 'unexpected label: ${e.date}');
      }
    });
  });
}
