import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';

import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';

/// The reader's colour pickers, plus the sheet frame they share.
///
/// ── Why this file exists ────────────────────────────────────────────────────
/// `showModalBottomSheet` dismisses on a downward drag only over a part of
/// itself with no competing vertical-drag recogniser. Every sheet in the reader
/// used to wrap its whole surface in a `SingleChildScrollView`, and that
/// scrollable — being the innermost recogniser in the hit-test path — won the
/// gesture arena every time. A drag down therefore scrolled (and, at offset
/// zero, did nothing at all): the sheet could not be swiped shut, and tapping
/// the scrim was the only way out.
///
/// [_MushafSheetBody] keeps the surface dismissable: while the content fits it
/// installs `NeverScrollableScrollPhysics`, so the scrollable adds no drag
/// recogniser and the sheet's own gesture handler receives the drag. It only
/// claims the gesture when there is genuinely something to scroll — a tall
/// palette in landscape, or a large in-app font scale — and it re-evaluates
/// that on every metrics change, so rotating mid-sheet recovers the drag.

/// The sheet frame: drag handle, title, and a body that can always be swiped
/// away.
Future<T?> showMushafSheet<T>({
  required BuildContext context,
  required MushafPalette palette,
  required String title,
  String? subtitle,
  double maxHeightRatio = 0.85,
  // The body is built with the *sheet's* context, so a swatch can pop the
  // sheet without having to be handed the navigator from outside — popping
  // with the caller's context would close the reader instead.
  required Widget Function(BuildContext sheetContext) contentBuilder,
  /// Pinned below the scrolling body, inside the sheet's own SafeArea. Use it
  /// for chrome that must never scroll out of reach (a sheet's close button,
  /// say): a taller body scrolls, the footer stays put.
  Widget? footer,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: palette.surface,
    isScrollControlled: true,
    useSafeArea: true,
    // The drag handle is drawn by [_MushafSheetBody] rather than by
    // `showDragHandle`, for two reasons: the built-in handle is painted with the
    // *app* theme's colour (unreadable on the night palette's dark surface),
    // and it must sit outside the scrollable to stay draggable when the body
    // does need to scroll. The route's own drag handling (`enableDrag`, on by
    // default) is what actually dismisses.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * maxHeightRatio,
    ),
    builder: (sheetContext) => _MushafSheetBody(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      handleColor: palette.surfaceText.withValues(alpha: 0.28),
      footer: footer,
      children: [
        _SheetTitle(title: title, subtitle: subtitle, palette: palette),
        contentBuilder(sheetContext),
      ],
    ),
  );
}

/// Picks a page background.
///
/// The picker hands every tap to [onPick] immediately and **stays open** —
/// that is what makes the full-page preview live. Closing the sheet is a
/// plain dismissal (swipe it down, tap the scrim), not a commit: by the time
/// it closes the choice has already been painted and saved.
Future<void> showMushafBackgroundPicker({
  required BuildContext context,
  required MushafPalette palette,
  required Color selected,
  required Color recitationColor,
  required ValueChanged<Color> onPick,
}) {
  return showMushafSheet<void>(
    context: context,
    palette: palette,
    title: 'رنگ پس‌زمینهٔ صفحه',
    subtitle: '۲۲ کاغذ، هیچ‌کدام تکراری',
    contentBuilder: (sheet) => MushafBackgroundPickerContent(
      palette: palette,
      selectedIndex: mushafNearestBackgroundIndexOf(selected),
      recitationColor: recitationColor,
      onPick: (index) => onPick(kMushafBackgrounds[index].color),
    ),
  );
}

/// Picks the colour of the ayah being recited. Same contract as
/// [showMushafBackgroundPicker]: live preview, applied on every tap, closed by
/// dismissal.
Future<void> showMushafRecitationColorPicker({
  required BuildContext context,
  required MushafPalette palette,
  required Color selected,
  required Color pageBackground,
  required ValueChanged<Color> onPick,
}) {
  return showMushafSheet<void>(
    context: context,
    palette: palette,
    title: 'رنگ آیهٔ در حال تلاوت',
    subtitle: '۱۸ رنگ، روی کاغذ کنونی برای خواندن تنظیم می‌شود',
    contentBuilder: (sheet) => MushafRecitationPickerContent(
      palette: palette,
      selectedIndex: mushafNearestRecitationIndexOf(selected),
      pageBackground: pageBackground,
      onPick: (index) => onPick(kMushafRecitationColors[index].color),
    ),
  );
}

