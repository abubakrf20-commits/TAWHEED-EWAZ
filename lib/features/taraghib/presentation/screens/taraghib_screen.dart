import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/section_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_book_screen.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_chapter_screen.dart';
import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_matter_screen.dart';
import 'package:tawheeed/features/taraghib/services/taraghib_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';
import 'package:tawheeed/shared/widgets/app_snack_bar.dart';
import 'package:tawheeed/shared/widgets/content_database_delete_dialog.dart';

// ═══════════════════════════════════════════════════════════════
//  صحیح الترغیب — بخش مستقل مطالعه و محتوا
//  کتاب ← باب ← حدیث: 29 کتاب، 428 باب، 3775 حدیثِ شماره‌دار
//  + مقدمه و خاتمه در بخش‌های جداگانه؛ هر پانوشت زیر همان حدیثی که در
//  نسخهٔ چاپی زیرش آمده نمایش داده می‌شود.
// ═══════════════════════════════════════════════════════════════

class TaraghibScreen extends StatefulWidget {
  const TaraghibScreen({super.key, @visibleForTesting this.service});

  /// Test seam: a fake service can drive the database lifecycle without a
  /// real download or file system. Production builds their own.
  @visibleForTesting
  final TaraghibService? service;

  @override
  State<TaraghibScreen> createState() => _TaraghibScreenState();
}

class _TaraghibScreenState extends State<TaraghibScreen> {
  late final TaraghibService _service = widget.service ?? TaraghibService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _dbChecking = true;
  bool _dbMissing = false;
  bool _dbDownloading = false;
  bool _dbDeleting = false;

  /// True when the copy on disk is an older revision — the prompt then asks
  /// for an update instead of a first download.
  bool _dbUpdatePending = false;
  String? _dbError;
  String? _dbNotice;
  double _dbProgress = 0;

  List<Map<String, dynamic>>? _books;
  List<Map<String, dynamic>>? _chapters;
  List<Map<String, dynamic>>? _matters;
  Map<int, int>? _matterCounts;
  Map<int, Map<String, dynamic>>? _booksById;
  Map<int, Map<String, dynamic>>? _chaptersById;
  int? _totalHadiths;

  // search state: title hits + full-text hits (row + its chapter)
  List<Map<String, dynamic>>? _textResults;
  bool _searching = false;
  String? _searchError;

  /// Bumped on every keystroke and every search, so a slow query can never
  /// land its rows on a newer query's screen.
  int _searchSeq = 0;

