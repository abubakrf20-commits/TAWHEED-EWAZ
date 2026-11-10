// Builder half of [QuranMushafViewState] (M5 file split): `setState` is
// `@protected`, so the analyzer flags it outside the class body — the receiver
// here is still the State itself, so the calls are valid.
// ignore_for_file: invalid_use_of_protected_member

part of 'quran_mushaf_view.dart';

extension _QuranMushafViewBuild on QuranMushafViewState {
  // ── Page rendering ────────────────────────────────────────────────────────

  Widget _buildPage(int page) {
    int? hlS;
    int? hlA;
    int? hlWord;
    if (_audio.hasSession) {
      hlS = _audio.chapter;
      hlA = _audio.verse;
      hlWord = _audio.activeWord;
    } else if (_translationAudio.hasSession) {
      hlS = _translationAudio.chapter;
      hlA = _translationAudio.verse;
    } else if (_navHighlightSurah != null) {
      hlS = _navHighlightSurah;
      hlA = _navHighlightVerse;
    }

    // Tapping a word/verse-end highlights it before opening the action
    // sheet. The body lives on the state (`_selectHighlight`) so every tap
    // path shares one route.
    void selectHighlight(int s, int a, [int? pos]) => _selectHighlight(s, a);

    // The font mushaf uses the flat background directly, so the ink color
    // must adapt for contrast (a dark page needs light ink). Light on dark:
    // cream ink; dark on light: near-black ink.
    final bgColor = _bgColor;
    // Ink is chosen by contrast, not by a luminance cut-off: the palette now
    // runs all the way through the browns, where a hard threshold hands the
    // page the *less* legible ink (see mushafNeedsLightInk).
    final onDark = mushafNeedsLightInk(bgColor);
    final inkColor = onDark ? kMushafCreamInk : kMushafDarkInk;
    // Recited-ayah color: the reader's pick, lifted toward the page's own ink
    // only as far as legibility needs. The old rule swapped any dark pick for a
    // fixed light gold on a dark page — throwing the reader's choice away.
    final hlColor = mushafRecitationInkOn(bgColor, _recitationColor);
    // Corner chips (surah / juz / page) follow the ayah-number color so
    // they stay readable on dark backgrounds (palette.surfaceText can be
    // dark-on-dark there).
    final verseMarkerColor =
        onDark ? const Color(0xFFC9965C) : const Color(0xFF7A4A21);

    return Container(
      color: bgColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Reserve a slim top/bottom band so the page chrome (the
          // bottom-left page-side glyph) never sits on top of the Quranic
          // glyphs — the font mushaf is full-bleed, so the text must be inset
          // away from the chrome.
          // The chrome bands (header / mini player) are added on top: they are
          // overlays, so charging them to the *viewport* would resize the
          // PageView. Reserving them here instead keeps the scroll extent
          // invariant while the glyphs stay clear of the chrome.
          const band = 28.0;
          final topInset = band + _pageTopInset;
          final bottomInset = band + _pageBottomInset;
          return Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
                child: Qcf4PageViewer(
                  page: page,
                  highlight: Qcf4Highlight(
                    surah: hlS,
                    ayah: hlA,
                    activeWord: hlWord,
                  ),
                  highlightColor: hlColor,
                  // The tint behind the recited ayah, guaranteed readable on
                  // this paper (the wash sits under glyphs of its own colour).
                  recitationWash: mushafLiveAyahWashOn(bgColor, hlColor),
                  verseTints: _verseBands,
                  textColor: inkColor,
                  fontWeight: FontWeight.w500,
                  fontSize: _landscape
                      ? QuranMushafViewState._landscapeFontSize
                      : QuranMushafViewState._portraitFontSize,
                  lineHeight: 1.5,
                  fitWidth: _landscape,
                  verseMarkerColor: verseMarkerColor,
                  surahHeaderColor: onDark
                      ? const Color(0xFFD4A651)
                      : const Color(0xFF7B5B3A),
                  onFallback: () {
                    // The font/data for this page failed — show the inline
                    // error card (fired from the viewer's async load, so
                    // setState here is post-frame safe).
                    if (mounted) setState(() => _pageFailed.add(page));
                  },
                  retryTick: _pageRetryTick[page] ?? 0,
                  // A word tap highlights its ayah and opens the verse
                  // actions. The per-word meaning sheet was removed at the
                  // reader's request, so the tap never waits on the network.
                  onWordTap: (s, a, pos) => _selectHighlight(s, a),
                  // Long-press opens the same verse actions — the bookmarks
                  // empty state has instructed «روی آیه نگه دارید» all along.
                  onWordLongPress: selectHighlight,
                  onVerseEndTap: selectHighlight,
                  onDoubleTap: _toggleChrome,
                ),
              ),
              // Spec: no control floats over the page any more. Every page
              // carries its own identity — surah (top-right), juz (top-left)
              // and the page number (bottom-left) — on a continuation page
              // just as on the page a surah opens, and in both chrome states
              // (reader request). The text block geometry is unchanged; this
              // only paints in the reserved bands, so the labels clear the
              // header and mini-player overlays by the insets above.
              _PageChrome(
                page: page,
                textColor: verseMarkerColor,
                surahName: _surahNameFor(page),
                juz: _juzFor(page),
                // The paper's shade, not a grey stripe: the binding shadow
                // belongs to the sheet it falls on.
                gutterTint: Color.alphaBlend(
                  Colors.black.withValues(alpha: onDark ? 0.35 : 0.55),
                  bgColor,
                ),
                byParity: _pageChromeByParity,
                headerBand: _pageTopInset,
                playerBand: _pageBottomInset,
              ),
              if (_pageFailed.contains(page))
                _PageLoadErrorCard(
                  ink: inkColor,
                  paper: bgColor,
                  onRetry: () {
                    // Optimistic clear: a re-failure re-adds the page via
                    // onFallback; success renders the page (card gone).
                    setState(() {
                      _pageFailed.remove(page);
                      _pageRetryTick[page] = (_pageRetryTick[page] ?? 0) + 1;
                    });
                  },
                  onDownload: () async {
                    await _showPreDownloadSheet();
                    if (!mounted) return;
                    await Qcf4DownloadManager.instance.refreshFullyDownloaded();
                    if (!mounted) return;
                    if (Qcf4DownloadManager
                        .instance.state.value.fullyDownloaded) {
                      setState(() {
                        for (final p in _pageFailed) {
                          _pageRetryTick[p] = (_pageRetryTick[p] ?? 0) + 1;
                        }
                        _pageFailed.clear();
                      });
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  String _friendlyMessage(Object e) {
    if (e is QuranApiException) {
      switch (e.type) {
        case QuranApiErrorType.offline:
          return 'این صفحه هنوز دانلود نشده است؛ اتصال اینترنت را بررسی کنید و دوباره تلاش کنید.';
        case QuranApiErrorType.configMissing:
          return 'تنظیمات API قرآن کامل نیست؛ کلیدها را در assets/env/quran_api.env قرار دهید.';
        case QuranApiErrorType.notFound:
          return 'داده‌ی این صفحه پیدا نشد.';
        case QuranApiErrorType.server:
          return 'خطای سرور؛ کمی بعد دوباره تلاش کنید.';
        default:
          return e.message;
      }
    }
    return 'خطا در بارگذاری صفحه';
  }
}
