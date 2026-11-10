import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/data/suwar.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_reader_prefs.dart';
import 'package:tawheeed/features/quran/mushaf/quran_kit_row.dart';
import 'package:tawheeed/features/quran/mushaf/quran_paper_chrome.dart';
import 'package:tawheeed/shared/services/daily_content_format.dart';
import 'package:tawheeed/shared/services/daily_verse_source.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/persian_text.dart';

/// Full list of the 114 surahs of the new mushaf reader, with the «آیه روز»
/// banner on top (same verse the daily notification shows).
const Color _cream = Color(0xFFFBF3E7);

class QuranSurahListScreen extends StatefulWidget {
  const QuranSurahListScreen({
    super.key,
    required this.onSelect,
  });

  /// Called with the surah number (1-114) when the user taps a surah.
  final void Function(int surahNumber) onSelect;

  @override
  State<QuranSurahListScreen> createState() => _QuranSurahListScreenState();
}

class _QuranSurahListScreenState extends State<QuranSurahListScreen> {
  /// Same rule the reader uses: the night palette is derived from the chosen
  /// page background, never from a separate day/night switch. The list is
  /// reachable on its own (before the reader loads), so it reads the persisted
  /// colour itself rather than depending on the reader's state.
  MushafPalette _p = MushafPalette.light;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  Future<void> _loadPalette() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Same rule the reader uses, read from the same palette: the night chrome
      // follows the persisted page colour, so this screen agrees with the mushaf
      // even though it can be opened before the reader has ever built. The
      // decision is contrast-based now — a mid-brown paper is dark enough to
      // need the cream ink, and the chrome has to follow the ink.
      final night = mushafNeedsLightInk(
          MushafReaderPrefs.backgroundFrom(prefs, writeBack: false));
      if (mounted) {
        setState(() => _p = night ? MushafPalette.night : MushafPalette.light);
      }
    } catch (e) {
      AppLogger.warning('SurahList', 'background palette read failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final daily = DailyVerseSource.verseForDate(DateTime.now());
    final tail = dailyContentTail(
      text: daily['verse'] ?? '',
      ref: daily['ref'] ?? '',
      trans: daily['trans'] ?? '',
    );

    return Scaffold(
      backgroundColor: _p.background,
      appBar: quranPaperAppBar(
        context,
        palette: _p,
        title: 'فهرست سوره‌ها',
      ),
      body: Column(
        children: [
          // Surah search: matches the Arabic name, the transliterated name
          // or the surah number (Persian or Latin digits).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily, color: _p.surfaceText),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, color: _p.surfaceMuted),
                hintText: 'جستجوی سوره… (نام یا شماره)',
                hintStyle: TextStyle(
                    fontFamily: AppTheme.fontFamily, color: _p.surfaceMuted),
                filled: true,
                fillColor: _p.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _p.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _p.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(builder: (context) {
              final q = NumberFormat.normalizeDigits(_query).toLowerCase();
              final filtered = q.isEmpty
                  ? surah
                  : surah.where((s) {
                      final n = (s['id'] as num?)?.toInt() ?? 0;
                      final arabic = (s['arabic'] as String?) ?? '';
                      final name = (s['name'] as String?) ?? '';
                      return arabic.contains(q) ||
                          name.toLowerCase().contains(q) ||
                          NumberFormat.toLatin('$n').contains(q) ||
                          '$n' == q;
                    }).toList();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _DailyVerseCard(
                      verse: daily['verse'] ?? '',
                      ref: daily['ref'] ?? '',
                      trans: daily['trans'] ?? '',
                      tail: tail,
                    );
                  }
                  final s = filtered[index - 1] as Map;
                  final n = (s['id'] as num?)?.toInt() ?? 0;
                  final page = _startPageFor(n);
                  return _SurahTile(
                    palette: _p,
                    number: n,
                    arabicName: (s['arabic'] as String?) ?? '',
                    translitName: (s['name'] as String?) ?? '',
                    place: (s['place'] as String?) ?? '',
                    verseCount: (s['aya'] as num?)?.toInt() ?? 0,
                    page: page,
                    // Close the list first so tapping a surah lands directly
                    // in the reader — no extra back press needed.
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelect(n);
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Start page for display; the view re-resolves via the API lookup when the
  /// user actually taps (more precise than this static map).
  static int _startPageFor(int surah) {
    try {
      return getPageNumber(surah, 1);
    } catch (e) {
      AppLogger.warning(
          'quran_surah_list_screen', 'start page lookup failed: $e');
      return 1;
    }
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({
    required this.palette,
    required this.number,
    required this.arabicName,
    required this.translitName,
    required this.place,
    required this.verseCount,
    required this.page,
    required this.onTap,
  });

  final MushafPalette palette;
  final int number;
  final String arabicName;
  final String translitName;
  final String place;
  final int verseCount;
  final int page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placeFa = place.toLowerCase() == 'makkah' ? 'مکی' : 'مدنی';
    // The row follows the app's shared list language: a duotone number tile,
    // the Arabic name over its transliteration/place/verse meta, and the start
    // page as the trailing chip. The per-row Card is gone — the kit rows sit
    // flat on the page like Home and «بیشتر», which is what made this screen
    // read as a stack of detached rectangles.
    return QuranKitRow(
      palette: palette,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      leading: QuranKitNumberTile(
        accent: palette.accent,
        label: NumberFormat.normalizeDigits('$number'),
      ),
      title: arabicName,
      subtitle: '$translitName • $placeFa • '
          '${NumberFormat.normalizeDigits('$verseCount')} آیه',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: palette.surfaceText.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'ص ${NumberFormat.normalizeDigits('$page')}',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: palette.surfaceText,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _DailyVerseCard extends StatelessWidget {
  const _DailyVerseCard({
    required this.verse,
    required this.ref,
    required this.trans,
    required this.tail,
  });

  final String verse;
  final String ref;
  final String trans;
  final String tail;

  @override
  Widget build(BuildContext context) {
    // The 2026 design language: the hero card wears the ACTIVE palette's
    // hero gradient (gold, a pinned phase, or the live time-of-day phase)
    // instead of a hard-coded legacy emerald.
    final hero = TimeThemeKit.of(context).palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [hero.heroTop, hero.heroMid, hero.heroBottom],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: _cream, size: 16),
              const SizedBox(width: 6),
              Text(
                'آیه روز',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _cream,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(
                      text: dailyContentBody(
                    text: verse,
                    ref: ref,
                    trans: trans,
                  )));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'آیه کپی شد',
                        style: TextStyle(fontFamily: AppTheme.fontFamily),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Icon(Icons.copy_rounded, color: _cream, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            spacedZwnj(verse),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 21,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: _cream,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Text(
            tail,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: _cream.withValues(alpha: 0.85),
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
