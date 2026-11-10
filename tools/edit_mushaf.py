# -*- coding: utf-8 -*-
import io

p = 'lib/features/quran/mushaf/quran_mushaf_view.dart'
s = io.open(p, encoding='utf-8').read()


def rep(old, new):
    global s
    assert old in s, 'NOT FOUND:\n' + old[:200]
    s = s.replace(old, new, 1)


# 1. Zoom interaction flag
rep("""  final TransformationController _zoomController = TransformationController();

  final Map<int, List<QuranVerse>> _versesByPage = {};""",
"""  final TransformationController _zoomController = TransformationController();

  /// True while the user is actively pinching/panning the current page. While
  /// true the PageView scrolling is disabled so a pinch is never misread as a
  /// page swipe (previously a zoom gesture could fling back to page 1).
  bool _zoomInteracting = false;

  final Map<int, List<QuranVerse>> _versesByPage = {};""")

# 2. Reciter type -> String identifier
rep("""  int _currentPage = 1;
  int? _reciterId;
  List<Mp3QuranReciter> _reciters = [];""",
"""  int _currentPage = 1;
  String? _reciterId;
  List<Mp3QuranReciter> _reciters = [];""")

# 3. Night mode removal (fields / getters)
rep("""  final bool _night = false;

  /// Selectable background colors behind the transparent mushaf pages.
  static const List<Color> dayBgColors = [
    Color(0xFFFBF3E7), // کرم
    Color(0xFFFFFFFF), // سفید
    Color(0xFFF4EDDC), // بژ
    Color(0xFFEEDFC0), // شنی
  ];
  static const List<Color> nightBgColors = [
    Color(0xFF221A12), // شکلاتی تیره
    Color(0xFF121212), // مشکی
    Color(0xFF1C1A17), // خاکستری تیره
  ];
  static const String bgDayPrefsKey = 'quran_bg_day';
  static const String bgNightPrefsKey = 'quran_bg_night';
  int _bgDayIndex = 0;
  int _bgNightIndex = 0;

  /// Background color behind the transparent page image for the active theme.
  Color get _bgColor {
    final list = _night ? nightBgColors : dayBgColors;
    final idx = (_night ? _bgNightIndex : _bgDayIndex).clamp(0, list.length - 1);
    return list[idx];
  }

  MushafPalette get _palette =>
      _night ? MushafPalette.night : MushafPalette.light;""",
"""  /// Selectable background colors behind the transparent mushaf pages.
  static const List<Color> dayBgColors = [
    Color(0xFFFBF3E7), // کرم
    Color(0xFFFFFFFF), // سفید
    Color(0xFFF4EDDC), // بژ
    Color(0xFFEEDFC0), // شنی
  ];
  static const String bgDayPrefsKey = 'quran_bg_day';
  int _bgDayIndex = 0;

  /// Background color behind the transparent page image.
  Color get _bgColor =>
      dayBgColors[_bgDayIndex.clamp(0, dayBgColors.length - 1)];

  MushafPalette get _palette => MushafPalette.light;""")

# 4. Reciter prefs -> v2 string key + drop night bg pref
rep("""      lastPage = (prefs.getInt('quran_last_page') ?? 1).clamp(1, 604);
      savedReciter = prefs.getInt('quran_reciter_id');
      _bgDayIndex = prefs.getInt(bgDayPrefsKey) ?? 0;
      _bgNightIndex = prefs.getInt(bgNightPrefsKey) ?? 0;
    } catch (_) {}""",
"""      lastPage = (prefs.getInt('quran_last_page') ?? 1).clamp(1, 604);
      savedReciter = prefs.getString('quran_reciter_id_v2');
      _bgDayIndex = prefs.getInt(bgDayPrefsKey) ?? 0;
    } catch (_) {}""")

rep("""    var lastPage = 1;
    int? savedReciter;""",
"""    var lastPage = 1;
    String? savedReciter;""")

