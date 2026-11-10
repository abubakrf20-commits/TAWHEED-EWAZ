import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';

/// شریط پایین خواننده: صفحهٔ قبل/بعد و نوار پرش.
///
/// Deliberately one row of chrome. The page itself now carries its printed
/// folio, so this bar only has to say where the reader is in the whole book —
/// the old two-row bar (slider row + three labels) ate a quarter of a small
/// phone's height and left the page with no bottom margin at all.
class BookReaderProgressBar extends StatefulWidget {
  final int currentPage;
  final int totalPages;

  /// Printed page label from `BookPage.pageLabel` — «59 / 458» or the plain
  /// index for a book without print markers.
  final String pageLabel;

  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageChanged;

  /// The reader's own paper and ink, so the bar belongs to the page instead
  /// of floating over it in the app's card colour.
  final Color surface;
  final Color ink;

  /// Pages the reader bookmarked, drawn as ticks on the track: a book you are
  /// reading has marks in it, and the bar is the only place that shows the
  /// whole book at once.
  final List<int> bookmarkPages;

  const BookReaderProgressBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.pageLabel,
    required this.onPageChanged,
    required this.surface,
    required this.ink,
    this.bookmarkPages = const [],
    this.onPrev,
    this.onNext,
  });

  @override
  State<BookReaderProgressBar> createState() => _BookReaderProgressBarState();
}

class _BookReaderProgressBarState extends State<BookReaderProgressBar> {
  /// Local thumb position while dragging. The page commit is deferred to
  /// `onChangeEnd`: firing `onPageChanged` on every `onChanged` pixel made the
  /// reader reload the page, re-run the bookmark lookup and autosave dozens of
  /// times per drag.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.totalPages;
    final ink = widget.ink;
    final currentPage = widget.currentPage;
    final progress =
        totalPages > 0 ? (((currentPage + 1) / totalPages) * 100).round() : 0;
    final sliderValue = totalPages > 0
        ? (_dragValue ?? currentPage.clamp(0, totalPages - 1).toDouble())
            .clamp(0.0, (totalPages - 1).toDouble())
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      decoration: BoxDecoration(
        color: widget.surface,
        border:
            Border(top: BorderSide(color: ink.withValues(alpha: 0.12))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_right, size: 22),
              tooltip: 'صفحهٔ قبل',
              visualDensity: VisualDensity.compact,
              // Gated by the reader, not by the page number: a title sheet
              // sits in front of page one, so going back is possible at 0.
              color: widget.onPrev != null ? ink : ink.withValues(alpha: 0.3),
              onPressed: widget.onPrev,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        NumberFormat.ltrIsolated(widget.pageLabel),
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontFamily: AppTheme.fontFamily,
                            color: ink.withValues(alpha: 0.75)),
                      ),
                      Text(
                        '${NumberFormat.ltrIsolated('$progress')}٪',
                        style: TextStyle(
                            fontSize: AppTheme.scaledFontSize(context, 11),
                            fontFamily: AppTheme.fontFamily,
                            color: ink.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 22,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (widget.bookmarkPages.isNotEmpty && totalPages > 1)
                          Positioned.fill(
                            child: Padding(
                              // Matches the thumb radius: the ticks have to
                              // start and end where the track does.
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: CustomPaint(
                                painter: _BookmarkTicks(
                                  pages: widget.bookmarkPages,
                                  totalPages: totalPages,
                                  color: ink.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                          ),
                          child: Slider(
                            value: sliderValue,
                            max: totalPages > 0
                                ? (totalPages - 1).toDouble()
                                : 1,
                            onChanged: (v) => setState(() => _dragValue = v),
                            onChangeEnd: (v) {
                              setState(() => _dragValue = null);
                              widget.onPageChanged(v.round());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_left, size: 22),
              tooltip: 'صفحهٔ بعد',
              visualDensity: VisualDensity.compact,
              color: widget.onNext != null
                  ? ink
                  : ink.withValues(alpha: 0.3),
              onPressed: widget.onNext,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ticks for the reader's bookmarks, drawn on the track.
///
/// A tiny painter instead of a decorated slider: the slider owns its
/// geometry, and a second widget inside it would either fight it or need a
/// custom track shape that also has to keep the drag maths.
class _BookmarkTicks extends CustomPainter {
  const _BookmarkTicks({
    required this.pages,
    required this.totalPages,
    required this.color,
  });

  final List<int> pages;
  final int totalPages;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (totalPages < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final last = (totalPages - 1).toDouble();
    for (final page in pages) {
      final t = page.clamp(0, totalPages - 1) / last;
      final x = t * size.width;
      canvas.drawLine(
        Offset(x, size.height / 2 - 5),
        Offset(x, size.height / 2 + 5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BookmarkTicks old) =>
      old.totalPages != totalPages ||
      old.color != color ||
      old.pages.length != pages.length ||
      !List.generate(pages.length, (i) => old.pages[i] == pages[i])
          .every((same) => same);
}
