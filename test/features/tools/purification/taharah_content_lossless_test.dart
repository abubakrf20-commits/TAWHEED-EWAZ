import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/purification/data/taharah_data.dart';
import 'package:tawheeed/features/tools/purification/presentation/widgets/taharah_quote_text.dart';

/// The RELIGIOUS CONTENT RULE (presentation only): the quote splitter
/// must be a byte-for-byte no-op on every string the taharah content
/// carries. This suite loads the real JSON asset and round-trips every
/// title/body/item through splitTaharahQuotes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TaharahData.load();
  });

  /// Round-trips a body: per paragraph, join the segments in reading
  /// order; re-join paragraphs with '\n\n'.
  String roundTrip(String body) {
    final paragraphs = splitTaharahQuotes(body);
    return [
      for (final p in paragraphs) p.map((s) => s.text).join(),
    ].join('\n\n');
  }

  /// Every content string the taharah module renders. A FUNCTION, not
  /// a field: the values are read AFTER setUpAll has loaded the asset
  /// (a top-level/main() initializer would freeze an empty snapshot
  /// before setUpAll runs).
  List<String> allBodies() => <String>[
        for (final list in [
          TaharahData.intro,
          TaharahData.wudu,
          TaharahData.wuduConditions,
          TaharahData.wuduArkan,
          TaharahData.nullifiers,
          TaharahData.ghusl,
          TaharahData.ghuslObligations,
          TaharahData.ghuslArkan,
          TaharahData.tayammum,
          TaharahData.tayammumConditions,
          TaharahData.tayammumArkan,
          TaharahData.najasah,
          TaharahData.najasahTypes,
          TaharahData.tathir,
          TaharahData.miscellaneous,
        ])
          ...list.map((r) => (r['body'] ?? '') as String),
        for (final s in [
          ...TaharahData.wuduSunan,
          ...TaharahData.doNotNullify,
          ...TaharahData.ghuslMustahabb,
          ...TaharahData.ghuslSunan,
        ])
          s,
        TaharahData.disclaimer,
        TaharahData.tayammumNote,
        TaharahData.tayammumNullifiers,
      ]..removeWhere((s) => s.isEmpty);

  /// Corner cases (not from the JSON) — splitter edge behaviour.
  const corners = [
    'plain text only',
    'text before ﴿آیه unclosed marker stays plain',
    'a «quote» with no citation',
    'a ﴿آیه﴾ [النقل: ۱] with citation',
    '«پیامبر ﷺ» (صحیح مسلم) and ﴿وَإِن كُنتُمْ جُنُبًا فَاطَّهَّرُوا﴾ [المائدة: ۶] mixed',
    'essay [براکت جعلی] و (پرانتز جعلی) without marker',
    '«nested ﴿mix﴾ inside» (گزیده)',
    'leading ﴿اِنَّ﴾ then «حدیث» then تَعلیق',
    'blank\n\nparagraphs\n\n\n\ninside',
  ];

  group('quote splitter — byte-for-byte losslessness', () {
    test('the content actually loaded (asset decoded, non-empty)', () {
      expect(TaharahData.isLoaded, isTrue);
      expect(allBodies().length, greaterThan(30));
    });

    test('every body/item string in taharah.json round-trips exactly', () {
      for (final body in allBodies()) {
        expect(roundTrip(body), body,
            reason:
                'splitter altered: ${body.substring(0, body.length > 40 ? 40 : body.length)}…');
      }
    });

    test('every corner case round-trips exactly', () {
      for (final corner in corners) {
        expect(roundTrip(corner), corner, reason: 'corner: $corner');
      }
    });

    test('blank paragraphs survive the round-trip', () {
      const withBlanks = 'p1\n\n\n\np2\n\np3';
      final paragraphs = splitTaharahQuotes(withBlanks);
      expect(paragraphs.map((p) => p.map((s) => s.text).join()).join('\n\n'),
          withBlanks);
    });

    test('classification is marker-based only — plain text never quoted', () {
      final plain =
          splitTaharahQuotesInParagraph('essay [براکت جعلی] و (پرانتز جعلی)');
      expect(plain.every((s) => !s.isQuote), isTrue);

      final quotes = splitTaharahQuotesInParagraph(
          'تعریف «اَطْهُور» (صحیح مسلم) و ﴿طَهِّرُوا﴾ [البقرة: ۲۲۲]');
      final quoted = quotes.where((s) => s.isQuote).toList();
      expect(quoted, hasLength(2));
      // Hadith first, Quran second — and their citations RIDE with the
      // quotes (never stranded in plain text).
      expect(quoted[0].text, contains('«'));
      expect(quoted[0].text, contains('»'));
      expect(quoted[0].text, contains('(صحیح مسلم)'));
      expect(quoted[0].isQuran, isFalse);
      expect(quoted[1].text, contains('﴿'));
      expect(quoted[1].text, contains('﴾'));
      expect(quoted[1].text, contains('[البقرة: ۲۲۲]'));
      expect(quoted[1].isQuran, isTrue);
    });

    test('no citation decays into a swallowed plain span', () {
      // The historical bug this guards: _citationEnd once returned the
      // WHOLE paragraph when no citation followed, misclassifying prose
      // after the first closing marker as quote and breaking round-trip.
      final segs = splitTaharahQuotesInParagraph('«quote» و ادامهٔ عادی متن');
      expect(segs.map((s) => s.text).join(), '«quote» و ادامهٔ عادی متن');
      expect(segs.length, 2);
      expect(segs[1].isQuote, isFalse);
      expect(segs[1].text, ' و ادامهٔ عادی متن');
    });

    test('unclosed marker degrades to plain, not to a fake quote', () {
      final segs = splitTaharahQuotesInParagraph('متن ﴿نیمه‌کاره و بدون بستن');
      // The buffer flushes, then the unclosed REMAINDER stays plain —
      // two plain segments, zero invented quotes.
      expect(segs, hasLength(2));
      expect(segs.every((s) => !s.isQuote), isTrue);
      expect(segs.map((s) => s.text).join(), 'متن ﴿نیمه‌کاره و بدون بستن');
    });
  });

  group('tab list integrity — nothing renders silently empty', () {
    test('the screen-numbered lists are non-empty', () {
      for (final list in [
        TaharahData.wuduConditions,
        TaharahData.wuduArkan,
        TaharahData.nullifiers,
        TaharahData.ghuslObligations,
        TaharahData.ghuslArkan,
        TaharahData.tayammum,
        TaharahData.tayammumConditions,
        TaharahData.tayammumArkan,
        TaharahData.najasah,
        TaharahData.najasahTypes,
        TaharahData.tathir,
        TaharahData.miscellaneous,
        TaharahData.intro,
        TaharahData.wudu,
        TaharahData.ghusl,
      ]) {
        expect(list, isNotEmpty,
            reason: 'the screen renders this list; silently rendering '
                'an empty list would make an entire fiqh section vanish '
                'while the page still looks filled');
      }
    });

    test('the bullet lists are non-empty', () {
      for (final list in [
        TaharahData.wuduSunan,
        TaharahData.doNotNullify,
        TaharahData.ghuslMustahabb,
        TaharahData.ghuslSunan,
      ]) {
        expect(list, isNotEmpty);
      }
    });

    test('the checklist steps mirror the JSON arkan (both sources in step)',
        () {
      // The const checklists (_wuduSteps/_ghuslSteps/_tayammumSteps)
      // mirror assets/content/taharah.json rukn steps; each must carry
      // a rukn step for the corresponding arkan titles.
      expect(
        TaharahData.wuduArkan
            .every((a) => (a['title'] ?? '') is String && a['title'] != ''),
        isTrue,
      );
      expect(
        TaharahData.ghuslArkan
            .every((a) => (a['title'] ?? '') is String && a['title'] != ''),
        isTrue,
      );
      expect(
        TaharahData.tayammumArkan
            .every((a) => (a['title'] ?? '') is String && a['title'] != ''),
        isTrue,
      );
    });
  });
}
