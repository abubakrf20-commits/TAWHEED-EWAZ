import 'package:tawheeed/core/design_system/components/section_search.dart';
import 'package:tawheeed/features/quran/data/juzs.dart' as quran_juzs;
import 'package:tawheeed/features/quran/data/suwar.dart' as quran_suwar;

/// The searchable index of «ختم قرآن».
///
/// WHY surah names: the page has no prose worth searching — four virtue lines
/// and a 30-cell grid. What a reader actually needs to look up is a mapping:
/// «سورهٔ کهف در کدام جزء است؟» (so they can claim the right juz) and «جزء ۱۵
/// شامل چه سوره‌هایی است؟» (so they know what they took on). Both are answerable
/// from the Quran metadata the app already ships, and both are answerable in the
/// result card itself — the juz numbers sit in the body, so no jump is needed.
///
/// The index is built once and reused: it is a pure function of two `const`
/// tables, and rebuilding 114 formatted strings on every keystroke would be
/// work for nothing.
class KhatmSearchIndex {
  KhatmSearchIndex._();

  static List<SectionSearchEntry>? _cache;

  /// One entry per surah.
  static List<SectionSearchEntry> entries() => _cache ??= _build();

  /// The juz numbers a surah spans, in order. Empty when the metadata is
  /// missing that surah — the card then simply omits the line.
  static List<int> juzsOf(int surahNumber) {
    final found = <int>[];
    for (final entry in quran_juzs.juz) {
      final surahs = entry['surahs'];
      if (surahs is List && surahs.contains(surahNumber)) {
        final id = entry['id'];
        if (id is int) found.add(id);
      }
    }
    return found;
  }

  static List<SectionSearchEntry> _build() {
    final out = <SectionSearchEntry>[];
    for (final raw in quran_suwar.surah) {
      final surah = raw as Map;
      final number = surah['id'] as int;
      final arabic = surah['arabic'] as String? ?? '';
      final latin = surah['name'] as String? ?? '';
      final place = surah['place'] == 'Makkah' ? 'مکی' : 'مدنی';
      final verses = surah['aya'] as int? ?? 0;
      final juzs = juzsOf(number);
      final juzText =
          juzs.isEmpty ? '' : ' · جزء ${juzs.map(_faDigits).join('، ')}';
      out.add(SectionSearchEntry(
        title: 'سورهٔ $arabic',
        // The transliteration is searchable too: a reader who types "kahf"
        // should not be told the surah does not exist.
        body: '$latin · $place · ${_faDigits(verses)} آیه$juzText',
      ));
    }
    return out;
  }

  static const List<String> _fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  /// Latin → Persian digits, so the card reads like the rest of the page.
  static String _faDigits(int value) {
    final buffer = StringBuffer();
    for (final unit in value.toString().split('')) {
      final digit = int.tryParse(unit);
      buffer.write(digit == null ? unit : _fa[digit]);
    }
    return buffer.toString();
  }
}
