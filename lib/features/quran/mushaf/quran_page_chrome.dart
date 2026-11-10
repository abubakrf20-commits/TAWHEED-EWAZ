// Reader page chrome — what sits AROUND the Quran text, never on it.
//
// Spec: the small colour swatch that used to prefix the page number is gone, the
// page-side book glyph is gone too (reader request: «پایین ایکون صفحهٔ راست و
// چپ حذف کن»), and a faint gutter shadow still runs down the binding side. The
// gold hairlines above and below the text block were removed earlier: the page
// reads as paper, not as a framed panel.
//
// Page identity (reader request, 2026-10-13): every page prints its own facts
// in the bands it reserves around the glyphs — the surah name top-right, the
// juz top-left, the folio bottom-centre — on a continuation page just as much
// as on the page a surah opens, and in BOTH chrome states.
//
// Alignment contract (reader request, 2026-11-10: «شمارهٔ صفحه پایین تراز
// نیست» and «اسم سوره و جزء هم تراز نیستند»): the three labels used to come
// from three different rules — juz and surah pinned at 10dp from opposite
// edges, the folio at a hard-coded 34dp, each with its own edge depending on
// page parity — so nothing lined up. They now share ONE contract:
//   * one edge inset for all page furniture ([_kPageEdge] = 12dp);
//   * surah and juz sit in one Row on a common alphabetic baseline;
//   * the folio is centred on the page, in the bottom band;
//   * parity no longer moves a label (it only picks which edge the binding
//     shadow falls on), so a page prints the same furniture in a spread or
//     alone.
// Everything is still drawn in the bands the page already reserves
// (`_pageTopInset` / `_pageBottomInset`), so the glyph geometry is untouched.
//
// Nothing floats over the page as a control: the handle that used to open the
// header is gone, and the way back to it is the double tap (see `_toggleChrome`).

part of 'quran_mushaf_view.dart';

/// Distance of every page-furniture label from the page edge.
const double _kPageEdge = 12;

/// Page chrome drawn in the reserved bands: the gutter shadow, the surah and juz
/// corner labels, and the page number.
/// IgnorePointer — it is decoration, and taps must reach the page's own
/// double-tap detector through it.
class _PageChrome extends StatelessWidget {
  const _PageChrome({
    required this.page,
    required this.textColor,
    required this.surahName,
    required this.juz,
    required this.gutterTint,
    this.byParity = true,
    this.headerBand = 0,
    this.playerBand = 0,
  });

  final int page;

  /// Ink colour for the page furniture — follows the ayah-number colour so it
  /// stays readable on dark papers (palette.surfaceText can be dark-on-dark
  /// there, which is why the old chips took this colour too).
  final Color textColor;

  /// The Arabic surah name printed in the top-right corner, on every page.
  final String? surahName;

  /// The juz printed in the top-left corner, on the same terms as [surahName].
  final int? juz;

  /// How much of the top band the header overlay already covers
  /// (`_pageTopInset`): the labels sit below it, inside the 28 dp the page
  /// keeps clear of its own glyphs.
  final double headerBand;

  /// How much of the bottom band the mini player covers (`_pageBottomInset`),
  /// on the same terms for the page number.
  final double playerBand;

  /// The shade the binding falls into: the paper mixed towards black, so the
  /// gutter belongs to the sheet it is printed on instead of being a grey
  /// stripe (the night paper uses black on its own).
  final Color gutterTint;

  /// «ظاهر صفحات راست و چپ مثل مصحف چاپی» — kept for the binding side only.
  /// It no longer moves the page furniture: the labels used to swap edges with
  /// the page parity, which is what made two facing pages disagree about where
  /// the folio belongs. The printed sheet's 18dp spine is still parity-driven.
  final bool byParity;

  @override
  Widget build(BuildContext context) {
    final surah = surahName;
    final juzNumber = juz;
    // Half an identity is no identity: a lone surah name in a corner would
    // read as a stray label rather than as the page's own printing.
    final showIdentity =
        surah != null && surah.isNotEmpty && juzNumber != null && juzNumber > 0;
    // A Persian book opens from the RIGHT: page 1 is the right-hand sheet,
    // page 2 the left-hand one, and the spine runs BETWEEN them — so an odd
    // page's binding is its LEFT edge and an even page's is its RIGHT edge.
    final isOdd = page.isOdd;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gutter shadow on the binding (spine) side. The printed sheet's
          // spread is 18 dp; the pre-parity look is kept at its 26 dp so
          // turning the option off restores the old page exactly.
          Positioned(
            top: 0,
            bottom: 0,
            right: isOdd ? null : 0,
            left: isOdd ? 0 : null,
            width: byParity ? 18 : 26,
            child: _GutterShadow(rightSide: !isOdd, tint: gutterTint),
          ),
          // The page's own two facts, on one baseline in the band above the
          // text block. The Row is LTR so the juz is always the LEFT label and
          // the surah always the right one, whatever the app locale; each
          // label itself renders RTL, so the Arabic name reads correctly.
          if (showIdentity)
            Positioned(
              top: headerBand + 8,
              left: _kPageEdge,
              right: _kPageEdge,
              child: Row(
                textDirection: TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  _PageCornerLabel(
                    key: ValueKey('mushaf_corner_juz_$page'),
                    text: 'جزء ${NumberFormat.toLatin('$juzNumber')}',
                    color: textColor,
                  ),
                  Flexible(
                    child: _PageCornerLabel(
                      key: ValueKey('mushaf_corner_surah_$page'),
                      text: 'سورة $surah',
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          // The folio: centred in the bottom band, on the same contract as the
          // identity above — one edge inset, one baseline, no parity jump. A
          // centred folio is what a printed mushaf carries, and it cannot
          // collide with the binding shadow on either hand.
          Positioned(
            bottom: playerBand + 6,
            left: 0,
            right: 0,
            child: Center(
              child: _PageCornerLabel(
                key: ValueKey('mushaf_corner_page_$page'),
                text: NumberFormat.toLatin('$page'),
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One corner fact of the page identity — the surah, the juz, the page number.
/// Plain dim text in the band the page keeps clear of its glyphs: nothing here
/// is boxed, captioned or tappable, so it reads as the page's own printing
/// rather than as a control sitting on the mushaf.
class _PageCornerLabel extends StatelessWidget {
  const _PageCornerLabel({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      textDirection: TextDirection.rtl,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color.withValues(alpha: 0.6),
      ),
    );
  }
}

/// The gutter: a soft dark gradient falling away from the spine edge, painted
/// flat (no blur) so it costs nothing on the page layer. [rightSide] is true
/// for the LEFT-hand page of a spread, whose spine is its right edge.
class _GutterShadow extends StatelessWidget {
  const _GutterShadow({required this.rightSide, this.tint});

  final bool rightSide;

  /// The paper's own shade, mixed towards black by the caller. Null keeps the
  /// pre-parity black wash so the option's OFF state is pixel-identical.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final shade =
        tint == null ? const Color(0x22000000) : tint!.withValues(alpha: 0.26);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: rightSide ? Alignment.centerRight : Alignment.centerLeft,
          end: rightSide ? Alignment.centerLeft : Alignment.centerRight,
          colors: [shade, shade.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
