import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/router/route_names.dart';
import 'package:tawheeed/app/state/app_bootstrap.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/splash/domain/splash_orchestrator.dart';
import 'package:tawheeed/features/splash/presentation/splash_style.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// The cold-start frame: the app's own logo on a fixed gold-brown field, with
/// a handful of stars, a crescent and four decorative feature tiles.
///
/// Everything about this screen is built for the weakest phone in the matrix:
/// no AnimationController exists unless the slow-start dots appear, the
/// decorations are one painter that never repaints, the logo is a plain
/// [Image] of the real asset (its own pixels, nothing drawn on or around it),
/// and the screen leaves the moment initialization is done — the 400 ms floor
/// is the only deliberate time the user spends here.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

/// One star: fractional position (so it scales with the screen) and a radius
/// in dp. Fixed, hand-placed, and kept out of the band the coin occupies.
@immutable
class _Star {
  const _Star(this.dx, this.dy, this.radius);
  final double dx;
  final double dy;
  final double radius;
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// The 13 stars of the field. Every fourth one (index 3, 7, 11) is the
  /// warm-white bright variant; all sit in the upper 60 % of the screen.
  static const List<_Star> _stars = [
    _Star(0.08, 0.10, 1.2),
    _Star(0.22, 0.18, 1.0),
    _Star(0.15, 0.30, 1.3),
    _Star(0.30, 0.08, 1.4),
    _Star(0.72, 0.12, 1.1),
    _Star(0.86, 0.22, 1.3),
    _Star(0.64, 0.26, 1.0),
    _Star(0.92, 0.38, 1.2),
    _Star(0.06, 0.44, 1.1),
    _Star(0.24, 0.52, 1.3),
    _Star(0.78, 0.48, 1.0),
    _Star(0.55, 0.06, 1.2),
    _Star(0.40, 0.20, 1.0),
  ];

  bool _showLoader = false;
  bool _logoPrecached = false;

  /// Only ever created when the wait actually crossed [SplashTiming
  /// .loaderDelay], and never at all under reduce-motion.
  AnimationController? _loaderController;

  /// `lite_mode`, read from the same prefs instance as the routing flag so
  /// the hand-off costs no extra channel call.
  bool _liteMode = false;

  @override
  void initState() {
    super.initState();
    // The splash is a portrait composition (a centred coin plus a row of
    // tiles); Home keeps whatever the device allows afterwards.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    unawaited(_runGate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logoPrecached) return;
    _logoPrecached = true;
    // Kick the decode off now, without awaiting it: the Image below attaches
    // to the same stream, so the first Flutter frame carries the coin instead
    // of an empty box where the native splash just was.
    precacheImage(SplashAssets.logo, context);
  }

  Future<void> _runGate() async {
    final destination = await SplashOrchestrator().run(
      init: () => ref.read(appBootstrapProvider).ready,
      onboardingDone: _readOnboardingDecision,
      onLoaderDue: _showSlowStartLoader,
    );
    if (!mounted) return;
    context.go(
      destination == SplashDestination.shell
          ? RouteNames.shell
          : RouteNames.onboarding,
      // The router reads this as the hand-off fade length (see
      // `_handoffPage`). 0 in lite mode and under reduce-motion.
      extra: _handoffDuration,
    );
  }

  Duration get _handoffDuration {
    if (_liteMode ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations) {
      return Duration.zero;
    }
    return SplashTiming.crossFade;
  }

  void _showSlowStartLoader() {
    if (!mounted) return;
    final animate = !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (animate) {
      _loaderController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat();
    }
    setState(() => _showLoader = true);
  }

