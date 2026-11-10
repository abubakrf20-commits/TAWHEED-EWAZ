import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The counter ring's beads and arc are drawn by a `CustomPainter`, and the two
/// stat pills are private widgets, so neither has a widget seam a colour can be
/// asserted through. This source guard stands in for one.
///
/// What it protects:
///  * the ring and the count wear the *tasbih section's* amber
///    (`SectionHues.tasbih`) — the same hue the «تسبیح سریع» pill and the
///    section header use — and never the pale `AppPalette.heroGold` they used
///    to, which read as generic chrome beside the page's colored pills;
///  * the bead track stays two-tone (a lit run up to the count, a faint rest)
///    and the travelled arc keeps warming from its tail to its tip;
///  * the stat pills wear the «تسبیح سریع» pill's recipe — fully rounded,
///    hue-tinted, hue-bordered — and the two of them do not both wear the
///    section amber that the toggle between them owns.
void main() {
  final source = File('lib/features/adhkar/tasbih/presentation/widgets/'
          'tasbih_counter_widget.dart')
      .readAsStringSync();

  /// The text between [start] and [end], so an assertion can be scoped to one
  /// widget instead of the whole file (the completion badge still legitimately
  /// paints a gold button).
  String region(String start, String end) {
    final from = source.indexOf(start);
    final to = source.indexOf(end);
    expect(from, isNonNegative, reason: '«$start» moved — re-point this guard');
    expect(to, greaterThan(from), reason: '「$end」 moved — re-point this guard');
    return source.substring(from, to);
  }

  test('the ring and the count wear the section amber, never the hero gold', () {
    final circle = region('class _BeadCounterCircle', 'class _BeadRingPainter');
    expect(circle.contains('SectionHues.tasbih'), isTrue,
        reason: 'the ring is painted from the section hue');
    expect(circle.contains('dsContentColor(context, hue)'), isTrue,
        reason: 'the count uses the app\'s readable-hue derivation');
    expect(circle.contains('heroGold'), isFalse,
        reason: 'the pale hero gold is what the section amber replaced');

    final painter = region('class _BeadRingPainter', 'class _QuickModePill');
    expect(painter.contains('heroGold'), isFalse);
    expect(painter.contains('litCount'), isTrue,
        reason: 'the bead track is lit up to the count, faint after it');
    expect(painter.contains('SweepGradient'), isTrue,
        reason: 'the arc warms from its tail (deep) to its tip (accent)');
  });

  test('the stat pills wear the quick-tasbih recipe in their own hues', () {
    final pills = region('class _MiniStatBox', 'class _ActionButton');
    expect(pills.contains('BorderRadius.circular(20)'), isTrue,
        reason: 'fully rounded, like the «تسبیح سریع» pill');
    expect(pills.contains('dsContentColor(context, hue)'), isTrue,
        reason: 'the pill\'s ink is the hue itself, not the page\'s text colour');
    expect(pills.contains('t.card'), isFalse,
        reason: 'a card fill under a hue border is how the two looked before');

    final page = region(
        "label: 'هدف روزانه'", 'const SizedBox(height: DsSpacing.gap)');
    expect(page.contains('hue: AppPalette.emerald'), isTrue,
        reason: 'the day box keeps its emerald');
    expect(page.contains('hue: SectionHues.calendar'), isTrue,
        reason: 'the week box takes a hue of its own, not a third amber');
  });
}
