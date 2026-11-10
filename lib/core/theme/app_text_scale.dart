import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tawheeed/core/constants/month_display.dart';
import 'package:tawheeed/core/theme/month_display_scope.dart';

/// App-wide text scale (اندازه فونت).
///
/// The app's text size is owned by **its own** setting, but the device's
/// font-size preference is an accessibility choice that must still work:
///
///  * **Never smaller** — a phone set below the in-app scale cannot shrink the
///    print-style, fixed-measure layouts (mushaf, hero clock, stat cards)
///    below the size the app was designed for.
///  * **Larger is honoured** — a user who needs large text across the whole
///    phone gets it here too, without hunting for the in-app slider. The
///    device factor is floored at 1.0 and multiplied with the in-app one, and
///    the product is capped at [maxScale] — the same ceiling the in-app
///    setting offers, so no fixed measure is asked for a size it never had to
///    carry.
///
/// The device curve is sampled at body size (14sp): the app's layout maths
/// needs one predictable factor, and Android 14+'s non-linear curve differs
/// from linear mostly at extremes the fixed measures cannot carry anyway.
///
/// Place it once, as the root `MaterialApp.builder` wrapper. Multiplying the
/// theme's type sizes as well would scale every themed text twice.
class AppTextScale extends StatefulWidget {
  /// The stored multiplier (`AppSettings.fontScale`), where 1.0 is the design
  /// baseline. Values outside the safe window are clamped rather than trusted:
  /// a hand-edited or legacy row must never be able to shatter the layout.
  final double fontScale;

  final Widget child;

  const AppTextScale({
    super.key,
    required this.fontScale,
    required this.child,
  });

  /// The lowest multiplier the app renders at.
  static const double minScale = 0.8;

  /// The highest multiplier the app renders at. Beyond this the fixed
  /// dossier-style measures (mushaf page, hero clock, stat cards) stop fitting.
  static const double maxScale = 1.8;

  /// The single multiplier applied to text, for callers that need the number
  /// (tests, layout maths) rather than the widget.
  static double factorOf(double fontScale) =>
      fontScale.clamp(minScale, maxScale);

  @override
  State<AppTextScale> createState() => _AppTextScaleState();
}

class _AppTextScaleState extends State<AppTextScale> {
  @override
  void initState() {
    super.initState();
    // The month-name choice is pref-backed (no Drift column); this root wrapper
    // is where the app first paints, so it loads the choice before most screens
    // read `DateConstants.persianMonths`.
    unawaited(loadMonthDisplay());
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final app = AppTextScale.factorOf(widget.fontScale);
    // Sample the device curve at body size (14sp): layout maths needs ONE
    // predictable factor, and the non-linear Android curve only diverges from
    // linear at extremes the fixed measures cannot carry. Flooring at 1.0 is
    // what keeps a shrunken system font from undoing the app's own size.
    final deviceFactor =
        media.textScaler.clamp(minScaleFactor: 1.0).scale(14) / 14;
    final effective =
        (app * deviceFactor)
            .clamp(AppTextScale.minScale, AppTextScale.maxScale)
            .toDouble();
    return MediaQuery(
      // copyWith keeps every other metric (padding, insets, orientation) —
      // only the *font* behaviour of the device is replaced.
      data: media.copyWith(textScaler: TextScaler.linear(effective)),
      child: MonthDisplayScope(child: widget.child),
    );
  }
}
