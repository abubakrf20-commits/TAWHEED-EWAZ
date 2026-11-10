part of 'quran_mushaf_view.dart';

class _TranslationSheet extends StatefulWidget {
  const _TranslationSheet({
    required this.initialPage,
    required this.initialVerses,
    required this.palette,
    required this.loadPage,
    required this.onPageChanged,
  });

  final int initialPage;
  final List<QuranVerse> initialVerses;
  final MushafPalette palette;

  /// Loads one page's verses: the reader owns the page cache and the fetch, so
  /// a turn here costs the same one round trip the reader itself would pay.
  final Future<List<QuranVerse>> Function(int page) loadPage;

  /// Fired after a page actually landed, so the mushaf underneath turns with
  /// the sheet instead of drifting away from it.
  final ValueChanged<int> onPageChanged;

  @override
  State<_TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<_TranslationSheet> {
  final ScrollController _scroll = ScrollController();
  late int _page;
  late List<QuranVerse> _verses;
  Map<String, String> _texts = {};
  List<QuranContentFile> _translations = const [];
  String _selectedId = QuranTranslationService.defaultId;
  String _selectedName = '';
  bool _loading = true;
  bool _notReady = false;
  bool _downloading = false;
  bool _pickerOpen = false;
  bool _paging = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _verses = widget.initialVerses;
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notReady = false;
    });
    final entry = await QuranTranslationService.selectedEntry();
    final list = QuranTranslationService.available();
    if (!mounted) return;
    setState(() {
      _selectedId = entry.id;
      _selectedName = entry.name;
      _translations = list;
    });
    if (!await QuranTranslationService.isReady()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notReady = true;
      });
      return;
    }
    final map = await _fetchTexts(_verses);
    if (!mounted) return;
    setState(() {
      _texts = map;
      _loading = false;
    });
  }

  /// Reads the rows for [verses] as ONE map keyed `chapter:verse`, so a turn
  /// can merge a page's worth of fresh rows into the cache without dropping the
  /// pages already read.
  Future<Map<String, String>> _fetchTexts(List<QuranVerse> verses) async {
    final groups = <int, List<QuranVerse>>{};
    for (final v in verses) {
      groups.putIfAbsent(v.chapterId, () => []).add(v);
    }
    final map = <String, String>{};
    for (final group in groups.entries) {
      final vs = group.value;
      final start = vs.map((v) => v.verseNumber).reduce(math.min);
      final end = vs.map((v) => v.verseNumber).reduce(math.max);
      final texts = await QuranTranslationService.getTranslationsForPage(
          group.key, start, end);
      for (final e in texts.entries) {
        map['${group.key}:${e.key}'] = e.value;
      }
    }
    return map;
  }

  /// Turns one page. The sheet only commits the new page once its verses AND
  /// its translations are in hand, so no half-page is ever shown and the folio
  /// never names a page the paper has not reached.
  Future<void> _changePage(int delta) async {
    if (_paging) return;
    final target = _page + delta;
    if (target < 1 || target > QuranApiConfig.mushafPageCount) return;
    setState(() => _paging = true);
    List<QuranVerse> verses;
    try {
      verses = await widget.loadPage(target);
    } catch (e) {
      AppLogger.warning(
          'quran_mushaf_view', 'translation sheet page $target failed: $e');
      verses = const [];
    }
    if (!mounted) return;
    if (verses.isEmpty) {
      setState(() => _paging = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('این صفحه بارگذاری نشد؛ دوباره تلاش کنید.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    final fresh = await _fetchTexts(verses);
    if (!mounted) return;
    setState(() {
      _page = target;
      _verses = verses;
      _texts = {..._texts, ...fresh};
      _paging = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    widget.onPageChanged(target);
  }

  Future<void> _pick(QuranContentFile file) async {
    if (file.id == _selectedId) {
      setState(() => _pickerOpen = false);
      return;
    }
    setState(() => _pickerOpen = false);
    await QuranTranslationService.setSelectedId(file.id);
    await _load();
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    final path = await QuranTranslationService.ensureDownloaded();
    if (!mounted) return;
    setState(() => _downloading = false);
    if (path != null) {
      await _load();
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content:
              Text('دانلود ترجمه ناموفق بود؛ اتصال اینترنت را بررسی کنید.'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  String _arabicOf(QuranVerse v) {
    // Only real unicode text: [VerseWord.glyphV2] is a QCF4 glyph code, not a
    // character, and would render as isolated forms in the app face.
    final fromWords = v.words
        .map((w) => w.unicodeText)
        .where((text) => text.isNotEmpty)
        .join(' ');
    return fromWords.isNotEmpty
        ? fromWords
        : bundledArabicVerse(v.chapterId, v.verseNumber);
  }

  /// The header's second line names the READING, not the folio: the page number
  /// is printed in the pager below, and a second «صفحهٔ N» up here would read as
  /// two competing page marks on one sheet.
  String _pageSubtitle() {
    if (_verses.isEmpty) return 'صفحهٔ ${NumberFormat.en(_page)}';
    final chapters = <int>[];
    for (final v in _verses) {
      if (chapters.isEmpty || chapters.last != v.chapterId) {
        chapters.add(v.chapterId);
      }
    }
    if (chapters.length > 1) {
      return chapters.map(getSurahNameArabic).join(' · ');
    }
    final numbers = _verses.map((v) => v.verseNumber);
    final first = numbers.reduce(math.min);
    final last = numbers.reduce(math.max);
    final name = getSurahNameArabic(chapters.first);
    return first == last
        ? '$name · آیهٔ ${NumberFormat.en(first)}'
        : '$name · آیهٔ ${NumberFormat.en(first)} تا ${NumberFormat.en(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    QuranContentFile? selectedFile;
    for (final f in _translations) {
      if (f.id == _selectedId) {
        selectedFile = f;
        break;
      }
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height *
              kMushafContentSheetHeightFraction,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MushafContentSheetHeader(
              palette: palette,
              title: _selectedName.isEmpty ? 'ترجمهٔ قرآن' : _selectedName,
              subtitle: _pageSubtitle(),
              bottom: _translations.length <= 1
                  ? null
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                      child: QuranKitRow(
                        palette: palette,
                        icon: Icons.translate,
                        title: _selectedName.isEmpty ? 'ترجمه' : _selectedName,
                        badge:
                            selectedFile == null || selectedFile.langLabel.isEmpty
                                ? null
                                : QuranLangChip(
                                    lang: selectedFile.lang ?? '',
                                    label: selectedFile.langLabel,
                                  ),
                        subtitle: _pickerOpen
                            ? 'یک ترجمه را انتخاب کنید'
                            : 'برای تغییر ترجمه لمس کنید',
                        selected: _pickerOpen,
                        trailing: Icon(
                          _pickerOpen ? Icons.expand_less : Icons.expand_more,
                          color: palette.surfaceMuted,
                        ),
                        onTap: () =>
                            setState(() => _pickerOpen = !_pickerOpen),
                      ),
                    ),
            ),
            if (_pickerOpen)
              Expanded(
                child: MushafSheetScrollable(
                  builder: (context, physics) => ListView(
                    physics: physics,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      for (final f in _translations)
                        QuranKitRow(
                          palette: palette,
                          icon: Icons.translate,
                          title: f.name,
                          badge: f.langLabel.isEmpty
                              ? null
                              : QuranLangChip(
                                  lang: f.lang ?? '',
                                  label: f.langLabel,
                                ),
                          subtitle: f.id == _selectedId
                              ? 'ترجمهٔ فعال'
                              : 'برای انتخاب لمس کنید',
                          selected: f.id == _selectedId,
                          onTap: () => _pick(f),
                        ),
                    ],
                  ),
                ),
              )
            else if (_loading)
              const SizedBox(
                height: 240,
                width: double.infinity,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_notReady)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.translate, size: 40, color: palette.accent),
                    const SizedBox(height: 12),
                    Text(
                      '${_selectedName.isEmpty ? 'ترجمه' : _selectedName} '
                      'هنوز دانلود نشده است.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: palette.surfaceText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'برای دانلود یک بار و استفادهٔ آفلاین، دکمهٔ زیر را بزنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: palette.surfaceText.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _downloading ? null : _download,
                      icon: _downloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 18),
                      label: const Text('دانلود ترجمه'),
                    ),
                  ],
                ),
              )
            else ...[
              Expanded(
                // [SelectionArea] wraps the scrollable rather than the rows, so
                // a drag can run from one ayah into the next — copy is the
                // reader's, and not a single run's style changes for it.
                child: SelectionArea(
                  child: MushafSheetScrollable(
                    builder: (context, physics) => ListView.builder(
                      controller: _scroll,
                      physics: physics,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      itemCount: _verses.length,
                      itemBuilder: (context, index) {
                        final verse = _verses[index];
                        final isChapterStart = index == 0 ||
                            _verses[index - 1].chapterId != verse.chapterId;
                        final isLast = index == _verses.length - 1;
                        final text =
                            _texts['${verse.chapterId}:${verse.verseNumber}'];
                        // Whitespace — never a card — is what sets one ayah
                        // apart from the next. The verse number sits on the far
                        // left, out of the reading column and under a short
                        // rule of its own, so the two texts keep one flush right
                        // edge from the first line to the last while the margin
                        // reads as a rule broken once per ayah.
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isChapterStart)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: index == 0 ? 4 : 26,
                                  bottom: 20,
                                ),
                                child: _SheetSurahHeading(
                                  title: getSurahNameArabic(verse.chapterId),
                                  palette: palette,
                                ),
                              ),
                            Padding(
                              padding:
                                  EdgeInsets.only(bottom: isLast ? 20 : 30),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          _arabicOf(verse),
                                          textDirection: TextDirection.rtl,
                                          textAlign: TextAlign.right,
                                          style: mushafAyahTextStyle(
                                            context,
                                            palette,
                                            baseSize: 18,
                                            height: 2.05,
                                          ),
                                        ),
                                        if (text != null) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            text,
                                            textDirection: TextDirection.rtl,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: AppTheme.scaledFontSize(
                                                  context, 14),
                                              height: 1.95,
                                              color: palette.surfaceText,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Tabular figures keep the marker column from
                                  // stepping in and out as the numbers change
                                  // width down the page.
                                  SizedBox(
                                    width: 20,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 2,
                                          height: 16,
                                          color: palette.accent
                                              .withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          NumberFormat.en(verse.verseNumber),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: AppTheme.scaledFontSize(
                                                context, 10),
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures()
                                            ],
                                            color: palette.surfaceMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              MushafSheetPager(
                palette: palette,
                page: _page,
                onPrevious: _page > 1 ? () => _changePage(-1) : null,
                onNext: _page < QuranApiConfig.mushafPageCount
                    ? () => _changePage(1)
                    : null,
                busy: _paging,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A surah break in the translation sheet: the name set as a display line,
/// opened by the page's one ornament.
///
/// A printed page announces a new surah by holding the name on its own line
/// between air and a single mark, not by ruling it in on both sides — the
/// verses below already carry the margin's rule, so a second pair here would
/// read as a second column rather than as a break.
class _SheetSurahHeading extends StatelessWidget {
  const _SheetSurahHeading({required this.title, required this.palette});

  final String title;
  final MushafPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MushafRuleOrnament(palette: palette),
        const SizedBox(height: 12),
        Text(
          title,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: AppTheme.scaledFontSize(context, 17),
            height: 1.4,
            fontWeight: FontWeight.w800,
            color: palette.accent,
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet listing every verse of the current surah. While talaawah /
/// translation audio is playing it highlights the recited ayah and auto-scrolls
/// the list to keep it in view (reading-progress follower).
class _VerseFollowSheet extends StatefulWidget {
  const _VerseFollowSheet({
    required this.surah,
    required this.verseCount,
    required this.palette,
    required this.audio,
    required this.translationAudio,
  });

  final int surah;
  final int verseCount;
  final MushafPalette palette;
  final QuranAudioController audio;
  final QuranTranslationAudioController translationAudio;

  @override
  State<_VerseFollowSheet> createState() => _VerseFollowSheetState();
}

class _VerseFollowSheetState extends State<_VerseFollowSheet> {
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _rowKeys = [];
  final List<String> _arabic = [];
  Map<int, String> _translation = const {};
  bool _loading = true;
  int _activeVerse = 0;

  int get _surah => widget.surah;
  int get _count => widget.verseCount;

  @override
  void initState() {
    super.initState();
    _activeVerse = _currentActive();
    widget.audio.addListener(_onAudio);
    widget.translationAudio.addListener(_onAudio);
    _rowKeys.addAll(List<GlobalKey>.generate(_count, (_) => GlobalKey()));
    _load();
  }

  @override
  void dispose() {
    widget.audio.removeListener(_onAudio);
    widget.translationAudio.removeListener(_onAudio);
    _scroll.dispose();
    super.dispose();
  }

  int _currentActive() {
    if (widget.audio.hasSession) return widget.audio.verse;
    if (widget.translationAudio.hasSession) {
      return widget.translationAudio.verse;
    }
    return 0;
  }

  void _onAudio() {
    if (!mounted) return;
    final v = _currentActive();
    if (v == _activeVerse) return;
    setState(() => _activeVerse = v);
    _scrollTo(v);
  }

  void _scrollTo(int verse) {
    if (verse < 1 || verse > _count) return;
    final key = _rowKeys[verse - 1];
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
  }

  Future<void> _load() async {
    // Arabic text of each verse, reconstructed from the QCF4 page JSON of the
    // surah's pages (offline-friendly since the font mushaf caches them).
    final arabic = List<String>.filled(_count, '');
    try {
      final startPage = getPageNumber(_surah, 1);
      final endPage = getPageNumber(_surah, _count);
      final store = Qcf4DataStore.instance;
      for (var page = startPage; page <= endPage; page++) {
        final res = await store.loadPage(page, allowNetwork: false);
        if (res is! Qcf4PageLoaded) continue;
        for (final line in res.page.lines) {
          for (final w in line.words) {
            if (w.type != 'word' || w.verseKey == null) continue;
            final parts = w.verseKey!.split(':');
            if (parts.length != 2) continue;
            final s = int.tryParse(parts[0]);
            final v = int.tryParse(parts[1]);
            if (s == null || v == null || s != _surah) continue;
            final piece = (w.text ?? '').trim();
            if (piece.isEmpty || v < 1 || v > _count) continue;
            arabic[v - 1] += '$piece ';
          }
        }
      }
    } catch (_) {
      AppLogger.warning('quran_mushaf_view', 'operation failed');
    }
    if (!mounted) return;
    final translation =
        await QuranTranslationService.getTranslationsForPage(_surah, 1, _count);
    if (!mounted) return;
    setState(() {
      _arabic
        ..clear()
        ..addAll(arabic);
      _translation = translation;
      _loading = false;
    });
    // Initial auto-scroll to the active ayah once the list is laid out.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollTo(_activeVerse));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'لیست آیات — ${getSurahNameArabic(_surah)} '
                '(پیروی از تلاوت)',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.surfaceText,
                ),
              ),
            ),
            Divider(height: 1, color: palette.accent),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (_count == 0)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'آیه‌ای برای این سوره یافت نشد.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    color: palette.surfaceMuted,
                  ),
                ),
              )
            else
              Expanded(
                child: MushafSheetScrollable(
                  builder: (context, physics) => ListView.builder(
                    controller: _scroll,
                    physics: physics,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _count,
                    itemBuilder: (context, index) {
                      final verse = index + 1;
                      final isActive = verse == _activeVerse;
                      return KeyedSubtree(
                        key: _rowKeys[index],
                        child: _buildRow(palette, verse, isActive),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(MushafPalette palette, int verse, bool isActive) {
    final arabic = _arabic.length >= verse ? _arabic[verse - 1] : '';
    final translation = _translation[verse];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? palette.accent.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: palette.accent.withValues(alpha: 0.6))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? palette.accent
                      : palette.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  NumberFormat.toLatin('$verse'),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : palette.accent,
                  ),
                ),
              ),
              if (isActive &&
                  (widget.audio.hasSession ||
                      widget.translationAudio.hasSession)) ...[
                const SizedBox(width: 8),
                Icon(Icons.volume_up,
                    size: 15, color: palette.accent.withValues(alpha: 0.9)),
              ],
            ],
          ),
          if (arabic.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              arabic,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 17,
                height: 1.7,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? palette.accent : palette.surfaceText,
              ),
            ),
          ],
          if (translation != null && translation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              translation,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                height: 1.5,
                color: palette.surfaceMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
