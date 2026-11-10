import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/books/data/services/book_highlight_service.dart';
import 'package:tawheeed/features/books/presentation/book_justification.dart';
import 'package:tawheeed/features/books/presentation/book_page_notes.dart';
import 'package:tawheeed/features/books/presentation/book_palette.dart';
import 'package:tawheeed/features/books/presentation/book_page_text.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

/// The page's own type and surface — everything that changes when the reader
/// moves a slider.
class BookReaderPageStyle {
  const BookReaderPageStyle({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.ink,
    required this.sideMargin,
    this.justify = true,
    this.footnoteMode = BookFootnoteMode.markers,
    this.mirrorMargin = false,
    this.gutterOnLeft = false,
  });

  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final Color ink;

  /// Left/right margin of the text column, and the width of the page-turn
  /// strips outside it.
  final double sideMargin;

  /// Set the page justified where it reads well, ragged where it would gap.
  ///
  /// This is the reader's switch, not a promise that every paragraph is
  /// justified: [BookJustification] measures each one and refuses the ones a
  /// stretch would tear apart, so «تراز» never becomes a line of three
  /// scattered words. Turning it off sets the whole page ragged.
  final bool justify;

  /// What the page does with its notes. Three states, not a bool: the notes
  /// can be printed without pointers in the text, and a reader who wants the
  /// page uninterrupted can drop the apparatus entirely.
  final BookFootnoteMode footnoteMode;

  /// حاشیهٔ آینه‌ای: the extra margin a bound book gives the fold side, moved
  /// to the other edge on the next page so the gutter alternates as you turn.
  /// Off by default so the sheet keeps two equal margins — the reader passes
  /// it from the page's own sheet.
  final bool mirrorMargin;

  /// Which side the fold sits on for THIS sheet: `true` puts the extra margin
  /// on the left, `false` on the right. The reader alternates it sheet by
  /// sheet — that is what makes the gutter mirror as you turn.
  /// Only meaningful with [mirrorMargin].
  final bool gutterOnLeft;

  /// How much wider the fold margin is. Small on purpose: a gutter you notice
  /// is a page that looks crooked.
  static const double gutter = 12;

  /// Space between paragraphs — a paper page separates them by air, not by a
  /// blank line that would double the line height.
  double get paragraphGap => fontSize * 0.55;

  /// Chrome size that follows the app's type scale.
  double chromeSize(BuildContext context, double base) =>
      AppTheme.scaledFontSize(context, base);
}

/// One printed page: running head, justified text column, folio.
///
/// The page is deliberately NOT a scrollable sheet of text with chrome around
/// it: the head and the folio stay put while the text scrolls, exactly as a
/// chapter title and a page number would. That is the whole point of the
/// widget — turning the reader into something that reads like a book rather
/// than a long text field.
class BookReaderPage extends StatefulWidget {
  const BookReaderPage({
    super.key,
    required this.page,
    required this.bookTitle,
    required this.style,
    required this.highlights,
    required this.footnotes,
    this.searchQuery = '',
    this.onPrev,
    this.onNext,
    this.selectionMode = false,
    this.selectionController,
    this.onHighlightRange,
  }) : assert(!selectionMode || selectionController != null,
            'selection mode needs the page controller');

  final BookPage page;

  /// Shown in the running head when the page carries no detected heading.
  final String bookTitle;

  final BookReaderPageStyle style;
  final List<BookHighlight> highlights;

  /// The page's own notes, already resolved and numbered from 1 by
  /// [BookPageNotes.of]. The page never re-discovers them: one resolver feeds
  /// both the printed rows and the in-text markers, so the two can never
  /// disagree about which notes exist.
  final List<BookPageNote> footnotes;
  final String searchQuery;

  /// Page-turn strips in the outer margins. `null` disables that side, which
  /// is how the first and last page of a book stay still.
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  /// Highlight mode swaps the selectable paragraphs for one read-only field so
  /// a selection can span paragraphs; the offsets stay in page coordinates.
  final bool selectionMode;
  final TextEditingController? selectionController;

  /// Called with PAGE offsets when the reader picks «هایلایت» from the system
  /// text menu. Without it the page only offers the platform's copy menu.
  final void Function(int start, int end)? onHighlightRange;

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  final Map<int, GlobalKey> _paragraphKeys = {};

  /// One key per printed note, so its marker can bring the eye to the foot
  /// of the page where the note actually is — a real book's apparatus sits
  /// under its own text, not behind a tap.
  ///
  /// Cleared with the paragraph keys: a stale entry would aim a marker at a
  /// widget the page no longer builds.
  final Map<String, GlobalKey> _noteKeys = {};

  /// The justification decision, memoized per paragraph as it is laid out.
  ///
  /// Measuring a paragraph needs one text layout, and these widgets rebuild on
  /// every scroll, selection and search keystroke — so the answer is kept for
  /// as long as the paragraph, the column width and the type stay the same.
  final Map<Object, bool> _justified = {};

