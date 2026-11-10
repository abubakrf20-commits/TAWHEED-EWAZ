import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/core/database/app_database.dart' show NoteTableData;
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import 'package:tawheeed/features/adhkar/duas/presentation/screens/dua_detail_screen.dart';
import 'package:tawheeed/features/books/data/models/book_model.dart';
import 'package:tawheeed/features/books/presentation/providers/book_provider.dart';
import 'package:tawheeed/features/books/presentation/screens/book_reader_screen.dart';
import 'package:tawheeed/features/hadith/presentation/screens/hadith_books_screen.dart';
import 'package:tawheeed/features/hadith/services/hadith_books_service.dart';
import 'package:tawheeed/features/maalim/presentation/screens/maalim_chapter_screen.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_chapter_screen.dart';
import 'package:tawheeed/features/search/presentation/screens/content_hit_reader_screen.dart';
import 'package:tawheeed/features/search/services/content_hit.dart';
import 'package:tawheeed/features/search/services/content_targets.dart';
import 'package:tawheeed/features/search/services/more_content_search.dart';
import 'package:tawheeed/features/settings/presentation/more/more_duotone.dart';
import 'package:tawheeed/features/settings/presentation/more/more_registry.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_chapter_screen.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';
import 'package:tawheeed/shared/widgets/in_app_browser_screen.dart';

/// Routes unlocked with their password during the current app session.
/// The «تثبیت یقین» content is still under construction — gated behind a
/// simple password so early users cannot open it before it is published.
final Set<String> _unlockedMoreRoutes = {};

/// Bumped every time a locked route is unlocked. It is baked into the cached
/// [_GroupArea] instances so returning from an unlocked section — which
/// rebuilds this screen with unchanged search state — still re-evaluates the
/// lock badges instead of reusing the identical pre-unlock group widgets.
int _lockEpoch = 0;

/// ═══════════════════════════════════════════════════════════════
/// MoreScreen — «بیشتر»
/// A categorized launcher for all secondary features.
///
/// Single source of truth: the sections, the section counts, the search
/// haystack and the tests all read `more_registry.dart`, so an item cannot
/// exist in one place and be missing in another.
///
/// The search field answers in two layers: the tiles that match the words the
/// user typed, and — below them — the text found INSIDE the sections by
/// `more_content_search.dart`, grouped under the tile that owns each hit.
///
/// Design («Style 2» flat duotone): every tile is an accent-tinted squircle
/// with a corner dot — ALL colors are flat alpha tints derived from the item's
/// fixed topic hue (`MoreDuotone`); no gradients, no white borders, no
/// shadows. Tiles sit in white group cards; the section header's gold bar is
/// for grouping only.
///
/// Performance (low-end Android): no blur, no shadows and no `Opacity` — every
/// tint is a color alpha; the per-second countdown is the only thing inside
/// its own RepaintBoundary. The search state lives on a `ValueNotifier` read
/// only by `_SearchResultsArea`, so a keystroke repaints the results and only
/// the group blocks whose items actually changed — never the page, the strip
/// or an unchanged grid. The content index is built once per process and runs
/// off the build phase.
/// ═══════════════════════════════════════════════════════════════
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key, @visibleForTesting this.contentSources});

  /// Test seam for the deep search: `null` — every real screen — consults the
  /// shipped `kMoreContentSources`; a widget test hands in fakes so the content
  /// layer is deterministic instead of waiting on assets and databases.
  @visibleForTesting
  final List<MoreContentSource>? contentSources;

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

/// One immutable snapshot of the search state: the query, whether the
/// expensive scans are still running, and the hits found so far.
///
/// It lives on a [ValueNotifier] instead of the screen's fields so a
/// keystroke repaints only the results area — the page chrome, the section
/// tiles and the strip never rebuild for search state. `hits` is compared by
/// identity (a fresh list from a landed wave is a new state), so a re-published
/// equal query — 'وضو ' refining to the already-typed 'وضو' — is the same
/// state and skips the results build entirely.
class _MoreSearchState {
  const _MoreSearchState({
    this.query = '',
    this.rawQuery = '',
    this.hits = const [],
    this.searchingContent = false,
  });

  /// Already-normalized query ('' shows everything).
  final String query;

  /// What the user actually typed — the content index uses it to place the
  /// snippet window, the normalized [query] only to match.
  final String rawQuery;

