import 'package:tawheeed/shared/utils/number_format.dart';

/// The ONE shared display formatter set for the compass/astro surfaces
/// (qibla, sun sign, moon): every numeric surface that can be embedded in
/// Persian (RTL) text goes through these, so numbers are LTR-isolated and
/// never reordered by the bidi algorithm, and digit policy stays Latin (the
/// app-wide product standard).
///
/// Lives next to [NumberFormat.ltrIsolated] and reuses it — the isolate
/// characters (U+2066 … U+2069) are the single mechanism that stops an RTL
/// neighbour from flipping «‎149 :اختلاف» into «اختلاف: 149°».
class GeoFormat {
  GeoFormat._();

  /// `246.9°` — degrees with a fixed number of decimals, LTR-isolated.
  static String degrees(double value, {int decimals = 1}) => NumberFormat
      .ltrIsolated('${value.abs().toStringAsFixed(decimals)}\u00b0');

  /// `+4.2°` / `−4.2°` — signed degrees (declination), LTR-isolated with a
  /// real typographic minus so it never renders «‎4.2-°».
  static String signedDegrees(double value, {int decimals = 1}) {
    final sign = value >= 0 ? '+' : '\u2212';
    return NumberFormat
        .ltrIsolated('$sign${value.abs().toStringAsFixed(decimals)}\u00b0');
  }

  /// `10%` — an integer percent, half-UP rounded (0.5 rounds to 1), so a
  /// moon illumination of 9.529707880484157 reads «10%» and never repeats
  /// fifteen decimals.
  static String percent(double value, {int decimals = 0}) {
    var pow10 = 1;
    for (var i = 0; i < decimals; i++) {
      pow10 *= 10;
    }
    final scaled = value * pow10;
    // Half-UP for positives (value is a percent, always ≥ 0 here).
    final rounded = (scaled.abs() + 0.5).floor() * (scaled < 0 ? -1 : 1) / pow10;
    var text = rounded.toStringAsFixed(decimals);
    if (decimals > 0) {
      text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return NumberFormat.ltrIsolated('$text%');
  }

  /// `14:10` — zero-padded wall clock, LTR-isolated so a Persian label can't
  /// drag the minute to the other end of the row.
  static String clock(int hour, int minute) =>
      NumberFormat.ltrIsolated('${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}');

  /// `15 ساعت و 36 دقیقه` / `7 دقیقه` — a duration in Persian words, never
  /// the «15س 36د» shorthand whose digit runs the bidi algorithm reorders.
  static String durationWords(Duration d) {
    final total = d.abs();
    final hours = total.inHours;
    final minutes = total.inMinutes % 60;
    final days = total.inDays;
    final parts = <String>[];
    if (hours >= 24) {
      parts.add('$days روز');
    }
    final h = hours % 24;
    if (h > 0) parts.add('$h ساعت');
    if (minutes > 0 || parts.isEmpty) {
      parts.add('$minutes دقیقه');
    }
    if (parts.length == 1) return NumberFormat.ltrIsolated(parts.first);
    return parts.join(' و ');
  }
}
