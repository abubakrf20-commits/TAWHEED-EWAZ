import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
// Shown selectively: this file also imports hadith_books_service.dart, which
// defines its own HadithChapter — a plain import would make that name
// ambiguous.
import 'package:tawheeed/features/hadith/domain/entities/hadith.dart'
    show HadithGrade, HadithGradeExtension, parseHadithGrade;
import 'package:tawheeed/features/hadith/services/hadith_books_service.dart';
import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';
import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/widgets/content_database_delete_dialog.dart';

// ═══════════════════════════════════════════════════════════════
//  HADITH BOOKS HOME — 3 categories, 17 books
// ═══════════════════════════════════════════════════════════════

class HadithBooksScreen extends StatefulWidget {
  const HadithBooksScreen({super.key});

  @override
  State<HadithBooksScreen> createState() => _HadithBooksScreenState();
}

class _HadithBooksScreenState extends State<HadithBooksScreen> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  /// The last global search threw. Rendered as a named failure with a retry,
  /// instead of the blank page the old `_searchResults == null` branch drew.
  bool _searchFailed = false;
  List<({HadithBookMeta book, HadithEntry hadith})>? _searchResults;
  Timer? _debounce;

  bool _dbChecking = true;
  bool _dbMissing = false;
  bool _dbDownloading = false;
  bool _dbDeleting = false;
  String? _dbError;
  double _dbProgress = 0;

  @override
  void initState() {
    super.initState();
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    setState(() {
      _dbChecking = true;
      _dbError = null;
    });
    try {
      if (!await HadithDbService.isDownloaded()) {
        if (mounted) {
          setState(() {
            _dbChecking = false;
            _dbMissing = true;
          });
        }
        return;
      }
      await HadithDbService().init();
      if (mounted) {
        setState(() {
          _dbChecking = false;
          _dbMissing = false;
        });
      }
    } catch (e) {
      AppLogger.warning('hadith_books_screen', 'error: $e');
      if (mounted) {
        setState(() {
          _dbChecking = false;
          _dbMissing = true;
          _dbError = '$e';
        });
      }
    }
  }

  Future<void> _downloadDatabase() async {
    setState(() {
      _dbDownloading = true;
      _dbError = null;
      _dbProgress = 0;
    });
    try {
      await HadithDbService.download(onProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          _dbProgress = total > 0 ? received / total : 0;
        });
      });
      await HadithDbService().init();
      if (mounted) {
        setState(() {
          _dbDownloading = false;
          _dbMissing = false;
        });
      }
    } catch (e) {
      AppLogger.warning('hadith_books_screen', 'error: $e');
      if (mounted) {
        setState(() {
          _dbDownloading = false;
          _dbError = '$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Removes the downloaded hadith database; the page falls back to its
  /// download prompt, which is also how the data comes back.
  Future<void> _deleteDatabase() async {
    final ok = await confirmContentDatabaseDelete(context, name: 'کتب حدیث');
    if (!ok || !mounted) return;
    setState(() => _dbDeleting = true);
    await HadithDbService.deleteDownloaded();
    if (!mounted) return;
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _dbDeleting = false;
      _dbMissing = true;
      _dbError = null;
      _searchQuery = '';
      _searchResults = null;
      _searching = false;
      _searchFailed = false;
    });
    AppSnackBar.success(context, 'دادهٔ کتب حدیث حذف شد.');
  }

  void _onSearchChanged(String v) {
    setState(() => _searchQuery = v);
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _searching = false;
        _searchFailed = false;
      });
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _performGlobalSearch(v));
  }

  Future<void> _performGlobalSearch(String query) async {
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final results = await HadithBooksService().search(query, limit: 30);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      AppLogger.warning('hadith_books_screen', 'error: $e');
      if (!mounted) return;
      // `_searchResults` stays null — but the body now distinguishes
      // "nothing found" from "the search never ran".
      setState(() {
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'كتب السنة',
        actions: [
          if (!_dbChecking && !_dbMissing && _dbError == null) ...[
            IconButton(
              icon: const Icon(Icons.shuffle, size: 20),
              tooltip: 'حدیث تصادفی',
              onPressed: _showRandomHadith,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: 'حذف داده‌های دانلودشده',
              onPressed: _dbDeleting ? null : _deleteDatabase,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'جستجو در تمام متون احادیث...',
                hintStyle: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    fontFamily: AppTheme.fontFamily),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'پاک کردن جستجو',
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1A1410).withValues(alpha: 0.06)
                    : const Color(0xFF3E2723).withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_dbChecking) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_dbMissing || _dbError != null) {
      return _buildDownloadPrompt();
    }
    return _buildContent();
  }

  Widget _buildDownloadPrompt() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_download_outlined,
                size: 56, color: AppTheme.goldRich),
            const SizedBox(height: 16),
            Text('دادهٔ احادیث دانلود نشده است',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTheme.fontFamily,
                )),
            const SizedBox(height: 8),
            Text(
              'برای استفاده از 17 کتاب حدیث و جستجو در بیش از 80 هزار حدیث، '
              'دادهٔ احادیث (حدود 16 مگابایت) را یک‌بار دانلود کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: TimeThemeKit.of(context).palette.textMuted,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(height: 20),
            if (_dbDownloading) ...[
              SizedBox(
                width: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: _dbProgress),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'در حال دانلود… ${(_dbProgress * 100).toStringAsFixed(0)}٪',
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: TimeThemeKit.of(context).palette.textMuted,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ] else
              FilledButton.icon(
                onPressed: _downloadDatabase,
                icon: const Icon(Icons.download),
                label: const Text('دانلود دادهٔ احادیث'),
              ),
            if (_dbError != null) ...[
              const SizedBox(height: 12),
              // Inline: the download panel is still on screen and still has its
              // own button, so this only has to say what went wrong.
              FailureView(
                id: 'hadith_db_download',
                title: 'دانلود دادهٔ احادیث کامل نشد',
                onRetry: _downloadDatabase,
                layout: FailureLayout.inline,
                icon: Icons.cloud_off,
                error: _dbError,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_searchQuery.isEmpty) {
      return _buildCategorizedView();
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchFailed) {
      return FailureView(
        id: 'hadith_search',
        title: 'جست‌وجو انجام نشد',
        detail: 'پایگاه‌دادهٔ احادیث پاسخ نداد. نتیجه‌ای که می‌بینید ناقص است، '
            'نه اینکه حدیثی پیدا نشده باشد.',
        onRetry: () => _performGlobalSearch(_searchQuery),
        layout: FailureLayout.page,
        icon: Icons.cloud_off,
      );
    }
    if (_searchResults == null) {
      return const SizedBox.shrink();
    }
    if (_searchResults!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48, color: TimeThemeKit.of(context).palette.textMuted),
            const SizedBox(height: 12),
            Text('نتیجه‌ای یافت نشد',
                style: TextStyle(
                    color: TimeThemeKit.of(context).palette.textMuted,
                    fontFamily: AppTheme.fontFamily)),
          ],
        ),
      );
    }
    return _buildSearchResults();
  }

  Widget _buildCategorizedView() {
    final cats = HadithBooksService.categories;
    final flatItems = cats.expand((cat) {
      final metas = HadithBooksService.getAllMeta(category: cat.key);
      return [
        _CategoryHeader(labelAr: cat.labelAr),
        const SizedBox(height: 8),
        ...metas
            .map((meta) => _BookCard(meta: meta, onTap: () => _openBook(meta))),
        const SizedBox(height: 16),
      ];
    }).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 8, DsSpacing.page, 24),
      itemCount: flatItems.length,
      itemBuilder: (ctx, i) => flatItems[i],
    );
  }

  Widget _buildSearchResults() {
    final results = _searchResults!;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 8, DsSpacing.page, 24),
      itemCount: results.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${results.length} نتیجه',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: TimeThemeKit.of(context).palette.textMuted,
                    fontFamily: AppTheme.fontFamily)),
          );
        }
        final item = results[i - 1];
        return _SearchResultRow(
          hadith: item.hadith,
          bookMeta: item.book,
          query: _searchQuery,
          onTap: () => _openHadith(item.hadith, item.book),
        );
      },
    );
  }

  void _openHadith(HadithEntry hadith, HadithBookMeta meta, {String? query}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HadithDetailSheet(
        hadith: hadith,
        bookMeta: meta,
        query: query ?? _searchQuery,
      ),
    );
  }

  void _openBook(HadithBookMeta meta) {
    // Phase-6 audit F2a: the detail screen is a transparent scaffold pushed
    // outside the router — wrap it here so it never paints the bare window.
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AmbientBackground(
            child: HadithBookDetailScreen(meta: meta),
          ),
        ));
  }

  Future<void> _showRandomHadith() async {
    try {
      final result = await HadithBooksService().getRandomHadith();
      if (result == null || !mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _HadithDetailSheet(
          hadith: result.hadith,
          bookMeta: result.book,
        ),
      );
    } catch (e) {
      AppLogger.warning('hadith_books_screen', 'error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('باز کردن این حدیث ممکن نشد؛ دوباره تلاش کنید.')),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  CATEGORY HEADER
// ═══════════════════════════════════════════════════════════════

class _CategoryHeader extends StatelessWidget {
  final String labelAr;
  const _CategoryHeader({required this.labelAr});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:
            AppTheme.goldRich.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppTheme.goldRich.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories,
              size: 18, color: AppTheme.goldRich),
          const SizedBox(width: 8),
          Text(labelAr,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 14),
                fontWeight: FontWeight.w700,
                color: AppTheme.goldRich,
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BOOK CARD
// ═══════════════════════════════════════════════════════════════

class _BookCard extends StatelessWidget {
  final HadithBookMeta meta;
  final VoidCallback onTap;
  const _BookCard({required this.meta, required this.onTap});

  IconData get _categoryIcon => switch (meta.category) {
        'forties' => Icons.format_list_numbered_rtl,
        'other_books' => Icons.menu_book,
        'the_9_books' => Icons.library_books,
        _ => Icons.book,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: TimeThemeKit.of(context).palette.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: TopicHues.hadithBooks.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon,
                      color: TopicHues.hadithBooks, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meta.titleArabic,
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            color: TimeThemeKit.of(context).palette.textPrimary,
                          ),
                          textDirection: TextDirection.rtl),
                      const SizedBox(height: 2),
                      Text(meta.authorArabic,
                          style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: TimeThemeKit.of(context).palette.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            TopicHues.hadithBooks.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${meta.hadithCount} حدیث',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w600,
                              color: TopicHues.hadithBooks,
                              fontFamily: AppTheme.fontFamily)),
                    ),
                    const SizedBox(height: 4),
                    Text('${meta.chapterCount} باب',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            color: TimeThemeKit.of(context).palette.textMuted,
                            fontFamily: AppTheme.fontFamily)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BOOK DETAIL SCREEN — chapters + full hadiths
// ═══════════════════════════════════════════════════════════════

class HadithBookDetailScreen extends StatefulWidget {
  final HadithBookMeta meta;
  const HadithBookDetailScreen({super.key, required this.meta});

  @override
  State<HadithBookDetailScreen> createState() => _HadithBookDetailScreenState();
}

class _HadithBookDetailScreenState extends State<HadithBookDetailScreen> {
  HadithFullBook? _book;
  Map<num, int> _counts = {};
  int _totalCount = 0;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBook() async {
    try {
      final book = await HadithBooksService().loadBook(widget.meta.key);
      final counts =
          await HadithBooksService().chapterHadithCounts(widget.meta.key);
      if (!mounted) return;
      setState(() {
        _book = book;
        _counts = counts;
        _totalCount = counts.values.fold(0, (a, b) => a + b);
        _loading = false;
      });
    } catch (e) {
      AppLogger.warning('hadith_books_screen', 'error: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: widget.meta.titleArabic,
        actions: [
          if (_book != null)
            IconButton(
              icon: const Icon(Icons.search, size: 20),
              tooltip: 'جستجوی کتاب‌ها',
              onPressed: _showSearchDialog,
            ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'کپی فهرست',
            onPressed: _book != null ? _copyChapterList : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return FailureView(
      id: 'hadith_book_load',
      title: 'کتاب باز نشد',
      detail: 'متن کتاب همراه برنامه ذخیره شده است؛ فقط خواندنش ناموفق بود.',
      onRetry: () {
        setState(() {
          _loading = true;
          _error = null;
        });
        _loadBook();
      },
      layout: FailureLayout.page,
      error: _error,
    );
  }

  Widget _buildContent() {
    final book = _book!;
    final itemCount = 2 + book.chapters.length;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TopicHues.hadithBooks.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: TopicHues.hadithBooks.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.metadata.titleArabic,
                    style: TextStyle(
                        fontSize: AppTheme.scaledFontSize(context, 18),
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTheme.fontFamily),
                    textDirection: TextDirection.rtl),
                if (book.metadata.authorArabic.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(book.metadata.authorArabic,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: TimeThemeKit.of(context).palette.textSecondary,
                          fontFamily: AppTheme.fontFamily),
                      textDirection: TextDirection.rtl),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  _statChip('$_totalCount حدیث'),
                  const SizedBox(width: 8),
                  _statChip('${book.chapters.length} باب'),
                ]),
              ],
            ),
          );
        }

        if (index == 1) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              tileColor: TopicHues.hadithBooks.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.all_inclusive,
                  color: TopicHues.hadithBooks),
              title: Text('همه احادیث',
                  style: TextStyle(
                      color: TopicHues.hadithBooks,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontFamily)),
              trailing: Text('$_totalCount',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: TimeThemeKit.of(context).palette.textMuted,
                      fontFamily: AppTheme.fontFamily)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AmbientBackground(
                      child: HadithListAllScreen(
                        bookMeta: book.metadata,
                        bookId: book.id,
                      ),
                    ),
                  )),
            ),
          );
        }

        final ch = book.chapters[index - 2];
        final count = _counts[ch.id] ?? 0;
        return _ChapterTile(
          chapter: ch,
          hadithCount: count,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AmbientBackground(
                  child: HadithChapterScreen(
                    bookMeta: book.metadata,
                    bookId: book.id,
                    chapter: ch,
                  ),
                ),
              )),
        );
      },
    );
  }

  Widget _statChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: TopicHues.hadithBooks.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: TopicHues.hadithBooks,
              fontWeight: FontWeight.w600,
              fontFamily: AppTheme.fontFamily)),
    );
  }

  void _copyChapterList() {
    final text =
        _book!.chapters.map((ch) => '${ch.id}. ${ch.arabic}').join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('فهرست فصول کپی شد'), duration: Duration(seconds: 1)),
    );
  }

  void _showSearchDialog() {
    _searchCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('جستجو در ${widget.meta.titleArabic}',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
        content: TextField(
          controller: _searchCtrl,
          textDirection: TextDirection.rtl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'جستجو در متن عربی...',
            hintStyle: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontFamily: AppTheme.fontFamily),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            onPressed: () {
              final q = _searchCtrl.text.trim();
              Navigator.pop(ctx);
              if (q.isNotEmpty) _performSearch(q);
            },
            child: const Text('جستجو'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    try {
      final results =
          await HadithBooksService().searchInBook(widget.meta.key, query);
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نتیجه‌ای یافت نشد')),
        );
        return;
      }
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AmbientBackground(
              child: HadithSearchResultsScreen(
                results: results,
                bookMeta: widget.meta,
                query: query,
              ),
            ),
          ));
    } catch (e) {
      AppLogger.warning('hadith_books_screen', 'error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('باز کردن این حدیث ممکن نشد؛ دوباره تلاش کنید.')),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  CHAPTER TILE
// ═══════════════════════════════════════════════════════════════

class _ChapterTile extends StatelessWidget {
  final HadithChapter chapter;
  final int hadithCount;
  final VoidCallback onTap;
  const _ChapterTile(
      {required this.chapter, required this.hadithCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: TopicHues.hadithBooks.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text('${chapter.id}',
              style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 12),
                  color: TopicHues.hadithBooks,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily)),
        ),
        title: Text(
          chapter.arabic,
          textDirection: TextDirection.rtl,
          style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 14),
              fontFamily: AppTheme.fontFamily),
        ),
        trailing: Text('$hadithCount',
            style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 11),
                color: TimeThemeKit.of(context).palette.textMuted,
                fontFamily: AppTheme.fontFamily)),
        onTap: onTap,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ALL HADITHS LIST (paginated)
