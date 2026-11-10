import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_chapter_screen.dart';
import 'package:tawheeed/features/hadith/services/part_books.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_book_screen.dart';
import 'package:tawheeed/features/riyad/presentation/screens/riyad_intro_screen.dart';
import 'package:tawheeed/features/riyad/services/riyad_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/widgets/content_database_delete_dialog.dart';

// ═══════════════════════════════════════════════════════════════
//  ریاض الصالحین — بخش مستقل مطالعه و محتوا
//  فهرست ۳۷۲ بابِ کتاب با سرفصلِ «کتاب»هایی که هر باب زیرِ آن چاپ شده،
//  مقدمه‌های جلد نخست، و جست‌وجو در عنوان و متن.
// ═══════════════════════════════════════════════════════════════

class RiyadScreen extends StatefulWidget {
  const RiyadScreen({super.key, @visibleForTesting this.service});

  /// Test seam: the caller's service, so a widget test can drive a fake
  /// database without the download flow.
  @visibleForTesting
  final RiyadService? service;

  @override
  State<RiyadScreen> createState() => _RiyadScreenState();
}

class _RiyadScreenState extends State<RiyadScreen> {
  late final RiyadService _service = widget.service ?? RiyadService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _dbChecking = true;
  bool _dbMissing = false;
  bool _dbDownloading = false;
  bool _dbDeleting = false;

  /// True only when the copy on disk is an older revision. The download button
  /// used to read this off `_dbNotice != null`, so a copy that had just been
  /// downloaded but failed to open also offered «دانلود نسخهٔ جدید».
  bool _dbOutdated = false;
  String? _dbError;
  String? _dbNotice;
  double _dbProgress = 0;

  List<Map<String, dynamic>>? _chapters;
  Map<num, int>? _hadithCounts;
  List<Map<String, dynamic>> _matters = const [];
  int _hadithTotal = 0;

  // search state: title hits + full-text hits (row + its bab index)
  List<Map<String, dynamic>>? _textResults;
  Map<int, num>? _chapterIndexById;
  bool _searching = false;
  bool _searchFailed = false;

  /// The query the rows in [_textResults] were found for — the field may have
  /// moved on, but the row and its destination must paint what matched.
  String _textQuery = '';

  /// Every keystroke and every new search takes a number; an answer whose
  /// number is older than the current one is thrown away. Without it a slow
  /// read of «زکات» landing after the reader typed «زکات‌دهنده» painted the
  /// old rows under the new word — including the word it highlighted.
  int _searchGeneration = 0;

  /// Rows the search asks for. The list is capped, so the header cannot claim a
  /// total it does not have.
  static const int _searchLimit = RiyadService.searchLimit;

  static const _reenterNotice = 'کتاب دانلود شد، اما باز کردن آن ممکن نشد.\n'
      'لطفاً یک‌بار از این بخش خارج شوید و دوباره وارد شوید.';

  /// What the prompt says when reading or writing failed — never the thrown
  /// object's text: «SocketException: …» is not an explanation a reader can use.
  static const _downloadErrorNotice = 'دانلود کامل نشد؛ اتصال را بررسی کنید و '
      'دوباره بزنید.';
  static const _openErrorNotice = 'محتوا باز نشد. فایل روی این دستگاه ناقص '
      'مانده؛ «دانلود محتوا» آن را از نو می‌گیرد.';

  /// Shown when the copy on disk predates the republished database.
  static const _outdatedNotice = 'نسخهٔ تصحیح‌شدهٔ کتاب منتشر شده است؛ '
      'برای دریافت، دوباره دانلود کنید.';

