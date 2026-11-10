import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/app/state/clock_providers.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/month_display_scope.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/home/presentation/providers/arc_style_provider.dart';
import 'package:tawheeed/features/home/presentation/utils/date_formatters.dart';
import 'package:tawheeed/features/home/presentation/utils/time_formatters.dart';
import 'package:tawheeed/features/home/presentation/widgets/arc/home_arc.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';

/// The 2026-10-13 user request grew the hero's clock block 20 %; 2026-11 the
/// same reader asked for it back down — «باکس ساعت … کوتاه‌تر و جمع‌وجورتر» —
/// because the hero had grown taller than the arc it serves. One multiplier
/// keeps every dimension of the group proportional. 1.08 keeps the group
/// larger than its original 1.0 while pulling ~10 % of the height back, and
/// the digit faces snap to the shared type scale: `48 * 1.08` (51.8) resolves
/// to 48, so the digits shrink WITH their tiles instead of filling a smaller
/// box at 56.
///
/// 2026-10-14: the adhan countdown's two text lines joined the group, so
/// [_Countdown] multiplies both by this constant.
const double _heroScale = 1.08;

/// ═══════════════════════════════════════════════════════════════
/// HeroCard — the redesigned home's signature element, full-bleed with
/// rounded bottom corners.
///
/// Layer order (design): the active theme's hero gradient with a sun orb, bottom
/// glow and five static stars (repaints only for lite changes), glass
/// location chip + weekday outline chip, the digit-tile clock with the
/// 44px live seconds ring, the triple-calendar chips, and the TEN-marker
/// horizon arc (صبح … صبح بعدی) with the adhan countdown and the
/// adhan/iqamah pills below it.
///
/// Performance contract:
/// - the background painter is static — no per-frame work, no blur, no
///   Opacity/saveLayer (flat alphas and shaders only);
/// - the clock tiles rebuild per minute and the seconds ring/countdown
///   per second — but only while the tab is visible: [_HeroCardState]
///   reads TickerMode once and passes [active] down, so hidden tabs
///   subscribe to nothing (the shared ClockTicker keeps running app-wide);
/// - the arc repaints only when its quantized ArcState changes (~every
///   two minutes), inside its own RepaintBoundary;
/// - [lite] turns the orb/glow/stars off for weak devices.
/// ═══════════════════════════════════════════════════════════════
class HeroCard extends ConsumerStatefulWidget {
  const HeroCard({super.key, this.lite = false});

  /// On low-end devices the star field and glows are skipped entirely.
  final bool lite;