/// The background swatch grid, grouped exactly the way the palette is ordered:
/// light papers first, dark papers after, with a live full-page preview on
/// top. Exported so the reader can reuse it anywhere a page colour is offered.
///
/// Stateful on purpose: a tap moves the selection and repaints the preview
/// **without closing the sheet**, which is the point — the reader can walk the
/// papers against one fixed page instead of closing, looking, and reopening.
/// The tap is also handed to [onPick] straight away, so the page behind the
/// sheet is already painted with it.
class MushafBackgroundPickerContent extends StatefulWidget {
  const MushafBackgroundPickerContent({
    super.key,
    required this.palette,
    required this.selectedIndex,
    required this.recitationColor,
    required this.onPick,
  });

  final MushafPalette palette;
  final int selectedIndex;

  /// The reader's recited-ayah colour. The preview has to show a *finished*
  /// page, and the highlight on that page is this colour — not a placeholder.
  final Color recitationColor;

  /// Global palette index, applied and persisted immediately.
  final ValueChanged<int> onPick;

  @override
  State<MushafBackgroundPickerContent> createState() =>
      _MushafBackgroundPickerContentState();
}

class _MushafBackgroundPickerContentState
    extends State<MushafBackgroundPickerContent> {
  late int _index =
      widget.selectedIndex.clamp(0, kMushafBackgrounds.length - 1);

  void _pick(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    widget.onPick(index);
  }

  @override
  Widget build(BuildContext context) {
    final day = kMushafBackgrounds.take(kMushafDayBackgroundCount).toList();
    final night = kMushafBackgrounds.skip(kMushafDayBackgroundCount).toList();
    final paper = kMushafBackgrounds[_index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MushafPagePreview(
          palette: widget.palette,
          background: paper.color,
          recitationColor: widget.recitationColor,
          caption: 'پیش‌نمایش روی «${paper.name}»',
        ),
        const SizedBox(height: 8),
        _SwatchGroup(
          palette: widget.palette,
          caption: 'کاغذ روشن',
          colors: day.map((b) => b.color).toList(),
          names: day.map((b) => b.name).toList(),
          selectedIndex: _index,
          // The keys are global palette indices so a test can address a swatch
          // without knowing how the list is split for display.
          indexOffset: 0,
          keyPrefix: 'bg_color_swatch',
          onPick: _pick,
        ),
        const SizedBox(height: 8),
        _SwatchGroup(
          palette: widget.palette,
          caption: 'کاغذ تیره',
          colors: night.map((b) => b.color).toList(),
          names: night.map((b) => b.name).toList(),
          selectedIndex: _index,
          indexOffset: kMushafDayBackgroundCount,
          keyPrefix: 'bg_color_swatch',
          onPick: _pick,
        ),
        const SizedBox(height: 6),
        _SelectedName(palette: widget.palette, text: paper.name),
        const SizedBox(height: 2),
        _ApplyHint(palette: widget.palette),
      ],
    );
  }
}

/// The recited-ayah swatch grid, with the same live full-page preview.
class MushafRecitationPickerContent extends StatefulWidget {
  const MushafRecitationPickerContent({
    super.key,
    required this.palette,
    required this.selectedIndex,
    required this.pageBackground,
    required this.onPick,
  });

  final MushafPalette palette;
  final int selectedIndex;
  final Color pageBackground;

  /// Global palette index, applied and persisted immediately.
  final ValueChanged<int> onPick;

  @override
  State<MushafRecitationPickerContent> createState() =>
      _MushafRecitationPickerContentState();
}

