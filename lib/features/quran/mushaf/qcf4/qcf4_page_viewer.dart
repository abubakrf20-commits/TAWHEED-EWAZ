import 'package:flutter/material.dart';

import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_data_store.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_font_loader.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_models.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_page_chrome.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_surah_header.dart';

/// Data structure describing which verse/word the audio (or nav highlight) is
/// currently on, so the viewer can color it.
@immutable
class Qcf4Highlight {
  final int? surah;
  final int? ayah;

  /// 0-based word index within the *currently playing verse's* words (from
  /// `QuranAudioController.activeWord`). Unsolicited when null → highlight the
  /// whole ayah (and all its lines) instead of a single word.
  final int? activeWord;

  const Qcf4Highlight({this.surah, this.ayah, this.activeWord});
}

/// Renders one QCF4 Mushaf page as live fonts: an RTL column of lines, each
/// word a glyph in its QCF4 font family. Loads page JSON + fonts on demand
/// (disk first, then CDN) and reports the `page`/font status back to the
/// caller so it can show a loading / offline fallback.
///
/// Word-level behavior:
///  * `highlight` colors the active word (or whole active ayah) in gold via
///    the [highlightColor].
///  * tapping a `word` calls `onWordTap(surah, ayah, position)`; tapping a
///    verse-end/quarter calls `onVerseEndTap(surah, ayah)`.
class Qcf4PageViewer extends StatefulWidget {
  const Qcf4PageViewer({
    super.key,
    required this.page,
    required this.highlight,
    this.highlightColor,
    this.recitationWash,
    this.verseTints = const {},
    this.fontSize,
    this.lineHeight,
    this.textColor,
    this.fontWeight,
    this.verseMarkerColor,
    this.surahHeaderColor,
    this.onWordTap,
    this.onWordLongPress,
    this.onVerseEndTap,
    this.onDoubleTap,
    this.onFallback,
    this.retryTick = 0,
    this.fitWidth = false,
  });

  final int page;
  final Qcf4Highlight highlight;
  final Color? highlightColor;

  /// The wash painted behind the ayah being recited — the tint the palette
  /// resolved for *this* page (`mushafLiveAyahWashOn`), matching the ink in
  /// [highlightColor].
  ///
  /// The viewer cannot derive it: it does not know which paper it is sitting
  /// on, and a tint invented here would be a tint the palette never checked
  /// against that paper's legibility floor. Null therefore paints nothing — a
  /// missing wash only loses the "here" hint, while an unchecked wash can hide
  /// the words the reader is reciting. Like [verseTints], the colour is drawn
  /// exactly as given.
  final Color? recitationWash;

  /// Persistent user highlights: verseKey ('surah:ayah') → the opaque band
  /// colour to paint under that verse's words, already tuned for the current
  /// paper by `mushafAyahBandOn`. The band is drawn as given — the caller owns
  /// the legibility contract, and re-alpha-ing it here would put it back over
  /// the paper and undo that tuning.
  final Map<String, Color> verseTints;
  final double? fontSize;
  final double? lineHeight;
  final Color? textColor;
  final FontWeight? fontWeight;
  final Color? verseMarkerColor;
  final Color? surahHeaderColor;
  final void Function(int surah, int ayah, int? position)? onWordTap;
  final void Function(int surah, int ayah, int? position)? onWordLongPress;
  final void Function(int surah, int ayah)? onVerseEndTap;
  /// A tap on the page that is not part of a double tap does nothing: the
  /// reader's chrome is woken by the *double* tap alone, so a finger on the
  /// paper while reading can never turn the header back on.
  final VoidCallback? onDoubleTap;

  /// Invoked when the live-font page cannot be rendered (page JSON or fonts
  /// unavailable), so the caller can fall back to the pre-rendered image.
  final VoidCallback? onFallback;

  /// Bump to force a reload (e.g. after a full-mushaf download completes).
  final int retryTick;

  /// Landscape reading mode: instead of shrinking the whole page to fit the
  /// (short) viewport height, bind the fit on width and scroll the vertical
  /// overflow. Glyphs render much larger — for readers with weak eyesight.
  final bool fitWidth;

  @override
  State<Qcf4PageViewer> createState() => _Qcf4PageViewerState();
}

class _Qcf4PageViewerState extends State<Qcf4PageViewer> {
  Qcf4Page? _page;
  bool _loading = true;
  bool _fallbackRequested = false;

  /// Previously rendered tree, kept while a new page loads so a cold flip
  /// never collapses to a bare spinner: the old page stays on screen
  /// underneath and the new one crossfades in when ready. Cleared once the
  /// new tree is live.
  Widget? _staleTree;

