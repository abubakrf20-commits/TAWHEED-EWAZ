import 'dart:math' show pi;

import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// The reading surface shared by the tafsir and translation sheets.
///
/// An ayah is always read the way the reader already knows it: the app's own
/// face (Calibri unless the user picked another), a step larger than the body,
/// in a deeper emerald ink; the translation or tafsir follows underneath in
/// the plain body ink. Nothing on either sheet is boxed — measure, ink weight
/// and whitespace carry the hierarchy. Both sheets open through
/// [MushafContentSheetHeader] so their chrome can never drift apart again.
///
/// The page's only ornament is [MushafRuleOrnament] — a hairline broken by a
/// [MushafDiamond] — and it appears exactly where a printed page would put one:
/// above a surah's name, above a tafsir's title, and at the end of a reading.
/// Everything else is type, leading and air.

/// Height cap for the reader's content sheets (tafsir, translation).
const double kMushafContentSheetHeightFraction = 0.85;

/// Ink for a quoted ayah on a sheet: the palette accent pulled 22 % toward
/// the body ink.
///
/// The bare accent already clears the 4.5 floor on the page (≈4.74:1 light,
/// ≈6.80:1 night), but an ayah is the deepest thing on its sheet and the mix
/// measures ≈5.74:1 light / ≈7.93:1 night — the extra depth is what keeps the
/// quoted passage reading above the commentary without a box around it.
Color mushafAyahInk(MushafPalette palette) =>
    mix(palette.accent, palette.surfaceText, 0.22);

/// The quoted-ayah face: the reader's own font family, a step above the body.
TextStyle mushafAyahTextStyle(
  BuildContext context,
  MushafPalette palette, {
  double baseSize = 17,
  double height = 2.0,
}) {
  return TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontFamilyFallback: const ['Amiri', 'Calibri'],
    fontSize: AppTheme.scaledFontSize(context, baseSize),
    height: height,
    fontWeight: FontWeight.w600,
    color: mushafAyahInk(palette),
  );
}

/// A quoted ayah — the passage a tafsir explains.
///
/// Deliberately un-boxed: no fill, no border, no radius. The passage separates
/// itself from the commentary below by size, ink and the whitespace after it,
/// so the reader's page never reads as a stack of cards.
class MushafPassageAyah extends StatelessWidget {
  const MushafPassageAyah({
    super.key,
    required this.text,
    required this.palette,
    this.baseSize = 17,
  });

  final String text;
  final MushafPalette palette;
  final double baseSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: mushafAyahTextStyle(context, palette, baseSize: baseSize),
      ),
    );
  }
}

/// The kit's one ornament: a small square turned a quarter turn, sat on a
/// hairline to break it.
///
/// Printed books mark a break with a rule and a mark, not with a filled panel;
/// that is the whole reason this exists. It is drawn with a solid [Container]
/// and a rotation so it needs no decoration, no radius and no ink of its own
/// beyond the accent at a fraction of its strength.
class MushafDiamond extends StatelessWidget {
  const MushafDiamond({
    super.key,
    required this.palette,
    this.size = 5,
    this.alpha = 0.55,
  });

  final MushafPalette palette;
  final double size;

  /// How much of the accent the mark carries. Below ~0.4 it disappears on the
  /// lighter papers; above ~0.7 it starts reading as a bullet instead of a mark.
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: pi / 4,
      child: Container(
        width: size,
        height: size,
        color: palette.accent.withValues(alpha: alpha),
      ),
    );
  }
}

/// A hairline broken by a [MushafDiamond] — the break above a title, the close
/// of a sheet, the divider between readings.
///
/// Both rules are plain 1 dp [Container]s in [MushafPalette.border], so the
/// ornament never draws a fill behind text and never introduces a second
/// border colour. Not for [MushafContentSheetHeader]: its closing hairline is
/// pinned by the sheet's own chrome test.
class MushafRuleOrnament extends StatelessWidget {
  const MushafRuleOrnament({
    super.key,
    required this.palette,
    this.diamondSize = 5,
  });

  final MushafPalette palette;
  final double diamondSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: palette.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: MushafDiamond(palette: palette, size: diamondSize),
        ),
        Expanded(child: Container(height: 1, color: palette.border)),
      ],
    );
  }
}

