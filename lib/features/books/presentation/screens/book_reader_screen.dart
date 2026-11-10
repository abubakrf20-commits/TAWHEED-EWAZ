import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/design_system/components/failure_view.dart';
import 'package:tawheeed/features/books/data/models/book_model.dart';
import 'package:tawheeed/features/books/data/daos/book_bookmark_dao.dart';
import 'package:tawheeed/features/books/services/book_content_service.dart';
import 'package:tawheeed/features/books/presentation/book_page_notes.dart';
import 'package:tawheeed/features/books/presentation/book_palette.dart';
import 'package:tawheeed/features/books/presentation/providers/book_provider.dart';
import 'package:tawheeed/features/books/presentation/providers/book_bookmark_provider.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_reader_page.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_reader_progress_bar.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_reader_display_settings.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_reader_bookmark_sheet.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_reader_search_sheet.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_reader_toc_sheet.dart';
import 'package:tawheeed/features/books/services/book_toc.dart';
import 'package:tawheeed/features/books/data/services/book_highlight_service.dart';
import 'package:tawheeed/features/books/presentation/providers/reading_stats_provider.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';
import 'package:tawheeed/features/books/services/book_page_migration.dart';
import 'package:tawheeed/features/books/services/book_sheet_layout.dart';
import 'package:tawheeed/features/books/presentation/widgets/book_title_page.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  final BookModel book;

  /// A word a deep-search hit was opened for: the page's own highlighting
  /// paints it the moment the reader lands, without opening the search bar.
  final String initialQuery;

  const BookReaderScreen(
      {super.key, required this.book, this.initialQuery = ''});

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  List<String> _content = [];

  /// صفحات واقعی — مطابق بر شماره‌صفحه‌های چاپی `(N/M)` در فایل محتوا.
  List<BookPage> _pages = [];
  int _currentPage = 0;

  /// The folded text of every page, built once per book.
  ///
  /// WHY: `_matchesFor` used to fold all N pages inside `onChanged`, so typing
  /// «الله» in a 400-page volume folded the whole book four times — once per
  /// character — and the reader stuttered on each key. The fold is a pure
  /// function of the page text, so it is computed once and reused for every
  /// later query; only the `contains` scan repeats.
  List<String>? _foldedPages;

  /// The keystroke that is waiting to be searched. Search runs on a short
  /// timer so a fast typist folds and scans once per word, not per letter.
  Timer? _searchDebounce;
  double _fontSize = 16;
  double _lineHeight = 1.8;

  /// The app's book face by default: the reader is the one screen where the
  /// typeface is the product, and Tika is bundled for exactly that.
  String _fontFamily = 'TKT-Tika';

  /// The page a reader picked (`reader_paper`). Surface AND ink travel with
  /// it — see [BookPalette.papers].
  String _paperKey = 'paper';

  /// Index into [readerMarginSteps] (`reader_margin`).
  int _marginStep = 1;

  /// `reader_justify` — every paragraph flush on both edges.
  bool _justify = true;

  /// `reader_footnote_mode` — do the page's notes print under the text, and
  /// does the text point at them? See [BookFootnoteMode].
  BookFootnoteMode _footnoteMode = BookFootnoteMode.markers;

  /// صفحهٔ عنوان، شروع فصل در برگ درست و حاشیهٔ آینه‌ای — all three are
  /// display-only: they add SHEETS, never pages, so a saved position,
  /// bookmark or highlight keeps its page number with them on.
  bool _titlePage = true;
  bool _chapterRecto = true;
  bool _mirrorMargin = true;

  /// The sheets the reader actually turns through — built from `_pages` plus
  /// the three switches above (see `BookSheetLayout`).
  BookSheetLayout _layout = BookSheetLayout.empty();

  /// Which sheet is on screen.
  int _sheetIndex = 0;

  /// The edition's own contents (`toc` in the book file) and how many printed
  /// volumes it has.
  List<BookTocItem> _toc = const [];
  int _volumes = 0;

  /// Page index where each volume starts — the جلد chips in the TOC sheet,
  /// derived once with the pages. `[0]` for a single-volume book.
  List<int> _volumeStarts = const [];

  /// The last non-night paper, so leaving night mode returns to the reader's
  /// own page instead of always snapping back to linen.
  String _dayPaper = 'paper';
  bool _isLoading = true;
  double _downloadProgress = 0;
  bool _isBookmarked = false;

  /// True once [_isBookmarked] describes the page currently on screen.
  ///
  /// WHY: the flag starts `false` and the bookmark button was live from the
  /// first frame, so tapping a page that WAS bookmarked opened the «add
  /// bookmark» sheet and stored a second bookmark for the same page — the
  /// reader could not remove a bookmark on the first try, and a duplicate
  /// row appeared in the sheet. The button is disabled until the page's own
  /// state has been read.
  bool _bookmarkKnown = false;
  bool _isNavigating = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  /// When this reading session started — one row of reading minutes is
  /// written on exit if the session lasted a whole minute.
  final DateTime _sessionStartedAt = DateTime.now();
  String _searchQuery = '';
  List<int> _searchMatches = [];
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearchVisible = false;
  int _currentMatchIndex = 0;
  bool _isHighlightMode = false;
  bool _immersive = false;
  List<BookHighlight> _pageHighlights = [];
  final _highlightService = BookHighlightService.instance;
  final _highlightTextController = TextEditingController();
  TextSelection _lastTextSelection = const TextSelection.collapsed(offset: 0);

  /// The page the current selection belongs to, so the colour bar stores the
  /// highlight where the reader actually selected.
  int _lastSelectionPage = 0;

  @override
  void initState() {
    super.initState();
    _highlightTextController.addListener(() {
      final sel = _highlightTextController.selection;
      if (sel.isValid && !sel.isCollapsed) {
        _lastTextSelection = sel;
        _lastSelectionPage = _currentPage;
      }
    });
    _loadContent();
    _currentPage = widget.book.currentPage;
    final initialQuery = widget.initialQuery.trim();
    if (initialQuery.isNotEmpty) {
      _searchQuery = initialQuery;
      _searchCtrl.text = initialQuery;
    }
    _loadBookmarkStatus();
    _loadDisplayPrefs();
  }

  ({String key, String label, Color surface, Color ink}) get _paper =>
      BookPalette.paperFor(_paperKey);

  bool get _isNightMode => _paperKey == 'night';

  /// One read for every display preference. They used to be loaded piecemeal
  /// (theme here, font there) and only two of the four were persisted at all —
  /// so a reader who moved the size slider lost it on the next open.
  Future<void> _loadDisplayPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Installs that predate `reader_paper` only carry the boolean.
    final legacyNight = prefs.getBool('reader_night_mode') ?? false;
    final paper =
        prefs.getString('reader_paper') ?? (legacyNight ? 'night' : 'paper');
    final font = prefs.getString('reader_font');
    final size = prefs.getDouble('reader_font_size');
    final lineHeight = prefs.getDouble('reader_line_height');
    final margin = prefs.getInt('reader_margin');
    final justify = prefs.getBool('reader_justify');
    // Installs that predate `reader_footnote_mode` only carry the boolean.
    final storedFootnoteMode = prefs.getString('reader_footnote_mode');
    final footnoteMode = storedFootnoteMode == null
        ? BookFootnoteMode.fromLegacyBool(prefs.getBool('reader_footnotes'))
        : BookFootnoteMode.fromWire(storedFootnoteMode);
    final titlePage = prefs.getBool('reader_title_page');
    final chapterRecto = prefs.getBool('reader_chapter_recto');
    final mirror = prefs.getBool('reader_mirror_margin');
    // `reader_spread` is orphaned on purpose: the two-page layout was removed,
    // and nothing reads the key an older build left behind.
    if (!mounted) return;
    setState(() {
      _paperKey = BookPalette.paperFor(paper).key;
      if (_paperKey != 'night') _dayPaper = _paperKey;
      if (font != null && font.isNotEmpty) _fontFamily = font;
      if (size != null) _fontSize = size.clamp(12, 28);
      if (lineHeight != null) _lineHeight = lineHeight.clamp(1.2, 3.0);
      if (margin != null) {
        _marginStep = margin.clamp(0, readerMarginSteps.length - 1);
      }
      if (justify != null) _justify = justify;
      _footnoteMode = footnoteMode;
      if (titlePage != null) _titlePage = titlePage;
      if (chapterRecto != null) _chapterRecto = chapterRecto;
      if (mirror != null) _mirrorMargin = mirror;
    });
    // The content may already be waiting: re-arrange the sheets with the
    // switches the reader actually saved.
    _rebuildLayout();
  }

  Future<void> _saveDisplayPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_paper', _paperKey);
    // Kept in step for any older build reading the boolean.
    await prefs.setBool('reader_night_mode', _isNightMode);
    await prefs.setString('reader_font', _fontFamily);
    await prefs.setDouble('reader_font_size', _fontSize);
    await prefs.setDouble('reader_line_height', _lineHeight);
    await prefs.setInt('reader_margin', _marginStep);
    await prefs.setBool('reader_justify', _justify);
    await prefs.setString('reader_footnote_mode', _footnoteMode.wire);
    // Kept in step for any older build reading the boolean.
    await prefs.setBool(
      'reader_footnotes',
      _footnoteMode != BookFootnoteMode.hidden,
    );
    await prefs.setBool('reader_title_page', _titlePage);
    await prefs.setBool('reader_chapter_recto', _chapterRecto);
    await prefs.setBool('reader_mirror_margin', _mirrorMargin);
  }

  /// ترتیب برگ‌ها را از صفحات و کلیدهای نمایش دوباره می‌سازد.
  ///
  /// Pages never move: the reader re-anchors the sheet it is on to the page
  /// it was showing, unless it is sitting on the title sheet — then it stays
  /// there (or falls back to the first page if the title was switched off).
  void _rebuildLayout() {
    if (_pages.isEmpty) return;
    final onTitle = _layout.sheets.isNotEmpty &&
        _sheetIndex < _layout.sheets.length &&
        _layout.sheets[_sheetIndex].kind == BookSheetKind.title;
    final layout = BookSheetLayout.build(
      pages: _pages,
      titlePage: _titlePage,
      chapterRecto: _chapterRecto,
    );
    if (!mounted) return;
    setState(() {
      _layout = layout;
      _sheetIndex = onTitle && _titlePage && layout.sheets.isNotEmpty
          ? 0
          : layout.sheetForPage(_currentPage);
    });
    _loadPageHighlights();
  }

  void _setPaper(String key) {
    setState(() {
      _paperKey = BookPalette.paperFor(key).key;
      if (_paperKey != 'night') _dayPaper = _paperKey;
    });
    _saveDisplayPrefs();
  }

  Future<void> _toggleNightMode() async {
    _setPaper(_isNightMode ? _dayPaper : 'night');
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _loadBookmarkStatus() async {
    final bookmarkProv =
        ref.read(bookBookmarkProvider(widget.book.id).notifier);
    final page = _currentPage;
    final bookmarked = await bookmarkProv.isPageBookmarked(page);
    if (!mounted) return;
    setState(() {
      // The reader may have turned the page while this was in flight; a
      // late answer for the old page must not claim the new one.
      if (page != _currentPage) return;
      _isBookmarked = bookmarked;
      _bookmarkKnown = true;
    });
  }

  /// یک‌بار ایندکس‌های ذخیره‌شده را پس از بازلایه‌بندی به صفحهٔ تازه می‌برد.
  ///
  /// پیشرفت مطالعه، نشانک‌ها و هایلایت‌ها همه ایندکس صفحه را ذخیره می‌کنند و
  /// حذفِ صفحه‌های ساختگی شمارش را عوض کرده است؛ شمارهٔ صفحهٔ چاپی تنها
  /// لنگرِ مشترک دو چیدمان است. پرچمِ هر کتاب مانع اجرای دوباره است.
  Future<int> _migratePageIndexes(
    List<BookPage> pages,
    List<String> content,
  ) async {
    final saved = widget.book.currentPage;
    final prefs = await SharedPreferences.getInstance();
    final flag = BookPageMigration.flagKey(widget.book.id);
    if (prefs.getBool(flag) ?? false) return saved;
    final remap = BookPageMigration.remap(
      legacyPrintNos: BookPagination.legacyPrintNos(content),
      pages: pages,
    );
    try {
      final dao = ref.read(bookBookmarkDaoProvider);
      for (final bookmark in await dao.getBookmarks(widget.book.id)) {
        final fresh = remap[bookmark.page];
        if (fresh != null && fresh != bookmark.page) {
          await dao.updateBookmarkPage(bookmark.id, fresh);
        }
      }
    } catch (e) {
      AppLogger.warning('book_reader_screen', 'bookmark remap failed: $e');
    }
    try {
      await _highlightService.remapPages(
        widget.book.id,
        remap,
        [for (final page in pages) page.text.length],
      );
    } catch (e) {
      AppLogger.warning('book_reader_screen', 'highlight remap failed: $e');
    }
    await prefs.setBool(flag, true);
    return remap[saved] ?? saved;
  }

  Future<void> _loadContent() async {
    // «تلاش مجدد» runs this again: without clearing the message the error view
    // stays up after a successful retry (and no spinner ever shows).
    if (_errorMessage != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      // Download the book content on first open (it is no longer bundled),
      // then read + decode the (still gzipped) file off the UI isolate.
      final localPath = await BookContentService.ensureDownloaded(
        widget.book.id,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = total > 0 ? received / total : 0;
          });
        },
      );
      if (localPath == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage =
              'دانلود کتاب ناموفق بود؛ لطفاً اتصال اینترنت را بررسی کنید.';
        });
        return;
      }
      final bytes = await File(localPath).readAsBytes();
      // Decode + parse on a background isolate: books can be several MB
      // decompressed and doing that on the UI thread froze or OOM'd low-end
      // phones (reported «library doesn't work» crash).
      final parsed = await compute(_decodeBookFile, bytes);
      if (!mounted) return;
      if (parsed['content'] != null) {
        final content = List<String>.from(parsed['content']);
        final volumes = (parsed['volumes'] as num?)?.toInt() ?? 0;
        final legacyNotes =
            Map<String, String>.from(parsed['footnotes'] ?? {});
        // صفحه‌بندی بر اساس مرز صفحات چاپی — جدا از ایزوله انجام شدنی است
        // (فقط متن ساده است) اما ورودی همین‌جا خیلی سریع پردازش می‌شود.
        // پانوشت‌ها هم همین‌جا سهمیه‌بندی می‌شوند: هر صفحه فقط پانوشت‌های
        // خودش را می‌گیرد، وگرنه متنِ پای صفحهٔ نخست در همهٔ صفحه‌ها تکرار
        // می‌شد.
        final pages = BookPagination.paginate(
          content,
          volumes: volumes,
          legacyNotes: legacyNotes,
        );
        final restoredPage = await _migratePageIndexes(pages, content);
        if (!mounted) return;
        setState(() {
          _content = content;
          _toc = BookToc.parse(
              List<String>.from(parsed['toc'] ?? const <String>[]));
          _volumes = volumes;
          _volumeStarts = BookPagination.volumeStartsOf(pages);
          _pages = pages;
          // A new book (or a re-pagination) invalidates the fold.
          _foldedPages = null;
          _layout = BookSheetLayout.build(
            pages: pages,
            titlePage: _titlePage,
            chapterRecto: _chapterRecto,
          );
          // A saved position from the shelf is an index into the OLD page
          // count (the edition can carry 458 pages where the card said 400).
          _currentPage = pages.isEmpty
              ? 0
              : restoredPage.clamp(0, pages.length - 1);
          // A book that has never been read opens on its title, the way a
          // printed one does; a reader who comes back mid-book lands where
          // they stopped instead.
          _sheetIndex = _titlePage &&
                  widget.book.currentPage <= 0 &&
                  _layout.sheets.isNotEmpty
              ? 0
              : _layout.sheetForPage(_currentPage);
          _isLoading = false;
          _errorMessage = null;
        });
        // A deep-search hit opens with its word already recorded: fill the
        // match list so the in-reader search bar agrees with what is painted.
        if (_searchQuery.isNotEmpty) {
          final matches = _matchesFor(_searchQuery);
          if (mounted) setState(() => _searchMatches = matches);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.warning('book_reader_screen', 'error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'خواندن متن کتاب ممکن نشد؛ دوباره تلاش کنید.';
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _highlightTextController.dispose();
    // The stats providers are keepAlive, so pages counted during this session
    // would stay invisible on the stats screen until the app restarted.
    // Refreshing here (not per page turn) keeps reading smooth.
    ref
      ..invalidate(readingStatsProvider)
      ..invalidate(readingTotalProvider)
      ..invalidate(readingStreakProvider)
      ..invalidate(readingMinutesTotalProvider);
    trackReadingMinutes(
        ref, DateTime.now().difference(_sessionStartedAt).inMinutes);
    if (widget.book.pageCount > 0 || _pages.isNotEmpty) {
      try {
        final totalPages =
            _pages.isNotEmpty ? _pages.length : widget.book.pageCount;
        if (totalPages > 0) {
          final clamped = _currentPage.clamp(0, totalPages - 1);
          ref
              .read(bookProvider.notifier)
              .updateProgress(widget.book.id, clamped, totalPages: totalPages);
        }
      } catch (_) {
        // Best-effort progress save on exit — must never crash the pop.
      }
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool get _hasContent =>
      !_isLoading && _content.isNotEmpty && _paginateContent().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final danger = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;

    return Scaffold(
      appBar: _immersive ? null : _buildAppBar(),
      backgroundColor: _paper.surface,
      body: Stack(
        children: [
          Column(
            children: [
              if (_isSearchVisible)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: _isNightMode
                      ? BookPalette.searchStripNight
                      : BookPalette.searchStripDay,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'عبارت جستجو را وارد کنید'
                              : _searchMatches.isEmpty
                                  ? 'نتیجه‌ای یافت نشد'
                                  : '${_searchMatches.length} نتیجه در کتاب',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            // Paper ink, not theme ink: a dark app theme over a
                            // linen page made the muted colour invisible.
                            color: _searchMatches.isEmpty &&
                                    _searchQuery.isNotEmpty
                                ? danger
                                : _paper.ink.withValues(alpha: 0.7),
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                      if (_searchMatches.isNotEmpty)
                        TextButton.icon(
                          onPressed: _showSearchResults,
                          icon: const Icon(Icons.list_alt, size: 16),
                          label: Text('فهرست نتایج',
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 11),
                                  fontFamily: AppTheme.fontFamily)),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                TimeThemeKit.of(context).palette.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            if (_downloadProgress > 0) ...[
                              const SizedBox(height: 12),
                              Text(
                                'در حال دانلود کتاب… ${(_downloadProgress * 100).toStringAsFixed(0)}٪',
                                style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 12),
                                  color: TimeThemeKit.of(context)
                                      .palette
                                      .textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? _buildErrorView()
                        : _content.isEmpty
                            ? _buildEmptyContent()
                            : _buildContent(),
              ),
            ],
          ),
          if (_immersive)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: _paper.surface.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                    elevation: 2,
                    child: IconButton(
                      icon: Icon(Icons.fullscreen_exit,
                          size: 20, color: _paper.ink.withValues(alpha: 0.85)),
                      tooltip: 'خروج از حالت تمرکز',
                      onPressed: _toggleImmersive,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _immersive
          ? null
          : _isHighlightMode
              ? _buildHighlightBar()
              : _content.isNotEmpty
                  ? BookReaderProgressBar(
                      currentPage: _currentPage,
                      totalPages: pages.length,
                      pageLabel: pages.isEmpty
                          ? '1'
                          : _isTitleSheet
                              ? 'عنوان'
                              : pages[_currentPage.clamp(0, pages.length - 1)]
                                  .pageLabel,
                      surface: _paper.surface,
                      ink: _paper.ink,
                      bookmarkPages: [
                        for (final b in ref
                                .watch(bookBookmarkProvider(widget.book.id))
                                .value ??
                            const <BookBookmarkData>[])
                          b.page,
                      ],
                      onPrev: _layout.stepBack(_sheetIndex) != null
                          ? _goToPrevPage
                          : null,
                      onNext: _layout.stepForward(_sheetIndex) != null
                          ? _goToNextPage
                          : null,
                      onPageChanged: _jumpToPage,
                    )
                  : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final danger = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;
    if (_isSearchVisible) {
      return AppBar(
        backgroundColor: _paper.surface,
        foregroundColor: _paper.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontFamily: AppTheme.fontFamily),
          decoration: InputDecoration(
            hintText: 'جستجو در کتاب...',
            hintStyle: TextStyle(
                color: TimeThemeKit.of(context).palette.textMuted,
                fontFamily: AppTheme.fontFamily),
            border: InputBorder.none,
          ),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          if (_searchMatches.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${_currentMatchIndex + 1}/${_searchMatches.length}',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: TimeThemeKit.of(context).palette.textMuted,
                      fontFamily: AppTheme.fontFamily),
                ),
              ),
            ),
          if (_searchMatches.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: 'مطابقت قبلی',
              onPressed: _goToPrevMatch,
              visualDensity: VisualDensity.compact,
            ),
          if (_searchMatches.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'مطابقت بعدی',
              onPressed: _goToNextMatch,
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'بستن جستجو',
            onPressed: () {
              setState(() {
                _isSearchVisible = false;
                _searchCtrl.clear();
                _searchFocusNode.unfocus();
                _onSearchChanged('');
              });
            },
          ),
        ],
      );
    }
    return AppBar(
      // The chrome is part of the page: an app-themed bar over linen paper is
      // the one thing that made the reader look like a list of text, not a
      // book. Both papers carry ink that stays legible on this surface.
      backgroundColor: _paper.surface,
      foregroundColor: _paper.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(widget.book.title,
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontFamily: AppTheme.fontFamily,
              color: _paper.ink)),
      centerTitle: true,
      // Four controls, not eight: the title used to be squeezed to nothing
      // at 320 dp, and night/immersive/highlight/favourite are settings a
      // reader sets once, not every page. They live in the overflow now.
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'جستجو',
          onPressed: () {
            setState(() {
              _isSearchVisible = true;
              _searchCtrl.clear();
              _onSearchChanged('');
            });
          },
        ),
        IconButton(
          icon: Icon(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color:
                _isBookmarked ? TimeThemeKit.of(context).palette.primary : null,
          ),
          tooltip: !_bookmarkKnown
              ? 'در حال خواندن وضعیت نشانک…'
              : _isBookmarked
                  ? 'حذف نشانک'
                  : 'افزودن نشانک',
          // Disabled until this page's own state is known — see
          // [_bookmarkKnown].
          onPressed: _bookmarkKnown ? _toggleBookmark : null,
        ),
        IconButton(
          icon: const Icon(Icons.format_size),
          tooltip: 'تنظیمات نمایش',
          onPressed: _showDisplaySettings,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'بیشتر',
          onSelected: (value) {
            switch (value) {
              case 'night':
                _toggleNightMode();
              case 'immersive':
                _toggleImmersive();
              case 'highlight':
                setState(() => _isHighlightMode = !_isHighlightMode);
                if (_isHighlightMode) _loadPageHighlights();
              case 'share':
                if (_hasContent) _shareCurrentPage();
              case 'copy':
                if (_hasContent) _copyCurrentPage();
              case 'bookmarks':
                if (_hasContent) _showBookmarkList();
              case 'toc':
                if (_hasContent) _showTableOfContents();
              case 'favorite':
                ref.read(bookProvider.notifier).toggleFavorite(widget.book.id);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
                value: 'night',
                child: Row(children: [
                  Icon(_isNightMode ? Icons.light_mode : Icons.dark_mode,
                      size: 20),
                  const SizedBox(width: 10),
                  Text(_isNightMode ? 'حالت روز' : 'حالت شب')
                ])),
            PopupMenuItem(
                value: 'immersive',
                child: Row(children: [
                  Icon(_immersive ? Icons.fullscreen_exit : Icons.fullscreen,
                      size: 20),
                  const SizedBox(width: 10),
                  Text(_immersive ? 'خروج از حالت تمرکز' : 'حالت تمرکز')
                ])),
            PopupMenuItem(
                value: 'highlight',
                child: Row(children: [
                  Icon(
                      _isHighlightMode
                          ? Icons.highlight_off
                          : Icons.highlight_alt_outlined,
                      size: 20),
                  const SizedBox(width: 10),
                  Text(
                      _isHighlightMode ? 'خروج از حالت هایلایت' : 'هایلایت متن')
                ])),
            const PopupMenuDivider(),
            const PopupMenuItem(
                value: 'toc',
                child: Row(children: [
                  Icon(Icons.list, size: 20),
                  SizedBox(width: 10),
                  Text('فهرست کتاب')
                ])),
            const PopupMenuItem(
                value: 'bookmarks',
                child: Row(children: [
                  Icon(Icons.bookmarks, size: 20),
                  SizedBox(width: 10),
                  Text('نشانک‌ها')
                ])),
            const PopupMenuItem(
                value: 'share',
                child: Row(children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 10),
                  Text('اشتراک‌گذاری صفحه')
                ])),
            const PopupMenuItem(
                value: 'copy',
                child: Row(children: [
                  Icon(Icons.content_copy, size: 20),
                  SizedBox(width: 10),
                  Text('کپی متن صفحه')
                ])),
            const PopupMenuDivider(),
            PopupMenuItem(
                value: 'favorite',
                child: Row(children: [
                  Icon(
                      widget.book.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 20,
                      color: widget.book.isFavorite ? danger : null),
                  const SizedBox(width: 10),
                  Text(widget.book.isFavorite
                      ? 'حذف از علاقه‌مندی‌ها'
                      : 'افزودن به علاقه‌مندی‌ها'),
                ])),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    final danger = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;
    // The reader is a paper surface, so the panel is inked from the paper rather
    // than the ambient time theme. The raw exception goes to `error`, which the
    // panel renders in debug builds only — the old version printed
    // «خطا در بارگذاری کتاب: $e» straight to the reader, which told them the
    // name of a database table and nothing they could act on.
    return FailureView(
      id: 'book_reader_load',
      title: 'بارگذاری کتاب ناموفق بود',
      detail: 'متن کتاب از فایل خودش خوانده می‌شود و جایی نرفته است؛ '
          'با تلاش دوباره دوباره خوانده می‌شود.',
      onRetry: _loadContent,
      layout: FailureLayout.page,
      error: _errorMessage,
      ink: FailureInk(
        title: _paper.ink,
        detail: _paper.ink.withValues(alpha: 0.7),
        danger: danger,
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book,
              size: 64, color: _paper.ink.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('محتوای کتاب بارگذاری نشد',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontFamily: AppTheme.fontFamily,
                  color: _paper.ink.withValues(alpha: 0.75))),
          const SizedBox(height: 8),
          Text('فایل اصلی کتاب ممکن است ناقص باشد',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  fontFamily: AppTheme.fontFamily,
                  color: _paper.ink.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  /// The sheet as a printed page — or the title and blank sheets a book
  /// opens on and turns through before the text starts.
  Widget _buildContent() {
    if (_pages.isEmpty || _layout.sheets.isEmpty) {
      return _buildEmptyContent();
    }
    final index = _sheetIndex.clamp(0, _layout.sheets.length - 1);
    final sheet = _layout.sheets[index];
    final Widget page;
    if (sheet.kind == BookSheetKind.title) {
      page = _turnable(BookTitlePage(
        title: widget.book.title,
        author: widget.book.author,
        category: widget.book.category,
        ink: _paper.ink,
        fontFamily: _fontFamily,
        volumes: _volumes,
      ));
    } else if (sheet.kind == BookSheetKind.blank) {
      page = _turnable(const BookBlankSheet());
    } else {
      page = _buildSheetPage(index);
    }
    // برگ با هر ورق خوردن از سمت شیرازه جا می‌افتد؛ بدون این، صفحه‌ها
    // بی‌درنگ عوض می‌شدند و خواندن دیگر شبیه ورق زدن نبود.
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: _turnTransition,
      child: KeyedSubtree(key: ValueKey('sheet-$index'), child: page),
    );
  }

  Widget _turnTransition(Widget child, Animation<double> animation) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(rtl ? 0.05 : -0.05, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  /// The title and blank sheets are tapped to move on, the way the margins
  /// of a page turn it.
  Widget _turnable(Widget child) {
    final next =
        _layout.stepForward(_sheetIndex) != null ? _goToNextPage : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: next,
      child: child,
    );
  }

  /// One sheet of the book as a running page.
  Widget _buildSheetPage(int index) {
    final page = _pages[_layout.sheets[index].page];
    return BookReaderPage(
      // A fresh element per page: the scroll offset, the paragraph keys and
      // the reveal-the-first-match pass all belong to one page.
      key: ValueKey('${widget.book.id}:${page.index}'),
      page: page,
      bookTitle: widget.book.title,
      style: BookReaderPageStyle(
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        fontFamily: _fontFamily,
        ink: _paper.ink,
        sideMargin: readerMarginSteps[_marginStep],
        justify: _justify,
        footnoteMode: _footnoteMode,
        mirrorMargin: _mirrorMargin,
        // The fold changes edge as the reader turns, so the wide margin
        // alternates with the sheet.
        gutterOnLeft: index.isEven,
      ),
      highlights: _pageHighlights,
      footnotes: BookPageNotes.of(page, page.notes),
      searchQuery: _searchQuery,
      onHighlightRange: (start, end) => _highlightRange(page.index, start, end),
      selectionMode: _isHighlightMode,
      selectionController: _highlightTextController,
      onPrev: _layout.stepBack(index) != null ? _goToPrevPage : null,
      onNext: _layout.stepForward(index) != null ? _goToNextPage : null,
    );
  }

  /// Is the title sheet on screen — the bar says «عنوان» instead of a page.
  bool get _isTitleSheet =>
      _layout.sheets.isNotEmpty &&
      _sheetIndex < _layout.sheets.length &&
      _layout.sheets[_sheetIndex].kind == BookSheetKind.title;

  /// The sheet on screen as a page number — a blank keeps the page in front
  /// of it, so turning onto a flyleaf never claims you passed the chapter.
  int get _sheetPage {
    if (_layout.sheets.isEmpty) return _currentPage;
    final sheet =
        _layout.sheets[_sheetIndex.clamp(0, _layout.sheets.length - 1)];
    return sheet.isPage ? sheet.page : _currentPage;
  }

  /// Moves the reader to [sheet] and keeps `_currentPage` — the coordinate
  /// every stored thing is keyed on — pointing at the page that sheet shows.
  void _setSheet(int sheet) {
    setState(() {
      _sheetIndex = sheet.clamp(0, _layout.sheets.length - 1);
      final shown = _layout.sheets[_sheetIndex];
      if (shown.isPage) _currentPage = shown.page;
      // The bookmark flag still describes the page we just left; the button
      // must not act on it before the new page's own state arrives.
      _bookmarkKnown = false;
    });
    _updateBookmarkStatus();
    _scheduleAutoSave();
    _loadPageHighlights();
  }

  /// Jumps straight to a content page (slider, TOC, search, bookmark): the
  /// sheet in front of it — its flyleaf — is skipped, because a jump is not
  /// a page-by-page turn.
  void _jumpToPage(int page) {
    if (_pages.isEmpty) return;
    setState(() {
      _currentPage = page.clamp(0, _pages.length - 1);
      _sheetIndex = _layout.sheetForPage(_currentPage);
      _bookmarkKnown = false;
    });
    _updateBookmarkStatus();
    _scheduleAutoSave();
    _loadPageHighlights();
  }

  void _goToNextPage() {
    if (_isNavigating) return;
    final next = _layout.stepForward(_sheetIndex);
    if (next == null) return;
    _isNavigating = true;
    _setSheet(next);
    trackReadingPage(ref, 1);
    Future.delayed(
        const Duration(milliseconds: 300), () => _isNavigating = false);
  }

  void _goToPrevPage() {
    if (_isNavigating) return;
    final previous = _layout.stepBack(_sheetIndex);
    if (previous == null) return;
    _isNavigating = true;
    _setSheet(previous);
    Future.delayed(
        const Duration(milliseconds: 300), () => _isNavigating = false);
  }

  void _copyCurrentPage() {
    final pages = _paginateContent();
    if (_currentPage >= pages.length) return;
    Clipboard.setData(ClipboardData(text: pages[_currentPage]));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('متن صفحه کپی شد'), duration: Duration(seconds: 2)),
      );
    }
  }

  List<String> _paginateContent() {
    // متن صفحات واقعی (مرز صفحات چاپی) — سخت‌افزاری و بدون بازمحاسبه.
    return [for (final p in _pages) p.text];
  }

  void _toggleBookmark() {
    if (_isBookmarked) {
      ref
          .read(bookBookmarkProvider(widget.book.id).notifier)
          .toggleBookmark(_currentPage);
      setState(() => _isBookmarked = false);
      return;
    }
    final noteCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final prov = ref.read(bookBookmarkProvider(widget.book.id).notifier);
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.bookmark_add,
                      color: TimeThemeKit.of(context).palette.primary),
                  const SizedBox(width: 8),
                  Text('نشانک صفحه ${_currentPage + 1}',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 15),
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTheme.fontFamily)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'بستن',
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'یادداشت (اختیاری)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: TextStyle(fontFamily: AppTheme.fontFamily),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      prov.addBookmark(_currentPage);
                      setState(() => _isBookmarked = true);
                      Navigator.pop(ctx);
                    },
                    child: Text('بدون یادداشت',
                        style: TextStyle(fontFamily: AppTheme.fontFamily)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.bookmark, size: 16),
                    onPressed: () {
                      final note = noteCtrl.text.trim();
                      prov.addBookmark(_currentPage,
                          note: note.isEmpty ? null : note);
                      setState(() => _isBookmarked = true);
                      Navigator.pop(ctx);
                    },
                    label: Text('ذخیره',
                        style: TextStyle(fontFamily: AppTheme.fontFamily)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // Deferred one frame: the sheet's TextField disposes itself in this
      // frame's finalizeTree — disposing earlier races with it.
      WidgetsBinding.instance.addPostFrameCallback((_) => noteCtrl.dispose());
    });
  }

  Future<void> _updateBookmarkStatus() async {
    final bookmarkProv =
        ref.read(bookBookmarkProvider(widget.book.id).notifier);
    final page = _currentPage;
    final bookmarked = await bookmarkProv.isPageBookmarked(page);
    if (!mounted) return;
    setState(() {
      if (page != _currentPage) return;
      _isBookmarked = bookmarked;
      _bookmarkKnown = true;
    });
  }

  void _scheduleAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && widget.book.pageCount > 0) {
        final pages = _paginateContent();
        if (pages.isNotEmpty) {
          ref.read(bookProvider.notifier).updateProgress(
              widget.book.id, _currentPage.clamp(0, pages.length - 1),
              totalPages: pages.length);
        }
      }
    });
  }

  // Arabic matching delegates to the shared forgiving normalizer so the
  // library, reader and duas all match the same way.
  static String _normalizeArabic(String text) => normalizeForSearch(text);

  /// Every page's folded text, built on first use and kept until the book
  /// changes.
  List<String> _foldedPagesFor() {
    final cached = _foldedPages;
    if (cached != null) return cached;
    final folded = [
      for (final page in _paginateContent())
        _normalizeArabic(page.toLowerCase()),
    ];
    return _foldedPages = folded;
  }

  List<int> _matchesFor(String query) {
    final normalizedQuery = _normalizeArabic(query.toLowerCase());
    if (normalizedQuery.isEmpty) return const [];
    final folded = _foldedPagesFor();
    return [
      for (var i = 0; i < folded.length; i++)
        if (folded[i].contains(normalizedQuery)) i,
    ];
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    // Clearing is instant — an empty field has nothing to scan, and the reader
    // expects the highlights gone the moment the text is.
    if (query.isEmpty) {
      setState(() {
        _searchQuery = query;
        _searchMatches.clear();
        _currentMatchIndex = 0;
      });
      return;
    }
    setState(() => _searchQuery = query);
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final matches = _matchesFor(query);
      setState(() {
        // The field may have moved on while this was queued.
        if (_searchQuery != query) return;
        _searchMatches
          ..clear()
          ..addAll(matches);
        _currentMatchIndex = 0;
      });
      if (_searchMatches.isNotEmpty && _searchQuery == query) {
        _goToSearchMatch(0);
      }
    });
  }

  void _goToSearchMatch(int index) {
    if (_searchMatches.isEmpty) return;
    final idx = index.clamp(0, _searchMatches.length - 1);
    setState(() => _currentMatchIndex = idx);
    _jumpToPage(_searchMatches[idx]);
  }

  void _goToNextMatch() {
    if (_searchMatches.isEmpty) return;
    final next = _currentMatchIndex + 1;
    _goToSearchMatch(next >= _searchMatches.length ? 0 : next);
  }

  void _goToPrevMatch() {
    if (_searchMatches.isEmpty) return;
    final prev = _currentMatchIndex - 1;
    _goToSearchMatch(prev < 0 ? _searchMatches.length - 1 : prev);
  }

  Future<void> _loadPageHighlights() async {
    final pages = _paginateContent();
    final shown = _sheetPage;
    final highlights =
        await _highlightService.getPageHighlights(widget.book.id, shown);
    if (!mounted) return;
    if (shown < pages.length) {
      _highlightTextController.text = pages[shown];
    }
    setState(() {
      _pageHighlights = highlights;
    });
  }

  Future<void> _shareCurrentPage() async {
    final pages = _paginateContent();
    if (_currentPage >= pages.length) return;
    await SharePlus.instance.share(
      ShareParams(
          text: pages[_currentPage],
          subject: '${widget.book.title} - صفحه ${_currentPage + 1}'),
    );
  }

  void _showTableOfContents() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, sc) => BookReaderTocSheet(
          pages: _pages,
          entries: _toc,
          volumes: _volumes,
          volumeStarts: _volumeStarts,
          currentPage: _currentPage,
          scrollController: sc,
          onTap: _jumpToPage,
        ),
      ),
    );
  }

  void _showSearchResults() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, sc) => BookReaderSearchSheet(
          pages: _pages,
          matches: _searchMatches,
          query: _searchQuery,
          currentPage: _currentPage,
          scrollController: sc,
          onTap: (index) {
            _jumpToPage(index);
            _loadPageHighlights();
          },
        ),
      ),
    );
  }

  /// Highlighting straight from the page's own text menu.
  ///
  /// The colour picker is the same six swatches the highlight bar offers; the
  /// point is that the reader no longer has to switch on a mode first.
  Future<void> _highlightRange(int page, int start, int end) async {
    if (end <= start) return;
    final color = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: _paper.surface,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رنگ هایلایت',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(ctx, 14),
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTheme.fontFamily)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  for (final c in BookPalette.highlights)
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, c),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _paper.ink.withValues(alpha: 0.15)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (color == null) return;
    await _highlightService.addHighlight(BookHighlight(
      bookId: widget.book.id,
      page: page,
      startOffset: start,
      endOffset: end,
      color: color,
    ));
    await _loadPageHighlights();
  }

  void _showBookmarkList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, sc) => BookReaderBookmarkSheet(
          bookId: widget.book.id,
          scrollController: sc,
          onPageTap: _jumpToPage,
        ),
      ),
    );
  }

  Widget _buildHighlightBar() {
    final isHighlighted = _pageHighlights.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _paper.surface,
        border:
            Border(top: BorderSide(color: _paper.ink.withValues(alpha: 0.12))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.highlight_alt,
                  size: 16, color: TimeThemeKit.of(context).palette.primary),
              const SizedBox(width: 6),
              Text(
                  isHighlighted
                      ? '${_pageHighlights.length} هایلایت'
                      : 'متن را انتخاب کنید سپس روی رنگ ضربه بزنید',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: _paper.ink.withValues(alpha: 0.65),
                      fontFamily: AppTheme.fontFamily)),
              const Spacer(),
              if (isHighlighted)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  onPressed: () async {
                    for (final h in _pageHighlights) {
                      await _highlightService.removeHighlight(widget.book.id,
                          _sheetPage, h.startOffset, h.endOffset);
                    }
                    _loadPageHighlights();
                  },
                  label: Text('حذف همه',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontFamily: AppTheme.fontFamily)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: BookPalette.highlights.map((c) {
                final sameColor =
                    _pageHighlights.where((h) => h.color == c).toList();
                final isActive = sameColor.isNotEmpty;
                return GestureDetector(
                  onTap: () async {
                    if (isActive) {
                      for (final h in sameColor) {
                        await _highlightService.removeHighlight(widget.book.id,
                            _sheetPage, h.startOffset, h.endOffset);
                      }
                      _loadPageHighlights();
                    } else {
                      final sel = _lastTextSelection;
                      if (!sel.isValid || sel.isCollapsed) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'لطفاً ابتدا متن مورد نظر را انتخاب کنید'),
                                duration: Duration(seconds: 2)),
                          );
                        }
                        return;
                      }
                      await _highlightService.addHighlight(BookHighlight(
                        bookId: widget.book.id,
                        page: _lastSelectionPage,
                        startOffset: sel.start,
                        endOffset: sel.end,
                        color: c,
                      ));
                      _loadPageHighlights();
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? TimeThemeKit.of(context).palette.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isActive
                        ? const Icon(Icons.check,
                            size: 18, color: Colors.black54)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisplaySettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => BookReaderDisplaySettings(
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          fontFamily: _fontFamily,
          paperKey: _paperKey,
          marginStep: _marginStep,
          justify: _justify,
          footnoteMode: _footnoteMode,
          mirrorMargin: _mirrorMargin,
          chapterRecto: _chapterRecto,
          titlePage: _titlePage,
          onMirrorMarginChanged: (on) {
            setModalState(() => _mirrorMargin = on);
            _saveDisplayPrefs();
            _rebuildLayout();
          },
          onChapterRectoChanged: (on) {
            setModalState(() => _chapterRecto = on);
            _saveDisplayPrefs();
            _rebuildLayout();
          },
          onPageTitleChanged: (on) {
            setModalState(() => _titlePage = on);
            _saveDisplayPrefs();
            _rebuildLayout();
          },
          onFootnoteModeChanged: (mode) {
            setModalState(() => _footnoteMode = mode);
            _saveDisplayPrefs();
          },
          onFontSizeChanged: (v) {
            setModalState(() => _fontSize = v);
            _saveDisplayPrefs();
          },
          onLineHeightChanged: (v) {
            setModalState(() => _lineHeight = v);
            _saveDisplayPrefs();
          },
          onFontFamilyChanged: (family) {
            setModalState(() => _fontFamily = family);
            _saveDisplayPrefs();
          },
          onPaperChanged: (key) {
            setModalState(() => _paperKey = key);
            _saveDisplayPrefs();
          },
          onMarginChanged: (step) {
            setModalState(() => _marginStep = step);
            _saveDisplayPrefs();
          },
          onJustifyChanged: (on) {
            setModalState(() => _justify = on);
            _saveDisplayPrefs();
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}

/// Decompresses, decodes and parses a book's content file entirely on a
/// background isolate (via `compute`).
Map<String, dynamic> _decodeBookFile(Uint8List bytes) {
  final decompressed = gzip.decode(bytes);
  final jsonStr = utf8.decode(decompressed);
  return json.decode(jsonStr) as Map<String, dynamic>;
}