  /// Last rendered layout subtree + the key of every input that produced it.
  /// During audio playback the parent rebuilds the PageView on every word
  /// tick; when a page's highlight is unchanged (or does not touch this page
  /// at all) it reuses this tree, so a tick only relayouts the recited page.
  Widget? _cachedTree;
  String? _cachedTreeKey;

  /// Natural-size metrics per page, so short pages can be vertically
  /// justified to fill the screen exactly (printed-Mushaf look) instead of
  /// floating in letterbox margins. Keyed by page+font+scale. A process-wide
  /// shared LRU: with keep-alive disabled the viewer for a revisited page is
  /// re-created, so caching here lets it reuse measured metrics instead of
  /// re-running a TextPainter for every word.
  static final Map<String, _Qcf4PageMetrics> _metricsCache = {};

  /// Target design width (in body-size units) every font group's widest line
  /// should render at — the shared normalization baseline of the
  /// font-uniformity probe (see [build]). 16.3 ≈ the measured span of a full
  /// verse line at the dataset's intended size, which the fixed surah-banner
  /// width already uses.
  static const double _kRefLineUnits = 16.3;

  /// Per font-group glyph scale from the design-uniformity probe, keyed by
  /// `'group@fontSize'`. The QCF4 files were digitized from different scans,
  /// so a fixed body size renders some page groups visibly larger than
  /// others — the reported "some pages longer / some shorter". Once a group
  /// is probed, every page of that group renders at the same effective glyph
  /// size, so page ink and line rhythm stay consistent across the mushaf.
  static final Map<String, double> _fontGroupScale = {};