/// The sheet chrome: grab handle, a title, an optional subtitle, an optional
/// quiet action row and a closing hairline. [bottom] is a full-width slot for
/// the content picker, which sits under the actions.
///
/// [MushafContentSheetHeader.compact] keeps the same handle and hairline but
/// puts the title and its actions on ONE line: the tafsir carries the surah in
/// the title itself, so a second text row would only cost the reader air.
class MushafContentSheetHeader extends StatelessWidget {
  const MushafContentSheetHeader({
    super.key,
    required this.palette,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.bottom,
  }) : compact = false;

  const MushafContentSheetHeader.compact({
    super.key,
    required this.palette,
    required this.title,
    this.actions = const <Widget>[],
    this.bottom,
  })  : subtitle = null,
        compact = true;

  final MushafPalette palette;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? bottom;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      textAlign: TextAlign.center,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: AppTheme.scaledFontSize(context, compact ? 14 : 16),
        fontWeight: FontWeight.w800,
        height: 1.35,
        color: palette.surfaceText,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: compact ? 8 : 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: Row(
              children: [
                // The title takes the row's free measure and scales down inside
                // it, so a long surah name and the actions always share one
                // line instead of one of them pushing the other out.
                Expanded(
                  child: FittedBox(fit: BoxFit.scaleDown, child: titleText),
                ),
                ...actions,
              ],
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: titleText,
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: palette.surfaceMuted,
                ),
              ),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
            ),
        ],
        if (bottom != null) bottom!,
        Padding(
          padding: EdgeInsets.only(top: compact ? 0 : 2),
          child: Container(height: 1, color: palette.border),
        ),
      ],
    );
  }
}

/// One quiet action in a [MushafContentSheetHeader] row.
class MushafSheetAction extends StatelessWidget {
  const MushafSheetAction({
    super.key,
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final MushafPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    final ink = active
        ? palette.accent
        : palette.surfaceMuted.withValues(alpha: 0.55);
    return TextButton.icon(
      onPressed: active ? onTap : null,
      icon: Icon(icon, size: 16, color: ink),
      label: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// One page-turn control of a [MushafSheetPager]: a glyph above its word, the
/// way a page control is read at a glance.
///
/// Disabling is the only busy signal these sheets ever show — a spinner here
/// would outlive `pumpAndSettle` in every test that opens the sheet, and a
/// page turn is short enough that honest disabled ink is the better answer.
class MushafSheetRailButton extends StatelessWidget {
  const MushafSheetRailButton({
    super.key,
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final MushafPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = onTap != null
        ? palette.accent
        : palette.surfaceMuted.withValues(alpha: 0.45);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(52, 46),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: ink),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10),
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// The running folio of a sheet: «صفحه» over the page number, read as one
/// label by a screen reader.
class MushafSheetFolio extends StatelessWidget {
  const MushafSheetFolio({
    super.key,
    required this.palette,
    required this.page,
    this.dimmed = false,
  });

  final MushafPalette palette;
  final int page;

  /// Drawn quieter while the sheet is turning, in place of any animation.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'صفحهٔ ${NumberFormat.en(page)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'صفحه',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 9),
              fontWeight: FontWeight.w600,
              color: palette.surfaceMuted.withValues(alpha: dimmed ? 0.4 : 0.9),
            ),
          ),
          Text(
            NumberFormat.en(page),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 15),
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: dimmed
                  ? palette.surfaceMuted.withValues(alpha: 0.5)
                  : palette.surfaceText,
            ),
          ),
        ],
      ),
    );
  }
}

/// A sheet's foot: previous page, the folio, next page.
///
/// The arrows keep their reading direction (previous sits at the right of an
/// RTL row, where a book's back page is), and [busy] disables both ends and
/// dims the folio until the incoming page has landed.
class MushafSheetPager extends StatelessWidget {
  const MushafSheetPager({
    super.key,
    required this.palette,
    required this.page,
    required this.onPrevious,
    required this.onNext,
    this.previousLabel = 'صفحهٔ قبلی',
    this.nextLabel = 'صفحهٔ بعدی',
    this.busy = false,
  });

  final MushafPalette palette;
  final int page;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String previousLabel;
  final String nextLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            MushafSheetRailButton(
              palette: palette,
              icon: Icons.arrow_back,
              label: previousLabel,
              onTap: busy ? null : onPrevious,
            ),
            Expanded(
              child: Center(
                child: MushafSheetFolio(
                  palette: palette,
                  page: page,
                  dimmed: busy,
                ),
              ),
            ),
            MushafSheetRailButton(
              palette: palette,
              icon: Icons.arrow_forward,
              label: nextLabel,
              onTap: busy ? null : onNext,
            ),
          ],
        ),
      ),
    );
  }
}