class _MushafRecitationPickerContentState
    extends State<MushafRecitationPickerContent> {
  late int _index =
      widget.selectedIndex.clamp(0, kMushafRecitationColors.length - 1);

  void _pick(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    widget.onPick(index);
  }

  @override
  Widget build(BuildContext context) {
    final pick = kMushafRecitationColors[_index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Painting the pick on the reader's own page is the whole point: the
        // swatch shows the hue, the page shows it at reading contrast — as a
        // marker band on one ayah and as the recited ayah's own ink on another.
        MushafPagePreview(
          palette: widget.palette,
          background: widget.pageBackground,
          recitationColor: pick.color,
          caption: 'پیش‌نمایش «${pick.name}»',
        ),
        const SizedBox(height: 8),
        _SwatchGroup(
          palette: widget.palette,
          colors: kMushafRecitationColors.map((c) => c.color).toList(),
          names: kMushafRecitationColors.map((c) => c.name).toList(),
          selectedIndex: _index,
          indexOffset: 0,
          keyPrefix: 'recitation_color_swatch',
          onPick: _pick,
        ),
        const SizedBox(height: 6),
        _SelectedName(palette: widget.palette, text: pick.name),
        const SizedBox(height: 2),
        _ApplyHint(palette: widget.palette),
      ],
    );
  }
}

/// A wrap of round colour swatches, optionally captioned.
///
/// Also used for the per-ayah marker colours, which share the recited-ayah
/// palette — one grid, so a swatch can never mean one thing in one sheet and
/// something else in another.
class MushafSwatchGroup extends StatelessWidget {
  const MushafSwatchGroup({
    super.key,
    required this.palette,
    required this.colors,
    required this.names,
    required this.selected,
    required this.keyPrefix,
    required this.onPick,
    this.caption,
  });

  final MushafPalette palette;
  final List<Color> colors;
  final List<String> names;
  final Color? selected;
  final String keyPrefix;
  final ValueChanged<int> onPick;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexOfExact(colors, selected);
    return _SwatchGroup(
      palette: palette,
      caption: caption,
      colors: colors,
      names: names,
      selectedIndex: selectedIndex,
      indexOffset: 0,
      keyPrefix: keyPrefix,
      onPick: onPick,
    );
  }
}

int _indexOfExact(List<Color> colors, Color? selected) {
  if (selected == null) return -1;
  for (var i = 0; i < colors.length; i++) {
    if (colors[i].toARGB32() == selected.toARGB32()) return i;
  }
  return -1;
}

class _SwatchGroup extends StatelessWidget {
  const _SwatchGroup({
    required this.palette,
    required this.colors,
    required this.names,
    required this.selectedIndex,
    required this.indexOffset,
    required this.keyPrefix,
    required this.onPick,
    this.caption,
  });

  final MushafPalette palette;
  final List<Color> colors;
  final List<String> names;

  /// Selection in *global* palette coordinates, or -1.
  final int selectedIndex;

  /// Added to a local swatch index to address it in global palette
  /// coordinates — used both for the swatch key and for the index handed to
  /// [onPick], which speaks global indices (the background picker splits a
  /// single palette into two groups, so a local index would resolve to the
  /// wrong colour in the second one).
  final int indexOffset;

