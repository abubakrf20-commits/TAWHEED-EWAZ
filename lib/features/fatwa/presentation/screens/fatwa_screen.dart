import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/fatwa/services/fatwa_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/favorites_store.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/widgets/content_database_delete_dialog.dart';

/// ═══════════════════════════════════════════════════════════════
/// FatwaScreen — «فتاوای شرعی (فارسی)»
///
/// 9٬081 پرسش‌وپاسخ فقهی اهل سنت و جماعت (منبع: IslamPP.Com).
/// • دانلود یک‌بارهٔ دیتابیس از کاتالوگ محتوا (مثل ریاض الصالحین)
/// • موتور جستجوی قوی: نرمال‌سازی اعراب/ی-ک فارسی-عربی، جستجوی چندواژه‌ای
///   AND، پیش‌نمایشِ بخش مرتبط از جواب روی کارت نتایج
/// • دسته‌بندی خودکار موضوعی + فیلتر چیپی
/// • علاقه‌مندی محلی، اشتراک‌گذاری متن فتوا، «فتوای تصادفی»
/// ═══════════════════════════════════════════════════════════════

/// سلب مسئولیت فقهی — پس از ورود به بخش 5 ثانیه در بالای صفحه نمایش داده
/// می‌شود و در صفحهٔ دانلود هم ذکر می‌گردد.
const String kFatwaDisclaimer =
    'تذکر: فتوا نسبت به منطقه، زمان و مذهب متغیر است؛ در مسائل مهم و '
    'اختلافی بهتر است به عالم دین مراجعه کنید.';

class FatwaScreen extends StatefulWidget {
  const FatwaScreen({super.key});

  @override
  State<FatwaScreen> createState() => _FatwaScreenState();
}

class _FatwaScreenState extends State<FatwaScreen> {
  static const Color accent = TopicHues.fatwa;
  static const String _favKey = 'fatwa_favorite_ids';
  static const int _pageSize = 30;

  final FatwaService _service = FatwaService();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  // DB lifecycle
  bool _checking = true;
  bool _missing = false;
  bool _outdated = false;
  bool _downloading = false;
  bool _deleting = false;
  double _progress = 0;
  String? _error;

  // content
  final List<Map<String, dynamic>> _items = [];
  bool _loadingMore = false;
  bool _hasMore = true;

  /// The last page fetch threw. Rendered as a retry row instead of the
  /// spinner, which otherwise sat at the bottom of the list forever while
  /// `_hasMore` stayed true and every scroll retried the same failing query.
  bool _listFailed = false;

  // search
  bool _searchMode = false;
  bool _searching = false;
  List<Map<String, dynamic>>? _results;
  bool _resultsTruncated = false;

  // favorites
  Set<int> _favorites = {};
  bool _onlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _checkDatabase();
    _loadFavorites();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Lifecycle ────────────────────────────────────────────────

