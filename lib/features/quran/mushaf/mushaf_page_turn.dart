import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';

/// How the reader crosses from one page to the next.
///
/// Both ride the pager itself, so a page never changes slot: the memoised page
/// tree is kept through the whole turn, whichever method is chosen.
enum MushafPageTurn {
  plain(
    'plain',
    'عادی',
    'صفحه‌ها کنار هم می‌لغزند',
    Icons.swap_horiz_rounded,
  ),
  bookFlip(
    'bookFlip',
    'ورق کتابی',
    'صفحه از عطف خم می‌شود و ورق می‌خورد',
    Icons.auto_stories_rounded,
  );

  const MushafPageTurn(this.wire, this.label, this.description, this.icon);

  /// The persisted value. Renaming one forgets every reader who picked it.
  final String wire;
  final String label;
  final String description;
  final IconData icon;

  /// A stored value still opens the reader the reader chose.
  ///
  /// `leaf` was the wire of the first flip attempt and `flip` the second;
  /// both are the book turn, so they resolve to [bookFlip]. `scroll` was the
  /// rolled-paper experiment this release retired: its readers asked for a
  /// turning page, so they keep one. `slide` was the old plain value and keeps
  /// [plain]. A missing value is a fresh install, which starts on [plain]: the
  /// effect is opt-in, never imposed on a reader who never asked for it.
  static MushafPageTurn fromWire(String? wire) {
    switch (wire) {
      case 'leaf':
      case 'flip':
      case 'scroll':
        return bookFlip;
      case 'slide':
      case 'plain':
        return plain;
      case 'bookFlip':
        return bookFlip;
    }
    return plain;
  }
}

/// Logical pixels one hinge strip should cover.
///
/// The old fixed count (8) gave every strip ~1/8 of a page width — on a dense
/// mushaf page the glyph baseline visibly kinked at each seam. Strips are now
/// sized from the slot instead: ~14 dp per hinge at normal quality (≈30 hinges
/// on a 412 dp phone) and ~28 dp in lite mode (≈15 hinges), so the curve reads
/// as a curve and the faceting moves below the visible threshold without
/// changing the widget tree or the number of state updates.
const double kBookFlipStripWidth = 14;
const double kBookFlipStripWidthLite = 28;
const int kBookFlipStripsMin = 12;
const int kBookFlipStripsMax = 36;
const int kBookFlipStripsLiteMin = 8;
const int kBookFlipStripsLiteMax = 18;

/// Hinges for one book turn, chosen from the slot's own width.
int mushafTurnStripCount(
  MushafPageTurn mode, {
  required double width,
  required bool lite,
}) {
  if (mode == MushafPageTurn.plain || width <= 0 || !width.isFinite) return 0;
  final perStrip = lite ? kBookFlipStripWidthLite : kBookFlipStripWidth;
  final min = lite ? kBookFlipStripsLiteMin : kBookFlipStripsMin;
  final max = lite ? kBookFlipStripsLiteMax : kBookFlipStripsMax;
  return (width / perStrip).ceil().clamp(min, max);
}

/// The whole leaf's angle at the end of a book turn, and the curve it follows:
/// slow at first (the page lifts), then committing.
const double kBookFlipMaxAngle = 100 * math.pi / 180;
const double kBookFlipAngleExponent = 1.55;

/// How far each hinge bends past the one before it, at the middle of the turn.
const double kBookFlipBend = 7 * math.pi / 180;

/// The paper a turned leaf shows once it is past edge-on: the sheet's own back,
/// never a mirrored glyph.
Color mushafLeafBackOn(Color paper) =>
    Color.alphaBlend(const Color(0x14000000), paper);

/// Camera distance for the strip painters, as a fraction of the page width.
const double kMushafTurnCamera = 1 / 1100;

/// Cumulative hinge angles (radians) for one strip chain at progress [p].
///
/// `angles[k]` is the absolute angle of strip `k`, whose hinge is the edge it
/// shares with strip `k-1` — strip 0 hangs off the spine. The book turn lifts
/// the whole leaf by `100° * p^1.55` and bends each hinge a further
/// `7° * sin(pi p)`, so the page curves while it rises and flattens as it
/// lands.
List<double> mushafTurnStripAngles({
  required MushafPageTurn mode,
  required double p,
  required int strips,
}) {
  final t = p.clamp(0.0, 1.0);
  if (strips <= 0) return const [];
  if (mode == MushafPageTurn.bookFlip) {
    final phi = kBookFlipMaxAngle * math.pow(t, kBookFlipAngleExponent);
    final bend = kBookFlipBend * math.sin(math.pi * t);
    return [for (var k = 0; k < strips; k++) phi + k * bend];
  }
  return List<double>.filled(strips, 0);
}

