part of 'quran_mushaf_view.dart';

/// Inline error card for a QCF4 page whose font/data failed to load.
/// Replaces the old dead blank page: retry re-triggers the viewer, download
/// opens the full-mushaf pre-download sheet.
///
/// The inks arrive from the page that draws it instead of being re-typed here.
/// The card used to carry four literal colours — two of which were the page's
/// own ink constants retyped, and two of which were a muted pair nothing else
/// knew about — so a reader on any page tint other than the two the card
/// guessed got an unreadable panel. The muted ink is now derived from the ink
/// and the paper, which is the only relationship that stays true across the
/// whole palette.
class _PageLoadErrorCard extends StatelessWidget {
  const _PageLoadErrorCard({
    required this.ink,
    required this.paper,
    required this.onRetry,
    required this.onDownload,
  });

  /// The page's own text colour ([kMushafCreamInk] / [kMushafDarkInk], chosen
  /// by contrast at the call site).
  final Color ink;

  /// The page's background, used only to blend the secondary ink.
  final Color paper;

  final VoidCallback onRetry;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final sub = Color.alphaBlend(ink.withValues(alpha: 0.62), paper);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: sub),
            const SizedBox(height: 12),
            Text(
              'این صفحه آماده نیست',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 17),
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'اتصال اینترنت را بررسی کنید یا مصحف را برای استفادهٔ آفلاین دانلود کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: sub,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                    onPressed: onRetry, child: const Text('تلاش دوباره')),
                const SizedBox(width: 12),
                OutlinedButton(
                    onPressed: onDownload, child: const Text('دانلود مصحف')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The small pill that takes the mini player's place when the reader tucked
/// the bar away («مخفی کردن نوار پخش»). Playback is untouched — a tap brings
/// the full panel back. Only rendered while a session actually exists.
class _ResumePlayerPill extends StatelessWidget {
  const _ResumePlayerPill({required this.palette, required this.onTap});

  final MushafPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'نمایش نوار پخش',
      child: Tooltip(
        message: 'نمایش نوار پخش',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: palette.chrome.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: palette.onChrome.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      size: 16, color: AppPalette.heroGold),
                  const SizedBox(width: 5),
                  Text(
                    'نمایش نوار پخش',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.onChrome,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
