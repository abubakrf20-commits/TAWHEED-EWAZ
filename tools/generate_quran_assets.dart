/// One-time script to generate the bundled local Quran data file.
///
/// Run with: dart run tools/generate_quran_assets.dart
///
/// This downloads all Quran verses (Arabic Uthmani + Imlaei) and Persian
/// translation (Islamhouse, ID 135) from api.quran.com and produces
/// `assets/quran_local.json`.
///
/// After running, add the asset to pubspec.yaml:
///   - assets/quran_local.json
///
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:tawheeed/shared/utils/app_logger.dart';

const String _base = 'https://api.quran.com/api/v4';
const int _translationId = 135; // Islamhouse Persian

Future<void> main() async {
  AppLogger.info('generate_quran_assets', '=== Quran Local Data Generator ===');
  AppLogger.info('generate_quran_assets', 'Downloading chapters list...');

  // 1. Get chapters metadata
  final chaptersResp = await http.get(Uri.parse('$_base/chapters?language=fa'));
  final chaptersData = jsonDecode(chaptersResp.body);
  final chaptersList = chaptersData['chapters'] as List;

  final chaptersMeta = <Map<String, dynamic>>[];
  for (final c in chaptersList) {
    chaptersMeta.add({
      'id': c['id'],
      'name_arabic': c['name_arabic'],
      'name_simple': c['name_simple'],
      'translated_name': c['translated_name']?['name'] ?? '',
      'verses_count': c['verses_count'],
      'revelation_place': c['revelation_place'],
      'pages': c['pages'],
      'bismillah_pre': c['bismillah_pre'],
    });
  }
  AppLogger.info('generate_quran_assets', '  Got ${chaptersMeta.length} chapters');

  // 2. Download all verses for all 114 chapters
  final chaptersJson = <String, dynamic>{};
  int totalVerses = 0;

  for (int ch = 1; ch <= 114; ch++) {
    final verses = await _fetchChapterVerses(ch);
    chaptersJson['$ch'] = verses;
    totalVerses += verses.length;
    stdout.write('\r  Chapter $ch/114 (${verses.length} verses, total: $totalVerses)');
  }
  AppLogger.info('generate_quran_assets', '\n  Downloaded $totalVerses total verses');

  // 3. Download Persian translation (Islamhouse)
  AppLogger.info('generate_quran_assets', 'Downloading Persian translation (ID: $_translationId)...');
  final translationsJson = <String, dynamic>{};
  final transMap = <String, dynamic>{};

  for (int ch = 1; ch <= 114; ch++) {
    final trans = await _fetchChapterTranslation(ch, _translationId);
    transMap['$ch'] = trans;
    stdout.write('\r  Translation chapter $ch/114');
  }
  translationsJson['$_translationId'] = transMap;
  AppLogger.info('generate_quran_assets', '\n  Translation downloaded');

  // 4. Build final JSON
  final output = {
    'version': '1.0',
    'generated_at': DateTime.now().toIso8601String(),
    'chapters_meta': chaptersMeta,
    'chapters': chaptersJson,
    'translations': translationsJson,
  };

  // 5. Write to file
  final file = File('assets/quran_local.json');
  await file.writeAsString(jsonEncode(output));

  final sizeInKb = await file.length() ~/ 1024;
  AppLogger.info('generate_quran_assets', '\n=== Done! ===');
  AppLogger.info('generate_quran_assets', 'Generated: assets/quran_local.json (${sizeInKb}KB)');
  AppLogger.info('generate_quran_assets', 'Total verses: $totalVerses');
  AppLogger.info('generate_quran_assets', '');
  AppLogger.info('generate_quran_assets', 'Next steps:');
  AppLogger.info('generate_quran_assets', '1. Add "- assets/quran_local.json" to pubspec.yaml under flutter: assets:');
  AppLogger.info('generate_quran_assets', '2. Run "flutter pub get"');
  AppLogger.info('generate_quran_assets', '3. Rebuild the app');
}

Future<List<Map<String, dynamic>>> _fetchChapterVerses(int chapterId) async {
  final all = <Map<String, dynamic>>[];
  int page = 1;

  while (true) {
    final url = '$_base/verses/by_chapter/$chapterId'
        '?words=false&fields=text_uthmani,text_imlaei,page_number,juz_number,sajdah_number,verse_key'
        '&per_page=50&page=$page';

    final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      AppLogger.warning('generate_quran_assets', 'Chapter $chapterId page $page returned ${resp.statusCode}');
      break;
    }

    final data = jsonDecode(resp.body);
    final verses = data['verses'] as List;

    for (final v in verses) {
      all.add({
        'id': v['id'],
        'sura': chapterId,
        'ayah': v['verse_number'],
        'verse_number': v['verse_number'],
        'verse_key': v['verse_key'],
        'text_uthmani': v['text_uthmani'] ?? '',
        'text_imlaei': v['text_imlaei'] ?? '',
        'page_number': v['page_number'] ?? 1,
        'juz_number': v['juz_number'] ?? 1,
        'sajdah_number': v['sajdah_number'],
      });
    }

    if (verses.length < 50) break;
    page++;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  return all;
}

Future<List<String>> _fetchChapterTranslation(int chapterId, int translationId) async {
  final texts = <String>[];
  int page = 1;

  while (true) {
    final url = '$_base/verses/by_chapter/$chapterId'
        '?words=false&fields=verse_number'
        '&translations=$translationId'
        '&per_page=50&page=$page';

    final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) break;

    final data = jsonDecode(resp.body);
    final verses = data['verses'] as List;

    for (final v in verses) {
      final transList = v['translations'] as List?;
      final text = (transList != null && transList.isNotEmpty)
          ? transList[0]['text'] ?? ''
          : '';
      texts.add(text.toString());
    }

    if (verses.length < 50) break;
    page++;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  return texts;
}
