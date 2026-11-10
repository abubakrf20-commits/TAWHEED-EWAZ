// Reader header chrome (spec A): a slim two-cluster band that carries the
// page identity, so nothing has to float over the glyphs.
//
//   start  → surah index · search
//   centre → «سورة X» 14/600 cream + «جزء N · صفحه M» 10 gold
//   end    → bookmark · orientation (rotate) · overflow (⋮)
//
// Everything the old bar used to squeeze in (reciter, repeat, reading
// settings, translation/tafsir, downloads) lives in the player or the
// overflow menu instead — that is what truncated the reciter name to
// «ماهر ال…» on a phone.
//
// The band is a single flat emerald, not the app's time-of-day hero gradient:
// the mushaf is theme-independent and its chrome may not change hue at
// maghrib. One colour token is shared with both player pads, so the reader
// never shows two different chromes in one session. The gold hairline under
// the band is the only separation from the paper — the 3dp progress line is
// gone (it duplicated the page number the paper already prints).
//
// Performance: the band is `const`-friendly and rebuilds only when the page
// or its identity changes; the glyph layer below never re-lays-out because
// the band's height is the same constant the page already reserves.

part of 'quran_mushaf_view.dart';

/// Height of the header band. The page's top inset is derived from this, so
/// the two must stay in sync — see [_pageTopInset].
const double _kReaderHeaderBand = 46;

/// The chrome ink shared by the header band and both player pads.
///
/// One deep emerald — not the active app theme's hero gradient. The paper, the
/// ink and the accent all come from [MushafPalette], which is deliberately
/// theme-independent; a chrome that turned with the time of day was the only
/// surface in the reader that did.
const Color _kReaderChrome = Color(0xFF0C3B2F);

/// Gold used on the chrome: the hairline under the band and the active icon.
const Color _kReaderChromeGold = Color(0xFFC9A227);

/// Cream label ink on the dark chrome.
const Color _kReaderHeaderTitle = Color(0xFFFFF6E3);

/// The reader chrome colour, for callers outside this file (the two player
/// pads) so the band and the pads can never drift apart.
Color _readerChromeColor() => _kReaderChrome;

class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({
    required this.palette,
    required this.page,
    required this.surahName,
    required this.juz,
    required this.bookmarked,
    required this.landscape,
    required this.onIndex,
    required this.onSearch,
    required this.onBookmark,
    required this.onOrientation,
    required this.onOverflow,
    required this.onGoTo,
  });

  final MushafPalette palette;
  final int page;
  final String surahName;
  final int juz;

  /// Whether the current page carries a bookmark (drives the filled icon).
  final bool bookmarked;

  /// Whether the reader is locked to landscape. Drives the rotate button's
  /// glyph and its tooltip (which names where the tap will take you).
  final bool landscape;

  final VoidCallback onIndex;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;

  /// Flips the reader between the locked landscape view and portrait. Shares
  /// the reading-settings switch's preference, so the two never disagree.
  final VoidCallback onOrientation;
  final VoidCallback onOverflow;

  /// Jump-to-page sheet (page / surah / juz) — the centre title is a button
  /// too, because that is what a reader taps when lost mid-surah.
  final VoidCallback onGoTo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kReaderHeaderBand,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _kReaderChrome,
          // A hairline, not a shadow: the band is ink on the paper's edge, so
          // it must not lift off the page like a material sheet.
          border: Border(
            bottom: BorderSide(color: Color(0x61C9A227), width: 1),
          ),
        ),
        child: Row(
          children: [
            // ── start: index + search ──────────────────────────────
            _hdrIcon(Icons.format_list_numbered_rtl, 'فهرست سوره‌ها', onIndex),
            _hdrIcon(Icons.search_rounded, 'جستجو در قرآن', onSearch),
            // ── centre: the page identity ─────────────────────────
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onGoTo,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'سورة $surahName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kReaderHeaderTitle,
                      ),
                    ),
                    Text(
                      'جزء ${NumberFormat.toLatin('$juz')} · '
                      'صفحه ${NumberFormat.toLatin('$page')}',
                      maxLines: 1,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 10),
                        letterSpacing: 0.2,
                        color: _kReaderChromeGold.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── end: bookmark + orientation + overflow ─────────────
            _hdrIcon(
              bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              'نشان‌های قرآن',
              onBookmark,
              active: bookmarked,
            ),
            // The rotate button: one tap swaps the reader between the
            // locked landscape spread and portrait. The tooltip names the
            // destination, so its meaning is never a guess.
            _hdrIcon(
              landscape
                  ? Icons.stay_current_portrait_rounded
                  : Icons.stay_current_landscape_rounded,
              landscape ? 'حالت عمودی' : 'حالت افقی',
              onOrientation,
              active: landscape,
            ),
            _hdrIcon(Icons.more_vert_rounded, 'بیشتر', onOverflow),
          ],
        ),
      ),
    );
  }

  /// One compact header button: 44dp wide around a 20px icon, so a narrow band
  /// still satisfies the accessibility floor. Every glyph is `_rounded` at the
  /// same 20px so the bar reads as one set, and the three states are fixed:
  /// inactive = cream at 86%, active = gold, disabled = cream at 38%.
  Widget _hdrIcon(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return SizedBox(
      width: 44,
      height: _kReaderHeaderBand,
      child: IconButton(
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        tooltip: tooltip,
        icon: Icon(
          icon,
          color: active
              ? _kReaderChromeGold
              : palette.onChrome.withValues(alpha: 0.86),
          size: 20,
        ),
        onPressed: onTap,
      ),
    );
  }
}