rep("""      if (list.isNotEmpty) {
        final sel = (savedReciter != null &&
                list.any((r) => r.id == savedReciter))
            ? savedReciter
            : list.first.id;
        _reciterId = sel;
        _audio.setReciter(sel);
      }""",
"""      if (list.isNotEmpty) {
        final sel = (savedReciter != null &&
                list.any((r) => r.identifier == savedReciter))
            ? savedReciter
            : _preferredReciterId(list);
        _reciterId = sel;
        _audio.setReciter(sel);
      }""")

rep("""  String get _reciterName {
    if (_reciterId == null) return 'انتخاب قاری';
    for (final r in _reciters) {
      if (r.id == _reciterId) return r.name;
    }
    return 'انتخاب قاری';
  }""",
"""  /// Default reciter: Alafasy when available, else the first in the list.
  String _preferredReciterId(List<Mp3QuranReciter> list) {
    for (final r in list) {
      if (r.identifier == 'ar.alafasy') return r.identifier;
    }
    return list.first.identifier;
  }

  String get _reciterName {
    if (_reciterId == null) return 'انتخاب قاری';
    for (final r in _reciters) {
      if (r.identifier == _reciterId) return r.name;
    }
    return 'انتخاب قاری';
  }""")

# 5. Bg picker night removal
rep("""  Future<void> _showBgPicker() async {
    final colors = _night ? nightBgColors : dayBgColors;
    final current = _night ? _bgNightIndex : _bgDayIndex;""",
"""  Future<void> _showBgPicker() async {
    final colors = dayBgColors;
    final current = _bgDayIndex;""")

rep("""                        setState(() {
                          if (_night) {
                            _bgNightIndex = i;
                          } else {
                            _bgDayIndex = i;
                          }
                        });
                        try {
                          SharedPreferences.getInstance().then((p) => p.setInt(
                              _night ? bgNightPrefsKey : bgDayPrefsKey, i));
                        } catch (_) {}""",
"""                        setState(() {
                          _bgDayIndex = i;
                        });
                        try {
                          SharedPreferences.getInstance()
                              .then((p) => p.setInt(bgDayPrefsKey, i));
                        } catch (_) {}""")

# 6. Reciter sheet select -> String
rep("""        selectedId: _reciterId,
        onSelect: (id) async {
          setState(() => _reciterId = id);
          _audio.setReciter(id);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('quran_reciter_id', id);
          } catch (_) {}
          if (ctx.mounted) Navigator.pop(ctx);
        },""",
"""        selectedId: _reciterId,
        onSelect: (id) async {
          setState(() => _reciterId = id);
          _audio.setReciter(id);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('quran_reciter_id_v2', id);
          } catch (_) {}
          if (ctx.mounted) Navigator.pop(ctx);
        },""")

# 7. Pre-download sheet: pass reciters + reciter-change callback
rep("""      builder: (ctx) => _PreDownloadSheet(
        palette: _palette,
        audioService: QuranAudioDownloadService.instance,
        reciterId: _reciterId,
        reciterName: reciterName,
        currentSurah: currentSurah,
      ),""",
"""      builder: (ctx) => _PreDownloadSheet(
        palette: _palette,
        audioService: QuranAudioDownloadService.instance,
        reciters: _reciters,
        reciterId: _reciterId,
        reciterName: reciterName,
        currentSurah: currentSurah,
        onReciterChanged: _changeReciter,
      ),""")

# Add the _changeReciter helper right before _showPreDownloadSheet
rep("""  Future<void> _showPreDownloadSheet() async {""",
"""  /// Switches the active reciter (used by the reciter picker inside the
  /// offline-download sheet and the header picker).
  Future<void> _changeReciter(String id) async {
    setState(() => _reciterId = id);
    _audio.setReciter(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quran_reciter_id_v2', id);
    } catch (_) {}
  }

  Future<void> _showPreDownloadSheet() async {""")

# 8. PageView physics gating
rep("""                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: QuranApiConfig.mushafPageCount,
                  itemBuilder: (context, index) => _buildPage(index + 1),
                ),""",
"""                child: PageView.builder(
                  controller: _pageController,
                  // While pinching/panning the current page, the PageView must
                  // not steal the gesture as a swipe (which used to fling the
                  // reader back to page 1 when zooming).
                  physics: _zoomInteracting
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  itemCount: QuranApiConfig.mushafPageCount,
                  itemBuilder: (context, index) => _buildPage(index + 1),
                ),""")

