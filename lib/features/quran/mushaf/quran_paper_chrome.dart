import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';

/// The one bar the reader's paper aux screens wear.
///
/// The mushaf is theme-independent: its screens draw from a [MushafPalette],
/// never from the app's time theme. The three aux screens that are not the
/// immersive reader — the bookmark list, the surah index and the in-reader
/// search — had each grown their own [AppBar] instead: two on `chrome` and one
/// on `surface`, three title styles, `centerTitle` on two of the three and
/// `elevation` on one. The same paper therefore opened three different bars.
/// This is that recipe, once.
///
/// The title still runs through [AppTheme.scaledFontSize] like every other
/// surface: 15 is a step on the shared scale, so the default rendering is
/// pixel-identical, but the size can never drift off the scale again.
///
/// Deliberately NOT used by [QuranMushafView] (the immersive reader paints its
/// own chrome over the page) or by the ayah/tafsir share screens (they are
/// `AmbientBackground` + `ShareCardPalette` surfaces, a different family).
AppBar quranPaperAppBar(
  BuildContext context, {
  required MushafPalette palette,
  required String title,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: palette.chrome,
    foregroundColor: palette.onChrome,
    // The bar is paper, not a material sheet: no lift in either scroll state.
    // The app theme zeroes both already; stating them here keeps the bar
    // correct under any theme a test or an embedder pumps it into.
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    actions: actions,
    title: Text(
      title,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, 15),
        fontWeight: FontWeight.w700,
        color: palette.onChrome,
      ),
    ),
  );
}