/// What a slot is doing mid-turn. Drives the shading and the transform.
enum MushafTurnRole {
  /// No turn in flight — the slot paints exactly as it does at rest.
  none,

  /// The page being turned: it tilts about the spine.
  leaf,

  /// The page underneath: it stays put while its window opens.
  reveal,
}

/// How close the camera sits to the paper, in page widths, as a fraction of a
/// page: the lifted free edge ends up magnified by `1 / (1 + depth)` at the end
/// of a turn. Expressed per page width rather than in pixels, so the tilt reads
/// the same on a phone and on a tablet.
const double kMushafFlipDepth = 0.48;

/// A tilt this close to a right angle already projects a hairline leaf; past
/// it the page would show its back, which a one-page-per-screen reader has no
/// room for.
const double _kMinCover = 1e-6;

/// Below this the pager is considered at rest, so a settled page is drawn by
/// the untouched pipeline and its golden stays byte-identical.
const double _kTurnRestEpsilon = 1e-4;

/// One slot's share of a turn, as pure numbers.
///
/// At rest every slot answers [MushafTurnFrame.still], so an untouched reader
/// paints byte-identically to the build before this effect existed.
@immutable
class MushafTurnFrame {
  const MushafTurnFrame({
    required this.dx,
    required this.angle,
    required this.progress,
    required this.role,
  });

  /// The unturned state: nothing moves, nothing tilts, nothing is shaded.
  const MushafTurnFrame.still()
      : dx = 0,
        angle = 0,
        progress = 0,
        role = MushafTurnRole.none;

  /// Horizontal shift of the slot, in page widths, on top of the pager.
  final double dx;

  /// The leaf's tilt about the spine, in radians: 0 flat, just short of a right
  /// angle edge-on. Both slots of a turn carry the same value — only the leaf
  /// rotates, the page beneath reads it as where the fold has travelled.
  final double angle;

  /// Distance travelled through the turn, 0..1 — drives the shading only.
  final double progress;

  final MushafTurnRole role;

  bool get isStill => role == MushafTurnRole.none && dx == 0 && angle == 0;

  bool get isTurning => angle > 0;

  /// The share of the slot the lifted leaf still covers once the camera has
  /// foreshortened it. The reveal's window is exactly the rest, so the two
  /// painted surfaces tile the slot at every angle instead of overlapping or
  /// leaving a seam — which is what a hinge looks like, and what a squeezed
  /// scale could never do.
  double get cover {
    if (angle <= 0) {
      return 1;
    }
    return (math.cos(angle) / (1 + kMushafFlipDepth * math.sin(angle)))
        .clamp(0.0, 1.0);
  }

  /// The spine side. The leaf hinges there; the reveal opens away from it.
  Alignment alignmentFor({required bool rtl}) =>
      rtl ? Alignment.centerRight : Alignment.centerLeft;

  /// The visible window, in the slot's own (already translated) coordinates.
  Rect clipRect(Size size, {required bool rtl}) {
    if (role != MushafTurnRole.reveal) {
      return Offset.zero & size;
    }
    final width = size.width * (1 - cover).clamp(0.0, 1.0);
    return Rect.fromLTWH(rtl ? 0 : size.width - width, 0, width, size.height);
  }

  /// The slot's transform. The leaf rotates about the spine with the camera a
  /// couple of pages away, so its free edge lifts towards the reader; every
  /// other slot is the identity, which `RenderTransform` paints without
  /// building a layer.
  Matrix4 matrixFor({required bool rtl, required Size size}) {
    if (role != MushafTurnRole.leaf || angle <= 0) {
      return Matrix4.identity();
    }
    final width = size.width <= 0 ? 1.0 : size.width;
    return Matrix4.identity()
      ..setEntry(3, 2, kMushafFlipDepth / width)
      ..rotateY(rtl ? angle : -angle);
  }

  @override
  bool operator ==(Object other) =>
      other is MushafTurnFrame &&
      other.dx == dx &&
      other.angle == angle &&
      other.progress == progress &&
      other.role == role;

  @override
  int get hashCode => Object.hash(dx, angle, progress, role);
}

