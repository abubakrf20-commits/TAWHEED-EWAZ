import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/home/presentation/providers/arc_style_provider.dart';
import 'package:tawheeed/features/home/presentation/widgets/arc/arc_layout.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';

const _fractions = <double>[
  0,
  1 / 6,
  1 / 3,
  1 / 2,
  7 / 12,
  8 / 12,
  9 / 12,
  10 / 12,
  11 / 12,
  1,
];

const _labels = [
  'صبح',
  'طلوع',
  'ضحی',
  'ظهر',
  'عصر',
  'مغرب',
  'عشاء',
  'نیمه‌شب',
  'ثلث آخر',
  'صبح (فردا)',
];

const _kinds = [
  ArcMarkerKind.prayer,
  ArcMarkerKind.derived,
  ArcMarkerKind.derived,
  ArcMarkerKind.prayer,
  ArcMarkerKind.prayer,
  ArcMarkerKind.prayer,
  ArcMarkerKind.prayer,
  ArcMarkerKind.derived,
  ArcMarkerKind.derived,
  ArcMarkerKind.prayer,
];

List<ArcMarker> _markers({int nextIndex = 6, int? dropIndex}) {
  final base = DateTime(2026, 11, 1, 5);
  final markers = <ArcMarker>[];
  for (var i = 0; i < _fractions.length; i++) {
    if (i == dropIndex) continue;
    markers.add(ArcMarker(
      label: _labels[i],
      kind: _kinds[i],
      fraction: _fractions[i],
      time: base.add(Duration(hours: i * 2)),
      state: i == nextIndex
          ? ArcMarkerState.next
          : (i < nextIndex
              ? ArcMarkerState.passed
              : ArcMarkerState.upcoming),
      isEnd: i == _fractions.length - 1,
    ));
  }
  return markers;
}

ArcLabelPlan _plan({
  required double width,
  required double scale,
  bool smallLabels = true,
  HomeArcStyle style = HomeArcStyle.tags,
  List<ArcMarker>? markers,
  double nowT = 0.55,
}) {
  final geometry = ArcGeometry(Size(width, ArcGeometry.heightFor(width)));
  return planArcLabels(
    style: style,
    geometry: geometry,
    markers: markers ?? _markers(),
    textScale: scale,
    showSmallLabels: smallLabels,
    nowT: nowT,
  );
}