  /// Hits inside the sections' own text, in source order.
  final List<ContentHit> hits;

  /// True while a search wave is still running for the current query.
  final bool searchingContent;

  bool get searching => moreContentQueryIsSearchable(query) && searchingContent;

  static const Object _unset = Object();

  _MoreSearchState copyWith({
    Object? query = _unset,
    Object? rawQuery = _unset,
    Object? hits = _unset,
    Object? searchingContent = _unset,
  }) {
    return _MoreSearchState(
      query: query == _unset ? this.query : query as String,
      rawQuery: rawQuery == _unset ? this.rawQuery : rawQuery as String,
      hits: hits == _unset ? this.hits : hits as List<ContentHit>,
      searchingContent: searchingContent == _unset
          ? this.searchingContent
          : searchingContent as bool,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _MoreSearchState &&
        other.query == query &&
        other.rawQuery == rawQuery &&
        other.searchingContent == searchingContent &&
        identical(other.hits, hits);
  }

  @override
  int get hashCode =>
      Object.hash(query, rawQuery, searchingContent, identityHashCode(hits));
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  /// The single holder of search state. The page build never reads it —
  /// [_SearchResultsArea] listens — so a keystroke repaints the results, not
  /// the page.
  final ValueNotifier<_MoreSearchState> _search =
      ValueNotifier(const _MoreSearchState());

  /// Bumped by every search and every edit: a response older than the current
  /// generation belongs to a query the user has already replaced.
  int _contentGeneration = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Debounced: filtering lays out the filtered group grids, so a fast typist
  /// should pay for one keystroke, not for ten.
  void _onSearchChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final trimmed = raw.trim();
      final query = normalizeMoreText(trimmed);
      _search.value = _search.value.copyWith(query: query, rawQuery: trimmed);
      _searchSectionContent(query, trimmed);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    _contentGeneration++;
    if (!mounted) return;
    _search.value = const _MoreSearchState();
  }

  /// Asks every content section for its own text matches. Two waves: what is
  /// already in memory answers first (so those rows appear while the expensive
  /// scans — کتابخانه decompresses whole books — are still running), then the
  /// deferred wave is folded in and the progress ring stops.
  ///
  /// Off the build phase and generation-checked, so a slow section can never
  /// land its answer on top of a newer query's. While a wave runs the OLD hits
  /// stay published under the new query, exactly as before.
  void _searchSectionContent(String query, String raw) {
    final generation = ++_contentGeneration;
    if (!moreContentQueryIsSearchable(query)) {
      if (!mounted) return;
      _search.value = _search.value.copyWith(
        hits: const <ContentHit>[],
        searchingContent: false,
      );
      return;
    }
    if (!mounted) return;
    _search.value = _search.value.copyWith(searchingContent: true);
    unawaited(_runSearch(query, raw, generation));
  }

  Future<void> _runSearch(String query, String raw, int generation) async {
    Future<List<ContentHit>> wave(MoreSearchPhase phase) =>
        searchMoreContent(
          query: query,
          rawQuery: raw,
          ref: ref,
          sources: widget.contentSources,
          phase: phase,
        ).catchError((Object e) {
          AppLogger.warning('MoreScreen', 'section content search failed: $e');
          return const <ContentHit>[];
        });

    final fast = await wave(MoreSearchPhase.fast);
    if (!mounted || generation != _contentGeneration) return;
    _search.value = _search.value.copyWith(hits: fast);

    final deferred = await wave(MoreSearchPhase.deferred);
    if (!mounted || generation != _contentGeneration) return;
    _search.value = _search.value.copyWith(
      hits: [...fast, ...deferred],
      searchingContent: false,
    );
  }