  final String keyPrefix;
  final ValueChanged<int> onPick;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              caption!,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.surfaceMuted,
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Swatch size adapts to the width so a 25-colour palette stays a
            // handful of rows on a phone instead of turning the sheet into a
            // scrolling list — which is also what keeps the sheet
            // drag-dismissable (see the file comment).
            const spacing = 12.0;
            const columns = 6;
            final size =
                ((constraints.maxWidth - (columns - 1) * spacing) / columns)
                    .clamp(34.0, 50.0);
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < colors.length; i++)
                  _Swatch(
                    key: ValueKey('${keyPrefix}_${i + indexOffset}'),
                    color: colors[i],
                    name: names[i],
                    palette: palette,
                    size: size,
                    selected: i + indexOffset == selectedIndex,
                    // The offset is applied to the *pick* as well as to the
                    // key: the night group of the background picker is the
                    // tail of [kMushafBackgrounds], and its callback indexes
                    // the whole palette. Reporting the bare local index made
                    // every dark paper paint the day paper of the same slot,
                    // which is why «کاغذ تیره» could not be selected.
                    onPick: () => onPick(i + indexOffset),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.name,
    required this.palette,
    required this.size,
    required this.selected,
    required this.onPick,
  });

  final Color color;
  final String name;
  final MushafPalette palette;
  final double size;
  final bool selected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    // A swatch whose own colour is close to the sheet surface would otherwise
    // read as an empty hole; a hairline keeps its edge visible either way.
    final edge =
        mushafContrastRatio(color, palette.surface) < 1.25 ? 0.55 : 0.25;
    return Semantics(
      label: name,
      button: true,
      selected: selected,
      child: Tooltip(
        message: name,
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          onTap: onPick,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? palette.accent
                    : palette.surfaceText.withValues(alpha: edge),
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: size * 0.45,
                    color: mushafContrastRatio(color, palette.accent) >= 3
                        ? palette.accent
                        : (mushafNeedsLightInk(color)
                            ? kMushafCreamInk
                            : kMushafDarkInk),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

// ── The live page preview ───────────────────────────────────────────────────

/// Height of the mini page. Deliberately small: the picker still has to fit the
/// 640dp phones the reader uses *without* its body becoming a scrollable, or
/// the sheet stops being drag-dismissable (see the file comment) — and it has
/// to leave room for 22 swatches below it.
const double _kPreviewHeight = 116;

/// Six short lines, so the mini page reads as a mushaf page rather than a
/// colour chip with one line of text on it.
const List<String> _kPreviewLines = [
  'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
  'الرَّحْمَٰنِ الرَّحِيمِ',
  'مَالِكِ يَوْمِ الدِّينِ',
  'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
  'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
  'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ',
];

/// The line carrying the *saved-marker* band, and the line carrying the ayah
/// being *recited* — the two things a colour choice changes on a real page.
const int _kPreviewBandLine = 2;
const int _kPreviewRecitedLine = 4;

/// A miniature of a real mushaf page: the paper, both inks, the saved-marker
/// band and the recited ayah's wash — painted with the very maths the reader
/// uses ([mushafPageInk], [mushafRecitationInkOn], [mushafAyahBandOn],
/// [mushafLiveAyahWashOn]).
///
/// A swatch shows a colour; only a page shows what that colour does to a page.
/// That is why the pickers keep this on screen while the reader walks the
/// grid: the ayah marker and the recited ink are the two places a pick can
/// fail, and they are both on this thumbnail.
class MushafPagePreview extends StatelessWidget {
  const MushafPagePreview({
    super.key,
    required this.palette,
    required this.background,
    required this.recitationColor,
    this.caption,
  });

  final MushafPalette palette;

  /// The paper the page is painted on — the pick the reader is hovering.
  final Color background;

  /// The recited-ayah colour, painted on that paper.
  final Color recitationColor;

  /// Names the pair being previewed. Without it the reader has to hunt the
  /// selection ring in the grid to know what they are looking at.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final ink = mushafPageInk(background);
    final recitedInk = mushafRecitationInkOn(background, recitationColor);
    final wash = mushafLiveAyahWashOn(background, recitedInk);
    final band = mushafAyahBandOn(background, recitationColor);
    // The read page picks its verse marker from the same day/night split (see
    // `quran_mushaf_view_build.dart`), so the thumbnail does too.
    final marker = mushafNeedsLightInk(background)
        ? const Color(0xFFC9965C)
        : const Color(0xFF7A4A21);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _kPreviewHeight * 0.72,
          height: _kPreviewHeight,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(9),
            border:
                Border.all(color: palette.surfaceText.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The surah banner the real page opens with.
              Container(
                height: 12,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: marker.withValues(alpha: 0.5)),
                ),
                child: _previewText('سُورَةُ الْفَاتِحَة', marker, 6.5),
              ),
              const SizedBox(height: 3),
              for (var i = 0; i < _kPreviewLines.length; i++)
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    // The marker band and the recited wash, exactly as the
                    // page paints them — pre-composited over the paper.
                    color: i == _kPreviewBandLine
                        ? band
                        : (i == _kPreviewRecitedLine ? wash : null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      // scaleDown, never ellipsis: a clipped line would make
                      // the preview lie about the page.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _previewText(
                          _kPreviewLines[i],
                          i == _kPreviewRecitedLine ? recitedInk : ink,
                          i == _kPreviewRecitedLine ? 8 : 7.2,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              _previewText('١', ink.withValues(alpha: 0.55), 6),
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 10.0),
              color: palette.surfaceText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

Text _previewText(String text, Color color, double size) => Text(
      text,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: 'Amiri',
        fontSize: size,
        height: 1.25,
        color: color,
      ),
    );

/// Says out loud what the pickers do, since there is no confirm button to
/// explain the interaction: a tap is not a *preview* of a choice, it *is* the
/// choice — the page behind the sheet is already painted with it.
class _ApplyHint extends StatelessWidget {
  const _ApplyHint({required this.palette});

  final MushafPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      'هر رنگی که بزنی همان لحظه روی صفحه اعمال می‌شود',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 10,
        height: 1.3,
        color: palette.surfaceMuted,
      ),
    );
  }
}

