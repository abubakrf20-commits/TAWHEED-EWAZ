// Ayah action sheet (spec D) — the sheet a long-press or a tap opens.
//
//   title «سورهٔ X — آیةٔ N» + chips (صفحه / جزء / مکی‌مدنیه)
//   ONE row of six icon tiles (reader request, 2026-10-13)
//   a SECOND row of the same tiles: share + note (user request)
//
// Every action keeps its previous behaviour; the layout is what changed. The
// six actions used to sit in three two-cell rows, which left each glyph small
// and made the sheet tall; one line shows them all at once and the tiles grew
// with it (40 → 48 dp). Sharing and noting then moved off their full-width
// subtitled rows onto that same 48 dp cell, so the whole sheet reads as one
// icon system. A cell's visible text is therefore one word, scaled down
// rather than wrapped, while `semanticLabel` keeps the full wording for
// screen readers. The cells wear the app's shared duotone icon tile — the
// same squircle «بیشتر» draws on every item — so the options read as one icon
// system with the rest of the app instead of a local gradient recipe.

part of 'quran_mushaf_view.dart';

/// One action cell: a duotone icon tile over a one-line label, exactly the shape
/// «بیشتر» puts on its grid items.
///
/// Six of these share the sheet's width, so the label is a single line that
/// scales down instead of wrapping, and the tile asks for 48 dp — clamped to
/// the cell on the narrowest supported width (320 dp), where six 48 dp cells do
/// not fit. A cell can therefore never overflow its column.
class _AyahActionTile extends StatelessWidget {
  const _AyahActionTile({
    required this.icon,
    required this.label,
    required this.tone,
    required this.palette,
    required this.onTap,
    this.semanticLabel,
  });

  /// The tile side the six-cell row asks for — 20 % up from the old 40 dp grid.
  static const double preferredSide = 48;

  final IconData icon;

  /// The cell's visible text: one word, because six cells share the sheet.
  final String label;

  /// Full wording for screen readers when [label] is the shortened cell text.
  final String? semanticLabel;

  /// Accent colour the tile is derived from (duotone fill, glyph, border).
  final Color tone;

  /// The sheet's palette — the label ink follows the surface it is drawn on
  /// (cream paper vs the night sheet), which the tile itself cannot know.
  final MushafPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep the squircle square: on a 320 dp phone the six cells take
                // the whole width, so the requested 48 dp would be clipped into a
                // 44×48 rectangle by DuotoneIconTile's tight constraints.
                final side = constraints.maxWidth < preferredSide
                    ? constraints.maxWidth
                    : preferredSide;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DuotoneIconTile(accent: tone, icon: icon, size: side),
                    const SizedBox(height: 6),
                    // One line, scaled down rather than wrapped: a two-line
                    // label would push this cell taller than its neighbours.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 11),
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: palette.surfaceText,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Small identity chip in the ayah sheet's title row (صفحه / جزء / مکیّه).
class _VerseChip extends StatelessWidget {
  const _VerseChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 10),
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// The note writer for one ayah (report §7.4).
///
/// It owns its [TextEditingController]. A controller built by the caller and
/// disposed the moment `showDialog` returns trips the framework's "used after
/// being disposed" assert — the dialog is still animating out and rebuilding at
/// that point — so the controller lives exactly as long as the route does.
///
/// Pops `null` when the reader cancels, and the text (possibly empty, which
/// means "clear the note but keep the bookmark") when they save.
class _VerseNoteDialog extends StatefulWidget {
  const _VerseNoteDialog({required this.palette, required this.existingNote});

  final MushafPalette palette;

  /// The note already stored on this ayah's bookmark, if any.
  final String? existingNote;

  @override
  State<_VerseNoteDialog> createState() => _VerseNoteDialogState();
}

class _VerseNoteDialogState extends State<_VerseNoteDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.existingNote ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'یادداشت آیه',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 15),
          fontWeight: FontWeight.w700,
          color: palette.surfaceText,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: 300,
        textDirection: TextDirection.rtl,
        cursorColor: palette.accent,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 13),
          height: 1.6,
          color: palette.surfaceText,
        ),
        decoration: InputDecoration(
          hintText: 'یادداشت شما برای این آیه…',
          hintStyle: TextStyle(color: palette.surfaceMuted),
          helperText: 'همراه نشان این آیه ذخیره می‌شود',
          helperStyle: TextStyle(color: palette.surfaceMuted),
          counterStyle: TextStyle(color: palette.surfaceMuted),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.accent),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('لغو', style: TextStyle(color: palette.surfaceMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text('ذخیره', style: TextStyle(color: palette.accent)),
        ),
      ],
    );
  }
}