  @override
  ConsumerState<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends ConsumerState<HeroCard> {
  ValueListenable<TickerModeData>? _tickerModeNotifier;
  bool _active = true;
  void Function()? _disposeCityListener;

  @override
  void initState() {
    super.initState();
    // The shared ClockTicker keeps firing app-wide; the per-second/minute
    // UI below only subscribes while the tab is visible (TickerMode from
    // the shell), so a hidden home tab costs nothing.
    _tickerModeNotifier = TickerMode.getValuesNotifier(context);
    _tickerModeNotifier?.addListener(_onTickerModeChanged);
    _active = _tickerModeNotifier?.value.enabled ?? true;
    _listenCityName();
  }

  void _onTickerModeChanged() {
    final active = _tickerModeNotifier?.value.enabled ?? true;
    if (active == _active || !mounted) return;
    setState(() => _active = active);
  }

  void _listenCityName() {
    final repo = ref.read(prayerTimeServiceProvider);
    try {
      _disposeCityListener = repo.listenCityName(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      AppLogger.warning('hero_card', 'city listener failed: $e');
    }
  }

  @override
  void dispose() {
    _tickerModeNotifier?.removeListener(_onTickerModeChanged);
    _disposeCityListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticker = ref.watch(clockTickerProvider);
    final clock = ref.watch(prayerClockProvider);
    final timesAsync = ref.watch(prayerTimesProvider);
    final city = ref.watch(cityProvider);
    final use12Hour = ref.watch(use12HourProvider);
    final hijriOffset = ref.watch(hijriOffsetProvider);
    final prayerService = ref.watch(prayerTimeServiceProvider);
    final resolved = prayerService.cityName;
    final locationName = resolved.isNotEmpty
        ? resolved
        : (city?.isNotEmpty == true ? city! : '');

    final now = ticker.minute.value;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: CustomPaint(
          painter: _HeroBackgroundPainter(widget.lite),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Row children get unbounded main-axis width, so a bare
                    // chip could push the weekday chip off-screen on a long
                    // city name at 320dp; Flexible caps it with ellipsis.
                    Flexible(
                        child: _GlassChip(
                      icon: Icons.location_on_rounded,
                      text: locationName.isNotEmpty
                          ? (prayerService.altitude != null
                              ? '$locationName · ${prayerService.altitude!.round()} متر'
                              : locationName)
                          : 'در حال دریافت مکان...',
                      onTap: () async {
                        final service = ref.read(prayerTimeServiceProvider);
                        final settings = ref.read(settingsProvider).value;
                        final writer = ref.read(settingsProvider.notifier);
                        await service.forceRefreshLocation(
                            settings: settings, writer: writer);
                      },
                    )),
                    const SizedBox(width: 8),
                    _OutlineChip(_weekdayName(now)),
                  ],
                ),
                const SizedBox(height: 4),
                _LiveClock(
                  minute: ticker.minute,
                  second: ticker.second,
                  use12Hour: use12Hour,
                  active: _active,
                ),
                const SizedBox(height: 3),
                _DateChips(now: now, hijriOffset: hijriOffset),
                const SizedBox(height: 3),
                if (clock == null)
                  _ArcPlaceholder(
                    failed:
                        timesAsync.hasError && !timesAsync.hasValue,
                  )
                else
                  _ArcCountdown(
                    clock: clock,
                    minute: ticker.minute,
                    second: ticker.second,
                    use12Hour: use12Hour,
                    active: _active,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _weekdayName(DateTime now) => switch (now.weekday) {
        1 => 'دوشنبه',
        2 => 'سه‌شنبه',
        3 => 'چهارشنبه',
        4 => 'پنجشنبه',
        5 => 'جمعه',
        6 => 'شنبه',
        _ => 'یکشنبه',
      };
}

// ───────────────────────── پس‌زمینه ثابت ─────────────────────────

/// The hero's field wears the home-screen widget's own dark navy — the same
/// `#004F9E` the native card paints under `WidgetTokens.DEFAULT_BG` — so the
/// big box (clock + dates + arc) and the placed widget read as one surface.
/// It replaces the theme's brown/gold hero gradient: the tiles, chips and arc
/// already carry the widget's gold hairline, and a brown field around them
/// made the app's box and the widget's box look like two different designs.
/// The gradient darkens toward the bottom for depth and the five static stars
/// stay; the sun orb and bottom glow remain gone.
const List<Color> _heroWidgetField = <Color>[
  Color(0xFF004F9E),
  Color(0xFF003D7A),
  Color(0xFF002E5C),
];

/// Static hero background: the dark widget field above and five static stars.
/// Repaints only when [lite] changes — never per frame.
class _HeroBackgroundPainter extends CustomPainter {
  _HeroBackgroundPainter(this.lite);

  final bool lite;

  // Five tiny static stars (white/gold) as fractions of the size.
  static const _stars = <(double, double, double, bool)>[
    (.09, .12, 1.2, false),
    (.37, .08, 1.0, false),
    (.66, .14, 1.3, true),
    (.93, .24, 1.0, false),
    (.78, .05, .9, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _heroWidgetField,
          stops: const [0, .5, 1],
        ).createShader(rect),
    );
    if (lite) return;

    // The soft gold sun orb that used to sit behind the clock is GONE
    // (brief 2026-11-07: «نور وسط بوکس کنار ساعت برداشته بشود»), and the
    // bottom glow is GONE too (brief 2026-11-08: «هاله ی نور از زیر باکس
    // ساعت برداشته بشود»). Both read as stray light around the tiles. The
    // five static stars stay as the only ornament; the field above and below
    // the clock is now the clean gradient itself.

    final white = Paint()..color = const Color(0xB3FFFFFF);
    final gold = Paint()..color = AppPalette.heroGold;
    for (final (x, y, r, isGold) in _stars) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * y),
        r,
        isGold ? gold : white,
      );
    }
  }

  @override
  bool shouldRepaint(_HeroBackgroundPainter old) => old.lite != lite;
}