/// One row of a mushaf settings sheet: an icon, a label, and the current value
/// spelled out underneath. The value line is the point — a settings sheet that
/// only lists the names of things makes the reader close it to see what is
/// actually set, which is awkward when the sheet covers the page being set.
class MushafSettingRow extends StatelessWidget {
  const MushafSettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.palette,
    required this.onTap,
    this.leading,
    this.trailing,
  });

  /// Optional widget in front of the icon — the reading-settings sheet puts
  /// the current colour swatch there so the pick is visible without opening
  /// the picker.
  final Widget? leading;

  /// Optional widget replacing the chevron — the page-turn picker puts the
  /// selected mode's tick there, because those rows apply in place instead
  /// of opening another sheet.
  final Widget? trailing;

  final IconData icon;
  final String title;
  final String value;
  final MushafPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // Dense on purpose: the whole settings sheet has to fit the 640dp-tall
      // phones it is used on, or the last row lands below the fold and a
      // downward drag scrolls the sheet instead of dismissing it.
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!],
          // The kit's duotone tile, not a bare accent icon (report §6.2):
          // this was the last mushaf list whose leading was not the shared
          // recipe, so the settings sheet looked like a different app.
          DuotoneIconTile(accent: palette.accent, icon: icon),
        ],
      ),
      title: Text(
        title,
        style: TextStyle(
            fontFamily: AppTheme.fontFamily, color: palette.surfaceText),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          color: palette.surfaceMuted,
        ),
      ),
      trailing:
          trailing ?? Icon(Icons.chevron_left, color: palette.surfaceMuted),
      onTap: onTap,
    );
  }
}

class _SelectedName extends StatelessWidget {
  const _SelectedName({required this.palette, required this.text});

  final MushafPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      'انتخاب‌شده: $text',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: palette.surfaceText,
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({
    required this.title,
    required this.subtitle,
    required this.palette,
  });

  final String title;
  final String? subtitle;
  final MushafPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.surfaceText,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: palette.surfaceMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The sheet's surface: a drag handle, then a body that scrolls only when it
/// has to.
///
/// The scrollable is the only thing that can stop the modal sheet above from
/// being swiped away — it sits deeper in the tree, so it wins the gesture arena
/// for any vertical drag over it. It therefore must not exist, as far as the
/// gesture system is concerned, unless there is something to scroll. The body
/// measures itself (`maxScrollExtent`) and installs
/// [NeverScrollableScrollPhysics] while it fits, which makes its scrollable
/// register no drag recogniser at all, so the sheet receives the drag.
///
/// `shrinkWrap: true` matters as much: without it the viewport would expand to
/// the full height cap, so every sheet would be a tall panel with the content
/// jammed at the top — which is what made the old pickers look half empty.
class _MushafSheetBody extends StatefulWidget {
  const _MushafSheetBody({
    required this.children,
    required this.padding,
    required this.handleColor,
    this.footer,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final Color handleColor;

  /// Rendered after the scrolling list, pinned to the bottom.
  final Widget? footer;

  @override
  State<_MushafSheetBody> createState() => _MushafSheetBodyState();
}

class _MushafSheetBodyState extends State<_MushafSheetBody> {
  bool _overflows = false;

  void _onMetrics(ScrollMetricsNotification notification) {
    final overflows = notification.metrics.maxScrollExtent > 0.5;
    if (overflows == _overflows) return;
    // The notification can arrive while the tree is still being laid out, so
    // the flip waits for the frame to finish.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && overflows != _overflows) {
        setState(() => _overflows = overflows);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Flexible so the list is offered only the space left under the
          // handle; `shrinkWrap` then keeps it exactly as tall as its content
          // when that fits.
          Flexible(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) {
                _onMetrics(notification);
                return false;
              },
              child: ListView(
                shrinkWrap: true,
                physics: _overflows
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: widget.padding,
                children: widget.children,
              ),
            ),
          ),
          if (widget.footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: widget.footer,
            ),
        ],
      ),
    );
  }
}