/// The frame a slot contributes at continuous pager position [page].
///
/// [page] is the pager's own zero-based position (fractional mid-swipe) and
/// [index] the zero-based slot being built. Only two slots ever move: the leaf
/// at `floor(page)` and the page that takes its place at `floor(page) + 1`.
MushafTurnFrame mushafTurnFrameFor({
  required MushafPageTurn mode,
  required double? page,
  required int index,
  required int pageCount,
  required bool rtl,
}) {
  if (mode == MushafPageTurn.plain || page == null) {
    return const MushafTurnFrame.still();
  }
  if (!page.isFinite || page < 0 || page > pageCount - 1) {
    return const MushafTurnFrame.still();
  }
  final base = page.floor();
  final fraction = page - base;
  if (fraction < _kTurnRestEpsilon) {
    return const MushafTurnFrame.still();
  }
  if (index != base && index != base + 1) {
    return const MushafTurnFrame.still();
  }
  // Both slots cancel the pager: the leaf pivots about the spine in place and
  // the page beneath stands still while its window opens, so the reader sees a
  // page being lifted rather than two pages sliding past each other.
  //
  // The tilt is derived from the distance travelled, not from an angle driven
  // by it, so the fold stays under the reader's finger: a swipe a quarter of
  // the way through uncovers a quarter of the next page. The turn is
  // continuous at both ends — a fraction of 0 is a flat leaf, a fraction of 1
  // is the next page fully uncovered.
  final tilt = math.acos((1 - fraction).clamp(_kMinCover, 1.0));
  return MushafTurnFrame(
    dx: rtl ? index - page : page - index,
    angle: tilt,
    progress: fraction,
    role: index == base ? MushafTurnRole.leaf : MushafTurnRole.reveal,
  );
}

/// Wraps one pager slot in the page-turn effect.
///
/// The wrapper chain is the same in every mode and at every position — only
/// its numbers change. Dropping a link when the frame is still would change
/// the widget type under the slot, unmount the page subtree and lose
/// `Qcf4PageViewer`'s cached layout mid-swipe.
class MushafTurningPage extends StatelessWidget {
  const MushafTurningPage({
    super.key,
    required this.controller,
    required this.index,
    required this.pageCount,
    required this.mode,
    required this.palette,
    required this.child,
    this.leafImage,
    this.lite = false,
  });

  final PageController controller;
  final int index;
  final int pageCount;
  final MushafPageTurn mode;
  final MushafPalette palette;
  final Widget child;

  /// The current page, captured when the turn began. The strip effects paint
  /// this instead of the live page: eight hinges around a widget subtree would
  /// mean eight layouts per frame, while strips of one captured sheet are one
  /// draw call each. Null (not captured yet, or freed) falls back to the live
  /// single-plane tilt, so a turn never waits for a snapshot.
  final ui.Image? leafImage;

  /// Six book hinges or eight scroll hinges instead of eight and twelve.
  final bool lite;