  /// Opens where a content hit really lives AND carries the matched word there,
  /// so the destination paints it: a hadith chapter jumps to the carrying entry
  /// (`initialHadithNumber`/`initialQuery`), a library hit opens the reader on
  /// the carrying page, the encyclopedia and حصن screens take the literal, and
  /// the sections with no per-item route open the hit's own block.
  void _openHit(ContentHit hit) {
    final target = hit.target;
    if (target is HadithChapterTarget) {
      if (target.itemId == 'maalim') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MaalimChapterScreen(
            chapterIndex: target.chapterIndex,
            chapterTitle: target.chapterTitle,
            initialHadithNumber: target.hadithNumber,
            initialQuery: hit.highlightQuery,
          ),
        ));
        return;
      }
      if (target.itemId == 'taraghib') {
        final bookId = target.bookId;
        if (bookId != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaraghibChapterScreen(
              bookId: bookId,
              chapterIndex: target.chapterIndex,
              chapterTitle: target.chapterTitle,
              initialHadithNumber: target.hadithNumber,
              initialQuery: hit.highlightQuery,
            ),
          ));
          return;
        }
        // `chapter_index` restarts in every book, so a taraghib hit without a
        // book id cannot address a chapter; fall through to the hit's own
        // block below, which still paints the matched word.
      } else {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RiyadChapterScreen(
            chapterIndex: target.chapterIndex,
            chapterTitle: target.chapterTitle,
            initialHadithNumber: target.hadithNumber,
            initialQuery: hit.highlightQuery,
          ),
        ));
        return;
      }
    }
    if (target is HadithBookEntryTarget) {
      final meta = HadithBooksService.metaForDbId(target.bookDbId);
      if (meta != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AmbientBackground(
            child: HadithChapterScreen(
              bookMeta: meta,
              bookId: target.bookDbId,
              chapter: HadithChapter(
                id: target.chapterIndex,
                bookId: target.bookDbId,
                arabic: target.chapterTitle,
              ),
              initialHadithNumber: target.hadithNumber,
              initialQuery: hit.highlightQuery,
            ),
          ),
        ));
        return;
      }
      // An unknown book id falls through to the hit's own block below, which
      // still paints the matched word.
    }
    if (target is BookPageTarget) {
      _openBookPage(target, hit.highlightQuery);
      return;
    }
    final entity = hit.entity;
    if (entity is NoteTableData) {
      final query = hit.highlightQuery.trim();
      context.push(
        query.isEmpty
            ? RouteNames.noteEditor
            : '${RouteNames.noteEditor}?q=${Uri.encodeQueryComponent(query)}',
        extra: entity,
      );
      return;
    }
    if (entity is DuaModel) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DuaDetailScreen(
          dua: entity,
          highlightQuery: hit.highlightQuery,
        ),
      ));
      return;
    }
    if (entity is int) {
      final query = hit.highlightQuery.trim();
      context.push(query.isEmpty
          ? RouteNames.hadeethEncDetailPath(entity)
          : '${RouteNames.hadeethEncDetailPath(entity)}'
              '?q=${Uri.encodeQueryComponent(query)}');
      return;
    }
    final owner = moreItemById(hit.itemId);
    if (owner == null) return;
    // No per-item route: show the exact block the match was found in, with the
    // word painted, and keep the owning section one tap away.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ContentHitReaderScreen(
        hit: hit,
        sectionTitle: owner.title,
        sectionIcon: owner.icon,
        accent: owner.accent,
        onOpenSection: () => _openMoreItem(context, owner),
      ),
    ));
  }

  /// Opens the library book at the page that carries the match. The reader
  /// takes a whole [BookModel], so the catalog row is copied with the hit page
  /// as its start — the shared provider instance is never mutated, and the
  /// reader's own progress save keeps the library in step on the way out.
  void _openBookPage(BookPageTarget target, String query) {
    final known = (ref.read(bookProvider).value ?? [])
        .where((b) => b.id == target.bookId)
        .firstOrNull;
    final fallbackTitle =
        target.bookTitle.isNotEmpty ? target.bookTitle : 'کتاب';
    final knownTitle = known?.title ?? '';
    final book = BookModel(
      id: target.bookId,
      title: knownTitle.isNotEmpty ? knownTitle : fallbackTitle,
      author: known?.author ?? '',
      category: known?.category ?? '',
      pageCount: known?.pageCount ?? 0,
      currentPage: target.pageIndex,
      isFavorite: known?.isFavorite ?? false,
      language: known?.language ?? 'fa',
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookReaderScreen(book: book, initialQuery: query),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // The page chrome is rendered ONCE — search state lives on the [_search]
    // notifier and is read only by [_SearchResultsArea], so a keystroke
    // repaints the results, not the page.
    return SectionShell.list(
      title: 'بیشتر',
      // No AppBar: the slim page header rides the ListView (user request,
      // 2026-10-14), so it scrolls away with the content. The page gutter
      // lives on the list, which is why the header's own inset is vertical.
      headerPadding: const EdgeInsets.only(bottom: DsSpacing.gap),
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, DsSpacing.gap, DsSpacing.page, 32),
      children: [
        const _MorePrayerStrip(),
        const SizedBox(height: DsSpacing.gap),
        _SearchField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          onClear: _clearSearch,
        ),
        const SizedBox(height: 14),
        _SearchResultsArea(
          search: _search,
          onOpenHit: _openHit,
          lockEpoch: _lockEpoch,
        ),
      ],
    );
  }
}