  Future<void> _checkDatabase() async {
    setState(() => _checking = true);
    try {
      if (!await _service.isAvailable()) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _missing = true;
          _outdated = false;
        });
        return;
      }
      // The hosted database was republished with corrected content; drop the
      // stale copy instead of keeping the old fatwas forever.
      if (await _service.needsUpdate()) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _missing = true;
          _outdated = true;
        });
        return;
      }
      await _service.ensureReady();
      await _loadFirstPage();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _missing = false;
        _outdated = false;
      });
    } catch (e) {
      AppLogger.warning('fatwa_screen', 'error: $e');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _missing = true;
        _error = '$e';
      });
    }
  }

  Future<void> _downloadDatabase() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      await _service.download(onProgress: (received, total) {
        if (!mounted) return;
        setState(() => _progress = total > 0 ? received / total : 0);
      });
      await _service.ensureReady();
      _items.clear();
      await _loadFirstPage();
      if (!mounted) return;
      setState(() => _downloading = false);
    } catch (e) {
      AppLogger.warning('fatwa_screen', 'error: $e');
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = '$e';
      });
    }
  }

  // ─── Paging ───────────────────────────────────────────────────

  /// Removes the downloaded database; the page falls back to its download
  /// prompt, which is also how the data comes back.
  Future<void> _deleteDatabase() async {
    final ok = await confirmContentDatabaseDelete(context, name: 'فتاوای شرعی');
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    await _service.deleteDownloaded();
    if (!mounted) return;
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _deleting = false;
      _missing = true;
      _outdated = false;
      _error = null;
      _items.clear();
      _hasMore = true;
      _searchMode = false;
      _searching = false;
      _results = null;
      _resultsTruncated = false;
      _onlyFavorites = false;
    });
    AppSnackBar.success(context, 'دادهٔ فتاوای شرعی حذف شد.');
  }

  Future<void> _loadFirstPage() async {
    setState(() => _hasMore = true);
    _items.clear();
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    if (_listFailed && mounted) setState(() => _listFailed = false);
    try {
      // SQLite work is fast (<5ms on 9k rows); keep the frame smooth by
      // yielding once so the spinner paints before the query runs.
      await Future<void>.delayed(Duration.zero);
      final page = _service.listPage(
        offset: _items.length,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
        _listFailed = false;
      });
    } catch (e, st) {
      AppLogger.error(
          'fatwa', 'page load failed at offset ${_items.length}: $e', st);
      if (!mounted) return;
      // Stop the automatic scroll-triggered retry loop: the row below offers
      // an explicit retry instead.
      setState(() {
        _listFailed = true;
        _hasMore = false;
      });
    } finally {
      _loadingMore = false;
    }
  }

  void _onScroll() {
    if (!_searchMode &&
        !_onlyFavorites &&
        _scrollCtrl.position.pixels >
            _scrollCtrl.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  // ─── Search ───────────────────────────────────────────────────

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _searchMode = false;
        _results = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(
        const Duration(milliseconds: 350), () => _performSearch(v.trim()));
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searching = true);
    try {
      await Future<void>.delayed(Duration.zero);
      final (:rows, more: truncated) = _service.search(query);
      if (!mounted) return;
      setState(() {
        _searchMode = true;
        _results = rows;
        _resultsTruncated = truncated;
        _searching = false;
      });
    } catch (_) {
      AppLogger.warning('fatwa_screen', 'operation failed');
      if (mounted) setState(() => _searching = false);
    }
  }

  // ─── Favorites ────────────────────────────────────────────────

  Future<void> _loadFavorites() async {
    // The shared store already drops corrupt entries and never throws;
    // ids stay ints in memory, strings on disk (same format as before).
    final stored = await FavoritesStore.load(_favKey);
    if (!mounted) return;
    setState(() =>
        _favorites = stored.map(int.tryParse).whereType<int>().toSet());
  }

  Future<void> _toggleFavorite(int id) async {
    final next = {..._favorites};
    if (!next.remove(id)) next.add(id);
    await FavoritesStore.save(_favKey, next.map((e) => '$e').toSet());
    if (!mounted) return;
    setState(() {
      _favorites = next;
      if (_onlyFavorites) _filterFavoritesInPlace();
    });
  }

  /// Rebuilds the visible list when only-favorites mode is on.
  ///
  /// WHY one query by id: this used to pull all 9,081 rows into memory and
  /// filter in Dart on every heart tap, on the UI thread. The ids are already
  /// known, so SQLite returns exactly those rows.
  void _filterFavoritesInPlace() {
    _items
      ..clear()
      ..addAll(_service.byIds(_favorites));
    _hasMore = false;
  }

  Future<void> _toggleOnlyFavorites() async {
    final next = !_onlyFavorites;
    setState(() => _onlyFavorites = next);
    if (next) {
      _filterFavoritesInPlace();
    } else {
      await _loadFirstPage();
    }
  }

  // ─── Random fatwa ─────────────────────────────────────────────

  void _openRandom() {
    final f = _service.random();
    if (f == null) return;
    _openDetail(f['id'] as int);
  }

  void _openDetail(int id) {
    final fatwa = _service.byId(id);
    if (fatwa == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _FatwaDetailScreen(
        fatwa: fatwa,
        isFavorite: _favorites.contains(id),
        onToggleFavorite: () => _toggleFavorite(id),
      ),
    ));
  }

  // ─── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'فتاوای شرعی',
        actions: [
          if (!_missing && !_checking) ...[
            IconButton(
              tooltip: 'فقط علاقه‌مندی‌ها',
              onPressed: _toggleOnlyFavorites,
              icon: Icon(
                _onlyFavorites ? Icons.favorite : Icons.favorite_border,
                color: _onlyFavorites ? const Color(0xFFE91E63) : null,
              ),
            ),
            IconButton(
              tooltip: 'فتوای تصادفی',
              onPressed: _openRandom,
              icon: const Icon(Icons.casino_outlined),
            ),
            IconButton(
              tooltip: 'حذف داده‌های دانلودشده',
              onPressed: _deleting ? null : _deleteDatabase,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _checking
            ? const Center(child: CircularProgressIndicator())
            : _missing
                ? _buildDownloadPrompt()
                : _buildContent(),
      ),
    );
  }

  Widget _buildDownloadPrompt() {
    final warning = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkWarning
        : AppTheme.lightWarning;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gavel_outlined, size: 44, color: accent),
            ),
            const SizedBox(height: 18),
            Text('فتاوای شرعی (فارسی)',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 17),
                  fontWeight: FontWeight.w800,
                  color: TimeThemeKit.of(context).palette.textPrimary,
                )),
            const SizedBox(height: 8),
            Text(
              'بیش از 9٬000 پرسش و پاسخ فقهی اهل سنت و جماعت\n'
              '(منبع: IslamPP.Com) — دانلود یک‌باره حدود 18 مگابایت',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                height: 1.9,
                color: TimeThemeKit.of(context).palette.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'پس از دانلود، کافی است یکی دو واژه بنویسید تا در میان '
              'هزاران فتوا جستجو کنید و پاسخ موردنظرتان را بیابید؛ '
              'بدون نیاز به اینترنت.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                height: 1.9,
                fontWeight: FontWeight.w600,
                color: TimeThemeKit.of(context).palette.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              kFatwaDisclaimer,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12),
                height: 1.9,
                fontWeight: FontWeight.w600,
                color: warning,
              ),
            ),
            const SizedBox(height: 24),
            if (_downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: _progress, minHeight: 6),
              ),
              const SizedBox(height: 10),
              Text('${(_progress * 100).toStringAsFixed(0)}٪',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: TimeThemeKit.of(context).palette.textMuted,
                  )),
            ] else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                onPressed: _downloadDatabase,
                icon: Icon(_outdated
                    ? Icons.system_update_alt
                    : Icons.download_outlined),
                label: Text(_outdated ? 'به‌روزرسانی' : 'دانلود داده‌ها',
                    style: TextStyle(fontFamily: AppTheme.fontFamily)),
              ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              FailureView(
                id: 'fatwa_db_download',
                title: 'دانلود دادهٔ فتواها کامل نشد',
                onRetry: _downloadDatabase,
                layout: FailureLayout.inline,
                icon: Icons.cloud_off,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'جستجو در فتاوا…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'پاک کردن جستجو',
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                ),
          filled: true,
          fillColor: TimeThemeKit.of(context).palette.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_searchMode) {
      if (_searching) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      final results = _results ?? const [];
      if (results.isEmpty) {
        return _buildEmpty('نتیجه‌ای برای این جستجو یافت نشد');
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.page, 4, DsSpacing.page, 24),
        itemCount: results.length + (_resultsTruncated ? 2 : 1),
        itemBuilder: (context, i) {
          if (i == 0) {
            final label = _resultsTruncated
                ? 'بیش از ${_toFaDigits(results.length)} نتیجه:'
                : '${_toFaDigits(results.length)} نتیجه یافت شد';
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
              child: Text(label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: TimeThemeKit.of(context).palette.textMuted,
                  )),
            );
          }
          final i0 = i - 1;
          if (i0 >= results.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('نتایج بیشتر موجود است — جستجو را دقیق‌تر کنید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 12),
                    color: TimeThemeKit.of(context).palette.textMuted,
                  )),
            );
          }
          final r = results[i0];
          return _FatwaCard(
            question: r['question'] as String,
            subtitle: r['snippet'] as String?,
            favorite: _favorites.contains(r['id'] as int),
            onToggleFavorite: () => _toggleFavorite(r['id'] as int),
            onTap: () => _openDetail(r['id'] as int),
          );
        },
      );
    }

    if (_onlyFavorites && _items.isEmpty) {
      return _buildEmpty('هنوز فتوایی به علاقه‌مندی‌ها افزوده نشده است');
    }
    if (_items.isEmpty) {
      return _buildEmpty('فتوایی در این دسته نیست');
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.page, 4, DsSpacing.page, 24),
      itemCount: _items.length + (_hasMore || _listFailed ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          if (_listFailed) {
            return Padding(
              padding: const EdgeInsets.all(10),
              child: FailureView(
                id: 'fatwa_load_more',
                title: 'بارگذاری بقیهٔ فتواها ناموفق بود',
                onRetry: () {
                  setState(() => _hasMore = true);
                  _loadMore();
                },
                layout: FailureLayout.inline,
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(14),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final r = _items[i];
        return _FatwaCard(
          question: r['question'] as String,
          favorite: _favorites.contains(r['id'] as int),
          onToggleFavorite: () => _toggleFavorite(r['id'] as int),
          onTap: () => _openDetail(r['id'] as int),
        );
      },
    );
  }

  Widget _buildEmpty(String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 40, color: TimeThemeKit.of(context).palette.textMuted),
            const SizedBox(height: 10),
            Text(msg,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13),
                  color: TimeThemeKit.of(context).palette.textMuted,
                )),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
