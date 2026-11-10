import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/books/presentation/book_palette.dart';
import 'package:tawheeed/features/books/presentation/providers/book_provider.dart';
import 'package:tawheeed/features/books/services/book_content_service.dart';
import 'package:tawheeed/features/books/data/models/book_model.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

import 'package:tawheeed/core/design_system/ambient_background.dart';
import 'package:tawheeed/core/design_system/components/components.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';

import 'package:tawheeed/shared/widgets/app_empty_state.dart';

import 'package:tawheeed/features/books/presentation/screens/book_reader_screen.dart';
import 'package:tawheeed/features/books/presentation/screens/reading_stats_screen.dart';
import 'package:tawheeed/features/books/presentation/providers/book_bookmark_provider.dart';

class KetabkhanehScreen extends ConsumerStatefulWidget {
  const KetabkhanehScreen({super.key});

  @override
  ConsumerState<KetabkhanehScreen> createState() => _KetabkhanehScreenState();
}

class _KetabkhanehScreenState extends ConsumerState<KetabkhanehScreen>
    with WidgetsBindingObserver {
  String _searchQuery = '';
  String _selectedCategory = 'همه';
  String? _selectedAuthor;

  /// Extra shelf filter from the overflow menu: `favorites`, `recent` or
  /// `reading`. Null means «همه» — the menu rows toggle themselves off.
  String? _libraryView;
  String _sort = 'title'; // title | author | recent
  bool _isGridView = true;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearchingContent = false;
  final Set<String> _contentMatchIds = {};
  final Map<String, List<String>> _contentCache = {};

  /// Decoded book contents for search — capped (LRU) so a library-wide
  /// search can't pin every book's full text in memory at once.
  static const int _contentCacheCap = 3;

  void _cacheContent(String bookId, List<String> content) {
    _contentCache.remove(bookId);
    _contentCache[bookId] = content;
    while (_contentCache.length > _contentCacheCap) {
      _contentCache.remove(_contentCache.keys.first);
    }
  }

  final Map<String, String> _contentSnippets = {};
  int _searchGeneration = 0;
  bool get _isSearchActive => _searchQuery.isNotEmpty && _searchQuery != ' ';
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ref.invalidate(bookProvider));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(bookProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookProvider);
    final notifier = ref.read(bookProvider.notifier);
    if (booksAsync.isLoading && !booksAsync.hasValue) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (booksAsync.hasError) {
      return _buildLoadErrorView(booksAsync.error);
    }
    final books = booksAsync.value ?? [];

    final filteredBooks = _filterBooks(books, notifier);
    final currentlyReading =
        books.where((b) => b.readProgress > 0 && b.readProgress < 1.0).toList();
    final completedBooksList =
        books.where((b) => b.readProgress >= 1.0).toList();
    final recentBooks = books.where((b) => b.lastRead != null).toList()
      ..sort((a, b) => b.lastRead!.compareTo(a.lastRead!));
    final categories = ['همه', ...notifier.categories];
    // نویسنده‌های پرمحتوا (تا 10 مورد) — فیلتر دومی برای محدودکردن گرید.
    final authorCounts = <String, int>{};
    for (final b in books) {
      if (b.author.isNotEmpty) {
        authorCounts[b.author] = (authorCounts[b.author] ?? 0) + 1;
      }
    }
    final topAuthors = authorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final authors = [for (final e in topAuthors.take(10)) e.key];
    final totalBooks = books.length;
    final completedBooks = completedBooksList.length;
    final favoritedCount = notifier.favorites.length;
    final bookmarkedIdsAsync = ref.watch(allBookmarkedIdsProvider);
    final bookmarkedIds = bookmarkedIdsAsync.value ?? <String>{};

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    final danger = isDark ? AppTheme.darkError : AppTheme.lightError;
    final onPrimary = dsOnAccent(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'کتابخانه',
        titleWidget: _searchQuery.isNotEmpty
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 16),
                    fontFamily: AppTheme.fontFamily),
                decoration: InputDecoration(
                  hintText: 'جستجو در کتاب‌ها...',
                  hintStyle: TextStyle(
                      color: TimeThemeKit.of(context).palette.textMuted,
                      fontFamily: AppTheme.fontFamily),
                  border: InputBorder.none,
                ),
                textDirection: TextDirection.rtl,
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(_searchQuery.isNotEmpty ? Icons.close : Icons.search),
            tooltip:
                _searchQuery.isNotEmpty ? 'بستن جستجو' : 'جستجو در کتاب‌ها',
            onPressed: () {
              setState(() {
                if (_searchQuery.isNotEmpty) {
                  _searchQuery = '';
                  _searchCtrl.clear();
                  _contentMatchIds.clear();
                  _searchDebounce?.cancel();
                  _isSearchingContent = false;
                } else {
                  _searchQuery = ' ';
                }
              });
            },
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'نمایش لیستی' : 'نمایش شبکه‌ای',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'بیشتر',
            onSelected: (value) {
              // The three shelf rows are toggles: picking the active one again
              // clears the filter and returns to «همه».
              if (value == 'favorites' ||
                  value == 'recent' ||
                  value == 'reading') {
                setState(
                    () => _libraryView = _libraryView == value ? null : value);
                return;
              }
              if (value == 'stats') {
                // Phase-6 audit F2e: the stats screen is a transparent
                // scaffold pushed outside the router — wrap it here so it
                // never paints the bare (black) window.
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AmbientBackground(
                            child: ReadingStatsScreen())));
              } else if (value == 'sort_title') {
                setState(() => _sort = 'title');
              } else if (value == 'sort_author') {
                setState(() => _sort = 'author');
              } else if (value == 'sort_recent') {
                setState(() => _sort = 'recent');
              }
            },
            itemBuilder: (context) => [
              _viewMenuItem(
                  context, 'favorites', Icons.favorite, 'علاقه‌مندی‌ها'),
              _viewMenuItem(
                  context, 'recent', Icons.history, 'مطالعه شده اخیر'),
              _viewMenuItem(
                  context, 'reading', Icons.auto_stories, 'در حال مطالعه'),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'sort_title',
                child: Row(children: [
                  Icon(
                      _sort == 'title'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color:
                          _sort == 'title' ? TimeThemeKit.of(context).palette.primary : null),
                  const SizedBox(width: 10),
                  const Text('مرتب‌سازی: عنوان')
                ]),
              ),
              PopupMenuItem(
                value: 'sort_author',
                child: Row(children: [
                  Icon(
                      _sort == 'author'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _sort == 'author'
                          ? TimeThemeKit.of(context).palette.primary
                          : null),
                  const SizedBox(width: 10),
                  const Text('مرتب‌سازی: نویسنده')
                ]),
              ),
              PopupMenuItem(
                value: 'sort_recent',
                child: Row(children: [
                  Icon(
                      _sort == 'recent'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _sort == 'recent'
                          ? TimeThemeKit.of(context).palette.primary
                          : null),
                  const SizedBox(width: 10),
                  const Text('مرتب‌سازی: آخرین خوانده‌شده')
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'stats',
                  child: Row(children: [
                    Icon(Icons.bar_chart, size: 20),
                    SizedBox(width: 10),
                    Text('آمار مطالعه')
                  ])),
            ],
          ),
        ],
      ),
      body: filteredBooks.isEmpty &&
              _searchQuery.isNotEmpty &&
              !_isSearchingContent
          ? const AppEmptyState(
              icon: Icons.menu_book_outlined,
              message: 'کتابی یافت نشد',
              subtitle: 'کتاب‌ها را جستجو کنید یا فیلتر را تغییر دهید',
            )
          : CustomScrollView(
              slivers: [
                // Stats row
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: DsSpacing.page, vertical: 8),
                    child: Row(
                      children: [
                        _StatBadge(
                            icon: Icons.menu_book,
                            label: 'کل',
                            value: '$totalBooks',
                            color: TimeThemeKit.of(context).palette.primary),
                        const SizedBox(width: 8),
                        _StatBadge(
                            icon: Icons.check_circle_outline,
                            label: 'تکمیل',
                            value: '$completedBooks',
                            color: success),
                        const SizedBox(width: 8),
                        _StatBadge(
                            icon: Icons.auto_stories,
                            label: 'در حال مطالعه',
                            value: '${currentlyReading.length}',
                            color: TopicHues.ketabkhaneh),
                        const SizedBox(width: 8),
                        _StatBadge(
                            icon: Icons.favorite,
                            label: 'علاقه‌مندی',
                            value: '$favoritedCount',
                            color: danger),
                      ],
                    ),
                  ),
                ),
                // Currently reading section
                if (currentlyReading.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.page, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_stories,
                              size: 16, color: TopicHues.ketabkhaneh),
                          const SizedBox(width: 6),
                          Text('در حال مطالعه',
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w700,
                                  color: TopicHues.ketabkhaneh,
                                  fontFamily: AppTheme.fontFamily)),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: currentlyReading.length,
                        itemBuilder: (context, index) => _CurrentlyReadingCard(
                          book: currentlyReading[index],
                          onTap: () =>
                              _openBook(context, currentlyReading[index]),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
                // Completed books section
                if (completedBooksList.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.page, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 16, color: success),
                          const SizedBox(width: 6),
                          Text('کتاب‌های خوانده شده',
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w700,
                                  color: success,
                                  fontFamily: AppTheme.fontFamily)),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: completedBooksList.length,
                        itemBuilder: (context, index) => _CompletedBookCard(
                          book: completedBooksList[index],
                          onTap: () =>
                              _openBook(context, completedBooksList[index]),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
                // Recently Read section
                if (recentBooks.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.page, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.history,
                              size: 16, color: TimeThemeKit.of(context).palette.primary),
                          const SizedBox(width: 6),
                          Text('مطالعه شده اخیر',
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 13),
                                  fontWeight: FontWeight.w700,
                                  color: TimeThemeKit.of(context).palette.primary,
                                  fontFamily: AppTheme.fontFamily)),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount:
                            recentBooks.length > 5 ? 5 : recentBooks.length,
                        itemBuilder: (context, index) => _CurrentlyReadingCard(
                          book: recentBooks[index],
                          onTap: () => _openBook(context, recentBooks[index]),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
                // Content search indicator
                if (_isSearchingContent)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.page, vertical: 4),
                      child: Row(
                        children: [
                          const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text('در حال جستجو در متن کتاب‌ها...',
                              style: TextStyle(
                                  fontSize: AppTheme.scaledFontSize(context, 12),
                                  color: TimeThemeKit.of(context).palette.textMuted)),
                        ],
                      ),
                    ),
                  ),
                // Category tabs
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = cat == _selectedCategory;
                        final catColor =
                            BookPalette.categoryColors[cat] ?? TimeThemeKit.of(context).palette.primary;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            avatar: cat != 'همه' && cat.isNotEmpty
                                ? Icon(_categoryIcons[cat] ?? Icons.book,
                                    size: 12,
                                    color: isSelected
                                        ? onPrimary
                                        : catColor)
                                : null,
                            label: Center(
                              child: Text(cat,
                                  style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 12),
                                    fontFamily: AppTheme.fontFamily,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? onPrimary
                                        : catColor,
                                  )),
                            ),
                            labelPadding: EdgeInsets.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat),
                            selectedColor: catColor,
                            backgroundColor: catColor.withValues(alpha: 0.08),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Author filter chips
                if (authors.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: authors.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isAll = _selectedAuthor == null;
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(start: 6),
                              child: ChoiceChip(
                                avatar: const Icon(Icons.person, size: 12),
                                label: Text('همهٔ نویسندگان',
                                    style: TextStyle(
                                        fontSize: AppTheme.scaledFontSize(context, 11),
                                        fontFamily: AppTheme.fontFamily,
                                        color: isAll
                                            ? onPrimary
                                            : TimeThemeKit.of(context).palette.textSecondary)),
                                selected: isAll,
                                onSelected: (_) =>
                                    setState(() => _selectedAuthor = null),
                                selectedColor: TimeThemeKit.of(context).palette.primary,
                                backgroundColor: TimeThemeKit.of(context).palette.card,
                                side: BorderSide.none,
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          }
                          final author = authors[index - 1];
                          final isSelected = _selectedAuthor == author;
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(start: 6),
                            child: ChoiceChip(
                              label: Text(author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: AppTheme.scaledFontSize(context, 11),
                                      fontFamily: AppTheme.fontFamily,
                                      color: isSelected
                                          ? onPrimary
                                          : TimeThemeKit.of(context).palette.textSecondary)),
                              selected: isSelected,
                              onSelected: (_) => setState(() =>
                                  _selectedAuthor = isSelected ? null : author),
                              selectedColor: TimeThemeKit.of(context).palette.primary,
                              backgroundColor: TimeThemeKit.of(context).palette.card,
                              side: BorderSide.none,
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                // Personal tags
                if (notifier.allUserTags.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: notifier.allUserTags.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isAll = _selectedTag == null;
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(start: 6),
                              child: ChoiceChip(
                                label: Text('همه',
                                    style: TextStyle(
                                        fontSize: AppTheme.scaledFontSize(context, 11),
                                        fontFamily: AppTheme.fontFamily,
                                        color: isAll
                                            ? onPrimary
                                            : TimeThemeKit.of(context).palette.textSecondary)),
                                selected: isAll,
                                onSelected: (_) =>
                                    setState(() => _selectedTag = null),
                                selectedColor: TopicHues.ketabkhaneh,
                                backgroundColor: TopicHues.ketabkhaneh
                                    .withValues(alpha: 0.08),
                                side: BorderSide.none,
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          }
                          final tag = notifier.allUserTags.elementAt(index - 1);
                          final isSelected = _selectedTag == tag;
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(start: 6),
                            child: ChoiceChip(
                              avatar: const Icon(Icons.label, size: 10),
                              label: Text(tag,
                                  style: TextStyle(
                                      fontSize: AppTheme.scaledFontSize(context, 11),
                                      fontFamily: AppTheme.fontFamily,
                                      color: isSelected
                                          ? onPrimary
                                          : TimeThemeKit.of(context).palette.textSecondary)),
                              selected: isSelected,
                              onSelected: (_) => setState(
                                  () => _selectedTag = isSelected ? null : tag),
                              selectedColor: TopicHues.ketabkhaneh,
                              backgroundColor: TopicHues.ketabkhaneh
                                  .withValues(alpha: 0.08),
                              side: BorderSide.none,
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                // Book count
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: DsSpacing.page, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '${filteredBooks.length} کتاب',
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              color: TimeThemeKit.of(context).palette.textMuted,
                              fontFamily: AppTheme.fontFamily),
                        ),
                        const Spacer(),
                        if (notifier.favorites.isNotEmpty)
                          Text(
                            '${notifier.favorites.length} علاقه‌مندی',
                            style: TextStyle(
                                fontSize: AppTheme.scaledFontSize(context, 12),
                                color: TimeThemeKit.of(context).palette.textMuted,
                                fontFamily: AppTheme.fontFamily),
                          ),
                      ],
                    ),
                  ),
                ),
                // Books grid or list as sliver
                if (filteredBooks.isEmpty)
                  SliverFillRemaining(
                    child: AppEmptyState(
                      icon: Icons.menu_book_outlined,
                      message: 'کتابی یافت نشد',
                      subtitle: _isSearchingContent
                          ? 'در حال جستجو...'
                          : 'کتاب‌ها را جستجو کنید یا فیلتر را تغییر دهید',
                    ),
                  )
                else
                  _isGridView
                      ? _buildGridSliver(context, filteredBooks, bookmarkedIds)
                      : _buildListSliver(context, filteredBooks, bookmarkedIds),
              ],
            ),
    );
  }

  Widget _buildLoadErrorView(Object? error) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SectionAppBar(title: 'کتابخانه'),
      body: FailureView(
        id: 'library_load',
        title: 'بارگذاری کتاب‌ها ناموفق بود',
        detail: 'فهرست از پایگاه‌دادهٔ خودِ برنامه خوانده می‌شود؛ '
            'کتاب‌های دانلودشده جایی نرفته‌اند.',
        onRetry: () => ref.invalidate(bookProvider),
        layout: FailureLayout.page,
        error: error,
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchGeneration++;
    final gen = _searchGeneration;
    if (value.length < 2 || value == ' ') {
      setState(() {
        _contentMatchIds.clear();
        _contentSnippets.clear();
        _isSearchingContent = false;
      });
      return;
    }
    setState(() {
      _contentMatchIds.clear();
      _contentSnippets.clear();
      _isSearchingContent = true;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _searchInContent(value, gen);
    });
  }

  // Arabic matching delegates to the shared forgiving normalizer so the
  // library, reader and duas all match the same way.
  static String _normalizeArabic(String text) => normalizeForSearch(text);

  Future<void> _searchInContent(String query, int generation) async {
    final q = _normalizeArabic(query.toLowerCase());
    final books = ref.read(bookProvider).value ?? [];
    for (int i = 0; i < books.length; i++) {
      if (generation != _searchGeneration) return;
      final book = books[i];
      List<String> content;
      final cached = _contentCache.remove(book.id);
      if (cached != null) {
        // Re-insert to mark recently used for the LRU cap.
        content = cached;
        _contentCache[book.id] = content;
      } else {
        // Never trigger downloads from search: only books already on disk
        // are scanned (downloading the whole library on every keystroke
        // would burn data + battery).
        if (!await BookContentService.isDownloaded(book.id)) continue;
        try {
          final localPath = await BookContentService.ensureDownloaded(book.id);
          if (localPath == null) continue;
          final bytes = await File(localPath).readAsBytes();
          // Decode + parse off the main isolate: books can be several MB
          // decompressed and json.decode of that on the UI thread freezes or
          // OOMs low-end phones (the reported «library doesn't work» issue).
          content = await compute(_decodeBookContent, bytes);
          _cacheContent(book.id, content);
        } catch (_) {
          // Don't cache failures — a re-downloaded book must be re-scanned.
          continue;
        }
      }
      for (final c in content) {
        final normal = _normalizeArabic(c.toLowerCase());
        final idx = normal.indexOf(q);
        if (idx >= 0) {
          final startC = idx > 40 ? idx - 40 : 0;
          final endC = idx + q.length + 60;
          final snippet = (startC > 0 ? '...' : '') +
              c.substring(startC, endC > c.length ? c.length : endC) +
              (endC < c.length ? '...' : '');
          if (mounted && generation == _searchGeneration) {
            setState(() {
              _contentMatchIds.add(book.id);
              _contentSnippets[book.id] = snippet.replaceAll('\n', ' ');
            });
          }
          break;
        }
      }
    }
    if (mounted && generation == _searchGeneration) {
      setState(() => _isSearchingContent = false);
    }
  }

  /// A shelf-filter row in the overflow menu, checked when it is the active
  /// view — the same affordance the sort rows use.
  PopupMenuItem<String> _viewMenuItem(
      BuildContext context, String value, IconData icon, String label) {
    final active = _libraryView == value;
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(active ? Icons.radio_button_checked : icon,
            size: 20, color: active ? TimeThemeKit.of(context).palette.primary : null),
        const SizedBox(width: 10),
        Text(label),
      ]),
    );
  }

  List<BookModel> _filterBooks(List<BookModel> books, Book notifier) {
    var result = books;
    if (_selectedCategory != 'همه') {
      result = result.where((b) => b.category == _selectedCategory).toList();
    }
    // Shelf filter from the overflow menu.
    switch (_libraryView) {
      case 'favorites':
        result = result
            .where((b) => notifier.favorites.any((f) => f.id == b.id))
            .toList();
      case 'reading':
        result = result
            .where((b) => b.readProgress > 0 && b.readProgress < 1.0)
            .toList();
      case 'recent':
        result = result.where((b) => b.lastRead != null).toList();
      case _:
    }
    if (_selectedAuthor != null) {
      result = result.where((b) => b.author == _selectedAuthor).toList();
    }
    if (_selectedTag != null) {
      result = result.where((b) => b.tags.contains(_selectedTag)).toList();
    }
    if (_searchQuery.isNotEmpty && _searchQuery != ' ') {
      final q = _normalizeArabic(_searchQuery.toLowerCase());
      result = result
          .where((b) =>
              _normalizeArabic(b.title.toLowerCase()).contains(q) ||
              _normalizeArabic(b.author.toLowerCase()).contains(q) ||
              _normalizeArabic(b.category.toLowerCase()).contains(q) ||
              _contentMatchIds.contains(b.id))
          .toList();
    }
    // مرتب‌سازی سراسری بعد از همهٔ فیلترها.
    final sorted = [...result];
    if (_libraryView == 'recent') {
      // «مطالعه شده اخیر» is a time list by definition — newest first.
      sorted.sort((a, b) => b.lastRead!.compareTo(a.lastRead!));
      return sorted;
    }
    switch (_sort) {
      case 'author':
        sorted.sort((a, b) => a.author.compareTo(b.author));
      case 'recent':
        sorted.sort((a, b) {
          final ar = a.lastRead ?? DateTime(1970);
          final br = b.lastRead ?? DateTime(1970);
          return br.compareTo(ar);
        });
      default:
        sorted.sort((a, b) => a.title.compareTo(b.title));
    }
    return sorted;
  }

  Widget _buildGridSliver(
      BuildContext context, List<BookModel> books, Set<String> bookmarkedIds) {
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        // A fixed height instead of an aspect ratio: the card's type got
        // readable (12 sp title, two lines) and an aspect-ratio tile at 320 dp
        // was a few pixels short of holding it.
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: 118,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _BookGridCard(
            book: books[index],
            isBookmarked: bookmarkedIds.contains(books[index].id),
            snippet: _isSearchActive ? _contentSnippets[books[index].id] : null,
            searchQuery: _isSearchActive ? _searchQuery : null,
            onTap: () => _openBook(context, books[index]),
            onEditTags: () => _showTagEditDialog(context, books[index]),
          ),
          childCount: books.length,
        ),
      ),
    );
  }

  Widget _buildListSliver(
      BuildContext context, List<BookModel> books, Set<String> bookmarkedIds) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _BookListCard(
            book: books[index],
            isBookmarked: bookmarkedIds.contains(books[index].id),
            snippet: _isSearchActive ? _contentSnippets[books[index].id] : null,
            searchQuery: _isSearchActive ? _searchQuery : null,
            onTap: () => _openBook(context, books[index]),
            onEditTags: () => _showTagEditDialog(context, books[index]),
          ),
          childCount: books.length,
        ),
      ),
    );
  }

  Future<void> _showTagEditDialog(BuildContext context, BookModel book) async {
    final controller = TextEditingController(text: book.tags.join('، '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('برچسب‌ها',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: AppTheme.scaledFontSize(context, 16))),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'برچسب‌ها را با کاما جدا کنید',
              hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: TimeThemeKit.of(context).palette.textMuted),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: AppTheme.scaledFontSize(context, 14)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('لغو',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text('ذخیره',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result != null && mounted) {
      // Accept both ASCII (,) and Persian (،) separators — the dialog
      // displays tags joined with Persian comma, so splitting on ASCII
      // only would collapse everything into a single tag.
      final tags = result
          .split(RegExp(r'[,،]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      ref.read(bookProvider.notifier).updateTags(book.id, tags);
    }
  }

  Future<void> _openBook(BuildContext context, BookModel book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookReaderScreen(book: book)),
    );
    if (mounted) {
      ref.invalidate(bookProvider);
    }
  }
}

