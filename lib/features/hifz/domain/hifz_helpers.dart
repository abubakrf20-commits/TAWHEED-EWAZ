import 'package:tawheeed/features/quran/data/page_data.dart';
import 'package:tawheeed/features/quran/data/suwar.dart';

/// Quran-layout helpers for the hifz (حفظ قرآن) feature.
///
/// All lookups are backed by the local static data files (`pageData`,
/// `suwar`) so the feature works fully offline.

const int totalQuranPages = 604;

/// Renders [n] with Latin (ASCII) digits — the product standard.
String en(int n) => '$n';

/// Arabic name of surah [id] (1-114), e.g. 2 → 'البقرة'.
String surahNameAr(int id) {
  if (id < 1 || id > surah.length) return '';
  final entry = surah[id - 1];
  if (entry is Map && entry['arabic'] is String) {
    return entry['arabic'] as String;
  }
  return '';
}

/// The Mushaf page (1-604) where [surah]:[ayah] falls, or 0 when unknown.
int pageForAyah(int surahId, int ayah) {
  if (surahId < 1 || surahId > 114 || ayah < 1) return 0;
  for (var page = 1; page <= totalQuranPages; page++) {
    final entries = pageData[page - 1];
    if (entries is! List) continue;
    for (final e in entries) {
      if (e is! Map) continue;
      final s = e['surah'];
      final start = e['start'];
      final end = e['end'];
      if (s is int &&
          start is int &&
          end is int &&
          s == surahId &&
          ayah >= start &&
          ayah <= end) {
        return page;
      }
    }
  }
  return 0;
}

/// Number of pages covered by the range, or 0 when the range is invalid.
/// [sFrom] must be <= [sTo] (and when equal, [aFrom] <= [aTo]).
/// A valid range always counts at least 1 page (one ayah = one page),
/// even when the page lookup for its boundaries is unknown.
int pagesForRange(int sFrom, int aFrom, int sTo, int aTo) {
  if (!isRangeValid(sFrom, aFrom, sTo, aTo)) return 0;
  final pFrom = pageForAyah(sFrom, aFrom);
  final pTo = pageForAyah(sTo, aTo);
  if (pFrom <= 0 || pTo <= 0) return 1;
  return pTo - pFrom + 1;
}

/// True when [sFrom]:[aFrom] comes at or before [sTo]:[aTo].
bool isRangeValid(int sFrom, int aFrom, int sTo, int aTo) {
  if (sFrom < 1 || sFrom > 114 || sTo < 1 || sTo > 114) return false;
  if (aFrom < 1 || aTo < 1) return false;
  if (sFrom > sTo) return false;
  if (sFrom == sTo && aFrom > aTo) return false;
  return true;
}

/// Compact label for a range, e.g. 'البقرة 1 تا 5' or
/// 'البقرة 1:1 تا آل عمران 5:10'.
String rangeLabel(int sFrom, int aFrom, int sTo, int aTo) {
  final fromName = surahNameAr(sFrom);
  final toName = surahNameAr(sTo);
  if (sFrom == sTo) {
    if (aFrom == aTo) return '$fromName ${en(aFrom)}';
    return '$fromName ${en(aFrom)} تا ${en(aTo)}';
  }
  return '$fromName ${en(aFrom)} تا $toName ${en(aTo)}';
}

/// Union of the ranges of [lessons] (clamped to the first and last),
/// or null when [lessons] is empty.
({int sFrom, int aFrom, int sTo, int aTo})? unionOfLessons(
    List<({int sFrom, int aFrom, int sTo, int aTo})> lessons) {
  if (lessons.isEmpty) return null;
  var sFrom = lessons.first.sFrom;
  var aFrom = lessons.first.aFrom;
  var sTo = lessons.first.sTo;
  var aTo = lessons.first.aTo;
  for (final l in lessons.skip(1)) {
    if ((l.sFrom < sFrom) || (l.sFrom == sFrom && l.aFrom < aFrom)) {
      sFrom = l.sFrom;
      aFrom = l.aFrom;
    }
    if ((l.sTo > sTo) || (l.sTo == sTo && l.aTo > aTo)) {
      sTo = l.sTo;
      aTo = l.aTo;
    }
  }
  return (sFrom: sFrom, aFrom: aFrom, sTo: sTo, aTo: aTo);
}

/// Number of DISTINCT Mushaf pages covered by [ranges].
///
/// Repeated or overlapping ayahs are counted once, so memorizing the same
/// page again on another day does not inflate the total (this fixes the
/// double-counting of repeated ayahs). A range whose page lookup is unknown
/// still contributes at least 1 page.
int uniquePagesOf(List<({int sFrom, int aFrom, int sTo, int aTo})> ranges) {
  var fallback = 0;
  final pages = <int>{};
  for (final r in ranges) {
    if (!isRangeValid(r.sFrom, r.aFrom, r.sTo, r.aTo)) continue;
    final pFrom = pageForAyah(r.sFrom, r.aFrom);
    final pTo = pageForAyah(r.sTo, r.aTo);
    if (pFrom <= 0 || pTo <= 0) {
      fallback += 1;
      continue;
    }
    for (var p = pFrom; p <= pTo; p++) {
      pages.add(p);
    }
  }
  return pages.length + fallback;
}