# 9. InteractiveViewer interaction callbacks
rep("""          return InteractiveViewer(
            transformationController: _zoomController,
            maxScale: 4.0,
            minScale: 1.0,
            clipBehavior: Clip.none,
            // While zoomed in, horizontal drags pan instead of flipping pages.
            child: GestureDetector(""",
"""          return InteractiveViewer(
            transformationController: _zoomController,
            maxScale: 4.0,
            minScale: 1.0,
            clipBehavior: Clip.none,
            onInteractionStart: (_) {
              if (!_zoomInteracting) {
                setState(() => _zoomInteracting = true);
              }
            },
            onInteractionEnd: (_) {
              if (_zoomInteracting) {
                setState(() => _zoomInteracting = false);
              }
            },
            // While zoomed in, horizontal drags pan instead of flipping pages.
            child: GestureDetector(""")

# 10. Surah list screen: stop passing night (removed field)
rep("""                  builder: (_) => QuranSurahListScreen(
                    night: _night,
                    onSelect: (surahNumber) async {""",
"""                  builder: (_) => QuranSurahListScreen(
                    onSelect: (surahNumber) async {""")

# 11. Header: remove surah/juz/page column + tafsir/translation buttons
rep("""    return Container(
      color: _palette.chrome,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: _palette.onChrome, size: 20),
              const SizedBox(width: 8),
              SizedBox(
                width: 160,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$surahName — صفحهٔ '
                    '${NumberFormat.normalizeDigits('$_currentPage')} '
                    '(${_currentPage.isOdd ? 'راست' : 'چپ'})',
                    style: TextStyle(
                      fontFamily: 'Calibri',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _palette.onChrome,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    juz > 0
                        ? 'جزء ${NumberFormat.normalizeDigits('$juz')} • $reciterName'
                        : reciterName,
                    style: TextStyle(
                      fontFamily: 'Calibri',
                      fontSize: 10,
                      color: _palette.onChrome.withValues(alpha: 0.72),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (juz > 0) ...[
                    const SizedBox(height: 3),
                    _buildJuzProgress(juz),
                  ],
                ],
              ),
            ),
            IconButton(""",
"""    return Container(
      color: _palette.chrome,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: _palette.onChrome, size: 20),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  reciterName,
                  style: TextStyle(
                    fontFamily: 'Calibri',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _palette.onChrome.withValues(alpha: 0.92),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
            IconButton(""")

# 12. Remove the translate / tafsir buttons from the header
rep("""            // Explicit translation / tafsir actions so both are one tap away.
            IconButton(
              tooltip: 'ترجمهٔ این صفحه',
              icon: Icon(Icons.translate,
                  color: _palette.onChrome, size: 20),
              onPressed: _showTranslationSheet,
            ),
            IconButton(
              tooltip: 'تفسیر آیهٔ فعلی',
              icon: Icon(Icons.menu_book_rounded,
                  color: _palette.onChrome, size: 20),
              onPressed: _showCurrentTafsir,
            ),
            // Less-used actions live in the “بیشتر” menu so the header fits
            // narrow screens instead of overflowing.
            PopupMenuButton<String>(""",
"""            // Less-used actions live in the “بیشتر” menu so the header fits
            // narrow screens instead of overflowing. Tafsir/translation are
            // one tap away on each ayah (tap an ayah → action sheet).
            PopupMenuButton<String>(""")

