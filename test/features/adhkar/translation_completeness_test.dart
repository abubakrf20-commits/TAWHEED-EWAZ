import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the bundled adhkar content against truncated Arabic/ Persian text.
///
/// The «تایم لاین اعمال» cards render `translation` straight from these
/// assets, so a string that was saved mid-sentence shows up verbatim to the
/// user with a trailing `...`. Historical regressions: Ayat al-Kursi, Sayyid
/// al-Istighfar and the two closing verses of al-Baqarah were all cut short.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Markers that mean "the author stopped writing here".
  bool looksTruncated(String value) {
    final s = value.trim();
    return s.endsWith('...') || s.endsWith('…') || s.endsWith('..');
  }

  Future<dynamic> loadAsset(String path) async =>
      jsonDecode(await rootBundle.loadString(path));

  void expectNoTruncation(Iterable<dynamic> nodes, String describe) {
    final offenders = <String>[];
    void walk(dynamic node, String at) {
      if (node is Map) {
        node.forEach((k, v) => walk(v, '$at.$k'));
      } else if (node is List) {
        for (var i = 0; i < node.length; i++) {
          walk(node[i], '$at[$i]');
        }
      } else if (node is String && looksTruncated(node)) {
        offenders.add('$at => …${node.trim().substring(
              node.trim().length > 30 ? node.trim().length - 30 : 0,
            )}');
      }
    }

    walk(nodes, describe);
    expect(
      offenders,
      isEmpty,
      reason: 'truncated text in $describe:\n${offenders.join('\n')}',
    );
  }

  group('assets/azkar_content.json', () {
    late List<dynamic> items;

    setUpAll(() async {
      items = await loadAsset('assets/azkar_content.json') as List<dynamic>;
    });

    test('no Arabic or Persian text is cut short', () {
      expectNoTruncation(items, 'azkar_content.json');
    });

    test('every record has non-empty Arabic and translation', () {
      for (final raw in items) {
        final it = raw as Map<String, dynamic>;
        expect(
          (it['arabicText'] as String?)?.trim(),
          isNotEmpty,
          reason: '${it['id']} has no Arabic',
        );
        expect(
          (it['translation'] as String?)?.trim(),
          isNotEmpty,
          reason: '${it['id']} has no translation',
        );
      }
    });

    test('Ayat al-Kursi records are complete in all three periods', () {
      final kursi = items
          .where((raw) => (raw as Map)['title'] == 'آیه الکرسی')
          .cast<Map<String, dynamic>>()
          .toList();
      expect(kursi, isNotEmpty, reason: 'Ayat al-Kursi disappeared');

      for (final it in kursi) {
        final arabic = it['arabicText'] as String;
        final persian = it['translation'] as String;
        // The verse ends at «وَهُوَ الْعَلِيُّ الْعَظِيمُ» (2:255).
        expect(arabic, contains('الْعَظِيمُ'),
            reason: '${it['id']} Arabic stops before the end of 2:255');
        expect(arabic, contains('وَسِعَ كُرْسِيُّهُ'),
            reason: '${it['id']} Arabic is missing the middle of 2:255');
        // A full translation of 2:255 is well over 300 Persian characters.
        expect(persian.length, greaterThan(300),
            reason: '${it['id']} Persian translation is too short to be 2:255');
        expect(persian, isNot(contains('الكرسي')),
            reason:
                '${it['id']} translation mentions the title, not the verse');
      }
    });

    test('closing verses of al-Baqarah are complete', () {
      final baqarah = items
          .where((raw) => (raw as Map)['title'] == 'دو آیه آخر بقره')
          .cast<Map<String, dynamic>>()
          .toList();
      expect(baqarah, isNotEmpty);
      for (final it in baqarah) {
        expect(it['arabicText'] as String, contains('الْكَافِرِينَ'),
            reason: '${it['id']} is missing the end of 2:286');
        expect(it['translation'] as String, contains('پیروز گردان'),
            reason: '${it['id']} is missing the end of 2:286');
      }
    });
  });

  group('assets/content/sunnah_azkar.json', () {
    late Map<String, dynamic> doc;

    setUpAll(() async {
      doc = await loadAsset('assets/content/sunnah_azkar.json')
          as Map<String, dynamic>;
    });

    test('no Arabic or Persian text is cut short', () {
      expectNoTruncation(doc['sections'], 'sunnah_azkar.json');
    });

    test('every record has non-empty Arabic and translation', () {
      for (final sec in doc['sections'] as List) {
        for (final raw in (sec as Map)['items'] as List) {
          final it = raw as Map<String, dynamic>;
          expect((it['arabic'] as String?)?.trim(), isNotEmpty,
              reason: '${it['title']} has no Arabic');
          expect((it['persian'] as String?)?.trim(), isNotEmpty,
              reason: '${it['title']} has no translation');
        }
      }
    });

    test('the translation field holds a translation, not the virtue', () {
      // Regression: two evening records had their `virtue` sentence pasted
      // into `persian` while `virtue` was left null.
      for (final sec in doc['sections'] as List) {
        for (final raw in (sec as Map)['items'] as List) {
          final it = raw as Map<String, dynamic>;
          final persian = (it['persian'] as String).trim();
          expect(
            persian,
            isNot(contains('برای او کافی است')),
            reason: '${it['title']} has the virtue in its translation',
          );
          expect(
            persian,
            isNot(contains('در امان خواهد بود')),
            reason: '${it['title']} has the virtue in its translation',
          );
        }
      }
    });

    test('Ayat al-Kursi records are complete', () {
      final kursi = <Map<String, dynamic>>[];
      for (final sec in doc['sections'] as List) {
        for (final raw in (sec as Map)['items'] as List) {
          final it = raw as Map<String, dynamic>;
          if (it['title'] == 'آیه الکرسی' ||
              it['title'] == 'آیة الکرسی بعد نماز') {
            kursi.add(it);
          }
        }
      }
      expect(kursi, isNotEmpty);
      for (final it in kursi) {
        final arabic = it['arabic'] as String;
        // The «آیة الکرسی بعد نماز» record quotes the hadith, not the verse.
        if (arabic.contains('الْكُرْسِيِّ فِي دُبُرِ')) continue;
        expect(arabic, contains('الْعَظِيمُ'),
            reason: '${it['title']} Arabic stops before the end of 2:255');
        expect((it['persian'] as String).length, greaterThan(300));
      }
    });
  });
}