/// The only stateful consumer of search state. It paints everything below
/// the search field — the matching group blocks, the spinner while the
/// expensive scans run, and the hits found inside the sections — and it is
/// the REBUILD SCOPE of a keystroke: the page chrome above it never rebuilds
/// for search state, and the blocks below it skip whenever nothing visible
/// changed (see [_SearchResultsAreaState._groupWidgets]).
class _SearchResultsArea extends StatefulWidget {
  const _SearchResultsArea({
    required this.search,
    required this.onOpenHit,
    required this.lockEpoch,
  });

  final ValueNotifier<_MoreSearchState> search;
  final void Function(ContentHit hit) onOpenHit;

  /// Bumped on every unlock; baked into the group blocks so an unlock still
  /// repaints the lock badges.
  final int lockEpoch;

  @override
  State<_SearchResultsArea> createState() => _SearchResultsAreaState();
}

class _SearchResultsAreaState extends State<_SearchResultsArea> {
  late _MoreSearchState _state = widget.search.value;
  late int _lockEpoch = widget.lockEpoch;

  /// Cached block instances. `Widget.==` is non-virtual identity and
  /// [Element.updateChild]'s fast path (`child.widget == newWidget`) needs
  /// the SAME instance to skip a subtree — a fresh-but-equal widget always
  /// rebuilds. So each keystroke re-emits the cached instance for every block
  /// whose membership is unchanged, and only blocks whose items actually
  /// changed get a new instance and repaint. The group is the block's key, so
  /// when blocks shift position the keyed children are matched by key, not by
  /// slot — a surviving block keeps its element (and its skip) even when the
  /// group before it disappears.
  final Map<MoreGroup, _GroupArea> _groupWidgets = {};
  _HitsArea? _hitsWidget;

  @override
  void initState() {
    super.initState();
    widget.search.addListener(_onSearch);
  }

  @override
  void didUpdateWidget(covariant _SearchResultsArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.search, widget.search)) {
      oldWidget.search.removeListener(_onSearch);
      widget.search.addListener(_onSearch);
    }
    // No setState: a widget update always rebuilds, and the forced rebuild
    // after this callback is what re-reads the new epoch. Returning from an
    // unlocked section lands here with unchanged search state but a moved
    // epoch.
    _lockEpoch = widget.lockEpoch;
  }

  void _onSearch() {
    if (!mounted) return;
    setState(() => _state = widget.search.value);
  }

  @override
  void dispose() {
    widget.search.removeListener(_onSearch);
    super.dispose();
  }

  /// The registry items and the hits are fresh lists of shared instances —
  /// identity per member is the exact "did the content change" test.
  static bool _sameMembers<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final searching = s.searching;
    final hits = s.hits;

    final blocks = <_GroupArea>[];
    var anyGroup = false;
    for (final group in kMoreGroupOrder) {
      final items = moreItemsIn(group, s.query);
      if (items.isEmpty) {
        _groupWidgets.remove(group);
        continue;
      }
      anyGroup = true;
      var area = _groupWidgets[group];
      if (area == null ||
          area.lockEpoch != _lockEpoch ||
          !_sameMembers(area.items, items)) {
        area = _GroupArea(
          key: ValueKey<MoreGroup>(group),
          group: group,
          items: items,
          lockEpoch: _lockEpoch,
        );
        _groupWidgets[group] = area;
      }
      blocks.add(area);
    }

    if (!anyGroup && hits.isEmpty && !searching) {
      return const _MoreEmptyState();
    }

    _HitsArea? hitsBlock;
    if (hits.isEmpty) {
      _hitsWidget = null;
    } else {
      final cached = _hitsWidget;
      if (cached == null ||
          cached.searching != searching ||
          !_sameMembers(cached.hits, hits)) {
        _hitsWidget = _HitsArea(
          hits: hits,
          searching: searching,
          onOpenHit: widget.onOpenHit,
        );
      }
      hitsBlock = _hitsWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...blocks,
        if (searching && hits.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (hitsBlock != null) hitsBlock,
      ],
    );
  }
}

