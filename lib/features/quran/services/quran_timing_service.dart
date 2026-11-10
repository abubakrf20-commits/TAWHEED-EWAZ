import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:tawheeed/features/quran/data/reciter_map.dart';
import 'package:tawheeed/features/quran/services/quran_storage.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// کلمه با بازه زمانی داخل یک آیه.
class WordTiming {
  final String text;
  final int startMs;
  final int endMs;
  const WordTiming(
      {required this.text, required this.startMs, required this.endMs});
}

/// نتیجه segments یک آیه.
class AyahTiming {
  final String ayahKey; // "2:255"
  final List<WordTiming> words;
  final String audioUrl;
  const AyahTiming(
      {required this.ayahKey, required this.words, required this.audioUrl});
  bool get hasWords => words.isNotEmpty;
}

/// سرویس timing — از Quran.com v4 با پارامتر segments=true.
/// کش: quran_content/timings/{quranComId}/{surah}_{ayah}.json
class QuranTimingService {
  static const _base = 'https://api.quran.com/api/v4/quran/recitations';

  /// نگاشت islamicNetworkId → quranComId (اگر موجود نباشد null → هایلایت کل آیه).
  static int? quranComIdFor(String islamicId) => kIslamicToQuranCom[islamicId];

  static Future<AyahTiming?> fetchTiming(
      String islamicNetworkId, int surah, int ayah) async {
    final qid = quranComIdFor(islamicNetworkId);
    if (qid == null) return null;

    final cachePath = await _cachePath(qid, surah, ayah);
    final cached = await _loadCache(cachePath);
    if (cached != null) return cached;

    try {
      final url = '$_base/$qid/by_ayah/$surah:$ayah?segments=true';
      final res = await http.get(Uri.parse(url), headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final timing = _parse(body, surah, ayah);
      if (timing != null) {
        await _saveCache(cachePath, timing);
      }
      return timing;
    } catch (_) {
      AppLogger.warning('quran_timing_service', 'operation failed');
      return null;
    }
  }

  static AyahTiming? _parse(Map<String, dynamic> json, int surah, int ayah) {
    // Quran.com payload: { audio_file: { url, segments: [[loc, start, end, text?], ...] } }
    // or { audio_files: [...] } depending on endpoint version.
    final af = json['audio_file'] ??
        (json['audio_files'] is List
            ? (json['audio_files'] as List).firstOrNull
            : null);
    if (af is! Map) return null;
    final url = (af['audio_url'] ?? af['url'] ?? '') as String;
    final segs = af['segments'] as List?;
    final words = <WordTiming>[];
    if (segs != null) {
      for (final s in segs) {
        if (s is List && s.length >= 3) {
          // format: [location, startMs, endMs, text?]
          final start = (s[1] as num?)?.toInt() ?? 0;
          final end = (s[2] as num?)?.toInt() ?? 0;
          final txt = s.length > 3 ? (s[3]?.toString() ?? '') : '';
          words.add(WordTiming(text: txt, startMs: start, endMs: end));
        } else if (s is Map) {
          words.add(WordTiming(
            text: (s['text'] ?? '').toString(),
            startMs: (s['start_time'] ?? s['start'] ?? 0) as int,
            endMs: (s['end_time'] ?? s['end'] ?? 0) as int,
          ));
        }
      }
    }
    return AyahTiming(ayahKey: '$surah:$ayah', words: words, audioUrl: url);
  }

  static Future<String> _cachePath(int qid, int surah, int ayah) async {
    final root = await QuranStorage.contentDir();
    return p.join(root.path, 'timings', '$qid', '${surah}_$ayah.json');
  }

  static Future<AyahTiming?> _loadCache(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      final words = (j['words'] as List?)
              ?.map((e) => WordTiming(
                  text: e['text'] ?? '',
                  startMs: e['startMs'] ?? 0,
                  endMs: e['endMs'] ?? 0))
              .toList() ??
          [];
      return AyahTiming(
          ayahKey: j['ayahKey'] ?? '',
          words: words,
          audioUrl: j['audioUrl'] ?? '');
    } catch (_) {
      AppLogger.warning('quran_timing_service', 'operation failed');
      return null;
    }
  }

  static Future<void> _saveCache(String path, AyahTiming t) async {
    try {
      final f = File(path);
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({
        'ayahKey': t.ayahKey,
        'audioUrl': t.audioUrl,
        'words': t.words
            .map(
                (w) => {'text': w.text, 'startMs': w.startMs, 'endMs': w.endMs})
            .toList(),
      }));
    } catch (_) {
      AppLogger.warning('quran_timing_service', 'operation failed');
    }
  }

  /// پیش‌بار بی‌صدا برای دو آیه بعدی (مثل صوت).
  static Future<void> prefetch(String islamicId, int surah, int ayah) async {
    try {
      await fetchTiming(islamicId, surah, ayah);
    } catch (_) {
      AppLogger.warning('quran_timing_service', 'operation failed');
    }
  }
}

extension _F<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