  static double? _pageOf(PageController controller) {
    if (controller.positions.length != 1) {
      return null;
    }
    final position = controller.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return null;
    }
    return controller.page;
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The perspective is a page-width fraction, so the slot's own size is
        // part of the geometry and both the matrix and the clip need it.
        final size = constraints.biggest;
        return AnimatedBuilder(
          // A ScrollController forwards its position's notifications, so the
          // position itself can drive the turn — no ticker to own or dispose.
          animation: controller,
          child: child,
          builder: (context, page) {
            final frame = mushafTurnFrameFor(
              mode: mode,
              page: _pageOf(controller),
              index: index,
              pageCount: pageCount,
              rtl: rtl,
            );
            // A captured leaf plus a strip mode is the curved turn: the strips
            // are painted from the image, so the live page is hidden (not
            // unmounted — Visibility keeps its state and layout) and the
            // slot's own transform stays identity. Without an image the live
            // page tilts on one plane, exactly as before.
            final wantsStrips = frame.role == MushafTurnRole.leaf &&
                frame.isTurning &&
                mode != MushafPageTurn.plain &&
                leafImage != null;
            final matrix = wantsStrips
                ? Matrix4.identity()
                : frame.matrixFor(rtl: rtl, size: size);
            final quality = frame.role == MushafTurnRole.leaf &&
                    frame.isTurning &&
                    !wantsStrips
                ? FilterQuality.low
                : null;
            final shade = frame.role == MushafTurnRole.none
                ? null
                : _TurnShadePainter(
                    role: frame.role,
                    progress: frame.progress,
                    fold: 1 - frame.cover,
                    rtl: rtl,
                    tint: palette.chrome,
                  );
            final painter = wantsStrips
                ? _TurnStripsPainter(
                    image: leafImage!,
                    mode: mode,
                    progress: frame.progress,
                    rtl: rtl,
                    paper: palette.background,
                    tint: palette.chrome,
                    highlight: palette.accent,
                    lite: lite,
                  )
                : shade;
            return FractionalTranslation(
              translation: Offset(frame.dx, 0),
              child: ClipRect(
                clipper: _TurnClipper(frame, rtl, size),
                child: Transform(
                  transform: matrix,
                  alignment: frame.alignmentFor(rtl: rtl),
                  filterQuality: quality,
                  child: CustomPaint(
                    // Only the foreground painter is consulted for hits, so the
                    // shade can never swallow an ayah tap.
                    foregroundPainter: painter,
                    child: wantsStrips
                        ? Visibility(
                            visible: false,
                            maintainState: true,
                            maintainAnimation: true,
                            maintainSize: true,
                            child: page!,
                          )
                        : page!,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TurnClipper extends CustomClipper<Rect> {
  _TurnClipper(this.frame, this.rtl, this.size);

  final MushafTurnFrame frame;
  final bool rtl;
  final Size size;

  @override
  Rect getClip(Size size) => frame.clipRect(size, rtl: rtl);

  @override
  bool shouldReclip(_TurnClipper oldClipper) =>
      oldClipper.rtl != rtl ||
      oldClipper.size != size ||
      oldClipper.frame != frame;
}

/// Paints the paper's share of the turn: a gutter shadow at the spine, a thin
/// crease along the leaf's free edge and a band on the page beneath it.
///
/// It is drawn inside the transform, so the shading tilts with the page, and it
/// uses only [MushafPalette.chrome] — the one ink that is dark in both paper
/// palettes, where the night text would read as a glow instead of a shadow.
class _TurnShadePainter extends CustomPainter {
  const _TurnShadePainter({
    required this.role,
    required this.progress,
    required this.fold,
    required this.rtl,
    required this.tint,
  });

  final MushafTurnRole role;
  final double progress;

  /// Where the moving edge sits across the slot, 0..1 — the reveal's window is
  /// the fold, so its shadow has to follow the hinge and not the clock.
  final double fold;
  final bool rtl;
  final Color tint;

  /// Thin crease line along the leaf's free edge.
  static const double _foldHairline = 1.2;

  /// Width of the shadow the lifted leaf casts on the page beneath, as a
  /// fraction of the page width.
  static const double _foldBand = 0.055;

  /// Deepest wash of the leaf's gutter shadow.
  static const double _leafShade = 0.22;

  /// Deepest inked shadow of the reveal band.
  static const double _revealShade = 0.18;

  @override
  void paint(Canvas canvas, Size size) {
    if (role == MushafTurnRole.none || size.isEmpty) {
      return;
    }
    final c = progress.clamp(0.0, 1.0);
    final lift = math.sin(c * math.pi / 2);

    if (role == MushafTurnRole.leaf) {
      if (lift <= 0) {
        return;
      }
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
            end: rtl ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              tint.withValues(alpha: _leafShade * lift),
              tint.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          rtl ? 0 : size.width - _foldHairline,
          0,
          _foldHairline,
          size.height,
        ),
        Paint()..color = tint.withValues(alpha: 0.30 * lift),
      );
      return;
    }

    // The band fades in and out with the turn, otherwise it would pop at the
    // moment the reader grabs the page.
    final bandAlpha = _revealShade * math.sin(c * math.pi);
    if (bandAlpha <= 0) {
      return;
    }
    final band = size.width * _foldBand;
    if (band <= 0 || band >= size.width) {
      return;
    }
    // The band's darker edge rides the fold, so it is anchored to where the
    // leaf's edge projects — not to the fraction the swipe has travelled.
    final edge = fold.clamp(0.0, 1.0) * size.width;
    final left = (edge - band).clamp(0.0, size.width - band);
    final rect = Rect.fromLTWH(left, 0, band, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
          end: rtl ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            tint.withValues(alpha: bandAlpha),
            tint.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_TurnShadePainter oldDelegate) =>
      oldDelegate.role != role ||
      oldDelegate.progress != progress ||
      oldDelegate.fold != fold ||
      oldDelegate.rtl != rtl ||
      oldDelegate.tint != tint;

  @override
  bool shouldRebuildSemantics(_TurnShadePainter oldDelegate) => false;
}

/// The curved turn, painted from one captured page: a hinge chain from the
/// spine outwards, one strip per hinge.
///
/// Each strip is drawn in its parent's frame and then the canvas is advanced by
/// one strip width along the *rotated* axis, so the strips form a chain instead
/// of a fan: that is what makes the sheet curve rather than hinge like a door.
/// Strips past edge-on show the paper's own back, never a mirrored glyph.
class _TurnStripsPainter extends CustomPainter {
  const _TurnStripsPainter({
    required this.image,
    required this.mode,
    required this.progress,
    required this.rtl,
    required this.paper,
    required this.tint,
    required this.highlight,
    required this.lite,
  });

  final ui.Image image;
  final MushafPageTurn mode;
  final double progress;
  final bool rtl;
  final Color paper;
  final Color tint;

  /// The section's own accent, used for the specular along the free edge so
  /// the sheet reads as paper instead of a warped bitmap.
  final Color highlight;
  final bool lite;

  /// Deepest wash of a turned hinge.
  static const double _maxStripShade = 0.38;

  /// Width of the spine shadow, as a fraction of the page.
  static const double _spineBand = 0.30;

  /// Deepest spine shadow, once the leaf is fully lifted.
  static const double _spineShade = 0.20;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || image.width == 0) return;
    final strips = mushafTurnStripCount(mode, width: size.width, lite: lite);
    if (strips == 0) return;

    final resolved = progress.clamp(0.0, 1.0);
    final angles =
        mushafTurnStripAngles(mode: mode, p: resolved, strips: strips);
    final stripW = size.width / strips;
    final imgW = image.width.toDouble();
    final srcW = imgW / strips;
    final back = mushafLeafBackOn(paper);
    final perspective = Matrix4.identity()..setEntry(3, 2, kMushafTurnCamera);
    final paint = Paint()..filterQuality = FilterQuality.low;

    canvas.save();
    if (rtl) {
      canvas.translate(size.width, 0);
    } else {
      // The same chain mirrored: the spine is the left edge and the strips
      // advance to the right.
      canvas.scale(-1, 1);
      canvas.translate(-size.width, 0);
    }
    for (var k = 0; k < strips; k++) {
      final a = angles[k];
      final dest = Rect.fromLTWH(-stripW, 0, stripW, size.height);
      final isFreeEdge = k == strips - 1;
      canvas.save();
      canvas.transform(perspective.storage);
      canvas.transform((Matrix4.identity()..rotateY(rtl ? -a : a)).storage);
      final facingBack = a > math.pi / 2 && a < 3 * math.pi / 2;
      if (facingBack) {
        canvas.drawRect(dest, Paint()..color = back);
      } else {
        // Strip k is the k-th sheet from the spine, which is the right edge in
        // an RTL page and the left one otherwise.
        final srcX = rtl ? imgW - (k + 1) * srcW : k * srcW;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(srcX, 0, srcW, image.height.toDouble()),
          dest,
          paint,
        );
        if (isFreeEdge) {
          canvas.drawRect(
            Rect.fromLTWH(-1.6, 0, 1.6, size.height),
            Paint()
              ..color = highlight.withValues(
                  alpha: (0.10 + 0.18 * math.sin(a).abs()).clamp(0.0, 1.0)),
          );
        }
      }
      final shade = math.min(_maxStripShade, math.sin(a).abs() * 0.42);
      if (shade > 0.002) {
        canvas.drawRect(
          dest,
          Paint()
            ..color = tint.withValues(
                alpha: (shade * (facingBack ? 1.15 : 1)).clamp(0.0, 1.0)),
        );
      }
      canvas.restore();
      canvas.translate(-stripW, 0);
    }

    // The gutter shadow rides the whole slot, not each hinge: one continuous
    // gradient at the spine instead of a stack of per-strip bands.
    final lift = math.sin(resolved * math.pi / 2);
    if (lift > 0.001) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              tint.withValues(alpha: _spineShade * lift),
              tint.withValues(alpha: 0),
            ],
            stops: const [0, _spineBand],
          ).createShader(rect),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TurnStripsPainter old) =>
      old.image != image ||
      old.mode != mode ||
      old.progress != progress ||
      old.rtl != rtl ||
      old.paper != paper ||
      old.tint != tint ||
      old.highlight != highlight ||
      old.lite != lite;

  @override
  bool shouldRebuildSemantics(_TurnStripsPainter old) => false;
}

/// How long a programmatic turn takes, and how long the settle reads.
///
/// The pager's own drag ballistics are Flutter's; this drives the turns the app
/// starts itself (edge taps, the next/previous buttons, audio follow) and the
/// settings preview, so «آهسته» is slow where the app owns the clock.
enum MushafTurnSpeed {
  fast('fast', 'سریع', 260),
  normal('normal', 'عادی', 380),
  slow('slow', 'آهسته', 520);

  const MushafTurnSpeed(this.wire, this.label, this.millis);

  final String wire;
  final String label;
  final int millis;

  static MushafTurnSpeed fromWire(String? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return normal;
  }
}
