// ignore_for_file: prefer_single_quotes, prefer_double_quotes, prefer_final_locals, avoid_redundant_argument_values, curly_braces_in_flow_control_structures

/// Quran data access helpers (replaces the old `qcf_quran_lite` package).
///
/// All lookups are backed by the local data files:
///  * [pageData]     — page → surah/verse ranges
///  * [surah]        — surah metadata (names, place of revelation, verse count)
///  * [juz]          — juz verse ranges
///  * [quarters]     — hizb quarter boundaries
library;

import 'juzs.dart';
import 'page_data.dart';
import 'quarters.dart';
import 'suwar.dart';

/// Returns the raw page data for a [pageNumber] (1-604): a list of entries
/// with `surah`, `start` and `end` keys.
List getPageData(int pageNumber) {
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }
  return pageData[pageNumber - 1];
}

Map<String, int>? _pageForAyahCache;

Map<String, int> _buildPageForAyahCache() {
  final m = <String, int>{};
  for (var pageIndex = 0; pageIndex < pageData.length; pageIndex++) {
    for (final e in pageData[pageIndex] as List) {
      final surah = e['surah'] as int;
      final start = e['start'] as int;
      final end = e['end'] as int;
      for (var a = start; a <= end; a++) {
        m['$surah:$a'] = pageIndex + 1;
      }
    }
  }
  return m;
}

/// Returns the page number (1-604) where the given [surahNumber] and
/// [ayaNo] are located. O(1) via cached map (built lazily on first call).
int getPageNumber(int surahNumber, int ayaNo) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  _pageForAyahCache ??= _buildPageForAyahCache();
  final key = '$surahNumber:$ayaNo';
  final page = _pageForAyahCache![key];
  if (page != null) return page;
  throw "Invalid verse number.";
}

/// Returns the total number of verses in a specific [surahNumber].
int getVerseCount(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No verse found with given surahNumber";
  }
  return int.parse(surah[surahNumber - 1]['aya'].toString());
}

/// Returns the Surah name in transliterated format for a given [surahNumber].
String getSurahName(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['name'].toString();
}

/// Returns the Surah name in Arabic for a given [surahNumber].
String getSurahNameArabic(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['arabic'].toString();
}

/// Returns the Juz number (1-30) for a specific [surahNumber] and [ayaNo].
int getJuzNumber(int surahNumber, int ayaNo) {
  for (final j in juz) {
    if (j["verses"].keys.contains(surahNumber)) {
      if (ayaNo >= j["verses"][surahNumber][0] &&
          ayaNo <= j["verses"][surahNumber][1]) {
        return int.parse(j["id"].toString());
      }
    }
  }
  return -1;
}

/// Returns the current Hizb number (1-60) for the top of the given
/// [pageNumber] — derived from the Rub' el-Hizb quarters.
int getCurrentHizbNumberForPage(int pageNumber) {
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }
  var currentQuarterIndex = 0;
  for (var i = 0; i < quarters.length; i++) {
    final qPage =
        getPageNumber(quarters[i]['surah'] ?? 0, quarters[i]['ayah'] ?? 0);
    if (pageNumber >= qPage) {
      currentQuarterIndex = i;
    } else {
      break;
    }
  }
  return (currentQuarterIndex ~/ 4) + 1;
}

/// Returns the starting page number for the given [hizbNumber] (1-60).
int getHizbStartPage(int hizbNumber) {
  if (hizbNumber < 1 || hizbNumber > 60) {
    throw "Invalid Hizb number. Must be between 1 and 60";
  }
  final q = quarters[(hizbNumber - 1) * 4];
  return getPageNumber(q['surah'] ?? 0, q['ayah'] ?? 0);
}

/// Returns the current active Juz number (1-30) for the top of the given
/// [pageNumber].
int getCurrentJuzNumberForPage(int pageNumber) {
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }

  // Get the first entry (Surah and starting Ayah) on the requested page.
  final firstEntryOnPage = pageData[pageNumber - 1].first;
  final int surahNumber = firstEntryOnPage['surah'] ?? 0;
  final int firstAyahOnPage = firstEntryOnPage['start'] ?? 0;

  // Use the existing getJuzNumber function to find the Juz for that Ayah.
  return getJuzNumber(surahNumber, firstAyahOnPage);
}

/// Returns the starting page number for the given [juzNumber] (1-30).
int getJuzStartPage(int juzNumber) {
  if (juzNumber < 1 || juzNumber > 30) {
    throw "Invalid Juz number. Must be between 1 and 30";
  }
  final juzData = juz[juzNumber - 1];
  final verses = juzData['verses'] as Map<dynamic, dynamic>;
  final firstSurah = (juzData['surahs'] as List).first as int;
  final firstVerse = (verses[firstSurah] as List).first as int;
  return getPageNumber(firstSurah, firstVerse);
}

/// Verse ranges of [juzNumber] (1-30): surah number → (first verse, last
/// verse) inside that juz. Useful for downloading only a juz's verses.
Map<int, (int, int)> juzVerseRanges(int juzNumber) {
  if (juzNumber < 1 || juzNumber > 30) {
    throw "Invalid Juz number. Must be between 1 and 30";
  }
  final juzData = juz[juzNumber - 1];
  final surahs = (juzData['surahs'] as List).cast<int>();
  final verses = juzData['verses'] as Map<dynamic, dynamic>;
  final ranges = <int, (int, int)>{};
  for (final s in surahs) {
    final list = (verses[s] as List).cast<int>();
    ranges[s] = (list.first, list.last);
  }
  return ranges;
}

/// Normalizes Arabic text for flawless searching: strips diacritics and
/// Quranic symbols, and unifies Alef/Ya/Waw/Ta-Marbuta variants.
String normalizeArabicSearchText(String text) {
  if (text.isEmpty) return text;

  // 1. Remove all Arabic diacritics and Quranic symbols (Tashkeel, Waqf marks).
  text = text.replaceAll(
      RegExp(
          r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u06DF-\u06E8\u06EA-\u06ED\u08D4-\u08E2\u08E3-\u08FF]'),
      '');

  // 2. Normalize Alef forms to bare Alef (ا).
  text = text.replaceAll(RegExp(r'[إأآٱ]'), 'ا');

  // 3. Normalize Ya and Alif Maksura to Ya (ي).
  text = text.replaceAll(RegExp(r'[ىئ]'), 'ي');

  // 4. Normalize Waw with Hamza to bare Waw (و).
  text = text.replaceAll(RegExp(r'[ؤ]'), 'و');

  // 5. Normalize Ta Marbuta to Ha (ه).
  text = text.replaceAll(RegExp(r'ة'), 'ه');

  return text;
}
