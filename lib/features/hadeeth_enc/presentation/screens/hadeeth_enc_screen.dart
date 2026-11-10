import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/hadeeth_enc/services/hadeeth_enc_db_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/favorites_store.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/widgets/content_database_delete_dialog.dart';

/// List screen of موسوعه احادیث — paginated, searchable.
class HadeethEncScreen extends StatefulWidget {
  const HadeethEncScreen({super.key});

  @override
  State<HadeethEncScreen> createState() => _HadeethEncScreenState();
}

class _HadeethEncScreenState extends State<HadeethEncScreen> {
  static const int _pageSize = 40;

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  final List<HadeethEncHadith> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _initialLoading = true;
  bool _searching = false;
  String _query = '';
  List<HadeethEncHadith> _results = const [];

  // موضوع browsing: main category → its subcategories
  int? _mainCat;
  String? _subCat;
  final Map<int, List<String>> _subsCache = {};
  List<String> _subs = const [];

  String? _error;
  int _totalCount = 0;
  bool _showFab = false;

  // Favorites (hadith ids as strings, same pattern as fatwa).
  static const _favKey = 'hadeeth_enc_favorite_ids';
  Set<String> _favorites = {};
  bool _favOnly = false;

  /// The favorites view is fetched BY ID from the database. Filtering the
  /// loaded page made the chip read «علاقه‌مندی‌ها (۱۲)» while showing the two
  /// favorites that happened to be on screen.
  List<HadeethEncHadith> _favItems = const [];
  bool _loadingFavs = false;

