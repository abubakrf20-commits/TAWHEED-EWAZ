import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';

import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/features/quran/mushaf/quran_kit_row.dart';
import 'package:tawheeed/features/quran/mushaf/quran_paper_chrome.dart';
import 'package:tawheeed/features/quran/mushaf/quran_search_highlight.dart';
import 'package:tawheeed/features/quran/services/quran_search_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// Arabic-text Quran search opened from inside the mushaf header. Uses the
/// same local FTS index as the global search (no internet needed); picking a
/// result navigates back to the mushaf on that page with the verse highlighted.

/// The count line above the results (upgrade wave-1 #5).
///
/// A result list must say how big it is — and when it is truncated: the
/// service's page cap (80) means «the first 80», and presenting that as the
/// whole answer would be a lie to the reader whose query genuinely matches
/// more. Exposed for the screen test.
@visibleForTesting
class SearchResultCountHeader extends StatelessWidget {
  const SearchResultCountHeader({super.key, required this.count, required this.palette});

  final int count;
  final MushafPalette palette;

  static const int _servicePageCap = 80;

  @override
  Widget build(BuildContext context) {
    final label = count >= _servicePageCap
        ? 'نمایش 80 نتیجهٔ نخست — عبارت را دقیق‌تر کنید'
        : '${NumberFormat.normalizeDigits('$count')} نتیجه';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(Icons.format_list_numbered,
              size: 14, color: palette.surfaceMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11.5),
              fontWeight: FontWeight.w600,
              color: palette.surfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
class QuranSearchScreen extends StatefulWidget {
  const QuranSearchScreen({super.key, required this.palette});

  final MushafPalette palette;

  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  final TextEditingController _field = TextEditingController();
  Timer? _debounce;
  List<QuranSearchResult> _results = [];
  bool _searching = false;
  bool _searched = false;

  /// The query that produced [_results] — the highlight must follow the results
  /// on screen, not the field's live text (which runs 250 ms ahead).
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _searched = false;
        _searching = false;
      });
      return Future.value();
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_runSearch(query.trim()));
    });
    return Future.value();
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _searched = true;
      _query = query;
    });
    try {
      // Re-load the verse list if the startup load ever failed; searching
      // never waits on the SQLite/FTS index — that is warmed in the
      // background and search quietly uses the in-memory scan until ready.
      await loadQuranData();
      unawaited(QuranSearchService.prepare());
      final results = QuranSearchService.search(query, limit: 80);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      AppLogger.warning('quran_search_screen', 'operation failed');
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
    }
  }

  void _pick(QuranSearchResult r) {
    Navigator.of(context).pop((r.surah, r.verse));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Scaffold(
      backgroundColor: palette.surface,
      appBar: quranPaperAppBar(
        context,
        palette: palette,
        title: 'جستجو در قرآن',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _field,
              autofocus: true,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                color: palette.surfaceText,
              ),
              decoration: InputDecoration(
                hintText: 'مثلاً: الرحمن',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: palette.surfaceMuted,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _field.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'پاک کردن جستجو',
                        onPressed: () {
                          _field.clear();
                          _onQueryChanged('');
                        },
                      ),
                filled: true,
                fillColor: palette.surface.withValues(alpha: 0.6),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.accent),
                ),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: _runSearch,
            ),
          ),
          Divider(height: 1, color: palette.border),
          Expanded(child: _buildBody(palette)),
        ],
      ),
    );
  }

  Widget _buildBody(MushafPalette palette) {
    if (_searching) {
      // The reader's own ink, like the bookmark list: an untinted spinner is
      // the app theme's accent on a paper it does not own.
      return Center(child: CircularProgressIndicator(color: palette.accent));
    }
    if (!_searched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 44, color: palette.surfaceMuted),
            const SizedBox(height: 12),
            Text(
              'عبارت عربی را بنویسید تا در کل قرآن جستجو شود.\n'
              'حداقل 2 حرف لازم است.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                height: 1.7,
                color: palette.surfaceMuted,
              ),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'نتیجه‌ای برای «${_field.text.trim()}» یافت نشد.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: palette.surfaceMuted,
          ),
        ),
      );
    }
    // The honest scope line (upgrade wave-1 #5): a cap of 80 is the service's
    // page size, and the reader deserves to know when a list is truncated
    // rather than complete.
    return Column(
      children: [
        SearchResultCountHeader(count: _results.length, palette: palette),
        Expanded(child: _buildResultList(palette)),
      ],
    );
  }

  Widget _buildResultList(MushafPalette palette) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        // Same kit row as the rest of the reader: a duotone number tile, the
        // surah identity, the matching verse as the (kept-readable) second
        // line and the page as the trailing chip. The words the reader typed
        // are marked inside that verse line (report §6.5 / §7.1).
        return QuranKitRow(
          palette: palette,
          leading: QuranKitNumberTile(
            accent: palette.accent,
            label: NumberFormat.normalizeDigits('${r.verse}'),
          ),
          title: '${getSurahNameArabic(r.surah)} — ${getSurahName(r.surah)}',
          subtitleRich: buildSearchHighlightSpan(
            text: r.textOriginal,
            query: _query,
            matchColor: palette.accent,
            matchBackground: palette.accent.withValues(alpha: 0.16),
          ),
          subtitleColor: palette.surfaceText.withValues(alpha: 0.85),
          trailing: Text(
            'صفحهٔ ${NumberFormat.normalizeDigits('${r.page}')}',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: palette.surfaceMuted,
            ),
          ),
          onTap: () => _pick(r),
        );
      },
    );
  }
}
