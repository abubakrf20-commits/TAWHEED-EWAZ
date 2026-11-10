import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:tawheeed/features/home/presentation/providers/arc_style_provider.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';

/// Geometry of the home arc, in the 330×215 design space.
///
/// The arc is the top half of a circle whose centre sits ON the horizon
/// (330/2, 170) with R = 135, so t = 0 is the left end, t = 0.5 the top and
/// t = 1 the right end. Everything is multiplied by one scale factor, so a
/// 320dp phone and a tablet draw the same shape.
class ArcGeometry {
  const ArcGeometry(this.size);

  static const double designWidth = 330;
  static const double designHeight = 206;
  static const double designRadius = 135;
  static const Offset designCenter = Offset(165, 170);

  final Size size;

  double get k => size.width / designWidth;

  /// Circle centre, on the horizon line.
  Offset get center => Offset(designCenter.dx * k, designCenter.dy * k);

  double get radius => designRadius * k;

  /// The horizon (baseline) y.
  double get baselineY => center.dy;

  /// Canvas height the design asks for at this width.
  static double heightFor(double width) =>
      width * designHeight / designWidth;

  /// Point on the arc for a path fraction 0..1 (0 = left end).
  Offset pointAt(double t) {
    final angle = math.pi * (1 - t.clamp(0.0, 1.0));
    return center +
        Offset(radius * math.cos(angle), -radius * math.sin(angle));
  }

  /// Unit vector pointing away from the centre at [t].
  Offset normalAt(double t) {
    final point = pointAt(t);
    final delta = point - center;
    final length = delta.distance;
    if (length < 0.001) return const Offset(0, -1);
    return delta / length;
  }

  /// The half-disc under the arc, closed along the baseline.
  Path domePath() {
    final rect = Rect.fromCircle(center: center, radius: radius);
    return Path()
      ..moveTo(center.dx - radius, baselineY)
      ..arcTo(rect, math.pi, math.pi, false)
      ..close();
  }

  /// The arc stroke itself, left end over the top to the right end.
  Path arcPath() {
    final rect = Rect.fromCircle(center: center, radius: radius);
    return Path()
      ..addArc(rect, math.pi, math.pi);
  }

  /// A short piece of the arc from [from] to [to] (both 0..1).
  Path arcSlice(double from, double to) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    return Path()
      ..addArc(rect, math.pi * (1 + from), math.pi * (to - from));
  }
}

/// Where a label belongs on the arc.
enum ArcLabelRole {
  /// A prayer milestone's name, outside the arc.
  tagName,

  /// A milestone name inside the arc (diamond names, or every name in the
  /// segmented style).
  innerName,
}

/// One placed label.
///
/// The rectangle is ESTIMATED from the string length and the font size (no
/// text layout here), which keeps the planner cheap and makes the no-overlap
/// rule testable without a font. The painter centres the real text on
/// [center], so a wide glyph can stray inside the margin the planner reserved.
@immutable
class ArcLabel {
  const ArcLabel({
    required this.markerIndex,
    required this.text,
    required this.center,
    required this.fontSize,
    required this.role,
    required this.rect,
  });

  final int markerIndex;
  final String text;
  final Offset center;
  final double fontSize;
  final ArcLabelRole role;
  final Rect rect;

  @override
  String toString() =>
      'ArcLabel($markerIndex, $text, $role, ${rect.width.toStringAsFixed(1)}'
      'x${rect.height.toStringAsFixed(1)})';
}

/// The labels that fit, in drawing order, plus what was dropped and why.
@immutable
class ArcLabelPlan {
  const ArcLabelPlan({required this.labels, required this.dropped});

  final List<ArcLabel> labels;

  /// Marker indices whose label (or time) was dropped for room.
  final Set<int> dropped;

  bool overlapsAnything(ArcLabel label) =>
      labels.any((other) => other.rect.overlaps(label.rect));
}

/// Estimates a text box without a font: wide enough for Persian at these sizes,
/// and identical in the painter and in the tests.
Rect estimateTextBox(String text, Offset center, double fontSize) {
  final width = (text.length * fontSize * 0.52) + 4;
  final height = fontSize * 1.25;
  return Rect.fromCenter(center: center, width: width, height: height);
}

double _designFont(double base, double k, double textScale) =>
    (base * k * textScale).clamp(10.0, base * 1.3);