  @override
  void initState() {
    super.initState();
    _checkDatabase();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkDatabase() async {
    setState(() {
      _dbChecking = true;
      _dbError = null;
      _dbNotice = null;
      _dbOutdated = false;
    });
    try {
      if (!await _service.isAvailable()) {
        if (mounted) {
          setState(() {
            _dbChecking = false;
            _dbMissing = true;
          });
        }
        return;
      }
      // The six-volume build replaced the copy cut out of hadith.db (366 باب,
      // no footnotes, numbering in a bundled label table); a copy that
      // predates that revision must be replaced, not opened forever.
      if (await _service.needsUpdate()) {
        if (mounted) {
          setState(() {
            _dbChecking = false;
            _dbMissing = true;
            _dbOutdated = true;
            _dbNotice = _outdatedNotice;
          });
        }
        return;
      }
      final opened = await _openAndLoad();
      if (mounted) {
        setState(() {
          _dbChecking = false;
          _dbMissing = !opened;
          _dbNotice = opened ? null : _reenterNotice;
        });
      }
    } catch (e) {
      AppLogger.warning('riyad_screen', 'error: $e');
      if (mounted) {
        setState(() {
          _dbChecking = false;
          _dbMissing = true;
          _dbError = _openErrorNotice;
        });
      }
    }
  }

  /// Opens the database and loads its content, retrying [retries] times.
  /// Returns whether the content loaded; never throws.
  Future<bool> _openAndLoad({int retries = 0}) async {
    for (var attempt = 0;; attempt++) {
      try {
        await _service.ensureReady();
        await _loadContent();
        return true;
      } catch (e) {
        AppLogger.warning(
            'riyad_screen', 'open attempt ${attempt + 1} failed: $e');
        if (attempt >= retries) return false;
      }
    }
  }

  Future<void> _downloadDatabase() async {
    setState(() {
      _dbDownloading = true;
      _dbError = null;
      _dbNotice = null;
      _dbProgress = 0;
    });
    try {
      await _service.download(onProgress: (received, total) {
        if (!mounted) return;
        setState(() => _dbProgress = total > 0 ? received / total : 0);
      });
    } catch (e) {
      AppLogger.warning('riyad_screen', 'download failed: $e');
      if (mounted) {
        setState(() {
          _dbDownloading = false;
          _dbError = _downloadErrorNotice;
        });
      }
      return;
    }
    // The bytes are on disk. A transient hiccup while opening them is not a
    // failed download — retry once, then ask the reader to re-enter.
    final opened = await _openAndLoad(retries: 1);
    if (mounted) {
      setState(() {
        _dbDownloading = false;
        _dbMissing = !opened;
        _dbOutdated = false;
        _dbNotice = opened ? null : _reenterNotice;
      });
    }
  }

  Future<void> _loadContent() async {
    final chapters = await _service.chapters();
    final hadithCounts = await _service.hadithCountsPerChapter();
    final matters = await _service.matterSections();
    final total = await _service.totalEntries();
    if (!mounted) return;
    setState(() {
      _chapters = chapters;
      _hadithCounts = hadithCounts;
      _matters = matters;
      _hadithTotal = total;
      _chapterIndexById = {
        for (final c in chapters) (c['id'] as int): c['chapter_index'] as num,
      };
    });
  }

  /// Removes the downloaded database; the page falls back to its download
  /// prompt, which is also how the data comes back.
  Future<void> _deleteDatabase() async {
    final ok =
        await confirmContentDatabaseDelete(context, name: 'ریاض الصالحین');
    if (!ok || !mounted) return;
    setState(() => _dbDeleting = true);
    await _service.deleteDownloaded();
    if (!mounted) return;
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _dbDeleting = false;
      _dbMissing = true;
      _dbOutdated = false;
      _dbNotice = null;
      _dbError = null;
      _chapters = null;
      _hadithCounts = null;
      _matters = const [];
      _hadithTotal = 0;
      _chapterIndexById = null;
      _textResults = null;
      _textQuery = '';
      _searching = false;
      _searchFailed = false;
    });
    AppSnackBar.success(context, 'دادهٔ ریاض الصالحین حذف شد.');
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    // Any answer still in flight belongs to the text that was just replaced.
    _searchGeneration++;
    final query = v.trim();
    setState(() {
      _textResults = null;
      _textQuery = '';
      _searching = false;
      _searchFailed = false;
    });
    // The title filter works for any query and is local; the database read is
    // only worth its round trip from two letters (one letter matches almost
    // every narration, which reads as «جست‌وجو خراب است»).
    if (query.length < 2) return;
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    final generation = ++_searchGeneration;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final rows = await _service.search(q);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _textResults = rows;
        _textQuery = q;
        _searching = false;
      });
    } catch (e) {
      AppLogger.warning('riyad_screen', 'search failed: $e');
      if (!mounted || generation != _searchGeneration) return;
      // The old rows are gone with the query they belonged to; the panel says
      // what failed instead of leaving yesterday's answer on screen.
      setState(() {
        _searching = false;
        _searchFailed = true;
        _textResults = null;
        _textQuery = '';
      });
    }
  }

  bool _titleMatches(Map<String, dynamic> ch, String q) =>
      TextHighlight.normalize((ch['name_arabic'] ?? '') as String)
          .contains(TextHighlight.normalize(q));

  /// پرش مستقیم به یک حدیث با شمارهٔ همین نسخه (1 تا 1,897).
  Future<void> _showJumpDialog() async {
    final max = await _service.maxHadithNumber();
    if (!mounted || max <= 0) return;
    final number = await showDialog<int>(
      context: context,
      builder: (context) => _RiyadJumpDialog(max: max),
    );
    if (number == null || !mounted) return;
    final loc = await _service.locateHadithNumber(number);
    if (!mounted) return;
    if (loc == null) {
      AppSnackBar.warning(
          context, 'حدیث شمارهٔ ${_num(number)} در این نسخه موجود نیست.');
      return;
    }
    final (chIdx, hadithNumber) = loc;
    final chTitle = _chapters?.firstWhere(
            (c) => (c['chapter_index'] as num).toDouble() == chIdx,
            orElse: () => const {})['name_arabic'] as String? ??
        '';
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RiyadChapterScreen(
        chapterIndex: chIdx,
        chapterTitle: chTitle,
        initialHadithNumber: hadithNumber,
      ),
    ));
  }

  Future<void> _openChapter(Map<String, dynamic> ch) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RiyadChapterScreen(
        chapterIndex: ch['chapter_index'] as num,
        chapterTitle: (ch['name_arabic'] ?? '') as String,
      ),
    ));
  }

  void _openIntro() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RiyadIntroScreen(
        sections: _matters,
        service: widget.service,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.riyad;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'ریاض الصالحین',
        actions: [
          if (!_dbChecking && !_dbMissing) ...[
            IconButton(
              icon: const Icon(Icons.numbers, size: 20),
              tooltip: 'پرش به شماره حدیث',
              onPressed: _showJumpDialog,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: 'حذف داده‌های دانلودشده',
              onPressed: _dbDeleting ? null : _deleteDatabase,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _dbChecking
            ? const Center(child: CircularProgressIndicator())
            : _dbMissing
                ? _buildDownloadPrompt(accent)
                : _buildReady(context, accent),
      ),
    );
  }

  // ─── Download prompt ─────────────────────────────────────────

  Widget _buildDownloadPrompt(Color accent) {
    final danger = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkError
        : AppTheme.lightError;
    return Center(
      child: SingleChildScrollView(
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
              child:
                  Icon(Icons.local_florist_outlined, size: 42, color: accent),
            ),
            const SizedBox(height: 20),
            Text('ریاض الصالحین',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 20),
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'شرح کامل علامه عثیمین با ترجمهٔ فارسی\n'
              'دانلود یک‌باره حدود ۳٫۴ مگابایت',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13.5),
                  height: 1.9,
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            if (_dbNotice != null) ...[
              const SizedBox(height: 14),
              Text(_dbNotice!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w700,
                      color: accent)),
            ],
            const SizedBox(height: 24),
            if (_dbDownloading) ...[
              LinearProgressIndicator(value: _dbProgress, color: accent),
              const SizedBox(height: 10),
              Text('در حال دانلود… ${(_dbProgress * 100).toStringAsFixed(0)}٪',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ] else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: _downloadDatabase,
                icon: const Icon(Icons.download_outlined),
                label: Text(
                    _dbOutdated ? 'دانلود نسخهٔ جدید' : 'دانلود محتوا',
                    style: TextStyle(fontFamily: AppTheme.fontFamily)),
              ),
            if (_dbError != null) ...[
              const SizedBox(height: 12),
              Text(_dbError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: danger,
                      fontSize: AppTheme.scaledFontSize(context, 12))),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Ready ───────────────────────────────────────────────────

  Widget _buildReady(BuildContext context, Color accent) {
    final query = _searchCtrl.text.trim();
    final chapters = _chapters ?? const [];
    // Title matches are computed for every query. They used to be dropped the
    // moment a text search answered — `_textResults != null` made this null —
    // and the body then fell back to *every* chapter, so a search painted all
    // 372 باب under its hits and called the section «یافت نشد».
    final filtered = query.isEmpty
        ? null
        : chapters.where((c) => _titleMatches(c, query)).toList();

    return Column(
      children: [
        _buildHeaderCard(accent),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'جست‌وجو در باب‌ها و متن احادیث…',
              prefixIcon: Icon(Icons.search, color: accent),
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody(context, accent, query, filtered)),
      ],
    );
  }

  Widget _buildHeaderCard(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.local_florist_outlined, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('شرح ریاض الصالحین',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 15.5),
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    'علامه محمد بن صالح العثیمین · ترجمهٔ محمد ابراهیم کیانی',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11.5),
                        color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 5),
                  // Two counts, not a row of fixed cells: at a large text
                  // scale «372 باب» plus «1897 حدیث» are wider than the card's
                  // text column, and the second chip was cut off.
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _statChip('${_num(_chapters?.length ?? 0)} باب', accent),
                      _statChip('${_num(_hadithTotal)} حدیث', accent),
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

  Widget _statChip(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 11),
              fontWeight: FontWeight.w700,
              color: accent)),
    );
  }

  Widget _buildBody(BuildContext context, Color accent, String query,
      List<Map<String, dynamic>>? filteredChapters) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // A hit is shown only for the query it was found for: a slow read can land
    // after the field moved on, and `_textQuery` is also what the highlight
    // marks in the row.
    final showTextResults =
        query.isNotEmpty && _textResults != null && _textQuery == query;
    final chapters = _chapters ?? const <Map<String, dynamic>>[];
    final textRows =
        showTextResults ? _textResults! : const <Map<String, dynamic>>[];
    // A query is a match set, not the book's traversal: only the باب‌ها whose
    // title matched are listed below the text hits.
    final tiles = filteredChapters ?? const <Map<String, dynamic>>[];

    // The edition's chain is کتاب › فصل › باب. The reader asked for the three
    // steps صحیح الترغیب has — کتاب › باب › حدیث — so the default page lists the
    // book's own «کتاب»s and each one opens its باب‌ها. A query is a match set,
    // not the book's traversal, so it keeps listing matching باب‌ها directly.
    final books = query.isEmpty ? partBooksOf(chapters) : const <PartBook>[];
    final rows = <Object>[
      if (query.isEmpty) ...books else ...tiles,
    ];

    final header = <Widget>[
      if (showTextResults)
        _sectionLabel(textRows.length >= _searchLimit
            ? 'نتایج متن (${_num(textRows.length)} نتیجهٔ نخست)'
            : 'نتایج متن (${_num(textRows.length)})'),
    ];
    final mid = <Widget>[
      if (_searchFailed)
        FailureView(
          id: 'riyad_search',
          title: 'جست‌وجو انجام نشد',
          detail: 'متن روی این دستگاه است و جایی نرفته؛ فقط این جست‌وجو '
              'نتوانست بخواندش. باب‌های هم‌نام پایین‌تر همچنان فهرست شده‌اند.',
          onRetry: () => _performSearch(_searchCtrl.text),
        ),
      if (showTextResults) ...[
        if (textRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('در متن حدیثی با این واژه پیدا نشد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ),
          ),
        const SizedBox(height: 12),
      ],
      if (query.isEmpty && _matters.isNotEmpty)
        _introTile(accent),
      _sectionLabel(query.isEmpty
          ? 'کتاب‌ها (${_num(books.length)})'
          : tiles.isNotEmpty
              ? 'باب‌های هم‌نام (${_num(tiles.length)})'
              : 'باب‌هایی با این عنوان یافت نشد'),
    ];

    return ListView.builder(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 32),
      itemCount: header.length + textRows.length + mid.length + rows.length,
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        final a = i - header.length;
        if (a < textRows.length) return _searchResultTile(textRows[a], accent);
        final b = a - textRows.length;
        if (b < mid.length) return mid[b];
        final c = b - mid.length;
        final row = rows[c];
        if (row is PartBook) return _bookTile(row, accent);
        final ch = row as Map<String, dynamic>;
        return _chapterTile(ch, (ch['chapter_index'] as num).toInt(), accent);
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(text,
          style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodySmall?.color)),
    );
  }

  /// One «کتاب» of the edition: its own title and how many باب‌ها and
  /// narrations it holds. Tapping it opens the bab list.
  Widget _bookTile(PartBook book, Color accent) {
    final hadiths = book.chapters.fold<int>(
        0, (sum, ch) => sum + (_hadithCounts?[ch['chapter_index']] ?? 0));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RiyadBookScreen(
              book: book,
              hadithCounts: _hadithCounts ?? const {},
            ),
          )),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.menu_book_rounded, size: 19, color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w600,
                              height: 1.7)),
                      const SizedBox(height: 2),
                      Text(
                          '${_num(book.babCount)} باب · '
                          '${_num(hadiths)} حدیث',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 10.5),
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_left,
                    size: 18,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// «مقدمه‌ها» — درآمدی بر کتاب، دو زندگینامه و مقدمه‌ی مؤلف. این‌ها حدیث
  /// نیستند و در فهرست باب‌ها نمی‌آیند.
  Widget _introTile(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openIntro,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.menu_book_outlined, size: 20, color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مقدمه‌ها',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        _matters.map((m) => (m['title'] ?? '') as String).join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10.5),
                            color: Theme.of(context).textTheme.bodySmall?.color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left,
                    size: 18,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chapterTile(Map<String, dynamic> ch, int number, Color accent) {
    final idx = ch['chapter_index'] as num;
    final count = _hadithCounts?[idx.toDouble()] ?? _hadithCounts?[idx] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openChapter(ch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(_num(number),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: accent)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    (ch['name_arabic'] ?? '') as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w600,
                        height: 1.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(count == 0 ? 'شرح' : '${_num(count)} حدیث',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10.5),
                        color: Theme.of(context).textTheme.bodySmall?.color)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left,
                    size: 18,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchResultTile(Map<String, dynamic> row, Color accent) {
    final text = ((row['arabic'] ?? '') as String).trim();
    final snippet = text.length > 180 ? '${text.substring(0, 180)}…' : text;
    final snippetStyle = TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 12.5),
        height: 1.9);
    final chIdx = _chapterIndexById?[row['chapter_id'] as int];
    final chTitle = _chapters?.firstWhere((c) => c['id'] == row['chapter_id'],
        orElse: () => const {})['name_arabic'];
    final hadithNo = row['hadith_number'] as int?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: chIdx == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RiyadChapterScreen(
                      chapterIndex: chIdx,
                      chapterTitle: (chTitle ?? '') as String,
                      initialHadithNumber: hadithNo,
                      initialQuery: _textQuery,
                    ),
                  )),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((chTitle ?? '') != '')
                  Text('باب: ${chTitle as String}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w700,
                          color: accent)),
                if ((chTitle ?? '') != '') const SizedBox(height: 6),
                if (_textQuery.isEmpty)
                  Text(snippet,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: snippetStyle)
                else
                  Text.rich(
                    TextSpan(
                      children: TextHighlight.spans(
                        snippet,
                        _textQuery,
                        baseStyle: snippetStyle,
                        highlightStyle: TextHighlight.defaultHighlightStyle(
                            context,
                            base: snippetStyle),
                      ),
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _num(Object? n) => '$n';

/// «پرش به شماره حدیث» — یک فیلد عددی همراه با اسلایدر برای پیمایش سریع در
/// شماره‌های همین نسخه (1 تا [max]). مقدار خارج از بازه پذیرفته نمی‌شود.
class _RiyadJumpDialog extends StatefulWidget {
  final int max;
  const _RiyadJumpDialog({required this.max});

  @override
  State<_RiyadJumpDialog> createState() => _RiyadJumpDialogState();
}

class _RiyadJumpDialogState extends State<_RiyadJumpDialog> {
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
    final parsed = int.tryParse(raw.trim());
    final valid = raw.trim().isNotEmpty &&
        parsed != null &&
        parsed >= 1 &&
        parsed <= widget.max;
    setState(() {
      _value = valid ? parsed : null;
      if (valid) _slider = parsed.toDouble();
    });
  }

  void _fromSlider(double v) {
    final n = v.round().clamp(1, widget.max);
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
    const accent = TopicHues.riyad;
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
            'شمارهٔ حدیث از 1 تا ${_num(widget.max)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 12.5),
              color: Theme.of(context).textTheme.bodySmall?.color,
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
              errorText: invalid ? 'از 1 تا ${_num(widget.max)}' : null,
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
            value: _slider.clamp(1, widget.max.toDouble()),
            min: 1,
            max: widget.max.toDouble(),
            activeColor: accent,
            label: '${_slider.round()}',
            onChanged: _fromSlider,
          ),
          Text(
            _num(_slider.round()),
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