  // ── Page-chrome constants (shared by widgets and metrics) ──────────────
  // Banner geometry mirrors the quran-common band's own compartments (see
  // Qcf4Config fractions, measured from the font outlines): the calligraphic
  // name fills the middle cartouche, the number / revelation medallions fill
  // the two ring compartments.
  static const double _bannerNameWFill = 0.90; // of the name cartouche width
  // Fraction of the name-cartouche height the calligraphic ink may fill —
  // the per-surah ink table sizes each name exactly, this is just slack.
  static const double _bannerNameInkFill = 0.88;
  static const double _bannerMarginV = 3; // vertical breathing room
  static const double _bodyLineVPadding = 4; // Padding(vertical: 2) × 2
  static const double _specialLineVPadding = 8; // Padding(vertical: 4) × 2

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant Qcf4PageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page ||
        oldWidget.retryTick != widget.retryTick) {
      _fallbackRequested = false;
      // Preserve the current render so the incoming cold load crossfades
      // over it instead of flashing a full-page spinner.
      if (_cachedTree != null && _staleTree == null) {
        _staleTree = _cachedTree;
      }
      _load();
    }
  }

  /// Fonts a page needs to render: its body font, the QBSML header font, and
  /// any per-word families the page's glyphs use.
  Set<String> _neededFonts(Qcf4Page page) {
    final needed = <String>{page.font, Qcf4Config.qbsmlFontFamily};
    for (final line in page.lines) {
      for (final w in line.words) {
        if (w.font.isNotEmpty) needed.add(w.font);
      }
    }
    return needed;
  }

  Future<void> _load() async {
    // Fast path: the page JSON is already decoded in RAM and every font it
    // needs is registered, so render together without ever flashing the busy
    // spinner. This is the common case while flipping within the warm window.
    final mem = Qcf4DataStore.instance.peek(widget.page);
    if (mem != null &&
        _neededFonts(mem).every(Qcf4FontLoader.instance.isLoaded)) {
      if (!mounted) return;
      setState(() {
        _page = mem;
        _loading = false;
      });
      return;
    }

    if (!_loading) {
      setState(() {
        _loading = true;
      });
    }
    final res = await Qcf4DataStore.instance.loadPage(widget.page);
    if (!mounted) return;
    if (res is! Qcf4PageLoaded) {
      // The page isn't on disk/network — let the caller render its own
      // offline placeholder instead of a dead error screen.
      if (_fallbackRequested) return;
      _fallbackRequested = true;
      setState(() {});
      widget.onFallback?.call();
      return;
    }
    final page = res.page;
    setState(() => _page = page);

    var allOk = true;
    for (final family in _neededFonts(page)) {
      final ok = await Qcf4FontLoader.instance.ensure(family);
      if (!ok) {
        allOk = false;
        break;
      }
    }
    if (!mounted) return;
    if (!allOk) {
      // A required font failed to download/decode — fall back to the image.
      if (_fallbackRequested) return;
      _fallbackRequested = true;
      setState(() {});
      widget.onFallback?.call();
      return;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_fallbackRequested) return const SizedBox.shrink();
    if (_loading) {
      // Cold load with a previous page still rendered: keep it visible with
      // a small spinner in the corner, so the flip never goes blank.
      final stale = _staleTree;
      if (stale != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            stale,
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return _busy(context);
    }
    final page = _page!;

    final fontSize = widget.fontSize ?? 30.0;
    final lineHeight = widget.lineHeight ?? 1.5;
    final fontWeight = widget.fontWeight ?? FontWeight.normal;
    final baseColor =
        widget.textColor ?? Theme.of(context).colorScheme.onSurface;
    final hlColor =
        widget.highlightColor ?? Theme.of(context).colorScheme.primary;

    final highlightMap = _buildHighlightMap(page);
    final headerColor = widget.surahHeaderColor ?? const Color(0xFF7B5B3A);
    final scaler = MediaQuery.textScalerOf(context);

    // Design-uniformity probe: once per font group, measure a handful of the
    // page's own words and size the group so its widest line matches a
    // shared design width (see [_fontGroupScale]). Pages within a group keep
    // one factor, so per-page layout never changes under the reader.
    final groupKey = widget.page.toString().padLeft(3, '0');
    final probeCacheKey = '$groupKey@$fontSize';
    var groupScale = _fontGroupScale[probeCacheKey];
    if (groupScale == null) {
      final probe = <Qcf4Word>[];
      for (final line in page.lines) {
        for (final w in line.words) {
          if (w.type == 'word' && w.font == page.font) probe.add(w);
        }
        if (probe.length >= 12) break;
      }
      if (probe.length >= 6) {
        var sum = 0.0;
        for (final wd in probe) {
          sum += _wordWidth(wd, fontSize, fontWeight, scaler);
        }
        _fontGroupScale[probeCacheKey] =
            (_kRefLineUnits * 12 / sum).clamp(0.90, 1.12);
      }
      groupScale = _fontGroupScale[probeCacheKey] ?? 1.0;
    }
    final effFontSize = fontSize * groupScale;

    // Render key for the tree memo. The highlight only matters to this page
    // when the page actually carries that verse; otherwise it is folded to a
    // constant so a neighbour page is not relaid out on every recited word.
    final highlight = widget.highlight;
    final highlightOnPage =
        _pageHasVerse(page, highlight.surah, highlight.ayah);
    final highlightKey = highlightOnPage
        ? '${highlight.surah}:${highlight.ayah}:${highlight.activeWord}'
        : 'none';
    // Persistent tints are part of the render inputs too — a saved highlight
    // must repaint the affected pages, so its fingerprint invalidates the memo.
    final tintKey = widget.verseTints.entries
        .map((e) => '${e.key}=${e.value.toARGB32()}')
        .join(',');
    // The wash belongs in the key for the same reason the tints do: it is paint,
    // and the memoized tree below would otherwise keep the previous paper's
    // tint when only the paper changed.
    final washKey = widget.recitationWash == null
        ? 'none'
        : widget.recitationWash!.toARGB32().toString();
    final renderKey = '${widget.page}|${widget.retryTick}|$effFontSize|'
        '$lineHeight|${fontWeight.value}|$scaler|'
        '${baseColor.toARGB32()}|${hlColor.toARGB32()}|'
        '${headerColor.toARGB32()}|w:$washKey|'
        '${(widget.verseMarkerColor ?? const Color(0xFF7A4A21)).toARGB32()}|'
        '${highlight.activeWord != null && highlightOnPage}'
        '|$highlightKey|t:$tintKey';

    // Short pages (the last mushaf pages holding small surahs like An-Nas,
    // Al-Falaq, Al-Ikhlas) carry a lot of empty "padding" lines that make the
    // natural column tall-and-narrow. FittedBox then binds on the page height
    // and the content renders small with big empty side margins. Dropping
    // those blank (non-header, non-word) lines lets the fit bind on width so
    // the glyphs render larger and the page fills the screen — all real
    // verses/headers are preserved (nothing lives on the blank rows).
    final isShort = page.lines.where(_lineHasContent).length < 11;
    final lines =
        isShort ? page.lines.where(_lineHasContent).toList() : page.lines;

    final metrics = _metricsFor(
      page: page,
      lines: lines,
      fontSize: effFontSize,
      lineHeight: lineHeight,
      fontWeight: fontWeight,
      headerColor: headerColor,
      baseColor: baseColor,
      scaler: scaler,
    );

    // Fit the whole Mushaf page onto the screen: render every line at a
    // natural size, then scale the column down so the full page — including
    // band/header/footer rows — is visible without scrolling or clipping.
    // Tap targets still map correctly under the transform. Short pages are
    // vertically justified (extra space becomes even inter-line gaps) so
    // every page fills the screen edge to edge — except the first two
    // pages (Al-Fatihah + the opening of Al-Baqarah): with so few lines the
    // stretched gaps look broken, so those keep natural spacing and sit at
    // the top instead of filling the screen.
    //
    // When the page opens with the surah banner, the top padding shrinks so
    // the ornament sits close to the screen edge.
    final firstIsBanner = lines.isNotEmpty &&
        lines.first.words.isNotEmpty &&
        lines.first.words.first.type == 'surah_header';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        // `opaque`, not `deferToChild`: the page is mostly blank space between
        // lines and around the text block, and a deferred detector only fires
        // where a glyph already claimed the hit — so the double tap could not
        // bring the chrome back from the margins. Word and verse marks keep
        // their own handlers: they sit deeper in the tree and win the arena for
        // taps that land on them.
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTap,
        child: SizedBox.expand(
          // Horizontal breathing room: the glyphs must not touch the screen
          // edges like the print does not touch the paper edge. Portrait gets
          // a slimmer margin than landscape (larger glyphs there).
          child: Padding(
            padding: EdgeInsets.fromLTRB(widget.fitWidth ? 16 : 10,
                firstIsBanner ? 1 : 8, widget.fitWidth ? 16 : 10, 8),
            child: LayoutBuilder(
              builder: (ctx, cons) {
                final treeKey = '$renderKey|${widget.fitWidth}|'
                    '${cons.maxWidth}x${cons.maxHeight}';
                if (_cachedTree != null && _cachedTreeKey == treeKey) {
                  return _cachedTree!;
                }
                // Vertical justification only makes sense when the whole page
                // is visible at once; in fitWidth mode the page overflows and
                // stretched gaps would just push content further down.
                final gap = !widget.fitWidth && page.page > 2
                    ? _fillGap(cons, metrics, effFontSize)
                    : 0.0;
                final children = <Widget>[];
                children.add(SizedBox(height: gap / 2));
                for (var i = 0; i < lines.length; i++) {
                  if (i > 0) children.add(SizedBox(height: gap));
                  children.add(_buildLine(
                    lines[i],
                    metrics.lineMetrics[i],
                    effFontSize,
                    lineHeight,
                    fontWeight,
                    baseColor,
                    hlColor,
                    headerColor,
                    highlightMap,
                    scaler,
                    // In the printed Mushaf every ordinary line spans the full
                    // text width. Measured slack within 15% of the body size
                    // is font-metric residue: stretch it so ALL full lines
                    // share identical right/left edges. A bigger deficit is a
                    // genuinely short line — those are right-aligned below
                    // instead of stretched, so they never sit mid-line.
                    justifyLine: metrics.width - metrics.lineMetrics[i].width <=
                        fontSize * 0.15,
                    fillWidth: metrics.width,
                  ));
                }
                children.add(SizedBox(height: gap / 2));
                final column = Column(
                  mainAxisSize: MainAxisSize
                      .min, // NOTE: keep the default (center) cross alignment. Stretch
                  // is forbidden here: under FittedBox the incoming width is
                  // unbounded, so stretch hands children tight(infinity)
                  // constraints → the column measures infinite → FittedBox
                  // scales to zero → a completely blank page in release.
                  children: children,
                );
                final Widget tree;
                if (widget.fitWidth) {
                  // Landscape reading mode: scale bound on width so glyphs
                  // render as large as the screen allows; the vertical
                  // overflow scrolls (top-anchored).
                  tree = SingleChildScrollView(
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      child: column,
                    ),
                  );
                } else {
                  tree = FittedBox(
                    // Top-anchored, except the first two pages (Al-Fatihah +
                    // Al-Baqarah's opening) which stay vertically centered as
                    // an exception. Leftover space goes below the last line,
                    // so the first line always sits close to the screen edge.
                    alignment:
                        page.page <= 2 ? Alignment.center : Alignment.topCenter,
                    child: column,
                  );
                }
                _cachedTreeKey = treeKey;
                _cachedTree = tree;
                // The new page is live — drop the preserved previous render.
                if (_staleTree != null) {
                  _staleTree = null;
                }
                return tree;
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Whether a line should be kept when compacting a short page: keep
  /// centered ornaments (surah banner / bismillah) and any line holding at
  /// least one Quranic word; drop the blank filler rows around them.
  bool _lineHasContent(Qcf4Line line) {
    if (line.words.isEmpty) return false;
    for (final w in line.words) {
      if (w.isCentered) return true;
      if (w.type == 'word') return true;
    }
    return false;
  }

  /// Whether this page carries the given verse — used to decide if a
  /// highlight change can possibly affect the page's rendered output.
  bool _pageHasVerse(Qcf4Page page, int? surah, int? ayah) {
    if (surah == null || ayah == null) return false;
    final target = '$surah:$ayah';
    for (final line in page.lines) {
      for (final w in line.words) {
        if (w.verseKey == target) return true;
      }
    }
    return false;
  }

  Widget _busy(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'در حال آماده‌سازی صفحه…',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(
    Qcf4Line line,
    _LineMetric metric,
    double fontSize,
    double lineHeight,
    FontWeight fontWeight,
    Color baseColor,
    Color hlColor,
    Color headerColor,
    Map<String, List<Qcf4Word>> highlightMap,
    TextScaler scaler, {
    // True when this line's measured width nearly fills the column, in
    // which case it is stretched edge to edge (see the Row below).
    required bool justifyLine,
    // The column's width; only used to bound a justified line so its row has
    // slack for `spaceBetween` to distribute (see below).
    required double fillWidth,
  }) {
    final words = line.words;
    final special = words.every((w) => w.isCentered);
    if (special && words.isNotEmpty) {
      // surah_header → the quran-common ornamental band (floral glyph with
      // the calligraphic surah name in its cartouche, the surah number and
      // the revelation place in its ring medallions), filling the same
      // banner box the metrics pipeline reserved, so page justification is
      // unchanged. Bismillah stays in the body/BSML ink.
      final isSurahHeader = words.first.type == 'surah_header';
      final headerGlyph =
          isSurahHeader ? Qcf4Config.surahNameGlyph(words.first.sura) : null;
      final nameSize = metric.headerSize;
      if (headerGlyph != null && nameSize != null) {
        final sura = words.first.sura;
        final bannerW = metric.bannerW ?? 0.0;
        final bannerH = bannerW * Qcf4Config.surahHeaderAspect;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: _bannerMarginV),
          child: SizedBox(
            width: bannerW,
            height: bannerH,
            child: QuranCommonSurahHeader(
              glyph: headerGlyph,
              nameSize: nameSize,
              color: headerColor,
              number: sura,
              place:
                  sura == null ? null : Qcf4PageChrome.surahMeta(sura)?.place,
            ),
          ),
        );
      }
    }

    // Ordinary physical line → RTL row of words.
    //
    // QCF4 words have NO whitespace gaps between them — the inter-word spacing
    // is baked into each glyph's advance width so adjacent glyphs form the
    // exact printed Mushaf line. Adding any horizontal padding breaks the
    // alignment (words drift left/right along the line), so words are placed
    // with zero horizontal padding and share a common baseline so every verse
    // sits fixed at its correct position.
    final row = Row(
      // Justified lines spread only the font-metric residue between their
      // words (spaceBetween), giving every full verse line identical
      // right/left edges like the printed Mushaf. Genuinely short lines
      // hug the RIGHT edge — `start` in RTL, i.e. where the printed line
      // begins — instead of floating centered mid-column, which visually
      // misaligned them with the full lines above and below.
      mainAxisAlignment: justifyLine
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (final w in words)
          _buildWord(w, fontSize, lineHeight, fontWeight, baseColor, hlColor,
              highlightMap),
      ],
    );
    // A justified line needs at least [fillWidth] so `spaceBetween` has slack
    // to distribute and every full verse line shares identical right/left edges.
    // Using minWidth (not a fixed width) avoids the sub-pixel measurement vs
    // rendering mismatch that would overflow a rigid Box: if the Row's natural
    // width slightly exceeds [fillWidth] the Row keeps its natural width and
    // no RenderFlex overflow occurs. Genuinely short lines keep their natural
    // width and right-align through the Row's start (RTL) alignment.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: justifyLine
          ? ConstrainedBox(
              constraints: BoxConstraints(minWidth: fillWidth),
              child: row,
            )
          : row,
    );
  }

  /// Faux-bold: the QCF4 families ship a single TTF weight, so [FontWeight]
  /// alone cannot thicken the glyphs. Two crisp zero-blur shadows offset by
  /// ±[halfWidth] redraw the glyph on both sides, widening every outline by
  /// ~2×[halfWidth] in total. Used ONLY for the global body ink — the recited
  /// ayah is distinguished by color + a soft background band instead
  /// (see [_buildWord]); the user asked for no extra weight while playing.
  List<Shadow> _bold(Color color, double halfWidth) => [
        Shadow(color: color, offset: Offset(halfWidth, 0)),
        Shadow(color: color, offset: Offset(-halfWidth, 0)),
      ];

  Widget _buildWord(
    Qcf4Word w,
    double fontSize,
    double lineHeight,
    FontWeight fontWeight,
    Color baseColor,
    Color hlColor,
    Map<String, List<Qcf4Word>> highlightMap,
  ) {
    final active = _isActiveWord(w, highlightMap);
    final color = active ? hlColor : baseColor;

    // Verse-end markers get a distinctive brown colour so they visually
    // separate from the text (matching the printed Madinah mushaf).
    final isVerseEnd = w.type == 'end';
    final markerColor = widget.verseMarkerColor ?? const Color(0xFF7A4A21);
    final textColor = isVerseEnd ? markerColor : color;

    // Persistent (user-saved) ayah highlight: a marker-pen band in the saved
    // color under the words of that ayah, independent of playback.
    final tint = w.verseKey == null ? null : widget.verseTints[w.verseKey];

    final text = Text(
      w.char,
      style: TextStyle(
        fontFamily: w.font,
        // The end-of-verse medallion (number + circle) is drawn ~15% bigger
        // than the surrounding words; quarter markers keep the smaller size.
        fontSize: isVerseEnd
            ? fontSize * 0.92
            : w.type == 'quarter'
                ? fontSize * 0.8
                : fontSize,
        height: lineHeight,
        fontWeight: fontWeight,
        color: textColor,
        // Body ink gets a constant subtle weight (medallion slightly more) —
        // the active ayah is NOT bolder; it is colored + banded.
        shadows: _bold(textColor, fontSize * (isVerseEnd ? 0.01 : 0.005)),
      ),
      textDirection: TextDirection.rtl,
    );

    // The recited ayah's tint comes from the palette, not from a local alpha:
    // the wash sits under text of its own colour, so how strong it may be is a
    // legibility question the palette answers per paper (see
    // `mushafLiveAyahWashOn`).
    final wash = widget.recitationWash;
    final body = active
        ? wash != null
            ? DecoratedBox(
                decoration: BoxDecoration(color: wash),
                child: text,
              )
            : text
        : tint != null
            ? DecoratedBox(
                decoration: BoxDecoration(color: tint),
                child: text,
              )
            : text;

    // Verse-end and quarter markers are tappable but not word-audio targets.
    if (isVerseEnd || w.type == 'quarter') {
      final surah = _surahFromKey(w.verseKey);
      final ayah = _ayahFromKey(w.verseKey);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (surah != null && ayah != null) {
            widget.onVerseEndTap?.call(surah, ayah);
          }
        },
        child: isVerseEnd
            // The QCF4 end-of-verse glyph already carries its own decorative
            // medallion + number, so no extra circle is needed. Just nudge it
            // up a touch so the number sits level with the line instead of
            // dropping below the baseline.
            ? Transform.translate(
                // Nudged up so the number sits level with the line; +5% more
                // from the previous offset per the user's request.
                offset: Offset(0, -(fontSize * 0.10)),
                child: body,
              )
            : body,
      );
    }

    // A `word` → tap fires verse actions with the Quran.com position.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final s = _surahFromKey(w.verseKey);
        final a = _ayahFromKey(w.verseKey);
        if (s != null && a != null) widget.onWordTap?.call(s, a, w.position);
      },
      onLongPress: () {
        final s = _surahFromKey(w.verseKey);
        final a = _ayahFromKey(w.verseKey);
        if (s != null && a != null) {
          widget.onWordLongPress?.call(s, a, w.position);
        }
      },
      child: body,
    );
  }

  /// Builds a lookup of verse key → list of its `word`-type Qcf4Word on this
  /// page, plus remembers the currently-active word's key so we can color it.
  Map<String, List<Qcf4Word>> _buildHighlightMap(Qcf4Page page) {
    final map = <String, List<Qcf4Word>>{};
    for (final line in page.lines) {
      for (final w in line.words) {
        final vk = w.verseKey;
        if (vk == null || w.type != 'word') continue;
        map.putIfAbsent(vk, () => []).add(w);
      }
    }
    return map;
  }

  bool _isActiveWord(Qcf4Word w, Map<String, List<Qcf4Word>> highlightMap) {
    final h = widget.highlight;
    if (h.surah == null || h.ayah == null) return false;
    final vk = w.verseKey;
    if (vk == null || w.type != 'word') return false;

    final target = '${h.surah}:${h.ayah}';
    if (vk != target) return false;

    // Word-level audio: `activeWord` is -1 while the controller has no
    // per-word timing loaded, so -1 also means "the whole ayah".
    final aw = h.activeWord;
    if (aw == null || aw < 0) {
      // Whole-ayah mode: every word of the ayah carries the recitation color
      // (and the soft band) — word ticks switch to the single-word form.
      return w.verseKey != null;
    }

    // Word-level: the QCF4 `position` is 1-based and matches the
    // Quran.com word index (which `activeWord` indexes 0-based).
    final list = highlightMap[vk];
    if (list == null) return true;
    final index = list.indexOf(w);
    return index == h.activeWord;
  }

  int? _surahFromKey(String? key) {
    if (key == null) return null;
    final idx = key.indexOf(':');
    if (idx <= 0) return null;
    return int.tryParse(key.substring(0, idx));
  }

  int? _ayahFromKey(String? key) {
    if (key == null) return null;
    final idx = key.indexOf(':');
    if (idx < 0 || idx == key.length - 1) return null;
    return int.tryParse(key.substring(idx + 1));
  }

  // ── Natural-size metrics + vertical justification ─────────────────────────
  //
  // Every child is measured with the exact style it renders with, so the
  // computed column size matches the real layout. Short pages then get even
  // inter-line gaps that make the column aspect equal the viewport aspect —
  // FittedBox fits it edge to edge instead of centering it in margins.

  Size _measureSpans(List<InlineSpan> spans, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
    )..layout();
    return tp.size;
  }

  TextStyle _wordMeasureStyle(
      Qcf4Word w, double fontSize, FontWeight fontWeight, double factor) {
    // Must mirror the render style in [_buildWord]: the faux-bold shadow
    // pair extends each glyph's layout width by the shadow offset, so leaving
    // them out of the measurement under-counters every rendered line and a
    // justified row pinned to that width overflows.
    return TextStyle(
      fontFamily: w.font,
      fontSize: fontSize * factor,
      fontWeight: fontWeight,
      shadows: _bold(const Color(0xFF000000),
          fontSize * factor * (w.type == 'end' ? 0.01 : 0.005)),
    );
  }

  double _wordFactor(Qcf4Word w) => w.type == 'end'
      ? 0.92
      : w.type == 'quarter'
          ? 0.8
          : 1.0;

  /// Process-wide cache of a word's natural width, keyed by font, glyph char,
  /// scaled size and weight. QCF4 reuses the same visual word (same font +
  /// char code) across every page of a font group, so after the first pages of
  /// a group most words are already measured and later pages never pay a
  /// TextPainter for them. Sized from the front, bounded.
  static final Map<String, double> _wordWidthCache = {};
  static const int _wordWidthCacheMax = 3000;

  double _wordWidth(
      Qcf4Word w, double fontSize, FontWeight fontWeight, TextScaler scaler) {
    final factor = _wordFactor(w);
    final key = '${w.font}|${w.char}|${fontSize * factor}'
        '|${fontWeight.value}|${scaler.scale(1.0)}';
    final cached = _wordWidthCache[key];
    if (cached != null) return cached;
    while (_wordWidthCache.length >= _wordWidthCacheMax) {
      _wordWidthCache.remove(_wordWidthCache.keys.first);
    }
    final width = _measureSpans(
      [
        TextSpan(
          text: w.char,
          style: _wordMeasureStyle(w, fontSize, fontWeight, factor),
        ),
      ],
      scaler,
    ).width;
    _wordWidthCache[key] = width;
    return width;
  }

  /// Name font size so the calligraphic glyph's advance fills the
  /// quran-common band's middle cartouche — capped by that surah's exact ink
  /// height (from the measured TTF bounds) so the ink fills the field
  /// without touching the cartouche walls in any surah.
  double _bannerNameSize({
    required double bannerW,
    required int? sura,
    required double fontSize,
  }) {
    final cartW = bannerW * Qcf4Config.quranHeaderCartoucheW;
    final cartH = bannerW * Qcf4Config.quranHeaderCartoucheH;
    var nameSize =
        Qcf4Config.surahNameSizeForWidth(sura, cartW * _bannerNameWFill) ??
            fontSize;
    final inkH = Qcf4Config.surahNameInkHeight(sura ?? 0) ?? 820;
    final nameMaxH = cartH * _bannerNameInkFill * 1024 / inkH;
    if (nameSize > nameMaxH) nameSize = nameMaxH;
    return nameSize;
  }

  _Qcf4PageMetrics _metricsFor({
    required Qcf4Page page,
    required List<Qcf4Line> lines,
    required double fontSize,
    required double lineHeight,
    required FontWeight fontWeight,
    required Color headerColor,
    required Color baseColor,
    required TextScaler scaler,
  }) {
    final key =
        '${page.page}|$fontSize|$lineHeight|${fontWeight.value}|$scaler';
    final cached = _metricsCache.remove(key);
    if (cached != null) {
      _metricsCache[key] = cached; // mark most-recently-used
      return cached;
    }

    // Shared process-wide LRU: drop the oldest entry once full so revisiting
    // pages stays cheap without pinning every page's metrics in RAM.
    const maxEntries = 42;
    while (_metricsCache.length >= maxEntries) {
      _metricsCache.remove(_metricsCache.keys.first);
    }

    // Lines.
    var width = 0.0;
    final lineMetrics = <_LineMetric>[];
    for (final line in lines) {
      final words = line.words;
      final special = words.isNotEmpty && words.every((w) => w.isCentered);
      if (special) {
        final isHeader = words.first.type == 'surah_header';
        final glyph =
            isHeader ? Qcf4Config.surahNameGlyph(words.first.sura) : null;
        // Fixed banner width (font-size derived, identical on every page)
        // — calibrated to span the column like the verse lines.
        final bannerW =
            Qcf4Config.surahHeaderBannerWidth(words.first.sura, fontSize);
        if (glyph != null && bannerW != null) {
          final bannerH = bannerW * Qcf4Config.surahHeaderAspect;
          final nameSize = _bannerNameSize(
            bannerW: bannerW,
            sura: words.first.sura,
            fontSize: fontSize,
          );
          final h = bannerH + 2 * _bannerMarginV;
          if (bannerW > width) width = bannerW;
          lineMetrics.add(_LineMetric(bannerW, h, nameSize, bannerW));
          continue;
        }
        // Bismillah / header fallback at 1.4×.
        final size = _measureSpans(
          [
            for (final w in words)
              TextSpan(
                text: w.char,
                style: TextStyle(
                    fontFamily: w.font,
                    fontSize: fontSize * 1.4,
                    fontWeight: fontWeight),
              ),
          ],
          scaler,
        );
        final w = size.width;
        final h = fontSize * 1.4 * lineHeight + _specialLineVPadding;
        if (w > width) width = w;
        lineMetrics.add(_LineMetric(w, h));
        continue;
      }
      // Ordinary line: words sit with zero gaps, so the width is the sum.
      // Measuring one combined paragraph here would NOT match the per-word
      // Texts rendered in the Row (run-boundary shaping can shift advances),
      // so widths must be summed word by word — see [_wordWidth], which makes
      // this cheap across pages via a process-wide cache.
      var w = 0.0;
      for (final wd in words) {
        w += _wordWidth(wd, fontSize, fontWeight, scaler);
      }
      final h = fontSize * lineHeight + _bodyLineVPadding;
      if (w > width) width = w;
      lineMetrics.add(_LineMetric(w, h));
    }

    final metrics = _Qcf4PageMetrics(
      width: width,
      lineMetrics: lineMetrics,
    );
    _metricsCache[key] = metrics;
    return metrics;
  }

  /// Even inter-line gap (natural px) that stretches a short page to the
  /// viewport aspect. Zero on height-bound (full) pages. Capped so nearly
  /// empty pages never get absurd spacing.
  double _fillGap(
      BoxConstraints cons, _Qcf4PageMetrics metrics, double fontSize) {
    final n = metrics.lineMetrics.length;
    if (n <= 0 || metrics.width <= 0 || metrics.totalHeight <= 0) return 0;
    final vw = cons.maxWidth;
    final vh = cons.maxHeight;
    if (!vw.isFinite || !vh.isFinite || vw <= 0 || vh <= 0) return 0;
    final s = vw / metrics.width < vh / metrics.totalHeight
        ? vw / metrics.width
        : vh / metrics.totalHeight;
    if (s <= 0) return 0;
    final extra = vh / s - metrics.totalHeight;
    if (extra <= 0) return 0;
    final gap = extra / n;
    final cap = fontSize * 3;
    return gap > cap ? cap : gap;
  }
}

/// Natural size of one column child (+ the banner's precomputed name size
/// and ornament width).
class _LineMetric {
  final double width;
  final double height;
  final double? headerSize;
  final double? bannerW;
  const _LineMetric(this.width, this.height, [this.headerSize, this.bannerW]);
}

/// Natural column geometry of a page: per-line metrics.
class _Qcf4PageMetrics {
  final double width;
  final List<_LineMetric> lineMetrics;

  const _Qcf4PageMetrics({
    required this.width,
    required this.lineMetrics,
  });

  double get totalHeight {
    var h = 0.0;
    for (final l in lineMetrics) {
      h += l.height;
    }
    return h;
  }
}