/// One section block: the header + the tile grid (or the app rows list).
///
/// Never rebuilt directly for search state: [_SearchResultsAreaState]
/// re-emits the SAME instance while the group's membership and the lock epoch
/// are unchanged, and the framework's identity fast path skips the whole
/// subtree — the tiles included. A new instance (membership changed, or the
/// epoch moved after an unlock) is what repaints it.
class _GroupArea extends StatelessWidget {
  const _GroupArea({
    super.key,
    required this.group,
    required this.items,
    required this.lockEpoch,
  });

  final MoreGroup group;
  final List<MoreItem> items;
  final int lockEpoch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: group.title,
          count: '${items.length}',
          margin: const EdgeInsets.only(bottom: 8),
        ),
        if (group == MoreGroup.app)
          _UtilityList(items: items)
        else
          AppCard(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
            child: _Style2Grid(items: items),
          ),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// The «در متن بخش‌ها» block: the hits found inside the sections' own text.
///
/// Instance-cached like the group blocks — a landed search wave produces
/// fresh hit instances, so a landed wave repaints; an unchanged state
/// re-emits the same instance and the block skips.
class _HitsArea extends StatelessWidget {
  const _HitsArea({
    required this.hits,
    required this.searching,
    required this.onOpenHit,
  });

  final List<ContentHit> hits;
  final bool searching;
  final void Function(ContentHit hit) onOpenHit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'در متن بخش‌ها',
          count: '${hits.length}',
          margin: const EdgeInsets.only(bottom: 8),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          // The card paints its own background, so the rows need a
          // transparent Material of their own to ripple on.
          child: Material(
            type: MaterialType.transparency,
            child: _ContentHitList(hits: hits, onOpen: onOpenHit),
          ),
        ),
        // The deferred wave (کتابخانه's whole-library scan) is still
        // running: the rows already found stay readable while it does.
        if (searching)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NAVIGATION — one switch for all four kinds of destination
// ═══════════════════════════════════════════════════════════════

/// True while [item] still needs its session password.
bool _isLocked(MoreItem item) =>
    item.isLocked && !_unlockedMoreRoutes.contains(item.destination);

void _openMoreItem(BuildContext context, MoreItem item) {
  switch (item.kind) {
    case MoreKind.route:
      context.push(item.destination);
    case MoreKind.web:
      context.push(
        RouteNames.inAppBrowser,
        extra: InAppBrowserArgs(title: item.title, url: item.destination),
      );
    case MoreKind.audioCategory:
      context.push('${RouteNames.audioLibrary}?cat=${item.destination}');
    case MoreKind.lockedRoute:
      if (_isLocked(item)) {
        _showLockDialog(context, item);
      } else {
        context.push(item.destination);
      }
  }
}

