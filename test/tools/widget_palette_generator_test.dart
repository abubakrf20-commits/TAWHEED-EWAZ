import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verifies the drawables emitted by tool/widget_palette_generator.dart still
/// match assets/widget_palettes.json — catches a hand-edited drawable or a
/// palette change that was not regenerated.
void main() {
  late Map<String, dynamic> config;

  setUpAll(() {
    config = _loadJson('assets/widget_palettes.json');
  });

  String alphaHexOf(double step) => switch (step) {
        1.0 => '',
        0.85 => 'D9',
        0.7 => 'B3',
        0.55 => '8C',
        _ => throw StateError('no alpha for $step'),
      };

  test('every opaque palette has one drawable per opacity step', () {
    final palettes =
        (config['palettes'] as List).cast<Map<String, dynamic>>();
    final steps = (config['opacitySteps'] as List).cast<num>();
    for (final p in palettes) {
      if (p['auto'] == true) continue;
      final id = p['id'] as String;
      for (final step in steps) {
        final s = step.toDouble();
        final suffix = s == 1.0 ? '' : '_o${(s * 100).round()}';
        final path =
            'android/app/src/main/res/drawable/widget_${id}_bg$suffix.xml';
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'missing $path');
        final xml = file.readAsStringSync();
        final expectedStart = '${alphaHexOf(s)}${_hex(p['bg'] as String)}';
        final expectedEnd = '${alphaHexOf(s)}${_hex(p['bgEnd'] as String)}';
        expect(
          xml.contains('#$expectedStart'),
          isTrue,
          reason: '$path startColor should be #$expectedStart',
        );
        expect(
          xml.contains('#$expectedEnd'),
          isTrue,
          reason: '$path endColor should be #$expectedEnd',
        );
      }
    }
  });

  test('the native prayer card paints its surface from the palette', () {
    // The generated skin drawables no longer reach the card: a native card's
    // surface slot takes a bitmap, so the renderer paints the palette's
    // gradient itself — with the radius painted INTO the bitmap, so launchers
    // that ignore an outline radius still show the rounded shape.
    final src = File(
      'android/app/src/main/kotlin/com/islamic/tawheeed/widget/'
      'PrayerNativeViews.kt',
    ).readAsStringSync();
    expect(src, contains('WidgetArt.surface('),
        reason: 'the card must paint its background through the cached painter');
    expect(src, contains('WidgetTheme.CORNER_RADIUS_DP'),
        reason: 'the radius stays the single source in WidgetTheme');
    final art = File(
      'android/app/src/main/kotlin/com/islamic/tawheeed/widget/WidgetArt.kt',
    ).readAsStringSync();
    expect(art, contains('GradientDrawable.Orientation.TL_BR'),
        reason: 'the fallback gradient must keep the brand diagonal');
  });

  test('drawables are marked generated', () {
    final file = File(
        'android/app/src/main/res/drawable/widget_brown_gold_bg.xml');
    expect(file.readAsStringSync(), contains('widget_palette_generator'));
  });

  test('every skin bakes the corner radius the native render paints', () {
    final theme = File('android/app/src/main/kotlin/com/islamic/tawheeed/'
            'widget/WidgetTheme.kt')
        .readAsStringSync();
    final radius = RegExp(r'CORNER_RADIUS_DP\s*=\s*(\d+)')
        .firstMatch(theme)
        ?.group(1);
    expect(radius, isNotNull,
        reason: 'WidgetTheme.CORNER_RADIUS_DP is the single radius source');
    final tokens = File(
      'lib/features/settings/presentation/widgets/widget_design_tokens.dart',
    ).readAsStringSync();
    final dartRadius = RegExp(r'widgetRadius\s*=\s*(\d+)')
        .firstMatch(tokens)
        ?.group(1);
    expect(dartRadius, radius,
        reason: 'the Flutter preview token must mirror the Kotlin constant');
    final palettes =
        (config['palettes'] as List).cast<Map<String, dynamic>>();
    final steps = (config['opacitySteps'] as List).cast<num>();
    for (final p in palettes) {
      if (p['auto'] == true) continue;
      final id = p['id'] as String;
      for (final step in steps) {
        final s = step.toDouble();
        final suffix = s == 1.0 ? '' : '_o${(s * 100).round()}';
        final path =
            'android/app/src/main/res/drawable/widget_${id}_bg$suffix.xml';
        expect(
          File(path).readAsStringSync(),
          contains('<corners android:radius="${radius}dp" />'),
          reason: '$path must bake the WidgetTheme radius ($radius dp)',
        );
      }
    }
  });

  test('the generator reads the radius instead of hardcoding one', () {
    final source = File('tool/widget_palette_generator.dart').readAsStringSync();
    expect(source, contains('CORNER_RADIUS_DP'));
    expect(source, isNot(contains('android:radius="20dp"')));
  });
}

Map<String, dynamic> _loadJson(String path) {
  final raw = File(path).readAsStringSync();
  return const JsonDecoder().convert(raw) as Map<String, dynamic>;
}

String _hex(String raw) => raw.replaceFirst('#', '').toUpperCase();
