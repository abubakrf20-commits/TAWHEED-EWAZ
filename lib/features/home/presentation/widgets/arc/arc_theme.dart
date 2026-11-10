import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/time_theme.dart';

/// The arc's own palette, resolved once per build.
///
/// These are the arc's tokens — the hero's existing ones (gold, cream, the
/// dark hero field) plus the few the three styles add (the sky gradient stops
/// and the nine interval colours). The defaults live here and nowhere else, so
/// no painter carries a hex of its own. Light surfaces get darker, higher
/// contrast variants of the same hues rather than the dark card's glow.
@immutable
class ArcTheme {
  const ArcTheme({
    required this.isDark,
    required this.track,
    required this.passed,
    required this.label,
    required this.labelDim,
    required this.timeLabel,
    required this.timePassed,
    required this.markerFill,
    required this.derivedFill,
    required this.markerStroke,
    required this.orbFill,
    required this.orbRing,
    required this.nextRing,
    required this.segmentColors,
    required this.skyStops,
    required this.starColor,
    required this.domeTop,
    required this.horizon,
  });

  final bool isDark;

  /// The unpassed arc body.
  final Color track;

  /// The part of the day already behind the reader.
  final Color passed;

  final Color label;
  final Color labelDim;
  final Color timeLabel;
  final Color timePassed;

  /// Prayer marker fill when upcoming, and the derived (diamond) fill.
  final Color markerFill;
  final Color derivedFill;

  /// The 2dp outline that separates a marker from the arc.
  final Color markerStroke;

  final Color orbFill;
  final Color orbRing;
  final Color nextRing;

  /// Style 3's nine intervals: Fajr→Sunrise … LastThird→NextFajr.
  final List<Color> segmentColors;

  /// Style 2's horizontal gradient along the arc.
  final List<Color> skyStops;

  final Color starColor;
  final Color domeTop;
  final Color horizon;

  static const Color _skyA = Color(0xFFA99BFF);
  static const Color _skyB = Color(0xFFF6D98B);
  static const Color _skyC = Color(0xFFF3C14B);
  static const Color _skyD = Color(0xFFF08A4B);
  static const Color _skyE = Color(0xFF7B8CFF);
  static const Color _skyF = Color(0xFF5E73E8);

  static const List<Color> _segments = [
    Color(0xFFA99BFF),
    Color(0xFFF6D98B),
    Color(0xFFF3C14B),
    Color(0xFFF0A63A),
    Color(0xFFEE8A3C),
    Color(0xFFE5604A),
    Color(0xFF7B8CFF),
    Color(0xFF5E73E8),
    Color(0xFF8FB3F5),
  ];

  static const List<Color> _skyStopColors = [
    _skyA,
    _skyB,
    _skyC,
    _skyD,
    _skyE,
    _skyF,
  ];

  static const Color _diamond = Color(0xFFC9D6F2);

  factory ArcTheme.of(BuildContext context) =>
      ArcTheme.resolve(Theme.of(context).brightness == Brightness.dark);

  /// The dark card is the arc's home: the hero is always the dark field, in
  /// both app themes. [isDark] selects the contrast of the ink on it, which is
  /// what the light-theme variant changes.
  factory ArcTheme.resolve(bool isDark) {
    const gold = AppPalette.heroGold;
    return ArcTheme(
      isDark: isDark,
      track: Colors.white.withValues(alpha: isDark ? .18 : .30),
      passed: gold,
      label: isDark ? const Color(0xFFE9EEFB) : const Color(0xFFF4F7FF),
      labelDim: isDark ? const Color(0xFFB8C6E6) : const Color(0xFFD5DEF2),
      timeLabel: isDark ? const Color(0xFFB8C6E6) : const Color(0xFFD5DEF2),
      timePassed: isDark ? const Color(0xFFD9C27A) : const Color(0xFFEBD79B),
      markerFill: const Color(0xE6FFFFFF),
      derivedFill: _diamond,
      markerStroke: const Color(0xFF1B2233),
      orbFill: const Color(0xFF1B2233),
      orbRing: gold,
      nextRing: gold,
      segmentColors: isDark ? _segments : _lightSegments,
      skyStops: isDark ? _skyStopColors : _lightSky,
      starColor: Colors.white.withValues(alpha: .75),
      domeTop: Colors.white.withValues(alpha: .16),
      horizon: Colors.white.withValues(alpha: .25),
    );
  }

  /// The same nine intervals, deepened so they read on a pale backdrop.
  static const List<Color> _lightSegments = [
    Color(0xFF7B6BE0),
    Color(0xFFC9A63F),
    Color(0xFFC79A24),
    Color(0xFFC87E22),
    Color(0xFFC06424),
    Color(0xFFB23F2C),
    Color(0xFF5468D8),
    Color(0xFF3D55C4),
    Color(0xFF5E86D6),
  ];

  static const List<Color> _lightSky = [
    Color(0xFF7B6BE0),
    Color(0xFFC9A63F),
    Color(0xFFC79A24),
    Color(0xFFC06424),
    Color(0xFF5468D8),
    Color(0xFF3D55C4),
  ];

  @override
  bool operator ==(Object other) =>
      other is ArcTheme && other.isDark == isDark;

  @override
  int get hashCode => isDark.hashCode;
}