// ───────────────────────── ساعت کاشی‌ای ─────────────────────────

/// Digit-tile clock: hours + colon dots + minutes + a 44px live seconds
/// ring. Subscribes per-minute for the tiles and per-second for the ring
/// only — and only while [active].
///
/// 2026-11-07: the tiles wear the DARK widget's colours (brief: «رنگ‌هاش
/// مانند رنگ‌های ویجت تیره باشند») — a deep glass that reads near-black over
/// the hero field with the widget's gold hairline, instead of the old washed
/// white-22% plates. The digits stay cream, the accents stay heroGold.
class _LiveClock extends StatelessWidget {
  const _LiveClock({
    required this.minute,
    required this.second,
    required this.use12Hour,
    required this.active,
  });

  final ValueListenable<DateTime> minute;
  final ValueListenable<DateTime> second;
  final bool use12Hour;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return _PerMinute(
      minute: minute,
      active: active,
      builder: (context, now) {
        final h24 = now.hour;
        final h = use12Hour ? (h24 % 12 == 0 ? 12 : h24 % 12) : h24;
        final m = now.minute.toString().padLeft(2, '0');
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Tile(use12Hour ? '$h' : h.toString().padLeft(2, '0')),
              const SizedBox(width: 6 * _heroScale),
              const _ColonDots(),
              const SizedBox(width: 6 * _heroScale),
              _Tile(m),
              const SizedBox(width: 6 * _heroScale),
              Column(
                children: [
                  _SecondsRing(second: second, active: active),
                  if (use12Hour) ...[
                    const SizedBox(height: 4),
                    _MeridiemBox(h24 < 12),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Minute-driven layer: rebuilds when the minute changes, or instantly on
/// becoming visible again; subscribes to nothing while [active] is false.
class _PerMinute extends StatelessWidget {
  const _PerMinute({
    required this.minute,
    required this.active,
    required this.builder,
  });

  final ValueListenable<DateTime> minute;
  final bool active;
  final Widget Function(BuildContext, DateTime) builder;

  @override
  Widget build(BuildContext context) {
    if (!active) return builder(context, minute.value);
    return ValueListenableBuilder<DateTime>(
      valueListenable: minute,
      builder: (context, now, _) => builder(context, now),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78 * _heroScale,
      height: 68 * _heroScale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // The dark widget's box: near-black glass with the gold hairline, so
        // the clock block and the home-screen widget read as one family.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF000000).withValues(alpha: .55),
            const Color(0xFF000000).withValues(alpha: .38),
          ],
        ),
        borderRadius: BorderRadius.circular(20 * _heroScale),
        border: Border.all(
          color: AppPalette.heroGold.withValues(alpha: .6),
          width: .5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppTheme.scaledFontSize(context, 48 * _heroScale),
          height: 1,
          fontWeight: FontWeight.w500,
          color: AppPalette.cream,
          fontFamily: AppTheme.fontFamily,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 44px seconds ring: white-20% track + gold progress arc (seconds/60,
/// round caps) + 13px gold seconds number. Its own widget on the `second`
/// notifier inside a RepaintBoundary, so the per-second repaint stays
/// inside this 44px box; the hour/minute tiles above only rebuild per
/// minute. Inactive (hidden tab): one static render, no subscription.
class _SecondsRing extends StatelessWidget {
  const _SecondsRing({required this.second, required this.active});
  final ValueListenable<DateTime> second;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return _ring(context, second.value.second);
    return ValueListenableBuilder<DateTime>(
      valueListenable: second,
      builder: (context, now, _) => _ring(context, now.second),
    );
  }

  Widget _ring(BuildContext context, int seconds) {
    return RepaintBoundary(
      child: SizedBox(
        width: 44 * _heroScale,
        height: 44 * _heroScale,
        child: CustomPaint(
          painter: _SecondsRingPainter(seconds: seconds),
          child: Center(
            child: Text(
              seconds.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 16),
                height: 1,
                fontWeight: FontWeight.w600,
                color: AppPalette.heroGold,
                fontFamily: AppTheme.fontFamily,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondsRingPainter extends CustomPainter {
  const _SecondsRingPainter({required this.seconds});
  final int seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - 5) / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * _heroScale
        ..color = Colors.white.withValues(alpha: .20),
    );
    if (seconds <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -0.5 * 3.141592653589793,
      2 * 3.141592653589793 * (seconds / 60),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * _heroScale
        ..strokeCap = StrokeCap.round
        ..color = AppPalette.heroGold,
    );
  }

  @override
  bool shouldRepaint(_SecondsRingPainter old) => old.seconds != seconds;
}

/// Small ق.ظ/ب.ظ box — the meridiem lives in its own compact tile under
/// the seconds box (12-hour clocks only), gold-on-glass like the seconds.
class _MeridiemBox extends StatelessWidget {
  const _MeridiemBox(this.isAm);
  final bool isAm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42 * _heroScale,
      height: 24 * _heroScale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.heroGold.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(10 * _heroScale),
      ),
      child: Text(
        isAm ? 'ق.ظ' : 'ب.ظ',
        style: TextStyle(
          fontSize: AppTheme.scaledFontSize(context, 10.5 * _heroScale),
          height: 1,
          fontWeight: FontWeight.w700,
          color: AppPalette.heroGold,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

class _ColonDots extends StatelessWidget {
  const _ColonDots();

  @override
  Widget build(BuildContext context) {
    const dot = DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.heroGold,
        shape: BoxShape.circle,
      ),
      child: SizedBox(width: 5 * _heroScale, height: 5 * _heroScale),
    );
    return const Column(
        children: [dot, SizedBox(height: 8 * _heroScale), dot]);
  }
}

// ───────────────────────── چیپ‌ها ─────────────────────────

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppPalette.heroGold),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTheme.scaledFontSize(context, 11),
                  color: Colors.white,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.refresh_rounded,
                size: 11,
                color: Colors.white.withValues(alpha: .55),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.heroGold, width: .5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppTheme.scaledFontSize(context, 11),
          color: AppPalette.heroGold,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

/// Triple-calendar chips (Jalali / Hijri / Gregorian) with fixed identity
/// dots (gold / green / blue).
///
/// The three boxes are ONE size (user request 2026-10-23: «الان هجری کوتاه‌تر
/// از بقیه است و زیبا نیست»): the row is three `Expanded` cells and the chip's
/// box fills its cell, so the shortest reading wears a box as wide as the
/// longest. A `Flexible` cell cannot do that — it hugs its child's intrinsic
/// width, which is exactly what made the Hijri box read short.
///
/// It still never overflows: each cell only ever has its third of the row, and
/// the dot+date inside the box is a `FittedBox(scaleDown)`, so 320dp width and
/// text scale 1.3 shrink the glyphs instead of truncating them.
class _DateChips extends StatelessWidget {
  const _DateChips({required this.now, required this.hijriOffset});
  final DateTime now;
  final int hijriOffset;

  @override
  Widget build(BuildContext context) {
    MonthDisplayScope.of(context);
    final jalali = Jalali.fromDateTime(now);
    final hijri = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
        offset: hijriOffset);
    // Single source for the three readings: the formatters isolate each
    // digit run, so bidi can never re-order a date differently here than in
    // the share card or the calendar (audit P-01).
    final shamsiStr = DateFormatters.formatShamsi(
        jalali.day, jalali.month, jalali.year);
    final hijriStr =
        DateFormatters.formatHijri(hijri.day, hijri.month, hijri.year);
    final gregStr = DateFormatters.formatGregorian(
        now.day, now.month, now.year);

    return Row(
      children: [
        Expanded(
            child: _SmallChip(
          key: const ValueKey('date-chip-shamsi'),
          shamsiStr,
          dot: AppColors.datePillShamsi,
        )),
        const SizedBox(width: 5 * _heroScale),
        Expanded(
            child: _SmallChip(
          key: const ValueKey('date-chip-hijri'),
          hijriStr,
          dot: AppColors.datePillHijri,
        )),
        const SizedBox(width: 5 * _heroScale),
        Expanded(
            child: _SmallChip(
          key: const ValueKey('date-chip-gregorian'),
          gregStr,
          dot: AppColors.datePillGregorian,
        )),
      ],
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip(this.text, {required this.dot, super.key});
  final String text;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    // `alignment` makes the decorated box fill the cell it was given
    // (_DateChips' Expanded), which is what keeps the three boxes equal;
    // without it the box would shrink-wrap its own content again.
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
          horizontal: 7 * _heroScale, vertical: 3 * _heroScale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(10 * _heroScale),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5 * _heroScale,
              height: 5 * _heroScale,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
            ),
            const SizedBox(width: 4 * _heroScale),
            Text(
              text,
              maxLines: 1,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 10.5 * _heroScale),
                color: Colors.white,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── قوس + شمارش معکوس ─────────────────────────

/// Visible loading state for the arc. A blank box here is what made the hero
/// read as «قوس و باقی‌مانده کاملاً مخفی است» while the location pipeline ran;
/// it keeps the arc's exact footprint so nothing jumps when the times land.
/// Static on purpose: no repeating animation controller.
class _ArcPlaceholder extends StatelessWidget {
  const _ArcPlaceholder({this.failed = false});

  /// The prayer times read has already failed, so «در حال محاسبه…» would be a
  /// claim the page cannot keep. Without this flag the hero said «calculating»
  /// for as long as the app was open while the card below it said «در دسترس
  /// نیست» — two blocks on one screen disagreeing about the same read.
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 306 / 130,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              failed ? Icons.error_outline : Icons.nights_stay_outlined,
              size: 28,
              color: Colors.white.withValues(alpha: .75)),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              failed
                  ? 'اوقات شرعی محاسبه نشد'
                  : 'در حال محاسبهٔ اوقات شرعی…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.scaledFontSize(context, 13),
                color: Colors.white.withValues(alpha: .85),
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcCountdown extends ConsumerWidget {
  const _ArcCountdown({
    required this.clock,
    required this.minute,
    required this.second,
    required this.use12Hour,
    required this.active,
  });

  final PrayerClock clock;
  final ValueListenable<DateTime> minute;
  final ValueListenable<DateTime> second;
  final bool use12Hour;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arcPrefs = ref.watch(homeArcPrefsProvider);
    final lite = ref.watch(liteModeProvider).value ?? false;
    final textScale =
        (MediaQuery.maybeOf(context)?.textScaler.scale(1) ?? 1.0).clamp(1.0, 1.3);
    return ValueListenableBuilder<PrayerSnapshot>(
      valueListenable: clock,
      builder: (context, snap, _) {
        final arc = snap.arc;
        // The adhan + iqamah milestones as two pills below the arc; the
        // iqamah pill is hidden when iqamah is disabled/unknown.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                HomeArc(
                  arc: arc,
                  style: arcPrefs.style,
                  smallLabels: arcPrefs.smallLabels,
                  textScale: textScale,
                  lite: lite,
                ),
                // The countdown sits inside the dome. It keeps its own
                // per-second subscription, so the arc never repaints for it.
                Positioned.fill(
                  child: ValueListenableBuilder<DateTime>(
                    valueListenable: minute,
                    builder: (context, now, _) {
                      final markers = arc.markers;
                      final nextIdx = markers
                          .indexWhere((m) => m.state == ArcMarkerState.next);
                      final prevMarker = nextIdx > 0
                          ? markers[nextIdx - 1].label
                          : (markers.isNotEmpty ? markers.first.label : 'صبح');
                      final nextMarker = nextIdx >= 0
                          ? markers[nextIdx].label
                          : (markers.isNotEmpty ? markers.last.label : 'صبح');
                      return Semantics(
                        label: TimeFormatters.arcSemantics(
                          moon: arc.moon,
                          prevMarker: prevMarker,
                          nextMarker: nextMarker,
                          nextLabel: snap.nextId.label,
                          remaining: snap.nextAdhanTime.difference(now),
                        ),
                        child: Align(
                          alignment: const Alignment(0, .34),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _Countdown(
                              minute: minute,
                              second: second,
                              target: snap.nextAdhanTime,
                              nextLabel: snap.nextId.label,
                              active: active,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MilestonePill(
                    text:
                        '${snap.nextId.label} · ${_formatClock(snap.nextAdhanTime, use12Hour)}',
                    fill: Colors.white.withValues(alpha: .14),
                    textColor: AppPalette.cream,
                  ),
                  if (snap.iqamahTime != null) ...[
                    const SizedBox(width: 6),
                    _MilestonePill(
                      text:
                          'اقامه · ${_formatClock(snap.iqamahTime!, use12Hour)}',
                      fill: AppPalette.heroGold.withValues(alpha: .22),
                      textColor: AppPalette.heroGold,
                      icon: Icons.notifications_none_rounded,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatClock(DateTime t, bool use12Hour) {
    final m = t.minute.toString().padLeft(2, '0');
    if (!use12Hour) {
      final h = t.hour.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:$m ${t.hour < 12 ? 'ق.ظ' : 'ب.ظ'}';
  }
}

/// Milestone pill below the arc («اذان مغرب · 17:38»).
class _MilestonePill extends StatelessWidget {
  const _MilestonePill({
    required this.text,
    required this.fill,
    required this.textColor,
    this.icon,
  });

  final String text;
  final Color fill;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 11),
              color: textColor,
              fontFamily: AppTheme.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Remaining time to the next adhan, as the big gold number under the
/// arc («۰۱:۲۳» LTR, tabular), with the «تا اذان <نام>» caption ABOVE it.
///
/// Subscription follows the display: per second under an hour (so the
/// seconds pair ticks), otherwise per minute — the widget re-subscribes
/// itself when the remaining time crosses the hour boundary or the target
/// changes. Inactive (hidden tab): no subscription, one static render.
class _Countdown extends StatefulWidget {
  const _Countdown({
    required this.minute,
    required this.second,
    required this.target,
    required this.nextLabel,
    required this.active,
  });

  final ValueListenable<DateTime> minute;
  final ValueListenable<DateTime> second;

  /// Snapshot's adhan time — the ONLY countdown target.
  final DateTime target;

  /// Already-localized «اذان <نام>» for the caption line.
  final String nextLabel;
  final bool active;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  ValueListenable<DateTime>? _sub;

  @override
  void initState() {
    super.initState();
    _resubscribe(_currentTime);
  }

  @override
  void didUpdateWidget(_Countdown old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target || old.active != widget.active) {
      _resubscribe(_currentTime);
    }
  }

  DateTime get _currentTime => widget.active
      ? (_sub?.value ?? widget.minute.value)
      : widget.minute.value;

  void _resubscribe(DateTime now) {
    _sub?.removeListener(_onTick);
    _sub = null;
    if (!widget.active) return;
    final showSeconds =
        TimeFormatters.formatCountdown(widget.target.difference(now))
            .showSeconds;
    _sub = showSeconds ? widget.second : widget.minute;
    _sub?.addListener(_onTick);
  }

  void _onTick() {
    if (!mounted) return;
    // Crossing the hour boundary swaps the subscription (and the format).
    _resubscribe((_sub ?? widget.minute).value);
    setState(() {});
  }

  @override
  void dispose() {
    _sub?.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = _currentTime;
    final formatted =
        TimeFormatters.formatCountdown(widget.target.difference(now));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The 2026-10-13 request: the «تا اذان <نام>» caption sits ABOVE the
        // remaining-time number (it used to hang under it). 2026-11-07 brief:
        // both lines grew again and read cleaner — the caption stepped up to
        // a bolder cream and the number to 30 sp at w700, still inside the
        // FittedBox so a 320 dp cell scales down instead of clipping.
        Text(
          'تا ${widget.nextLabel}',
          key: const ValueKey('hero-countdown-caption'),
          style: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 16 * _heroScale),
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: .2,
            color: AppPalette.cream.withValues(alpha: .92),
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: 5),
        RepaintBoundary(
          child: Text(
            formatted.text,
            key: const ValueKey('hero-countdown-value'),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: AppTheme.scaledFontSize(context, 30 * _heroScale),
              height: 1,
              fontWeight: FontWeight.w700,
              color: AppPalette.heroGold,
              fontFamily: AppTheme.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
