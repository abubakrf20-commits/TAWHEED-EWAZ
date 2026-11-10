library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Run once on dev machine to generate the offline Quran SQLite database.
/// dart run tools/generate_quran_db.dart
///
/// Output: assets/quran_offline.json
/// This file is bundled with the app — zero network calls at runtime.

Future<void> main() async {
  const base = 'https://api.quran.com/api/v4';
  const persianTranslationId = 135;

  AppLogger.info('generate_quran_db', '=== Quran Offline DB Generator ===');

  // 1. Download chapter metadata
  AppLogger.info('generate_quran_db', '[1/3] Downloading surah metadata...');
  final chResp = await http.get(Uri.parse('$base/chapters?language=fa'));
  final chData = jsonDecode(chResp.body)['chapters'] as List;
  final surahs = <Map<String, dynamic>>[];
  for (final c in chData) {
    surahs.add({
      'id': c['id'],
      'name_arabic': c['name_arabic'] ?? '',
      'name_simple': c['name_simple'] ?? '',
      'name_persian': (c['translated_name'] as Map?)?['name'] ?? '',
      'ayah_count': c['verses_count'] ?? 0,
      'revelation_place': c['revelation_place'] ?? 'makkah',
      'start_page': (c['pages'] as List?)?[0] ?? 1,
      'end_page': (c['pages'] as List?)?[1] ?? 1,
      'bismillah_pre': c['bismillah_pre'] ?? true,
    });
  }
  AppLogger.info('generate_quran_db', '  -> ${surahs.length} surahs');

  // 2. Download all verses (Arabic) for each chapter
  AppLogger.info('generate_quran_db', '[2/3] Downloading Arabic verses (114 chapters)...');
  final ayahs = <Map<String, dynamic>>[];
  for (int ch = 1; ch <= 114; ch++) {
    int page = 1;
    while (true) {
      final url = '$base/verses/by_chapter/$ch'
          '?words=false&fields=text_uthmani,text_imlaei,page_number,juz_number,sajdah_number,verse_key,hizb_number'
          '&per_page=50&page=$page';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) break;
      final verses = (jsonDecode(resp.body)['verses'] as List);
      for (final v in verses) {
        ayahs.add({
          'surah': ch,
          'ayah': v['verse_number'],
          'page': v['page_number'] ?? 1,
          'juz': v['juz_number'] ?? 1,
          'hizb': v['hizb_number'] ?? 1,
          'sajdah': v['sajdah_number'],
          'text_uthmani': v['text_uthmani'] ?? '',
          'text_imlaei': v['text_imlaei'] ?? '',
        });
      }
      if (verses.length < 50) break;
      page++;
      await Future.delayed(const Duration(milliseconds: 80));
    }
    stdout.write('\r  Chapter $ch/114 (${ayahs.length} verses)');
  }
  AppLogger.info('generate_quran_db', '\n  -> ${ayahs.length} total verses');

  // 3. Download Persian translation
  AppLogger.info('generate_quran_db', '[3/3] Downloading Persian translation...');
  final transMap = <String, String>{};
  for (int ch = 1; ch <= 114; ch++) {
    int page = 1;
    while (true) {
      final url = '$base/verses/by_chapter/$ch'
          '?words=false&fields=verse_number'
          '&translations=$persianTranslationId'
          '&per_page=50&page=$page';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) break;
      final verses = (jsonDecode(resp.body)['verses'] as List);
      for (final v in verses) {
        final key = '$ch:${v['verse_number']}';
        final transList = v['translations'] as List?;
        transMap[key] = (transList != null && transList.isNotEmpty)
            ? (transList[0]['text'] ?? '').toString()
            : '';
      }
      if (verses.length < 50) break;
      page++;
      await Future.delayed(const Duration(milliseconds: 80));
    }
    stdout.write('\r  Translation $ch/114');
  }
  AppLogger.info('generate_quran_db', '\n  -> ${transMap.length} translated verses');

  // 4. Merge translations into ayahs
  for (final a in ayahs) {
    final key = '${a['surah']}:${a['ayah']}';
    a['persian'] = transMap[key] ?? '';
  }

  // 5. Write final JSON
  final output = {
    'version': '1.0',
    'surahs': surahs,
    'ayahs': ayahs,
  };

  final file = File('assets/quran_offline.json');
  await file.writeAsString(jsonEncode(output));
  final kb = await file.length() ~/ 1024;
  AppLogger.info('generate_quran_db', '=== Done! ===');
  AppLogger.info('generate_quran_db', 'Output: assets/quran_offline.json (${kb}KB)');
  AppLogger.info('generate_quran_db', 'Surahs: ${surahs.length}');
  AppLogger.info('generate_quran_db', 'Ayahs: ${ayahs.length}');
  AppLogger.info('generate_quran_db', '');
  AppLogger.info('generate_quran_db', 'Next: Add "- assets/quran_offline.json" to pubspec.yaml assets');
}