// FATWA CARD
// ═══════════════════════════════════════════════════════════════

class _FatwaCard extends StatelessWidget {
  final String question;
  final String? subtitle;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const _FatwaCard({
    required this.question,
    this.subtitle,
    required this.favorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: TimeThemeKit.of(context).palette.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: TimeThemeKit.of(context).palette.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(question,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            height: 1.7,
                            color: TimeThemeKit.of(context).palette.textPrimary,
                          )),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              height: 1.8,
                              color: TimeThemeKit.of(context).palette.textMuted,
                            )),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // No SizedBox wrapper: tight constraints clamped the whole
                // button (and its hit area) to 34 dp. The explicit constraints
                // keep the same paint size while Material's padded tap target
                // restores the 48 dp hit area around it.
                IconButton.outlined(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 34, height: 34),
                  iconSize: 18,
                  tooltip: favorite
                      ? 'حذف از علاقه‌مندی‌ها'
                      : 'افزودن به علاقه‌مندی‌ها',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    color: favorite
                        ? const Color(0xFFE91E63)
                        : TimeThemeKit.of(context).palette.textMuted,
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

// ═══════════════════════════════════════════════════════════════
// DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════

/// The opened fatwa.
///
/// WHY stateful: it used to be a StatelessWidget holding `isFavorite` as a
/// final field passed once at push, so the parent's `setState` could never
/// rebuild it — the heart stayed hollow after a tap, the reader tapped again
/// believing the first tap missed, and un-favourited what they had just saved.
/// It now owns the flag, flips it optimistically, and tells the parent.
class _FatwaDetailScreen extends StatefulWidget {
  static const Color accent = TopicHues.fatwa;

