import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/providers/duas_provider.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/dua_detail_screen.dart';
import 'package:tawheeed/features/notes/presentation/providers/notes_provider.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_provider.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/home/presentation/widgets/adhkar_category_page.dart';
import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';
import 'package:tawheeed/features/quran/mushaf/quran_search_highlight.dart';
import 'package:tawheeed/features/quran/services/quran_search_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

enum SearchCategory { all, duas, notes, azkar, quran }

class GlobalSearchDelegate extends SearchDelegate<void> {
  final WidgetRef ref;
  final void Function(int page, {int? highlightSurah, int? highlightVerse})?
      onQuranNavigate;

  /// Sends the user to «بیشتر», whose own field reads inside every section —
  /// the scope this overlay deliberately does not cover.
  final VoidCallback? onMoreNavigate;

  GlobalSearchDelegate(this.ref,
      {this.onQuranNavigate, this.onMoreNavigate});

  static const _categoryLabels = {
    SearchCategory.all: 'همه',
    SearchCategory.duas: 'دعاها',
    SearchCategory.notes: 'یادداشت‌ها',
    SearchCategory.azkar: 'اذکار',
    SearchCategory.quran: 'قرآن',
  };

  static const _categoryIcons = {
    SearchCategory.all: Icons.all_inclusive,
    SearchCategory.duas: Icons.book,
    SearchCategory.notes: Icons.note_alt_outlined,
    SearchCategory.azkar: Icons.wb_sunny_outlined,
    SearchCategory.quran: Icons.auto_stories,
  };

  /// Selected category filter. A [ValueNotifier] instead of a plain field:
  /// [SearchDelegate] only rebuilds when `query` changes, so tapping a chip
  /// used to update the field without repainting — the selection looked dead
  /// until the next keystroke.
  final ValueNotifier<SearchCategory> _category =
      ValueNotifier(SearchCategory.all);

  SearchCategory get _selectedCategory => _category.value;