/// Prompts for the temporary unlock password of a locked item and opens the
/// route after a correct entry. Wrong attempts show an inline error.
Future<void> _showLockDialog(BuildContext context, MoreItem item) {
  final ctrl = TextEditingController();
  var error = '';
  return showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (dialogCtx, setState) {
          void submit() {
            setState(() {});
            if (ctrl.text.trim() == item.lockCode) {
              // Persist for the session so the user is not asked again.
              _unlockedMoreRoutes.add(item.destination);
              _lockEpoch++;
              Navigator.of(dialogCtx).pop();
              context.push(item.destination);
            } else {
              setState(() => error = 'رمز اشتباه است؛ دوباره تلاش کنید.');
              ctrl.clear();
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: item.accent),
                const SizedBox(width: 8),
                Text('بخش قفل‌شده',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '«${item.title}» هنوز در حال تکمیل است و فقط با رمز قابل دسترسی است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(dialogCtx, 13),
                    color: TimeThemeKit.of(dialogCtx).palette.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    hintText: 'رمز را وارد کنید',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(dialogCtx, 12),
                        color: Theme.of(dialogCtx).colorScheme.error),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: submit,
                style: FilledButton.styleFrom(
                    backgroundColor: item.accent,
                    foregroundColor: Colors.white),
                child: const Text('ورود'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    // Deferred one frame: the dialog route disposes its TextField in this
    // frame's finalizeTree — disposing earlier races with it.
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  });
}

// ═══════════════════════════════════════════════════════════════
// SLIM HERO STRIP — next prayer + live countdown on the hero gradient
// ═══════════════════════════════════════════════════════════════

class _MorePrayerStrip extends ConsumerStatefulWidget {
  const _MorePrayerStrip();

  @override
  ConsumerState<_MorePrayerStrip> createState() => _MorePrayerStripState();
}

class _MorePrayerStripState extends ConsumerState<_MorePrayerStrip> {
  ValueListenable<TickerModeData>? _tickerModeNotifier;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    // The shared ClockTicker runs app-wide; the per-second countdown below
    // only subscribes while this tab is visible (same contract as the hero).
    _tickerModeNotifier = TickerMode.getValuesNotifier(context);
    _tickerModeNotifier?.addListener(_onTickerModeChanged);
    _active = _tickerModeNotifier?.value.enabled ?? true;
  }

  void _onTickerModeChanged() {
    final active = _tickerModeNotifier?.value.enabled ?? true;
    if (active == _active || !mounted) return;
    setState(() => _active = active);
  }

  @override
  void dispose() {
    _tickerModeNotifier?.removeListener(_onTickerModeChanged);
    super.dispose();
  }

  /// The strip is a shortcut to the prayer tab, not another detail page.
  void _goHome() => ref.read(shellTabIndexProvider.notifier).setIndex(0);

  @override
  Widget build(BuildContext context) {
    final ticker = ref.watch(clockTickerProvider);
    final clock = ref.watch(prayerClockProvider);
    final use12Hour = ref.watch(use12HourProvider);
    final lite = ref.watch(liteModeProvider).value ?? false;

    return HeroCardShell(
      lite: lite,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // A-02: minHeight, not a fixed 48 — at text scale 1.333 the adhan/iqamah
      // line needs a second row, and a fixed height truncated it with «…».
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: clock == null
            ? const SizedBox.shrink()
            : ValueListenableBuilder<PrayerSnapshot>(
                valueListenable: clock,
                builder: (context, snap, _) => Semantics(
                  button: true,
                  label: 'رفتن به خانه',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _goHome,
                    // Layout constraints, not MediaQuery: the strip's real
                    // width is what the countdown must fit into.
                    child: LayoutBuilder(
                      builder: (context, strip) => Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: .08),
                              border: Border.all(
                                color:
                                    AppPalette.heroGold.withValues(alpha: .55),
                                width: 1.25,
                              ),
                            ),
                            child: Icon(_iconFor(snap.nextId),
                                size: 18, color: AppPalette.heroGold),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  snap.nextId.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w500,
                                    color: AppPalette.cream,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Both times stay readable at every text scale:
                                // the strip grows instead of cutting the line,
                                // and the non-breaking spaces keep each label
                                // attached to its time when it wraps.
                                Text(
                                  _timeLine(snap, use12Hour),
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 11),
                                    color: AppPalette.cream
                                        .withValues(alpha: .78),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // The countdown is the page's only per-second repaint,
                          // so it gets its own boundary and nothing else does.
                          // It keeps its 21sp size wherever it fits, and only
                          // scales down on a 320dp phone at a large text scale —
                          // a bare Text there overflowed the row by ~6px.
                          RepaintBoundary(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: strip.maxWidth * .36,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerEnd,
                                child: _LiveCountdown(
                                  second: ticker.second,
                                  // The label names the adhan, so the number
                                  // must be the time to that adhan — never the
                                  // iqamah.
                                  target: snap.nextAdhanTime,
                                  active: _active,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// The two times the named prayer is said at: the adhan always, plus the
  /// iqamah when one is configured (shown separately, never counted to).
  static String _timeLine(PrayerSnapshot snap, bool use12Hour) {
    final adhan = _formatClock(snap.nextAdhanTime, use12Hour);
    if (snap.iqamahTime == null) return 'اذان\u00A0$adhan';
    return 'اذان\u00A0$adhan · اقامه\u00A0'
        '${_formatClock(snap.iqamahTime!, use12Hour)}';
  }

  static String _formatClock(DateTime t, bool use12Hour) {
    final m = t.minute.toString().padLeft(2, '0');
    if (!use12Hour) return '${t.hour.toString().padLeft(2, '0')}:$m';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:$m ${t.hour < 12 ? 'ق.ظ' : 'ب.ظ'}';
  }

  static IconData _iconFor(PrayerId id) => switch (id) {
        PrayerId.fajr => Icons.nightlight_round,
        PrayerId.sunrise => Icons.wb_sunny_outlined,
        PrayerId.dhuhr => Icons.light_mode_rounded,
        PrayerId.asr => Icons.wb_sunny_outlined,
        PrayerId.maghrib => Icons.wb_twilight_rounded,
        PrayerId.isha => Icons.dark_mode_rounded,
      };
}

class _LiveCountdown extends StatelessWidget {
  const _LiveCountdown({
    required this.second,
    required this.target,
    required this.active,
  });

  final ValueListenable<DateTime> second;
  final DateTime target;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return _text(context, second.value);
    return ValueListenableBuilder<DateTime>(
      valueListenable: second,
      builder: (context, now, _) => _text(context, now),
    );
  }

  Widget _text(BuildContext context, DateTime now) {
    final d = target.difference(now);
    final safe = d.isNegative ? Duration.zero : d;
    String two(int n) => n.toString().padLeft(2, '0');
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        '${two(safe.inHours)}:${two(safe.inMinutes % 60)}:${two(safe.inSeconds % 60)}',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 21),
          fontWeight: FontWeight.w500,
          color: AppPalette.heroGold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SEARCH FIELD — filters every group below
// ═══════════════════════════════════════════════════════════════

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: .5),
      );

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 13),
        color: t.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'جستجو در بخش\u200cها',
        hintStyle: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 13),
          color: t.textMuted,
        ),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: t.textMuted),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: t.textMuted,
              tooltip: 'پاک کردن',
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
            );
          },
        ),
        isDense: true,
        filled: true,
        fillColor: t.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: _border(t.outline),
        enabledBorder: _border(t.outline),
        focusedBorder: _border(t.outline),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CONTENT RESULTS — text found INSIDE a section, under its own tile
