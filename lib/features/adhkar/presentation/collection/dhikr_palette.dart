import 'package:flutter/material.dart';

/// The dhikr collections' fixed identity colours.
///
/// They are tokens, not widget literals: the same navy pill, cream label and
/// blue-lilac track appear in the mode selector, the timeline nodes and the
/// focus ring, and three copies of `Color(0xFF243056)` would eventually drift
/// apart. The neutral/gold/success surfaces still come from the theme
/// (`DhikrTone.of`), so a daytime/dark switch keeps working.
class DhikrPalette {
  DhikrPalette._();

  /// Selected segment fill and the count pills' solid button.
  static const Color navy = Color(0xFF243056);

  /// Text printed on [navy].
  static const Color cream = Color(0xFFFCF8EF);

  /// The timeline's unfinished rail and the segmented bar's upcoming cells.
  static const Color railIdle = Color(0xFFC2CFE6);

  /// Upcoming cells of the progress bar (a touch lighter than the rail).
  static const Color segmentIdle = Color(0xFFC9D4EA);

  /// The focus ring's track and the empty part of the counter ring.
  static const Color ringTrack = Color(0xFFDCE4F3);

  /// Partial-count pill fill.
  static const Color goldTint = Color(0xFFFFF6DA);

  /// Arabic block paper, so it reads as a page even on the white card.
  static const Color paper = Color(0xFFFCFAF6);

  /// The collection cards' hairline.
  static const Color hairline = Color(0xFFEADFCC);
}