  // download gate
  bool _checking = true;
  bool _missing = false;
  bool _downloading = false;
  bool _deleting = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _checkDatabase();
    FavoritesStore.load(_favKey).then((ids) {
      if (mounted) setState(() => _favorites = ids);
    });
  }

  Future<void> _toggleFavorite(int id) async {
    final next = await FavoritesStore.toggle(_favKey, '$id');
    if (!mounted) return;
    setState(() {
      _favorites = next;
      // Un-favoriting from inside the favorites view must drop the card.
      if (_favOnly) _favItems = [..._favItems.where((h) => h.id != id)];
    });
  }

  /// Opens the favorites view, fetching every saved id in one query.
  Future<void> _openFavorites() async {
    setState(() {
      _favOnly = true;
      _loadingFavs = true;
    });
    final ids = _favorites.map(int.tryParse).whereType<int>().toList();
    if (ids.isEmpty) {
      if (mounted) setState(() => _loadingFavs = false);
      return;
    }
    try {
      final items = await HadeethEncDbService().getByIds(ids);
      if (!mounted) return;
      setState(() {
        _favItems = items;
        _loadingFavs = false;
      });
    } catch (e) {
      AppLogger.warning('hadeeth_enc_screen', 'favorites load failed: $e');
      if (!mounted) return;
      setState(() {
        _favItems = const [];
        _loadingFavs = false;
        _error = 'بارگذاری علاقه‌مندی‌ها ممکن نشد.';
      });
    }
  }

  bool _isFav(HadeethEncHadith h) => _favorites.contains('${h.id}');

  Future<void> _loadCount() async {
    try {
      final c = await HadeethEncDbService().getCount();
      if (mounted && c > 0) setState(() => _totalCount = c);
    } catch (_) {
      AppLogger.warning('hadeeth_enc_screen', 'operation failed');
    }
  }

  Future<void> _checkDatabase() async {
    setState(() => _checking = true);
    try {
      if (!await HadeethEncDbService().isAvailable()) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _missing = true;
        });
        return;
      }
      await HadeethEncDbService().init();
      _loadMore();
      _loadCount();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _missing = false;
      });
    } catch (_) {
      AppLogger.warning('hadeeth_enc_screen', 'operation failed');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _missing = true;
      });
    }
  }

  Future<void> _downloadDatabase() async {
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      await HadeethEncDbService().download(onProgress: (received, total) {
        if (!mounted) return;
        setState(() => _progress = total > 0 ? received / total : 0);
      });
      await HadeethEncDbService().init();
      _loadMore();
      _loadCount();
      if (!mounted) return;
      setState(() => _downloading = false);
    } catch (_) {
      AppLogger.warning('hadeeth_enc_screen', 'operation failed');
      if (!mounted) return;
      setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Removes the downloaded database; the page falls back to its download
  /// prompt, which is also how the data comes back.
  Future<void> _deleteDatabase() async {
    final ok = await confirmContentDatabaseDelete(context, name: 'موسوعه احادیث');
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    await HadeethEncDbService().deleteDownloaded();
    if (!mounted) return;
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _deleting = false;
      _missing = true;
      _items.clear();
      _hasMore = true;
      _initialLoading = true;
      _totalCount = 0;
      _query = '';
      _results = const [];
      _favItems = const [];
      _subs = const [];
      _subsCache.clear();
      _mainCat = null;
      _subCat = null;
      _showFab = false;
    });
    AppSnackBar.success(context, 'دادهٔ موسوعه احادیث حذف شد.');
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
    final showFab = _scrollCtrl.position.pixels > 800;
    if (showFab != _showFab) {
      setState(() => _showFab = showFab);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _query.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      final page = await HadeethEncDbService()
          .getPage(offset: _items.length, limit: _pageSize, category: _subCat);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
        _loading = false;
        _initialLoading = false;
        _error = null;
      });
    } catch (e) {
      AppLogger.warning('hadeeth_enc_screen', 'error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initialLoading = false;
        _error = 'خطا در بارگذاری';
      });
    }
  }

  /// Resets the paginated list for the current موضوع selection.
  void _resetList() {
    _items.clear();
    _hasMore = true;
    _initialLoading = true;
    if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels > 0) {
      _scrollCtrl.jumpTo(0);
    }
    _loadMore();
  }

  Future<void> _onMainCatChanged(int? mainId) async {
    _debounce?.cancel();
    _searchCtrl.clear();
    List<String> subs = const [];
    if (mainId != null) {
      final cached = _subsCache[mainId];
      subs = cached ?? await HadeethEncDbService().subCategories(mainId);
      _subsCache[mainId] = subs;
    }
    if (!mounted) return;
    setState(() {
      _mainCat = mainId;
      _subCat = null;
      _results = const [];
      _query = '';
      _subs = subs;
    });
    _resetList();
  }

  void _onSubCatChanged(String? sub) {
    _debounce?.cancel();
    if (sub == _subCat) return;
    setState(() => _subCat = sub);
    _resetList();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    setState(() => _query = v);
    if (v.trim().isEmpty && _subCat == null) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  Future<void> _search(String v) async {
    setState(() => _searching = true);
    try {
      final r = await HadeethEncDbService().search(v, category: _subCat);
      if (!mounted) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    } catch (_) {
      AppLogger.warning('hadeeth_enc_screen', 'operation failed');
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _showRandom() async {
    try {
      final service = HadeethEncDbService();
      final count = await service.getCount();
      if (count == 0) return;
      final random = DateTime.now().millisecondsSinceEpoch % count;
      final page = await service.getPage(offset: random, limit: 1);
      if (page.isEmpty) return;
      final full = await service.getHadith(page.first.id);
      if (full == null || !mounted) return;
      // شماره ترتیبی واقعی (نه id خام که می‌تواند از تعداد کل بیشتر باشد).
      context.push(RouteNames.hadeethEncDetailPath(full.id),
          extra: (full, random + 1));
    } catch (_) {
      AppLogger.warning('hadeeth_enc_screen', 'operation failed');
    }
  }

  /// پرش مستقیم به یک شماره از فهرست (مثلاً 300) بدون اسکرول.
  Future<void> _showJumpDialog() async {
    final count =
        _totalCount > 0 ? _totalCount : await HadeethEncDbService().getCount();
    if (!mounted) return;
    if (count == 0) {
      _showSnack('لیست هنوز آماده نیست');
      return;
    }
    final number = await showDialog<int>(
      context: context,
      builder: (context) => _JumpDialog(count: count),
    );
    if (number == null || !mounted) return;
    if (number < 1 || number > count) {
      _showSnack('شماره حدیث باید بین 1 تا $count باشد');
      return;
    }
    final service = HadeethEncDbService();
    final id = await service.getHadithIdAt(number - 1);
    final full = id == null ? null : await service.getHadith(id);
    if (!mounted) return;
    if (full == null) {
      _showSnack('حدیث یافت نشد');
      return;
    }
    context
        .push(RouteNames.hadeethEncDetailPath(full.id), extra: (full, number));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: TextStyle(fontFamily: AppTheme.fontFamily))));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'موسوعه احادیث',
        actions: [
          if (!_checking && !_missing) ...[
            IconButton(
              icon: const Icon(Icons.numbers, size: 20),
              tooltip: 'پرش به شماره حدیث',
              onPressed: _showJumpDialog,
            ),
            IconButton(
              icon: const Icon(Icons.shuffle, size: 20),
              tooltip: 'حدیث تصادفی',
              onPressed: _showRandom,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: 'حذف داده‌های دانلودشده',
              onPressed: _deleting ? null : _deleteDatabase,
            ),
          ],
        ],
        bottom: (_checking || _missing)
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(_mainCat == null ? 128 : 168),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          hintText: 'جستجو در متن، ترجمه، شرح و نکات حدیث...',
                          hintStyle: TextStyle(
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              fontFamily: AppTheme.fontFamily),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _query.isNotEmpty
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
                              ? const Color(0xFF1A1410)
                                  .withValues(alpha: 0.06)
                              : const Color(0xFF3E2723)
                                  .withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'علاقه‌مندی‌ها (${_favorites.length})',
                              selected: _favOnly,
                              onTap: () => _favOnly
                                  ? setState(() => _favOnly = false)
                                  : _openFavorites(),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'همه موضوع‌ها',
                              selected: _mainCat == null && !_favOnly,
                              onTap: () {
                                setState(() => _favOnly = false);
                                _onMainCatChanged(null);
                              },
                            ),
                            for (final (id, name)
                                in HadeethEncDbService.mainCategories) ...[
                              const SizedBox(width: 6),
                              _FilterChip(
                                label: name,
                                selected: _mainCat == id,
                                onTap: () => _onMainCatChanged(id),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_mainCat != null && _subs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _subs.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (_, i) {
                              final sub = i == 0 ? null : _subs[i - 1];
                              return Center(
                                child: _FilterChip(
                                  label: sub ?? 'همه',
                                  selected: _subCat == sub,
                                  onTap: () => _onSubCatChanged(sub),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    if (_totalCount > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _subCat != null
                                ? 'موضوع: $_subCat'
                                : 'مجموع احادیث: $_totalCount',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 11.5),
                              color: TimeThemeKit.of(context).palette.textMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : _missing
              ? _buildDownloadPrompt()
              : _buildBody(),
      floatingActionButton: (_showFab && !_missing && !_checking)
          ? InsetFab(
              inset: MediaQuery.paddingOf(context).bottom,
              child: FloatingActionButton.small(
                heroTag: 'hadeethTop',
              tooltip: 'بازگشت به بالا',
              backgroundColor: TopicHues.hadeethEnc,
              foregroundColor: Colors.white,
              onPressed: () {
                if (!_scrollCtrl.hasClients) return;
                _scrollCtrl.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Icon(Icons.arrow_upward, size: 20),
              ),
            )
          : null,
    );
  }

  /// Download gate — shown when the categorized database is not on disk yet.
  Widget _buildDownloadPrompt() {
    const accent = TopicHues.hadeethEnc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_mosaic_outlined,
                  size: 42, color: accent),
            ),
            const SizedBox(height: 20),
            Text('موسوعه احادیث',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 19),
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              '2٬275 حدیث با ترجمه، شرح و نکات\n'
              '(منبع: HadeethEnc.com) — دانلود یک‌باره حدود 2٫1 مگابایت\n'
              'پس از دانلود، کاملاً آفلاین در دسترس است.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  height: 1.9,
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 24),
            if (_downloading) ...[
              LinearProgressIndicator(value: _progress, color: accent),
              const SizedBox(height: 10),
              Text('در حال دانلود… ${(_progress * 100).toStringAsFixed(0)}٪',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ] else ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: _downloadDatabase,
                icon: const Icon(Icons.download_outlined),
                label: Text('دانلود داده‌ها',
                    style: TextStyle(fontFamily: AppTheme.fontFamily)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _isSearchMode => _query.isNotEmpty;

  Widget _buildBody() {
    if (_favOnly) {
      if (_loadingFavs) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_favItems.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border,
                  size: 48, color: TimeThemeKit.of(context).palette.textMuted),
              const SizedBox(height: 12),
              Text('هنوز حدیثی را به علاقه‌مندی‌ها اضافه نکرده‌اید',
                  style: TextStyle(
                      color: TimeThemeKit.of(context).palette.textMuted,
                      fontFamily: AppTheme.fontFamily)),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.page, 4, DsSpacing.page, 24),
        itemCount: _favItems.length,
        itemBuilder: (context, i) => _HadithListCard(
            hadith: _favItems[i],
            number: _favItems[i].sequence ?? i + 1,
            onTap: () => _open(_favItems[i]),
            isFavorite: true,
            onToggleFavorite: () => _toggleFavorite(_favItems[i].id)),
      );
    }
    if (_isSearchMode) {
      if (_searching) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_results.isEmpty) {
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
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.page, 4, DsSpacing.page, 24),
        itemCount: _results.length,
        itemBuilder: (context, i) => _HadithListCard(
            hadith: _results[i],
            number: _results[i].sequence ?? i + 1,
            onTap: () => _open(_results[i], sequence: i + 1),
            isFavorite: _isFav(_results[i]),
            onToggleFavorite: () => _toggleFavorite(_results[i].id)),
      );
    }

    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      // The old panel used `Colors.red.shade300` for both the icon and the
      // heading, so it was the same salmon in daylight and at night, and it put
      // the raw error string where the heading belongs — «DatabaseException(...)»
      // as a title. The message is the debug channel now.
      return FailureView(
        id: 'hadeeth_enc_load',
        title: 'فهرست احادیث باز نشد',
        detail: 'احادیث همراه برنامه ذخیره شده‌اند و جایی نرفته‌اند؛ '
            'فقط خواندن فهرست ناموفق بود.',
        onRetry: () {
          setState(() {
            _initialLoading = true;
            _error = null;
          });
          _loadMore();
        },
        layout: FailureLayout.page,
        error: _error,
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 4, DsSpacing.page, 24),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final h = _items[i];
        return _HadithListCard(
            hadith: h,
            number: h.sequence ?? i + 1,
            onTap: () => _open(h, sequence: i + 1),
            isFavorite: _isFav(h),
            onToggleFavorite: () => _toggleFavorite(h.id));
      },
    );
  }

  /// Opens the detail screen with the FULL hadith (list items only carry
  /// id + titles, so a stale partial object would show empty translation,
  /// source, explanation...).
  Future<void> _open(HadeethEncHadith hadith, {int? sequence}) async {
    final full = await HadeethEncDbService().getHadith(hadith.id);
    if (!mounted) return;
    final shown = full ?? hadith;
    context.push(RouteNames.hadeethEncDetailPath(shown.id),
        extra: (shown, sequence));
  }
}