const _categoryIcons = {
  'فقه': Icons.gavel,
  'عقیده': Icons.psychology,
  'تفسیر': Icons.explore,
  'حدیث': Icons.forum,
  'سیره': Icons.timeline,
  'اخلاق': Icons.heart_broken,
  'ادعیه': Icons.handshake,
  'عبادات': Icons.mosque,
  'ادبیات': Icons.auto_stories,
  'متفرقه': Icons.category,
  'تجوید': Icons.record_voice_over,
  'فقه و عبادات': Icons.mosque,
  'تزکیه': Icons.self_improvement,
};

// ═══════════════════════════════════════════════════════════
//  STAT BADGE
// ═══════════════════════════════════════════════════════════

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatBadge(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFamily: AppTheme.fontFamily)),
            Text(label,
                style: TextStyle(
                    fontSize: AppTheme.scaledFontSize(context, 9),
                    color: TimeThemeKit.of(context).palette.textMuted,
                    fontFamily: AppTheme.fontFamily)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  COMPLETED BOOK CARD
// ═══════════════════════════════════════════════════════════

class _CompletedBookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;
  const _CompletedBookCard({required this.book, required this.onTap});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = BookPalette.categoryColors[book.category] ?? TimeThemeKit.of(context).palette.primary;
    final started = book.startedAt ?? book.dateAdded;
    final success = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSuccess
        : AppTheme.lightSuccess;
    final ended = book.completedAt ?? book.lastRead ?? DateTime.now();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsetsDirectional.only(start: 10),
        decoration: BoxDecoration(
          color: TimeThemeKit.of(context).palette.card,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: success.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  color: color.withValues(alpha: 0.10),
                ),
                child: Center(
                  child: Icon(Icons.check_circle,
                      size: 32,
                      color: success.withValues(alpha: 0.4)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w600,
                          color: TimeThemeKit.of(context).palette.textPrimary,
                          fontFamily: AppTheme.fontFamily)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.play_arrow,
                          size: 10, color: TimeThemeKit.of(context).palette.textMuted),
                      const SizedBox(width: 2),
                      Expanded(
                          child: Text(_formatDate(started),
                              style: TextStyle(
                                  fontSize: AppTheme.scaledFontSize(context, 8),
                                  color: TimeThemeKit.of(context).palette.textMuted,
                                  fontFamily: AppTheme.fontFamily))),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.stop,
                          size: 10, color: TimeThemeKit.of(context).palette.textMuted),
                      const SizedBox(width: 2),
                      Expanded(
                          child: Text(_formatDate(ended),
                              style: TextStyle(
                                  fontSize: AppTheme.scaledFontSize(context, 8),
                                  color: TimeThemeKit.of(context).palette.textMuted,
                                  fontFamily: AppTheme.fontFamily))),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 10, color: TimeThemeKit.of(context).palette.textMuted),
                      const SizedBox(width: 2),
                      Expanded(
                          child: Text('${book.pageCount} صفحه',
                              style: TextStyle(
                                  fontSize: AppTheme.scaledFontSize(context, 8),
                                  color: TimeThemeKit.of(context).palette.textMuted,
                                  fontFamily: AppTheme.fontFamily))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CURRENTLY READING CARD
// ═══════════════════════════════════════════════════════════

class _CurrentlyReadingCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;
  const _CurrentlyReadingCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = BookPalette.categoryColors[book.category] ?? TimeThemeKit.of(context).palette.primary;
    final success = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSuccess
        : AppTheme.lightSuccess;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsetsDirectional.only(start: 10),
        decoration: BoxDecoration(
          color: TimeThemeKit.of(context).palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TimeThemeKit.of(context).palette.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  color: color.withValues(alpha: 0.10),
                ),
                child: Stack(
                  children: [
                    Center(
                        child: Icon(Icons.menu_book,
                            size: 28, color: color.withValues(alpha: 0.3))),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      right: 6,
                      child: LinearProgressIndicator(
                        value: book.readProgress,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        backgroundColor: TimeThemeKit.of(context).palette.divider,
                        valueColor:
                            AlwaysStoppedAnimation(success),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 10),
                          fontWeight: FontWeight.w600,
                          color: TimeThemeKit.of(context).palette.textPrimary,
                          fontFamily: AppTheme.fontFamily)),
                  Text('${(book.readProgress * 100).toInt()}%',
                      style: TextStyle(
                          fontSize: AppTheme.scaledFontSize(context, 9),
                          color: success,
                          fontFamily: AppTheme.fontFamily)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  GRID CARD
// ═══════════════════════════════════════════════════════════

class _BookGridCard extends StatelessWidget {
  final BookModel book;
  final bool isBookmarked;
  final String? snippet;
  final String? searchQuery;
  final VoidCallback onTap;
  final VoidCallback onEditTags;
  const _BookGridCard(
      {required this.book,
      required this.isBookmarked,
      this.snippet,
      this.searchQuery,
      required this.onTap,
      required this.onEditTags});

  @override
  Widget build(BuildContext context) {
    final color = BookPalette.categoryColors[book.category] ?? TimeThemeKit.of(context).palette.primary;
    final hasProgress = book.readProgress > 0;
    final success = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSuccess
        : AppTheme.lightSuccess;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onEditTags,
      child: Container(
        decoration: BoxDecoration(
          color: TimeThemeKit.of(context).palette.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TimeThemeKit.of(context).palette.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top color strip
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                color: color,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon row
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded, size: 13, color: color),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize:
                                      AppTheme.scaledFontSize(context, 12),
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: TimeThemeKit.of(context).palette.textPrimary,
                                  fontFamily: AppTheme.fontFamily)),
                        ),
                        if (isBookmarked)
                          const Icon(Icons.bookmark,
                              size: 12, color: TopicHues.ketabkhaneh),
                        _DownloadBadge(
                            bookId: book.id, fileSizeBytes: book.fileSize),
                      ],
                    ),
                    if (book.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 9),
                              color: TimeThemeKit.of(context).palette.textMuted,
                              fontFamily: AppTheme.fontFamily)),
                    ],
                    if (snippet != null && snippet!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: searchQuery != null
                              ? TextHighlight.snippetSpans(
                                  snippet!,
                                  searchQuery!,
                                  context: 20,
                                  highlightStyle: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 7),
                                    color: TimeThemeKit.of(context).palette.primary,
                                    fontFamily: AppTheme.fontFamily,
                                    backgroundColor:
                                        Colors.yellow.withValues(alpha: 0.3),
                                  ),
                                )
                              : [TextSpan(text: snippet!)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 7),
                            color: TimeThemeKit.of(context).palette.primary,
                            fontFamily: AppTheme.fontFamily),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text('${book.pageCount} ص',
                              style: TextStyle(
                                  fontSize: AppTheme.scaledFontSize(context, 8),
                                  color: TimeThemeKit.of(context).palette.textMuted,
                                  fontFamily: AppTheme.fontFamily)),
                        ),
                        if (hasProgress)
                          SizedBox(
                            width: 20,
                            height: 2,
                            child: LinearProgressIndicator(
                              value: book.readProgress,
                              backgroundColor: TimeThemeKit.of(context).palette.divider,
                              valueColor: AlwaysStoppedAnimation(
                                  success),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  LIST CARD
// ═══════════════════════════════════════════════════════════

class _BookListCard extends StatelessWidget {
  final BookModel book;
  final bool isBookmarked;
  final String? snippet;
  final String? searchQuery;
  final VoidCallback onTap;
  final VoidCallback onEditTags;
  const _BookListCard(
      {required this.book,
      required this.isBookmarked,
      this.snippet,
      this.searchQuery,
      required this.onTap,
      required this.onEditTags});

  @override
  Widget build(BuildContext context) {
    final color = BookPalette.categoryColors[book.category] ?? TimeThemeKit.of(context).palette.primary;
    final hasProgress = book.readProgress > 0;
    final success = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSuccess
        : AppTheme.lightSuccess;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: onEditTags,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TimeThemeKit.of(context).palette.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                if (isBookmarked)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.bookmark,
                        size: 14, color: TopicHues.ketabkhaneh),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w700,
                                    color: TimeThemeKit.of(context).palette.textPrimary,
                                    fontFamily: AppTheme.fontFamily)),
                          ),
                          if (book.isFavorite)
                            const Icon(Icons.favorite,
                                size: 12, color: Colors.red),
                          _DownloadBadge(
                              bookId: book.id, fileSizeBytes: book.fileSize),
                        ],
                      ),
                      Row(
                        children: [
                          if (book.author.isNotEmpty)
                            Text(book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 9),
                                    color: TimeThemeKit.of(context).palette.textMuted,
                                    fontFamily: AppTheme.fontFamily)),
                          if (book.author.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                    color: TimeThemeKit.of(context).palette.textMuted,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                          ],
                          if (snippet != null && snippet!.isNotEmpty) ...[
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: searchQuery != null
                                      ? TextHighlight.snippetSpans(
                                          snippet!,
                                          searchQuery!,
                                          context: 20,
                                          highlightStyle: TextStyle(
                                            fontSize: AppTheme.scaledFontSize(
                                                context, 8),
                                            color: TimeThemeKit.of(context).palette.primary,
                                            fontFamily: AppTheme.fontFamily,
                                            backgroundColor: Colors.yellow
                                                .withValues(alpha: 0.3),
                                          ),
                                        )
                                      : [TextSpan(text: snippet!)],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 8),
                                    color: TimeThemeKit.of(context).palette.primary,
                                    fontFamily: AppTheme.fontFamily),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            Text('${book.pageCount} صفحه',
                                style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 9),
                                    color: TimeThemeKit.of(context).palette.textMuted,
                                    fontFamily: AppTheme.fontFamily)),
                          ],
                          if (hasProgress) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: book.readProgress,
                                minHeight: 2,
                                backgroundColor: TimeThemeKit.of(context).palette.divider,
                                valueColor: AlwaysStoppedAnimation(
                                    success),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('${(book.readProgress * 100).toInt()}%',
                                style: TextStyle(
                                    fontSize:
                                        AppTheme.scaledFontSize(context, 8),
                                    color: success,
                                    fontFamily: AppTheme.fontFamily)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left,
                    size: 16, color: TimeThemeKit.of(context).palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decompresses and parses a book's content file. Runs on a background isolate
/// (via `compute`) so multi-MB book JSONs never block or OOM the UI thread.
List<String> _decodeBookContent(Uint8List bytes) {
  final decompressed = gzip.decode(bytes);
  final jsonStr = utf8.decode(decompressed);
  final parsed = json.decode(jsonStr) as Map<String, dynamic>;
  return List<String>.from(parsed['content'] ?? const []);
}

/// Download control on a book card: a green check when the book's content is
/// on disk, a tappable download button otherwise (content is fetched on
/// demand, see [BookContentService]).
class _DownloadBadge extends StatefulWidget {
  final String bookId;

  /// Content size in bytes from the hosted catalog (0 when unknown).
  final int fileSizeBytes;
  const _DownloadBadge({required this.bookId, this.fileSizeBytes = 0});

  @override
  State<_DownloadBadge> createState() => _DownloadBadgeState();
}

class _DownloadBadgeState extends State<_DownloadBadge> {
  bool _downloaded = false;
  bool _checking = true;
  bool _downloading = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    var d = false;
    try {
      d = await BookContentService.isDownloaded(widget.bookId);
    } catch (_) {
      AppLogger.warning('ketabkhaneh_screen', 'operation failed');
    }
    if (!mounted) return;
    setState(() {
      _downloaded = d;
      _checking = false;
    });
  }

  Future<void> _download() async {
    if (_downloading || _downloaded) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    final path = await BookContentService.ensureDownloaded(
      widget.bookId,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() => _progress = total > 0 ? received / total : null);
      },
    );
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _downloaded = path != null;
    });
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('دانلود کتاب ممکن نشد. بعداً دوباره تلاش کنید.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('کتاب دانلود شد',
              style: TextStyle(fontFamily: AppTheme.fontFamily)),
          duration: const Duration(seconds: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final success = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSuccess
        : AppTheme.lightSuccess;
    final Widget child;
    String? tooltip;
    if (_checking) {
      child = const SizedBox(
        width: 11,
        height: 11,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      tooltip = 'در حال بررسی';
    } else if (_downloading) {
      child = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: _progress,
          color: TopicHues.ketabkhaneh,
        ),
      );
      tooltip = 'در حال دانلود';
    } else if (_downloaded) {
      child =
          Icon(Icons.check_circle, size: 14, color: success);
      tooltip = 'کتاب دانلود شده است';
    } else {
      final sizeText = widget.fileSizeBytes > 0
          ? _formatBookSize(widget.fileSizeBytes)
          : null;
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sizeText != null) ...[
            Text(
              sizeText,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 8),
                color: TimeThemeKit.of(context).palette.textMuted,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(width: 3),
          ],
          const Icon(Icons.cloud_download_outlined,
              size: 14, color: TopicHues.ketabkhaneh),
        ],
      );
      tooltip = sizeText != null ? 'دانلود کتاب ($sizeText)' : 'دانلود کتاب';
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: _downloading || _downloaded ? null : _download,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Formats [bytes] as a human-readable size (e.g. "1.2 مگابایت").
  String _formatBookSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      final gb = mb / 1024;
      return '${NumberFormat.normalizeDigits(gb.toStringAsFixed(1))} گیگابایت';
    }
    if (mb >= 1) {
      return '${NumberFormat.normalizeDigits(mb.toStringAsFixed(1))} مگابایت';
    }
    return '${NumberFormat.normalizeDigits((bytes / 1024).toStringAsFixed(0))} کیلوبایت';
  }
}
