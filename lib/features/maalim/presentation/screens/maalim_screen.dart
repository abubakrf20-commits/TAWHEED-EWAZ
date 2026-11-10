import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/hadith/services/part_books.dart';
import 'package:tawheeed/features/maalim/presentation/screens/maalim_book_screen.dart';
import 'package:tawheeed/features/maalim/presentation/screens/maalim_matter_screen.dart';
import 'package:tawheeed/features/maalim/services/maalim_service.dart';
import 'package:tawheeed/features/maalim/presentation/screens/maalim_chapter_screen.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

// ═══════════════════════════════════════════════════════════════
//  معالم السنه النبویه — بخش مستقل مطالعه و محتوا
//  فهرستِ ۱٬۹۲۹ بابِ خودِ کتاب با سرفصل مقصد/کتاب/فصل + جست‌وجو در عنوان
//  باب‌ها و متن احادیث. آمارِ سرصفحه از خودِ پایگاه‌داده شمرده می‌شود، نه از
//  عددی که در کد نوشته شده باشد.
// ═══════════════════════════════════════════════════════════════

class MaalimScreen extends StatefulWidget {
  const MaalimScreen({super.key, @visibleForTesting this.service});

  /// Test seam: a fake service can drive the database lifecycle without a
  /// real download or file system. Production builds their own.
  @visibleForTesting
  final MaalimService? service;

  @override
  State<MaalimScreen> createState() => _MaalimScreenState();
}

class _MaalimScreenState extends State<MaalimScreen> {
  late final MaalimService _service = widget.service ?? MaalimService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _dbChecking = true;
  bool _dbMissing = false;
  bool _dbDownloading = false;
  String? _dbError;
  String? _dbNotice;
  double _dbProgress = 0;

  List<Map<String, dynamic>>? _chapters;
  Map<num, int>? _hadithCounts;

  /// مقدمه‌های کتاب و خاتمه‌اش — در `matter_sections`، نه در فهرست باب‌ها.
  List<Map<String, dynamic>> _matters = const [];

  /// آمارِ سرصفحه — در [_loadContent] از خودِ داده شمرده می‌شود.
  ///
  /// این دو عدد پیش‌تر ثابت‌های `274` و `474` بودند و پس از انتشار نسخهٔ
  /// کاملِ چهارجلدی (۱٬۹۲۹ باب · ۳٬۸۲۳ حدیث) همچنان نسخهٔ یک‌جلدی را اعلام
  /// می‌کردند — خواننده فکر می‌کرد کتاب همان ۴۷۴ حدیث است.
  int _babCount = 0;
  int _hadithTotal = 0;

  /// بالاترین شمارهٔ چاپیِ کتاب (۳٬۹۲۱ در نسخهٔ چهارجلدی). شمارش احادیث از آن
  /// کمتر است چون نسخهٔ چاپی ۲۴۴ شماره را به کار نبرده و ۱۴۴ شماره را دو بار
  /// چاپ کرده — همان دلیلی که «۳٬۸۲۳ حدیث» جواب درست است و «۳٬۹۲۱» شمارهٔ
  /// آخر. بدون این خط، خواننده شمارش را با شمارهٔ آخر اشتباه می‌گیرد.
  int _printedMax = 0;