// ═══════════════════════════════════════════════════════════════

/// Hits grouped by the section that owns them. The engine returns them in
/// source order, so a hit only ever joins the group above it — one pass, and
/// the sections keep the registry order the page already uses.
class _ContentHitList extends StatelessWidget {
  const _ContentHitList({required this.hits, required this.onOpen});

  final List<ContentHit> hits;
  final void Function(ContentHit hit) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final groups = <String, List<ContentHit>>{};
    for (final hit in hits) {
      groups.putIfAbsent(hit.itemId, () => <ContentHit>[]).add(hit);
    }

    final rows = <Widget>[];
    for (final entry in groups.entries) {
      final owner = moreItemById(entry.key);
      if (owner == null) continue;
      for (final hit in entry.value) {
        final snippetStyle = TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 11.5),
          color: t.textMuted,
          height: 1.35,
        );
        final query = hit.highlightQuery.trim();
        rows.add(
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -1),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            // dsContentColor — the accent is drawn as INK here, and a raw
            // topic hue can sit under 3:1 on the card (the same rule the
            // tiles' readableGlyph follows).
            leading: Icon(
              owner.icon,
              size: 20,
              color: dsContentColor(context, owner.accent),
            ),
            title: Text(
              hit.title.isEmpty ? owner.title : hit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13.5),
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hit.title.isNotEmpty)
                  Text(
                    owner.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w500,
                      color: dsContentColor(context, owner.accent),
                    ),
                  ),
                Text.rich(
                  TextSpan(
                    style: snippetStyle,
                    children: query.isEmpty
                        ? [TextSpan(text: hit.snippet)]
                        : TextHighlight.spans(
                            hit.snippet,
                            query,
                            baseStyle: snippetStyle,
                            highlightStyle:
                                TextHighlight.defaultHighlightStyle(
                              context,
                              base: snippetStyle,
                            ),
                          ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            onTap: () => onOpen(hit),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STYLE-2 GRID — four columns of flat duotone squircles
// ═══════════════════════════════════════════════════════════════

class _Style2Grid extends StatelessWidget {
  const _Style2Grid({required this.items});

  final List<MoreItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // crossAxisSpacing stays 0; the air around a tile is part of the tile
        // size formula, so the visual gap scales with the screen.
        final cell = constraints.maxWidth / 4;
        final s = moreTileSize(cell);
        // Cell height = tile + 7 + two label lines. Derived from the user's
        // font scale, so rows grow instead of clipping a long title.
        final cellHeight = s + 7 + AppTheme.scaledFontSize(context, 12.5) * 2.4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 14,
            childAspectRatio: cell / cellHeight,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _Style2Tile(item: items[index], tileSize: s),
        );
      },
    );
  }
}

