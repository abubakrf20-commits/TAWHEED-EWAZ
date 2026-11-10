import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The prayer-times share card is not pumpable in a widget test: it watches
/// `prayerTimeServiceProvider`, whose repository starts a location pipeline
/// and a native channel. This is the repo's source-scan idiom for a card like
/// this (see `share_surfaces_source_lock_test.dart`) — it pins the structure
/// the user asked for, not the pixels.
///
/// What it guards, and why each line matters:
///  * the city prints on the header's LEFT — the header is an RTL Row, so the
///    `trailing:` slot IS the visual left edge — with its own location glyph;
///  * the city is not left as the header subtitle again (that was the old,
///    right-aligned one-line-under-the-title placement);
///  * the header carries NO subtitle at all: «امروز · شنبه» only repeated the
///    weekday the date strip already prints two lines below, so the user asked
///    for it to go (2026-11-01);
///  * the six times sit in ONE framed table with a rule between rows, not six
///    separate bordered boxes.
String _source() {
  final raw = File('lib/features/prayer/presentation/screens/'
          'prayer_times_share_screen.dart')
      .readAsStringSync();
  // Comments stripped, so the prose above each rule cannot satisfy it.
  return raw
      .replaceAllMapped(RegExp(r'//[^\n]*'), (m) => '')
      .replaceAllMapped(RegExp(r'/\*.*?\*/', dotAll: true), (m) => '');
}

void main() {
  group('the prayer share card\'s city and table', () {
    late String source;
    setUpAll(() => source = _source());

    test('the city rides the header trailing slot with a pin', () {
      expect(source, contains('trailing: city.isEmpty ? null : _CityChip(city)'));
      expect(source, contains('Icons.place_outlined'));
      expect(source, contains('class _CityChip extends StatelessWidget'));
    });

    test('the city is no longer the header subtitle', () {
      expect(source, isNot(contains('subtitle: city.isEmpty ? null : city')));
    });

    test('the header carries no subtitle, so the card has one title', () {
      // «امروز · شنبه» under the title duplicated the date strip's first cell.
      // Scoped to the header CALL on purpose: the page's ListTiles do carry
      // subtitles (the P-07 city opt-out explains itself), so a page-wide
      // `subtitle:` scan would fail on those for no reason.
      final at = source.indexOf('ShareCardHeader(');
      expect(at, greaterThan(-1), reason: 'the header must be a ShareCardHeader');
      final end = source.indexOf('trailing:', at);
      final header = source.substring(at, end == -1 ? at + 320 : end);
      expect(header, isNot(contains('subtitle:')));
    });

    test('the six times are one table, not six boxes', () {
      expect(source, contains('_TimeTable(rows: _rows, times: times)'));
      expect(source, contains('class _TimeTable extends StatelessWidget'));
      // `_TimeRow` itself must not draw a frame any more — the table owns it.
      final timeRow = source.substring(source.indexOf('class _TimeRow'),
          source.indexOf('class _WisdomBox'));
      expect(timeRow, contains('class _TimeRow'));
      // The table owns the only frame; a row that drew its own border would
      // put six hairline boxes back inside one box.
      expect(timeRow, isNot(contains('Border.all')));
      expect(timeRow, isNot(contains('BoxDecoration')));
    });

    test('the city is always shared — the opt-out switch is gone', () {
      // User decision (2026-11-07): «گزینه نمایش شهر در تصویر و متن حذف کن
      // بصورت پیشفرض موجود باشد». A timetable without its city cannot be
      // read, so both the switch and its two guards are gone for good.
      expect(source, isNot(contains('prayer_share_show_city')));
      expect(source, isNot(contains('SwitchListTile')));
      expect(source, isNot(contains('_showCity')));
      // And neither reader may grow a silent opt-out again.
      final city = source.substring(
          source.indexOf('String get _city'),
          source.indexOf('String get _cityRead'));
      expect(city, contains('cityName'));
      // An empty city is still allowed when the service itself throws; what
      // must never come back is a flag check that blanks it on purpose.
      expect(city, isNot(contains('if (!')));
    });

    test('the verse box cycles BOTH ways, right = previous', () {
      // It used to only advance: one tap always moved forward, so a verse the
      // reader had just left could not be brought back. The two halves are
      // separate semantics nodes, right one first (RTL reading order).
      expect(source, contains('_cycleWisdom(-1)'));
      expect(source, contains('_cycleWisdom(1)'));
      expect(source, contains('class _WisdomTapZone extends StatelessWidget'));
      expect(source, contains("'ذکر قبلی'"));
      expect(source, contains("'ذکر بعدی'"));
      final zones = source.substring(source.indexOf('Positioned.fill('),
          source.indexOf('class _WisdomTapZone'));
      final previousAt = zones.indexOf('_WisdomTapZone(label: ');
      final nextAt = zones.indexOf('_WisdomTapZone(label: ', previousAt + 1);
      expect(previousAt, greaterThan(-1));
      expect(nextAt, greaterThan(previousAt),
          reason: 'the earlier message owns the RIGHT half, so it comes first '
              'in the RTL row');
    });

    test('nothing in the new pieces hard-codes an ink or a size', () {
      final city = source.substring(
          source.indexOf('class _CityChip'), source.indexOf('class _TimeTable'));
      expect(city, isNot(contains('Color(0x')));
      expect(city, isNot(contains('fontSize: 1')));
      expect(city, contains('AppTheme.scaledFontSize'));
      expect(city, contains('ShareCardColors.of(context)'));
    });
  });
}