  // search state: title hits + full-text hits (row + its bab index)
  List<Map<String, dynamic>>? _textResults;
  Map<int, num>? _chapterIndexById;
  bool _searching = false;

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
          });
        }
        return;
      }
      // The hosted maalim.db was republished corrected (274 باب + the
      // full مقصد/کتاب/فصل chain); a copy that predates the revision
      // must be replaced, not opened forever.
      if (await _service.needsUpdate()) {
        if (mounted) {
          setState(() {
            _dbChecking = false;
            _dbMissing = true;
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
      AppLogger.warning('maalim_screen', 'error: $e');
      if (mounted) {
        setState(() {
          _dbChecking = false;
          _dbMissing = true;
          _dbError = '$e';
        });
      }
    }
  }

  /// Shown when the copy is on disk but could not be opened right away: the
  /// download itself succeeded, and re-entering the section opens it.
  static const _reenterNotice = 'کتاب دانلود شد، اما باز کردن آن ممکن نشد.\n'
      'لطفاً یکبار از این بخش خارج شوید و دوباره وارد شوید.';

  /// Shown when the copy on disk predates the republished database: the
  /// download button then fetches the corrected edition over the stale one.
  static const _outdatedNotice = 'نسخهٔ تصحیح‌شدهٔ کتاب منتشر شده است؛ '
      'برای دریافت، دوباره دانلود کنید.';

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
            'maalim_screen', 'open attempt ${attempt + 1} failed: $e');
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
      AppLogger.warning('maalim_screen', 'download failed: $e');
      if (mounted) {
        setState(() {
          _dbDownloading = false;
          _dbError = '$e';
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
        _dbNotice = opened ? null : _reenterNotice;
      });
    }
  }

  Future<void> _loadContent() async {
    final chapters = await _service.chapters();
    final hadithCounts = await _service.hadithCountsPerChapter();
    final matters = await _service.matterSections();
    final printedMax = await _service.maxHadithNumber();
    if (!mounted) return;
    setState(() {
      _chapters = chapters;
      _hadithCounts = hadithCounts;
      _matters = matters;
      _printedMax = printedMax;
      _babCount = chapters.where(_isBab).length;
      _hadithTotal = hadithCounts.values.fold(0, (a, b) => a + b);
      _chapterIndexById = {
        for (final c in chapters) (c['id'] as int): c['chapter_index'] as num,
      };
    });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _textResults = null;
        _textQuery = '';
        _searching = false;
      });
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _performSearch(v));
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searching = true);
    try {
      final rows = await _service.search(query);
      if (!mounted) return;
      setState(() {
        _textResults = rows;
        _textQuery = query.trim();
        _searching = false;
      });
    } catch (_) {
      AppLogger.warning('maalim_screen', 'operation failed');
      if (mounted) setState(() => _searching = false);
    }
  }

  bool _titleMatches(Map<String, dynamic> ch, String q) =>
      TextHighlight.normalize((ch['name_arabic'] ?? '') as String)
          .contains(TextHighlight.normalize(q));

  /// پرش مستقیم به یک حدیث با شمارهٔ چاپی (۱ تا ۳٬۹۲۱) — همان شماره‌ای که صفحهٔ
  /// کتاب زیر روایت چاپ کرده و نشان «حدیث X» هر کارت نشان می‌دهد. شماره‌ای که
  /// نسخهٔ چاپی ندارد پیام «در این نسخه نیست» می‌گیرد، نه نزدیک‌ترین حدیث.
  Future<void> _showJumpDialog() async {
    final max = await _service.maxHadithNumber();
    if (!mounted || max <= 0) return;
    final number = await showDialog<int>(
      context: context,
      builder: (context) => _MaalimJumpDialog(max: max),
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
    final (chIdx, hadithNumber) = loc;
    final chTitle = _chapters?.firstWhere(
            (c) => (c['chapter_index'] as num).toDouble() == chIdx.toDouble(),
            orElse: () => const {})['name_arabic'] as String? ??
        '';
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MaalimChapterScreen(
        chapterIndex: chIdx,
        chapterTitle: chTitle,
        initialHadithNumber: hadithNumber,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const accent = TopicHues.maalim;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SectionAppBar(
        title: 'معالم السنه النبویه',
        actions: [
          if (!_dbChecking && !_dbMissing)
            IconButton(
              icon: const Icon(Icons.numbers, size: 20),
              tooltip: 'پرش به شماره حدیث',
              onPressed: _showJumpDialog,
            ),
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
              child: Icon(Icons.book_outlined, size: 42, color: accent),
            ),
            const SizedBox(height: 20),
            Text('معالم السنه النبویه',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 20),
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'خلاصه‌ای از ۱۴ کتاب اصلی حدیث\n'
              'جمع وترتیب: شیخ صالح أحمد الشامي ·\n'
              'ترجمه وتعلیق: شاکر الذهبي\n'
              'دانلود یک‌باره حدود ۲ مگابایت',
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
                label: Text('دانلود محتوا',
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
    final chapters = _chapters ?? const [];
    final filtered = query.isEmpty || _textResults != null
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
              child: Icon(Icons.book_outlined, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('معالم السنه النبویه',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 15.5),
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    'جمع وترتیب: شیخ صالح أحمد الشامي · ترجمه وتعلیق: شاکر الذهبي',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 11.5),
                        color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _statChip('${_num(_babCount)} باب', accent),
                      const SizedBox(width: 8),
                      _statChip('${_num(_hadithTotal)} حدیث', accent),
                    ],
                  ),
                  if (_printedMax > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'شمارهٔ چاپی ۱ تا ${_num(_printedMax)}',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 10),
                          color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
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

    final showTextResults = _textResults != null && query.isNotEmpty;
    final chapters = _chapters ?? const <Map<String, dynamic>>[];
    final textRows =
        showTextResults ? _textResults! : const <Map<String, dynamic>>[];
    final tiles = filteredChapters ?? chapters;

    // The edition's chain is مقصد › کتاب › فصل › باب. The reader asked for the
    // same three steps صحیح الترغیب has — کتاب › باب › حدیث — so the default
    // page lists the 49 «کتاب»s of the work and each opens its own باب‌ها. A
    // query is a match set, not the book's traversal, so it keeps listing the
    // matching باب‌ها directly.
    final books = query.isEmpty ? partBooksOf(chapters) : const <PartBook>[];
    final rows = <Object>[
      if (query.isEmpty) ...books else ...tiles,
    ];

    final header = <Widget>[
      if (showTextResults)
        _sectionLabel('نتایج متن (${_num(_textResults!.length)})'),
    ];
    final intros = query.isEmpty
        ? _matters.where((m) => (m['kind'] ?? '') != 'khatimah').toList()
        : const <Map<String, dynamic>>[];
    final codas = query.isEmpty
        ? _matters.where((m) => (m['kind'] ?? '') == 'khatimah').toList()
        : const <Map<String, dynamic>>[];

    final mid = <Widget>[
      if (showTextResults) ...[
        if (_textResults!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('نتیجه‌ای یافت نشد.',
                  style: TextStyle(fontFamily: AppTheme.fontFamily)),
            ),
          ),
        const SizedBox(height: 12),
      ],
      if (intros.isNotEmpty)
        _matterTile(
          intro: true,
          sections: intros,
          label: 'مقدمه‌ها',
          accent: accent,
        ),
      _sectionLabel(query.isEmpty
          ? 'کتاب‌ها (${_num(books.length)})'
          : (filteredChapters?.isNotEmpty ?? false)
              ? 'باب‌های هم‌نام'
              : 'باب‌هایی با این عنوان یافت نشد'),
    ];

    final footer = <Widget>[
      if (codas.isNotEmpty)
        _matterTile(
          intro: false,
          sections: codas,
          label: 'خاتمه',
          accent: accent,
        ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(DsSpacing.page, 4, DsSpacing.page, 32),
      itemCount: header.length +
          textRows.length +
          mid.length +
          rows.length +
          footer.length,
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        final a = i - header.length;
        if (a < textRows.length) return _searchResultTile(textRows[a], accent);
        final b = a - textRows.length;
        if (b < mid.length) return mid[b];
        final c = b - mid.length;
        if (c >= rows.length) return footer[c - rows.length];
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

  /// One «کتاب» of the work: its مقصد above, its own title, and how many
  /// باب‌ها and narrations it holds. Tapping it opens the bab list.
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
            builder: (_) => MaalimBookScreen(
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
                      if (book.parent != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: Text(book.parent!,
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
                        ),
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

  /// A row that opens the book's مقدمهها or its خاتمه — the parts the edition
  /// prints outside the باب chain, as ریاض and الترغیب already list theirs.
  Widget _matterTile({
    required bool intro,
    required List<Map<String, dynamic>> sections,
    required String label,
    required Color accent,
  }) {
    final titles =
        sections.map((s) => (s['title'] ?? '') as String).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MaalimMatterScreen(
              sections: sections,
              service: widget.service,
              title: intro
                  ? 'مقدمه‌های معالم السنه النبویه'
                  : 'خاتمهٔ معالم السنه النبویه',
            ),
          )),
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
                  child: Icon(
                      intro
                          ? Icons.menu_book_outlined
                          : Icons.history_edu_outlined,
                      size: 20,
                      color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        titles,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: AppTheme.scaledFontSize(context, 10.5),
                            color:
                                Theme.of(context).textTheme.bodySmall?.color),
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
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MaalimChapterScreen(
                chapterIndex: idx,
                chapterTitle: (ch['name_arabic'] ?? '') as String,
              ),
            ));
          },
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
                  child: Text(_isBab(ch) ? _num(number) : 'ف',
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
                Text('${_num(count)} حدیث',
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
    final chRow = _chapters?.firstWhere((c) => c['id'] == row['chapter_id'],
        orElse: () => const <String, dynamic>{});
    final chTitle = chRow?['name_arabic'];
    final babWord = _isBab(chRow ?? const <String, dynamic>{}) ? 'باب' : 'فصل';
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
                    builder: (_) => MaalimChapterScreen(
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
                  Text('$babWord: ${chTitle as String}',
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

/// سطرِ [ch] باب است؟ سطرهای فصل (بدون شمارهٔ باب) `is_bab` صفر دارند؛
/// پایگاه‌دادهٔ کهنهٔ بدون این ستون همه را باب می‌شمارد (رفتار قبلی).
bool _isBab(Map<String, dynamic> ch) =>
    ((ch['is_bab'] as num?)?.toInt() ?? 1) != 0;

String _num(Object? n) => '$n';

/// «پرش به شماره حدیث» — یک فیلد عددی همراه با اسلایدر برای پیمایش سریع در
/// شماره‌های پیوستهٔ این نسخه (1 تا [max]). مقدار خارج از بازه پذیرفته نمی‌شود؛
/// شماره‌هایی که در این نسخه وجود ندارند، پس از تأیید با پیام خطا نشان داده
/// می‌شوند.
class _MaalimJumpDialog extends StatefulWidget {
  final int max;
  const _MaalimJumpDialog({required this.max});

  @override
  State<_MaalimJumpDialog> createState() => _MaalimJumpDialogState();
}

class _MaalimJumpDialogState extends State<_MaalimJumpDialog> {
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
    const accent = TopicHues.maalim;
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
