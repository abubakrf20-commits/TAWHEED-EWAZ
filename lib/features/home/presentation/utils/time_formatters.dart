class TimeFormatters {
  TimeFormatters._();

  /// 12-hour `h:mm` with NO «ق.ظ/ب.ظ» marker — the shape the native widget
  /// prints (`PrayerWidgetViews.convertTo12h`, and its `h:mm` clock).
  /// Unparseable input passes through.
  static String to12HourNoMarker(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:${minute.toString().padLeft(2, '0')}';
  }

  static String to12Hour(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    final period = hour >= 12 ? 'ب.ظ' : 'ق.ظ';
    return '${to12HourNoMarker(raw)} $period';
  }

  static String formatTime(String raw, {required bool use12Hour}) {
    return use12Hour ? to12Hour(raw) : raw;
  }

  /// The widget mirror's switch: the same setting, the marker-free shape,
  /// because the prayer widget's five boxes sit side by side and the marker
  /// costs about half of a box. The names above each time carry the period.
  static String formatTimeNoMarker(String raw, {required bool use12Hour}) {
    return use12Hour ? to12HourNoMarker(raw) : raw;
  }

  /// Hero countdown text for [remaining] until the next adhan.
  ///
  /// - 1 hour or more → "HH:MM" (stable within the minute; the widget only
  ///   subscribes to the minute ticker then);
  /// - under 1 hour → "MM:SS" (subscribes per second).
  ///
  /// Digits stay Latin + LTR (there is no Persian-digits setting); callers
  /// render with tabular figures. Negative durations clamp to zero so the
  /// label can never show a minus sign at the adhan boundary.
  static ({String text, bool showSeconds}) formatCountdown(Duration remaining) {
    final totalSeconds = remaining.isNegative ? 0 : remaining.inSeconds;
    if (totalSeconds >= 3600) {
      final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      return (text: '$h:$m', showSeconds: false);
    }
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return (text: '$m:$s', showSeconds: true);
  }

  /// Screen-reader description of the horizon arc, e.g.
  /// «خورشید بین ظهر و عصر، 2 ساعت و 12 دقیقه تا اذان عصر».
  ///
  /// [prevMarker]/[nextMarker] are the labels of the arc markers bracketing
  /// the sun (from the snapshot's ArcState — the same source the painter
  /// draws); [nextLabel] is the localized `«اذان …»` the countdown
  /// targets. When the sun has passed the last marker the two labels
  /// collapse to «پس از [nextMarker]».
  static String arcSemantics({
    required bool moon,
    required String prevMarker,
    required String nextMarker,
    required String nextLabel,
    required Duration remaining,
  }) {
    final body = moon ? 'ماه' : 'خورشید';
    final position = prevMarker == nextMarker
        ? 'پس از $prevMarker'
        : 'بین $prevMarker و $nextMarker';
    final total = remaining.isNegative ? 0 : remaining.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final amount = h > 0
        ? '$h ساعت و $m دقیقه'
        : m > 0
            ? '$m دقیقه و $s ثانیه'
            : '$s ثانیه';
    return '$body $position، $amount تا $nextLabel';
  }
}