// ═══════════════════════════════════════════════════════════════

class HadithListAllScreen extends StatefulWidget {
  final HadithBookMeta bookMeta;
  final int bookId;
  const HadithListAllScreen(
      {super.key, required this.bookMeta, required this.bookId});

  @override
  State<HadithListAllScreen> createState() => _HadithListAllScreenState();
}

class _HadithListAllScreenState extends State<HadithListAllScreen> {
  static const _pageSize = 30;
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  /// The next page threw; the footer says so instead of offering the same
  /// button that just failed.
  bool _loadMoreFailed = false;
  final List<HadithEntry> _displayed = [];

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await HadithBooksService().loadBookHadiths(
        widget.bookMeta.key,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _displayed.addAll(next);
        _offset += next.length;
        _hasMore = next.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      AppLogger.warning('hadith_books_screen', 'load more failed: $e');
      if (!mounted) return;
      // `_hasMore` used to stay true, so the button reappeared and every tap
      // repeated the same silent failure.
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: widget.bookMeta.titleArabic,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.page, 8, DsSpacing.page, 24),
        itemCount: _displayed.length + (_hasMore || _loadMoreFailed ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _displayed.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : _loadMoreFailed
                        ? FailureView(
                            id: 'hadith_load_more',
                            title: 'بارگذاری بقیهٔ احادیث ناموفق بود',
                            onRetry: () {
                              setState(() {
                                _loadMoreFailed = false;
                                _hasMore = true;
                              });
                              _loadMore();
                            },
                            layout: FailureLayout.inline,
                          )
                        : TextButton(
                            onPressed: _loadMore,
                            child: Text('بارگذاری بیشتر',
                                style: TextStyle(
                                    fontFamily: AppTheme.fontFamily)),
                          ),
              ),
            );
          }
          return _HadithCard(
            hadith: _displayed[i],
            bookMeta: widget.bookMeta,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CHAPTER HADITHS LIST
// ═══════════════════════════════════════════════════════════════

class HadithChapterScreen extends StatefulWidget {
  final HadithBookMeta bookMeta;
  final int bookId;
  final HadithChapter chapter;

  /// The entry (its stored `hadith_number`) a deep-search hit came from; the
  /// chapter scrolls to it once its rows are on screen.
  final int? initialHadithNumber;

  /// The literal the search matched — painted in the entries, and the fallback
  /// anchor when the row carries no number.
  final String initialQuery;

  const HadithChapterScreen(
      {super.key,
      required this.bookMeta,
      required this.bookId,
      required this.chapter,
      this.initialHadithNumber,
      this.initialQuery = ''});

  @override
  State<HadithChapterScreen> createState() => _HadithChapterScreenState();
}

class _HadithChapterScreenState extends State<HadithChapterScreen> {
  List<HadithEntry>? _hadiths;

  /// The chapter query threw. Kept apart from `_hadiths.isEmpty`, because an
  /// empty chapter and a failed read are two different statements and only one
  /// of them is true.
  bool _chapterFailed = false;
  final _itemCtrl = ItemScrollController();
  int? _focusIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _retry() {
    setState(() => _chapterFailed = false);
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await HadithBooksService()
          .loadChapterHadiths(widget.bookMeta.key, widget.chapter.id);
      if (!mounted) return;
      setState(() {
        _hadiths = rows;
        _chapterFailed = false;
        _focusIndex = _targetIndex(rows);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _focusIndex;
        if (!mounted || target == null || !_itemCtrl.isAttached) return;
        _itemCtrl.jumpTo(index: target, alignment: 0.02);
      });
    } catch (e) {
      AppLogger.warning('hadith_books_screen', 'chapter load failed: $e');
      if (!mounted) return;
      // `_hadiths = const []` made the body print «حدیثی یافت نشد» — a load
      // failure reported as a fact about the chapter. The error state is
      // separate, and offers the retry.
      setState(() => _chapterFailed = true);
    }
  }

  /// The row a deep-search hit named: its stored `hadith_number` first, and
  /// when the row carries none (or it is absent here) the first entry whose
  /// text still matches the literal under the painter's own normalizer.
  int? _targetIndex(List<HadithEntry> rows) {
    final number = widget.initialHadithNumber;
    if (number != null) {
      final i = rows.indexWhere((e) => e.idInBook == number);
      if (i >= 0) return i;
    }
    if (widget.initialQuery.trim().isEmpty) return null;
    final i = rows.indexWhere(
        (e) => TextHighlight.findMatches(e.arabic, widget.initialQuery).isNotEmpty);
    return i < 0 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    final hadiths = _hadiths;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: widget.chapter.arabic,
      ),
      body: _chapterFailed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 44, color: TimeThemeKit.of(context).palette.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'باب باز نشد',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w700,
                        color: TimeThemeKit.of(context).palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'خواندن احادیث این باب ناموفق بود.',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11.5),
                        color: TimeThemeKit.of(context).palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _retry,
                      child: const Text('تلاش دوباره'),
                    ),
                  ],
                ),
              ),
            )
          : hadiths == null
          ? const Center(child: CircularProgressIndicator())
          : hadiths.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book,
                          size: 48, color: TimeThemeKit.of(context).palette.outline),
                      const SizedBox(height: 12),
                      Text('حدیثی یافت نشد',
                          style: TextStyle(
                              color: TimeThemeKit.of(context).palette.textMuted,
                              fontFamily: AppTheme.fontFamily)),
                    ],
                  ),
                )
              : ScrollablePositionedList.builder(
                  itemScrollController: _itemCtrl,
                  padding: const EdgeInsets.fromLTRB(
                      DsSpacing.page, 8, DsSpacing.page, 24),
                  itemCount: hadiths.length,
                  itemBuilder: (ctx, i) => _HadithCard(
                    hadith: hadiths[i],
                    bookMeta: widget.bookMeta,
                    highlightQuery: widget.initialQuery,
                    autoExpand: i == _focusIndex,
                  ),
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SEARCH RESULTS SCREEN
// ═══════════════════════════════════════════════════════════════

class HadithSearchResultsScreen extends StatelessWidget {
  final List<HadithEntry> results;
  final HadithBookMeta bookMeta;
  final String query;
  const HadithSearchResultsScreen({
    super.key,
    required this.results,
    required this.bookMeta,
    required this.query,
  });

  void _openHadith(BuildContext context, HadithEntry hadith) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HadithDetailSheet(
        hadith: hadith,
        bookMeta: bookMeta,
        query: query,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'نتایج: $query',
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.page, 8, DsSpacing.page, 24),
        itemCount: results.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${results.length} نتیجه',
                  style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: TimeThemeKit.of(context).palette.textMuted,
                      fontFamily: AppTheme.fontFamily)),
            );
          }
          final h = results[i - 1];
          return _SearchResultRow(
            hadith: h,
            bookMeta: null,
            query: query,
            onTap: () => _openHadith(context, h),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SEARCH RESULT ROW — one-line snippet with the query highlighted
// ═══════════════════════════════════════════════════════════════

class _SearchResultRow extends StatelessWidget {
  final HadithEntry hadith;
  final HadithBookMeta?
      bookMeta; // when set, shows the book name chip (global search)
  final String query;
  final VoidCallback onTap;
  const _SearchResultRow({
    required this.hadith,
    required this.bookMeta,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Choose the field that actually contains the match so the highlighted
    // word is visible right in the result line.
    final snippetText = hadith.arabic;
    const dir = TextDirection.rtl;
    final fontFamily = AppTheme.fontFamily;

    final baseStyle = TextStyle(
      fontSize:
          AppTheme.scaledFontSize(context, dir == TextDirection.rtl ? 15 : 13),
      fontFamily: fontFamily,
      height: 1.7,
      color: TimeThemeKit.of(context).palette.textPrimary,
    );
    final highlightStyle =
        TextHighlight.defaultHighlightStyle(context, base: baseStyle);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: TimeThemeKit.of(context).palette.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (bookMeta != null) ...[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              TopicHues.hadithBooks.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bookMeta!.titleArabic,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              color: TopicHues.hadithBooks,
                              fontFamily: AppTheme.fontFamily),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text('حدیث ${hadith.idInBook}',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: TimeThemeKit.of(context).palette.textMuted,
                          fontFamily: AppTheme.fontFamily)),
                  const Spacer(),
                  Icon(Icons.chevron_left,
                      size: 18, color: TimeThemeKit.of(context).palette.textMuted),
                ],
              ),
              const SizedBox(height: 6),
              // One-line snippet with the searched word shaded.
              Text.rich(
                TextSpan(
                  children: TextHighlight.snippetSpans(
                    snippetText,
                    query,
                    context: 34,
                    baseStyle: baseStyle,
                    highlightStyle: highlightStyle,
                  ),
                ),
                textDirection: dir,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HADITH CARD — expandable, with copy & share
// ═══════════════════════════════════════════════════════════════

class _HadithCard extends StatefulWidget {
  final HadithEntry hadith;
  final HadithBookMeta bookMeta;

  /// The literal a deep search matched — painted wherever it occurs.
  final String highlightQuery;

  /// Opens the card already expanded: the entry the search landed on must show
  /// the match even when it sits past the collapsed 12-line window.
  final bool autoExpand;

  const _HadithCard({
    required this.hadith,
    required this.bookMeta,
    this.highlightQuery = '',
    this.autoExpand = false,
  });

  @override
  State<_HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<_HadithCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.autoExpand;
  }

  /// Check if text likely overflows 12 lines (approximate check).
  bool _isTextOverflowing(String text) {
    // Rough heuristic: Arabic text with average 60 chars per line at size 18
    return text.length > 600;
  }

  Widget _buildArabic(BuildContext context, String text) {
    final style = TextStyle(
        fontSize: AppTheme.scaledFontSize(context, 18),
        fontFamily: AppTheme.fontFamily,
        height: 2.0,
        color: TimeThemeKit.of(context).palette.textPrimary);
    final query = widget.highlightQuery.trim();
    if (query.isEmpty) {
      return Text(
        text,
        textDirection: TextDirection.rtl,
        style: style,
        maxLines: _expanded ? null : 12,
        overflow: _expanded ? null : TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: TextHighlight.spans(
          text,
          query,
          baseStyle: style,
          highlightStyle:
              TextHighlight.defaultHighlightStyle(context, base: style),
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: _expanded ? null : 12,
      overflow: _expanded ? null : TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hadith;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: TimeThemeKit.of(context).palette.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: TopicHues.hadithBooks.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'حدیث ${h.idInBook}',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          color: TopicHues.hadithBooks,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTheme.fontFamily),
                    ),
                  ),
                  const Spacer(),
                  // Copy button
                  IconButton(
                    icon: Icon(Icons.copy_outlined,
                        size: 16, color: TimeThemeKit.of(context).palette.textMuted),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: h.arabic));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('متن عربی کپی شد'),
                            duration: Duration(seconds: 1)),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'کپی',
                  ),
                  const SizedBox(width: 4),
                  // Share button
                  IconButton(
                    icon: Icon(Icons.share_outlined,
                        size: 16, color: TimeThemeKit.of(context).palette.textMuted),
                    onPressed: () {
                      final text =
                          '🕌 ${widget.bookMeta.titleArabic}\n\n${h.arabic}';
                      SharePlus.instance.share(ShareParams(text: text));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'اشتراک',
                  ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: TimeThemeKit.of(context).palette.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              // Arabic text
              _buildArabic(context, h.arabic),
              if (!_expanded && _isTextOverflowing(h.arabic))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'بیشتر...',
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      color: TopicHues.hadithBooks,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HADITH DETAIL SHEET (for random hadith)
// ═══════════════════════════════════════════════════════════════

class _HadithDetailSheet extends StatelessWidget {
  final HadithEntry hadith;
  final HadithBookMeta bookMeta;
  final String? query;
  const _HadithDetailSheet(
      {required this.hadith, required this.bookMeta, this.query});

  Widget _text(BuildContext context, String text, TextStyle style,
      {TextDirection? dir}) {
    final q = query?.trim() ?? '';
    if (q.isEmpty) {
      return Text(text, style: style, textDirection: dir);
    }
    return Text.rich(
      TextSpan(
        children: TextHighlight.spans(
          text,
          q,
          baseStyle: style,
          highlightStyle:
              TextHighlight.defaultHighlightStyle(context, base: style),
        ),
      ),
      textDirection: dir,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: TimeThemeKit.of(context).palette.outline,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          // Book name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: TopicHues.hadithBooks.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${bookMeta.titleArabic}  ·  حدیث ${hadith.idInBook}',
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 13),
                    color: TopicHues.hadithBooks,
                    fontFamily: AppTheme.fontFamily),
                textAlign: TextAlign.center),
          ),
          // Authenticity grade (صحیح / حسن / ضعیف) — only when the DB has one
          if (hadith.grade.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _GradeBadge(raw: hadith.grade),
          ],
          const SizedBox(height: 16),
          // Arabic
          _text(
            context,
            hadith.arabic,
            TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 20),
                fontFamily: AppTheme.fontFamily,
                height: 2.0,
                fontWeight: FontWeight.bold,
                color: TimeThemeKit.of(context).palette.textPrimary),
            dir: TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: hadith.arabic));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('کپی شد'),
                        duration: Duration(seconds: 1)),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text('کپی',
                    style: TextStyle(fontFamily: AppTheme.fontFamily)),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () {
                  final text = '🕌 ${bookMeta.titleArabic}\n\n${hadith.arabic}';
                  SharePlus.instance.share(ShareParams(text: text));
                },
                icon: const Icon(Icons.share, size: 16),
                label: Text('اشتراک',
                    style: TextStyle(fontFamily: AppTheme.fontFamily)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  GRADE BADGE
// ═══════════════════════════════════════════════════════════

/// Small pill showing a hadith's authenticity grade (صحیح / حسن / ضعیف).
///
/// Values that don't map to [HadithGrade] fall back to a neutral pill with
/// the raw text, so nothing is ever hidden — and nothing is invented.
class _GradeBadge extends StatelessWidget {
  final String raw;
  const _GradeBadge({required this.raw});

  @override
  Widget build(BuildContext context) {
    final text = raw.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final grade = parseHadithGrade(text);
    final known = grade != HadithGrade.unknown;
    final color = Color(grade.colorValue);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          known ? grade.label : text,
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 12),
            color: color,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ),
    );
  }
}