  /// Shell vs onboarding, exactly as before the redesign: the dedicated
  /// SharedPreferences flag wins (it is written when onboarding finishes),
  /// the settings row is the one-time fallback, and an unknown answer opens
  /// Home rather than showing onboarding to a returning user.
  Future<bool?> _readOnboardingDecision() async {
    SharedPreferences? prefs;
    try {
      // A missing or slow prefs channel must never stall the decision. In
      // tests (and on a wedged device) `getInstance()` can hang forever, so
      // it gets its own short timeout and we fall back to the settings read.
      prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(milliseconds: 400));
      _liteMode = prefs.getBool('lite_mode') ?? false;
    } catch (e) {
      AppLogger.warning(
          'splash_screen', 'prefs unavailable, using settings: $e');
    }
    try {
      final doneFlag = prefs?.getBool('onboarding_done_v1');
      if (doneFlag != null) return doneFlag;
      final settings = await ref
          .read(settingsProvider.future)
          .timeout(const Duration(seconds: 8));
      try {
        await prefs
            ?.setBool('onboarding_done_v1', settings.onboardingCompleted);
      } catch (e) {
        AppLogger.warning(
            'splash_screen', 'onboarding flag write failed: $e');
      }
      return settings.onboardingCompleted;
    } catch (e, st) {
      AppLogger.error(
          'splash_screen', 'onboarding read failed — opening Home: $e', st);
      return null;
    }
  }

  @override
  void dispose() {
    _loaderController?.dispose();
    // Hand the orientation back unconditionally: the lock belonged to this
    // route only, and leaving it set would tilt the whole app to portrait.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // The splash caps the reader's font scale: at 2× the tagline would meet
    // the tile row on a short screen, and the composition is fixed.
    final clampedScale =
        media.textScaler.scale(1).clamp(1.0, SplashSizes.maxTextScale).toDouble();

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Phase-1 audit fix kept: declaring the style through an
        // AnnotatedRegion means leaving this route restores the system chrome
        // by itself — no style leaks into Home.
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: SplashColors.fieldBottom,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: SplashColors.fieldMid,
          // One semantics node for the whole frame: a splash is branding, not
          // content, and the tiles are decoration, not shortcuts.
          body: Semantics(
            label: 'توحید — همراه شما در مسیر بندگی',
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SplashFieldPainter(
                    stars: _stars,
                    topInset: media.padding.top,
                    moonOnRight:
                        Directionality.of(context) == TextDirection.rtl,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _field(context, constraints, media),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    BoxConstraints constraints,
    MediaQueryData media,
  ) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final logo = SplashSizes.logoSize(width);
    // A centimetre above the screen centre, floored so a window too short for
    // the lift still shows the whole coin. Everything below hangs off this
    // edge, so the tagline and the tiles follow the mark instead of colliding
    // with it.
    final logoTop = math.max(
      SplashSizes.logoTopFloor,
      (height - logo) / 2 - SplashSizes.logoLift,
    );
    final taglineTop = logoTop + logo + SplashSizes.taglineGap;

    // Tiles are hidden on a short or narrow screen rather than shrunk: the
    // coin never goes below [SplashSizes.logoMin] and nothing ever overflows.
    const tilesBlockHeight = SplashSizes.tile +
        SplashSizes.tileLabelGap +
        SplashSizes.tileLabelSize * 1.5;
    final tilesTop = height -
        (SplashSizes.bottomPadding + media.viewPadding.bottom) -
        tilesBlockHeight;
    final taglineBlockHeight =
        SplashSizes.taglineSize * 1.6 + (_showLoader ? 16 : 0);
    final showTiles = width >= SplashSizes.tilesRowWidth(width) &&
        tilesTop > taglineTop + taglineBlockHeight + 12;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Stars + crescent, one painter, never repainting.
        RepaintBoundary(
          child: CustomPaint(
            painter: _SplashFieldPainter(
              stars: _stars,
              topInset: media.padding.top,
              moonOnRight: Directionality.of(context) == TextDirection.rtl,
            ),
          ),
        ),
        // The coin: the real asset, its own pixels only, centred horizontally
        // and a centimetre over the vertical centre. It is the only place the
        // mark is drawn in a launch — the system window carries no icon — so no
        // box, no clip, no shadow, no glow: nothing on or around it.
        Positioned(
          top: logoTop,
          left: 0,
          right: 0,
          child: Center(
            child: Image(
              image: SplashAssets.logo,
              key: const ValueKey('splash-logo'),
              width: logo,
              height: logo,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                AppLogger.error('splash_screen',
                    'logo asset failed to load: $error', stackTrace);
                return SizedBox(width: logo, height: logo);
              },
            ),
          ),
        ),
        Positioned(
          top: taglineTop,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'همراه شما در مسیر بندگی',
                textAlign: TextAlign.center,
                style: TextStyle(
                  // Named token, not a literal: the splash's type is part of a
                  // fixed composition, so it does not ride the app's theme
                  // (which is what `scaledFontSize` derives from).
                  fontSize: SplashSizes.taglineSize,
                  color: SplashColors.goldLight,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
              if (_showLoader) ...[
                const SizedBox(height: 16),
                _loader(),
              ],
            ],
          ),
        ),
        if (showTiles)
          Positioned(
            bottom: SplashSizes.bottomPadding + media.viewPadding.bottom,
            left: 0,
            right: 0,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FeatureTile(
                    icon: Icons.menu_book_rounded, label: 'قرآن'),
                SizedBox(width: SplashSizes.tileGap),
                _FeatureTile(
                    icon: Icons.auto_awesome_rounded, label: 'اذکار'),
                SizedBox(width: SplashSizes.tileGap),
                _FeatureTile(
                    icon: Icons.mosque_rounded, label: 'نماز'),
                SizedBox(width: SplashSizes.tileGap),
                _FeatureTile(
                    icon: Icons.explore_rounded, label: 'قبله'),
              ],
            ),
          ),
      ],
    );
  }

  /// Three gold dots, only after a wait the user can feel. Under reduce-motion
  /// they simply appear and stay.
  Widget _loader() {
    final controller = _loaderController;
    Widget row(List<double> alphas) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: SplashSizes.loaderGap),
              Container(
                width: SplashSizes.loaderDot,
                height: SplashSizes.loaderDot,
                decoration: BoxDecoration(
                  color: SplashColors.goldLight.withValues(alpha: alphas[i]),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        );
    if (controller == null) return row(const [1.0, 1.0, 1.0]);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => row([
        for (var i = 0; i < 3; i++)
          0.35 +
              0.65 *
                  (0.5 +
                      0.5 *
                          math.cos(2 * math.pi *
                              (controller.value - i / 3))),
      ]),
    );
  }
}