void main() {
  group('geometry', () {
    test('the arc runs left end, top, right end', () {
      const geometry = ArcGeometry(Size(330, 206));
      expect(geometry.center, const Offset(165, 170));
      expect(geometry.radius, 135);

      final left = geometry.pointAt(0);
      final top = geometry.pointAt(0.5);
      final right = geometry.pointAt(1);
      expect(left.dx, closeTo(30, 0.001));
      expect(left.dy, closeTo(170, 0.001));
      expect(top.dx, closeTo(165, 0.001));
      expect(top.dy, closeTo(35, 0.001));
      expect(right.dx, closeTo(300, 0.001));
      expect(right.dy, closeTo(170, 0.001));
    });

    test('the canvas keeps the design ratio at any width', () {
      expect(ArcGeometry.heightFor(330), closeTo(206, 0.001));
      expect(ArcGeometry.heightFor(165), closeTo(103, 0.001));
    });

    test('markers sit on their design fractions', () {
      const geometry = ArcGeometry(Size(330, 206));
      final dhuhr = geometry.pointAt(0.5);
      expect(dhuhr.dx, closeTo(165, 0.01));
      expect(dhuhr.dy, closeTo(35, 0.01), reason: 'ظهر is the top');
      // The left half is three segments, the right half six.
      final sunrise = geometry.pointAt(1 / 6);
      final asr = geometry.pointAt(7 / 12);
      expect(sunrise.dx, lessThan(165));
      expect(asr.dx, greaterThan(165));
    });

    test('every arc path faces UP, over the baseline', () {
      const geometry = ArcGeometry(Size(330, 206));
      final center = geometry.center;
      final radius = geometry.radius;
      final domeTop = center.dy - radius;
      // A path is allowed to leave the canvas by a hair of Bezier slack, but a
      // sweep that dips below the horizon reaches center.dy + radius = 305.
      final horizon = center.dy + 1.0;

      final stroke = geometry.arcPath().getBounds();
      expect(stroke.top, closeTo(domeTop, 1.0), reason: 'the stroke must crown the dome');
      expect(stroke.bottom, lessThanOrEqualTo(horizon), reason: 'the stroke is a bowl, not a dome');

      final dome = geometry.domePath().getBounds();
      expect(dome.top, closeTo(domeTop, 1.0));
      expect(dome.bottom, closeTo(center.dy, 1.0), reason: 'the half-disc closes on the horizon');

      for (final (from, to) in const <(double, double)>[(0, 1), (0.25, 0.75), (0, 0.4), (0.6, 1)]) {
        final slice = geometry.arcSlice(from, to).getBounds();
        expect(slice.bottom, lessThanOrEqualTo(horizon), reason: 'arcSlice($from, $to) faces down');
        expect(slice.inflate(0.75).contains(geometry.pointAt((from + to) / 2)), isTrue,
            reason: 'arcSlice($from, $to) must pass through its own pointAt');
      }
    });
  });

  group('label layout', () {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.15, 1.3]) {
        test('no two labels overlap at ${width.toInt()}dp / $scale', () {
          final plan = _plan(width: width, scale: scale);
          for (var i = 0; i < plan.labels.length; i++) {
            for (var j = i + 1; j < plan.labels.length; j++) {
              expect(
                plan.labels[i].rect.overlaps(plan.labels[j].rect),
                isFalse,
                reason: '${plan.labels[i]} overlaps ${plan.labels[j]}',
              );
            }
          }
        });
      }
    }

    test('the arc carries NO clock times (user request 2026-11)', () {
      final plan = _plan(width: 412, scale: 1.0);
      // The names stay; the times under them are gone — they live in the
      // milestone pill below the arc and in the prayer card, and the arc read
      // crowded with both.
      expect(
        plan.labels.map((l) => l.role).toSet(),
        {ArcLabelRole.tagName, ArcLabelRole.innerName},
        reason: 'names only — the tagTime role is retired with the times',
      );
      expect(plan.labels.map((l) => l.text), contains('ظهر'));
    });

    test('the tag names are all present at 412dp', () {
      final plan = _plan(width: 412, scale: 1.0);
      final names = plan.labels
          .where((l) => l.role == ArcLabelRole.tagName)
          .map((l) => l.text)
          .toList();
      expect(names, containsAll(['صبح', 'ظهر', 'عصر', 'مغرب', 'عشاء']));
    });

    test('diamond names live inside the arc', () {
      final plan = _plan(width: 412, scale: 1.0);
      final inner = plan.labels
          .where((l) => l.role == ArcLabelRole.innerName)
          .map((l) => l.text)
          .toList();
      expect(inner, isNotEmpty);
      expect(inner, contains('طلوع'));
    });

    test('the small-label setting hides the diamond names', () {
      final plan = _plan(width: 412, scale: 1.0, smallLabels: false);
      final inner = plan.labels.where((l) => l.role == ArcLabelRole.innerName);
      // At scale 1.0 the only survivor allowed is the one next to the orb; with
      // the setting off none of them are drawn at all.
      expect(inner, isEmpty);
    });

    test('the diamond names sit close to the stroke they name', () {
      final geometry = ArcGeometry(Size(412, ArcGeometry.heightFor(412)));
      final plan = _plan(width: 412, scale: 1.0);
      final inner = plan.labels
          .where((l) => l.role == ArcLabelRole.innerName)
          .toList();
      expect(inner, isNotEmpty);
      for (final label in inner) {
        final marker = _markers()[label.markerIndex];
        final at = geometry.pointAt(marker.fraction);
        // The old 0.72 R put ~38 dp of air between the name and the arc; the
        // names now hug the stroke (17 dp inside it, plus the small nudge).
        // Measured from the circle's centre, in design units.
        final gap = ((at - geometry.center).distance -
                (label.center - geometry.center).distance) /
            geometry.k;
        expect(gap, closeTo(17.0, 2.5), reason: label.text);
        expect(gap, lessThan(24.0),
            reason: '${label.text} must not drift away from the arc again');
      }
    });

    test('a dropped milestone keeps the rest on the arc', () {
      // No isha (high latitude): eight markers, nothing crashes, labels fit.
      final plan = _plan(width: 360, scale: 1.15, markers: _markers(dropIndex: 6));
      for (var i = 0; i < plan.labels.length; i++) {
        for (var j = i + 1; j < plan.labels.length; j++) {
          expect(
            plan.labels[i].rect.overlaps(plan.labels[j].rect),
            isFalse,
          );
        }
      }
      expect(plan.labels, isNotEmpty);
    });

    test('the segmented style puts every name inside', () {
      final plan = _plan(
        width: 412,
        scale: 1.0,
        style: HomeArcStyle.segments,
      );
      expect(
        plan.labels.every((l) => l.role == ArcLabelRole.innerName),
        isTrue,
      );
      expect(plan.labels.map((l) => l.text), contains('ظهر'));
    });
  });

  group('style preference', () {
    test('the wire values are stable and unknown values fall back to tags', () {
      expect(HomeArcStyle.tags.wire, 'tags');
      expect(HomeArcStyle.sky.wire, 'sky');
      expect(HomeArcStyle.segments.wire, 'segments');
      expect(HomeArcStyle.fromWire('sky'), HomeArcStyle.sky);
      expect(HomeArcStyle.fromWire(null), HomeArcStyle.tags);
      expect(HomeArcStyle.fromWire('nonsense'), HomeArcStyle.tags);
    });

    test('each style has its Persian label', () {
      expect(HomeArcStyle.tags.label, 'برچسب‌دار');
      expect(HomeArcStyle.sky.label, 'آسمان');
      expect(HomeArcStyle.segments.label, 'قطعه‌ای');
    });
  });
}