# 13. Page overlays: rebuild the image Stack in _buildPage
rep("""          Widget image;
          if (cached != null) {
            image = Center(
              child: Image.file(
                File(cached),
                width: w,
                height: h,
                fit: BoxFit.fill,
                cacheWidth: cacheW,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    _buildPagePlaceholder(images, theme, page, configured),
              ),
            );
          } else {
            unawaited(images.ensurePage(theme, page));
            image = _buildPagePlaceholder(images, theme, page, configured);
          }""",
"""          Widget pageImage;
          if (cached != null) {
            pageImage = Image.file(
              File(cached),
              width: w,
              height: h,
              fit: BoxFit.fill,
              cacheWidth: cacheW,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  _buildPagePlaceholder(images, theme, page, configured),
            );
          } else {
            unawaited(images.ensurePage(theme, page));
            pageImage = _buildPagePlaceholder(images, theme, page, configured);
          }

          // Page overlays (surah ornament at surah starts, surah name top
          // right, juz top left, page number + left/right icon bottom left).
          // The surah ornament lives INSIDE the page-image box so it zooms
          // with the text; the corner chips stay screen-size so they remain
          // readable while zoomed.
          final banner = _surahStartBanner(page);
          final image = Stack(
            fit: StackFit.expand,
            children: [
              pageImage,
              if (banner != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: Center(child: banner)),
                ),
            ],
          );""")

rep("""              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (rects.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter:
                              _AyahHighlightPainter(rects, _palette.highlight),
                        ),
                      ),
                    ),
                  // Surah-start banner: a decorative box with the surah name at
                  // the top of the first page of each surah (like a real mushaf).
                  if (_surahStartBanner(page) != null)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(child: _surahStartBanner(page)),
                    ),
                ],
              ),
            ),
          );""",
"""              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (rects.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter:
                              _AyahHighlightPainter(rects, _palette.highlight),
                        ),
                      ),
                    ),
                  // Corner info overlays, anchored to the page-image edges so
                  // they sit like the printed page's own header/footer.
                  IgnorePointer(
                    child: _PageCornerInfo(
                      page: page,
                      palette: _palette,
                      area: area,
                      viewport: box,
                    ),
                  ),
                ],
              ),
            ),
          );""")

# 14. Replace _surahStartBanner with the ornate ornament + corner info widget
rep("""  /// Decorative surah-start banner for the first page of a surah, or null
  /// for pages that only continue a surah. Shows the surah's Arabic name
  /// inside a box (the ayah numbers are already on the page image itself).
  Widget? _surahStartBanner(int page) {
    try {
      final rows = getPageData(page);
      int? startSurah;
      for (final row in rows) {
        if ((row['start'] as int) == 1) {
          startSurah = row['surah'] as int;
          break;
        }
      }
      if (startSurah == null) return null;
      final name = getSurahNameArabic(startSurah);
      return Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: _palette.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _palette.accent.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            name,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Calibri',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _palette.surfaceText,
            ),
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }""",
"""  /// Decorative surah-start banner for the first page of a surah, or null
  /// for pages that only continue a surah. Rendered like the printed mushaf:
  /// an ornate frame with the surah's Arabic name inside (the ayah numbers are
  /// already on the page image itself).
  Widget? _surahStartBanner(int page) {
    try {
      final rows = getPageData(page);
      int? startSurah;
      for (final row in rows) {
        if ((row['start'] as int) == 1) {
          startSurah = row['surah'] as int;
          break;
        }
      }
      if (startSurah == null) return null;
      final name = getSurahNameArabic(startSurah);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ]),
          child: CustomPaint(
            painter: _SurahOrnamentPainter(
              accent: _palette.accent,
              text: _palette.surfaceText,
              surface: _palette.surface,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 11),
              child: Text(
                name,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Calibri',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _palette.surfaceText,
                ),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }""")

# 15. Remove _buildJuzProgress (no longer used in the header)
rep("""  /// Thin progress bar showing how far the reader is through the current
  /// juz (page range of that juz), so long recitations can gauge position.
  Widget _buildJuzProgress(int juz) {
    int from;
    int to;
    try {
      from = getJuzStartPage(juz);
      to = juz >= 30
          ? QuranApiConfig.mushafPageCount
          : getJuzStartPage(juz + 1) - 1;
    } catch (_) {
      return const SizedBox.shrink();
    }
    final total = to - from + 1;
    final progress = (_currentPage - from + 1) / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 3,
        backgroundColor: _palette.onChrome.withValues(alpha: 0.14),
        valueColor: AlwaysStoppedAnimation<Color>(_palette.accent),
      ),
    );
  }

""", "")

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('OK - all replacements applied')