/// The field's decoration, drawn once. [shouldRepaint] is false on purpose:
/// the stars and the moon are fixed, so this layer costs no picture after the
/// first frame even while the countdown-free splash sits there.
class _SplashFieldPainter extends CustomPainter {
  _SplashFieldPainter({
    required this.stars,
    required this.topInset,
    required this.moonOnRight,
  });

  final List<_Star> stars;
  final double topInset;
  final bool moonOnRight;

  @override
  void paint(Canvas canvas, Size size) {
    final field = Offset.zero & size;
    // The ramp first, then the decoration on top of it — one layer, and the
    // reason the coin has no box around it: there is no widget between them.
    canvas.drawRect(
      field,
      Paint()..shader = SplashField.gradient.createShader(field),
    );

    final fill = Paint()..isAntiAlias = true;
    for (var i = 0; i < stars.length; i++) {
      final star = stars[i];
      fill.color = i % 4 == 3
          ? SplashColors.starBright
          : SplashColors.starSoft;
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        star.radius,
        fill,
      );
    }

    const radius = SplashSizes.moonDiameter / 2;
    final center = Offset(
      moonOnRight
          ? size.width - SplashSizes.moonEdgeInset - radius
          : SplashSizes.moonEdgeInset + radius,
      topInset + SplashSizes.moonTopInset + radius,
    );
    final moon = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    // A second, slightly smaller circle biting into the first — the classic
    // crescent, and the only way to get one without an image asset.
    final bite = Path()
      ..addOval(Rect.fromCircle(
        center: center + const Offset(radius * 0.42, -radius * 0.42),
        radius: radius * 0.86,
      ));
    fill.color = SplashColors.goldLight;
    canvas.drawPath(Path.combine(PathOperation.difference, moon, bite), fill);
  }

  @override
  bool shouldRepaint(covariant _SplashFieldPainter oldDelegate) => false;
}

/// One of the four feature tiles. Purely decoration — no gesture, no
/// semantics, and it never routes anywhere.
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: SplashSizes.tile,
          height: SplashSizes.tile,
          decoration: BoxDecoration(
            color: SplashColors.tileFill,
            borderRadius: BorderRadius.circular(SplashSizes.tileRadius),
            border: Border.all(color: SplashColors.tileBorder),
          ),
          child: Icon(
            icon,
            size: SplashSizes.tileGlyph,
            color: SplashColors.tileGlyph,
          ),
        ),
        const SizedBox(height: SplashSizes.tileLabelGap),
        SizedBox(
          width: SplashSizes.tile,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: SplashSizes.tileLabelSize,
              color: SplashColors.tileLabel,
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