  // Async search state — keeps the heavy search off the build phase and lets
  // us show a spinner instead of freezing the UI.
  final ValueNotifier<Future<List<_SearchResultItem>>?> _searchNotifier =
      ValueNotifier(null);
  String _activeQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _category.dispose();
    _searchNotifier.dispose();
    super.dispose();
  }

  /// Names the four sources this overlay actually reads. «تمام بخش‌ها» was a
  /// promise it never kept: every other section is searched from «بیشتر».
  @override
  String get searchFieldLabel => 'جستجو در قرآن، دعا، اذکار و یادداشت‌ها';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: t.pageBg,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: t.textMuted),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, size: 20),
          tooltip: 'پاک کردن جستجو',
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, size: 20),
      tooltip: 'بازگشت',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.length < 2) {
      // A cleared/short query must drop the pending debounce AND the
      // `_activeQuery` marker: otherwise typing the same term again after
      // clearing was treated as "already searched" and never ran — and the
      // orphaned timer kept the overlay alive after it closed.
      _debounce?.cancel();
      _activeQuery = '';
      return _buildEmptyHint(context);
    }

    // Debounce: only (re)start a search when the query actually changes.
    if (query != _activeQuery) {
      _activeQuery = query;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        _searchNotifier.value = _runSearch(query);
      });
    }

    return ValueListenableBuilder<Future<List<_SearchResultItem>>?>(
      valueListenable: _searchNotifier,
      builder: (ctx, future, _) {
        if (future == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return FutureBuilder<List<_SearchResultItem>>(
          future: future,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final results = snap.data ?? [];
            if (results.isEmpty) return _buildNoResults(context);
            return _buildResultsList(context, results);
          },
        );
      },
    );
  }

  /// Switches the active category and re-runs an in-flight query at once.
  void _selectCategory(SearchCategory cat) {
    _category.value = cat;
    if (query.length >= 2) {
      // Re-run immediately when a category is chosen mid-search.
      _searchNotifier.value = _runSearch(query);
    }
  }

  /// The category chips, rebuilt from [_category] so a tap repaints
  /// immediately (shared by the empty hint and the results header).
  Widget _buildCategoryChips() {
    return ValueListenableBuilder<SearchCategory>(
      valueListenable: _category,
      builder: (ctx, selected, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SearchCategory.values.map((cat) {
            return FilterChip(
              avatar: Icon(_categoryIcons[cat] ?? Icons.search, size: 16),
              label: Text(_categoryLabels[cat] ?? ''),
              selected: cat == selected,
              onSelected: (_) => _selectCategory(cat),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<_SearchResultItem>> _runSearch(String rawQuery) async {
    // Digit-fold the query: content is stored with Latin digits (product
    // standard), but a Persian-keyboard user types «۱۲۳» without thinking.
    final q = toAsciiDigits(rawQuery.trim().toLowerCase());
    final results = <_SearchResultItem>[];
    if (q.isEmpty) return results;
    final qNorm = _normalizeArabic(q);

    final searchQuran = _selectedCategory == SearchCategory.all ||
        _selectedCategory == SearchCategory.quran;
    final searchDuas = _selectedCategory == SearchCategory.all ||
        _selectedCategory == SearchCategory.duas;
    final searchNotes = _selectedCategory == SearchCategory.all ||
        _selectedCategory == SearchCategory.notes;
    final searchAzkar = _selectedCategory == SearchCategory.all ||
        _selectedCategory == SearchCategory.azkar;

    if (searchQuran) {
      try {
        // Re-load the verse list if the startup load ever failed; searching
        // never waits on the SQLite/FTS index — warmed in the background,
        // results come from the in-memory scan until it's ready.
        await loadQuranData();
        unawaited(QuranSearchService.prepare());
        final quranResults =
            QuranSearchService.search(rawQuery.trim(), limit: 10);
        for (final r in quranResults) {
          results.add(_SearchResultItem(
            category: SearchCategory.quran,
            title: '${getSurahNameArabic(r.surah)} (آیه ${r.verse})',
            subtitle: _snippet(r.textOriginal),
            icon: _categoryIcons[SearchCategory.quran] ?? Icons.search,
            quranPage: r.page,
            quranSurah: r.surah,
            quranVerse: r.verse,
          ));
        }
      } catch (e) {
        AppLogger.warning('GlobalSearch', 'Quran search failed: $e');
      }
    }

    if (searchDuas) {
      try {
        final duas = ref.read(duasProvider).duas;
        var hay = _duasHay;
        if (hay == null || !identical(duas, _duasSrc)) {
          _duasSrc = duas;
          hay = [
            for (final d in duas)
              _normalizeArabic('${d.title}\n${d.arabicText}\n${d.translation}')
          ];
          _duasHay = hay;
        }
        var taken = 0;
        for (var i = 0; i < duas.length && taken < 10; i++) {
          if (!hay[i].contains(qNorm)) continue;
          final d = duas[i];
          taken++;
          results.add(_SearchResultItem(
            category: SearchCategory.duas,
            title: d.title,
            subtitle: _snippet(d.translation),
            icon: _categoryIcons[SearchCategory.duas] ?? Icons.search,
            dua: d,
          ));
        }
      } catch (e) {
        AppLogger.warning('GlobalSearch', 'Duas search failed: $e');
      }
    }

    if (searchNotes) {
      try {
        // Await the load: reading `.value` missed every note when the
        // provider had not finished loading at search time.
        final notes = await ref.read(notesProvider.future);
        var hay = _notesHay;
        if (hay == null || !identical(notes, _notesSrc)) {
          _notesSrc = notes;
          hay = [
            for (final n in notes)
              _normalizeArabic('${n.title}\n${n.content}')
          ];
          _notesHay = hay;
        }
        var taken = 0;
        for (var i = 0; i < notes.length && taken < 10; i++) {
          if (!hay[i].contains(qNorm)) continue;
          final n = notes[i];
          taken++;
          results.add(_SearchResultItem(
            category: SearchCategory.notes,
            title: n.title,
            subtitle: _snippet(n.content),
            icon: _categoryIcons[SearchCategory.notes] ?? Icons.search,
            note: n,
          ));
        }
      } catch (e) {
        AppLogger.warning('GlobalSearch', 'Notes search failed: $e');
      }
    }

    if (searchAzkar) {
      try {
        final azkar = await ref.read(azkarProvider.future);
        var hay = _azkarHay;
        if (hay == null || !identical(azkar, _azkarSrc)) {
          _azkarSrc = azkar;
          hay = [
            for (final z in azkar)
              _normalizeArabic(
                  '${z.title}\n${z.arabicText}\n${z.translation}\n'
                  '${z.source}\n${z.daleel}')
          ];
          _azkarHay = hay;
        }
        var taken = 0;
        for (var i = 0; i < azkar.length && taken < 10; i++) {
          if (!hay[i].contains(qNorm)) continue;
          final z = azkar[i];
          taken++;
          results.add(_SearchResultItem(
            category: SearchCategory.azkar,
            title: z.title,
            subtitle: _snippet(z.arabicText),
            icon: _categoryIcons[SearchCategory.azkar] ?? Icons.search,
            zikr: z,
          ));
        }
      } catch (e) {
        AppLogger.warning('GlobalSearch', 'Azkar search failed: $e');
      }
    }

    return results;
  }

  /// Single canonical normalizer for every runtime-built search pair in this
  /// delegate (see shared/utils/arabic_search.dart). Precomputed-DB pairs
  /// (Quran FTS, fatwa search_norm) keep their own build-time functions.
  static String _normalizeArabic(String s) => normalizeForSearch(s);

  /// The literal to paint on the destination screen: the first field where the
  /// typed query occurs under [TextHighlight]'s narrower normalizer. The search
  /// itself runs on [normalizeForSearch] (digit/ZWNJ/whitespace folds), so a
  /// query that only matched through those folds finds no literal here and the
  /// destination opens unpainted rather than mis-painting an unrelated word.
  static String _literalFor(List<String> fields, String query) {
    final q = toAsciiDigits(query.trim());
    if (q.isEmpty) return '';
    for (final field in fields) {
      if (field.trim().isEmpty) continue;
      final literal = TextHighlight.literalMatch(field, q);
      if (literal.isNotEmpty) return literal;
    }
    return '';
  }

  // Normalized search haystacks per category, keyed by list identity: the
  // providers hand back a fresh list whenever content changes, so per-keystroke
  // scans only pay for `contains`, not for re-normalizing every field of every
  // item on the UI isolate.
  static List<DuaModel>? _duasSrc;
  static List<String>? _duasHay;
  static List<NoteTableData>? _notesSrc;
  static List<String>? _notesHay;
  static List<ZikrItem>? _azkarSrc;
  static List<String>? _azkarHay;

  /// Truncates to [max] code units without splitting a surrogate pair.
  static String _snippet(String s, {int max = 80}) {
    if (s.length <= max) return s;
    var cut = max;
    final prev = s.codeUnitAt(cut - 1);
    if (prev >= 0xD800 && prev <= 0xDBFF) cut--;
    return '${s.substring(0, cut)}...';
  }

  Widget _buildEmptyHint(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: t.textMuted),
            const SizedBox(height: 16),
            Text('حداقل 2 حرف وارد کنید',
                style: TextStyle(color: t.textMuted)),
            const SizedBox(height: 24),
            _buildCategoryChips(),
            const SizedBox(height: 24),
            _buildScopeFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: t.textMuted),
            const SizedBox(height: 16),
            Text('نتیجه‌ای برای «$query» یافت نشد',
                style: TextStyle(color: t.textMuted)),
            const SizedBox(height: 12),
            _buildScopeFooter(context),
          ],
        ),
      ),
    );
  }

  /// The honest scope line plus the door to the wider search: a miss in these
  /// four sources is not a miss in the app.
  Widget _buildScopeFooter(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'این جستجو قرآن، دعاها، اذکار و یادداشت‌ها را می‌گردد.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: t.textMuted,
          ),
        ),
        if (onMoreNavigate != null) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              close(context, null);
              onMoreNavigate!.call();
            },
            icon: const Icon(Icons.travel_explore, size: 18),
            label: const Text('جستجو در همهٔ بخش‌ها'),
          ),
        ],
      ],
    );
  }

  /// The row's subtitle span. Quran verses mark the words the reader typed —
  /// the quran search screen marks the same words inside the reader, so both
  /// surfaces agree (upgrade report wave-1 #1). Every other category keeps its
  /// plain snippet.
  InlineSpan _resultSubtitle(BuildContext context, _SearchResultItem r) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (r.category == SearchCategory.quran && query.trim().length >= 2) {
      final accent = isDark ? t.primary : t.tertiary;
      return buildSearchHighlightSpan(
        text: r.subtitle,
        query: query,
        matchColor: accent,
        matchBackground: accent.withValues(alpha: 0.16),
      );
    }
    return TextSpan(text: r.subtitle);
  }

  Widget _buildResultsList(
      BuildContext context, List<_SearchResultItem> results) {
    final t = TimeThemeKit.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final grouped = <SearchCategory, List<_SearchResultItem>>{};
    for (final r in results) {
      grouped.putIfAbsent(r.category, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DsSpacing.page, 0, DsSpacing.page, 4),
          child: _buildCategoryChips(),
        ),
        ...grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DsSpacing.page, 12, DsSpacing.page, 4),
                child: Row(
                  children: [
                    Icon(_categoryIcons[entry.key] ?? Icons.search,
                        size: 16,
                        color: isDark ? t.primary : t.tertiary),
                    const SizedBox(width: 6),
                    Text(_categoryLabels[entry.key] ?? '',
                        style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: isDark ? t.primary : t.tertiary,
                        )),
                  ],
                ),
              ),
              ...entry.value.map((r) => ListTile(
                    dense: true,
                    leading: Icon(r.icon,
                        size: 20,
                        color: isDark ? t.primary : t.tertiary),
                    title: Text(r.title,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 14))),
                    subtitle: r.subtitle.isNotEmpty
                        ? Text.rich(
                            _resultSubtitle(context, r),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: t.textMuted))
                        : null,
                    onTap: () {
                      if (r.category == SearchCategory.quran &&
                          r.quranPage != null) {
                        close(context, null);
                        onQuranNavigate?.call(
                          r.quranPage!,
                          highlightSurah: r.quranSurah,
                          highlightVerse: r.quranVerse,
                        );
                      } else if (r.category == SearchCategory.duas &&
                          r.dua != null) {
                        // Capture the navigator BEFORE close(): the delegate's
                        // context is deactivated by close() and pushing with
                        // it afterwards is a latent crash.
                        final navigator = Navigator.of(context);
                        final literal = _literalFor(
                          [r.dua!.arabicText, r.dua!.translation, r.dua!.title],
                          query,
                        );
                        close(context, null);
                        navigator.push(MaterialPageRoute(
                          builder: (_) => DuaDetailScreen(
                            dua: r.dua!,
                            highlightQuery: literal,
                          ),
                        ));
                      } else if (r.category == SearchCategory.notes &&
                          r.note != null) {
                        final router = GoRouter.of(context);
                        final literal = _literalFor(
                          [r.note!.content, r.note!.title],
                          query,
                        );
                        close(context, null);
                        router.push(
                          literal.isEmpty
                              ? RouteNames.noteEditor
                              : '${RouteNames.noteEditor}'
                                  '?q=${Uri.encodeQueryComponent(literal)}',
                          extra: r.note,
                        );
                      } else if (r.category == SearchCategory.azkar &&
                          r.zikr != null) {
                        // The azkar tab itself lists tasbih models, so the hit
                        // opens its own period page (the home timeline's
                        // destination) where the card can be painted.
                        final router = GoRouter.of(context);
                        final z = r.zikr!;
                        final literal = _literalFor([
                          z.arabicText,
                          z.translation,
                          z.title,
                          z.virtue,
                          z.source,
                          z.daleel,
                        ], query);
                        final all =
                            ref.read(azkarProvider).value ?? const <ZikrItem>[];
                        final periodItems = all
                            .where((e) => e.period == z.period)
                            .toList(growable: false);
                        close(context, null);
                        router.push(
                          RouteNames.azkarCategory,
                          extra: AdhkarCategoryArgs(
                            title: z.period.label,
                            period: z.period,
                            items: periodItems.isEmpty ? [z] : periodItems,
                            focusId: z.id,
                            highlightQuery: literal,
                          ),
                        );
                      }
                    },
                  )),
            ],
          );
        }),
      ],
    );
  }
}

class _SearchResultItem {
  final SearchCategory category;
  final String title;
  final String subtitle;
  final IconData icon;

  final int? quranPage;
  final int? quranSurah;
  final int? quranVerse;
  final DuaModel? dua;
  final NoteTableData? note;
  final ZikrItem? zikr;

  const _SearchResultItem({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.quranPage,
    this.quranSurah,
    this.quranVerse,
    this.dua,
    this.note,
    this.zikr,
  });
}
