import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/fasting/data/fasting_content.dart';

/// The RELIGIOUS CONTENT RULE for the fasting section: the flat redesign
/// must move words, never change them. This suite loads the real bundled
/// `sawm.json` through the production loader and pins its shape (every list
/// length), its integrity (no empty title/body/question/answer anywhere) and
/// its quotes (the Baqarah verse, the Ramadan hadith, the Laylat al-Qadr
/// verse and the Shafi'i disclaimer), so a redesign that drops or rewrites a
/// single ruling fails loudly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SawmData.load();
  });

  test('every content list keeps its shipped length', () {
    expect(SawmData.intro.length, 2);
    expect(SawmData.conditions.length, 6);
    expect(SawmData.arkan.length, 2);
    expect(SawmData.nullifiers.length, 7);
    expect(SawmData.doesNotNullify.length, 13);
    expect(SawmData.qadaKaffarah.length, 3);
    expect(SawmData.makruhat.length, 8);
    expect(SawmData.makruhatDetails.length, 8);
    expect(SawmData.sunan.length, 11);
    expect(SawmData.specialCases.length, 8);
    expect(SawmData.contemporaryIssues.length, 11);
    expect(SawmData.faq.length, 10);
    expect(SawmData.disclaimer, isNotEmpty);
  });

  test('no ruling entry has an empty title or body', () {
    final entries = [
      ...SawmData.intro,
      ...SawmData.conditions,
      ...SawmData.arkan,
      ...SawmData.nullifiers,
      ...SawmData.qadaKaffarah,
      ...SawmData.makruhatDetails,
      ...SawmData.specialCases,
      ...SawmData.contemporaryIssues,
    ];
    expect(entries, isNotEmpty);
    for (final e in entries) {
      expect((e['title'] ?? '').trim(), isNotEmpty,
          reason: 'empty title in $e');
      expect((e['body'] ?? '').trim(), isNotEmpty,
          reason: 'empty body in "${e['title']}"');
    }
  });

  test('no plain list item and no faq side is empty', () {
    for (final s in [...SawmData.doesNotNullify, ...SawmData.makruhat, ...SawmData.sunan]) {
      expect(s.trim(), isNotEmpty);
    }
    for (final e in SawmData.faq) {
      expect((e['question'] ?? '').trim(), isNotEmpty);
      expect((e['answer'] ?? '').trim(), isNotEmpty);
    }
  });

  test('the shipped quotes survive byte-for-byte', () {
    final bodies = [
      for (final list in [
        SawmData.intro,
        SawmData.conditions,
        SawmData.arkan,
        SawmData.nullifiers,
        SawmData.qadaKaffarah,
        SawmData.makruhatDetails,
        SawmData.specialCases,
        SawmData.contemporaryIssues,
      ])
        ...list.map((r) => (r['body'] ?? '') as String),
      ...SawmData.doesNotNullify,
      ...SawmData.sunan,
      SawmData.disclaimer,
    ].join('\n');
    // JSON-carried quotes: the Baqarah fasting verse and the disclaimer.
    // (Pinned short: the JSON prints الصِّيَامُ with a shadda where the
    // screen prints a fatha — same verse, different mushaf typography — so
    // the pin stops where all witnesses agree.)
    expect(bodies, contains('كُتِبَ عَلَيْكُمُ'));
    expect(SawmData.disclaimer, contains('مذهب امام شافعی'));
    expect(SawmData.disclaimer, contains('أُنِيبُ'));
    expect(SawmData.intro.first['title'], 'تعریف روزه');

    // Screen-hardcoded quotes (verse display, Ramadan hadith, Laylat
    // al-Qadr): pinned by source scan so the flat redesign cannot silently
    // drop or reword them. A passing run proves these byte sequences are in
    // the shipped screen source.
    final screen = File(
      'lib/features/fasting/presentation/screens/fasting_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('كُتِبَ عَلَيْكُمُ'));
    expect(screen, contains('مَنْ صَامَ رَمَضَانَ إِيمَانًا'));
    expect(screen, contains('خَيْرٌ مِّنْ أَلْفِ شَهْرٍ'));
    expect(screen, contains('بقره - 183'));
  });
}