  final Map<String, dynamic> fatwa;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _FatwaDetailScreen({
    required this.fatwa,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<_FatwaDetailScreen> createState() => _FatwaDetailScreenState();
}

class _FatwaDetailScreenState extends State<_FatwaDetailScreen> {
  late bool _favorite = widget.isFavorite;

  Map<String, dynamic> get fatwa => widget.fatwa;

  void _toggle() {
    setState(() => _favorite = !_favorite);
    widget.onToggleFavorite();
  }

  @override
  Widget build(BuildContext context) {
    // The hue lived on the widget as a static const; inside the State it has
    // to be named explicitly. Kept as a local const so the `const` widgets
    // below still compile.
    const accent = _FatwaDetailScreen.accent;
    final rawAnswer = (fatwa['answer'] ?? '') as String;
    // Prefer the server-side `full_question` column (added in the schema
    // migration); fall back to runtime parsing for already-downloaded DBs.
    final storedQuestion = (fatwa['full_question'] as String?)?.trim();
    final fullQuestion = (storedQuestion != null && storedQuestion.isNotEmpty)
        ? storedQuestion
        : FatwaService.splitFatwa(rawAnswer).fullQuestion;
    final title = (fatwa['question'] as String? ?? '').trim();
    final showQuestion = fullQuestion != null &&
        fullQuestion.isNotEmpty &&
        fullQuestion != title;
    final answer = (storedQuestion != null && storedQuestion.isNotEmpty)
        ? (fatwa['answer'] ?? '') as String
        : FatwaService.splitFatwa(rawAnswer).answer;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: fatwa['category'] as String? ?? 'فتوا',
        actions: [
          IconButton(
            tooltip: 'اشتراک‌گذاری',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final text =
                  '${fatwa['question']}\n\n${fatwa['answer']?.toString().trim()}\n\n'
                  '— فتاوای شرعی (فارسی)، منبع: IslamPP.Com';
              SharePlus.instance.share(ShareParams(text: text));
            },
          ),
          IconButton(
            tooltip: 'علاقه‌مندی',
            icon: Icon(
                _favorite ? Icons.favorite : Icons.favorite_border,
                color: _favorite ? const Color(0xFFE91E63) : null),
            onPressed: _toggle,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.page, 8, DsSpacing.page, 32),
            children: [
              // عنوان (خلاصه/عنوان سؤال).
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.label_outline,
                            size: 18, color: accent),
                        const SizedBox(width: 6),
                        Text('عنوان',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w800,
                              color: accent,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 15),
                          fontWeight: FontWeight.w700,
                          height: 1.9,
                          color: TimeThemeKit.of(context).palette.textPrimary,
                        )),
                  ],
                ),
              ),
              if (showQuestion) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.help_outline, size: 18, color: accent),
                    const SizedBox(width: 6),
                    Text('پرسش',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: accent,
                        )),
                  ],
                ),
                const SizedBox(height: 6),
                Text(fullQuestion,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14.5),
                      fontWeight: FontWeight.w600,
                      height: 1.9,
                      color: TimeThemeKit.of(context).palette.textPrimary,
                    )),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.gavel_outlined, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text('پاسخ',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w800,
                        color: accent,
                      )),
                ],
              ),
              const SizedBox(height: 6),
              Text(answer,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    height: 2.0,
                    color: TimeThemeKit.of(context).palette.textPrimary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

String _toFaDigits(Object? n) {
  const fa = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  return '$n'
      .replaceAllMapped(RegExp(r'\d'), (m) => fa[int.parse(m[0] ?? '0')]);
}