  @override
  void initState() {
    super.initState();
    _scheduleRevealFirstMatch();
  }

  @override
  void didUpdateWidget(BookReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.index != widget.page.index ||
        oldWidget.searchQuery != widget.searchQuery) {
      _paragraphKeys.clear();
      _noteKeys.clear();
      _justified.clear();
      _scheduleRevealFirstMatch();
    }
  }

  /// Jumps to the paragraph holding the first hit of the current query.
  ///
  /// Without it the reader lands at the top of a page whose match can be
  /// thirty lines down, so a search «found» words the reader never sees.
  void _scheduleRevealFirstMatch() {
    if (widget.searchQuery.trim().isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _firstMatchKey();
      final ctx = key?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.06,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  GlobalKey? _firstMatchKey() {
    final text = widget.page.text;
    final matches = TextHighlight.findMatches(text, widget.searchQuery);
    if (matches.isEmpty) return null;
    final offset = matches.first.start;
    final paragraphs = BookPageText.paragraphs(text);
    for (var i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      if (offset >= p.start && offset < p.end) return _paragraphKeys[i];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final style = widget.style;
    final heading = (page.heading ?? '').trim();
    // Locals: the null check below does not promote a widget field.
    final onNext = widget.onNext;
    final onPrev = widget.onPrev;
    // Alternating running head, as a printed book sets it: the book's name on
    // one page, the chapter on the next. A page with no detected chapter has
    // nothing to alternate with, so it keeps the title.
    final head = heading.isEmpty
        ? widget.bookTitle
        : (page.index.isEven ? widget.bookTitle : heading);

    return Column(
      children: [
        _buildRunningHead(context, head),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A measure cap: past ~620 dp a justified line becomes so long
              // the eye loses the next line. The extra width becomes margin
              // instead of longer lines.
              //
              // Below the cap the column is left as it falls. The engine breaks
              // Persian at a نیم‌فاصله, so a long compound never overflows the
              // line — the only cost of a narrow column is the stretch
              // justification applies, and that is answered by setting the
              // paragraph ragged ([BookJustification]) rather than by inserting
              // a break character: a page's text is the offset space its stored
              // highlights live in.
              final extra = (constraints.maxWidth - 620) / 2;
              final base =
                  style.sideMargin + (extra > 0 ? extra : 0);
              // The fold margin alternates by sheet, so a book opened flat
              // gives its binding the room it needs on both sides.
              final fold =
                  style.mirrorMargin ? BookReaderPageStyle.gutter : 0.0;
              final left = style.gutterOnLeft ? base + fold : base;
              final right = style.gutterOnLeft ? base : base + fold;
              final contentWidth = constraints.maxWidth - left - right;
              return Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(left, 6, right, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.selectionMode)
                            _buildSelectionField(context)
                          else
                            _buildParagraphs(context, contentWidth),
                          _buildNotes(context, contentWidth),
                        ],
                      ),
                    ),
                  ),
                  // Page-turn strips live in the margins only: the text
                  // column keeps its tap, which is what makes selection work
                  // outside highlight mode. A full-page overlay here used to
                  // swallow every tap on the text.
                  if (onNext != null)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: left,
                      child: _TurnStrip(onTap: onNext),
                    ),
                  if (onPrev != null)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: right,
                      child: _TurnStrip(onTap: onPrev),
                    ),
                ],
              );
            },
          ),
        ),
        _buildFolio(context),
      ],
    );
  }

  Widget _buildRunningHead(BuildContext context, String text) {
    final style = widget.style;
    final fold =
        style.mirrorMargin ? BookReaderPageStyle.gutter : 0.0;
    final left = style.sideMargin + (style.gutterOnLeft ? fold : 0);
    final right = style.sideMargin + (style.gutterOnLeft ? 0 : fold);
    return Padding(
      padding: EdgeInsets.fromLTRB(left, 8, right, 0),
      child: Column(
        children: [
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: style.fontFamily,
              fontSize: style.chromeSize(context, 10),
              height: 1.4,
              letterSpacing: 0.2,
              color: style.ink.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          _Hairline(ink: style.ink),
        ],
      ),
    );
  }

  Widget _buildFolio(BuildContext context) {
    final style = widget.style;
    final fold =
        style.mirrorMargin ? BookReaderPageStyle.gutter : 0.0;
    final left = style.sideMargin + (style.gutterOnLeft ? fold : 0);
    final right = style.sideMargin + (style.gutterOnLeft ? 0 : fold);
    return Padding(
      padding: EdgeInsets.fromLTRB(left, 0, right, 8),
      child: Column(
        children: [
          _Hairline(ink: style.ink),
          const SizedBox(height: 6),
          Text(
            NumberFormat.ltrIsolated(widget.page.pageLabel),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: style.fontFamily,
              fontSize: style.chromeSize(context, 11),
              height: 1.2,
              color: style.ink.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraphs(BuildContext context, double width) {
    final style = widget.style;
    final page = widget.page;
    final text = page.text;
    final paragraphs = BookPageText.paragraphs(text);
    final base = TextStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
      height: style.lineHeight,
      color: style.ink,
    );
    final matches = widget.searchQuery.trim().isEmpty
        ? const <({int start, int end})>[]
        : TextHighlight.findMatches(text, widget.searchQuery);
    final highlightRanges = <({int start, int end, int index})>[
      for (var i = 0; i < widget.highlights.length; i++)
        (
          start: widget.highlights[i].startOffset,
          end: widget.highlights[i].endOffset,
          index: i,
        ),
    ];

    final blocks = <Widget>[];
    final textScaler = MediaQuery.textScalerOf(context);
    for (var i = 0; i < paragraphs.length; i++) {
      final plain = text.substring(paragraphs[i].start, paragraphs[i].end);
      blocks.add(Padding(
        key: _paragraphKeys.putIfAbsent(i, GlobalKey.new),
        padding: EdgeInsets.only(
          bottom: i == paragraphs.length - 1 ? 0 : style.paragraphGap,
        ),
        child: SelectableText.rich(
          TextSpan(
            style: base,
            children: _spansFor(
              context,
              text,
              paragraphs[i].start,
              paragraphs[i].end,
              base,
              matches,
              highlightRanges,
            ),
          ),
          textAlign: _justifiedIn(
            plain: plain,
            width: width,
            style: base,
            textScaler: textScaler,
          )
              ? TextAlign.justify
              : TextAlign.start,
          textDirection: TextDirection.rtl,
          contextMenuBuilder: widget.onHighlightRange == null
              ? null
              : (ctx, editableState) => _selectionMenu(
                    ctx,
                    editableState,
                    paragraphs[i].start,
                  ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }

  /// Whether a block of the page may be set justified, memoized for its inputs.
  ///
  /// The measurement needs one text layout, and these widgets rebuild on every
  /// scroll, selection and search keystroke — so the answer is kept for as long
  /// as the block's text, the column width and the type stay the same.
  bool _justifiedIn({
    required String plain,
    required double width,
    required TextStyle style,
    required TextScaler textScaler,
  }) {
    if (!widget.style.justify) return false;
    final key = (
      plain,
      width,
      style.fontSize,
      style.height,
      style.fontFamily,
      textScaler.scale(1.0),
    );
    return _justified.putIfAbsent(
      key,
      () => BookJustification.accepts(
        text: plain,
        width: width,
        style: style,
        textScaler: textScaler,
        direction: TextDirection.rtl,
      ),
    );
  }

  /// The marker's tap brings its note into view — in a printed book the eye
  /// travels from the marker down to the foot of the page, and the note is
  /// already printed there. The bottom sheet this used to open is gone.
  void _revealNote(String id) {
    final ctx = _noteKeys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.25,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// The page's apparatus: its notes, open under its text behind a short
  /// rule — exactly where a printed book sets them, not behind a tap.
  ///
  /// The list is already resolved and numbered from 1 by [BookPageNotes.of],
  /// so this method prints what is here and never asks the text again: a page
  /// cannot print a note its own text does not point at, and the number the
  /// reader sees is this page's, not the chapter's source id.
  Widget _buildNotes(BuildContext context, double width) {
    final style = widget.style;
    final notes = widget.footnotes;
    if (notes.isEmpty || !style.footnoteMode.printsNotes) {
      return const SizedBox.shrink();
    }
    final noteStyle = TextStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize * 0.85,
      height: style.lineHeight,
      color: style.ink.withValues(alpha: 0.92),
    );
    final rows = <Widget>[];
    final textScaler = MediaQuery.textScalerOf(context);
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final number = NumberFormat.ltrIsolated('${note.displayNumber}.');
      rows.add(Padding(
        key: _noteKeys.putIfAbsent(note.sourceId, GlobalKey.new),
        padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
        child: Text.rich(
          TextSpan(
            style: noteStyle,
            children: [
              TextSpan(
                text: '$number ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: style.ink,
                ),
              ),
              TextSpan(text: note.text),
            ],
          ),
          textAlign: _justifiedIn(
            plain: '$number ${note.text}',
            width: width,
            style: noteStyle,
            textScaler: textScaler,
          )
              ? TextAlign.justify
              : TextAlign.start,
          textDirection: TextDirection.rtl,
        ),
      ));
    }
    return Padding(
      padding: EdgeInsets.only(top: style.paragraphGap * 1.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A short rule at the reading edge: the foot mark a printed page
          // sets above its apparatus — full-column would read as a divider.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 44,
              height: 1,
              color: style.ink.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 7),
          ...rows,
        ],
      ),
    );
  }

  List<InlineSpan> _spansFor(
    BuildContext context,
    String text,
    int start,
    int end,
    TextStyle base,
    List<({int start, int end})> matches,
    List<({int start, int end, int index})> highlights,
  ) {
    final style = widget.style;
    // The number the reader sees is the page's own, resolved once by
    // [BookPageNotes]; the source id only keys the note for a tap.
    // This set — never the book-wide key map — is what [BookPageText.runs]
    // inks, so a marker can never point at a note the page does not print.
    final markers = {
      for (final note in widget.footnotes) note.sourceId: note.displayNumber,
    };
    final runs = BookPageText.runs(
      text: text,
      rangeStart: start,
      rangeEnd: end,
      searchMatches: matches,
      highlights: highlights,
      footnotes: style.footnoteMode.pointsInText
          ? markers.keys.toSet()
          : const {},
    );
    final spans = <InlineSpan>[];
    for (final run in runs) {
      final slice = text.substring(run.start, run.end);
      switch (run.ink) {
        case BookInk.body:
          spans.add(TextSpan(text: slice));
        case BookInk.search:
          spans.add(TextSpan(
            text: slice,
            style: TextStyle(
              backgroundColor: BookPalette.searchWash.withValues(alpha: 0.45),
              color: style.ink,
              fontWeight: FontWeight.w600,
            ),
          ));
        case BookInk.highlight:
          final color = run.highlightIndex >= 0 &&
                  run.highlightIndex < widget.highlights.length
              ? widget.highlights[run.highlightIndex].color
              : BookPalette.searchWash;
          spans.add(TextSpan(
            text: slice,
            style: TextStyle(background: Paint()..color = color.withValues(alpha: 0.3)),
          ));
        case BookInk.footnote:
          final id = slice.replaceAll(RegExp(r'[()]'), '');
          final number = markers[id];
          if (number == null) {
            // Only [BookPageNotes] decides which notes this page carries, so a
            // marker it did not resolve is ordinary text, not a dead pointer.
            spans.add(TextSpan(text: slice));
            break;
          }
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _revealNote(id),
              child: Text(
                NumberFormat.ltrIsolated('$number'),
                style: TextStyle(
                  fontFamily: style.fontFamily,
                  fontSize: style.fontSize * 0.72,
                  height: style.lineHeight,
                  fontWeight: FontWeight.w700,
                  color: style.ink.withValues(alpha: 0.8),
                  decoration: TextDecoration.underline,
                  decorationColor: style.ink.withValues(alpha: 0.35),
                ),
              ),
            ),
          ));
      }
    }
    return spans;
  }

  /// The platform's own text menu plus «هایلایت».
  ///
  /// Highlighting used to need a separate mode, a read-only field and a colour
  /// bar; the reader had to know that. A selection in the page itself now
  /// offers the same colours, and the offsets go back to the reader in PAGE
  /// coordinates because [paragraphStart] is the paragraph's own offset.
  Widget _selectionMenu(
    BuildContext context,
    EditableTextState editableState,
    int paragraphStart,
  ) {
    final selection = editableState.textEditingValue.selection;
    final hasRange = selection.isValid && !selection.isCollapsed;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableState.contextMenuAnchors,
      buttonItems: [
        if (hasRange)
          ContextMenuButtonItem(
            label: 'هایلایت',
            onPressed: () {
              editableState.hideToolbar();
              widget.onHighlightRange!(
                paragraphStart + selection.start,
                paragraphStart + selection.end,
              );
            },
          ),
        ...editableState.contextMenuButtonItems,
      ],
    );
  }

  Widget _buildSelectionField(BuildContext context) {
    final style = widget.style;
    final controller = widget.selectionController;
    final text = widget.page.text;
    if (controller != null && controller.text != text) {
      controller.text = text;
    }
    return Semantics(
      label: 'متن صفحه — برای انتخاب عبارت در حالت هایلایت',
      child: TextField(
        readOnly: true,
        controller: controller,
        showCursor: false,
        enableInteractiveSelection: true,
        // The highlight field is one block for the whole page, not a paragraph
        // per line, so the per-paragraph policy cannot measure it; it follows
        // the switch alone.
        textAlign: style.justify ? TextAlign.justify : TextAlign.start,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          height: style.lineHeight,
          color: style.ink,
        ),
        textDirection: TextDirection.rtl,
        maxLines: null,
      ),
    );
  }
}

/// The page-turn target in a margin. Excluded from semantics on purpose: a
/// full-height invisible button is noise for TalkBack, and the footer already
/// exposes «صفحهٔ قبل/بعد» as real buttons.
class _TurnStrip extends StatelessWidget {
  const _TurnStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: ink.withValues(alpha: 0.10));
  }
}