  /// The query the rows in [_textResults] were found for — the field may have
  /// moved on, but the row and its destination must paint what matched.
  String _textQuery = '';

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
    });
    try {
      if (!await _service.isAvailable()) {
        if (mounted) {
          setState(() {
            _dbChecking = false;
            _dbMissing = true;
            _dbUpdatePending = false;
          });
        }
        return;
      }
      // An installed revision-1 copy has no books/matter tables and counts
      // 2,698 — opening it would show exactly the wrong numbers, so the
      // update gate must run BEFORE the database is opened.
      if (await _service.needsUpdate()) {
        if (mounted) {
          setState(() {
            _dbChecking = false;
            _dbMissing = true;
            _dbUpdatePending = true;
          });
        }
        return;
      }
      final opened = await _openAndLoad();
      if (mounted) {
        setState(() {
          _dbChecking = false;
          _dbMissing = !opened;
          _dbUpdatePending = false;
          _dbNotice = opened ? null : _reenterNotice;
        });
      }
    } catch (e) {
      AppLogger.warning('taraghib_screen', 'error: $e');
      if (mounted) {
        setState(() {
          _dbChecking = false;
          _dbMissing = true;
          _dbError = _openErrorNotice;
        });
      }
    }
  }

  /// Shown when the copy is on disk but could not be opened right away: the
  /// download itself succeeded, and re-entering the section opens it.
  static const _reenterNotice = 'کتاب دانلود شد، اما باز کردن آن ممکن نشد.\n'
      'لطفاً یکبار از این بخش خارج شوید و دوباره وارد شوید.';

  /// What the prompt says when reading or writing failed — never the thrown
  /// object's text: «SocketException: …» is not an explanation a reader can
  /// use. (ریاض الصالحین has said these from the start; this screen printed
  /// the raw error.)
  static const _downloadErrorNotice = 'دانلود کامل نشد؛ اتصال را بررسی کنید و '
      'دوباره بزنید.';
  static const _openErrorNotice = 'محتوا باز نشد. فایل روی این دستگاه ناقص '
      'مانده؛ «دانلود محتوا» آن را از نو می‌گیرد.';

  /// From how many letters a full-text read is worth its round trip. One
  /// letter matches almost every narration, which reads as «جست‌وجو خراب
  /// است»; the title filter stays live for shorter queries.
  static const int _searchMinimum = 2;

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
            'taraghib_screen', 'open attempt ${attempt + 1} failed: $e');
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
      AppLogger.warning('taraghib_screen', 'download failed: $e');
      if (mounted) {
        setState(() {
          _dbDownloading = false;
          _dbError = _downloadErrorNotice;
        });
      }
      return;
    }
    // The bytes are on disk. A transient hiccup while opening/loading them is
    // not a failed download — retry once, then tell the user to re-enter.
    final opened = await _openAndLoad(retries: 1);
    if (mounted) {
      setState(() {
        _dbDownloading = false;
        _dbMissing = !opened;
        _dbUpdatePending = false;
        _dbNotice = opened ? null : _reenterNotice;
      });
    }
  }

  Future<void> _loadContent() async {
    final books = await _service.books();
    final chapters = await _service.allChapters();
    final matters = await _service.matterSections();
    final matterCounts = await _service.matterParagraphCounts();
    final total = await _service.totalHadiths();
    if (!mounted) return;
    setState(() {
      _books = books;
      _chapters = chapters;
      _matters = matters;
      _matterCounts = matterCounts;
      _totalHadiths = total;
      _booksById = {for (final b in books) (b['id'] as int): b};
      _chaptersById = {for (final c in chapters) (c['id'] as int): c};
    });
  }

  /// Removes the downloaded database and its in-memory caches; the page falls
  /// back to its download prompt, which is also how the data comes back.
  Future<void> _deleteDatabase() async {
    final ok = await confirmContentDatabaseDelete(context, name: 'صحیح الترغیب');
    if (!ok || !mounted) return;
    setState(() => _dbDeleting = true);
    await _service.deleteDownloaded();
    if (!mounted) return;
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _dbDeleting = false;
      _dbMissing = true;
      _dbUpdatePending = false;
      _dbError = null;
      _dbNotice = null;
      _books = null;
      _chapters = null;
      _matters = null;
      _matterCounts = null;
      _booksById = null;
      _chaptersById = null;
      _totalHadiths = null;
      _textResults = null;
      _textQuery = '';
      _searching = false;
      _searchError = null;
    });
    AppSnackBar.success(context, 'دادهٔ صحیح الترغیب حذف شد.');
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    // Any answer still in flight belongs to the text that was just replaced.
    _searchSeq++;
    final query = v.trim();
    setState(() {
      _textResults = null;
      _textQuery = '';
      _searchError = null;
      _searching = false;
    });
    // The title filter in [_searchRows] is local and works for any query; the
    // full-text read is only worth its round trip from two letters.
    if (query.length < _searchMinimum) return;
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    final seq = ++_searchSeq;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final rows = await _service.search(query);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _textResults = rows;
        _textQuery = query.trim();
        _searching = false;
      });
    } catch (e) {
      AppLogger.warning('taraghib_screen', 'search failed: $e');
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _textResults = const [];
        _textQuery = query.trim();
        _searchError = 'جست‌وجو انجام نشد. دوباره تلاش کنید.';
        _searching = false;
      });
    }
  }

  /// Case/diacritic-insensitive match over any text field a row may carry.
  bool _matchesQuery(Object? text, String q) {
    final raw = text is String ? text : '';
    if (raw.isEmpty) return false;
    return TextHighlight.normalize(raw).contains(TextHighlight.normalize(q));
  }

  /// پرش مستقیم به یک حدیث با شمارهٔ پیوستهٔ این نسخه (1 تا 3775) — همان
  /// شماره‌ای که نشان «حدیث X» هر کارت و جست‌وجوی متن برمی‌گرداند.
  Future<void> _showJumpDialog() async {
    final max = await _service.maxHadithNumber();
    if (!mounted || max <= 0) return;
    final number = await showDialog<int>(
      context: context,
      builder: (context) => _TaraghibJumpDialog(max: max),
    );
    if (number == null || !mounted) return;
    final loc = await _service.locateHadithNumber(number);
    if (!mounted) return;
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'حدیث شمارهٔ ${_num(number)} در این نسخه موجود نیست.',
          style: TextStyle(fontFamily: AppTheme.fontFamily),
        ),
      ));
      return;
    }
    final chapter = await _service.chapterOf(loc.bookId, loc.chapterIndex);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TaraghibChapterScreen(
        bookId: loc.bookId,
        bookTitle: _bookTitleOf(loc.bookId),
        chapterIndex: loc.chapterIndex,
        chapterTitle: (chapter?['name_arabic'] ?? '') as String,
        initialHadithNumber: loc.number,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const accent = SectionColors.taraghib;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'صحیح الترغیب',
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
    final updating = _dbUpdatePending;
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
              child: Icon(
                  updating
                      ? Icons.system_update_alt_outlined
                      : Icons.local_florist_outlined,
                  size: 42,
                  color: accent),
            ),
            const SizedBox(height: 20),
            Text(updating ? 'به‌روزرسانی صحیح الترغیب' : 'صحیح الترغیب',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 20),
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              updating
                  ? 'نسخهٔ روی این دستگاه قدیمی است و کتاب‌ها، مقدمه، خاتمه و '
                      'پانوشت‌های درون متن را ندارد.\n'
                      '${_num(29)} کتاب · ${_num(428)} باب · '
                      '${_num(3775)} حدیث\n'
                      'دانلود یک‌باره حدود 2 مگابایت'
                  : 'ترجمهٔ شیخ موسی بازماندگان\n'
                      '${_num(29)} کتاب · ${_num(428)} باب · '
                      '${_num(3775)} حدیث\n'
                      'به‌همراه مقدمه، خاتمه و پانوشت‌های زیر هر حدیث\n'
                      'دانلود یک‌باره حدود 2 مگابایت',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 13.5),
                  height: 1.9,
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ),
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
                label: Text(updating ? 'به‌روزرسانی محتوا' : 'دانلود محتوا',
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
            if (_dbNotice != null) ...[
              const SizedBox(height: 12),
              Text(_dbNotice!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: accent,
                      fontSize: AppTheme.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Ready ───────────────────────────────────────────────────

  Widget _buildReady(BuildContext context, Color accent) {
    final query = _searchCtrl.text.trim();

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
              hintText: 'جست‌وجو در کتاب‌ها، باب‌ها و متن احادیث…',
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
        Expanded(child: _buildBody(context, accent, query)),
      ],
    );
  }

  Widget _buildHeaderCard(Color accent) {
    final bookCount = _books?.length ?? 0;
    final chapterCount = _chapters?.length ?? 0;
    final hadithCount = _totalHadiths ?? 0;
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
                  Text('صحیح الترغیب و الترهیب',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 15.5),
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    'علامه منذری · تخریج علامه البانی · ترجمهٔ شیخ موسی بازماندگان',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11.5),
                        color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (bookCount > 0)
                        _statChip('${_num(bookCount)} کتاب', accent),
                      if (chapterCount > 0)
                        _statChip('${_num(chapterCount)} باب', accent),
                      if (hadithCount > 0)
                        _statChip('${_num(hadithCount)} حدیث', accent),
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

  Widget _buildBody(BuildContext context, Color accent, String query) {
    // Only a read in flight spins. Waiting on «no answer for this query yet»
    // hung the page for queries that never search — one letter, or the empty
    // field the debounce was cancelled on.
    if (_searching) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // A hit is shown only for the query it was found for: a slow read can land
    // after the field moved on, and `_textQuery` is also what the highlight
    // marks in the row. Until an answer exists the title matches stay up, so
    // typing never shows «چیزی پیدا نشد» for a search that has not run yet.
    final answered =
        query.isNotEmpty && _textResults != null && _textQuery == query;
    final rows = query.isEmpty
        ? _browseRows(accent)
        : _searchRows(query, accent, answered);
    return ListView.builder(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 32),
      itemCount: rows.length,
      itemBuilder: (context, i) => rows[i],
    );
  }

  /// The default page: مقدمه، کتاب‌ها، then خاتمه. The edition's فهرست مطالب
  /// is not stored — it repeats the book and باب list this page already shows.
  List<Widget> _browseRows(Color accent) {
    final books = _books ?? const <Map<String, dynamic>>[];
    final matters = _matters ?? const <Map<String, dynamic>>[];
    final intro = matters.where((m) => m['kind'] == 'intro').toList();
    final khatimah = matters.where((m) => m['kind'] == 'khatimah').toList();

    final rows = <Widget>[];
    if (intro.isNotEmpty) {
      rows.add(_sectionLabel('مقدمه'));
      rows.addAll(intro.map((m) => _matterTile(m, accent)));
    }
    rows.add(_sectionLabel('کتاب‌ها (${_num(books.length)})'));
    if (books.isEmpty) {
      rows.add(_emptyLine('کتابی برای این نسخه ثبت نشده است.'));
    } else {
      rows.addAll(books.map((b) => _bookTile(b, accent)));
    }
    if (khatimah.isNotEmpty) {
      rows.add(_sectionLabel('خاتمه و پایان جلدها'));
      rows.addAll(khatimah.map((m) => _matterTile(m, accent)));
    }
    return rows;
  }

  /// Search mode: the full-text hits first, then every book, باب and matter
  /// section whose own title matches the query.
  List<Widget> _searchRows(String query, Color accent, bool answered) {
    final hits = answered
        ? (_textResults ?? const <Map<String, dynamic>>[])
        : const <Map<String, dynamic>>[];
    final books = (_books ?? const <Map<String, dynamic>>[])
        .where((b) =>
            _matchesQuery(b['title_persian'], query) ||
            _matchesQuery(b['title_arabic'], query))
        .toList();
    final chapters = (_chapters ?? const <Map<String, dynamic>>[])
        .where((c) =>
            _matchesQuery(c['name_persian'], query) ||
            _matchesQuery(c['name_arabic'], query))
        .toList();
    final matters = (_matters ?? const <Map<String, dynamic>>[])
        .where((m) => _matchesQuery(m['title'], query))
        .toList();

    final rows = <Widget>[];
    if (answered) {
      // A capped list must say it is capped: «(30)» next to a book of 3,775
      // narrations claimed the search had found exactly thirty matches.
      rows.add(_sectionLabel(hits.length >= TaraghibService.searchLimit
          ? 'نتایج متن (${_num(hits.length)} نتیجهٔ نخست)'
          : 'نتایج متن (${_num(hits.length)})'));
      if (hits.isEmpty) {
        rows.add(_emptyLine(
            _searchError ?? 'در متن احادیث نتیجه‌ای برای این عبارت یافت نشد.'));
      } else {
        rows.addAll(hits.map((r) => _searchResultTile(r, accent)));
      }
      rows.add(const SizedBox(height: 4));
    }

    rows.add(_sectionLabel('کتاب‌ها، باب‌ها و بخش‌های هم‌نام'));
    if (books.isEmpty && chapters.isEmpty && matters.isEmpty) {
      rows.add(_emptyLine('کتاب یا بابی با این عنوان یافت نشد.'));
    } else {
      rows.addAll(books.map((b) => _bookTile(b, accent)));
      rows.addAll(chapters.map((c) => _chapterTile(c, accent)));
      rows.addAll(matters.map((m) => _matterTile(m, accent)));
    }
    return rows;
  }

  Widget _emptyLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 12.5),
                color: Theme.of(context).textTheme.bodySmall?.color)),
      ),
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

  // ─── Row builders ────────────────────────────────────────────

  /// The Persian title the edition prints, falling back to the Arabic heading
  /// (every book carries one; `title_english` is empty in this edition).
  String _bookTitle(Map<String, dynamic> book) {
    final persian = (book['title_persian'] ?? '') as String;
    if (persian.isNotEmpty) return persian;
    return (book['title_arabic'] ?? '') as String;
  }

  String? _bookTitleOf(int bookId) {
    final book = _booksById?[bookId];
    return book == null ? null : _bookTitle(book);
  }

  /// The Persian chapter title when the edition prints one — `name_arabic` is
  /// the combined printed heading and is what the chapter page itself shows.
  String _chapterTitle(Map<String, dynamic> ch) {
    final persian = (ch['name_persian'] ?? '') as String;
    if (persian.isNotEmpty) return persian;
    return (ch['name_arabic'] ?? '') as String;
  }

  /// One کتاب row. The badge is the PRINTED book number — the divider book
  /// the edition prints without a numeral falls back to an icon, never to the
  /// position it happens to hold in the list.
  Widget _bookTile(Map<String, dynamic> book, Color accent) {
    final bookNo = book['book_no'] as num?;
    final chapterCount = book['chapter_count'] as num? ?? 0;
    final hadithCount = book['hadith_count'] as num? ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaraghibBookScreen(book: book),
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
                  child: bookNo == null
                      ? Icon(Icons.book_outlined, size: 20, color: accent)
                      : Text(_num(bookNo),
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w800,
                              fontSize: AppTheme.scaledFontSize(context, 13),
                              color: accent)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_bookTitle(book),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w600,
                              height: 1.7)),
                      const SizedBox(height: 2),
                      Text(
                          '${_num(chapterCount)} باب · '
                          '${_num(hadithCount)} حدیث',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 10.5),
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color)),
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

  /// One باب row. The badge is the chapter's PRINTED number inside its own
  /// book (10 chapters print none; those fall back to the per-book index), and
  /// the row always carries its book because a chapter index repeats in every
  /// book.
  Widget _chapterTile(Map<String, dynamic> ch, Color accent) {
    final bookId = (ch['book_id'] as num).toInt();
    final idx = ch['chapter_index'] as num;
    final badge = ch['printed_number'] as num? ?? idx.toInt();
    final bookTitle = _bookTitleOf(bookId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaraghibChapterScreen(
              bookId: bookId,
              bookTitle: bookTitle,
              chapterIndex: idx,
              chapterTitle: (ch['name_arabic'] ?? '') as String,
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
                  child: Text(_num(badge),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: AppTheme.scaledFontSize(context, 13),
                          color: accent)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_chapterTitle(ch),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w600,
                              height: 1.7)),
                      if (bookTitle != null && bookTitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(bookTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize:
                                    AppTheme.scaledFontSize(context, 10.5),
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color)),
                      ],
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

  /// One مقدمه/خاتمه row. The unit word follows the section's kind: a خاتمه
  /// is a series of paragraphs like a مقدمه, so both read «بند».
  Widget _matterTile(Map<String, dynamic> section, Color accent) {
    final id = (section['id'] as num).toInt();
    final kind = (section['kind'] ?? '') as String;
    final count = _matterCounts?[id] ?? 0;
    final (IconData icon, String unit) = switch (kind) {
      'khatimah' => (Icons.history_edu_outlined, 'بند'),
      _ => (Icons.article_outlined, 'بند'),
    };
    final title = (section['title'] ?? '') as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaraghibMatterScreen(section: section),
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
                  child: Icon(icon, size: 19, color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title.isNotEmpty
                        ? title
                        : (section['source_title'] ?? '') as String,
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
                Text('${_num(count)} $unit',
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
    final chapterId = row['chapter_id'] as int?;
    final chapter = chapterId == null ? null : _chaptersById?[chapterId];
    final bookId = (chapter?['book_id'] as num?)?.toInt() ??
        (row['book_id'] as num?)?.toInt();
    final chIdx = chapter?['chapter_index'] as num?;
    final bookTitle = bookId == null ? null : _bookTitleOf(bookId);
    final chTitle = chapter == null ? null : _chapterTitle(chapter);
    final hadithNo = row['hadith_number'] as int?;

    VoidCallback? onTap;
    if (bookId != null && chIdx != null) {
      onTap = () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaraghibChapterScreen(
              bookId: bookId,
              bookTitle: bookTitle,
              chapterIndex: chIdx,
              chapterTitle: (chapter?['name_arabic'] ?? '') as String,
              initialHadithNumber: hadithNo,
              initialQuery: _textQuery,
            ),
          ));
    }

    final hasBook = bookTitle != null && bookTitle.isNotEmpty;
    final hasChapter = chTitle != null && chTitle.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasBook)
                  Text('کتاب: $bookTitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w700,
                          color: accent)),
                if (hasChapter) ...[
                  if (hasBook) const SizedBox(height: 2),
                  Text('باب: $chTitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodySmall?.color)),
                ],
                if (hasBook || hasChapter) const SizedBox(height: 6),
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
/// شماره‌های پیوستهٔ این نسخه (1 تا [max]). مقدار خارج از بازه پذیرفته نمی‌شود؛
/// شماره‌هایی که در این نسخه وجود ندارند، پس از تأیید با پیام خطا نشان داده
/// می‌شوند.
class _TaraghibJumpDialog extends StatefulWidget {
  final int max;
  const _TaraghibJumpDialog({required this.max});

  @override
  State<_TaraghibJumpDialog> createState() => _TaraghibJumpDialogState();
}

class _TaraghibJumpDialogState extends State<_TaraghibJumpDialog> {
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
    const accent = SectionColors.taraghib;
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
            'شمارهٔ حدیث از 1 تا ${_num(widget.max)} — همان شماره‌ای که روی هر حدیث نوشته شده',
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