class _Style2Tile extends StatefulWidget {
  const _Style2Tile({required this.item, required this.tileSize});

  final MoreItem item;
  final double tileSize;

  @override
  State<_Style2Tile> createState() => _Style2TileState();
}

class _Style2TileState extends State<_Style2Tile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final s = widget.tileSize;
    final t = TimeThemeKit.of(context).palette;
    final locked = _isLocked(item);
    final d = MoreDuotone.of(item.accent,
        isDark: Theme.of(context).brightness == Brightness.dark,
        cardSurface: t.card);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        // The whole grid cell is the touch target; the splash follows the
        // squircle radius.
        borderRadius: BorderRadius.circular(s * .32),
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.selectionClick();
          _openMoreItem(context, item);
        },
        child: Semantics(
          button: true,
          label: item.title,
          child: AnimatedScale(
            scale: _pressed ? .96 : 1,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Column(
              children: [
                Container(
                  width: s,
                  height: s,
                  // The 1dp accent hairline is drawn ON TOP of the clipped
                  // children so it stays a crisp edge.
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(s * .32),
                    border: Border.all(color: d.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(s * .32),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: d.fill)),
                        Center(
                          child: Icon(
                            item.icon,
                            size: s * .48 * item.iconScale,
                            color: locked ? t.textMuted : d.glyph,
                          ),
                        ),
                        PositionedDirectional(
                          top: s * .12,
                          end: s * .12,
                          child: _Style2Circle(diameter: s * .10, color: d.dot),
                        ),
                        if (locked)
                          PositionedDirectional(
                            top: s * .10,
                            start: s * .10,
                            child: Container(
                              padding: EdgeInsets.all(s * .03),
                              decoration: BoxDecoration(
                                color: item.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.lock,
                                  size: s * .13, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: _TileLabel(
                    text: item.title,
                    color: locked ? t.textMuted : t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Style2Circle extends StatelessWidget {
  const _Style2Circle({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Two lines at most: the text wraps first and is only scaled down when even
/// two lines do not fit, so a long Persian title never ends in an ellipsis.
class _TileLabel extends StatelessWidget {
  const _TileLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: constraints.maxWidth,
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// UTILITY LIST — «تنظیمات و بیشتر» as rows, not big tiles
// ═══════════════════════════════════════════════════════════════

class _UtilityList extends StatelessWidget {
  const _UtilityList({required this.items});

  final List<MoreItem> items;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0)
              Divider(
                  height: 1,
                  thickness: .5,
                  color: t.outline.withValues(alpha: .7)),
            _UtilityRow(
              item: item,
              onTap: () {
                HapticFeedback.selectionClick();
                _openMoreItem(context, item);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// A list row with the small version of the tile recipe: a 40dp squircle
/// drawn with the same proportional alphas, glyph at 0.52·S.
class _UtilityRow extends StatelessWidget {
  const _UtilityRow({required this.item, required this.onTap});

  final MoreItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            _Style2MiniTile(accent: item.accent, icon: item.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w500,
                      color: t.textPrimary,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: t.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left_rounded, size: 20, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

/// The 40dp row icon: the Style-2 recipe at row scale.
class _Style2MiniTile extends StatelessWidget {
  const _Style2MiniTile({required this.accent, required this.icon});

  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const s = 40.0;
    final t = TimeThemeKit.of(context).palette;
    final d = MoreDuotone.of(accent,
        isDark: Theme.of(context).brightness == Brightness.dark,
        cardSurface: t.card);
    return Container(
      width: s,
      height: s,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(s * .32),
        border: Border.all(color: d.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(s * .32),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: d.fill)),
            Center(
              child: Icon(icon, size: s * .52, color: d.glyph),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreEmptyState extends StatelessWidget {
  const _MoreEmptyState();

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 34, color: t.textMuted),
          const SizedBox(height: 10),
          Text(
            'موردی پیدا نشد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
