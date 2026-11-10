import 'package:tawheeed/features/quran/data/suwar.dart';

/// Page furniture for the QCF4 mushaf reader, styled after the printed
/// Madinah mushaf (top juz/surah band, ornamental surah banner panels,
/// page-number footer). Pure helpers — unit tested.
class Qcf4PageChrome {
  Qcf4PageChrome._();

  /// Quranak greens sampled from the reference reader (light mode).
  static const int quranakGreen = 0xFF2A7346;
  static const int quranakGreenBright = 0xFF30A73F;

  /// First page of each juz (1..30) in the 604-page Madinah mushaf.
  static const List<int> juzStartPages = <int>[
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182, //
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382, //
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582, //
  ];

  /// Juz (1..30) containing [page] (1..604). Clamped for out-of-range input.
  static int juzOfPage(int page) {
    final p = page.clamp(1, 604);
    var juz = 1;
    for (var i = 0; i < juzStartPages.length; i++) {
      if (p >= juzStartPages[i]) juz = i + 1;
    }
    return juz;
  }

  /// Arabic ordinal of the juz («الثالث» …), without the «الجزء» prefix.
  static const List<String> _juzOrdinals = <String>[
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
    'الحادي عشر',
    'الثاني عشر',
    'الثالث عشر',
    'الرابع عشر',
    'الخامس عشر',
    'السادس عشر',
    'السابع عشر',
    'الثامن عشر',
    'التاسع عشر',
    'العشرون',
    'الحادي والعشرون',
    'الثاني والعشرون',
    'الثالث والعشرون',
    'الرابع والعشرون',
    'الخامس والعشرون',
    'السادس والعشرون',
    'السابع والعشرون',
    'الثامن والعشرون',
    'التاسع والعشرون',
    'الثلاثون',
  ];

  /// «الجزء الثالث» for the juz containing [page].
  static String juzTitleOfPage(int page) =>
      'الجزء ${_juzOrdinals[juzOfPage(page) - 1]}';

  /// Latin digits → Arabic-Indic (٢٠٠) as in the printed mushaf.
  static String toArabicIndic(int n) {
    final s = '$n';
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c >= 0x30 && c <= 0x39) {
        buf.writeCharCode(0x0660 + (c - 0x30));
      } else {
        buf.writeCharCode(c);
      }
    }
    return buf.toString();
  }

  /// Verse count + revelation place («مكية»/«مدنية») for surah [n], or null
  /// when the metadata row is missing.
  static ({int verses, String place})? surahMeta(int n) {
    for (final s in surah) {
      if (s is! Map) continue;
      if ((s['id'] as num?)?.toInt() != n) continue;
      final verses = (s['aya'] as num?)?.toInt() ?? 0;
      final place = (s['place'] as String?) ?? '';
      if (verses <= 0) return null;
      return (
        verses: verses,
        place: place == 'Madinah' ? 'مدنية' : 'مكية',
      );
    }
    return null;
  }
}