class _HadithListCard extends StatelessWidget {
  final HadeethEncHadith hadith;
  final int number;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  const _HadithListCard({
    required this.hadith,
    required this.number,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.hadeethEnc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: TimeThemeKit.of(context).palette.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                          color: accent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hadith.titleAr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Calibri',
                          fontSize: AppTheme.scaledFontSize(context, 14.5),
                          fontWeight: FontWeight.w600,
                          height: 1.7,
                          color: TimeThemeKit.of(context).palette.textPrimary,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      if (hadith.title.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          hadith.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 12),
                            height: 1.6,
                            color: TimeThemeKit.of(context).palette.textSecondary,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isFavorite
                          ? Colors.red.shade400
                          : TimeThemeKit.of(context).palette.textMuted),
                  tooltip: 'علاقه‌مندی',
                  onPressed: onToggleFavorite,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Icon(Icons.chevron_left,
                    size: 18, color: TimeThemeKit.of(context).palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.hadeethEnc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.35 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accent
                : TimeThemeKit.of(context).palette.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 11.5),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? accent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : TimeThemeKit.of(context).palette.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// «پرش به شماره حدیث» — یک فیلد عددی همراه با اسلایدر برای پیمایش سریع در
/// فهرست بلند. مقدار خارج از بازه 1..تعداد پذیرفته نمی‌شود.
class _JumpDialog extends StatefulWidget {
  final int count;
  const _JumpDialog({required this.count});

  @override
  State<_JumpDialog> createState() => _JumpDialogState();
}

class _JumpDialogState extends State<_JumpDialog> {
  late final TextEditingController _controller;
  double _slider = 1;
  int? _value;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fromField(String raw) {
    // The Persian keyboard types «۱۲»; without normalising it the field looks
    // valid to the user but silently counts as no selection at all.
    final text = NumberFormat.normalizeDigits(raw.trim());
    final parsed = int.tryParse(text);
    final valid = parsed != null && parsed >= 1 && parsed <= widget.count;
    setState(() {
      _value = valid ? parsed : null;
      if (valid) _slider = parsed.toDouble();
    });
  }

  void _fromSlider(double v) {
    final n = v.round().clamp(1, widget.count);
    setState(() {
      _slider = n.toDouble();
      _value = n;
      _controller.text = '$n';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.hadeethEnc;
    final invalid = _value == null && _controller.text.trim().isNotEmpty;
    return AlertDialog(
      backgroundColor: TimeThemeKit.of(context).palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('پرش به شماره حدیث',
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'از 1 تا ${widget.count}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              color: TimeThemeKit.of(context).palette.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.rtl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'شماره حدیث',
              hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13)),
              prefixIcon: const Icon(Icons.numbers, size: 20),
              errorText: invalid ? 'از 1 تا ${widget.count}' : null,
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _fromField,
            onSubmitted: (v) {
              if (_value != null) Navigator.pop(context, _value);
            },
          ),
          const SizedBox(height: 8),
          Slider(
            value: _slider.clamp(1, widget.count.toDouble()),
            min: 1,
            max: widget.count.toDouble(),
            activeColor: accent,
            label: '${_slider.round()}',
            onChanged: _fromSlider,
          ),
          Text(
            '${_slider.round()}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 13),
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('انصراف', style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: accent),
          onPressed:
              _value == null ? null : () => Navigator.pop(context, _value),
          child: Text('برو', style: TextStyle(fontFamily: AppTheme.fontFamily)),
        ),
      ],
    );
  }
}