/// A bottom-sheet body that scrolls only when it has to.
///
/// Drop-in for `SingleChildScrollView` inside a modal bottom sheet. While the
/// content fits it installs [NeverScrollableScrollPhysics], so the scrollable
/// registers no drag recogniser at all and a downward drag reaches the sheet and
/// dismisses it — which a plain scroll view never allows, because it is the
/// innermost recogniser in the hit-test path and therefore wins the arena even
/// when it has nowhere to scroll.
///
/// It re-measures on every [ScrollMetricsNotification], so rotating the device,
/// changing the in-app font scale, or the content growing past the fold flips it
/// the other way without rebuilding the sheet.
class MushafSheetScroll extends StatefulWidget {
  const MushafSheetScroll({super.key, required this.child, this.padding});

  final Widget child;

  /// Padding to hand to the scroll view; `null` keeps the default.
  final EdgeInsetsGeometry? padding;

  @override
  State<MushafSheetScroll> createState() => _MushafSheetScrollState();
}

class _MushafSheetScrollState extends State<MushafSheetScroll> {
  bool _overflows = false;

  void _onMetrics(ScrollMetricsNotification notification) {
    final overflows = notification.metrics.maxScrollExtent > 0.5;
    if (overflows == _overflows) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && overflows != _overflows) {
        setState(() => _overflows = overflows);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _onMetrics(notification);
        return false;
      },
      child: SingleChildScrollView(
        padding: widget.padding,
        physics: _overflows
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}

/// A sheet-body *list* that only claims vertical drags while it has somewhere
/// to scroll.
///
/// The modal sheet dismisses on a downward drag only if no deeper scrollable
/// wins the gesture arena first, and a `ListView` always registers a vertical
/// drag recogniser — even when its content fits and there is nowhere to go. A
/// sheet whose body is a plain list could therefore never be swiped shut and
/// only the scrim would close it.
///
/// This is the list counterpart of [MushafSheetScroll]: while
/// `maxScrollExtent` is zero it hands the list [NeverScrollableScrollPhysics],
/// so the scrollable registers no drag recogniser and the drag reaches the
/// sheet; the moment the content genuinely overflows it switches to clamping
/// and the list scrolls again. It re-checks on every metrics change, so
/// rotating the device or a list that grows or shrinks flips it back without
/// any rebuild from outside.
///
/// It *is* the scrollable, so the caller supplies the builder and uses the
/// physics it is handed:
/// ```dart
/// MushafSheetScrollable(
///   builder: (context, physics) =>
///       ListView(physics: physics, children: const [...]),
/// )
/// ```
class MushafSheetScrollable extends StatefulWidget {
  const MushafSheetScrollable({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollPhysics physics) builder;

  @override
  State<MushafSheetScrollable> createState() => _MushafSheetScrollableState();
}

class _MushafSheetScrollableState extends State<MushafSheetScrollable> {
  bool _overflows = false;

  void _onMetrics(ScrollMetricsNotification notification) {
    final overflows = notification.metrics.maxScrollExtent > 0.5;
    if (overflows == _overflows) return;
    // The notification can arrive mid-layout, so the flip waits for the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && overflows != _overflows) {
        setState(() => _overflows = overflows);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _onMetrics(notification);
        return false;
      },
      child: widget.builder(
        context,
        _overflows
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
      ),
    );
  }
}
