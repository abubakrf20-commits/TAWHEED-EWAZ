import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/app_text_scale.dart';

/// The app owns its base text size, but must not defeat the device's
/// accessibility setting. These tests pin both halves of that contract: a
/// smaller device scale never shrinks the app, a larger one is honoured up to
/// the app's own ceiling, and the in-app «اندازه فونت» multiplier is the floor.
void main() {
  // A fixed 20px, height:1 line makes the laid-out height a clean multiple of
  // the scale (20 × scale), so the assertions read as multipliers.
  const sample = Text(
    '11',
    style: TextStyle(fontSize: 20, height: 1),
    textDirection: TextDirection.rtl,
  );

  /// Simulates a phone whose system font scale is [deviceScale]. When
  /// [appScale] is given the app's own scaler is applied on top, exactly as
  /// `MaterialApp.builder` does in production.
  Widget harness({required double deviceScale, double? appScale}) {
    return MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(deviceScale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Center(
        child: appScale == null
            ? sample
            : AppTextScale(fontScale: appScale, child: sample),
      ),
    );
  }

  testWidgets('a larger device font setting is honoured, up to the ceiling',
      (tester) async {
    await tester.pumpWidget(harness(deviceScale: 1.0, appScale: 1.0));
    final baseline = tester.getSize(find.text('11')).height;

    await tester.pumpWidget(harness(deviceScale: 1.3, appScale: 1.0));
    expect(tester.getSize(find.text('11')).height, closeTo(baseline * 1.3, 0.01),
        reason: 'a phone set to 130% font should enlarge the app too');

    await tester.pumpWidget(harness(deviceScale: 2.5, appScale: 1.0));
    expect(
        tester.getSize(find.text('11')).height,
        closeTo(baseline * AppTextScale.maxScale, 0.01),
        reason: 'the app ceiling caps an extreme device scale');
  });

  testWidgets('a smaller device font setting never shrinks the app',
      (tester) async {
    await tester.pumpWidget(harness(deviceScale: 0.7, appScale: 1.0));
    final baseline = tester.getSize(find.text('11')).height;

    await tester.pumpWidget(harness(deviceScale: 1.0, appScale: 1.0));
    expect(tester.getSize(find.text('11')).height, closeTo(baseline, 0.01),
        reason: 'the in-app setting is the floor, whatever the phone says');
  });

  testWidgets('follows the in-app font setting', (tester) async {
    await tester.pumpWidget(harness(deviceScale: 1.0, appScale: 1.0));
    final baseline = tester.getSize(find.text('11')).height;

    await tester.pumpWidget(harness(deviceScale: 1.0, appScale: 1.5));
    expect(
        tester.getSize(find.text('11')).height, closeTo(baseline * 1.5, 0.01));

    await tester.pumpWidget(harness(deviceScale: 0.85, appScale: 1.5));
    expect(
        tester.getSize(find.text('11')).height, closeTo(baseline * 1.5, 0.01),
        reason: 'a smaller device scale must not pull the app setting down');

    await tester.pumpWidget(harness(deviceScale: 1.0, appScale: 0.9));
    expect(
        tester.getSize(find.text('11')).height, closeTo(baseline * 0.9, 0.01));

    await tester.pumpWidget(harness(deviceScale: 1.2, appScale: 1.25));
    expect(tester.getSize(find.text('11')).height, closeTo(baseline * 1.5, 0.01),
        reason: 'a larger device scale composes with the in-app setting');
  });

  test('clamps the multiplier to the safe window', () {
    expect(AppTextScale.factorOf(1.0), 1.0);
    expect(AppTextScale.factorOf(0.1), AppTextScale.minScale,
        reason: 'a corrupt stored row must not collapse the layout');
    expect(AppTextScale.factorOf(9.0), AppTextScale.maxScale,
        reason: 'a corrupt stored row must not shatter the layout');
  });
}