/// Places the labels of the tagged/sky styles: prayer tags outside the arc,
/// diamond names just inside it, everything dropped rather than nudged when it
/// cannot fit.
///
/// The clock times are NOT drawn (user request, 2026-11: the arc read crowded,
/// and the times already live in the milestone pill below and the prayer
/// card) — only names are planned. [showSmallLabels] comes from the setting,
/// and [nowT] decides which diamond name survives at scale > 1.15 (the one
/// next to the orb).
ArcLabelPlan planTaggedLabels({
  required ArcGeometry geometry,
  required List<ArcMarker> markers,
  required double textScale,
  required bool showSmallLabels,
  required double nowT,
}) {
  final k = geometry.k;
  final accepted = <Rect>[];
  final labels = <ArcLabel>[];
  final dropped = <int>{};

  int nextIndex = markers.indexWhere((m) => m.state == ArcMarkerState.next);
  if (nextIndex < 0) nextIndex = markers.length - 1;

  // The diamond nearest the orb keeps its name when the scale squeezes them.
  var nearestDerived = -1;
  var nearestDistance = double.infinity;
  for (var i = 0; i < markers.length; i++) {
    if (markers[i].kind != ArcMarkerKind.derived) continue;
    final distance = (markers[i].fraction - nowT).abs();
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestDerived = i;
    }
  }

  bool fits(Rect rect) => !accepted.any((other) => other.overlaps(rect));

  void place(ArcLabel label) {
    if (!fits(label.rect)) {
      dropped.add(label.markerIndex);
      return;
    }
    accepted.add(label.rect);
    labels.add(label);
    dropped.remove(label.markerIndex);
  }

  // 1. The next prayer's tag, and the other prayer tags.
  final order = <int>[
    nextIndex,
    for (var i = 0; i < markers.length; i++)
      if (i != nextIndex && markers[i].kind == ArcMarkerKind.prayer) i,
  ];
  for (final i in order) {
    final marker = markers[i];
    final at = geometry.pointAt(marker.fraction);
    final isEdge = marker.fraction <= 0.001 || marker.fraction >= 0.999;
    final anchor = isEdge
        ? Offset(at.dx, geometry.baselineY + 26 * k)
        : at + geometry.normalAt(marker.fraction) * (24 * k);
    final nameSize = _designFont(11.5, k, textScale);
    final nameLabel = ArcLabel(
      markerIndex: i,
      text: marker.label,
      center: anchor,
      fontSize: nameSize,
      role: ArcLabelRole.tagName,
      rect: estimateTextBox(marker.label, anchor, nameSize),
    );
    if (!fits(nameLabel.rect)) {
      dropped.add(i);
      continue;
    }
    accepted.add(nameLabel.rect);
    labels.add(nameLabel);
  }

  // 2. Diamond names INSIDE the arc, close to the stroke. They had drifted to
  // 0.72 R — a ~38 dp gap that read as detached from the arc they name (user
  // request). 17 dp inside the stroke clears the 11 dp segment band and the
  // next marker's dashed ring while keeping the name visually attached.
  if (!showSmallLabels) {
    return ArcLabelPlan(labels: labels, dropped: dropped);
  }
  final hideDiamonds = textScale > 1.15;
  final insideFactor = (geometry.radius - 17 * k) / geometry.radius;
  for (var i = 0; i < markers.length; i++) {
    final marker = markers[i];
    if (marker.kind != ArcMarkerKind.derived) continue;
    if (hideDiamonds && i != nearestDerived) {
      dropped.add(i);
      continue;
    }
    final at = geometry.pointAt(marker.fraction);
    final inside = geometry.center + (at - geometry.center) * insideFactor;
    final anchor = inside - Offset(0, 2 * k);
    final size = _designFont(10, k, textScale);
    place(
      ArcLabel(
        markerIndex: i,
        text: marker.label,
        center: anchor,
        fontSize: size,
        role: ArcLabelRole.innerName,
        rect: estimateTextBox(marker.label, anchor, size),
      ),
    );
  }

  return ArcLabelPlan(labels: labels, dropped: dropped);
}

/// Places the segmented style's names: every milestone inside the arc, the
/// derived ones dropped first when the row gets tight.
ArcLabelPlan planSegmentedLabels({
  required ArcGeometry geometry,
  required List<ArcMarker> markers,
  required double textScale,
  required double nowT,
}) {
  final k = geometry.k;
  final accepted = <Rect>[];
  final labels = <ArcLabel>[];
  final dropped = <int>{};

  final hideDiamonds = textScale > 1.15;
  var nearestDerived = -1;
  var nearestDistance = double.infinity;
  for (var i = 0; i < markers.length; i++) {
    if (markers[i].kind != ArcMarkerKind.derived) continue;
    final distance = (markers[i].fraction - nowT).abs();
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestDerived = i;
    }
  }

  for (var i = 0; i < markers.length; i++) {
    final marker = markers[i];
    if (marker.kind == ArcMarkerKind.derived &&
        hideDiamonds &&
        i != nearestDerived) {
      dropped.add(i);
      continue;
    }
    final at = geometry.pointAt(marker.fraction);
    final anchor = geometry.center +
        (at - geometry.center) * ((geometry.radius - 21 * k) / geometry.radius);
    final size = _designFont(10, k, textScale);
    final rect = estimateTextBox(marker.label, anchor, size);
    if (accepted.any((other) => other.overlaps(rect))) {
      dropped.add(i);
      continue;
    }
    accepted.add(rect);
    labels.add(ArcLabel(
      markerIndex: i,
      text: marker.label,
      center: anchor,
      fontSize: size,
      role: ArcLabelRole.innerName,
      rect: rect,
    ));
  }

  return ArcLabelPlan(labels: labels, dropped: dropped);
}

/// Labels for whichever style is active.
ArcLabelPlan planArcLabels({
  required HomeArcStyle style,
  required ArcGeometry geometry,
  required List<ArcMarker> markers,
  required double textScale,
  required bool showSmallLabels,
  required double nowT,
}) {
  if (style == HomeArcStyle.segments) {
    return planSegmentedLabels(
      geometry: geometry,
      markers: markers,
      textScale: textScale,
      nowT: nowT,
    );
  }
  return planTaggedLabels(
    geometry: geometry,
    markers: markers,
    textScale: textScale,
    showSmallLabels: showSmallLabels,
    nowT: nowT,
  );
}
